import '../../../../core/config/brand_config.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../models/wallet_ledger_models.dart';
import 'coupon_voucher_service.dart';

/// Idempotent double-entry financial ledger, closed-loop client wallet,
/// technician payout engine, and automated cancellation split service.
class WalletAndLedgerService {
  WalletAndLedgerService({
    DateTime Function()? clock,
    CouponVoucherService? voucherService,
  })  : _clock = clock ?? DateTime.now,
        _voucherService = voucherService ?? CouponVoucherService(clock: clock);

  static const int minimumInstantCashOutFeeCents = 1000; // R10.00
  static const double instantCashOutFeeRate = 0.025; // 2.5%
  static const int defaultTechCancelApologyVoucherZar = 75;

  final DateTime Function() _clock;
  final CouponVoucherService _voucherService;

  final Map<String, ClosedLoopClientWallet> _clientWallets =
      <String, ClosedLoopClientWallet>{};
  final Map<String, TechEarningsLedgerAccount> _techAccounts =
      <String, TechEarningsLedgerAccount>{};
  final List<FinancialLedgerEntry> _ledgerEntries = <FinancialLedgerEntry>[];
  final List<TechPayoutRecord> _payoutRecords = <TechPayoutRecord>[];
  final Set<String> _processedIdempotencyKeys = <String>{};
  final Set<String> _settledBookingIds = <String>{};
  final Set<String> _cancelledBookingIds = <String>{};
  final Map<String, CancellationSplitOutcome> _cancellationOutcomesByKey =
      <String, CancellationSplitOutcome>{};
  final Map<String, TechPayoutRecord> _payoutsByKey =
      <String, TechPayoutRecord>{};
  final Map<String, CheckoutWalletApplicationResult> _checkoutResultsByKey =
      <String, CheckoutWalletApplicationResult>{};

  int _platformRevenueCents = 0;
  int _totalGmvCents = 0;

  CouponVoucherService get voucherService => _voucherService;
  int get platformRevenueCents => _platformRevenueCents;
  int get totalGmvCents => _totalGmvCents;

  int get totalClientWalletFloatCents => _clientWallets.values
      .fold<int>(0, (sum, wallet) => sum + wallet.balanceCents);

  int get totalPendingTechPayoutsCents => _techAccounts.values
      .fold<int>(0, (sum, acct) => sum + acct.unpaidNetEarningsCents);

  List<FinancialLedgerEntry> get ledgerEntries =>
      List<FinancialLedgerEntry>.unmodifiable(_ledgerEntries);

  List<TechPayoutRecord> get payoutRecords =>
      List<TechPayoutRecord>.unmodifiable(_payoutRecords);

  ClosedLoopClientWallet getClientWallet(String clientId) {
    final cleanId = InputSanitiser.sanitiseText(clientId, maxLength: 128);
    return _clientWallets.putIfAbsent(
      cleanId,
      () => ClosedLoopClientWallet(clientId: cleanId, updatedAtUtc: _clock()),
    );
  }

  TechEarningsLedgerAccount getTechAccount(String techId) {
    final cleanId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    return _techAccounts.putIfAbsent(
      cleanId,
      () => TechEarningsLedgerAccount(techId: cleanId),
    );
  }

  /// Explicitly rejects any attempt to cash out a closed-loop client wallet.
  Never withdrawClientWalletToBank({
    required String clientId,
    required int amountCents,
  }) {
    throw UnsupportedError(
      'Closed-Loop Wallet Policy: client wallet credits cannot be withdrawn as cash. '
      'Credits are automatically applied at checkout.',
    );
  }

  bool isBookingSettled(String bookingId) =>
      _settledBookingIds.contains(InputSanitiser.sanitiseText(bookingId, maxLength: 128));

