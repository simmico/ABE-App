import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../../core/uac/uac_permission_matrix.dart';
import '../../domain/services/hybrid_inventory_and_store_service.dart';

/// Combined Stock-Up Storefront (for Nail Techs ordering via Pending Payout Balance)
/// and Warehouse Supplier Portal (CSV import, manual edits, API webhook sync,
/// and Pargo 4-hour dispatch tracking).
class StockUpStoreAndWarehouseScreen extends StatefulWidget {
  const StockUpStoreAndWarehouseScreen({
    super.key,
    required this.actorId,
    required this.actorUacGroup,
    required this.storeService,
    this.actorIsActive = true,
    this.initialShowWarehousePortal = false,
    this.onBack,
  });

  final String actorId;
  final String actorUacGroup;
  final HybridInventoryAndStoreService storeService;
  final bool actorIsActive;
  final bool initialShowWarehousePortal;
  final VoidCallback? onBack;

  @override
  State<StockUpStoreAndWarehouseScreen> createState() =>
      _StockUpStoreAndWarehouseScreenState();
}

class _StockUpStoreAndWarehouseScreenState
    extends State<StockUpStoreAndWarehouseScreen> {
  late bool _showWarehousePortal;
  final List<String> _cartProductIds = <String>[];
  String _pargoCode = 'PARGO_CPT_CLAREMONT_01';
  String? _statusMessage;
  bool _isError = false;
  int _orderSeq = 0;

  final TextEditingController _csvInputController = TextEditingController(
    text: 'sku,name,category,priceZar,stockQuantity\n'
        'ABE-TOP-09,Crystal Glass No-Wipe Top Coat,Gel & BIAB,185,30',
  );

  @override
  void initState() {
    super.initState();
    _showWarehousePortal = widget.initialShowWarehousePortal;
  }

  @override
  void dispose() {
    _csvInputController.dispose();
    super.dispose();
  }

  void _setFeedback(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _isError = isError;
    });
  }

  void _handlePlaceTechOrder() {
    if (_cartProductIds.isEmpty) {
      _setFeedback('Add at least one supply item to your order.', isError: true);
      return;
    }
    try {
      _orderSeq++;
      final order = widget.storeService.placeTechStoreOrder(
        techId: widget.actorId,
        productIds: List<String>.from(_cartProductIds),
        pargoPickupPointCode: _pargoCode,
        idempotencyKey:
            'store_ord_${widget.actorId}_${DateTime.now().microsecondsSinceEpoch}_$_orderSeq',
      );
      _cartProductIds.clear();
      _setFeedback(
        'Order ${order.id} placed (R${order.totalAmountZar}) via Pending Payout credit. Pargo pickup: ${order.pargoPickupPointCode}.',
      );
    } catch (e) {
      _setFeedback(
        'Order could not be placed: confirm Available Store Credit covers your basket.',
        isError: true,
      );
    }
  }

  void _handleCsvImport() {
    try {
      final result = widget.storeService.importInventoryFromCsv(
        csvContent: _csvInputController.text,
        actorId: widget.actorId,
        actorUacGroup: widget.actorUacGroup,
        actorIsActive: widget.actorIsActive,
      );
      _setFeedback(
        'CSV sync complete: ${result.importedCount} imported, ${result.skippedCount} skipped.',
      );
    } catch (_) {
      _setFeedback(
        'Access denied: store.manage_inventory permission required.',
        isError: true,
      );
    }
  }

  void _handleWebhookSyncSample() {
    try {
      final result = widget.storeService.syncFromWarehouseApiWebhook(
        itemsPayload: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'prod_api_lamp_01',
            'sku': 'ABE-LAMP-PRO',
            'name': 'Cordless Rose Gold UV/LED Cure Lamp',
            'category': 'Equipment',
            'priceZar': 890,
            'stockQuantity': 12,
            'isAvailable': true,
          },
        ],
        actorId: widget.actorId,
        actorUacGroup: widget.actorUacGroup,
        actorIsActive: widget.actorIsActive,
      );
      _setFeedback(
        'Warehouse API webhook synced ${result.importedCount} product(s).',
      );
    } catch (_) {
      _setFeedback(
        'Access denied: store.manage_inventory permission required.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canManageWarehouse = widget.storeService.uacMatrix.hasPermission(
          userId: widget.actorId,
          uacGroupId: widget.actorUacGroup,
          permissionKey: AbePermissions.storeManageInventory,
          isActive: widget.actorIsActive,
        ) ||
        widget.storeService.uacMatrix.hasPermission(
          userId: widget.actorId,
          uacGroupId: widget.actorUacGroup,
          permissionKey: AbePermissions.storeFulfilOrders,
          isActive: widget.actorIsActive,
        );

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('store_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Stock-Up Supply Store'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: <Widget>[
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('store_mode_tech'),
                  label: const Text('Tech Storefront'),
                  selected: !_showWarehousePortal,
                  onSelected: (_) =>
                      setState(() => _showWarehousePortal = false),
                ),
                ChoiceChip(
                  key: const Key('store_mode_warehouse'),
                  label: const Text('Warehouse Supplier Portal'),
                  selected: _showWarehousePortal,
                  onSelected: (_) =>
                      setState(() => _showWarehousePortal = true),
                ),
              ],
            ),
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('store_status_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError
                        ? BrandConfig.errorSoft
                        : BrandConfig.sageSoft,
                    borderRadius:
                        BorderRadius.circular(BrandConfig.inputRadius),
                    border: Border.all(
                      color: _isError
                          ? BrandConfig.errorTerracotta
                          : BrandConfig.sageSuccess,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandConfig.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_showWarehousePortal)
              _buildWarehousePortal(textTheme, canManageWarehouse)
            else
              _buildTechStorefront(textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTechStorefront(TextTheme textTheme) {
    final acct = widget.storeService.walletService.getTechAccount(widget.actorId);
    final products = widget.storeService.products;

    var basketTotalZar = 0;
    for (final id in _cartProductIds) {
      final match = products.where((p) => p.id == id);
      if (match.isNotEmpty) {
        basketTotalZar += match.first.priceZar;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BrandConfig.surfaceCard,
            borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
            border: Border.all(color: BrandConfig.champagne),
            boxShadow: BrandConfig.softCardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Available Store Credit', style: textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      'R${acct.availableStoreCreditZar.toStringAsFixed(2)}',
                      key: const Key('store_available_credit_text'),
                      style: textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Zero upfront cash needed',
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Studio Nail Supplies', style: textTheme.headlineMedium),
        const SizedBox(height: 10),
        for (final prod in products)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BrandConfig.surfaceCard,
              borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
              border: Border.all(color: BrandConfig.borderWarm),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(prod.name, style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${prod.category} • SKU ${prod.sku} • ${prod.stockQuantity} in stock',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('R${prod.priceZar}', style: textTheme.titleSmall),
                const SizedBox(width: 10),
                Semantics(
                  label: 'Add ${prod.name}',
                  button: true,
                  child: OutlinedButton(
                    key: Key('add_store_product_${prod.id}'),
                    onPressed: prod.isAvailable && prod.stockQuantity > 0
                        ? () => setState(() => _cartProductIds.add(prod.id))
                        : null,
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _pargoCode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Pargo Pickup Point'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(
              value: 'PARGO_CPT_CLAREMONT_01',
              child: Text('Pargo Claremont Clicks (CPT)'),
            ),
            DropdownMenuItem(
              value: 'PARGO_JHB_ROSEBANK_02',
              child: Text('Pargo Rosebank Mall Locker (JHB)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _pargoCode = val);
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('place_store_order_button'),
            onPressed: _cartProductIds.isNotEmpty ? _handlePlaceTechOrder : null,
            child: Text(
              'Order (${_cartProductIds.length} items • R$basketTotalZar) via Store Credit',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarehousePortal(TextTheme textTheme, bool canManage) {
    if (!canManage) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrandConfig.errorSoft,
          borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
          border: Border.all(color: BrandConfig.errorTerracotta),
        ),
        child: Text(
          'Access denied: supplier or inventory manager permissions are required.',
          key: const Key('warehouse_access_denied_text'),
          style: textTheme.titleMedium?.copyWith(
            color: BrandConfig.espresso,
          ),
        ),
      );
    }

    final orders = widget.storeService.orders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Hybrid Inventory Sync Adapter', style: textTheme.headlineMedium),
        const SizedBox(height: 10),
        TextField(
          key: const Key('warehouse_csv_input'),
          controller: _csvInputController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'CSV / Excel Inventory Import',
            helperText: 'Columns: sku,name,category,priceZar,stockQuantity',
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final csvBtn = ElevatedButton.icon(
              key: const Key('warehouse_csv_import_button'),
              onPressed: _handleCsvImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('1-Click CSV Import'),
            );
            final apiBtn = OutlinedButton.icon(
              key: const Key('warehouse_api_sync_button'),
              onPressed: _handleWebhookSyncSample,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sync Warehouse API'),
            );
            if (constraints.maxWidth < 440) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  csvBtn,
                  const SizedBox(height: 8),
                  apiBtn,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: csvBtn),
                const SizedBox(width: 10),
                Expanded(child: apiBtn),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text('Pargo 4-Hour Dispatch Queue', style: textTheme.headlineMedium),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          Text('No pending warehouse orders.', style: textTheme.bodyMedium)
        else
          for (final order in orders)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BrandConfig.surfaceCard,
                borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                border: Border.all(color: BrandConfig.borderWarm),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${order.id} • R${order.totalAmountZar}',
                          style: textTheme.titleSmall,
                        ),
                        Text(
                          '${StoreOrderFulfilmentStatus.fromCode(order.status).label} • ${order.pargoPickupPointCode}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (order.status !=
                          StoreOrderFulfilmentStatus.pargoDispatched4h.code &&
                      order.status !=
                          StoreOrderFulfilmentStatus.collected.code)
                    OutlinedButton(
                      key: Key('dispatch_pargo_${order.id}'),
                      onPressed: () {
                        try {
                          widget.storeService.advanceOrderFulfilment(
                            orderId: order.id,
                            newStatus:
                                StoreOrderFulfilmentStatus.pargoDispatched4h,
                            actorId: widget.actorId,
                            actorUacGroup: widget.actorUacGroup,
                            actorIsActive: widget.actorIsActive,
                          );
                          _setFeedback(
                            'Order ${order.id} marked for Pargo 4-hour dispatch.',
                          );
                        } catch (_) {
                          _setFeedback(
                            'Could not update dispatch status.',
                            isError: true,
                          );
                        }
                      },
                      child: const Text('Dispatch 4h'),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
