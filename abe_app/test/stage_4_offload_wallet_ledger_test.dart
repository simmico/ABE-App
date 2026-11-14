import 'package:abe_app/features/wallet/domain/models/wallet_ledger_models.dart';
import 'package:abe_app/features/wallet/domain/services/coupon_voucher_service.dart';
import 'package:abe_app/features/wallet/domain/services/wallet_and_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

void main() {
  group('Stage 4A: Double-Entry Ledger & Completion Photo Lock', () {
    test(
      'computes 15% platform fee and 85% tech net split across multiple gross amounts',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 10, 0));
        final service = WalletAndLedgerService(clock: clock.call);

        final cases = <({
          String bookingId,
          String techId,
          int grossCents,
          int expectedFeeCents,
          int expectedTechNetCents,
        })>[
          (
            bookingId: 'bk_split_1',
            techId: 'tech_cpt_1',
            grossCents: 45000, // R450.00
            expectedFeeCents: 6750, // R67.50
            expectedTechNetCents: 38250, // R382.50
          ),
          (
            bookingId: 'bk_split_2',
            techId: 'tech_cpt_1',
            grossCents: 100000, // R1,000.00
            expectedFeeCents: 15000, // R150.00
            expectedTechNetCents: 85000, // R850.00
          ),
          (
            bookingId: 'bk_split_3',
            techId: 'tech_jhb_2',
            grossCents: 67500, // R675.00
            expectedFeeCents: 10125, // R101.25
            expectedTechNetCents: 57375, // R573.75
          ),
          (
            bookingId: 'bk_split_4',
            techId: 'tech_jhb_2',
            grossCents: 33333, // R333.33 rounding check
            expectedFeeCents: 5000,
            expectedTechNetCents: 28333,
          ),
        ];

        var expectedTotalGmv = 0;
        var expectedTotalPlatformRevenue = 0;

        for (var i = 0; i < cases.length; i++) {
          final item = cases[i];
          clock.advance(const Duration(minutes: 5));

          service.recordCompletedBookingSettlement(
            bookingId: item.bookingId,
            techId: item.techId,
            grossAmountCents: item.grossCents,
            completionPhotoUrl:
                'https://storage.abe.co.za/completions/${item.bookingId}.jpg',
            idempotencyKey: 'settle_${item.bookingId}',
          );

          expectedTotalGmv += item.grossCents;
          expectedTotalPlatformRevenue += item.expectedFeeCents;

          expect(service.isBookingSettled(item.bookingId), isTrue);
          expect(
            item.expectedFeeCents + item.expectedTechNetCents,
            equals(item.grossCents),
          );

          final bookingEntries = service.ledgerEntries
              .where((entry) => entry.bookingId == item.bookingId)
              .toList();
          expect(bookingEntries, hasLength(2));

          final feeEntry = bookingEntries.firstWhere(
            (e) => e.entryType == LedgerEntryType.platformCommission,
          );
          final techEntry = bookingEntries.firstWhere(
            (e) => e.entryType == LedgerEntryType.techPendingEarning,
          );

          expect(feeEntry.userId, equals('abe_platform'));
          expect(feeEntry.direction, equals('credit'));
          expect(feeEntry.amountZarCents, equals(item.expectedFeeCents));

          expect(techEntry.userId, equals(item.techId));
          expect(techEntry.direction, equals('credit'));
          expect(techEntry.amountZarCents, equals(item.expectedTechNetCents));
        }

        expect(service.totalGmvCents, equals(expectedTotalGmv));
        expect(
          service.platformRevenueCents,
          equals(expectedTotalPlatformRevenue),
        );
        expect(
          service.getTechAccount('tech_cpt_1').unpaidNetEarningsCents,
          equals(38250 + 85000),
        );
        expect(
          service.getTechAccount('tech_jhb_2').unpaidNetEarningsCents,
          equals(57375 + 28333),
        );
        expect(service.ledgerEntries, hasLength(cases.length * 2));
      },
    );

    test(
      'rejects settlement when completionPhotoUrl is missing, empty, or non-HTTPS',
      () {
        final service = WalletAndLedgerService();
        const invalidPhotoUrls = <String?>[
          null,
          '',
          '   ',
          'http://storage.abe.co.za/completions/insecure.jpg',
          'file:///storage/emulated/0/DCIM/nails.jpg',
          'completions/relative_path.jpg',
        ];

        for (var i = 0; i < invalidPhotoUrls.length; i++) {
          final photoUrl = invalidPhotoUrls[i];
          expect(
            () => service.recordCompletedBookingSettlement(
              bookingId: 'bk_invalid_$i',
              techId: 'tech_cpt_1',
              grossAmountCents: 50000,
              completionPhotoUrl: photoUrl,
              idempotencyKey: 'settle_invalid_$i',
            ),
            throwsStateError,
          );
          expect(service.isBookingSettled('bk_invalid_$i'), isFalse);
        }

        expect(service.platformRevenueCents, equals(0));
        expect(service.totalGmvCents, equals(0));
        expect(service.ledgerEntries, isEmpty);
        expect(
          service.getTechAccount('tech_cpt_1').unpaidNetEarningsCents,
          equals(0),
        );
      },
    );

    test(
      'rejects double settlement of the same bookingId under a different idempotencyKey',
      () {
        final service = WalletAndLedgerService();
        service.recordCompletedBookingSettlement(
          bookingId: 'bk_unique_1',
          techId: 'tech_1',
          grossAmountCents: 80000,
          completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_1.jpg',
          idempotencyKey: 'settle_key_a',
        );

        expect(
          () => service.recordCompletedBookingSettlement(
            bookingId: 'bk_unique_1',
            techId: 'tech_1',
            grossAmountCents: 80000,
            completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_1.jpg',
            idempotencyKey: 'settle_key_b',
          ),
          throwsStateError,
        );

        expect(service.ledgerEntries, hasLength(2));
        expect(service.totalGmvCents, equals(80000));
      },
    );
  });

  group('Stage 4A: Closed-Loop Client Wallet', () {
    test(
      'withdrawClientWalletToBank always throws UnsupportedError regardless of balance',
      () {
        final service = WalletAndLedgerService();

        expect(
          () => service.withdrawClientWalletToBank(
            clientId: 'client_empty',
            amountCents: 1000,
          ),
          throwsUnsupportedError,
        );

        final fundedWallet = service.creditClientWallet(
          clientId: 'client_funded',
          amountCents: 50000,
          idempotencyKey: 'credit_funded_1',
          reason: 'Apology refund credit',
        );
        expect(fundedWallet.supportsCashWithdrawal, isFalse);
        expect(fundedWallet.balanceCents, equals(50000));

        expect(
          () => service.withdrawClientWalletToBank(
            clientId: 'client_funded',
            amountCents: 25000,
          ),
          throwsUnsupportedError,
        );
        expect(
          service.getClientWallet('client_funded').balanceCents,
          equals(50000),
        );
      },
    );

    test(
      'applyClientWalletAtCheckout atomically deducts available credit and returns remaining gateway balance',
      () {
        final service = WalletAndLedgerService();

        // Case 1: Partial coverage (R300.00 wallet against R450.00 booking).
        service.creditClientWallet(
          clientId: 'client_partial',
          amountCents: 30000,
          idempotencyKey: 'cred_partial',
          reason: 'Late cancellation refund',
        );

        final partialResult = service.applyClientWalletAtCheckout(
          clientId: 'client_partial',
          bookingTotalCents: 45000,
          idempotencyKey: 'chk_partial',
          bookingId: 'bk_partial',
        );
        expect(partialResult.bookingTotalCents, equals(45000));
        expect(partialResult.walletAppliedCents, equals(30000));
        expect(partialResult.remainingGatewayDueCents, equals(15000));
        expect(partialResult.remainingWalletBalanceCents, equals(0));
        expect(
          service.getClientWallet('client_partial').balanceCents,
          equals(0),
        );

        final spendEntries = service.ledgerEntries
            .where((e) => e.entryType == LedgerEntryType.clientWalletSpend)
            .toList();
        expect(spendEntries, hasLength(1));
        expect(spendEntries.single.direction, equals('debit'));
        expect(spendEntries.single.amountZarCents, equals(30000));

        // Case 2: Full coverage (R600.00 wallet against R350.00 booking).
        service.creditClientWallet(
          clientId: 'client_full',
          amountCents: 60000,
          idempotencyKey: 'cred_full',
          reason: 'Full refund credit',
        );
        final fullResult = service.applyClientWalletAtCheckout(
          clientId: 'client_full',
          bookingTotalCents: 35000,
          idempotencyKey: 'chk_full',
          bookingId: 'bk_full',
        );
        expect(fullResult.walletAppliedCents, equals(35000));
        expect(fullResult.remainingGatewayDueCents, equals(0));
        expect(fullResult.remainingWalletBalanceCents, equals(25000));
        expect(
          service.getClientWallet('client_full').balanceCents,
          equals(25000),
        );

        // Case 3: Zero wallet balance leaves full gateway amount due and adds no debit entry.
        final ledgerCountBeforeZero = service.ledgerEntries.length;
        final zeroResult = service.applyClientWalletAtCheckout(
          clientId: 'client_zero',
          bookingTotalCents: 40000,
          idempotencyKey: 'chk_zero',
          bookingId: 'bk_zero',
        );
        expect(zeroResult.walletAppliedCents, equals(0));
        expect(zeroResult.remainingGatewayDueCents, equals(40000));
        expect(zeroResult.remainingWalletBalanceCents, equals(0));
        expect(service.ledgerEntries.length, equals(ledgerCountBeforeZero));
      },
    );
  });

  group('Stage 4A: Duplicate idempotencyKey Replay Protection', () {
    test(
      'replaying recordCompletedBookingSettlement does not double-mutate balances or ledger',
      () {
        final service = WalletAndLedgerService();
        service.recordCompletedBookingSettlement(
          bookingId: 'bk_idem_1',
          techId: 'tech_idem',
          grossAmountCents: 100000,
          completionPhotoUrl:
              'https://storage.abe.co.za/completions/bk_idem_1.jpg',
          idempotencyKey: 'idem_settle_1',
        );

        final countBefore = service.ledgerEntries.length;
        service.recordCompletedBookingSettlement(
          bookingId: 'bk_idem_1',
          techId: 'tech_idem',
          grossAmountCents: 100000,
          completionPhotoUrl:
              'https://storage.abe.co.za/completions/bk_idem_1.jpg',
          idempotencyKey: 'idem_settle_1',
        );

        expect(service.ledgerEntries.length, equals(countBefore));
        expect(service.platformRevenueCents, equals(15000));
        expect(service.totalGmvCents, equals(100000));
        expect(
          service.getTechAccount('tech_idem').unpaidNetEarningsCents,
          equals(85000),
        );
      },
    );

    test(
      'replaying processCancellationSplit does not double-mutate balances, ledger, or vouchers',
      () {
        final service = WalletAndLedgerService();

        // Client late cancellation replay
        final lateFirst = service.processCancellationSplit(
          bookingId: 'bk_idem_late',
          clientId: 'client_late',
          techId: 'tech_late',
          paidAmountCents: 40000,
          cancelledByTech: false,
          idempotencyKey: 'idem_cancel_late',
        );
        final lateLedgerCount = service.ledgerEntries.length;
        final lateReplay = service.processCancellationSplit(
          bookingId: 'bk_idem_late',
          clientId: 'client_late',
          techId: 'tech_late',
          paidAmountCents: 40000,
          cancelledByTech: false,
          idempotencyKey: 'idem_cancel_late',
        );

        expect(lateReplay.bookingId, equals(lateFirst.bookingId));
        expect(
          lateReplay.clientWalletCreditedCents,
          equals(lateFirst.clientWalletCreditedCents),
        );
        expect(
          lateReplay.techCompensatedCents,
          equals(lateFirst.techCompensatedCents),
        );
        expect(service.ledgerEntries.length, equals(lateLedgerCount));
        expect(
          service.getClientWallet('client_late').balanceCents,
          equals(30000),
        );
        expect(
          service.getTechAccount('tech_late').unpaidNetEarningsCents,
          equals(10000),
        );

        // Tech cancellation replay
        final couponsBefore = service.voucherService.allCoupons.length;
        final techFirst = service.processCancellationSplit(
          bookingId: 'bk_idem_tech',
          clientId: 'client_tech_c',
          techId: 'tech_tech_c',
          paidAmountCents: 60000,
          cancelledByTech: true,
          idempotencyKey: 'idem_cancel_tech',
        );
        final techLedgerCount = service.ledgerEntries.length;
        final couponsAfterFirst = service.voucherService.allCoupons.length;
        expect(couponsAfterFirst, equals(couponsBefore + 1));

        final techReplay = service.processCancellationSplit(
          bookingId: 'bk_idem_tech',
          clientId: 'client_tech_c',
          techId: 'tech_tech_c',
          paidAmountCents: 60000,
          cancelledByTech: true,
          idempotencyKey: 'idem_cancel_tech',
        );

        expect(
          techReplay.apologyVoucher?.code,
          equals(techFirst.apologyVoucher?.code),
        );
        expect(service.ledgerEntries.length, equals(techLedgerCount));
        expect(
          service.voucherService.allCoupons.length,
          equals(couponsAfterFirst),
        );
        expect(
          service.getClientWallet('client_tech_c').balanceCents,
          equals(60000),
        );
      },
    );

    test(
      'replaying reserveStockUpStoreOrder, requestInstantCashOut, and processScheduledTechPayout does not double-mutate',
      () {
        final service = WalletAndLedgerService();
        service.recordCompletedBookingSettlement(
          bookingId: 'bk_payout_seed',
          techId: 'tech_payout',
          grossAmountCents: 200000, // R2,000 gross -> R1,700 (170,000 cents) net
          completionPhotoUrl:
              'https://storage.abe.co.za/completions/bk_payout_seed.jpg',
          idempotencyKey: 'settle_payout_seed',
        );

        // 1. reserveStockUpStoreOrder replay
        final orderFirst = service.reserveStockUpStoreOrder(
          techId: 'tech_payout',
          orderId: 'ord_idem_1',
          orderTotalCents: 30000, // R300.00
          idempotencyKey: 'idem_store_1',
        );
        final ledgerAfterOrder = service.ledgerEntries.length;
        final orderReplay = service.reserveStockUpStoreOrder(
          techId: 'tech_payout',
          orderId: 'ord_idem_1',
          orderTotalCents: 30000,
          idempotencyKey: 'idem_store_1',
        );
        expect(orderReplay.openStoreOrdersCents, equals(30000));
        expect(orderReplay.availableStoreCreditCents, equals(140000));
        expect(
          orderFirst.openStoreOrdersCents,
          equals(orderReplay.openStoreOrdersCents),
        );
        expect(service.ledgerEntries.length, equals(ledgerAfterOrder));

        // 2. requestInstantCashOut replay
        final instantFirst = service.requestInstantCashOut(
          techId: 'tech_payout',
          requestedAmountCents: 50000, // R500.00 -> 2.5% = R12.50 (1,250 cents)
          idempotencyKey: 'idem_instant_1',
        );
        final ledgerAfterInstant = service.ledgerEntries.length;
        final payoutsAfterInstant = service.payoutRecords.length;
        final accountAfterInstant = service.getTechAccount('tech_payout');

        final instantReplay = service.requestInstantCashOut(
          techId: 'tech_payout',
          requestedAmountCents: 50000,
          idempotencyKey: 'idem_instant_1',
        );
        expect(instantReplay.id, equals(instantFirst.id));
        expect(instantReplay.convenienceFeeCents, equals(1250));
        expect(instantReplay.netPayoutCents, equals(48750));
        expect(service.ledgerEntries.length, equals(ledgerAfterInstant));
        expect(service.payoutRecords.length, equals(payoutsAfterInstant));
        expect(
          service.getTechAccount('tech_payout').unpaidNetEarningsCents,
          equals(accountAfterInstant.unpaidNetEarningsCents),
        );
        expect(
          service.getTechAccount('tech_payout').paidOutTotalCents,
          equals(accountAfterInstant.paidOutTotalCents),
        );

        // 3. processScheduledTechPayout replay
        // Remaining unpaid: 170000 - 50000 = 120000; open orders: 30000 -> withdrawable: 90000
        final schedFirst = service.processScheduledTechPayout(
          techId: 'tech_payout',
          idempotencyKey: 'idem_sched_1',
        );
        final ledgerAfterSched = service.ledgerEntries.length;
        final payoutsAfterSched = service.payoutRecords.length;
        final accountAfterSched = service.getTechAccount('tech_payout');

        final schedReplay = service.processScheduledTechPayout(
          techId: 'tech_payout',
          idempotencyKey: 'idem_sched_1',
        );
        expect(schedReplay.id, equals(schedFirst.id));
        expect(schedReplay.netPayoutCents, equals(90000));
        expect(schedReplay.convenienceFeeCents, equals(0));
        expect(service.ledgerEntries.length, equals(ledgerAfterSched));
        expect(service.payoutRecords.length, equals(payoutsAfterSched));
        expect(
          service.getTechAccount('tech_payout').unpaidNetEarningsCents,
          equals(accountAfterSched.unpaidNetEarningsCents),
        );
        expect(
          service.getTechAccount('tech_payout').paidOutTotalCents,
          equals(accountAfterSched.paidOutTotalCents),
        );
      },
    );
  });

  group('Stage 4A: Store Credit Cap', () {
    test(
      'enforces Available Store Credit = Unpaid Net Earnings - Open Store Orders and throws StateError when exceeded',
      () {
        final service = WalletAndLedgerService();
        service.recordCompletedBookingSettlement(
          bookingId: 'bk_store_cap',
          techId: 'tech_store',
          grossAmountCents: 200000, // R2,000 gross -> R1,700 (170,000 cents) net
          completionPhotoUrl:
              'https://storage.abe.co.za/completions/bk_store_cap.jpg',
          idempotencyKey: 'settle_store_cap',
        );

        final initialAccount = service.getTechAccount('tech_store');
        expect(initialAccount.unpaidNetEarningsCents, equals(170000));
        expect(initialAccount.openStoreOrdersCents, equals(0));
        expect(initialAccount.availableStoreCreditCents, equals(170000));

        final afterOrder1 = service.reserveStockUpStoreOrder(
          techId: 'tech_store',
          orderId: 'ord_cap_1',
          orderTotalCents: 50000,
          idempotencyKey: 'ord_cap_key_1',
        );
        expect(afterOrder1.openStoreOrdersCents, equals(50000));
        expect(afterOrder1.availableStoreCreditCents, equals(120000));

        final afterOrder2 = service.reserveStockUpStoreOrder(
          techId: 'tech_store',
          orderId: 'ord_cap_2',
          orderTotalCents: 45000,
          idempotencyKey: 'ord_cap_key_2',
        );
        expect(afterOrder2.openStoreOrdersCents, equals(95000));
        expect(afterOrder2.availableStoreCreditCents, equals(75000));

        final ledgerCountBeforeReject = service.ledgerEntries.length;
        expect(
          () => service.reserveStockUpStoreOrder(
            techId: 'tech_store',
            orderId: 'ord_cap_over',
            orderTotalCents: 75001,
            idempotencyKey: 'ord_cap_key_over',
          ),
          throwsStateError,
        );
        expect(service.ledgerEntries.length, equals(ledgerCountBeforeReject));
        expect(
          service.getTechAccount('tech_store').availableStoreCreditCents,
          equals(75000),
        );

        // Reserving exact remaining available credit succeeds and reduces allowance to zero.
        final exhausted = service.reserveStockUpStoreOrder(
          techId: 'tech_store',
          orderId: 'ord_cap_exact',
          orderTotalCents: 75000,
          idempotencyKey: 'ord_cap_key_exact',
        );
        expect(exhausted.openStoreOrdersCents, equals(170000));
        expect(exhausted.availableStoreCreditCents, equals(0));

        // Subsequent instant cash-out or scheduled payout is blocked whilst store orders lock all earnings.
        expect(
          () => service.requestInstantCashOut(
            techId: 'tech_store',
            requestedAmountCents: 20000,
            idempotencyKey: 'inst_blocked_by_store',
          ),
          throwsStateError,
        );
        expect(
          () => service.processScheduledTechPayout(
            techId: 'tech_store',
            idempotencyKey: 'sched_blocked_by_store',
          ),
          throwsStateError,
        );
      },
    );
  });

  group('Stage 4A: Automated Cancellation Split Engine', () {
    test(
      'client late cancellation credits exact 75% to Client ABE Wallet and 25% to Tech pending earnings',
      () {
        final service = WalletAndLedgerService();
        final outcome = service.processCancellationSplit(
          bookingId: 'bk_client_late_split',
          clientId: 'client_split_1',
          techId: 'tech_split_1',
          paidAmountCents: 45555, // 75% rounded = 34166, 25% remainder = 11389
          cancelledByTech: false,
          idempotencyKey: 'cancel_split_client_1',
        );

        expect(outcome.cancelledByTech, isFalse);
        expect(outcome.clientWalletCreditedCents, equals(34166));
        expect(outcome.techCompensatedCents, equals(11389));
        expect(
          outcome.clientWalletCreditedCents + outcome.techCompensatedCents,
          equals(45555),
        );
        expect(outcome.apologyVoucher, isNull);

        expect(
          service.getClientWallet('client_split_1').balanceCents,
          equals(34166),
        );
        expect(
          service.getTechAccount('tech_split_1').unpaidNetEarningsCents,
          equals(11389),
        );

        final entries = service.ledgerEntries
            .where((e) => e.bookingId == 'bk_client_late_split')
            .toList();
        expect(entries, hasLength(2));
        expect(
          entries
              .firstWhere(
                (e) => e.entryType == LedgerEntryType.clientLateCancelRefund,
              )
              .amountZarCents,
          equals(34166),
        );
        expect(
          entries
              .firstWhere(
                (e) => e.entryType == LedgerEntryType.clientLateCancelTechComp,
              )
              .amountZarCents,
          equals(11389),
        );
      },
    );

    test(
      'tech cancellation credits 100% to Client ABE Wallet and issues single-use apology voucher valid on next booking',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 14, 0));
        final service = WalletAndLedgerService(clock: clock.call);

        final outcome = service.processCancellationSplit(
          bookingId: 'bk_tech_cancel_1',
          clientId: 'client_wronged',
          techId: 'tech_flaked',
          paidAmountCents: 65000,
          cancelledByTech: true,
          idempotencyKey: 'cancel_split_tech_1',
        );

        expect(outcome.cancelledByTech, isTrue);
        expect(outcome.clientWalletCreditedCents, equals(65000));
        expect(outcome.techCompensatedCents, equals(0));
        expect(
          service.getClientWallet('client_wronged').balanceCents,
          equals(65000),
        );
        expect(
          service.getTechAccount('tech_flaked').unpaidNetEarningsCents,
          equals(0),
        );

        final voucher = outcome.apologyVoucher;
        expect(voucher, isNotNull);
        expect(
          voucher!.discountValue,
          equals(WalletAndLedgerService.defaultTechCancelApologyVoucherZar),
        );
        expect(voucher.maxRedemptions, equals(1));
        expect(voucher.perUserLimit, equals(1));
        expect(voucher.assignedToUserId, equals('client_wronged'));
        expect(voucher.issuedForReason, equals('tech_cancellation_apology'));

        // Another client cannot use this client-assigned apology voucher.
        final wrongClientAttempt = service.voucherService.validateCoupon(
          rawCode: voucher.code,
          userId: 'other_client',
          subtotalZar: 400,
        );
        expect(wrongClientAttempt.valid, isFalse);

        // Assigned client redeems the apology voucher on their next booking.
        final nextBookingRedeem = service.voucherService.redeemCoupon(
          rawCode: voucher.code,
          userId: 'client_wronged',
          subtotalZar: 400,
          idempotencyKey: 'redeem_apology_1',
        );
        expect(nextBookingRedeem.valid, isTrue);
        expect(
          nextBookingRedeem.discountZar,
          equals(WalletAndLedgerService.defaultTechCancelApologyVoucherZar),
        );

        // Single-use guarantee: second attempt with a new idempotencyKey fails.
        final secondUse = service.voucherService.redeemCoupon(
          rawCode: voucher.code,
          userId: 'client_wronged',
          subtotalZar: 400,
          idempotencyKey: 'redeem_apology_2',
        );
        expect(secondUse.valid, isFalse);

        // Duplicate cancellation on same bookingId with different idempotencyKey throws StateError.
        expect(
          () => service.processCancellationSplit(
            bookingId: 'bk_tech_cancel_1',
            clientId: 'client_wronged',
            techId: 'tech_flaked',
            paidAmountCents: 65000,
            cancelledByTech: true,
            idempotencyKey: 'cancel_split_tech_other_key',
          ),
          throwsStateError,
        );
      },
    );
  });

  group('Stage 4A: CouponVoucherService Engine', () {
    test(
      'calculates fixed ZAR and percentage discounts and enforces minSpendZar',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 9, 0));
        final vouchers = CouponVoucherService(
          clock: clock.call,
          seedCoupons: <PromoCouponRecord>[
            PromoCouponRecord(
              id: 'c_fixed',
              code: 'GLOW120',
              discountType: VoucherDiscountType.fixedZar,
              discountValue: 120,
              minSpendZar: 300,
              maxRedemptions: 50,
              perUserLimit: 2,
            ),
            PromoCouponRecord(
              id: 'c_pct',
              code: 'STUDIO25',
              discountType: VoucherDiscountType.percentage,
              discountValue: 25,
              minSpendZar: 200,
              maxRedemptions: 50,
              perUserLimit: 2,
            ),
            PromoCouponRecord(
              id: 'c_cap',
              code: 'GIFT500',
              discountType: VoucherDiscountType.fixedZar,
              discountValue: 500,
              minSpendZar: 100,
              maxRedemptions: 10,
              perUserLimit: 1,
            ),
          ],
        );

        // Below minSpendZar
        final belowMin = vouchers.validateCoupon(
          rawCode: 'glow120',
          userId: 'client_1',
          subtotalZar: 250,
        );
        expect(belowMin.valid, isFalse);
        expect(belowMin.discountZar, equals(0));

        // Fixed ZAR valid
        final fixedValid = vouchers.validateCoupon(
          rawCode: 'GLOW120',
          userId: 'client_1',
          subtotalZar: 450,
        );
        expect(fixedValid.valid, isTrue);
        expect(fixedValid.discountZar, equals(120));

        // Percentage valid (25% of R550 = R137.50 -> rounded to R138)
        final pctValid = vouchers.validateCoupon(
          rawCode: 'studio25',
          userId: 'client_1',
          subtotalZar: 550,
        );
        expect(pctValid.valid, isTrue);
        expect(pctValid.discountZar, equals(138));

        // Fixed discount exceeding subtotal is capped at subtotalZar
        final cappedValid = vouchers.validateCoupon(
          rawCode: 'GIFT500',
          userId: 'client_1',
          subtotalZar: 320,
        );
        expect(cappedValid.valid, isTrue);
        expect(cappedValid.discountZar, equals(320));
      },
    );

    test(
      'enforces expiry date, maxRedemptions limit, perUserLimit, and paused status',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 10, 0));
        final vouchers = CouponVoucherService(
          clock: clock.call,
          seedCoupons: <PromoCouponRecord>[
            PromoCouponRecord(
              id: 'c_exp',
              code: 'FLASH24H',
              discountType: VoucherDiscountType.fixedZar,
              discountValue: 50,
              minSpendZar: 150,
              maxRedemptions: 10,
              perUserLimit: 1,
              expiresAtUtc: clock.now.add(const Duration(hours: 2)),
            ),
            PromoCouponRecord(
              id: 'c_cap_limit',
              code: 'VIPONLY2',
              discountType: VoucherDiscountType.percentage,
              discountValue: 15,
              minSpendZar: 200,
              maxRedemptions: 2,
              perUserLimit: 1,
            ),
          ],
        );

        // Valid before expiry
        expect(
          vouchers
              .validateCoupon(
                rawCode: 'FLASH24H',
                userId: 'user_a',
                subtotalZar: 300,
              )
              .valid,
          isTrue,
        );

        // Advance clock past expiry
        clock.advance(const Duration(hours: 2, seconds: 1));
        final expiredOutcome = vouchers.validateCoupon(
          rawCode: 'FLASH24H',
          userId: 'user_a',
          subtotalZar: 300,
        );
        expect(expiredOutcome.valid, isFalse);
        expect(expiredOutcome.message, contains('expired'));

        // Pause VIPONLY2 -> rejected, then reactivate -> accepted
        vouchers.setCouponActive('VIPONLY2', isActive: false);
        final pausedOutcome = vouchers.validateCoupon(
          rawCode: 'VIPONLY2',
          userId: 'user_a',
          subtotalZar: 400,
        );
        expect(pausedOutcome.valid, isFalse);
        expect(pausedOutcome.message, contains('paused'));

        vouchers.setCouponActive('VIPONLY2', isActive: true);

        // User A redeems once (succeeds), second attempt hits perUserLimit
        expect(
          vouchers
              .redeemCoupon(
                rawCode: 'VIPONLY2',
                userId: 'user_a',
                subtotalZar: 400,
                idempotencyKey: 'vip_u_a_1',
              )
              .valid,
          isTrue,
        );
        final userASecond = vouchers.redeemCoupon(
          rawCode: 'VIPONLY2',
          userId: 'user_a',
          subtotalZar: 400,
          idempotencyKey: 'vip_u_a_2',
        );
        expect(userASecond.valid, isFalse);
        expect(userASecond.message, contains('redemption limit'));

        // User B redeems (maxRedemptions = 2 reached)
        expect(
          vouchers
              .redeemCoupon(
                rawCode: 'VIPONLY2',
                userId: 'user_b',
                subtotalZar: 400,
                idempotencyKey: 'vip_u_b_1',
              )
              .valid,
          isTrue,
        );

        // User C blocked by global maxRedemptions limit
        final userCOutcome = vouchers.redeemCoupon(
          rawCode: 'VIPONLY2',
          userId: 'user_c',
          subtotalZar: 400,
          idempotencyKey: 'vip_u_c_1',
        );
        expect(userCOutcome.valid, isFalse);
        expect(userCOutcome.message, contains('maximum redemptions'));
      },
    );

    test(
      'enforces sliding-window brute-force rate limit blocking on 11th validation within 5 minutes',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 16, 0));
        final vouchers = CouponVoucherService(clock: clock.call);

        // Attempts 1 through 10 within 5 minutes are allowed (not rate-limited).
        for (var i = 0; i < CouponVoucherService.maxValidationAttemptsPerWindow; i++) {
          clock.advance(const Duration(seconds: 10));
          final attempt = vouchers.validateCoupon(
            rawCode: 'BRUTE_$i',
            userId: 'actor_brute',
            subtotalZar: 500,
          );
          expect(attempt.rateLimited, isFalse);
          expect(attempt.valid, isFalse);
        }

        // 11th attempt within the 5-minute sliding window is rate-limited even for a valid code.
        final blocked = vouchers.validateCoupon(
          rawCode: 'R1_EVENT',
          userId: 'actor_brute',
          subtotalZar: 500,
        );
        expect(blocked.rateLimited, isTrue);
        expect(blocked.valid, isFalse);

        // Advancing past the 5-minute window restores validation access.
        clock.advance(const Duration(minutes: 5, seconds: 1));
        final recovered = vouchers.validateCoupon(
          rawCode: 'R1_EVENT',
          userId: 'actor_brute',
          subtotalZar: 500,
        );
        expect(recovered.rateLimited, isFalse);
        expect(recovered.valid, isTrue);
        expect(recovered.discountZar, equals(100));
      },
    );

    test(
      'redeemCoupon is idempotent when called repeatedly with the same idempotencyKey',
      () {
        final clock = _MutableClock(DateTime.utc(2026, 11, 14, 18, 0));
        final vouchers = CouponVoucherService(
          clock: clock.call,
          seedCoupons: <PromoCouponRecord>[
            PromoCouponRecord(
              id: 'c_idem',
              code: 'ONCEPERUSER',
              discountType: VoucherDiscountType.fixedZar,
              discountValue: 80,
              minSpendZar: 200,
              maxRedemptions: 2,
              perUserLimit: 1,
            ),
          ],
        );

        final first = vouchers.redeemCoupon(
          rawCode: 'ONCEPERUSER',
          userId: 'client_idem',
          subtotalZar: 350,
          idempotencyKey: 'redeem_idem_key_1',
        );
        expect(first.valid, isTrue);
        expect(first.discountZar, equals(80));
        expect(first.coupon?.currentRedemptions, equals(1));

        // Replaying with the exact same idempotencyKey returns the cached valid outcome
        // without consuming another global or per-user redemption slot.
        final replay = vouchers.redeemCoupon(
          rawCode: 'ONCEPERUSER',
          userId: 'client_idem',
          subtotalZar: 350,
          idempotencyKey: 'redeem_idem_key_1',
        );
        expect(replay.valid, isTrue);
        expect(replay.discountZar, equals(80));

        final storedCoupon = vouchers.allCoupons.firstWhere(
          (c) => c.code == 'ONCEPERUSER',
        );
        expect(storedCoupon.currentRedemptions, equals(1));

        // Same user with a NEW idempotencyKey is still blocked by perUserLimit: 1.
        final secondAttempt = vouchers.redeemCoupon(
          rawCode: 'ONCEPERUSER',
          userId: 'client_idem',
          subtotalZar: 350,
          idempotencyKey: 'redeem_idem_key_2',
        );
        expect(secondAttempt.valid, isFalse);

        // A second user can still redeem because the replay did not consume maxRedemptions.
        final otherUser = vouchers.redeemCoupon(
          rawCode: 'ONCEPERUSER',
          userId: 'client_second',
          subtotalZar: 350,
          idempotencyKey: 'redeem_idem_other_1',
        );
        expect(otherUser.valid, isTrue);
        expect(otherUser.coupon?.currentRedemptions, equals(2));
      },
    );
  });
}