  /// Settles a completed booking into the double-entry ledger:
  /// - Deducts **15% Platform Fee**
  /// - Credits **85% Net Earnings** to the tech's pending payout ledger
  /// - Strictly requires [completionPhotoUrl] (Live Camera Lock invariant) and [idempotencyKey].
  void recordCompletedBookingSettlement({
    required String bookingId,
    required String techId,
    required int grossAmountCents,
    required String? completionPhotoUrl,
    required String idempotencyKey,
  }) {
    final cleanKey = 'settle:${_requireIdempotencyKey(idempotencyKey)}';
    if (_processedIdempotencyKeys.contains(cleanKey)) {
      return;
    }

    final cleanBookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    final cleanPhotoUrl =
        InputSanitiser.sanitiseText(completionPhotoUrl ?? '', maxLength: 500);
    if (cleanBookingId.isEmpty || cleanTechId.isEmpty) {
      throw ArgumentError('bookingId and techId cannot be empty.');
    }
    if (_settledBookingIds.contains(cleanBookingId)) {
      throw StateError(
        'Booking $cleanBookingId has already been settled in the financial ledger.',
      );
    }
    if (cleanPhotoUrl.isEmpty || !cleanPhotoUrl.startsWith('https://')) {
      throw StateError(
        'Financial Lock: earnings cannot move to pending payout ledger without a verified HTTPS completionPhotoUrl.',
      );
    }

    final validGross = InputSanitiser.requireNonNegativeInt(
      grossAmountCents,
      fieldName: 'grossAmountCents',
      strictlyPositive: true,
    );

    final platformFeeCents =
        (validGross * BrandConfig.platformFeeRate).round();
    final techNetCents = validGross - platformFeeCents;
    final now = _clock().toUtc();

    final currentTech = getTechAccount(cleanTechId);
    _techAccounts[cleanTechId] = currentTech.copyWith(
      unpaidNetEarningsCents: currentTech.unpaidNetEarningsCents + techNetCents,
    );
    _platformRevenueCents += platformFeeCents;
    _totalGmvCents += validGross;
    _settledBookingIds.add(cleanBookingId);
    _processedIdempotencyKeys.add(cleanKey);

    _appendEntry(
      idempotencyKey: cleanKey,
      userId: 'abe_platform',
      entryType: LedgerEntryType.platformCommission,
      amountZarCents: platformFeeCents,
      direction: 'credit',
      description: '15% platform fee on completed booking $cleanBookingId',
      bookingId: cleanBookingId,
      now: now,
    );
    _appendEntry(
      idempotencyKey: cleanKey,
      userId: cleanTechId,
      entryType: LedgerEntryType.techPendingEarning,
      amountZarCents: techNetCents,
      direction: 'credit',
      description: '85% net tech earnings for completed booking $cleanBookingId',
      bookingId: cleanBookingId,
      now: now,
    );
  }

  /// Credits a client's closed-loop wallet idempotently (e.g. refunds, dispute credits).
  ClosedLoopClientWallet creditClientWallet({
    required String clientId,
    required int amountCents,
    required String idempotencyKey,
    required String reason,
    String? bookingId,
  }) {
    final cleanKey = _requireIdempotencyKey(idempotencyKey);
    final cleanClientId = InputSanitiser.sanitiseText(clientId, maxLength: 128);
    if (_processedIdempotencyKeys.contains(cleanKey)) {
      return getClientWallet(cleanClientId);
    }

    final validAmount = InputSanitiser.requireNonNegativeInt(
      amountCents,
      fieldName: 'amountCents',
      strictlyPositive: true,
    );
    final cleanReason = InputSanitiser.sanitiseText(reason, maxLength: 200);
    final now = _clock().toUtc();

    final wallet = getClientWallet(cleanClientId);
    final updated = wallet.copyWith(
      balanceCents: wallet.balanceCents + validAmount,
      updatedAtUtc: now,
    );
    _clientWallets[cleanClientId] = updated;
    _processedIdempotencyKeys.add(cleanKey);

    _appendEntry(
      idempotencyKey: cleanKey,
      userId: cleanClientId,
      entryType: LedgerEntryType.clientWalletCredit,
      amountZarCents: validAmount,
      direction: 'credit',
      description: cleanReason.isEmpty ? 'Client wallet credit' : cleanReason,
      bookingId: bookingId,
      now: now,
    );

    return updated;
  }

