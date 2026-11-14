import '../../../../core/utils/input_sanitiser.dart';
import '../../../portfolio/domain/models/visual_contract_item.dart';

/// Defines how a [BookingModifier] is selected by the client.
enum BookingModifierType {
  /// Binary toggle (0 or 1), such as Soak-Off / Removal or Extra Length.
  toggle('toggle'),

  /// Per-nail counter (0 to maxQuantity), such as Single Nail Repair.
  perNailCount('per_nail_count');

  const BookingModifierType(this.code);
  final String code;

  static BookingModifierType fromCode(String rawCode) {
    final cleaned = rawCode.trim().toLowerCase();
    for (final value in BookingModifierType.values) {
      if (value.code == cleaned) {
        return value;
      }
    }
    return BookingModifierType.toggle;
  }
}

/// Domain model for an optional add-on modifier on a Visual Contract booking.
///
/// Enforces non-negative ZAR price and minute duration additions, XSS sanitisation,
/// and UK/South African English copy with zero em-dashes.
class BookingModifier {
  BookingModifier({
    required String id,
    required String name,
    String subtitle = '',
    required num priceZar,
    required num durationMinutes,
    this.type = BookingModifierType.toggle,
    int maxQuantity = 1,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 64),
        name = InputSanitiser.sanitiseText(name, maxLength: 100),
        subtitle = InputSanitiser.sanitiseText(subtitle, maxLength: 200),
        priceZar = InputSanitiser.requireNonNegativeInt(
          priceZar,
          fieldName: 'priceZar',
        ),
        durationMinutes = InputSanitiser.requireNonNegativeInt(
          durationMinutes,
          fieldName: 'durationMinutes',
        ),
        maxQuantity = type == BookingModifierType.toggle
            ? 1
            : InputSanitiser.requireNonNegativeInt(
                maxQuantity,
                fieldName: 'maxQuantity',
                strictlyPositive: true,
              ).clamp(1, 10) {
    if (this.id.isEmpty) {
      throw ArgumentError('BookingModifier.id cannot be empty.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError('BookingModifier.name cannot be empty.');
    }
  }

  final String id;
  final String name;
  final String subtitle;
  final int priceZar;
  final int durationMinutes;
  final BookingModifierType type;
  final int maxQuantity;

  /// Formatted badge summary, for example `'+R80 • +30 mins'` or `'+R45 • +15 mins / nail'`.
  String get formattedSummary {
    final unitSuffix =
        type == BookingModifierType.perNailCount ? ' / nail' : '';
    return '+R$priceZar • +$durationMinutes mins$unitSuffix';
  }

  /// Converts a portfolio [ContractModifier] into a rich [BookingModifier].
  factory BookingModifier.fromContractModifier(ContractModifier mod) {
    final lowerId = mod.id.toLowerCase();
    final lowerName = mod.name.toLowerCase();
    final isPerNail =
        lowerId.contains('repair') || lowerName.contains('repair');

    String defaultSubtitle =
        'Optional studio add-on configured by your nail technician.';
    if (lowerId.contains('soak') || lowerName.contains('soak')) {
      defaultSubtitle =
          'Gentle studio soak-off and safe removal before applying your new set.';
    } else if (lowerId.contains('length') || lowerName.contains('length')) {
      defaultSubtitle =
          'Extended sculpting or tip length beyond the standard photo length.';
    } else if (isPerNail) {
      defaultSubtitle =
          'Targeted silk, builder gel, or tip repair for a damaged natural nail.';
    }

    return BookingModifier(
      id: mod.id,
      name: mod.name,
      subtitle: defaultSubtitle,
      priceZar: mod.additionalPriceZar,
      durationMinutes: mod.additionalDurationMinutes,
      type: isPerNail
          ? BookingModifierType.perNailCount
          : BookingModifierType.toggle,
      maxQuantity: isPerNail ? 10 : 1,
    );
  }

  /// Converts this [BookingModifier] back into a [ContractModifier] for portfolio storage.
  ContractModifier toContractModifier() {
    return ContractModifier(
      id: id,
      name: name,
      additionalPriceZar: priceZar,
      additionalDurationMinutes: durationMinutes,
    );
  }

  factory BookingModifier.fromJson(Map<String, dynamic> json) {
    final type = BookingModifierType.fromCode(
      (json['type'] ?? 'toggle').toString(),
    );
    return BookingModifier(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      priceZar: (json['priceZar'] as num?) ?? 0,
      durationMinutes: (json['durationMinutes'] as num?) ?? 0,
      type: type,
      maxQuantity: (json['maxQuantity'] as num?)?.toInt() ??
          (type == BookingModifierType.perNailCount ? 10 : 1),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'priceZar': priceZar,
      'durationMinutes': durationMinutes,
      'type': type.code,
      'maxQuantity': maxQuantity,
    };
  }

  /// Standard modifier presets finalised from Aqeelah's CPT and JHB market research.
  static List<BookingModifier> standardPresets() {
    return <BookingModifier>[
      BookingModifier(
        id: 'mod_soak_off',
        name: 'Soak-Off / Removal',
        subtitle:
            'Gentle studio soak-off and safe removal before applying your new set.',
        priceZar: 80,
        durationMinutes: 30,
        type: BookingModifierType.toggle,
      ),
      BookingModifier(
        id: 'mod_extra_length',
        name: 'Extra Length',
        subtitle:
            'Extended sculpting or tip length beyond the standard photo length.',
        priceZar: 60,
        durationMinutes: 15,
        type: BookingModifierType.toggle,
      ),
      BookingModifier(
        id: 'mod_nail_repair',
        name: 'Single Nail Repair',
        subtitle:
            'Targeted builder gel or tip repair for broken nails (select per nail).',
        priceZar: 45,
        durationMinutes: 15,
        type: BookingModifierType.perNailCount,
        maxQuantity: 10,
      ),
      BookingModifier(
        id: 'mod_chrome_glaze',
        name: 'Chrome / Pearl Glaze Finish',
        subtitle:
            'Mirror chrome or glazed pearl powder sealed over all ten nails.',
        priceZar: 50,
        durationMinutes: 10,
        type: BookingModifierType.toggle,
      ),
    ];
  }
}

/// Immutable breakdown of a Visual Contract price and appointment duration calculation.
class BookingPriceQuote {
  const BookingPriceQuote({
    required this.basePriceZar,
    required this.baseDurationMinutes,
    required this.modifiersPriceZar,
    required this.modifiersDurationMinutes,
    required this.subtotalPriceZar,
    required this.voucherDiscountZar,
    required this.totalPayableZar,
    required this.totalDurationMinutes,
    required this.platformFeeZar,
    required this.techNetPayoutZar,
    required this.selectedLineItems,
    this.appliedVoucherCode,
    this.voucherMessage,
    this.isVoucherValid = false,
  });

  final int basePriceZar;
  final int baseDurationMinutes;
  final int modifiersPriceZar;
  final int modifiersDurationMinutes;
  final int subtotalPriceZar;
  final int voucherDiscountZar;
  final int totalPayableZar;
  final int totalDurationMinutes;
  final int platformFeeZar;
  final int techNetPayoutZar;
  final List<BookingModifierLineItem> selectedLineItems;
  final String? appliedVoucherCode;
  final String? voucherMessage;
  final bool isVoucherValid;

  /// Compact Rand label, for example `'R450'` or `'R1250'`.
  String get formattedTotalPayable => 'R$totalPayableZar';

  /// Rand label with thousands separator, for example `'R1,250'`.
  String get formattedTotalPayableWithCommas =>
      formatZarCurrency(totalPayableZar, useCommas: true);

  /// Formatted total duration in minutes, for example `'120 mins'`.
  String get formattedTotalDuration => '$totalDurationMinutes mins';

  /// Formats a South African Rand integer value cleanly.
  static String formatZarCurrency(int amountZar, {bool useCommas = true}) {
    final clamped = amountZar < 0 ? 0 : amountZar;
    if (!useCommas) {
      return 'R$clamped';
    }
    final digits = clamped.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final positionFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return 'R${buffer.toString()}';
  }
}

/// Single active modifier line item in a [BookingPriceQuote].
class BookingModifierLineItem {
  const BookingModifierLineItem({
    required this.modifier,
    required this.quantity,
    required this.linePriceZar,
    required this.lineDurationMinutes,
  });

  final BookingModifier modifier;
  final int quantity;
  final int linePriceZar;
  final int lineDurationMinutes;
}
