import 'package:abe_app/core/config/feature_flags.dart';
import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/auth/domain/models/tech_profile.dart';
import 'package:abe_app/features/booking/domain/models/booking_modifier.dart';
import 'package:abe_app/features/booking/domain/models/booking_venue_models.dart';
import 'package:abe_app/features/booking/domain/services/appointment_start_lock_service.dart';
import 'package:abe_app/features/payment/domain/models/payment_models.dart';
import 'package:abe_app/features/payment/domain/services/checkout_payment_service.dart';
import 'package:abe_app/features/payment/domain/services/payment_gateway_adapter.dart';
import 'package:abe_app/features/payment/presentation/screens/checkout_payment_screen.dart';
import 'package:abe_app/features/portfolio/domain/models/visual_contract_item.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:abe_app/features/wallet/domain/services/wallet_and_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  VisualContractItem buildSampleContract() {
    return VisualContractItem(
      id: 'vc_cpt_pay_01',
      techId: 'tech_naledi_01',
      techDisplayName: 'Naledi M.',
      techTierBadge: TechTierBadge.certifiedPro,
      photoUrl: 'https://cdn.abe.co.za/looks/biab_french.jpg',
      title: 'Sculpted Almond BIAB & Micro French',
      basePriceZar: 500,
      baseDurationMinutes: 90,
      city: 'CPT',
      venueId: 'venue_cpt_claremont_01',
      venueName: 'The Rose Atelier Studio',
      venueType: CommercialVenueType.verifiedStudio,
      styleCategory: 'BIAB & Structured Gel',
      allowedModifiers: const <ContractModifier>[],
    );
  }

  BookingVenueSelection buildVerifiedVenueSelection() {
    return BookingVenueSelection(
      venueType: BookingVenueType.verifiedStudio,
      verifiedStudioId: 'venue_cpt_claremont_01',
      venue: CommercialVenue(
        id: 'venue_cpt_claremont_01',
        name: 'The Rose Atelier Studio',
        city: 'CPT',
        suburb: 'Claremont',
        address: '42 Vineyard Road, Claremont, Cape Town',
        type: CommercialVenueType.verifiedStudio,
        isVerified: true,
      ),
    );
  }

  BookingPriceQuote buildQuote({int totalZar = 500}) {
    final platformFee = (totalZar * 0.15).round();
    return BookingPriceQuote(
      basePriceZar: totalZar,
      baseDurationMinutes: 90,
      modifiersPriceZar: 0,
      modifiersDurationMinutes: 0,
      subtotalPriceZar: totalZar,
      voucherDiscountZar: 0,
      totalPayableZar: totalZar,
      totalDurationMinutes: 90,
      platformFeeZar: platformFee,
      techNetPayoutZar: totalZar - platformFee,
      selectedLineItems: const <BookingModifierLineItem>[],
    );
  }

  group('CheckoutPaymentService (Item 16.1)', () {
    test(
      'auto-applies voucher + closed-loop ABE Wallet before charging remainder via Paystack Card with tokenisation',
      () async {
        final walletService = WalletAndLedgerService();
        walletService.creditClientWallet(
          clientId: 'client_zara',
          amountCents: 15000, // R150 wallet credit
          idempotencyKey: 'seed_wallet_zara',
          reason: 'Prior refund credit',
        );
        final lockService = AppointmentStartLockService();
        final paymentService = CheckoutPaymentService(
          walletService: walletService,
          startLockService: lockService,
        );

        // R500 subtotal - R100 (R1_EVENT) - R150 wallet = R250 due on Paystack
        final req = PaymentCheckoutRequest(
          bookingId: 'bk_ps_001',
          clientId: 'client_zara',
          techId: 'tech_naledi_01',
          clientEmail: 'zara@abe.co.za',
          quote: buildQuote(totalZar: 500),
          venueSelection: buildVerifiedVenueSelection(),
          paymentMethod: PaymentMethodType.card,
          preferredCardOrEftProvider: PaymentGatewayProvider.paystack,
          voucherCode: 'R1_EVENT',
          saveCardForFutureBookings: true,
          idempotencyKey: 'idem_ps_001',
        );

        final pending = await paymentService.initiateCheckout(req);
        expect(pending.status, 'pending_gateway');
        expect(pending.grossTotalZarCents, 50000);
        expect(pending.voucherDiscountZarCents, 10000);
        expect(pending.walletAppliedZarCents, 15000);
        expect(pending.gatewayChargedZarCents, 25000);
        expect(pending.provider, PaymentGatewayProvider.paystack);
        expect(
          walletService.getClientWallet('client_zara').balanceCents,
          0,
        );

        final confirmed = await paymentService.confirmGatewayPayment(
          idempotencyKey: 'idem_ps_001',
        );
        expect(confirmed.isConfirmed, isTrue);
        expect(confirmed.savedCardToken, isNotNull);
        expect(confirmed.savedCardToken!.last4, '4242');
        expect(confirmed.clientBookingPin, isNotNull);
        expect(confirmed.clientBookingPin!.length, 4);

        // Idempotent replay returns exact same receipt without double debit
        final replay = await paymentService.initiateCheckout(req);
        expect(replay.reference, confirmed.reference);
        expect(replay.clientBookingPin, confirmed.clientBookingPin);
      },
    );

    test(
      'supports Peach Payments Instant EFT and PayJustNow 3x BNPL gated by feature flag',
      () async {
        final walletService = WalletAndLedgerService();
        final lockService = AppointmentStartLockService();
        final flags = FeatureFlagsService();
        final paymentService = CheckoutPaymentService(
          walletService: walletService,
          startLockService: lockService,
          featureFlags: flags,
        );

        // 1. Peach Payments Instant EFT
        final eftReq = PaymentCheckoutRequest(
          bookingId: 'bk_pp_002',
          clientId: 'client_lerato',
          techId: 'tech_naledi_01',
          clientEmail: 'lerato@abe.co.za',
          quote: buildQuote(totalZar: 600),
          venueSelection: buildVerifiedVenueSelection(),
          paymentMethod: PaymentMethodType.instantEft,
          preferredCardOrEftProvider: PaymentGatewayProvider.peachPayments,
          idempotencyKey: 'idem_pp_002',
        );

        final eftPending = await paymentService.initiateCheckout(eftReq);
        expect(eftPending.provider, PaymentGatewayProvider.peachPayments);
        expect(eftPending.method, PaymentMethodType.instantEft);
        expect(eftPending.gatewayChargedZarCents, 60000);
        final eftConfirmed = await paymentService.confirmGatewayPayment(
          idempotencyKey: 'idem_pp_002',
        );
        expect(eftConfirmed.isConfirmed, isTrue);

        // 2. PayJustNow 3x BNPL when enabled
        final pjnReq = PaymentCheckoutRequest(
          bookingId: 'bk_pjn_003',
          clientId: 'client_lerato',
          techId: 'tech_naledi_01',
          clientEmail: 'lerato@abe.co.za',
          quote: buildQuote(totalZar: 601),
          venueSelection: buildVerifiedVenueSelection(),
          paymentMethod: PaymentMethodType.bnplPayJustNow,
          idempotencyKey: 'idem_pjn_003',
        );

        final pjnPending = await paymentService.initiateCheckout(pjnReq);
        expect(pjnPending.provider, PaymentGatewayProvider.payJustNow);
        final plan = pjnPending.session?.instalmentPlan;
        expect(plan, isNotNull);
        expect(
          plan!.firstInstalmentCents +
              plan.secondInstalmentCents +
              plan.thirdInstalmentCents,
          60100,
        );

        // 3. PayJustNow blocked when feature flag disabled
        flags.setFlag(FeatureFlagsService.payJustNowBnpl, enabled: false);
        expect(
          () => paymentService.initiateCheckout(
            PaymentCheckoutRequest(
              bookingId: 'bk_pjn_004',
              clientId: 'client_lerato',
              techId: 'tech_naledi_01',
              clientEmail: 'lerato@abe.co.za',
              quote: buildQuote(totalZar: 400),
              venueSelection: buildVerifiedVenueSelection(),
              paymentMethod: PaymentMethodType.bnplPayJustNow,
              idempotencyKey: 'idem_pjn_004',
            ),
          ),
          throwsStateError,
        );
      },
    );

    test(
      'confirms immediately when closed-loop ABE Wallet covers 100% and rejects Paystack secret keys in client adapter',
      () async {
        expect(
          () => PaystackGatewayAdapter(publicKey: 'sk_live_forbidden'),
          throwsArgumentError,
        );

        final walletService = WalletAndLedgerService();
        walletService.creditClientWallet(
          clientId: 'client_mia',
          amountCents: 60000,
          idempotencyKey: 'seed_wallet_mia',
          reason: 'Tech cancellation credit',
        );
        final lockService = AppointmentStartLockService();
        final paymentService = CheckoutPaymentService(
          walletService: walletService,
          startLockService: lockService,
        );

        final receipt = await paymentService.initiateCheckout(
          PaymentCheckoutRequest(
            bookingId: 'bk_wallet_full',
            clientId: 'client_mia',
            techId: 'tech_naledi_01',
            clientEmail: 'mia@abe.co.za',
            quote: buildQuote(totalZar: 450),
            venueSelection: buildVerifiedVenueSelection(),
            paymentMethod: PaymentMethodType.walletFullCover,
            idempotencyKey: 'idem_wallet_full',
          ),
        );

        expect(receipt.isConfirmed, isTrue);
        expect(receipt.provider, PaymentGatewayProvider.abeWallet);
        expect(receipt.walletAppliedZarCents, 45000);
        expect(receipt.gatewayChargedZarCents, 0);
        expect(receipt.clientBookingPin, isNotNull);
        expect(walletService.getClientWallet('client_mia').balanceCents, 15000);
      },
    );
  });

  group('CheckoutPaymentScreen Widget Tests (Item 16.1)', () {
    testWidgets(
      'applies voucher + ABE Wallet, selects PayJustNow BNPL, confirms booking and displays 4-digit PIN',
      (WidgetTester tester) async {
        final walletService = WalletAndLedgerService();
        walletService.creditClientWallet(
          clientId: 'client_ui_01',
          amountCents: 10000, // R100
          idempotencyKey: 'seed_ui_wallet',
          reason: 'Refund credit',
        );
        final paymentService = CheckoutPaymentService(
          walletService: walletService,
          startLockService: AppointmentStartLockService(),
        );

        PaymentCheckoutReceipt? confirmedReceipt;

        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: CheckoutPaymentScreen(
              bookingId: 'bk_ui_01',
              clientId: 'client_ui_01',
              clientEmail: 'client@abe.co.za',
              contract: buildSampleContract(),
              quote: buildQuote(totalZar: 500),
              venueSelection: buildVerifiedVenueSelection(),
              paymentService: paymentService,
              onCheckoutConfirmed: (receipt) => confirmedReceipt = receipt,
            ),
          ),
        );

        expect(find.text('Secure ZAR Checkout'), findsOneWidget);
        expect(find.text('Pay R400 Securely'), findsOneWidget);

        // Apply R1_EVENT voucher (R100 off -> R300 remaining)
        await tester.enterText(
          find.byKey(const Key('checkout_voucher_input')),
          'R1_EVENT',
        );
        await tester.tap(find.byKey(const Key('checkout_apply_voucher_button')));
        await tester.pumpAndSettle();

        expect(find.text('Pay R300 Securely'), findsOneWidget);

        // Select PayJustNow BNPL
        final pjnOption = find.byKey(const Key('payment_method_payjustnow'));
        await tester.ensureVisible(pjnOption);
        await tester.tap(pjnOption);
        await tester.pumpAndSettle();

        // Tap Pay R300 Securely
        final payButton = find.byKey(const Key('checkout_pay_button'));
        await tester.ensureVisible(payButton);
        await tester.tap(payButton);
        await tester.pumpAndSettle();

        expect(find.text('Booking Confirmed'), findsOneWidget);
        expect(
          find.byKey(const Key('checkout_confirmed_pin_card')),
          findsOneWidget,
        );
        expect(confirmedReceipt, isNotNull);
        expect(confirmedReceipt!.provider, PaymentGatewayProvider.payJustNow);
        expect(confirmedReceipt!.gatewayChargedZarCents, 30000);
      },
    );

    testWidgets(
      'meets Flutter tap target, labelled target, and text contrast accessibility guidelines on CheckoutPaymentScreen',
      (WidgetTester tester) async {
        final semanticsHandle = tester.ensureSemantics();
        try {
          final walletService = WalletAndLedgerService();
          final paymentService = CheckoutPaymentService(
            walletService: walletService,
            startLockService: AppointmentStartLockService(),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AbeTheme.lightTheme,
              home: CheckoutPaymentScreen(
                bookingId: 'bk_a11y_01',
                clientId: 'client_a11y_01',
                clientEmail: 'a11y@abe.co.za',
                contract: buildSampleContract(),
                quote: buildQuote(totalZar: 450),
                venueSelection: buildVerifiedVenueSelection(),
                paymentService: paymentService,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          semanticsHandle.dispose();
        }
      },
    );

    test(
      'security audit checks: blocks extended residential terms, rejects invalid email/card expiry, and preserves wallet on flag block',
      () async {
        expect(
          () => CommercialVenue(
            id: 'ven_bad_01',
            name: 'Private Residential Loft',
            address: '12 Oak Lane',
            suburb: 'Sea Point',
            city: 'CPT',
            type: CommercialVenueType.verifiedStudio,
            isVerified: true,
          ),
          throwsArgumentError,
        );

        expect(
          () => SavedCardToken(
            id: 'card_bad_yr',
            clientId: 'client_01',
            provider: PaymentGatewayProvider.paystack,
            authorizationCode: 'AUTH_test',
            last4: '4242',
            cardBrand: 'Visa',
            expiryMonth: '12',
            expiryYear: 'abcd',
          ),
          throwsArgumentError,
        );

        expect(
          () => PaymentCheckoutRequest(
            bookingId: 'bk_bad_email',
            clientId: 'client_01',
            techId: 'tech_naledi_01',
            clientEmail: 'not-an-email@invalid',
            quote: buildQuote(totalZar: 400),
            venueSelection: buildVerifiedVenueSelection(),
            paymentMethod: PaymentMethodType.card,
            idempotencyKey: 'idem_bad_email',
          ),
          throwsArgumentError,
        );

        final flags = FeatureFlagsService(
          initialFlags: const <String, bool>{
            FeatureFlagsService.payJustNowBnpl: false,
          },
        );
        final walletService = WalletAndLedgerService();
        walletService.creditClientWallet(
          clientId: 'client_guard',
          amountCents: 10000,
          idempotencyKey: 'seed_guard_wallet',
          reason: 'Guard test credit',
        );
        final paymentService = CheckoutPaymentService(
          walletService: walletService,
          startLockService: AppointmentStartLockService(),
          featureFlags: flags,
        );

        await expectLater(
          paymentService.initiateCheckout(
            PaymentCheckoutRequest(
              bookingId: 'bk_guard_01',
              clientId: 'client_guard',
              techId: 'tech_naledi_01',
              clientEmail: 'guard@abe.co.za',
              quote: buildQuote(totalZar: 450),
              venueSelection: buildVerifiedVenueSelection(),
              paymentMethod: PaymentMethodType.bnplPayJustNow,
              voucherCode: 'R1_EVENT',
              idempotencyKey: 'idem_guard_01',
            ),
          ),
          throwsStateError,
        );
        // Wallet must remain intact if pre-flight flag check fails.
        expect(walletService.getClientWallet('client_guard').balanceCents, 10000);
      },
    );
  });
}