  /// Automatically applies closed-loop client wallet balance at checkout.
  CheckoutWalletApplicationResult applyClientWalletAtCheckout({
    required String clientId,
    required int bookingTotalCents,
    required String idempotencyKey,
    required String bookingId,
  }) {
    final cleanKey = _requireIdempotencyKey(idempotencyKey);
    final existing = _checkoutResultsByKey[cleanKey];
    if (existing != null) {
      return existing;
    }

    final cleanClientId = InputSanitiser.sanitiseText(clientId, maxLength: 128);
    final validTotal = InputSanitiser.requireNonNegativeInt(
      bookingTotalCents,
      fieldName: 'bookingTotalCents',
      strictlyPositive: true,
    );
    final wallet = getClientWallet(cleanClientId);
    final appliedCents = wallet.balanceCents.clamp(0, validTotal);
    final remainingDue = validTotal - appliedCents;
    final remainingWallet = wallet.balanceCents - appliedCents;
    final now = _clock().toUtc();

    if (appliedCents > 0) {
      _clientWallets[cleanClientId] = wallet.copyWith(
        balanceCents: remainingWallet,
        updatedAtUtc: now,
      );
      _appendEntry(
        idempotencyKey: cleanKey,
        userId: cleanClientId,
        entryType: LedgerEntryType.clientWalletSpend,
        amountZarCents: appliedCents,
        direction: 'debit',
        description: 'Closed-loop wallet applied to booking $bookingId',
        bookingId: bookingId,
        now: now,
      );
    }

    _processedIdempotencyKeys.add(cleanKey);
    final result = CheckoutWalletApplicationResult(
      bookingTotalCents: validTotal,
      walletAppliedCents: appliedCents,
      remainingGatewayDueCents: remainingDue,
      remainingWalletBalanceCents: remainingWallet,
    );
    _checkoutResultsByKey[cleanKey] = result;
    return result;
  }

