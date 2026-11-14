import '../../../../core/utils/input_sanitiser.dart';

/// Double-entry ledger entry classifications for ABE's financial engine.
enum LedgerEntryType {
  bookingGrossPayment('booking_gross_payment', 'Booking Gross Payment'),
  platformCommission('platform_commission', '15% Platform Fee'),
  techPendingEarning('tech_pending_earning', 'Pending Appointment Earnings'),
  clientWalletCredit('client_wallet_credit', 'Wallet Credit'),
  clientWalletSpend('client_wallet_spend', 'Applied at Checkout'),
  clientLateCancelRefund(
    'client_late_cancel_refund',
    'Late Cancellation Credit (75%)',
  ),
  clientLateCancelTechComp(
    'client_late_cancel_tech_comp',
    'Late Cancellation Chair Compensation (25%)',
  ),
  techCancelFullRefund(
    'tech_cancel_full_refund',
    'Tech Cancellation Full Refund (100%)',
  ),
  techScheduledPayout('tech_scheduled_payout', 'Scheduled Bank Payout'),
  techInstantCashOut('tech_instant_cash_out', 'Instant Cash-Out'),
  instantCashOutFee('instant_cash_out_fee', 'Instant Cash-Out Fee'),
  stockUpStoreOrderDebit(
    'stock_up_store_order_debit',
    'Stock-Up Supply Order',
  ),
  disputeResolutionAdjustment(
    'dispute_resolution_adjustment',
    'Dispute Resolution Adjustment',
  );

  const LedgerEntryType(this.code, this.label);
  final String code;
  final String label;
}

/// Immutable double-entry financial ledger record (`financial_ledger/{entryId}`).
class FinancialLedgerEntry {
  FinancialLedgerEntry({
    required String id,
    required String idempotencyKey,
    required String userId,
    required this.entryType,
    required int amountZarCents,
    required String direction,
    required String description,
    String? bookingId,
    String? orderId,
    DateTime? createdAtUtc,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        idempotencyKey =
            InputSanitiser.sanitiseText(idempotencyKey, maxLength: 160),
        userId = InputSanitiser.sanitiseText(userId, maxLength: 128),
        amountZarCents = InputSanitiser.requireNonNegativeInt(
          amountZarCents,
          fieldName: 'amountZarCents',
        ),
        direction = _validateDirection(direction),
        description = InputSanitiser.sanitiseText(description, maxLength: 240),
        bookingId = bookingId != null
            ? InputSanitiser.sanitiseText(bookingId, maxLength: 128)
            : null,
        orderId = orderId != null
            ? InputSanitiser.sanitiseText(orderId, maxLength: 128)
            : null,
        createdAtUtc = (createdAtUtc ?? DateTime.now()).toUtc() {
    if (this.id.isEmpty ||
        this.idempotencyKey.isEmpty ||
        this.userId.isEmpty ||
        this.description.isEmpty) {
      throw ArgumentError(
        'FinancialLedgerEntry requires non-empty id, idempotencyKey, userId, and description.',
      );
    }
  }

  final String id;
  final String idempotencyKey;
  final String userId;
  final LedgerEntryType entryType;

  /// Amount stored in South African cents to avoid floating-point rounding drift.
  final int amountZarCents;

  /// Either `'credit'` or `'debit'`.
  final String direction;
  final String description;
  final String? bookingId;
  final String? orderId;
  final DateTime createdAtUtc;

  double get amountZar => amountZarCents / 100.0;

  static String _validateDirection(String raw) {
    final clean = InputSanitiser.sanitiseText(raw, maxLength: 16).toLowerCase();
    if (clean != 'credit' && clean != 'debit') {
      throw ArgumentError.value(
        raw,
        'direction',
        'Ledger direction must be either credit or debit.',
      );
    }
    return clean;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'idempotencyKey': idempotencyKey,
      'userId': userId,
      'entryType': entryType.code,
      'amountZarCents': amountZarCents,
      'amountZar': amountZar,
      'direction': direction,
      'description': description,
      if (bookingId != null && bookingId!.isNotEmpty) 'bookingId': bookingId,
      if (orderId != null && orderId!.isNotEmpty) 'orderId': orderId,
      'createdAtIso': createdAtUtc.toIso8601String(),
    };
  }
}

/// Closed-loop client wallet account (`wallets/{clientId}`).
///
/// Strictly non-withdrawable: credits may only be applied to ABE bookings.
class ClosedLoopClientWallet {
  ClosedLoopClientWallet({
    required String clientId,
    int balanceCents = 0,
    DateTime? updatedAtUtc,
  })  : clientId = InputSanitiser.sanitiseText(clientId, maxLength: 128),
        balanceCents = InputSanitiser.requireNonNegativeInt(
          balanceCents,
          fieldName: 'balanceCents',
        ),
        updatedAtUtc = (updatedAtUtc ?? DateTime.now()).toUtc() {
    if (this.clientId.isEmpty) {
      throw ArgumentError('ClosedLoopClientWallet.clientId cannot be empty.');
    }
  }

