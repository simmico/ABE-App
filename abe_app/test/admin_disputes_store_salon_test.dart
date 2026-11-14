import 'package:abe_app/core/uac/uac_permission_matrix.dart';
import 'package:abe_app/features/admin/domain/services/admin_command_service.dart';
import 'package:abe_app/features/admin/presentation/screens/master_admin_command_centre_screen.dart';
import 'package:abe_app/features/disputes/domain/services/dispute_resolution_service.dart';
import 'package:abe_app/features/disputes/presentation/screens/dispute_support_queue_screen.dart';
import 'package:abe_app/features/salon_partner/domain/services/salon_partner_portal_service.dart';
import 'package:abe_app/features/salon_partner/presentation/screens/salon_partner_portal_screen.dart';
import 'package:abe_app/features/store/domain/models/store_models.dart';
import 'package:abe_app/features/store/domain/services/hybrid_inventory_and_store_service.dart';
import 'package:abe_app/features/store/presentation/screens/stock_up_store_and_warehouse_screen.dart';
import 'package:abe_app/features/wallet/domain/services/wallet_and_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('AdminCommandService & Dynamic UAC (Item 15.1)', () {
    test('manages custom UAC groups, 1-click revocation, immutable StaffAuditLog, and SARS CSV export', () {
      final uac = UacPermissionMatrix();
      final wallet = WalletAndLedgerService();
      wallet.recordCompletedBookingSettlement(
        bookingId: 'bk_adm_1',
        techId: 'tech_cpt_1',
        grossAmountCents: 100000,
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_adm_1.jpg',
        idempotencyKey: 'adm_settle_1',
      );
      final admin = AdminCommandService(uacMatrix: uac, walletService: wallet);

      final custom = admin.createCustomUacGroup(
        actorId: 'admin_rio',
        groupId: 'auditor_readonly',
        displayName: 'Read-Only Auditor',
        permissions: const <String>[AbePermissions.ledgerExport],
      );
      expect(custom.groupId, equals('auditor_readonly'));

      final invited = admin.inviteStaffMember(
        actorId: 'admin_rio',
        userId: 'staff_auditor_1',
        displayName: 'Sam Auditor',
        email: 'sam@abe.co.za',
        uacGroupId: 'auditor_readonly',
        city: 'JHB',
      );
      expect(
        uac.hasPermission(
          userId: invited.userId,
          uacGroupId: invited.uacGroupId,
          permissionKey: AbePermissions.ledgerExport,
        ),
        isTrue,
      );

      // 1-click revocation immediately blocks permission checks and writes StaffAuditLog.
      admin.revokeStaffAccess(
        actorId: 'admin_rio',
        targetUserId: 'staff_auditor_1',
        reason: 'Contract ended',
      );
      expect(
        uac.hasPermission(
          userId: 'staff_auditor_1',
          uacGroupId: 'auditor_readonly',
          permissionKey: AbePermissions.ledgerExport,
          isActive: true,
        ),
        isFalse,
      );

      final csv = admin.exportSarsLedgerCsv(actorId: 'admin_rio');
      expect(csv, contains('15% platform fee on completed booking bk_adm_1'));
      expect(admin.auditLogs.any((l) => l.action == 'uac.revoke_access'), isTrue);
      expect(admin.auditLogs.any((l) => l.action == 'ledger.export_csv'), isTrue);
    });

    testWidgets('MasterAdminCommandCentreScreen switches Telemetry, UAC, and Vouchers', (tester) async {
      final uac = UacPermissionMatrix();
      final wallet = WalletAndLedgerService();
      wallet.recordCompletedBookingSettlement(
        bookingId: 'bk_ui_adm',
        techId: 'tech_ui',
        grossAmountCents: 100000,
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_ui_adm.jpg',
        idempotencyKey: 'ui_adm_1',
      );
      final admin = AdminCommandService(uacMatrix: uac, walletService: wallet);

      await tester.pumpWidget(
        MaterialApp(
          home: MasterAdminCommandCentreScreen(
            actorId: 'admin_rio',
            adminService: admin,
          ),
        ),
      );

      expect(find.text('R1000.00'), findsOneWidget); // GMV
      expect(find.text('R150.00'), findsOneWidget); // 15% Revenue

      final exportBtn = find.byKey(const Key('admin_export_csv_button'));
      await tester.ensureVisible(exportBtn);
      await tester.pumpAndSettle();
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin_csv_preview_box')), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_tab_uac')));
      await tester.pumpAndSettle();
      expect(find.text('Rio (Co-Founder)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_tab_vouchers')));
      await tester.pumpAndSettle();
      expect(find.text('R1_EVENT'), findsOneWidget);
    });
  });

  group('DisputeSupportQueueScreen & DisputeResolutionService (Item 15.2)', () {
    testWidgets('shows 3 photos side-by-side and resolves dispute to client wallet', (tester) async {
      final uac = UacPermissionMatrix();
      final wallet = WalletAndLedgerService();
      final admin = AdminCommandService(uacMatrix: uac, walletService: wallet);
      final disputes = DisputeResolutionService(
        uacMatrix: uac,
        walletService: wallet,
        adminCommandService: admin,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DisputeSupportQueueScreen(
            actorId: 'staff_support_01',
            actorUacGroup: AbeUacGroupId.supportAgent.code,
            disputeService: disputes,
          ),
        ),
      );

      expect(find.text('1. Booked Contract'), findsWidgets);
      expect(find.text('2. Live Camera Proof'), findsWidgets);
      expect(find.text('3. Client Dispute'), findsWidgets);

      final refundBtn = find.byKey(const Key('dispute_refund_client_disp_01'));
      await tester.ensureVisible(refundBtn);
      await tester.pumpAndSettle();
      await tester.tap(refundBtn);
      await tester.pumpAndSettle();

      expect(wallet.getClientWallet('client_naledi').balanceCents, equals(45000));
      expect(
        admin.auditLogs.any((l) => l.action == 'dispute.resolve_refund_client'),
        isTrue,
      );
    });
  });

  group('Stock-Up Store, Warehouse Portal & Salon Portal (Item 15.3)', () {
    test('HybridInventoryAndStoreService imports CSV, syncs API, places credit order, and dispatches Pargo 4h', () {
      final uac = UacPermissionMatrix();
      final wallet = WalletAndLedgerService();
      wallet.recordCompletedBookingSettlement(
        bookingId: 'bk_st_1',
        techId: 'tech_cpt_store',
        grossAmountCents: 100000, // R850 net credit
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_st_1.jpg',
        idempotencyKey: 'st_settle_1',
      );
      final store = HybridInventoryAndStoreService(
        uacMatrix: uac,
        walletService: wallet,
      );

      final csvResult = store.importInventoryFromCsv(
        csvContent:
            'sku,name,category,priceZar,stockQuantity\n'
            'ABE-GEL-99,Milky Sheer Builder,Gel & BIAB,210,15',
        actorId: 'supplier_cpt_01',
        actorUacGroup: AbeUacGroupId.supplierPartner.code,
      );
      expect(csvResult.importedCount, equals(1));
      expect(
        store.products.any((p) => p.sku == 'ABE-GEL-99' && p.syncSource == StoreInventorySyncSource.csvImport),
        isTrue,
      );

      final order = store.placeTechStoreOrder(
        techId: 'tech_cpt_store',
        productIds: const <String>['prod_abe_gel_99'],
        pargoPickupPointCode: 'PARGO_CPT_CLAREMONT_01',
        idempotencyKey: 'ord_tech_1',
      );
      expect(order.totalAmountZar, equals(210));
      expect(
        wallet.getTechAccount('tech_cpt_store').availableStoreCreditCents,
        equals(64000), // R850 - R210 = R640
      );

      final dispatched = store.advanceOrderFulfilment(
        orderId: order.id,
        newStatus: StoreOrderFulfilmentStatus.pargoDispatched4h,
        actorId: 'supplier_cpt_01',
        actorUacGroup: AbeUacGroupId.supplierPartner.code,
      );
      expect(dispatched.status, equals('pargo_dispatched_4h'));
    });

    testWidgets('StockUpStoreAndWarehouseScreen & SalonPartnerPortalScreen render and mutate state', (tester) async {
      final uac = UacPermissionMatrix();
      final wallet = WalletAndLedgerService();
      wallet.recordCompletedBookingSettlement(
        bookingId: 'bk_st_ui',
        techId: 'tech_ui',
        grossAmountCents: 100000, // R850 net
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_st_ui.jpg',
        idempotencyKey: 'st_ui_1',
      );
      final store = HybridInventoryAndStoreService(
        uacMatrix: uac,
        walletService: wallet,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StockUpStoreAndWarehouseScreen(
            actorId: 'tech_ui',
            actorUacGroup: AbeUacGroupId.tech.code,
            storeService: store,
          ),
        ),
      );

      expect(find.text('R850.00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add_store_product_prod_biab_rose')));
      await tester.pumpAndSettle();

      final orderBtn = find.byKey(const Key('place_store_order_button'));
      await tester.ensureVisible(orderBtn);
      await tester.pumpAndSettle();
      await tester.tap(orderBtn);
      await tester.pumpAndSettle();
      expect(find.text('R610.00'), findsOneWidget); // 850 - 240

      final salonService = SalonPartnerPortalService();
      await tester.pumpWidget(
        MaterialApp(
          home: SalonPartnerPortalScreen(portalService: salonService),
        ),
      );
      expect(find.text('R900'), findsOneWidget); // (4*120) + (3*140)
      await tester.enterText(
        find.byKey(const Key('salon_name_input')),
        'The Velvet Nail Bar',
      );
      final publishBtn = find.byKey(const Key('salon_publish_chair_button'));
      await tester.ensureVisible(publishBtn);
      await tester.pumpAndSettle();
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(find.textContaining('The Velvet Nail Bar'), findsWidgets);
    });
  });
}