  /// Automated Cancellation Split Engine:
  /// - **Client Late Cancellation:** 75% to Client's ABE Wallet, 25% to Tech's earnings ledger.
  /// - **Tech Cancellation:** 100% to Client's ABE Wallet + single-use apology discount voucher.
  CancellationSplitOutcome processCancellationSplit({
    required String bookingId,
    required String clientId,
    required String techId,
    required int paidAmountCents,
    required bool cancelledByTech,
    required String idempotencyKey,
  }) {
    final cleanKey = 'cancel:${_requireIdempotencyKey(idempotencyKey)}';
    final existing = _cancellationOutcomesByKey[cleanKey];
    if (existing != null) {
      return existing;
    }

    final cleanBookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    if (_cancelledBookingIds.contains(cleanBookingId)) {
      throw StateError(
        'Cancellation split has already been processed for booking $cleanBookingId.',
      );
    }
    final cleanClientId = InputSanitiser.sanitiseText(clientId, maxLength: 128);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    if (cleanBookingId.isEmpty ||
        cleanClientId.isEmpty ||
        cleanTechId.isEmpty) {
      throw ArgumentError('bookingId, clientId, and techId cannot be empty.');
    }
    final validPaid = InputSanitiser.requireNonNegativeInt(
      paidAmountCents,
      fieldName: 'paidAmountCents',
      strictlyPositive: true,
    );
    final now = _clock().toUtc();

    late final CancellationSplitOutcome outcome;

    if (cancelledByTech) {
      final clientWallet = getClientWallet(cleanClientId);
      _clientWallets[cleanClientId] = clientWallet.copyWith(
        balanceCents: clientWallet.balanceCents + validPaid,
        updatedAtUtc: now,
      );

      _appendEntry(
        idempotencyKey: cleanKey,
        userId: cleanClientId,
        entryType: LedgerEntryType.techCancelFullRefund,
        amountZarCents: validPaid,
        direction: 'credit',
        description:
            '100% tech cancellation wallet refund for booking $cleanBookingId',
        bookingId: cleanBookingId,
        now: now,
      );

      final apologyVoucher = _voucherService.issueTechCancellationApologyVoucher(
        bookingId: cleanBookingId,
        clientId: cleanClientId,
        discountZar: defaultTechCancelApologyVoucherZar,
      );

      outcome = CancellationSplitOutcome(
        bookingId: cleanBookingId,
        cancelledByTech: true,
        clientWalletCreditedCents: validPaid,
        techCompensatedCents: 0,
        apologyVoucher: apologyVoucher,
        message:
            '100% credited to client ABE Wallet plus single-use voucher ${apologyVoucher.code} (R${apologyVoucher.discountValue} off).',
      );
    } else {
      final clientCreditCents =
          (validPaid * BrandConfig.clientLateCancelWalletRefundRate).round();
      final techCompCents = validPaid - clientCreditCents;

      final clientWallet = getClientWallet(cleanClientId);
      _clientWallets[cleanClientId] = clientWallet.copyWith(
        balanceCents: clientWallet.balanceCents + clientCreditCents,
        updatedAtUtc: now,
      );

      final techAcct = getTechAccount(cleanTechId);
      _techAccounts[cleanTechId] = techAcct.copyWith(
        unpaidNetEarningsCents: techAcct.unpaidNetEarningsCents + techCompCents,
      );

      _appendEntry(
        idempotencyKey: cleanKey,
        userId: cleanClientId,
        entryType: LedgerEntryType.clientLateCancelRefund,
        amountZarCents: clientCreditCents,
        direction: 'credit',
        description:
            '75% client late cancellation wallet credit for booking $cleanBookingId',
        bookingId: cleanBookingId,
        now: now,
      );
      _appendEntry(
        idempotencyKey: cleanKey,
        userId: cleanTechId,
        entryType: LedgerEntryType.clientLateCancelTechComp,
        amountZarCents: techCompCents,
        direction: 'credit',
        description:
            '25% chair-time compensation for late client cancellation on $cleanBookingId',
        bookingId: cleanBookingId,
        now: now,
      );

      outcome = CancellationSplitOutcome(
        bookingId: cleanBookingId,
        cancelledByTech: false,
        clientWalletCreditedCents: clientCreditCents,
        techCompensatedCents: techCompCents,
        message:
            'Client late cancellation split processed: 75% to client ABE Wallet and 25% to technician earnings.',
      );
    }

    _cancelledBookingIds.add(cleanBookingId);
    _processedIdempotencyKeys.add(cleanKey);
    _cancellationOutcomesByKey[cleanKey] = outcome;
    return outcome;
  }

  /// Reserves Stock-Up Supply Store order spend against the technician's
  /// `Available Store Credit = Unpaid Net Earnings - Open Store Orders`.
  TechEarningsLedgerAccount reserveStockUpStoreOrder({
    required String techId,
    required String orderId,
    required int orderTotalCents,
    required String idempotencyKey,
  }) {
    final cleanKey = _requireIdempotencyKey(idempotencyKey);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    if (_processedIdempotencyKeys.contains(cleanKey)) {
      return getTechAccount(cleanTechId);
    }

    final validOrderCents = InputSanitiser.requireNonNegativeInt(
      orderTotalCents,
      fieldName: 'orderTotalCents',
      strictlyPositive: true,
    );
    final acct = getTechAccount(cleanTechId);
    if (validOrderCents > acct.availableStoreCreditCents) {
      throw StateError(
        'Insufficient Pending Payout Store Allowance. Available credit is '
        'R${acct.availableStoreCreditZar.toStringAsFixed(2)}.',
      );
    }

    final updated = acct.copyWith(
      openStoreOrdersCents: acct.openStoreOrdersCents + validOrderCents,
    );
    _techAccounts[cleanTechId] = updated;
    _processedIdempotencyKeys.add(cleanKey);

    _appendEntry(
      idempotencyKey: cleanKey,
      userId: cleanTechId,
      entryType: LedgerEntryType.stockUpStoreOrderDebit,
      amountZarCents: validOrderCents,
      direction: 'debit',
      description: 'Stock-Up Store credit reservation for order $orderId',
      orderId: orderId,
      now: _clock().toUtc(),
    );

    return updated;
  }

