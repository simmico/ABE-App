import '../../../../core/uac/uac_permission_matrix.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../../admin/domain/services/admin_command_service.dart';
import '../../../wallet/domain/services/wallet_and_ledger_service.dart';
import '../models/store_models.dart';

/// Pargo 4-hour dispatch tracking status for Stock-Up Supply Store orders.
enum StoreOrderFulfilmentStatus {
  pendingFulfilment('pending_fulfilment', 'Pending Fulfilment'),
  packed('packed', 'Packed at Warehouse'),
  pargoDispatched4h('pargo_dispatched_4h', 'Pargo 4-Hour Dispatch'),
  collected('collected', 'Collected at Pargo Point');

  const StoreOrderFulfilmentStatus(this.code, this.label);
  final String code;
  final String label;

  static StoreOrderFulfilmentStatus fromCode(String rawCode) {
    for (final status in StoreOrderFulfilmentStatus.values) {
      if (status.code == rawCode.trim()) return status;
    }
    return StoreOrderFulfilmentStatus.pendingFulfilment;
  }
}

/// Result summary from a Hybrid Inventory Sync operation (CSV, manual, or API webhook).
class InventorySyncResult {
  const InventorySyncResult({
    required this.source,
    required this.importedCount,
    required this.skippedCount,
    required this.errors,
  });

  final StoreInventorySyncSource source;
  final int importedCount;
  final int skippedCount;
  final List<String> errors;
}

/// Manages the B2B Stock-Up Supply Store, Tech Pending-Payout checkout,
/// Pargo 4-hour dispatch tracking, and the Hybrid Inventory Sync Adapter.
class HybridInventoryAndStoreService {
  HybridInventoryAndStoreService({
    required this.uacMatrix,
    required this.walletService,
    this.adminCommandService,
    List<StoreProduct>? seedProducts,
  }) {
    final seed = seedProducts ?? _buildDefaultSeedProducts();
    for (final product in seed) {
      _products[product.id] = product;
    }
  }

  final UacPermissionMatrix uacMatrix;
  final WalletAndLedgerService walletService;
  final AdminCommandService? adminCommandService;

  final Map<String, StoreProduct> _products = <String, StoreProduct>{};
  final Map<String, StoreOrder> _orders = <String, StoreOrder>{};
  final Map<String, StoreOrder> _ordersByIdempotencyKey =
      <String, StoreOrder>{};

  List<StoreProduct> get products =>
      List<StoreProduct>.unmodifiable(_products.values);

  List<StoreOrder> get orders => List<StoreOrder>.unmodifiable(_orders.values);

  /// 1-click CSV / Excel-exported CSV upload for Warehouse Suppliers & Admins.
  ///
  /// Expected columns (with optional header row):
  /// `sku,name,category,priceZar,stockQuantity`
  InventorySyncResult importInventoryFromCsv({
    required String csvContent,
    required String actorId,
    required String actorUacGroup,
    bool actorIsActive = true,
  }) {
    _requireInventoryPermission(actorId, actorUacGroup, actorIsActive);

    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i == 0 && line.toLowerCase().startsWith('sku,')) {
        continue;
      }

      final parts = _splitCsvLine(line);
      if (parts.length < 5) {
        skipped++;
        errors.add('Row ${i + 1}: expected 5 columns (sku,name,category,priceZar,stockQuantity).');
        continue;
      }

