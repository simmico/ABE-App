import '../../../../core/uac/uac_permission_matrix.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../../disputes/domain/models/dispute_and_audit_models.dart';
import '../../../wallet/domain/models/wallet_ledger_models.dart';
import '../../../wallet/domain/services/coupon_voucher_service.dart';
import '../../../wallet/domain/services/wallet_and_ledger_service.dart';

/// Staff / partner directory entry visible inside the Dynamic UAC Manager.
class StaffDirectoryMember {
  StaffDirectoryMember({
    required String userId,
    required String displayName,
    required String email,
    required String uacGroupId,
    required String city,
    this.isActive = true,
  })  : userId = InputSanitiser.sanitiseText(userId, maxLength: 128),
        displayName = InputSanitiser.sanitiseText(displayName, maxLength: 120),
        email = InputSanitiser.sanitiseText(email, maxLength: 160),
        uacGroupId = InputSanitiser.sanitiseText(uacGroupId, maxLength: 64),
        city = InputSanitiser.validateCityCode(city) {
    if (this.userId.isEmpty ||
        this.displayName.isEmpty ||
        this.uacGroupId.isEmpty) {
      throw ArgumentError('Staff userId, displayName, and uacGroupId are required.');
    }
    if (!this.email.contains('@') || !this.email.contains('.')) {
      throw ArgumentError('A valid staff email address is required.');
    }
  }

  final String userId;
  final String displayName;
  final String email;
  final String uacGroupId;
  final String city;
  final bool isActive;