  /// Processes scheduled weekly or bi-weekly payout of available net earnings
  /// (`Unpaid Net Earnings - Open Store Orders`) with zero convenience fee.
  TechPayoutRecord processScheduledTechPayout({
    required String techId,
    required String idempotencyKey,
    PayoutCadence? cadenceOverride,
  }) {
    final cleanKey = _requireIdempotencyKey(idempotencyKey);
    final existing = _payoutsByKey[cleanKey];
    if (existing != null) {
      return existing;
    }

    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    final acct = getTechAccount(cleanTechId);
    final withdrawableCents = acct.availableStoreCreditCents;
    if (withdrawableCents <= 0) {
      throw StateError('No withdrawable earnings available for scheduled payout.');
    }

    final now = _clock().toUtc();
    _techAccounts[cleanTechId] = acct.copyWith(
      unpaidNetEarningsCents: acct.unpaidNetEarningsCents - withdrawableCents,
      paidOutTotalCents: acct.paidOutTotalCents + withdrawableCents,
      payoutCadence: cadenceOverride ?? acct.payoutCadence,
    );

    final payout = TechPayoutRecord(
      id: 'po_${now.millisecondsSinceEpoch}_${_payoutRecords.length + 1}',
      idempotencyKey: cleanKey,
      techId: cleanTechId,
      grossRequestedCents: withdrawableCents,
      convenienceFeeCents: 0,
      netPayoutCents: withdrawableCents,
      isInstantCashOut: false,
      status: 'paid',
      createdAtUtc: now,
    );

    _payoutRecords.add(payout);
    _payoutsByKey[cleanKey] = payout;
    _processedIdempotencyKeys.add(cleanKey);

    _appendEntry(
      idempotencyKey: cleanKey,
      userId: cleanTechId,
      entryType: LedgerEntryType.techScheduledPayout,
      amountZarCents: withdrawableCents,
      direction: 'debit',
      description: 'Scheduled ${(cadenceOverride ?? acct.payoutCadence).code} payout',
      now: now,
    );

    return payout;
  }

  /// Executes an Instant Cash-Out request with convenience fee deduction and
  /// strict `idempotencyKey` protection.
  TechPayoutRecord requestInstantCashOut({
    required String techId,
    required int requestedAmountCents,
    required String idempotencyKey,
  }) {
    final cleanKey = _requireIdempotencyKey(idempotencyKey);
    final existing = _payoutsByKey[cleanKey];
    if (existing != null) {
      return existing;
    }

    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    final validRequested = InputSanitiser.requireNonNegativeInt(
      requestedAmountCents,
      fieldName: 'requestedAmountCents',
      strictlyPositive: true,
    );

    final acct = getTechAccount(cleanTechId);
    if (validRequested > acct.availableStoreCreditCents) {
      throw StateError(
        'Requested Instant Cash-Out exceeds available earnings after open Stock-Up Store orders.',
      );
    }

    final calculatedFee = (validRequested * instantCashOutFeeRate).round();
    final feeCents = calculatedFee < minimumInstantCashOutFeeCents
        ? minimumInstantCashOutFeeCents
        : calculatedFee;
    if (validRequested <= feeCents) {
      throw ArgumentError(
        'Instant Cash-Out amount must exceed the R${(feeCents / 100).toStringAsFixed(2)} convenience fee.',
      );
    }
    final netPayoutCents = validRequested - feeCents;
    final now = _clock().toUtc();

    _techAccounts[cleanTechId] = acct.copyWith(
      unpaidNetEarningsCents: acct.unpaidNetEarningsCents - validRequested,
      paidOutTotalCents: acct.paidOutTotalCents + netPayoutCents,
    );

    final payout = TechPayoutRecord(
      id: 'po_inst_${now.millisecondsSinceEpoch}_${_payoutRecords.length + 1}',
      idempotencyKey: cleanKey,
      techId: cleanTechId,
      grossRequestedCents: validRequested,
      convenienceFeeCents: feeCents,
      netPayoutCents: netPayoutCents,
      isInstantCashOut: true,
      status: 'paid_instant',
      createdAtUtc: now,
    );

    _payoutRecords.add(payout);
    _payoutsByKey[cleanKey] = payout;
    _processedIdempotencyKeys.add(cleanKey);

    _appendEntry(
      idempotencyKey: cleanKey,
      userId: cleanTechId,
      entryType: LedgerEntryType.techInstantCashOut,
      amountZarCents: netPayoutCents,
      direction: 'debit',
      description: 'Instant Cash-Out net transfer (${payout.id})',
      now: now,
    );
    _appendEntry(
      idempotencyKey: cleanKey,
      userId: 'abe_platform',
      entryType: LedgerEntryType.instantCashOutFee,
      amountZarCents: feeCents,
      direction: 'credit',
      description: 'Instant Cash-Out convenience fee (${payout.id})',
      now: now,
    );

    return payout;
  }