      try {
        final cleanSku = InputSanitiser.sanitiseText(parts[0], maxLength: 80)
            .toUpperCase();
        final cleanName = InputSanitiser.sanitiseText(parts[1], maxLength: 160);
        final cleanCategory =
            InputSanitiser.sanitiseText(parts[2], maxLength: 80);
        final priceZar = int.parse(parts[3].trim());
        final stockQty = int.parse(parts[4].trim());

        final cleanSlug = cleanSku
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
        if (cleanSku.isEmpty || cleanName.isEmpty || cleanSlug.isEmpty) {
          throw ArgumentError('SKU and product name cannot be empty.');
        }
        final productId = 'prod_$cleanSlug';
        final product = StoreProduct(
          id: productId,
          sku: cleanSku,
          name: cleanName,
          category: cleanCategory.isEmpty ? 'Gel & BIAB' : cleanCategory,
          priceZar: priceZar,
          stockQuantity: stockQty,
          syncSource: StoreInventorySyncSource.csvImport,
          isAvailable: stockQty > 0,
        );
        _products[product.id] = product;
        imported++;
      } catch (e) {
        skipped++;
        errors.add('Row ${i + 1}: invalid product data ($e).');
      }
    }

    adminCommandService?.recordAuditLog(
      actorId: actorId,
      action: 'store.csv_import',
      targetId: 'store_products',
      notes: 'Imported $imported products ($skipped skipped) via CSV',
    );

    return InventorySyncResult(
      source: StoreInventorySyncSource.csvImport,
      importedCount: imported,
      skippedCount: skipped,
      errors: errors,
    );
  }

  /// Manual Admin/Supplier product creation or stock update.
  StoreProduct upsertProductManual({
    required StoreProduct product,
    required String actorId,
    required String actorUacGroup,
    bool actorIsActive = true,
  }) {
    _requireInventoryPermission(actorId, actorUacGroup, actorIsActive);

    final manualProduct = StoreProduct(
      id: product.id,
      sku: product.sku,
      name: product.name,
      category: product.category,
      priceZar: product.priceZar,
      stockQuantity: product.stockQuantity,
      syncSource: StoreInventorySyncSource.adminManual,
      isAvailable: product.isAvailable && product.stockQuantity > 0,
    );
    _products[manualProduct.id] = manualProduct;

    adminCommandService?.recordAuditLog(
      actorId: actorId,
      action: 'store.manual_upsert',
      targetId: manualProduct.id,
      notes: 'Manual inventory update for ${manualProduct.sku}',
    );
    return manualProduct;
  }

  /// External Warehouse REST API / Webhook JSON sync.
  InventorySyncResult syncFromWarehouseApiWebhook({
    required List<Map<String, dynamic>> itemsPayload,
    required String actorId,
    required String actorUacGroup,
    bool actorIsActive = true,
  }) {
    _requireInventoryPermission(actorId, actorUacGroup, actorIsActive);

    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < itemsPayload.length; i++) {
      try {
        final raw = Map<String, dynamic>.from(itemsPayload[i]);
        raw['syncSource'] = StoreInventorySyncSource.supplierApi.code;
        final product = StoreProduct.fromJson(raw);
        _products[product.id] = product;
        imported++;
      } catch (e) {
        skipped++;
        errors.add('Item $i: invalid webhook item ($e).');
      }
    }

    adminCommandService?.recordAuditLog(
      actorId: actorId,
      action: 'store.api_webhook_sync',
      targetId: 'store_products',
      notes: 'Synced $imported products via Warehouse API webhook',
    );

    return InventorySyncResult(
      source: StoreInventorySyncSource.supplierApi,
      importedCount: imported,
      skippedCount: skipped,
      errors: errors,
    );
  }

  /// Places a Stock-Up Supply Store order using the technician's
  /// **Pending Payout Balance** (`Available Store Credit = Unpaid Net Earnings - Open Store Orders`).
  StoreOrder placeTechStoreOrder({
    required String techId,
    required List<String> productIds,
    required String pargoPickupPointCode,
    required String idempotencyKey,
  }) {
    final cleanKey = InputSanitiser.sanitiseText(idempotencyKey, maxLength: 160);
    if (cleanKey.isEmpty) {
      throw ArgumentError('A non-empty idempotencyKey is required.');
    }
    final existingOrder = _ordersByIdempotencyKey[cleanKey];
    if (existingOrder != null) {
      return existingOrder;
    }

    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    final cleanPargo =
        InputSanitiser.sanitiseText(pargoPickupPointCode, maxLength: 64)
            .toUpperCase();
    if (cleanTechId.isEmpty) {
      throw ArgumentError('techId cannot be empty.');
    }
    if (!cleanPargo.startsWith('PARGO_')) {
      throw ArgumentError('Select a registered Pargo pickup point code.');
    }
    if (productIds.isEmpty) {
      throw ArgumentError('Select at least one product for your Stock-Up order.');
    }

    var totalZar = 0;
    final selectedProducts = <StoreProduct>[];
    for (final pid in productIds) {
      final prod = _products[pid];
      if (prod == null || !prod.isAvailable || prod.stockQuantity <= 0) {
        throw StateError('Product $pid is currently out of stock.');
      }
      totalZar += prod.priceZar;
      selectedProducts.add(prod);
    }

    final orderId = 'st_ord_${_orders.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    walletService.reserveStockUpStoreOrder(
      techId: cleanTechId,
      orderId: orderId,
      orderTotalCents: totalZar * 100,
      idempotencyKey: cleanKey,
    );

    for (final prod in selectedProducts) {
      final current = _products[prod.id]!;
      final nextStock = (current.stockQuantity - 1).clamp(0, 1000000);
      _products[prod.id] = StoreProduct(
        id: current.id,
        sku: current.sku,
        name: current.name,
        category: current.category,
        priceZar: current.priceZar,
        stockQuantity: nextStock,
        syncSource: current.syncSource,
        isAvailable: nextStock > 0,
      );
    }

    final order = StoreOrder(
      id: orderId,
      techUserId: cleanTechId,
      productIds: productIds,
      totalAmountZar: totalZar,
      status: StoreOrderFulfilmentStatus.pendingFulfilment.code,
      pargoPickupPointCode: cleanPargo,
    );
    _orders[order.id] = order;
    _ordersByIdempotencyKey[cleanKey] = order;
    return order;
  }

  /// Advances order fulfilment to Pargo 4-hour dispatch or collection.
  StoreOrder advanceOrderFulfilment({
    required String orderId,
    required StoreOrderFulfilmentStatus newStatus,
    required String actorId,
    required String actorUacGroup,
    bool actorIsActive = true,
  }) {
    final canFulfil = _hasAuthorisedPermission(
      actorId: actorId,
      actorUacGroup: actorUacGroup,
      actorIsActive: actorIsActive,
      permissionKey: AbePermissions.storeFulfilOrders,
    );
    if (!canFulfil) {
      throw StateError(
        'Access denied: actor $actorId lacks store.fulfil_orders permission.',
      );
    }

    final existing = _orders[orderId];
    if (existing == null) {
      throw StateError('StoreOrder $orderId not found.');
    }

    final currentStatus = StoreOrderFulfilmentStatus.fromCode(existing.status);
    final allowedNext = _allowedTransitions[currentStatus] ??
        const <StoreOrderFulfilmentStatus>{};
    if (!allowedNext.contains(newStatus)) {
      throw StateError(
        'Invalid fulfilment transition from ${currentStatus.code} to ${newStatus.code}.',
      );
    }

    final updated = StoreOrder(
      id: existing.id,
      techUserId: existing.techUserId,
      productIds: existing.productIds,
      totalAmountZar: existing.totalAmountZar,
      status: newStatus.code,
      pargoPickupPointCode: existing.pargoPickupPointCode,
    );
    _orders[updated.id] = updated;

    adminCommandService?.recordAuditLog(
      actorId: actorId,
      action: 'store.fulfil_order',
      targetId: updated.id,
      notes: 'Updated order ${updated.id} to ${newStatus.code}',
    );
    return updated;
  }

  static const Map<StoreOrderFulfilmentStatus, Set<StoreOrderFulfilmentStatus>>
      _allowedTransitions = <StoreOrderFulfilmentStatus,
          Set<StoreOrderFulfilmentStatus>>{
    StoreOrderFulfilmentStatus.pendingFulfilment: <StoreOrderFulfilmentStatus>{
      StoreOrderFulfilmentStatus.packed,
      StoreOrderFulfilmentStatus.pargoDispatched4h,
    },
    StoreOrderFulfilmentStatus.packed: <StoreOrderFulfilmentStatus>{
      StoreOrderFulfilmentStatus.pargoDispatched4h,
    },
    StoreOrderFulfilmentStatus.pargoDispatched4h: <StoreOrderFulfilmentStatus>{
      StoreOrderFulfilmentStatus.collected,
    },
    StoreOrderFulfilmentStatus.collected: <StoreOrderFulfilmentStatus>{},
  };

  bool _hasAuthorisedPermission({
    required String actorId,
    required String actorUacGroup,
    required bool actorIsActive,
    required String permissionKey,
  }) {
    if (adminCommandService != null) {
      return adminCommandService!.hasActivePermission(actorId, permissionKey);
    }
    if (actorUacGroup == AbeUacGroupId.superAdmin.code ||
        actorUacGroup == AbeUacGroupId.opsAdmin.code) {
      return false;
    }
    return uacMatrix.hasPermission(
      userId: actorId,
      uacGroupId: actorUacGroup,
      permissionKey: permissionKey,
      isActive: actorIsActive,
    );
  }

  void _requireInventoryPermission(
    String actorId,
    String actorUacGroup,
    bool actorIsActive,
  ) {
    final allowed = _hasAuthorisedPermission(
      actorId: actorId,
      actorUacGroup: actorUacGroup,
      actorIsActive: actorIsActive,
      permissionKey: AbePermissions.storeManageInventory,
    );
    if (!allowed) {
      throw StateError(
        'Access denied: actor $actorId lacks store.manage_inventory permission.',
      );
    }
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  static List<StoreProduct> _buildDefaultSeedProducts() {
    return <StoreProduct>[
      StoreProduct(
        id: 'prod_biab_rose',
        sku: 'ABE-BIAB-01',
        name: 'Alabaster Rose Builder Gel (15ml)',
        category: 'Gel & BIAB',
        priceZar: 240,
        stockQuantity: 36,
        syncSource: StoreInventorySyncSource.supplierApi,
      ),
      StoreProduct(
        id: 'prod_gelx_tips',
        sku: 'ABE-TIPS-02',
        name: 'Sculpted Almond Soft Gel Tips (500pc)',
        category: 'Extensions',
        priceZar: 310,
        stockQuantity: 22,
        syncSource: StoreInventorySyncSource.csvImport,
      ),
      StoreProduct(
        id: 'prod_chrome_champagne',
        sku: 'ABE-CHRM-03',
        name: 'Warm Champagne Mirror Chrome Powder',
        category: 'Nail Art',
        priceZar: 165,
        stockQuantity: 18,
        syncSource: StoreInventorySyncSource.adminManual,
      ),
    ];
  }
}
