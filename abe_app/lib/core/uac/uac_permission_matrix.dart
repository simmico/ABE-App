import 'package:flutter/foundation.dart';

/// Canonical UAC (User Access Control) group identifiers across the ABE platform.
enum AbeUacGroupId {
  /// Rio: full system, architecture, UAC matrix, and financial ledger control.
  superAdmin('super_admin', 'Super Admin (Engineering & Finance)'),

  /// Aqeelah: brand quality, Certified Pro grading, disputes, and operations.
  opsAdmin('ops_admin', 'Operations & Brand Admin'),

  /// Dispute resolution and customer care staff.
  supportAgent('support_agent', 'Dispute & Support Agent'),

  /// Warehouse and B2B nail supply partner (Stock-Up Store).
  supplierPartner('supplier_partner', 'Warehouse Supplier Partner'),

  /// Independent commercial salon listing Empty Chair capacity.
  salonPartner('salon_partner', 'Commercial Salon Partner'),

  /// Independent nail technician operating from a verified studio or salon chair.
  tech('tech', 'Nail Technician'),

  /// Beauty marketplace client booking appointments.
  client('client', 'Client');

  const AbeUacGroupId(this.code, this.displayName);

  final String code;
  final String displayName;

  static AbeUacGroupId fromCode(String rawCode) {
    for (final group in AbeUacGroupId.values) {
      if (group.code == rawCode.trim()) {
        return group;
      }
    }
    return AbeUacGroupId.client;
  }
}

/// Granular permission keys enforced by the Dynamic UAC Engine and Firestore Rules.
abstract final class AbePermissions {
  static const String disputesView = 'disputes.view';
  static const String disputesResolve = 'disputes.resolve';
  static const String walletCreditClient = 'wallet.credit_client';
  static const String techsApprove = 'techs.approve';
  static const String techsAwardPro = 'techs.award_pro';
  static const String vouchersManage = 'vouchers.manage';
  static const String storeManageInventory = 'store.manage_inventory';
  static const String storeFulfilOrders = 'store.fulfil_orders';
  static const String uacManageRoles = 'uac.manage_roles';
  static const String ledgerExport = 'ledger.export';

  /// All registered administrative and partner permission keys.
  static const List<String> allKeys = <String>[
    disputesView,
    disputesResolve,
    walletCreditClient,
    techsApprove,
    techsAwardPro,
    vouchersManage,
    storeManageInventory,
    storeFulfilOrders,
    uacManageRoles,
    ledgerExport,
  ];
}

/// Dynamic UAC (User Access Control) and Permission Matrix Engine.
///
/// Allows permissions per UAC group and per user override to be inspected,
/// updated, assigned, or immediately revoked from the Admin Dashboard.
class UacPermissionMatrix extends ChangeNotifier {
  UacPermissionMatrix({
    Map<String, Set<String>>? initialGroupPermissions,
  }) : _groupPermissions = initialGroupPermissions != null
            ? initialGroupPermissions.map(
                (key, value) => MapEntry(key, Set<String>.from(value)),
              )
            : _buildDefaultMatrix();

  final Map<String, Set<String>> _groupPermissions;
  final Map<String, bool> _userActiveStatus = <String, bool>{};
  final Map<String, String> _userAssignedGroups = <String, String>{};
  final Map<String, Set<String>> _userExplicitGrants = <String, Set<String>>{};
  final Map<String, Set<String>> _userExplicitRevocations =
      <String, Set<String>>{};

  static Map<String, Set<String>> _buildDefaultMatrix() {
    return <String, Set<String>>{
      AbeUacGroupId.superAdmin.code: Set<String>.from(AbePermissions.allKeys),
      AbeUacGroupId.opsAdmin.code: <String>{
        AbePermissions.disputesView,
        AbePermissions.disputesResolve,
        AbePermissions.walletCreditClient,
        AbePermissions.techsApprove,
        AbePermissions.techsAwardPro,
        AbePermissions.vouchersManage,
        AbePermissions.storeManageInventory,
        AbePermissions.storeFulfilOrders,
      },
      AbeUacGroupId.supportAgent.code: <String>{
        AbePermissions.disputesView,
        AbePermissions.disputesResolve,
        AbePermissions.walletCreditClient,
      },
      AbeUacGroupId.supplierPartner.code: <String>{
        AbePermissions.storeManageInventory,
        AbePermissions.storeFulfilOrders,
      },
      AbeUacGroupId.salonPartner.code: <String>{},
      AbeUacGroupId.tech.code: <String>{},
      AbeUacGroupId.client.code: <String>{},
    };
  }

  /// Returns an unmodifiable view of the permissions assigned to [groupCode].
  Set<String> permissionsForGroup(String groupCode) {
    final perms = _groupPermissions[groupCode];
    if (perms == null) return const <String>{};
    return Set<String>.unmodifiable(perms);
  }

  /// Evaluates whether a user with [uacGroupId], [isActive], and optional
  /// [customPermissions] holds the specified [permissionKey].
  ///
  /// Enforces the instant-revocation security invariant: if [isActive] is false
  /// (or the user has been deactivated in the live matrix), all permission checks
  /// immediately return `false`.
  bool hasPermission({
    required String userId,
    required String uacGroupId,
    required String permissionKey,
    bool isActive = true,
    Iterable<String> customPermissions = const <String>[],
  }) {
    final liveActive = _userActiveStatus[userId] ?? isActive;
    if (!liveActive) {
      return false;
    }

    final revokedForUser = _userExplicitRevocations[userId];
    if (revokedForUser != null && revokedForUser.contains(permissionKey)) {
      return false;
    }

    final effectiveGroup = _userAssignedGroups[userId] ?? uacGroupId;
    final groupSet = _groupPermissions[effectiveGroup] ?? const <String>{};
    if (groupSet.contains(permissionKey)) {
      return true;
    }

    if (customPermissions.contains(permissionKey)) {
      return true;
    }

    final explicitGrants = _userExplicitGrants[userId];
    if (explicitGrants != null && explicitGrants.contains(permissionKey)) {
      return true;
    }

    return false;
  }

  /// Grants [permissionKey] to [groupCode] dynamically from the Admin Dashboard.
  void grantPermissionToGroup(String groupCode, String permissionKey) {
    final set = _groupPermissions.putIfAbsent(groupCode, () => <String>{});
    if (set.add(permissionKey)) {
      notifyListeners();
    }
  }

  /// Revokes [permissionKey] from [groupCode] dynamically from the Admin Dashboard.
  void revokePermissionFromGroup(String groupCode, String permissionKey) {
    final set = _groupPermissions[groupCode];
    if (set != null && set.remove(permissionKey)) {
      notifyListeners();
    }
  }

  /// Assigns a user to a new UAC group live.
  void assignUserGroup(String userId, String newGroupCode) {
    _userAssignedGroups[userId] = newGroupCode;
    notifyListeners();
  }

  /// Immediately activates or deactivates a user across the UAC matrix.
  void setUserActiveStatus(String userId, {required bool isActive}) {
    _userActiveStatus[userId] = isActive;
    notifyListeners();
  }

  /// Explicitly revokes a specific permission from an individual user.
  void revokePermissionForUser(String userId, String permissionKey) {
    _userExplicitGrants[userId]?.remove(permissionKey);
    _userExplicitRevocations
        .putIfAbsent(userId, () => <String>{})
        .add(permissionKey);
    notifyListeners();
  }
}