  /// Generates a SARS / Accountant-ready CSV export of the double-entry ledger,
  /// neutralising spreadsheet formula-injection prefixes (`=`, `+`, `-`, `@`).
  String exportLedgerCsv() {
    final buffer = StringBuffer()
      ..writeln(
        'id,createdAtIso,idempotencyKey,userId,entryType,direction,amountZar,bookingId,orderId,description',
      );
    for (final entry in _ledgerEntries) {
      buffer.writeln(
        '${_csvCell(entry.id, quote: true)},${_csvCell(entry.createdAtUtc.toIso8601String(), quote: true)},'
        '${_csvCell(entry.idempotencyKey, quote: true)},${_csvCell(entry.userId, quote: true)},'
        '${_csvCell(entry.entryType.code, quote: true)},${_csvCell(entry.direction, quote: true)},'
        '${entry.amountZar.toStringAsFixed(2)},${_csvCell(entry.bookingId ?? '', quote: true)},'
        '${_csvCell(entry.orderId ?? '', quote: true)},${_csvCell(entry.description, quote: true)}',
      );
    }
    return buffer.toString();
  }

  String _csvCell(String raw, {bool quote = false}) {
    var safe = raw.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (safe.isNotEmpty &&
        (safe.startsWith('=') ||
            safe.startsWith('+') ||
            safe.startsWith('-') ||
            safe.startsWith('@') ||
            safe.startsWith('\t'))) {
      safe = "'$safe";
    }
    safe = safe.replaceAll('"', '""');
    return quote || safe.contains(',') ? '"$safe"' : safe;
  }

  String _requireIdempotencyKey(String rawKey) {
    final clean = InputSanitiser.sanitiseText(rawKey, maxLength: 160);
    if (clean.isEmpty) {
      throw ArgumentError('A non-empty idempotencyKey is mandatory.');
    }
    return clean;
  }

  void _appendEntry({
    required String idempotencyKey,
    required String userId,
    required LedgerEntryType entryType,
    required int amountZarCents,
    required String direction,
    required String description,
    String? bookingId,
    String? orderId,
    required DateTime now,
  }) {
    _ledgerEntries.add(
      FinancialLedgerEntry(
        id: 'led_${_ledgerEntries.length + 1}_${now.millisecondsSinceEpoch}',
        idempotencyKey: idempotencyKey,
        userId: userId,
        entryType: entryType,
        amountZarCents: amountZarCents,
        direction: direction,
        description: description,
        bookingId: bookingId,
        orderId: orderId,
        createdAtUtc: now,
      ),
    );
  }
}
