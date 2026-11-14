import 'package:abe_app/features/auth/domain/models/tech_profile.dart';
import 'package:abe_app/features/booking/domain/models/booking_modifier.dart';
import 'package:abe_app/features/booking/domain/services/booking_calculator_service.dart';
import 'package:abe_app/features/portfolio/domain/models/visual_contract_item.dart';
import 'package:abe_app/features/portfolio/domain/utils/portfolio_image_crop_helper.dart';
import 'package:abe_app/features/store/domain/models/store_models.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fullContract = VisualContractItem(
    id: 'vc_cpt_edge_01',
    techId: 'tech_cpt_01',
    techDisplayName: 'Nadia Jacobs',
    techTierBadge: TechTierBadge.certifiedPro,
    photoUrl: 'https://assets.abe.co.za/cpt/nadia_biab_4x5.jpg',
    title: 'Sculpted Almond BIAB & Micro French',
    basePriceZar: 450,
    baseDurationMinutes: 90,
    city: 'CPT',
    venueId: 'venue_cpt_seapoint_01',
    venueName: 'Atelier Rose Studio, Sea Point',
    venueType: CommercialVenueType.verifiedStudio,
    allowedModifiers: BookingModifier.standardPresets()
        .map((m) => m.toContractModifier())
        .toList(growable: false),
  );

  group('Background Task 2A: PortfolioImageCropHelper (4:5 Crop & Compression)', () {
    test('crops 9:16 portrait (1080x1920) to centred 1080x1350 (4:5)', () {
      final spec = PortfolioImageCropHelper.calculateFourByFiveCrop(
        sourceWidth: 1080,
        sourceHeight: 1920,
      );

      expect(spec.cropX, 0);
      expect(spec.cropY, 285); // (1920 - 1350) ~/ 2
      expect(spec.cropWidth, 1080);
      expect(spec.cropHeight, 1350);
      expect(spec.targetWidth, 1080);
      expect(spec.targetHeight, 1350);
      expect(spec.aspectRatio, closeTo(0.80, 1e-6));
      expect(spec.wasAlreadyFourByFive, isFalse);
      expect(spec.wasDownscaled, isFalse);
      expect(spec.recommendedQualityPercent, 82);
      expect(spec.recommendedFormat, 'webp');
    });

    test('crops 1:1 square (1200x1200) to centred 960x1200 (4:5)', () {
      final spec = PortfolioImageCropHelper.calculateFourByFiveCrop(
        sourceWidth: 1200,
        sourceHeight: 1200,
        preferredFormat: 'jpeg',
      );

      expect(spec.cropX, 120); // (1200 - 960) ~/ 2
      expect(spec.cropY, 0);
      expect(spec.cropWidth, 960);
      expect(spec.cropHeight, 1200);
      expect(spec.targetWidth, 960);
      expect(spec.targetHeight, 1200);
      expect(spec.aspectRatio, closeTo(0.80, 1e-6));
      expect(spec.wasAlreadyFourByFive, isFalse);
      expect(spec.wasDownscaled, isFalse);
      expect(spec.recommendedQualityPercent, 86);
      expect(spec.recommendedFormat, 'jpeg');
    });

    test('crops 4:3 landscape (1600x1200) to centred 960x1200 (4:5)', () {
      final spec = PortfolioImageCropHelper.calculateFourByFiveCrop(
        sourceWidth: 1600,
        sourceHeight: 1200,
      );

      expect(spec.cropX, 320); // (1600 - 960) ~/ 2
      expect(spec.cropY, 0);
      expect(spec.cropWidth, 960);
      expect(spec.cropHeight, 1200);
      expect(spec.targetWidth, 960);
      expect(spec.targetHeight, 1200);
      expect(spec.aspectRatio, closeTo(0.80, 1e-6));
    });

    test('preserves already-4:5 dimensions and caps high-res 4:5 (2160x2700) to 1080x1350', () {
      final nativeSpec = PortfolioImageCropHelper.calculateFourByFiveCrop(
        sourceWidth: 1080,
        sourceHeight: 1350,
      );
      expect(nativeSpec.wasAlreadyFourByFive, isTrue);
      expect(nativeSpec.wasDownscaled, isFalse);
      expect(nativeSpec.cropX, 0);
      expect(nativeSpec.cropY, 0);
      expect(nativeSpec.targetWidth, 1080);
      expect(nativeSpec.targetHeight, 1350);

      final highResSpec = PortfolioImageCropHelper.calculateFourByFiveCrop(
        sourceWidth: 2160,
        sourceHeight: 2700,
      );
      expect(highResSpec.wasAlreadyFourByFive, isTrue);
      expect(highResSpec.wasDownscaled, isTrue);
      expect(highResSpec.cropWidth, 2160);
      expect(highResSpec.cropHeight, 2700);
      expect(highResSpec.targetWidth, 1080);
      expect(highResSpec.targetHeight, 1350);
      expect(highResSpec.recommendedQualityPercent, 82);
    });

    test('rejects zero, negative, NaN, infinite, and sub-minimum dimensions', () {
      expect(
        () => PortfolioImageCropHelper.calculateFourByFiveCrop(
          sourceWidth: 0,
          sourceHeight: 1350,
        ),
        throwsArgumentError,
      );
      expect(
        () => PortfolioImageCropHelper.calculateFourByFiveCrop(
          sourceWidth: 1080,
          sourceHeight: -500,
        ),
        throwsArgumentError,
      );
      expect(
        () => PortfolioImageCropHelper.calculateFourByFiveCrop(
          sourceWidth: double.nan,
          sourceHeight: 1000,
        ),
        throwsArgumentError,
      );
      expect(
        () => PortfolioImageCropHelper.calculateFourByFiveCrop(
          sourceWidth: 3,
          sourceHeight: 4,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Background Task 2B: Multi-Modifier Combinations & Calculator Edge Cases', () {
    test('calculates zero modifiers accurately', () {
      const calculator = BookingCalculatorService();
      final quote = calculator.calculateQuote(
        contract: fullContract,
        selectedQuantities: const <String, int>{},
      );

      expect(quote.basePriceZar, 450);
      expect(quote.modifiersPriceZar, 0);
      expect(quote.subtotalPriceZar, 450);
      expect(quote.totalPayableZar, 450);
      expect(quote.totalDurationMinutes, 90);
      expect(quote.selectedLineItems, isEmpty);
      expect(quote.platformFeeZar, 68); // 450 * 0.15 = 67.5 -> 68
      expect(quote.techNetPayoutZar, 382);
    });

    test('calculates all 4 standard modifiers enabled simultaneously with maximum 10 nail repairs', () {
      const calculator = BookingCalculatorService();
      final quote = calculator.calculateQuote(
        contract: fullContract,
        selectedQuantities: const <String, int>{
          'mod_soak_off': 1, // +R80, +30 mins
          'mod_extra_length': 1, // +R60, +15 mins
          'mod_nail_repair': 10, // 10 * R45 = +R450, 10 * 15 = +150 mins
          'mod_chrome_glaze': 1, // +R50, +10 mins
        },
      );

      // Modifiers total: 80 + 60 + 450 + 50 = R640
      // Subtotal: 450 + 640 = R1,090
      // Duration: 90 + (30 + 15 + 150 + 10) = 295 mins
      expect(quote.selectedLineItems.length, 4);
      expect(quote.modifiersPriceZar, 640);
      expect(quote.subtotalPriceZar, 1090);
      expect(quote.totalPayableZar, 1090);
      expect(quote.modifiersDurationMinutes, 205);
      expect(quote.totalDurationMinutes, 295);
      expect(quote.formattedTotalPayableWithCommas, 'R1,090');

      // 15% platform fee on R1,090 = 163.5 -> R164, net tech payout = R926
      expect(quote.platformFeeZar, 164);
      expect(quote.techNetPayoutZar, 926);
    });

    test('clamps toggle modifiers with quantity > 1 to 1 and per-nail repairs > 10 to 10', () {
      const calculator = BookingCalculatorService();
      final quote = calculator.calculateQuote(
        contract: fullContract,
        selectedQuantities: const <String, int>{
          'mod_soak_off': 5, // Toggle maxQuantity is 1 -> +R80
          'mod_nail_repair': 99, // Per-nail maxQuantity is 10 -> +R450
        },
      );

      expect(quote.modifiersPriceZar, 530);
      expect(quote.subtotalPriceZar, 980);
      expect(quote.totalDurationMinutes, 270); // 90 + 30 + 150
    });
  });

  group('Background Task 2B: Voucher Discount Bounds & Security Sanitisation', () {
    test('clamps total payable to R0 when voucher discount exceeds subtotal', () {
      final calculator = BookingCalculatorService(
        availableVouchers: <VoucherCode>[
          VoucherCode(
            id: 'vch_vip_comp_1000',
            code: 'VIPCOMP1000',
            discountAmountZar: 1000,
            minSpendZar: 0,
            maxUses: 10,
            currentUses: 1,
            isActive: true,
            issuedForReason: 'VIP full complimentary studio voucher',
          ),
        ],
      );

      final quote = calculator.calculateQuote(
        contract: fullContract, // Base price R450
        rawVoucherCode: 'VIPCOMP1000',
      );

      expect(quote.isVoucherValid, isTrue);
      expect(quote.subtotalPriceZar, 450);
      expect(quote.voucherDiscountZar, 450); // Clamped to subtotal
      expect(quote.totalPayableZar, 0);
      expect(quote.platformFeeZar, 0);
      expect(quote.techNetPayoutZar, 0);
      expect(quote.formattedTotalPayable, 'R0');
      expect(quote.formattedTotalPayableWithCommas, 'R0');
    });

    test('rejects exhausted voucher where currentUses == maxUses', () {
      final calculator = BookingCalculatorService(
        availableVouchers: <VoucherCode>[
          VoucherCode(
            id: 'vch_exhausted',
            code: 'SOLD100',
            discountAmountZar: 100,
            minSpendZar: 200,
            maxUses: 50,
            currentUses: 50,
            isActive: true,
          ),
        ],
      );

      final quote = calculator.calculateQuote(
        contract: fullContract,
        rawVoucherCode: 'SOLD100',
      );

      expect(quote.isVoucherValid, isFalse);
      expect(quote.voucherDiscountZar, 0);
      expect(quote.totalPayableZar, 450);
      expect(quote.voucherMessage, contains('no longer active'));
    });

    test('rejects inactive voucher where isActive is false', () {
      final calculator = BookingCalculatorService(
        availableVouchers: <VoucherCode>[
          VoucherCode(
            id: 'vch_inactive',
            code: 'PAUSED50',
            discountAmountZar: 50,
            minSpendZar: 200,
            maxUses: 100,
            currentUses: 2,
            isActive: false,
          ),
        ],
      );

      final quote = calculator.calculateQuote(
        contract: fullContract,
        rawVoucherCode: 'PAUSED50',
      );

      expect(quote.isVoucherValid, isFalse);
      expect(quote.voucherDiscountZar, 0);
      expect(quote.totalPayableZar, 450);
      expect(quote.voucherMessage, contains('no longer active'));
    });

    test('sanitises XSS/HTML characters in voucher input safely without script injection', () {
      const calculator = BookingCalculatorService();

      // Pure XSS tag payload leaves no valid voucher code
      final pureTagQuote = calculator.calculateQuote(
        contract: fullContract,
        rawVoucherCode: '<script></script><b>!@#\$%^&*()</b>',
      );
      expect(pureTagQuote.isVoucherValid, isFalse);
      expect(pureTagQuote.voucherDiscountZar, 0);
      expect(
        pureTagQuote.voucherMessage,
        'Enter a valid alphanumeric voucher code.',
      );

      // XSS payload wrapping text is stripped before lookup
      final wrappedXssQuote = calculator.calculateQuote(
        contract: fullContract,
        rawVoucherCode: '<img src=x onerror=alert(1)>ABEWELCOME50',
      );
      expect(wrappedXssQuote.isVoucherValid, isTrue);
      expect(wrappedXssQuote.appliedVoucherCode, 'ABEWELCOME50');
      expect(wrappedXssQuote.voucherDiscountZar, 50);
      expect(wrappedXssQuote.totalPayableZar, 400);
    });
  });

  group('Background Task 2B: ZAR Currency Formatting', () {
    test('formats R0, R450, R1,250, and R12,500 accurately', () {
      expect(BookingPriceQuote.formatZarCurrency(-150), 'R0');
      expect(BookingPriceQuote.formatZarCurrency(0), 'R0');
      expect(BookingPriceQuote.formatZarCurrency(450), 'R450');
      expect(BookingPriceQuote.formatZarCurrency(1250), 'R1,250');
      expect(BookingPriceQuote.formatZarCurrency(12500), 'R12,500');
      expect(
        BookingPriceQuote.formatZarCurrency(1250, useCommas: false),
        'R1250',
      );
    });
  });
}
