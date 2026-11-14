import 'package:abe_app/features/wallet/domain/models/wallet_ledger_models.dart';
import 'package:abe_app/features/wallet/domain/services/coupon_voucher_service.dart';
import 'package:abe_app/features/wallet/domain/services/wallet_and_ledger_service.dart';
import 'package:abe_app/features/wallet/presentation/screens/client_wallet_screen.dart';
import 'package:abe_app/features/wallet/presentation/screens/tech_earnings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _MutableClock {
  _MutableClock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  group('WalletAndLedgerService (Item 14)', () {
    test('deducts 15% platform fee, credits 85% tech net earnings, and enforces idempotencyKey + completionPhotoUrl', () {
      final service = WalletAndLedgerService();

      expect(
        () => service.recordCompletedBookingSettlement(
          bookingId: 'bk_1',
          techId: 'tech_1',
          grossAmountCents: 100000,
          completionPhotoUrl: '',
          idempotencyKey: 'settle_bk_1',
        ),
        throwsStateError,
      );

      service.recordCompletedBookingSettlement(
        bookingId: 'bk_1',
        techId: 'tech_1',
        grossAmountCents: 100000, // R1000.00
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_1.jpg',
        idempotencyKey: 'settle_bk_1',
      );

      // Duplicate call with same idempotencyKey must not double-credit.
      service.recordCompletedBookingSettlement(
        bookingId: 'bk_1',
        techId: 'tech_1',
        grossAmountCents: 100000,
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_1.jpg',
        idempotencyKey: 'settle_bk_1',
      );

      expect(service.platformRevenueCents, equals(15000));
      expect(service.getTechAccount('tech_1').unpaidNetEarningsCents, equals(85000));
    });

    test('enforces closed-loop client wallet (auto-applied at checkout, zero cash withdrawal)', () {
      final service = WalletAndLedgerService();
      final wallet = service.creditClientWallet(
        clientId: 'client_1',
        amountCents: 30000,
        idempotencyKey: 'cred_1',
        reason: 'Refund credit',
      );
      expect(wallet.supportsCashWithdrawal, isFalse);

      expect(
        () => service.withdrawClientWalletToBank(
          clientId: 'client_1',
          amountCents: 10000,
        ),
        throwsUnsupportedError,
      );

      final checkout = service.applyClientWalletAtCheckout(
        clientId: 'client_1',
        bookingTotalCents: 45000,
        idempotencyKey: 'chk_1',
        bookingId: 'bk_chk_1',
      );
      expect(checkout.walletAppliedCents, equals(30000));
      expect(checkout.remainingGatewayDueCents, equals(15000));
      expect(checkout.remainingWalletBalanceCents, equals(0));
    });

    test('computes Store Credit allowance and processes scheduled & instant payouts idempotently', () {
      final service = WalletAndLedgerService();
      service.recordCompletedBookingSettlement(
        bookingId: 'bk_2',
        techId: 'tech_2',
        grossAmountCents: 200000, // R2000 gross -> R1700 net
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_2.jpg',
        idempotencyKey: 'settle_bk_2',
      );

      final afterOrder = service.reserveStockUpStoreOrder(
        techId: 'tech_2',
        orderId: 'ord_1',
        orderTotalCents: 50000, // R500 open store order
        idempotencyKey: 'ord_res_1',
      );
      expect(afterOrder.availableStoreCreditCents, equals(120000)); // R1200

      // Cannot reserve beyond Available Store Credit
      expect(
        () => service.reserveStockUpStoreOrder(
          techId: 'tech_2',
          orderId: 'ord_2',
          orderTotalCents: 130000,
          idempotencyKey: 'ord_res_2',
        ),
        throwsStateError,
      );

      // Instant Cash-Out of R400 (40000 cents) -> 2.5% = R10.00 (1000 cents fee), net R390
      final instant1 = service.requestInstantCashOut(
        techId: 'tech_2',
        requestedAmountCents: 40000,
        idempotencyKey: 'inst_1',
      );
      final instant2 = service.requestInstantCashOut(
        techId: 'tech_2',
        requestedAmountCents: 40000,
        idempotencyKey: 'inst_1',
      );
      expect(instant1.id, equals(instant2.id));
      expect(instant1.convenienceFeeCents, equals(1000));
      expect(instant1.netPayoutCents, equals(39000));

      // Remaining withdrawable for scheduled payout: 170000 - 40000 - 50000 = 80000
      final scheduled = service.processScheduledTechPayout(
        techId: 'tech_2',
        idempotencyKey: 'sched_1',
      );
      expect(scheduled.netPayoutCents, equals(80000));
      expect(scheduled.convenienceFeeCents, equals(0));
    });

    test('processes 75/25 client late cancellation and 100% + apology voucher tech cancellation', () {
      final service = WalletAndLedgerService();

      final clientLate = service.processCancellationSplit(
        bookingId: 'bk_late',
        clientId: 'client_a',
        techId: 'tech_a',
        paidAmountCents: 40000,
        cancelledByTech: false,
        idempotencyKey: 'cancel_late_1',
      );
      expect(clientLate.clientWalletCreditedCents, equals(30000));
      expect(clientLate.techCompensatedCents, equals(10000));
      expect(service.getClientWallet('client_a').balanceCents, equals(30000));
      expect(service.getTechAccount('tech_a').unpaidNetEarningsCents, equals(10000));

      final techCancel = service.processCancellationSplit(
        bookingId: 'bk_tech_x',
        clientId: 'client_b',
        techId: 'tech_b',
        paidAmountCents: 50000,
        cancelledByTech: true,
        idempotencyKey: 'cancel_tech_1',
      );
      expect(techCancel.clientWalletCreditedCents, equals(50000));
      expect(techCancel.techCompensatedCents, equals(0));
      expect(techCancel.apologyVoucher, isNotNull);
      expect(techCancel.apologyVoucher!.maxRedemptions, equals(1));
      expect(techCancel.apologyVoucher!.assignedToUserId, equals('client_b'));
    });

    test('CouponVoucherService enforces percentage/fixed, per-user limits, pause, and rate limiting', () {
      final clock = _MutableClock(DateTime.utc(2026, 11, 14, 12, 0));
      final vouchers = CouponVoucherService(clock: clock.call);
      vouchers.createOrUpdateCoupon(
        PromoCouponRecord(
          id: 'v_inf',
          code: 'AQEELAH20',
          discountType: VoucherDiscountType.percentage,
          discountValue: 20,
          minSpendZar: 300,
          maxRedemptions: 2,
          perUserLimit: 1,
          expiresAtUtc: clock.now.add(const Duration(days: 7)),
        ),
      );

      final first = vouchers.redeemCoupon(
        rawCode: 'aqeelah20',
        userId: 'user_1',
        subtotalZar: 500,
      );
      expect(first.valid, isTrue);
      expect(first.discountZar, equals(100));

      final secondSameUser = vouchers.redeemCoupon(
        rawCode: 'AQEELAH20',
        userId: 'user_1',
        subtotalZar: 500,
      );
      expect(secondSameUser.valid, isFalse);

      // Pause coupon
      vouchers.setCouponActive('AQEELAH20', isActive: false);
      final paused = vouchers.validateCoupon(
        rawCode: 'AQEELAH20',
        userId: 'user_2',
        subtotalZar: 500,
      );
      expect(paused.valid, isFalse);

      // Rate-limit check after 10 rapid checks
      for (var i = 0; i < 10; i++) {
        vouchers.validateCoupon(
          rawCode: 'GUESS_$i',
          userId: 'attacker_1',
          subtotalZar: 500,
        );
      }
      final throttled = vouchers.validateCoupon(
        rawCode: 'R1_EVENT',
        userId: 'attacker_1',
        subtotalZar: 500,
      );
      expect(throttled.rateLimited, isTrue);
      expect(throttled.valid, isFalse);
    });
  });

  group('Wallet & Earnings UI Widget Tests (Item 14)', () {
    testWidgets('ClientWalletScreen renders balance, non-withdrawable notice, and apology vouchers', (tester) async {
      final service = WalletAndLedgerService();
      service.processCancellationSplit(
        bookingId: 'bk_ui_c',
        clientId: 'client_ui',
        techId: 'tech_ui',
        paidAmountCents: 45000,
        cancelledByTech: true,
        idempotencyKey: 'ui_cancel_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWalletScreen(
            clientId: 'client_ui',
            walletService: service,
          ),
        ),
      );

      expect(find.text('R450.00'), findsOneWidget);
      expect(find.textContaining('non-withdrawable'), findsOneWidget);
      expect(find.text('R1_EVENT'), findsOneWidget);
    });

    testWidgets('TechEarningsScreen renders pending payout, Store Credit, and executes Instant Cash-Out', (tester) async {
      final service = WalletAndLedgerService();
      service.recordCompletedBookingSettlement(
        bookingId: 'bk_ui_t',
        techId: 'tech_ui',
        grossAmountCents: 100000, // R850 net
        completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_ui_t.jpg',
        idempotencyKey: 'ui_settle_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TechEarningsScreen(
            techId: 'tech_ui',
            walletService: service,
          ),
        ),
      );

      expect(find.text('R850.00'), findsWidgets);
      final cashOutBtn = find.byKey(const Key('tech_instant_cashout_button'));
      await tester.ensureVisible(cashOutBtn);
      await tester.pumpAndSettle();
      await tester.tap(cashOutBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tech_earnings_status_banner')), findsOneWidget);
      expect(service.getTechAccount('tech_ui').unpaidNetEarningsCents, equals(0));
    });
  });
}
