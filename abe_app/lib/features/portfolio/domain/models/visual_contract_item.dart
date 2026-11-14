import '../../../../core/utils/input_sanitiser.dart';
import '../../../auth/domain/models/tech_profile.dart';
import '../../../venue/domain/models/commercial_venue.dart';

/// Optional toggle modifier attached to a [VisualContractItem] (for example,
/// Soak-Off / Removal, Extra Length, or Nail Repair) that dynamically adds
/// price in ZAR and duration in minutes.
class ContractModifier {
  ContractModifier({
    required String id,
    required String name,
    required num additionalPriceZar,
    required num additionalDurationMinutes,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 64),
        name = InputSanitiser.sanitiseText(name, maxLength: 100),
        additionalPriceZar = InputSanitiser.requireNonNegativeInt(
          additionalPriceZar,
          fieldName: 'additionalPriceZar',
        ),
        additionalDurationMinutes = InputSanitiser.requireNonNegativeInt(
          additionalDurationMinutes,
          fieldName: 'additionalDurationMinutes',
        ) {
    if (this.id.isEmpty) {
      throw ArgumentError('ContractModifier.id cannot be empty.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError('ContractModifier.name cannot be empty.');
    }
  }

  final String id;
  final String name;
  final int additionalPriceZar;
  final int additionalDurationMinutes;

  factory ContractModifier.fromJson(Map<String, dynamic> json) {
    return ContractModifier(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      additionalPriceZar: (json['additionalPriceZar'] as num?) ?? 0,
      additionalDurationMinutes:
          (json['additionalDurationMinutes'] as num?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'additionalPriceZar': additionalPriceZar,
      'additionalDurationMinutes': additionalDurationMinutes,
    };
  }
}

/// The signature ABE "Visual Contract" portfolio item.
///
/// Every nail portfolio photo acts as a binding visual contract with a
/// hard-coded base price in ZAR (`basePriceZar`), exact base duration in minutes
/// (`baseDurationMinutes`), verified commercial venue, and optional toggle modifiers.
class VisualContractItem {
  VisualContractItem({
    required String id,
    required String techId,
    required String techDisplayName,
    required this.techTierBadge,
    required String photoUrl,
    required String title,
    required num basePriceZar,
    required num baseDurationMinutes,
    required String city,
    required String venueId,
    required String venueName,
    required this.venueType,
    String styleCategory = 'BIAB & Structured Gel',
    List<ContractModifier> allowedModifiers = const <ContractModifier>[],
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        techDisplayName =
            InputSanitiser.sanitiseText(techDisplayName, maxLength: 120),
        photoUrl = InputSanitiser.sanitiseText(photoUrl, maxLength: 500),
        title = InputSanitiser.sanitiseText(title, maxLength: 140),
        basePriceZar = InputSanitiser.requireNonNegativeInt(
          basePriceZar,
          fieldName: 'basePriceZar',
          strictlyPositive: true,
        ),
        baseDurationMinutes = InputSanitiser.requireNonNegativeInt(
          baseDurationMinutes,
          fieldName: 'baseDurationMinutes',
          strictlyPositive: true,
        ),
        city = InputSanitiser.validateCityCode(city),
        venueId = InputSanitiser.sanitiseText(venueId, maxLength: 128),
        venueName = InputSanitiser.sanitiseText(venueName, maxLength: 140),
        styleCategory =
            InputSanitiser.sanitiseText(styleCategory, maxLength: 80),
        allowedModifiers =
            List<ContractModifier>.unmodifiable(allowedModifiers) {
    if (this.id.isEmpty) {
      throw ArgumentError('VisualContractItem.id cannot be empty.');
    }
    if (this.techId.isEmpty) {
      throw ArgumentError('VisualContractItem.techId cannot be empty.');
    }
    if (this.title.isEmpty) {
      throw ArgumentError('VisualContractItem.title cannot be empty.');
    }
    if (this.venueId.isEmpty || this.venueName.isEmpty) {
      throw ArgumentError(
        'VisualContractItem must reference a verified commercial venue.',
      );
    }
  }

  final String id;
  final String techId;
  final String techDisplayName;
  final TechTierBadge techTierBadge;
  final String photoUrl;
  final String title;
  final int basePriceZar;
  final int baseDurationMinutes;

  /// Launch city code: `'CPT'` or `'JHB'`.
  final String city;

  final String venueId;
  final String venueName;
  final CommercialVenueType venueType;
  final String styleCategory;
  final List<ContractModifier> allowedModifiers;

  /// Formatted South African Rand label (for example, `'R450'`).
  String get formattedBasePrice => 'R$basePriceZar';

  /// Formatted duration label (for example, `'90 mins'`).
  String get formattedBaseDuration => '$baseDurationMinutes mins';

  /// Calculates total price in ZAR given selected modifier IDs.
  int calculateTotalPriceZar(Set<String> selectedModifierIds) {
    var total = basePriceZar;
    for (final mod in allowedModifiers) {
      if (selectedModifierIds.contains(mod.id)) {
        total += mod.additionalPriceZar;
      }
    }
    return total;
  }

  /// Calculates total duration in minutes given selected modifier IDs.
  int calculateTotalDurationMinutes(Set<String> selectedModifierIds) {
    var total = baseDurationMinutes;
    for (final mod in allowedModifiers) {
      if (selectedModifierIds.contains(mod.id)) {
        total += mod.additionalDurationMinutes;
      }
    }
    return total;
  }

  factory VisualContractItem.fromJson(Map<String, dynamic> json) {
    final rawMods = json['allowedModifiers'];
    final modifiers = rawMods is Iterable
        ? rawMods
            .whereType<Map<String, dynamic>>()
            .map(ContractModifier.fromJson)
            .toList()
        : const <ContractModifier>[];

    return VisualContractItem(
      id: (json['id'] ?? '').toString(),
      techId: (json['techId'] ?? '').toString(),
      techDisplayName: (json['techDisplayName'] ?? 'Verified Tech').toString(),
      techTierBadge: TechTierBadge.fromCode(
        (json['techTierBadge'] ?? 'verified').toString(),
      ),
      photoUrl: (json['photoUrl'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      basePriceZar: (json['basePriceZar'] as num?) ?? 0,
      baseDurationMinutes: (json['baseDurationMinutes'] as num?) ?? 0,
      city: (json['city'] ?? 'CPT').toString(),
      venueId: (json['venueId'] ?? '').toString(),
      venueName: (json['venueName'] ?? '').toString(),
      venueType: CommercialVenueType.fromCode(
        (json['venueType'] ?? 'verified_studio').toString(),
      ),
      styleCategory:
          (json['styleCategory'] ?? 'BIAB & Structured Gel').toString(),
      allowedModifiers: modifiers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'techId': techId,
      'techDisplayName': techDisplayName,
      'techTierBadge': techTierBadge.code,
      'photoUrl': photoUrl,
      'title': title,
      'basePriceZar': basePriceZar,
      'baseDurationMinutes': baseDurationMinutes,
      'city': city,
      'venueId': venueId,
      'venueName': venueName,
      'venueType': venueType.code,
      'styleCategory': styleCategory,
      'allowedModifiers': allowedModifiers.map((m) => m.toJson()).toList(),
    };
  }
}