  StaffDirectoryMember copyWith({
    String? uacGroupId,
    bool? isActive,
  }) {
    return StaffDirectoryMember(
      userId: userId,
      displayName: displayName,
      email: email,
      uacGroupId: uacGroupId ?? this.uacGroupId,
      city: city,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Metadata for a registered or custom UAC group.
class UacGroupMetadata {
  UacGroupMetadata({
    required String groupId,
    required String displayName,
    this.isCustom = false,
  })  : groupId = InputSanitiser.sanitiseText(groupId, maxLength: 64),
        displayName = InputSanitiser.sanitiseText(displayName, maxLength: 120) {
    if (this.groupId.isEmpty || this.displayName.isEmpty) {
      throw ArgumentError('UAC groupId and displayName cannot be empty.');
    }
  }

  final String groupId;
  final String displayName;
  final bool isCustom;
}

/// Executive telemetry snapshot for Rio & Aqeelah's Master Admin Command Centre.
class AdminTelemetrySnapshot {
  const AdminTelemetrySnapshot({
    required this.totalFloatCents,
    required this.totalGmvCents,
    required this.platformRevenueCents,
    required this.cptBookingsCount,
    required this.jhbBookingsCount,
    required this.chairTurnoverRate,
  });

  final int totalFloatCents;
  final int totalGmvCents;
  final int platformRevenueCents;
  final int cptBookingsCount;
  final int jhbBookingsCount;
  final double chairTurnoverRate;

  double get totalFloatZar => totalFloatCents / 100.0;
  double get totalGmvZar => totalGmvCents / 100.0;
  double get platformRevenueZar => platformRevenueCents / 100.0;
}

/// Orchestrates Rio & Aqeelah's Master Admin Command Centre:
/// - Telemetry & SARS CSV ledger exports
/// - Dynamic UAC Group creation, permission toggling, staff invites, and 1-click revocation
/// - Immutable [StaffAuditLog] tracking
/// - Promo Coupon & Voucher management
class AdminCommandService {
  AdminCommandService({
    required this.uacMatrix,
    required this.walletService,
    DateTime Function()? clock,
    List<StaffDirectoryMember>? initialStaff,
    this.cptBookingsCount = 42,
    this.jhbBookingsCount = 38,
    this.chairTurnoverRate = 3.4,
  }) : _clock = clock ?? DateTime.now {
    for (final g in AbeUacGroupId.values) {
      _groupDefinitions[g.code] = UacGroupMetadata(
        groupId: g.code,
        displayName: g.displayName,
      );
    }

    final seedStaff = initialStaff ??
        <StaffDirectoryMember>[
          StaffDirectoryMember(
            userId: 'admin_rio',
            displayName: 'Rio (Co-Founder)',
            email: 'rio@abe.co.za',
            uacGroupId: AbeUacGroupId.superAdmin.code,
            city: 'JHB',
          ),
          StaffDirectoryMember(
            userId: 'admin_aqeelah',
            displayName: 'Aqeelah (Co-Founder)',
            email: 'aqeelah@abe.co.za',
            uacGroupId: AbeUacGroupId.opsAdmin.code,
            city: 'CPT',
          ),
          StaffDirectoryMember(
            userId: 'staff_support_01',
            displayName: 'Zanele D.',
            email: 'zanele.support@abe.co.za',
            uacGroupId: AbeUacGroupId.supportAgent.code,
            city: 'CPT',
          ),
          StaffDirectoryMember(
            userId: 'supplier_cpt_01',
            displayName: 'Cape Nail Supply Hub',
            email: 'dispatch@capenailsupply.co.za',
            uacGroupId: AbeUacGroupId.supplierPartner.code,
            city: 'CPT',
          ),
        ];

    for (final member in seedStaff) {
      _staffDirectory[member.userId] = member;
      uacMatrix.assignUserGroup(member.userId, member.uacGroupId);
      uacMatrix.setUserActiveStatus(member.userId, isActive: member.isActive);
    }
  }

  final UacPermissionMatrix uacMatrix;
  final WalletAndLedgerService walletService;
  final DateTime Function() _clock;

  int cptBookingsCount;
  int jhbBookingsCount;
  double chairTurnoverRate;

  final Map<String, UacGroupMetadata> _groupDefinitions =
      <String, UacGroupMetadata>{};
  final Map<String, StaffDirectoryMember> _staffDirectory =
      <String, StaffDirectoryMember>{};
  final List<StaffAuditLog> _auditLogs = <StaffAuditLog>[];

  CouponVoucherService get voucherService => walletService.voucherService;

  List<UacGroupMetadata> get groups =>
      List<UacGroupMetadata>.unmodifiable(_groupDefinitions.values);

  List<StaffDirectoryMember> get staffMembers =>
      List<StaffDirectoryMember>.unmodifiable(_staffDirectory.values);

  List<StaffAuditLog> get auditLogs =>
      List<StaffAuditLog>.unmodifiable(_auditLogs);

  AdminTelemetrySnapshot buildTelemetrySnapshot() {
    final totalFloat = walletService.totalClientWalletFloatCents +
        walletService.totalPendingTechPayoutsCents;
    return AdminTelemetrySnapshot(
      totalFloatCents: totalFloat,
      totalGmvCents: walletService.totalGmvCents,
      platformRevenueCents: walletService.platformRevenueCents,
      cptBookingsCount: cptBookingsCount,
      jhbBookingsCount: jhbBookingsCount,
      chairTurnoverRate: chairTurnoverRate,
    );
  }

  bool hasActivePermission(String actorId, String permissionKey) =>
      _actorHasPermission(actorId, permissionKey);

  bool isStaffMember(String actorId) =>
      _staffDirectory[actorId]?.isActive == true;

  bool _actorHasPermission(String actorId, String permissionKey) {
    final actor = _staffDirectory[actorId];
    if (actor == null) return false;
    return uacMatrix.hasPermission(
      userId: actor.userId,
      uacGroupId: actor.uacGroupId,
      permissionKey: permissionKey,
      isActive: actor.isActive,
    );
  }

  void _requirePermission(String actorId, String permissionKey) {
    if (!_actorHasPermission(actorId, permissionKey)) {
      throw StateError(
        'Access denied: actor $actorId lacks active permission $permissionKey.',
      );
    }
  }

  void recordAuditLog({
    required String actorId,
    required String action,
    required String targetId,
    String notes = '',
  }) {
    final actor = _staffDirectory[actorId];
    if (actor == null || !actor.isActive) {
      throw StateError(
        'Access denied: only active registered staff may append audit logs.',
      );
    }
    final cleanAction = InputSanitiser.sanitiseText(action, maxLength: 80);
    final cleanTarget = InputSanitiser.sanitiseText(targetId, maxLength: 128);
    final cleanNotes = InputSanitiser.sanitiseText(notes, maxLength: 400);
    if (cleanAction.isEmpty || cleanTarget.isEmpty) {
      throw ArgumentError('Audit action and targetId cannot be empty.');
    }
    final now = _clock().toUtc();
    _auditLogs.add(
      StaffAuditLog(
        id: 'audit_${_auditLogs.length + 1}_${now.millisecondsSinceEpoch}',
        actorId: actor.userId,
        actorUacGroup: actor.uacGroupId,
        action: cleanAction,
        targetId: cleanTarget,
        timestampIso: now.toIso8601String(),
        notes: cleanNotes,
      ),
    );
  }

  /// Creates a custom UAC group dynamically and records an immutable [StaffAuditLog].
  UacGroupMetadata createCustomUacGroup({
    required String actorId,
    required String groupId,
    required String displayName,
    required Iterable<String> permissions,
  }) {
    _requirePermission(actorId, AbePermissions.uacManageRoles);

    final cleanId = InputSanitiser.sanitiseText(groupId, maxLength: 64)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    if (cleanId.isEmpty) {
      throw ArgumentError('Custom UAC groupId cannot be empty.');
    }

    final meta = UacGroupMetadata(
      groupId: cleanId,
      displayName: displayName,
      isCustom: true,
    );
    _groupDefinitions[cleanId] = meta;
    for (final perm in permissions) {
      if (AbePermissions.allKeys.contains(perm)) {
        uacMatrix.grantPermissionToGroup(cleanId, perm);
      }
    }

    recordAuditLog(
      actorId: actorId,
      action: 'uac.create_group',
      targetId: cleanId,
      notes: 'Created custom UAC group ${meta.displayName}',
    );
    return meta;
  }

  /// Toggles a granular permission on any UAC group and records an immutable [StaffAuditLog].
  void toggleGroupPermission({
    required String actorId,
    required String groupId,
    required String permissionKey,
    required bool enabled,
  }) {
    _requirePermission(actorId, AbePermissions.uacManageRoles);
    if (!_groupDefinitions.containsKey(groupId)) {
      throw ArgumentError.value(groupId, 'groupId', 'Unknown UAC group.');
    }
    if (!AbePermissions.allKeys.contains(permissionKey)) {
      throw ArgumentError.value(permissionKey, 'permissionKey', 'Unknown permission.');
    }
    if (!enabled &&
        groupId == AbeUacGroupId.superAdmin.code &&
        permissionKey == AbePermissions.uacManageRoles) {
      throw StateError(
        'Lockout protection: super_admin must retain uac.manage_roles permission.',
      );
    }

    if (enabled) {
      uacMatrix.grantPermissionToGroup(groupId, permissionKey);
    } else {
      uacMatrix.revokePermissionFromGroup(groupId, permissionKey);
    }

    recordAuditLog(
      actorId: actorId,
      action: enabled ? 'uac.grant_permission' : 'uac.revoke_permission',
      targetId: '$groupId:$permissionKey',
      notes: '${enabled ? 'Granted' : 'Revoked'} $permissionKey on $groupId',
    );
  }

  /// Invites a staff or partner member into a UAC group and logs the invite.
  StaffDirectoryMember inviteStaffMember({
    required String actorId,
    required String userId,
    required String displayName,
    required String email,
    required String uacGroupId,
    required String city,
  }) {
    _requirePermission(actorId, AbePermissions.uacManageRoles);
    if (!_groupDefinitions.containsKey(uacGroupId)) {
      throw ArgumentError.value(uacGroupId, 'uacGroupId', 'Unknown UAC group.');
    }

    final member = StaffDirectoryMember(
      userId: userId,
      displayName: displayName,
      email: email,
      uacGroupId: uacGroupId,
      city: city,
      isActive: true,
    );
    _staffDirectory[member.userId] = member;
    uacMatrix.assignUserGroup(member.userId, member.uacGroupId);
    uacMatrix.setUserActiveStatus(member.userId, isActive: true);

    recordAuditLog(
      actorId: actorId,
      action: 'uac.invite_staff',
      targetId: member.userId,
      notes: 'Invited ${member.displayName} to ${member.uacGroupId}',
    );
    return member;
  }

  /// 1-click instant access revocation for a staff/partner member.
  StaffDirectoryMember revokeStaffAccess({
    required String actorId,
    required String targetUserId,
    String reason = 'Revoked by Admin',
  }) {
    _requirePermission(actorId, AbePermissions.uacManageRoles);
    if (actorId == targetUserId) {
      throw StateError('Admins cannot revoke their own active session.');
    }
    final existing = _staffDirectory[targetUserId];
    if (existing == null) {
      throw StateError('Staff member $targetUserId not found.');
    }

    final updated = existing.copyWith(isActive: false);
    _staffDirectory[targetUserId] = updated;
    uacMatrix.setUserActiveStatus(targetUserId, isActive: false);

    recordAuditLog(
      actorId: actorId,
      action: 'uac.revoke_access',
      targetId: targetUserId,
      notes: reason,
    );
    return updated;
  }

  /// Exports the SARS / Accountant ledger CSV when actor holds `ledger.export`.
  String exportSarsLedgerCsv({required String actorId}) {
    _requirePermission(actorId, AbePermissions.ledgerExport);
    recordAuditLog(
      actorId: actorId,
      action: 'ledger.export_csv',
      targetId: 'financial_ledger',
      notes: 'Exported SARS/Accountant CSV ledger',
    );
    return walletService.exportLedgerCsv();
  }

  /// Creates or pauses a promo/voucher code (`vouchers.manage` required).
  PromoCouponRecord createCoupon({
    required String actorId,
    required PromoCouponRecord coupon,
  }) {
    _requirePermission(actorId, AbePermissions.vouchersManage);
    final saved = voucherService.createOrUpdateCoupon(coupon);
    recordAuditLog(
      actorId: actorId,
      action: 'voucher.create',
      targetId: saved.code,
      notes: 'Created coupon ${saved.code}',
    );
    return saved;
  }

  PromoCouponRecord toggleCouponActive({
    required String actorId,
    required String code,
    required bool isActive,
  }) {
    _requirePermission(actorId, AbePermissions.vouchersManage);
    final updated = voucherService.setCouponActive(code, isActive: isActive);
    recordAuditLog(
      actorId: actorId,
      action: isActive ? 'voucher.resume' : 'voucher.pause',
      targetId: updated.code,
      notes: '${isActive ? 'Resumed' : 'Paused'} coupon ${updated.code}',
    );
    return updated;
  }
}