  final String clientId;
  final int balanceCents;
  final DateTime updatedAtUtc;

  /// Explicitly documents and enforces that closed-loop client wallets never allow cash withdrawal.
  bool get supportsCashWithdrawal => false;

  int get balanceZarRounded => (balanceCents / 100).round();
  double get balanceZar => balanceCents / 100.0;

  ClosedLoopClientWallet copyWith({
    int? balanceCents,
    DateTime? updatedAtUtc,
  }) {
    return ClosedLoopClientWallet(
      clientId: clientId,
      balanceCents: balanceCents ?? this.balanceCents,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}

/// Technician earnings & payout balance summary (`wallets/tech_{techId}`).
class TechEarningsLedgerAccount {
  TechEarningsLedgerAccount({
    required String techId,
    int unpaidNetEarningsCents = 0,
    int openStoreOrdersCents = 0,
    int paidOutTotalCents = 0,
    this.payoutCadence = PayoutCadence.weekly,
  })  : techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        unpaidNetEarningsCents = InputSanitiser.requireNonNegativeInt(
          unpaidNetEarningsCents,
          fieldName: 'unpaidNetEarningsCents',
        ),
        openStoreOrdersCents = InputSanitiser.requireNonNegativeInt(
          openStoreOrdersCents,
          fieldName: 'openStoreOrdersCents',
        ),
        paidOutTotalCents = InputSanitiser.requireNonNegativeInt(
          paidOutTotalCents,
          fieldName: 'paidOutTotalCents',
        ) {
    if (this.techId.isEmpty) {
      throw ArgumentError('TechEarningsLedgerAccount.techId cannot be empty.');
    }
  }

  final String techId;
  final int unpaidNetEarningsCents;
  final int openStoreOrdersCents;
  final int paidOutTotalCents;
  final PayoutCadence payoutCadence;

  /// Formula: `Available Store Credit = Unpaid Net Earnings - Open Store Orders`.
  int get availableStoreCreditCents =>
      (unpaidNetEarningsCents - openStoreOrdersCents)
          .clamp(0, unpaidNetEarningsCents);

  double get unpaidNetEarningsZar => unpaidNetEarningsCents / 100.0;
  double get openStoreOrdersZar => openStoreOrdersCents / 100.0;
  double get availableStoreCreditZar => availableStoreCreditCents / 100.0;
  double get paidOutTotalZar => paidOutTotalCents / 100.0;

  TechEarningsLedgerAccount copyWith({
    int? unpaidNetEarningsCents,
    int? openStoreOrdersCents,
    int? paidOutTotalCents,
    PayoutCadence? payoutCadence,
  }) {
    return TechEarningsLedgerAccount(
      techId: techId,
      unpaidNetEarningsCents:
          unpaidNetEarningsCents ?? this.unpaidNetEarningsCents,
      openStoreOrdersCents: openStoreOrdersCents ?? this.openStoreOrdersCents,
      paidOutTotalCents: paidOutTotalCents ?? this.paidOutTotalCents,
      payoutCadence: payoutCadence ?? this.payoutCadence,
    );
  }
}

enum PayoutCadence {
  weekly('weekly', 'Weekly (Thursdays)'),
  biWeekly('bi_weekly', 'Bi-Weekly');

  const PayoutCadence(this.code, this.label);
  final String code;
  final String label;
}

/// Payout record generated for scheduled weekly/bi-weekly or Instant Cash-Out requests.
class TechPayoutRecord {
  TechPayoutRecord({
    required String id,
    required String idempotencyKey,
    required String techId,
    required int grossRequestedCents,
    required int convenienceFeeCents,
    required int netPayoutCents,
    required this.isInstantCashOut,
    required this.status,
    DateTime? createdAtUtc,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        idempotencyKey =
            InputSanitiser.sanitiseText(idempotencyKey, maxLength: 160),
        techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        grossRequestedCents = InputSanitiser.requireNonNegativeInt(
          grossRequestedCents,
          fieldName: 'grossRequestedCents',
          strictlyPositive: true,
        ),
        convenienceFeeCents = InputSanitiser.requireNonNegativeInt(
          convenienceFeeCents,
          fieldName: 'convenienceFeeCents',
        ),
        netPayoutCents = InputSanitiser.requireNonNegativeInt(
          netPayoutCents,
          fieldName: 'netPayoutCents',
          strictlyPositive: true,
        ),
        createdAtUtc = (createdAtUtc ?? DateTime.now()).toUtc();

  final String id;
  final String idempotencyKey;
  final String techId;
  final int grossRequestedCents;
  final int convenienceFeeCents;
  final int netPayoutCents;
  final bool isInstantCashOut;
  final String status;
  final DateTime createdAtUtc;
}

/// Checkout wallet auto-application calculation result.
class CheckoutWalletApplicationResult {
  const CheckoutWalletApplicationResult({
    required this.bookingTotalCents,
    required this.walletAppliedCents,
    required this.remainingGatewayDueCents,
    required this.remainingWalletBalanceCents,
  });

  final int bookingTotalCents;
  final int walletAppliedCents;
  final int remainingGatewayDueCents;
  final int remainingWalletBalanceCents;
}

/// Supported discount formats for Admin Coupons & Vouchers.
enum VoucherDiscountType {
  fixedZar('fixed_zar'),
  percentage('percentage');

  const VoucherDiscountType(this.code);
  final String code;
}

/// Extended promo code / voucher record supporting fixed ZAR & percentage discounts,
/// expiry dates, max redemptions, per-user limits, and pause controls.
class PromoCouponRecord {
  PromoCouponRecord({
    required String id,
    required String code,
    required this.discountType,
    required int discountValue,
    required int minSpendZar,
    required int maxRedemptions,
    required int perUserLimit,
    int currentRedemptions = 0,
    this.isActive = true,
    this.expiresAtUtc,
    String issuedForReason = 'promotional',
    String? assignedToUserId,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        code = InputSanitiser.sanitiseVoucherCode(code),
        discountValue = InputSanitiser.requireNonNegativeInt(
          discountValue,
          fieldName: 'discountValue',
          strictlyPositive: true,
        ),
        minSpendZar = InputSanitiser.requireNonNegativeInt(
          minSpendZar,
          fieldName: 'minSpendZar',
        ),
        maxRedemptions = InputSanitiser.requireNonNegativeInt(
          maxRedemptions,
          fieldName: 'maxRedemptions',
          strictlyPositive: true,
        ),
        perUserLimit = InputSanitiser.requireNonNegativeInt(
          perUserLimit,
          fieldName: 'perUserLimit',
          strictlyPositive: true,
        ),
        currentRedemptions = InputSanitiser.requireNonNegativeInt(
          currentRedemptions,
          fieldName: 'currentRedemptions',
        ),
        issuedForReason =
            InputSanitiser.sanitiseText(issuedForReason, maxLength: 120),
        assignedToUserId = assignedToUserId != null
            ? InputSanitiser.sanitiseText(assignedToUserId, maxLength: 128)
            : null {
    if (this.id.isEmpty) {
      throw ArgumentError('PromoCouponRecord.id cannot be empty.');
    }
    if (discountType == VoucherDiscountType.percentage &&
        this.discountValue > 100) {
      throw ArgumentError.value(
        discountValue,
        'discountValue',
        'Percentage discount cannot exceed 100%.',
      );
    }
  }

  final String id;
  final String code;
  final VoucherDiscountType discountType;
  final int discountValue;
  final int minSpendZar;
  final int maxRedemptions;
  final int perUserLimit;
  final int currentRedemptions;
  final bool isActive;
  final DateTime? expiresAtUtc;
  final String issuedForReason;
  final String? assignedToUserId;

  PromoCouponRecord copyWith({
    int? currentRedemptions,
    bool? isActive,
  }) {
    return PromoCouponRecord(
      id: id,
      code: code,
      discountType: discountType,
      discountValue: discountValue,
      minSpendZar: minSpendZar,
      maxRedemptions: maxRedemptions,
      perUserLimit: perUserLimit,
      currentRedemptions: currentRedemptions ?? this.currentRedemptions,
      isActive: isActive ?? this.isActive,
      expiresAtUtc: expiresAtUtc,
      issuedForReason: issuedForReason,
      assignedToUserId: assignedToUserId,
    );
  }

  int computeDiscountZar(int subtotalZar) {
    if (subtotalZar < minSpendZar) return 0;
    if (discountType == VoucherDiscountType.fixedZar) {
      return discountValue.clamp(0, subtotalZar);
    }
    return ((subtotalZar * discountValue) / 100.0).round().clamp(0, subtotalZar);
  }
}

/// Outcome returned when evaluating or redeeming a coupon/voucher code.
class VoucherValidationOutcome {
  const VoucherValidationOutcome({
    required this.valid,
    required this.discountZar,
    required this.message,
    this.coupon,
    this.rateLimited = false,
  });

  final bool valid;
  final int discountZar;
  final String message;
  final PromoCouponRecord? coupon;
  final bool rateLimited;
}

/// Outcome returned when processing an automated cancellation split.
class CancellationSplitOutcome {
  const CancellationSplitOutcome({
    required this.bookingId,
    required this.cancelledByTech,
    required this.clientWalletCreditedCents,
    required this.techCompensatedCents,
    required this.message,
    this.apologyVoucher,
  });

  final String bookingId;
  final bool cancelledByTech;
  final int clientWalletCreditedCents;
  final int techCompensatedCents;
  final String message;
  final PromoCouponRecord? apologyVoucher;
}
