import 'dart:math';

import 'package:abe_app/core/uac/uac_permission_matrix.dart';
import 'package:abe_app/features/admin/domain/services/admin_command_service.dart';
import 'package:abe_app/features/booking/domain/services/appointment_start_lock_service.dart';
import 'package:abe_app/features/disputes/domain/services/dispute_resolution_service.dart';
import 'package:abe_app/features/salon_partner/domain/services/salon_partner_portal_service.dart';
import 'package:abe_app/features/store/domain/models/store_models.dart';
import 'package:abe_app/features/store/domain/services/hybrid_inventory_and_store_service.dart';
import 'package:abe_app/features/wallet/domain/services/wallet_and_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock {
  _MutableClock(this.now);
  DateTime now;
  DateTime call() => now;
}

class _ConfigurableBiometricAdapter implements BiometricVerificationAdapter {
  _ConfigurableBiometricAdapter({this.shouldPass = true});
  bool shouldPass;

  @override
  Future<bool> authenticateTech({
    required String techId,
    required String reason,
  }) async {
    return shouldPass && techId.trim().isNotEmpty;
  }
}

void main() {
  group('AdminCommandService & Dynamic UAC revocation (Stage 4B)', () {
    test(
      '1-click revokeStaffAccess immediately revokes UAC access and blocks Dispute and Store calls',
      () {
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService();
        final admin = AdminCommandService(uacMatrix: uac, walletService: wallet);
        final disputes = DisputeResolutionService(
          uacMatrix: uac,
          walletService: wallet,
          adminCommandService: admin,
        );
        final store = HybridInventoryAndStoreService(
          uacMatrix: uac,
          walletService: wallet,
          adminCommandService: admin,
        );

        // Seed a tech settlement and an order so supplier fulfilment can be tested.
        wallet.recordCompletedBookingSettlement(
          bookingId: 'bk_rev_1',
          techId: 'tech_cpt_rev',
          grossAmountCents: 100000,
          completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_rev_1.jpg',
          idempotencyKey: 'rev_settle_1',
        );
        final order = store.placeTechStoreOrder(
          techId: 'tech_cpt_rev',
          productIds: const <String>['prod_biab_rose'],
          pargoPickupPointCode: 'PARGO_CPT_01',
          idempotencyKey: 'rev_ord_1',
        );

        // Before revocation: staff_support_01 can view disputes and supplier_cpt_01 can sync inventory.
        expect(
          admin.hasActivePermission('staff_support_01', AbePermissions.disputesResolve),
          isTrue,
        );
        expect(
          disputes.getTicketsForStaff(
            actorId: 'staff_support_01',
            actorUacGroup: AbeUacGroupId.supportAgent.code,
          ),
          isNotEmpty,
        );
        expect(
          admin.hasActivePermission('supplier_cpt_01', AbePermissions.storeManageInventory),
          isTrue,
        );

        // Revoke support agent and supplier partner.
        final revokedSupport = admin.revokeStaffAccess(
          actorId: 'admin_rio',
          targetUserId: 'staff_support_01',
          reason: 'Shift ended',
        );
        final revokedSupplier = admin.revokeStaffAccess(
          actorId: 'admin_rio',
          targetUserId: 'supplier_cpt_01',
          reason: 'Warehouse rotation',
        );

        expect(revokedSupport.isActive, isFalse);
        expect(revokedSupplier.isActive, isFalse);
        expect(admin.isStaffMember('staff_support_01'), isFalse);
        expect(admin.isStaffMember('supplier_cpt_01'), isFalse);
        expect(
          admin.hasActivePermission('staff_support_01', AbePermissions.disputesView),
          isFalse,
        );
        expect(
          uac.hasPermission(
            userId: 'staff_support_01',
            uacGroupId: AbeUacGroupId.supportAgent.code,
            permissionKey: AbePermissions.disputesResolve,
            isActive: true,
          ),
          isFalse,
        );
        expect(
          uac.hasPermission(
            userId: 'supplier_cpt_01',
            uacGroupId: AbeUacGroupId.supplierPartner.code,
            permissionKey: AbePermissions.storeManageInventory,
            isActive: true,
          ),
          isFalse,
        );

        // Subsequent DisputeResolutionService calls are immediately blocked.
        expect(
          () => disputes.getTicketsForStaff(
            actorId: 'staff_support_01',
            actorUacGroup: AbeUacGroupId.supportAgent.code,
          ),
          throwsStateError,
        );
        expect(
          () => disputes.resolveCreditClientWallet(
            ticketId: 'disp_01',
            actorId: 'staff_support_01',
            actorUacGroup: AbeUacGroupId.supportAgent.code,
            idempotencyKey: 'disp_rev_credit',
          ),
          throwsStateError,
        );
        expect(
          () => disputes.resolveReleasePayoutToTech(
            ticketId: 'disp_02',
            actorId: 'staff_support_01',
            actorUacGroup: AbeUacGroupId.supportAgent.code,
            idempotencyKey: 'disp_rev_payout',
          ),
          throwsStateError,
        );

        // Subsequent HybridInventoryAndStoreService calls are immediately blocked.
        expect(
          () => store.importInventoryFromCsv(
            csvContent: 'sku,name,category,priceZar,stockQuantity\nABE-X,Test,Gel,100,5',
            actorId: 'supplier_cpt_01',
            actorUacGroup: AbeUacGroupId.supplierPartner.code,
          ),
          throwsStateError,
        );
        expect(
          () => store.upsertProductManual(
            product: StoreProduct(
              id: 'prod_manual_rev',
              sku: 'ABE-MAN-01',
              name: 'Manual Builder Gel',
              category: 'Gel & BIAB',
              priceZar: 180,
              stockQuantity: 10,
              syncSource: StoreInventorySyncSource.adminManual,
            ),
            actorId: 'supplier_cpt_01',
            actorUacGroup: AbeUacGroupId.supplierPartner.code,
          ),
          throwsStateError,
        );
        expect(
          () => store.syncFromWarehouseApiWebhook(
            itemsPayload: const <Map<String, dynamic>>[],
            actorId: 'supplier_cpt_01',
            actorUacGroup: AbeUacGroupId.supplierPartner.code,
          ),
          throwsStateError,
        );
        expect(
          () => store.advanceOrderFulfilment(
            orderId: order.id,
            newStatus: StoreOrderFulfilmentStatus.pargoDispatched4h,
            actorId: 'supplier_cpt_01',
            actorUacGroup: AbeUacGroupId.supplierPartner.code,
          ),
          throwsStateError,
        );
      },
    );

    test(
      'prevents admins from revoking themselves and protects super_admin from losing uac.manage_roles',
      () {
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService();
        final admin = AdminCommandService(uacMatrix: uac, walletService: wallet);

        expect(
          () => admin.revokeStaffAccess(
            actorId: 'admin_rio',
            targetUserId: 'admin_rio',
          ),
          throwsStateError,
        );
        expect(admin.isStaffMember('admin_rio'), isTrue);

        expect(
          () => admin.toggleGroupPermission(
            actorId: 'admin_rio',
            groupId: AbeUacGroupId.superAdmin.code,
            permissionKey: AbePermissions.uacManageRoles,
            enabled: false,
          ),
          throwsStateError,
        );
        expect(
          uac.permissionsForGroup(AbeUacGroupId.superAdmin.code),
          contains(AbePermissions.uacManageRoles),
        );

        // Unauthorised staff cannot revoke others or manage UAC groups.
        expect(
          () => admin.revokeStaffAccess(
            actorId: 'staff_support_01',
            targetUserId: 'supplier_cpt_01',
          ),
          throwsStateError,
        );
      },
    );
  });

  group('Immutable StaffAuditLog trail & unauthenticated rejection (Stage 4B)', () {
    test(
      'rejects unauthenticated or revoked recordAuditLog calls and records full immutable audit trail',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 12, 0));
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService(clock: clock.call);
        final admin = AdminCommandService(
          uacMatrix: uac,
          walletService: wallet,
          clock: clock.call,
        );
        final store = HybridInventoryAndStoreService(
          uacMatrix: uac,
          walletService: wallet,
          adminCommandService: admin,
        );

        // Unknown / unauthenticated caller cannot append audit logs.
        expect(
          () => admin.recordAuditLog(
            actorId: 'unregistered_attacker',
            action: 'uac.escalate',
            targetId: 'admin_rio',
          ),
          throwsStateError,
        );

        // Empty action or targetId rejected.
        expect(
          () => admin.recordAuditLog(
            actorId: 'admin_rio',
            action: '   ',
            targetId: 'target_1',
          ),
          throwsArgumentError,
        );

        // 1. Custom UAC group creation
        admin.createCustomUacGroup(
          actorId: 'admin_rio',
          groupId: 'finance_reviewer',
          displayName: 'Finance Reviewer',
          permissions: const <String>[AbePermissions.ledgerExport],
        );

        // 2. Permission toggling (grant then revoke)
        admin.toggleGroupPermission(
          actorId: 'admin_rio',
          groupId: 'finance_reviewer',
          permissionKey: AbePermissions.disputesView,
          enabled: true,
        );
        admin.toggleGroupPermission(
          actorId: 'admin_rio',
          groupId: 'finance_reviewer',
          permissionKey: AbePermissions.disputesView,
          enabled: false,
        );

        // 3. Invite staff member
        admin.inviteStaffMember(
          actorId: 'admin_rio',
          userId: 'staff_fin_01',
          displayName: 'Thabo M.',
          email: 'thabo@abe.co.za',
          uacGroupId: 'finance_reviewer',
          city: 'JHB',
        );

        // 4. Revoke access (afterwards revoked staff cannot call recordAuditLog)
        admin.revokeStaffAccess(
          actorId: 'admin_rio',
          targetUserId: 'staff_fin_01',
          reason: 'Audit complete',
        );
        expect(
          () => admin.recordAuditLog(
            actorId: 'staff_fin_01',
            action: 'ledger.export_csv',
            targetId: 'financial_ledger',
          ),
          throwsStateError,
        );

        // 5. SARS CSV export
        admin.exportSarsLedgerCsv(actorId: 'admin_rio');

        // 6. Pargo 4-hour dispatch update
        wallet.recordCompletedBookingSettlement(
          bookingId: 'bk_audit_store',
          techId: 'tech_jhb_audit',
          grossAmountCents: 100000,
          completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_audit_store.jpg',
          idempotencyKey: 'audit_settle_1',
        );
        final order = store.placeTechStoreOrder(
          techId: 'tech_jhb_audit',
          productIds: const <String>['prod_biab_rose'],
          pargoPickupPointCode: 'PARGO_JHB_SANDTON_01',
          idempotencyKey: 'audit_ord_1',
        );
        store.advanceOrderFulfilment(
          orderId: order.id,
          newStatus: StoreOrderFulfilmentStatus.pargoDispatched4h,
          actorId: 'supplier_cpt_01',
          actorUacGroup: AbeUacGroupId.supplierPartner.code,
        );

        final actions = admin.auditLogs.map((log) => log.action).toList();
        expect(
          actions,
          containsAllInOrder(<String>[
            'uac.create_group',
            'uac.grant_permission',
            'uac.revoke_permission',
            'uac.invite_staff',
            'uac.revoke_access',
            'ledger.export_csv',
            'store.fulfil_order',
          ]),
        );

        // auditLogs getter must be immutable.
        expect(() => (admin.auditLogs as List).clear(), throwsUnsupportedError);
      },
    );
  });

  group('AppointmentStartLockService edge cases (Stage 4B)', () {
    test(
      '5 wrong PIN attempts trigger 15-minute lockout, emit SupportSecurityAlert, and require fresh biometric check after expiry',
      () async {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 9, 0));
        final bioAdapter = _ConfigurableBiometricAdapter(shouldPass: true);
        final service = AppointmentStartLockService(
          secureRandom: Random(23),
          biometricAdapter: bioAdapter,
          clock: clock.call,
        );

        final pinView = service.generatePinForConfirmedBooking(
          bookingId: 'bk_lock_4b',
          clientId: 'client_anele',
          techId: 'tech_cpt_4b',
        );
        final wrongPin = pinView.pinCode == '0123' ? '4567' : '0123';

        expect(
          await service.verifyTechBiometric(
            bookingId: 'bk_lock_4b',
            techId: 'tech_cpt_4b',
          ),
          isTrue,
        );

        // Attempts 1 to 4 do not lock yet.
        for (var attempt = 1; attempt <= 4; attempt++) {
          final outcome = service.submitPinAndStartAppointment(
            bookingId: 'bk_lock_4b',
            techId: 'tech_cpt_4b',
            enteredPin: wrongPin,
          );
          expect(outcome.success, isFalse);
          expect(outcome.isLocked, isFalse);
          expect(outcome.remainingAttempts, equals(5 - attempt));
          expect(service.supportAlerts, isEmpty);
        }

        // 5th consecutive wrong attempt triggers 15-minute lockout and SupportSecurityAlert.
        final fifthOutcome = service.submitPinAndStartAppointment(
          bookingId: 'bk_lock_4b',
          techId: 'tech_cpt_4b',
          enteredPin: wrongPin,
        );
        expect(fifthOutcome.success, isFalse);
        expect(fifthOutcome.isLocked, isTrue);
        expect(fifthOutcome.remainingAttempts, equals(0));
        expect(fifthOutcome.supportAlertTriggered, isTrue);
        expect(
          fifthOutcome.lockedUntilUtc,
          equals(DateTime.utc(2026, 11, 14, 9, 15)),
        );
        expect(service.supportAlerts, hasLength(1));
        final alert = service.supportAlerts.single;
        expect(alert.alertType, equals('pin_lockout'));
        expect(alert.bookingId, equals('bk_lock_4b'));
        expect(alert.clientId, equals('client_anele'));
        expect(alert.techId, equals('tech_cpt_4b'));

        // Even the correct PIN is rejected while inside the 15-minute lockout window.
        clock.now = DateTime.utc(2026, 11, 14, 9, 10);
        final duringLock = service.submitPinAndStartAppointment(
          bookingId: 'bk_lock_4b',
          techId: 'tech_cpt_4b',
          enteredPin: pinView.pinCode,
        );
        expect(duringLock.success, isFalse);
        expect(duringLock.isLocked, isTrue);
        expect(service.statusForBooking('bk_lock_4b'), equals('confirmed'));

        // Advance clock past the 15-minute lockout expiry.
        clock.now = DateTime.utc(2026, 11, 14, 9, 15, 1);
        final statusAfterExpiry = service.getTechLockStatus(
          bookingId: 'bk_lock_4b',
          techId: 'tech_cpt_4b',
        );
        expect(statusAfterExpiry.isLocked, isFalse);
        expect(statusAfterExpiry.failedAttempts, equals(0));

        // First PIN attempt after lockout expiry clears biometricVerified and requires re-verification.
        final firstAfterExpiry = service.submitPinAndStartAppointment(
          bookingId: 'bk_lock_4b',
          techId: 'tech_cpt_4b',
          enteredPin: pinView.pinCode,
        );
        expect(firstAfterExpiry.success, isFalse);
        expect(firstAfterExpiry.isLocked, isFalse);
        expect(
          firstAfterExpiry.message,
          contains('Complete biometric verification again'),
        );

        // Subsequent attempt without re-running biometric verification is still blocked.
        final secondWithoutBio = service.submitPinAndStartAppointment(
          bookingId: 'bk_lock_4b',
          techId: 'tech_cpt_4b',
          enteredPin: pinView.pinCode,
        );
        expect(secondWithoutBio.success, isFalse);
        expect(
          secondWithoutBio.message,
          contains('Complete biometric verification before entering the client PIN'),
        );

        // Re-pass biometric verification, then enter correct PIN -> transitions to in_progress.
        expect(
          await service.verifyTechBiometric(
            bookingId: 'bk_lock_4b',
            techId: 'tech_cpt_4b',
          ),
          isTrue,
        );
        final unlockedStart = service.submitPinAndStartAppointment(
          bookingId: 'bk_lock_4b',
          techId: 'tech_cpt_4b',
          enteredPin: pinView.pinCode,
        );
        expect(unlockedStart.success, isTrue);
        expect(unlockedStart.bookingStatus, equals('in_progress'));
        expect(service.statusForBooking('bk_lock_4b'), equals('in_progress'));
      },
    );

    test(
      'rejects spoofed or unassigned tech IDs and empty or invalid IDs',
      () async {
        final service = AppointmentStartLockService(secureRandom: Random(11));

        expect(
          () => service.generatePinForConfirmedBooking(
            bookingId: '',
            clientId: 'client_1',
            techId: 'tech_1',
          ),
          throwsArgumentError,
        );
        expect(
          () => service.generatePinForConfirmedBooking(
            bookingId: 'bk_empty_client',
            clientId: '   ',
            techId: 'tech_1',
          ),
          throwsArgumentError,
        );
        expect(
          () => service.generatePinForConfirmedBooking(
            bookingId: 'bk_empty_tech',
            clientId: 'client_1',
            techId: '  ',
          ),
          throwsArgumentError,
        );

        final pinView = service.generatePinForConfirmedBooking(
          bookingId: 'bk_spoof_1',
          clientId: 'client_real',
          techId: 'tech_real',
        );

        // Re-generating with mismatched participants throws StateError.
        expect(
          () => service.generatePinForConfirmedBooking(
            bookingId: 'bk_spoof_1',
            clientId: 'client_real',
            techId: 'tech_imposter',
          ),
          throwsStateError,
        );

        // Unknown booking IDs throw StateError.
        expect(
          () => service.getTechLockStatus(
            bookingId: 'bk_unknown',
            techId: 'tech_real',
          ),
          throwsStateError,
        );

        // Spoofed/unassigned tech IDs are rejected across all tech methods.
        expect(
          () => service.getTechLockStatus(
            bookingId: 'bk_spoof_1',
            techId: 'tech_imposter',
          ),
          throwsStateError,
        );
        await expectLater(
          service.verifyTechBiometric(
            bookingId: 'bk_spoof_1',
            techId: 'tech_imposter',
          ),
          throwsStateError,
        );
        expect(
          () => service.submitPinAndStartAppointment(
            bookingId: 'bk_spoof_1',
            techId: 'tech_imposter',
            enteredPin: pinView.pinCode,
          ),
          throwsStateError,
        );
        expect(
          () => service.submitPinAndStartAppointment(
            bookingId: 'bk_spoof_1',
            techId: '',
            enteredPin: pinView.pinCode,
          ),
          throwsStateError,
        );

        // Malformed PIN does not start appointment and does not burn attempts.
        await service.verifyTechBiometric(
          bookingId: 'bk_spoof_1',
          techId: 'tech_real',
        );
        final malformed = service.submitPinAndStartAppointment(
          bookingId: 'bk_spoof_1',
          techId: 'tech_real',
          enteredPin: '12ab',
        );
        expect(malformed.success, isFalse);
        expect(malformed.remainingAttempts, equals(5));
      },
    );
  });

  group('SARS CSV Export formula-injection sanitisation (Stage 4B)', () {
    test(
      'WalletAndLedgerService.exportLedgerCsv and AdminCommandService.exportSarsLedgerCsv neutralise =, +, -, @ prefixes and quote cells safely',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 14, 30));
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService(clock: clock.call);
        final admin = AdminCommandService(
          uacMatrix: uac,
          walletService: wallet,
          clock: clock.call,
        );

        wallet.creditClientWallet(
          clientId: '=CMD("calc")',
          amountCents: 15000,
          idempotencyKey: '+SUM(A1:A2)',
          reason: 'Refund, "special" @mention',
          bookingId: '-1+1',
        );
        wallet.creditClientWallet(
          clientId: '@HYPERLINK("https://evil.example","click")',
          amountCents: 20000,
          idempotencyKey: 'idem_safe_2',
          reason: '=1+1 formula in description',
          bookingId: '+bk_plus',
        );

        final directCsv = wallet.exportLedgerCsv();
        final adminCsv = admin.exportSarsLedgerCsv(actorId: 'admin_rio');
        expect(adminCsv, equals(directCsv));

        final lines = directCsv
            .trim()
            .split('\n')
            .map((l) => l.trim())
            .toList();
        expect(lines, hasLength(3));
        expect(
          lines.first,
          equals(
            'id,createdAtIso,idempotencyKey,userId,entryType,direction,amountZar,bookingId,orderId,description',
          ),
        );

        // Row 1 checks '=', '+', '-', quotes, and commas.
        expect(lines[1], contains('"\'=CMD(""calc"")"'));
        expect(lines[1], contains('"\'+SUM(A1:A2)"'));
        expect(lines[1], contains('"\'-1+1"'));
        expect(lines[1], contains('"Refund, ""special"" @mention"'));

        // Row 2 checks '@' and '=' prefix neutralisation.
        expect(
          lines[2],
          contains('"\'@HYPERLINK(""https://evil.example"",""click"")"'),
        );
        expect(lines[2], contains('"\'+bk_plus"'));
        expect(lines[2], contains('"\'=1+1 formula in description"'));

        // Unauthorised staff cannot export SARS CSV.
        expect(
          () => admin.exportSarsLedgerCsv(actorId: 'staff_support_01'),
          throwsStateError,
        );
      },
    );
  });

  group('HybridInventoryAndStoreService edge cases (Stage 4B)', () {
    test(
      'CSV import reports skipped malformed rows and rejects empty SKU or name',
      () {
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService();
        final store = HybridInventoryAndStoreService(
          uacMatrix: uac,
          walletService: wallet,
        );

        const csv = '''
sku,name,category,priceZar,stockQuantity
ABE-VALID-10,Rose Quartz Top Coat,Gel & BIAB,195,12
MALFORMED-FEW-COLS,Only Two Columns
,Missing SKU Product,Gel & BIAB,150,5
ABE-NO-NAME,,Gel & BIAB,150,5
ABE-BAD-PRICE,Bad Price Gel,Gel & BIAB,not_a_number,5
ABE-ZERO-PRICE,Zero Price Gel,Gel & BIAB,0,5
''';

        final result = store.importInventoryFromCsv(
          csvContent: csv,
          actorId: 'supplier_cpt_01',
          actorUacGroup: AbeUacGroupId.supplierPartner.code,
        );

        expect(result.source, equals(StoreInventorySyncSource.csvImport));
        expect(result.importedCount, equals(1));
        expect(result.skippedCount, equals(5));
        expect(result.errors, hasLength(5));
        expect(
          store.products.any((p) => p.sku == 'ABE-VALID-10' && p.priceZar == 195),
          isTrue,
        );
      },
    );

    test(
      'Webhook API sync ingests valid JSON payload and reports invalid items',
      () {
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService();
        final store = HybridInventoryAndStoreService(
          uacMatrix: uac,
          walletService: wallet,
        );

        final result = store.syncFromWarehouseApiWebhook(
          itemsPayload: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'prod_api_01',
              'sku': 'ABE-API-01',
              'name': 'Velvet Matte Top Gel',
              'category': 'Gel & BIAB',
              'priceZar': 225,
              'stockQuantity': 30,
            },
            <String, dynamic>{
              'id': 'prod_api_bad',
              'sku': '',
              'name': 'Missing SKU',
              'priceZar': 100,
              'stockQuantity': 5,
            },
          ],
          actorId: 'supplier_cpt_01',
          actorUacGroup: AbeUacGroupId.supplierPartner.code,
        );

        expect(result.source, equals(StoreInventorySyncSource.supplierApi));
        expect(result.importedCount, equals(1));
        expect(result.skippedCount, equals(1));
        expect(result.errors, hasLength(1));
        final synced = store.products.firstWhere((p) => p.id == 'prod_api_01');
        expect(synced.syncSource, equals(StoreInventorySyncSource.supplierApi));
        expect(synced.stockQuantity, equals(30));
      },
    );

    test(
      'idempotent placeTechStoreOrder retry returns existing order without double-decrementing stock',
      () {
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService();
        wallet.recordCompletedBookingSettlement(
          bookingId: 'bk_store_idem',
          techId: 'tech_jhb_store',
          grossAmountCents: 200000, // R1700 net credit
          completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_store_idem.jpg',
          idempotencyKey: 'settle_store_idem',
        );
        final store = HybridInventoryAndStoreService(
          uacMatrix: uac,
          walletService: wallet,
        );

        final initialStock = store.products
            .firstWhere((p) => p.id == 'prod_biab_rose')
            .stockQuantity;

        final firstOrder = store.placeTechStoreOrder(
          techId: 'tech_jhb_store',
          productIds: const <String>['prod_biab_rose'],
          pargoPickupPointCode: 'PARGO_JHB_ROSEBANK_01',
          idempotencyKey: 'idem_store_order_1',
        );

        final retryOrder = store.placeTechStoreOrder(
          techId: 'tech_jhb_store',
          productIds: const <String>['prod_biab_rose'],
          pargoPickupPointCode: 'PARGO_JHB_ROSEBANK_01',
          idempotencyKey: 'idem_store_order_1',
        );

        expect(retryOrder.id, equals(firstOrder.id));
        expect(store.orders, hasLength(1));
        final afterStock = store.products
            .firstWhere((p) => p.id == 'prod_biab_rose')
            .stockQuantity;
        expect(afterStock, equals(initialStock - 1));
        expect(
          wallet.getTechAccount('tech_jhb_store').openStoreOrdersCents,
          equals(24000),
        );
      },
    );

    test(
      'advanceOrderFulfilment enforces forward-only Pargo 4-hour dispatch transitions',
      () {
        final uac = UacPermissionMatrix();
        final wallet = WalletAndLedgerService();
        wallet.recordCompletedBookingSettlement(
          bookingId: 'bk_pargo_1',
          techId: 'tech_cpt_pargo',
          grossAmountCents: 100000,
          completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_pargo_1.jpg',
          idempotencyKey: 'settle_pargo_1',
        );
        final store = HybridInventoryAndStoreService(
          uacMatrix: uac,
          walletService: wallet,
        );

        final order = store.placeTechStoreOrder(
          techId: 'tech_cpt_pargo',
          productIds: const <String>['prod_chrome_champagne'],
          pargoPickupPointCode: 'PARGO_CPT_SEAPOINT_02',
          idempotencyKey: 'ord_pargo_1',
        );
        expect(order.status, equals('pending_fulfilment'));

        // Cannot skip straight from pending_fulfilment to collected.
        expect(
          () => store.advanceOrderFulfilment(
            orderId: order.id,
            newStatus: StoreOrderFulfilmentStatus.collected,
            actorId: 'supplier_cpt_01',
            actorUacGroup: AbeUacGroupId.supplierPartner.code,
          ),
          throwsStateError,
        );

        // Forward: pending_fulfilment -> pargo_dispatched_4h.
        final dispatched = store.advanceOrderFulfilment(
          orderId: order.id,
          newStatus: StoreOrderFulfilmentStatus.pargoDispatched4h,
          actorId: 'supplier_cpt_01',
          actorUacGroup: AbeUacGroupId.supplierPartner.code,
        );
        expect(dispatched.status, equals('pargo_dispatched_4h'));

        // Reject backward transitions from pargo_dispatched_4h.
        expect(
          () => store.advanceOrderFulfilment(
            orderId: order.id,
            newStatus: StoreOrderFulfilmentStatus.packed,
            actorId: 'supplier_cpt_01',
            actorUacGroup: AbeUacGroupId.supplierPartner.code,
          ),
          throwsStateError,
        );
        expect(
          () => store.advanceOrderFulfilment(
            orderId: order.id,
            newStatus: StoreOrderFulfilmentStatus.pendingFulfilment,
            actorId: 'supplier_cpt_01',
            actorUacGroup: AbeUacGroupId.supplierPartner.code,
          ),
          throwsStateError,
        );

        // Forward: pargo_dispatched_4h -> collected.
        final collected = store.advanceOrderFulfilment(
          orderId: order.id,
          newStatus: StoreOrderFulfilmentStatus.collected,
          actorId: 'supplier_cpt_01',
          actorUacGroup: AbeUacGroupId.supplierPartner.code,
        );
        expect(collected.status, equals('collected'));

        // Reject any post-collected transitions.
        for (final nextStatus in StoreOrderFulfilmentStatus.values) {
          expect(
            () => store.advanceOrderFulfilment(
              orderId: order.id,
              newStatus: nextStatus,
              actorId: 'supplier_cpt_01',
              actorUacGroup: AbeUacGroupId.supplierPartner.code,
            ),
            throwsStateError,
          );
        }
      },
    );
  });

  group('SalonPartnerPortalService Strict Commercial Venue validation (Stage 4B)', () {
    test(
      'rejects residential or house-call addresses, empty names or windows, and zero or negative chair fees',
      () {
        final portal = SalonPartnerPortalService();

        const forbiddenAddresses = <String>[
          '12 Oak Avenue, Residential Estate, Cape Town',
          'House call service in Sandton',
          'Home visit studio in Sea Point',
          'Client home near Rosebank',
          'Private residence, 44 Kloof Street',
          '   ',
        ];

        for (final badAddress in forbiddenAddresses) {
          expect(
            () => portal.publishEmptyChairSlot(
              slotId: 'chair_bad_addr',
              venueId: 'venue_bad',
              venueName: 'Studio Test',
              city: 'CPT',
              suburb: 'Sea Point',
              address: badAddress,
              chairFeeZar: 150,
              windowLabel: 'Mon 09:00 to 13:00',
            ),
            throwsArgumentError,
          );
        }

        // Empty venue name, suburb, or windowLabel.
        expect(
          () => portal.publishEmptyChairSlot(
            slotId: 'chair_no_name',
            venueId: 'venue_1',
            venueName: '   ',
            city: 'CPT',
            suburb: 'Claremont',
            address: '22 Main Road, Claremont, Cape Town',
            chairFeeZar: 150,
            windowLabel: 'Tue 09:00 to 12:00',
          ),
          throwsArgumentError,
        );
        expect(
          () => portal.publishEmptyChairSlot(
            slotId: 'chair_no_suburb',
            venueId: 'venue_1',
            venueName: 'Rosewood Nail Lounge',
            city: 'CPT',
            suburb: '',
            address: '22 Main Road, Claremont, Cape Town',
            chairFeeZar: 150,
            windowLabel: 'Tue 09:00 to 12:00',
          ),
          throwsArgumentError,
        );
        expect(
          () => portal.publishEmptyChairSlot(
            slotId: 'chair_no_window',
            venueId: 'venue_1',
            venueName: 'Rosewood Nail Lounge',
            city: 'CPT',
            suburb: 'Claremont',
            address: '22 Main Road, Claremont, Cape Town',
            chairFeeZar: 150,
            windowLabel: '  ',
          ),
          throwsArgumentError,
        );

        // Zero and negative chair fees.
        expect(
          () => portal.publishEmptyChairSlot(
            slotId: 'chair_zero_fee',
            venueId: 'venue_1',
            venueName: 'Rosewood Nail Lounge',
            city: 'JHB',
            suburb: 'Sandton',
            address: '88 Maude Street, Sandton, Johannesburg',
            chairFeeZar: 0,
            windowLabel: 'Wed 10:00 to 14:00',
          ),
          throwsArgumentError,
        );
        expect(
          () => portal.publishEmptyChairSlot(
            slotId: 'chair_neg_fee',
            venueId: 'venue_1',
            venueName: 'Rosewood Nail Lounge',
            city: 'JHB',
            suburb: 'Sandton',
            address: '88 Maude Street, Sandton, Johannesburg',
            chairFeeZar: -50,
            windowLabel: 'Wed 10:00 to 14:00',
          ),
          throwsArgumentError,
        );

        // Valid commercial venue succeeds.
        final published = portal.publishEmptyChairSlot(
          slotId: 'chair_jhb_sandton_valid',
          venueId: 'venue_jhb_sandton_09',
          venueName: 'Rosewood Nail Lounge',
          city: 'JHB',
          suburb: 'Sandton',
          address: '88 Maude Street, Sandton, Johannesburg',
          chairFeeZar: 160,
          windowLabel: 'Wed 10:00 to 14:00',
        );
        expect(published.city, equals('JHB'));
        expect(published.chairFeeZar, equals(160));
        expect(published.isAvailable, isTrue);
      },
    );
  });
}
