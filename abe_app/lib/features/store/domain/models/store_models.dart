import '../../../../core/utils/input_sanitiser.dart';

/// Discount and tech-cancellation voucher schema for ABE.
class VoucherCode {
  VoucherCode({
    required String id,
    required String code,
    required num discountAmountZar,
    required num minSpendZar,
    required num maxUses,
    num currentUses = 0,
    this.isActive = true,
    String issuedForReason = 'promotional',
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        code = InputSanitiser.sanitiseVoucherCode(code),
        discountAmountZar = InputSanitiser.requireNonNegativeInt(
          discountAmountZar,
          fieldName: 'discountAmountZar',
          strictlyPositive: true,
        ),
        minSpendZar = InputSanitiser.requireNonNegativeInt(
          minSpendZar,
          fieldName: 'minSpendZar',
        ),
        maxUses = InputSanitiser.requireNonNegativeInt(
          maxUses,
          fieldName: 'maxUses',
          strictlyPositive: true,
        ),
        currentUses = InputSanitiser.requireNonNegativeInt(
          currentUses,
          fieldName: 'currentUses',
        ),
        issuedForReason =
            InputSanitiser.sanitiseText(issuedForReason, maxLength: 120) {
    if (this.id.isEmpty) {
      throw ArgumentError('VoucherCode.id cannot be empty.');
    }
  }

  final String id;
  final String code;
  final int discountAmountZar;
  final int minSpendZar;
  final int maxUses;
  final int currentUses;
  final bool isActive;
  final String issuedForReason;

  bool get canRedeem => isActive && currentUses < maxUses;

  factory VoucherCode.fromJson(Map<String, dynamic> json) {
    return VoucherCode(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      discountAmountZar: (json['discountAmountZar'] as num?) ?? 0,
      minSpendZar: (json['minSpendZar'] as num?) ?? 0,
      maxUses: (json['maxUses'] as num?) ?? 1,
      currentUses: (json['currentUses'] as num?) ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      issuedForReason: (json['issuedForReason'] ?? 'promotional').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'discountAmountZar': discountAmountZar,
      'minSpendZar': minSpendZar,
      'maxUses': maxUses,
      'currentUses': currentUses,
      'isActive': isActive,
      'issuedForReason': issuedForReason,
    };
  }
}

/// Supported inventory synchronisation sources for the B2B Stock-Up Supply Store.
enum StoreInventorySyncSource {
  csvImport('csv_import'),
  adminManual('admin_manual'),
  supplierApi('supplier_api');

  const StoreInventorySyncSource(this.code);
  final String code;

  static StoreInventorySyncSource fromCode(String rawCode) {
    for (final source in StoreInventorySyncSource.values) {
      if (source.code == rawCode.trim()) {
        return source;
      }
    }
    return StoreInventorySyncSource.adminManual;
  }
}

/// B2B "Stock-Up" Supply Store product schema (supporting CSV, Admin, and Supplier API sync).
class StoreProduct {
  StoreProduct({
    required String id,
    required String sku,
    required String name,
    required String category,
    required num priceZar,
    required num stockQuantity,
    required this.syncSource,
    this.isAvailable = true,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        sku = InputSanitiser.sanitiseText(sku, maxLength: 80),
        name = InputSanitiser.sanitiseText(name, maxLength: 160),
        category = InputSanitiser.sanitiseText(category, maxLength: 80),
        priceZar = InputSanitiser.requireNonNegativeInt(
          priceZar,
          fieldName: 'priceZar',
          strictlyPositive: true,
        ),
        stockQuantity = InputSanitiser.requireNonNegativeInt(
          stockQuantity,
          fieldName: 'stockQuantity',
        ) {
    if (this.id.isEmpty || this.sku.isEmpty || this.name.isEmpty) {
      throw ArgumentError('StoreProduct id, sku, and name cannot be empty.');
    }
  }

  final String id;
  final String sku;
  final String name;
  final String category;
  final int priceZar;
  final int stockQuantity;
  final StoreInventorySyncSource syncSource;
  final bool isAvailable;

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      id: (json['id'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? 'Gel & BIAB').toString(),
      priceZar: (json['priceZar'] as num?) ?? 0,
      stockQuantity: (json['stockQuantity'] as num?) ?? 0,
      syncSource: StoreInventorySyncSource.fromCode(
        (json['syncSource'] ?? 'admin_manual').toString(),
      ),
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sku': sku,
      'name': name,
      'category': category,
      'priceZar': priceZar,
      'stockQuantity': stockQuantity,
      'syncSource': syncSource.code,
      'isAvailable': isAvailable,
    };
  }
}

/// Foundation schema for a Nail Technician's B2B Stock-Up Supply Store order.
class StoreOrder {
  StoreOrder({
    required String id,
    required String techUserId,
    required List<String> productIds,
    required num totalAmountZar,
    required String status,
    required String pargoPickupPointCode,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        techUserId = InputSanitiser.sanitiseText(techUserId, maxLength: 128),
        productIds = List<String>.unmodifiable(
          productIds
              .map((p) => InputSanitiser.sanitiseText(p, maxLength: 128))
              .where((p) => p.isNotEmpty),
        ),
        totalAmountZar = InputSanitiser.requireNonNegativeInt(
          totalAmountZar,
          fieldName: 'totalAmountZar',
          strictlyPositive: true,
        ),
        status = InputSanitiser.sanitiseText(status, maxLength: 40),
        pargoPickupPointCode =
            InputSanitiser.sanitiseText(pargoPickupPointCode, maxLength: 64) {
    if (this.id.isEmpty || this.techUserId.isEmpty || this.productIds.isEmpty) {
      throw ArgumentError(
        'StoreOrder requires a valid id, techUserId, and at least one productId.',
      );
    }
  }

  final String id;
  final String techUserId;
  final List<String> productIds;
  final int totalAmountZar;
  final String status;
  final String pargoPickupPointCode;

  factory StoreOrder.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['productIds'];
    final list = rawProducts is Iterable
        ? rawProducts.map((e) => e.toString()).toList()
        : const <String>[];

    return StoreOrder(
      id: (json['id'] ?? '').toString(),
      techUserId: (json['techUserId'] ?? '').toString(),
      productIds: list,
      totalAmountZar: (json['totalAmountZar'] as num?) ?? 0,
      status: (json['status'] ?? 'pending_fulfilment').toString(),
      pargoPickupPointCode: (json['pargoPickupPointCode'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'techUserId': techUserId,
      'productIds': productIds,
      'totalAmountZar': totalAmountZar,
      'status': status,
      'pargoPickupPointCode': pargoPickupPointCode,
    };
  }
}
