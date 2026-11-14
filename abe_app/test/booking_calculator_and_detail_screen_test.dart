import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/auth/domain/models/tech_profile.dart';
import 'package:abe_app/features/booking/domain/models/booking_modifier.dart';
import 'package:abe_app/features/booking/domain/services/booking_calculator_service.dart';
import 'package:abe_app/features/booking/presentation/screens/visual_contract_detail_screen.dart';
import 'package:abe_app/features/portfolio/domain/models/visual_contract_item.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final sampleContract = VisualContractItem(
    id: 'vc_cpt_test_01',
    techId: 'tech_cpt_01',
    techDisplayName: 'Nadia Jacobs',
    techTierBadge: TechTierBadge.certifiedPro,
    photoUrl: 'https://assets.abe.co.za/cpt/nadia_biab.jpg',
    title: 'Sculpted Almond BIAB & Micro French',
    basePriceZar: 450,
    baseDurationMinutes: 90,
    city: 'CPT',
    venueId: 'venue_cpt_01',
    venueName: 'Atelier Rose Studio, Sea Point',
    venueType: CommercialVenueType.verifiedStudio,
    allowedModifiers: <ContractModifier>[
      ContractModifier(
        id: 'mod_soak_off',
        name: 'Soak-Off / Removal',
        additionalPriceZar: 80,
        additionalDurationMinutes: 30,
      ),
      ContractModifier(
        id: 'mod_extra_length',
        name: 'Extra Length',
        additionalPriceZar: 60,
        additionalDurationMinutes: 15,
      ),
      ContractModifier(
        id: 'mod_nail_repair',
        name: 'Single Nail Repair',
        additionalPriceZar: 45,
        additionalDurationMinutes: 15,
      ),
    ],
  );

  group('BookingModifier & BookingCalculatorService Unit Tests', () {
    test('calculates base price, modifiers, and 15% platform fee accurately', () {
      const calculator = BookingCalculatorService();
      final quote = calculator.calculateQuote(
        contract: sampleContract,
        selectedQuantities: const <String, int>{
          'mod_soak_off': 1,
          'mod_extra_length': 1,
          'mod_nail_repair': 2,
        },
      );

      // Base 450 + Soak-Off 80 + Extra Length 60 + 2x Nail Repair (90) = 680
      expect(quote.basePriceZar, 450);
      expect(quote.modifiersPriceZar, 230);
      expect(quote.subtotalPriceZar, 680);
      expect(quote.totalPayableZar, 680);

      // Base 90 + 30 + 15 + 2x15 (30) = 165 mins
      expect(quote.baseDurationMinutes, 90);
      expect(quote.modifiersDurationMinutes, 75);
      expect(quote.totalDurationMinutes, 165);

      // 15% platform fee on R680 = R102, net tech payout = R578
      expect(quote.platformFeeZar, 102);
      expect(quote.techNetPayoutZar, 578);
    });

    test('clamps per-nail quantity and ignores negative modifier quantities', () {
      const calculator = BookingCalculatorService();
      final quote = calculator.calculateQuote(
        contract: sampleContract,
        selectedQuantities: const <String, int>{
          'mod_soak_off': -3,
          'mod_nail_repair': 25, // Clamped to maxQuantity 10
        },
      );

      // Base 450 + 10 * 45 = 900
      expect(quote.modifiersPriceZar, 450);
      expect(quote.totalPayableZar, 900);
      expect(quote.totalDurationMinutes, 240);
    });

    test('applies valid voucher code and enforces minimum spend threshold', () {
      const calculator = BookingCalculatorService();

      // ABEWELCOME50 gives R50 off on min spend R350
      final validQuote = calculator.calculateQuote(
        contract: sampleContract,
        rawVoucherCode: 'abewelcome50',
      );
      expect(validQuote.isVoucherValid, isTrue);
      expect(validQuote.appliedVoucherCode, 'ABEWELCOME50');
      expect(validQuote.voucherDiscountZar, 50);
      expect(validQuote.totalPayableZar, 400);

      // FOUNDING100 requires R500 min spend (base is R450)
      final belowMinQuote = calculator.calculateQuote(
        contract: sampleContract,
        rawVoucherCode: 'FOUNDING100',
      );
      expect(belowMinQuote.isVoucherValid, isFalse);
      expect(belowMinQuote.voucherDiscountZar, 0);
      expect(belowMinQuote.totalPayableZar, 450);
      expect(
        belowMinQuote.voucherMessage,
        contains('minimum spend of R500'),
      );
    });

    test('formats ZAR currency with commas and rejects negative modifier definitions', () {
      expect(
        BookingPriceQuote.formatZarCurrency(1250, useCommas: true),
        'R1,250',
      );
      expect(
        BookingPriceQuote.formatZarCurrency(450, useCommas: true),
        'R450',
      );

      expect(
        () => BookingModifier(
          id: 'mod_bad',
          name: 'Invalid Negative Price',
          priceZar: -20,
          durationMinutes: 15,
        ),
        throwsArgumentError,
      );
    });
  });

  group('VisualContractDetailScreen Widget Tests', () {
    testWidgets(
      'toggling modifiers and applying voucher dynamically updates sticky total bar',
      (WidgetTester tester) async {
        BookingPriceQuote? confirmedQuote;

        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: VisualContractDetailScreen(
              contract: sampleContract,
              onConfirmBooking: (quote) {
                confirmedQuote = quote;
              },
            ),
          ),
        );

        // Initial sticky total is R450 and 90 mins
        expect(
          find.byKey(const Key('booking_sticky_total_price')),
          findsOneWidget,
        );
        expect(find.text('R450'), findsWidgets);
        expect(find.text('90 mins'), findsWidgets);

        // Tap Soak-Off / Removal (+R80, +30 mins)
        final soakOffFinder = find.byKey(const Key('modifier_row_mod_soak_off'));
        await tester.ensureVisible(soakOffFinder);
        await tester.tap(soakOffFinder);
        await tester.pumpAndSettle();

        expect(find.text('R530'), findsWidgets);
        expect(find.text('120 mins'), findsWidgets);

        // Increment Single Nail Repair (+R45, +15 mins)
        final repairIncFinder = find.byKey(
          const Key('modifier_increment_mod_nail_repair'),
        );
        await tester.ensureVisible(repairIncFinder);
        await tester.tap(repairIncFinder);
        await tester.pumpAndSettle();

        expect(find.text('R575'), findsWidgets);
        expect(find.text('135 mins'), findsWidgets);

        // Apply ABEWELCOME50 voucher (-R50)
        final voucherInputFinder = find.byKey(
          const Key('booking_voucher_input'),
        );
        await tester.ensureVisible(voucherInputFinder);
        await tester.pumpAndSettle();
        await tester.enterText(voucherInputFinder, 'ABEWELCOME50');
        await tester.pumpAndSettle();
        final voucherApplyFinder = find.byKey(
          const Key('booking_voucher_apply_button'),
        );
        await tester.ensureVisible(voucherApplyFinder);
        await tester.pumpAndSettle();
        await tester.tap(voucherApplyFinder);
        await tester.pumpAndSettle();

        expect(find.text('R525'), findsWidgets);

        // Confirm booking
        await tester.tap(find.byKey(const Key('booking_confirm_button')));
        await tester.pumpAndSettle();

        expect(confirmedQuote, isNotNull);
        expect(confirmedQuote!.totalPayableZar, 525);
        expect(confirmedQuote!.totalDurationMinutes, 135);
      },
    );
  });
}
