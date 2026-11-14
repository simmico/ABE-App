import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/core/uac/uac_permission_matrix.dart';
import 'package:abe_app/features/booking/domain/models/appointment_lock_models.dart';
import 'package:abe_app/features/booking/domain/models/booking_modifier.dart';
import 'package:abe_app/features/booking/domain/services/appointment_completion_lock_service.dart';
import 'package:abe_app/features/booking/domain/services/appointment_start_lock_service.dart';
import 'package:abe_app/features/booking/domain/services/booking_calculator_service.dart';
import 'package:abe_app/features/booking/domain/services/venue_selection_service.dart';
import 'package:abe_app/features/booking/presentation/screens/tech_start_appointment_screen.dart';
import 'package:abe_app/features/booking/presentation/screens/visual_contract_detail_screen.dart';
import 'package:abe_app/features/payment/domain/models/payment_models.dart';
import 'package:abe_app/features/payment/domain/services/checkout_payment_service.dart';
import 'package:abe_app/features/payment/presentation/screens/checkout_payment_screen.dart';
import 'package:abe_app/features/portfolio/domain/models/visual_contract_item.dart';
import 'package:abe_app/features/portfolio/presentation/screens/discovery_feed_screen.dart';
import 'package:abe_app/features/store/domain/services/hybrid_inventory_and_store_service.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:abe_app/features/wallet/domain/services/wallet_and_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Shared end-to-end lifecycle test suite invoked by both:
/// - `flutter test test/end_to_end_lifecycle_test.dart`
/// - `flutter test integration_test/abe_end_to_end_lifecycle_test.dart`
void registerAbeLifecycleE2eTests() {
  group('ABE End-to-End Lifecycle Integration (Sub-task 17.2)', () {
    testWidgets(
      'Discovery -> Modifier & Voucher -> Venue Check -> Upfront Payment -> 4-Digit PIN -> Live Camera -> Tech Ledger -> Stock-Up Store -> 75/25 Cancel Split',
      (WidgetTester tester) async {
        const clientId = 'client_e2e_01';
        const bookingId = 'bk_e2e_01';

        final venueService = VenueSelectionService();
        const calculatorService = BookingCalculatorService();
        final walletService = WalletAndLedgerService();
        final startLockService = AppointmentStartLockService();
        final completionLockService = AppointmentCompletionLockService();
        final paymentService = CheckoutPaymentService(
          walletService: walletService,
          startLockService: startLockService,
        );
        final uacMatrix = UacPermissionMatrix();
        final storeService = HybridInventoryAndStoreService(
          uacMatrix: uacMatrix,
          walletService: walletService,
        );

        // ------------------------------------------------------------------
        // Step 1: Discovery Feed -> filter Cape Town -> select first set
        // ------------------------------------------------------------------
        VisualContractItem? pickedContract;
        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: DiscoveryFeedScreen(
              onSelectContract: (item) => pickedContract = item,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_city_CPT')));
        await tester.pumpAndSettle();

        final firstCardFinder = find.byKey(const Key('feed_card_vc_cpt_01'));
        await tester.scrollUntilVisible(
          firstCardFinder,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(firstCardFinder);
        await tester.pumpAndSettle();

        expect(pickedContract, isNotNull);
        final contract = pickedContract!;
        expect(contract.city, 'CPT');

        // ------------------------------------------------------------------
        // Step 2: Modifier & Voucher Toggle -> Confirm Quote
        // ------------------------------------------------------------------
        BookingPriceQuote? confirmedQuote;
        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: VisualContractDetailScreen(
              contract: contract,
              calculatorService: calculatorService,
              onConfirmBooking: (quote) => confirmedQuote = quote,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final firstModifierId = contract.allowedModifiers.first.id;
        final modRow = find.byKey(Key('modifier_row_$firstModifierId'));
        await tester.ensureVisible(modRow);
        await tester.tap(modRow);
        await tester.pumpAndSettle();

        final voucherField = find.byKey(const Key('booking_voucher_input'));
        await tester.ensureVisible(voucherField);
        await tester.enterText(voucherField, 'ABEWELCOME50');
        await tester.tap(find.byKey(const Key('booking_voucher_apply_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('booking_confirm_button')));
        await tester.pumpAndSettle();

        // Tap 'Done' on modal preview if shown so state stays clean
        final modalDone = find.byKey(const Key('modal_done_button'));
        if (modalDone.evaluate().isNotEmpty) {
          await tester.tap(modalDone);
          await tester.pumpAndSettle();
        }

        expect(confirmedQuote, isNotNull);
        final quote = confirmedQuote!;
        expect(quote.selectedLineItems, isNotEmpty);
        expect(quote.appliedVoucherCode, 'ABEWELCOME50');
        expect(quote.voucherDiscountZar, 50);

        // ------------------------------------------------------------------
        // Step 3: Strict Venue-Only Policy Check
        // ------------------------------------------------------------------
        expect(
          () => venueService.validateRawBookingPayload(<String, dynamic>{
            'venueType': 'house_call',
            'venueId': 'private_home_01',
            'address': '10 Oak Avenue, Constantia',
          }),
          throwsArgumentError,
        );

        final verifiedStudio = venueService
            .listVerifiedVenues(city: 'CPT')
            .firstWhere((v) => v.type == CommercialVenueType.verifiedStudio);
        final venueSelection = venueService.selectVerifiedStudio(
          venue: verifiedStudio,
        );
        final bookingPayload = venueService.validateAndBuildBookingPayload(
          bookingId: bookingId,
          clientId: clientId,
          techId: contract.techId,
          visualContractItemId: contract.id,
          venueSelection: venueSelection,
          city: contract.city,
          totalPriceZar: quote.totalPayableZar,
          totalDurationMinutes: quote.totalDurationMinutes,
          scheduledAt: DateTime.utc(2026, 11, 28, 11, 0),
          selectedModifierIds: <String>[firstModifierId],
        );
        expect(bookingPayload.verifiedStudioId, verifiedStudio.id);

        // ------------------------------------------------------------------
        // Step 4: Upfront Payment (R100 ABE Wallet + Paystack ZAR)
        // ------------------------------------------------------------------
        walletService.creditClientWallet(
          clientId: clientId,
          amountCents: 10000, // R100
          idempotencyKey: 'e2e_seed_wallet',
          reason: 'Loyalty refund credit',
        );

        PaymentCheckoutReceipt? paymentReceipt;
        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: CheckoutPaymentScreen(
              bookingId: bookingId,
              clientId: clientId,
              clientEmail: 'amara@abe.co.za',
              contract: contract,
              quote: quote,
              venueSelection: venueSelection,
              paymentService: paymentService,
              onCheckoutConfirmed: (receipt) => paymentReceipt = receipt,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final payButton = find.byKey(const Key('checkout_pay_button'));
        await tester.ensureVisible(payButton);
        await tester.pumpAndSettle();
        await tester.tap(payButton);
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.error_outline_rounded),
          findsNothing,
          reason: 'Unexpected checkout error banner rendered',
        );
        expect(find.text('Booking Confirmed'), findsOneWidget);
        expect(
          find.byKey(const Key('checkout_confirmed_pin_card')),
          findsOneWidget,
        );
        expect(paymentReceipt, isNotNull);
        expect(paymentReceipt!.isConfirmed, isTrue);
        expect(paymentReceipt!.walletAppliedZarCents, 10000);
        final pinCode = paymentReceipt!.clientBookingPin!;
        expect(pinCode.length, 4);

        // ------------------------------------------------------------------
        // Step 5: 4-Digit PIN & Biometric Appointment Start Lock
        // ------------------------------------------------------------------
        AppointmentStartOutcome? startOutcome;
        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: TechStartAppointmentScreen(
              bookingId: bookingId,
              techId: contract.techId,
              clientName: 'Amara',
              lookTitle: contract.title,
              venueName: verifiedStudio.name,
              priceZar: quote.totalPayableZar,
              durationMinutes: quote.totalDurationMinutes,
              lockService: startLockService,
              onAppointmentStarted: (outcome) => startOutcome = outcome,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Complete biometric check
        final biometricBtn = find.byKey(const Key('start_biometric_button'));
        await tester.ensureVisible(biometricBtn);
        await tester.tap(biometricBtn);
        await tester.pumpAndSettle();

        // Try 1 wrong PIN first and verify lockout counter decrements to 4
        final wrongDigit = pinCode[0] == '0' ? '1' : '0';
        for (var i = 0; i < 4; i++) {
          final btn = find.byKey(Key('pin_digit_$wrongDigit'));
          await tester.ensureVisible(btn);
          await tester.tap(btn);
        }
        await tester.pump();
        final submitBtn = find.byKey(const Key('start_appointment_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          startLockService
              .getTechLockStatus(bookingId: bookingId, techId: contract.techId)
              .remainingAttempts,
          4,
        );

        // Enter exact matching 4-digit client PIN
        for (var i = 0; i < 4; i++) {
          final btn = find.byKey(Key('pin_digit_${pinCode[i]}'));
          await tester.ensureVisible(btn);
          await tester.tap(btn);
        }
        await tester.pump();
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(startOutcome, isNotNull);
        expect(startOutcome!.success, isTrue);
        expect(startOutcome!.bookingStatus, 'in_progress');
        completionLockService.setBookingStatus(
          bookingId,
          'in_progress',
          techId: contract.techId,
        );

        // ------------------------------------------------------------------
        // Step 6: Live Camera Completion Lock (gallery rejected; camera only)
        // ------------------------------------------------------------------
        expect(
          () => LiveCaptureSource.requireCamera('gallery'),
          throwsArgumentError,
        );

        final capturedPhoto =
            await completionLockService.captureLiveCompletionPhoto(
          bookingId: bookingId,
          techId: contract.techId,
        );
        expect(capturedPhoto, isNotNull);
        expect(capturedPhoto!.source, LiveCaptureSource.camera);

        final completionOutcome =
            await completionLockService.submitLiveCompletionPhoto(
          bookingId: bookingId,
          techId: contract.techId,
          photo: capturedPhoto,
        );
        expect(completionOutcome.completed, isTrue);
        expect(completionOutcome.bookingStatus, 'completed');
        expect(completionOutcome.payoutMovedToPendingLedger, isTrue);
        expect(completionOutcome.completionPhotoUrl, startsWith('https://'));

        // ------------------------------------------------------------------
        // Step 7: Tech Ledger Settlement (15% Fee / 85% Net) & Stock-Up Store Order
        // ------------------------------------------------------------------
        final grossCents = quote.subtotalPriceZar * 100;
        final expectedFeeCents = (grossCents * 0.15).round();
        final expectedNetCents = grossCents - expectedFeeCents;

        walletService.recordCompletedBookingSettlement(
          bookingId: bookingId,
          techId: contract.techId,
          grossAmountCents: grossCents,
          completionPhotoUrl: completionOutcome.completionPhotoUrl,
          idempotencyKey: 'e2e_settle_$bookingId',
        );

        final techAccount = walletService.getTechAccount(contract.techId);
        expect(techAccount.unpaidNetEarningsCents, expectedNetCents);
        expect(walletService.platformRevenueCents, expectedFeeCents);

        final initialBiabStock = storeService.products
            .firstWhere((p) => p.id == 'prod_biab_rose')
            .stockQuantity;
        final storeOrder = storeService.placeTechStoreOrder(
          techId: contract.techId,
          productIds: const <String>['prod_biab_rose'],
          pargoPickupPointCode: 'PARGO_CPT_CLAREMONT_01',
          idempotencyKey: 'e2e_store_ord_01',
        );
        expect(storeOrder.totalAmountZar, 240);
        expect(storeOrder.status, 'pending_fulfilment');
        expect(
          storeService.products
              .firstWhere((p) => p.id == 'prod_biab_rose')
              .stockQuantity,
          initialBiabStock - 1,
        );
        expect(
          walletService.getTechAccount(contract.techId).openStoreOrdersCents,
          24000,
        );

        // ------------------------------------------------------------------
        // Step 8: 75/25 Client Late Cancellation Split + Closed-Loop Guard
        // ------------------------------------------------------------------
        final cancelOutcome = walletService.processCancellationSplit(
          bookingId: 'bk_e2e_cancel_01',
          clientId: clientId,
          techId: contract.techId,
          paidAmountCents: 40000, // R400 paid upfront
          cancelledByTech: false,
          idempotencyKey: 'e2e_cancel_75_25',
        );
        expect(cancelOutcome.clientWalletCreditedCents, 30000); // 75%
        expect(cancelOutcome.techCompensatedCents, 10000); // 25%
        expect(walletService.getClientWallet(clientId).balanceCents, 30000);
        expect(
          walletService.getTechAccount(contract.techId).unpaidNetEarningsCents,
          expectedNetCents + 10000,
        );

        // Closed-loop wallet must never allow cash withdrawal
        expect(
          () => walletService.withdrawClientWalletToBank(
            clientId: clientId,
            amountCents: 10000,
          ),
          throwsUnsupportedError,
        );
      },
    );
  });
}

void main() {
  registerAbeLifecycleE2eTests();
}
