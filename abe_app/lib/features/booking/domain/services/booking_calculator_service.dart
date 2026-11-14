import '../../../../core/config/brand_config.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../../portfolio/domain/models/visual_contract_item.dart';
import '../../../store/domain/models/store_models.dart';
import '../models/booking_modifier.dart';

/// Pure domain calculator for Visual Contract bookings, dynamic modifiers,
/// and promo/courtesy voucher previews.
///
/// Security invariants enforced:
/// - Total price in ZAR and appointment duration in minutes can never be negative.
/// - Modifier quantities are clamped to `[0, modifier.maxQuantity]`.
/// - Voucher codes are sanitised against XSS/injection and validated against
///   active status, usage cap, and minimum spend thresholds.
/// - Voucher discounts never exceed the booking subtotal (minimum payable is `R0`).
class BookingCalculatorService {
  const BookingCalculatorService({
    this.availableVouchers,
  });

  final List<VoucherCode>? availableVouchers;

  /// Default seeded vouchers for previewing promo and tech-cancellation discounts.
  static List<VoucherCode> defaultVoucherCatalog() {
    return <VoucherCode>[
      VoucherCode(
        id: 'vch_welcome_50',
        code: 'ABEWELCOME50',
        discountAmountZar: 50,
        minSpendZar: 350,
        maxUses: 500,
        currentUses: 42,
        isActive: true,
        issuedForReason: 'First booking welcome voucher',
      ),
      VoucherCode(
        id: 'vch_founding_100',
        code: 'FOUNDING100',
        discountAmountZar: 100,
        minSpendZar: 500,
        maxUses: 200,
        currentUses: 18,
        isActive: true,
        issuedForReason: 'Cape Town & Johannesburg launch celebration',
      ),
      VoucherCode(
        id: 'vch_tech_cancel_75',
        code: 'TECHCANCEL75',
        discountAmountZar: 75,
        minSpendZar: 250,
        maxUses: 1,
        currentUses: 0,
        isActive: true,
        issuedForReason: 'Tech cancellation courtesy discount voucher',
      ),
    ];
  }

  List<VoucherCode> get voucherCatalog =>
      availableVouchers ?? defaultVoucherCatalog();

  /// Resolves the list of [BookingModifier] items available for a [VisualContractItem].
  List<BookingModifier> resolveModifiersForContract(
    VisualContractItem contract,
  ) {
    if (contract.allowedModifiers.isEmpty) {
      return const <BookingModifier>[];
    }
    return contract.allowedModifiers
        .map(BookingModifier.fromContractModifier)
        .toList(growable: false);
  }

  /// Calculates a complete [BookingPriceQuote] from a [VisualContractItem],
  /// selected modifier quantities, and an optional voucher code string.
  BookingPriceQuote calculateQuote({
    required VisualContractItem contract,
    List<BookingModifier>? modifiers,
    Map<String, int> selectedQuantities = const <String, int>{},
    String? rawVoucherCode,
  }) {
    final resolvedModifiers =
        modifiers ?? resolveModifiersForContract(contract);

    var modifiersPriceZar = 0;
    var modifiersDurationMinutes = 0;
    final lineItems = <BookingModifierLineItem>[];

    for (final modifier in resolvedModifiers) {
      final rawQty = selectedQuantities[modifier.id] ?? 0;
      if (rawQty <= 0) {
        continue;
      }
      final clampedQty = rawQty.clamp(0, modifier.maxQuantity);
      final linePrice = modifier.priceZar * clampedQty;
      final lineDuration = modifier.durationMinutes * clampedQty;

      modifiersPriceZar += linePrice;
      modifiersDurationMinutes += lineDuration;

      lineItems.add(
        BookingModifierLineItem(
          modifier: modifier,
          quantity: clampedQty,
          linePriceZar: linePrice,
          lineDurationMinutes: lineDuration,
        ),
      );
    }

    final subtotalPriceZar = contract.basePriceZar + modifiersPriceZar;
    final totalDurationMinutes =
        contract.baseDurationMinutes + modifiersDurationMinutes;

    var voucherDiscountZar = 0;
    String? appliedVoucherCode;
    String? voucherMessage;
    var isVoucherValid = false;

    final trimmedCode = (rawVoucherCode ?? '').trim();
    if (trimmedCode.isNotEmpty) {
      String? sanitisedCode;
      try {
        sanitisedCode = InputSanitiser.sanitiseVoucherCode(trimmedCode);
      } on ArgumentError {
        sanitisedCode = null;
      }

      if (sanitisedCode == null) {
        voucherMessage = 'Enter a valid alphanumeric voucher code.';
      } else {
        VoucherCode? matched;
        for (final candidate in voucherCatalog) {
          if (candidate.code == sanitisedCode) {
            matched = candidate;
            break;
          }
        }

        if (matched == null) {
          voucherMessage = 'Voucher code "$sanitisedCode" was not found.';
        } else if (!matched.canRedeem) {
          voucherMessage =
              'Voucher code "${matched.code}" is no longer active.';
        } else if (subtotalPriceZar < matched.minSpendZar) {
          voucherMessage =
              'Voucher "${matched.code}" requires a minimum spend of R${matched.minSpendZar}.';
        } else {
          voucherDiscountZar =
              matched.discountAmountZar.clamp(0, subtotalPriceZar);
          appliedVoucherCode = matched.code;
          isVoucherValid = true;
          voucherMessage =
              'Voucher ${matched.code} applied (-R$voucherDiscountZar).';
        }
      }
    }

    final totalPayableZar =
        (subtotalPriceZar - voucherDiscountZar).clamp(0, subtotalPriceZar);
    final platformFeeZar =
        (totalPayableZar * BrandConfig.platformFeeRate).round();
    final techNetPayoutZar =
        (totalPayableZar - platformFeeZar).clamp(0, totalPayableZar);

    return BookingPriceQuote(
      basePriceZar: contract.basePriceZar,
      baseDurationMinutes: contract.baseDurationMinutes,
      modifiersPriceZar: modifiersPriceZar,
      modifiersDurationMinutes: modifiersDurationMinutes,
      subtotalPriceZar: subtotalPriceZar,
      voucherDiscountZar: voucherDiscountZar,
      totalPayableZar: totalPayableZar,
      totalDurationMinutes: totalDurationMinutes,
      platformFeeZar: platformFeeZar,
      techNetPayoutZar: techNetPayoutZar,
      selectedLineItems: List<BookingModifierLineItem>.unmodifiable(lineItems),
      appliedVoucherCode: appliedVoucherCode,
      voucherMessage: voucherMessage,
      isVoucherValid: isVoucherValid,
    );
  }
}
