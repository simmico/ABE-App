import '../../../../core/uac/uac_permission_matrix.dart';
import '../../../../core/utils/input_sanitiser.dart';

/// Represents a Dynamic User Access Control (UAC) Group in ABE.
class UacGroup {
  UacGroup({
    required String id,
    required String name,
    required List<String> permissions,
    this.isActive = true,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 64),
        name = InputSanitiser.sanitiseText(name, maxLength: 120),
        permissions = List<String>.unmodifiable(
          permissions
              .map((p) => InputSanitiser.sanitiseText(p, maxLength: 80))
              .where((p) => p.isNotEmpty),
        ) {
    if (this.id.isEmpty) {
      throw ArgumentError('UacGroup.id cannot be empty.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError('UacGroup.name cannot be empty.');
    }
  }

  final String id;
  final String name;
  final List<String> permissions;
  final bool isActive;

  bool hasPermission(String permissionKey) {
    if (!isActive) return false;
    return permissions.contains(permissionKey);
  }

  factory UacGroup.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'];
    final permList = rawPerms is Iterable
        ? rawPerms.map((e) => e.toString()).toList()
        : const <String>[];

    return UacGroup(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      permissions: permList,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'permissions': permissions,
      'isActive': isActive,
    };
  }
}

/// Core domain model for an authenticated user in Aqeelah's Beauty Empire (ABE).
class AbeUser {
  AbeUser({
    required String id,
    required String name,
    required String email,
    required String uacGroupId,
    required String city,
    List<String> permissions = const <String>[],
    this.isActive = true,
    num walletBalanceZar = 0,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        name = InputSanitiser.sanitiseText(name, maxLength: 120),
        email = InputSanitiser.sanitiseText(email, maxLength: 160),
        uacGroupId = InputSanitiser.sanitiseText(uacGroupId, maxLength: 64),
        city = InputSanitiser.validateCityCode(city),
        permissions = List<String>.unmodifiable(
          permissions
              .map((p) => InputSanitiser.sanitiseText(p, maxLength: 80))
              .where((p) => p.isNotEmpty),
        ),
        walletBalanceZar = InputSanitiser.requireNonNegativeDouble(
          walletBalanceZar,
          fieldName: 'walletBalanceZar',
        ) {
    if (this.id.isEmpty) {
      throw ArgumentError('AbeUser.id cannot be empty.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError('AbeUser.name cannot be empty.');
    }
  }

  final String id;
  final String name;
  final String email;
  final String uacGroupId;
  final List<String> permissions;
  final bool isActive;

  /// Launch city code: `'CPT'` (Cape Town) or `'JHB'` (Johannesburg).
  final String city;

  /// Closed-loop customer wallet balance in ZAR (read-only from client SDKs).
  final double walletBalanceZar;

  AbeUacGroupId get parsedGroup => AbeUacGroupId.fromCode(uacGroupId);

  /// Evaluates whether this user has [permissionKey] via [matrix] or explicit permissions.
  bool hasPermission(String permissionKey, {UacPermissionMatrix? matrix}) {
    if (!isActive) return false;
    final effectiveMatrix = matrix ?? UacPermissionMatrix();
    return effectiveMatrix.hasPermission(
      userId: id,
      uacGroupId: uacGroupId,
      permissionKey: permissionKey,
      isActive: isActive,
      customPermissions: permissions,
    );
  }

  factory AbeUser.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'];
    final permList = rawPerms is Iterable
        ? rawPerms.map((e) => e.toString()).toList()
        : const <String>[];

    return AbeUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      uacGroupId: (json['uacGroupId'] ?? AbeUacGroupId.client.code).toString(),
      city: (json['city'] ?? 'CPT').toString(),
      permissions: permList,
      isActive: json['isActive'] as bool? ?? true,
      walletBalanceZar: (json['walletBalanceZar'] as num?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'uacGroupId': uacGroupId,
      'city': city,
      'permissions': permissions,
      'isActive': isActive,
      'walletBalanceZar': walletBalanceZar,
    };
  }
}
