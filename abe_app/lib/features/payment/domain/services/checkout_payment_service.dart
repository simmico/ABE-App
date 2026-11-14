import '../../../../core/config/feature_flags.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../../booking/domain/services/appointment_start_lock_service.dart';
import '../../../wallet/domain/services/coupon_voucher_service.dart';
import '../../../wallet/domain/services/wallet_and_ledger_service.dart';
import '../models/payment_models.dart';
import 'payment_gateway_adapter.dart';

/// Orchestrates ABE upfront booking checkout in South African Rands (ZAR):
/// 1. Enforces Strict Venue-Only commercial venue verification.
/// 2. Applies promo or tech-cancellation apology vouchers via [CouponVoucherService].
/// 3. Automatically deducts available Closed-Loop ABE Wallet balance via [WalletAndLedgerService].
/// 4. Routes any remaining ZAR balance to Paystack, Peach Payments (Card tokenisation
///    or Instant EFT), or PayJustNow BNPL (gated by [FeatureFlagsService.payJustNowBnpl]).
/// 5. Guarantees idempotency by [idempotencyKey] and generates the client's
///    4-digit start PIN via [AppointmentStartLockService] once confirmed.
class CheckoutPaymentService {
  CheckoutPaymentService({
    required this.walletService,
    required this.startLockService,
    FeatureFlagsService? featureFlags,
    PaystackGatewayAdapter? paystackAdapter,
    PeachPaymentsGatewayAdapter? peachAdapter,
    PayJustNowBnplAdapter? payJustNowAdapter,
  })  : featureFlags = featureFlags ?? FeatureFlagsService(),
        _paystackAdapter = paystackAdapter ?? PaystackGatewayAdapter(),
        _peachAdapter = peachAdapter ?? PeachPaymentsGatewayAdapter(),
        _payJustNowAdapter = payJustNowAdapter ?? PayJustNowBnplAdapter();

  final WalletAndLedgerService walletService;
  final AppointmentStartLockService startLockService;
  final FeatureFlagsService featureFlags;
  final PaystackGatewayAdapter _paystackAdapter;
  final PeachPaymentsGatewayAdapter _peachAdapter;
  final PayJustNowBnplAdapter _payJustNowAdapter;

  final Map<String, PaymentCheckoutReceipt> _receiptsByKey =
      <String, PaymentCheckoutReceipt>{};
  final Map<String, GatewayCheckoutSession> _sessionsByKey =
      <String, GatewayCheckoutSession>{};
  final Map<String, List<SavedCardToken>> _savedCardsByClient =
      <String, List<SavedCardToken>>{};
  final Map<String, _PendingCheckoutSnapshot> _pendingSnapshotsByKey =
      <String, _PendingCheckoutSnapshot>{};

  List<SavedCardToken> savedCardsForClient(String clientId) {
    final cleanId = InputSanitiser.sanitiseText(clientId, maxLength: 128);
    return List<SavedCardToken>.unmodifiable(
      _savedCardsByClient[cleanId] ?? const <SavedCardToken>[],
    );
  }

  /// Calculates a live preview of how voucher + closed-loop wallet balance
  /// reduce the ZAR amount due before initiating payment.
  CheckoutBreakdownPreview previewCheckoutBreakdown({
    required String clientId,
    required int subtotalZar,
    String? rawVoucherCode,
  }) {
    final validSubtotalZar = InputSanitiser.requireNonNegativeInt(
      subtotalZar,
      fieldName: 'subtotalZar',
      strictlyPositive: true,
    );
    final grossCents = validSubtotalZar * 100;

    var voucherDiscountCents = 0;
    String? voucherMessage;
    String? validatedVoucherCode;

    final cleanVoucher = rawVoucherCode == null
        ? ''
        : InputSanitiser.sanitiseText(rawVoucherCode, maxLength: 40);
    if (cleanVoucher.isNotEmpty) {
      final outcome = walletService.voucherService.validateCoupon(
        rawCode: cleanVoucher,
        userId: clientId,
        subtotalZar: validSubtotalZar,
      );
      if (outcome.valid && outcome.discountZar > 0) {
        voucherDiscountCents =
            (outcome.discountZar * 100).clamp(0, grossCents);
        validatedVoucherCode = outcome.coupon?.code;
        voucherMessage = outcome.message;
      } else {
        voucherMessage = outcome.message;
      }
    }

    final afterVoucherCents = (grossCents - voucherDiscountCents).clamp(0, grossCents);
    final walletBalanceCents = walletService.getClientWallet(clientId).balanceCents;
    final walletAppliedCents = walletBalanceCents.clamp(0, afterVoucherCents);
    final remainingGatewayDueCents = afterVoucherCents - walletAppliedCents;

    return CheckoutBreakdownPreview(
      grossTotalZarCents: grossCents,
      voucherDiscountZarCents: voucherDiscountCents,
      walletAvailableZarCents: walletBalanceCents,
      walletAppliedZarCents: walletAppliedCents,
      remainingGatewayDueZarCents: remainingGatewayDueCents,
      appliedVoucherCode: validatedVoucherCode,
      voucherMessage: voucherMessage,
      payJustNowPlan: remainingGatewayDueCents > 0
          ? PayJustNowInstalmentPlan.fromTotalCents(remainingGatewayDueCents)
          : null,
    );
  }

  /// Initiates checkout idempotently:
  /// - Deducts valid voucher + closed-loop ABE wallet balance first.
  /// - If remaining due is R0, confirms immediately and generates the 4-digit PIN.
  /// - Otherwise creates a pending South African gateway session (Paystack,
  ///   Peach Payments, or PayJustNow BNPL).
  Future<PaymentCheckoutReceipt> initiateCheckout(
    PaymentCheckoutRequest request,
  ) async {
    final cleanKey = InputSanitiser.sanitiseText(
      request.idempotencyKey,
      maxLength: 160,
    );
    final existingReceipt = _receiptsByKey[cleanKey];
    if (existingReceipt != null) {
      return existingReceipt;
    }

    // Enforce Strict Venue-Only Policy and feature flags before mutating vouchers or wallet.
    if (!request.venueSelection.venue.isVerified) {
      throw StateError(
        'Strict Venue-Only Policy: checkout blocked because venue is unverified.',
      );
    }
    if (request.paymentMethod == PaymentMethodType.bnplPayJustNow &&
        !featureFlags.isEnabled(FeatureFlagsService.payJustNowBnpl)) {
      throw StateError(
        'PayJustNow BNPL is currently disabled by feature flag. Choose Card or Instant EFT.',
      );
    }

    final grossCents = InputSanitiser.requireNonNegativeInt(
      request.quote.subtotalPriceZar * 100,
      fieldName: 'grossTotalZarCents',
      strictlyPositive: true,
    );

    // Step 1: Apply promo or apology voucher code idempotently.
    var voucherDiscountCents = 0;
    String? voucherMessage;
    final candidateVoucher = request.voucherCode?.trim().isNotEmpty == true
        ? request.voucherCode!.trim()
        : request.quote.appliedVoucherCode;

    if (candidateVoucher != null && candidateVoucher.isNotEmpty) {
      final redemption = walletService.voucherService.redeemCoupon(
        rawCode: candidateVoucher,
        userId: request.clientId,
        subtotalZar: request.quote.subtotalPriceZar,
        idempotencyKey: 'voucher:$cleanKey',
      );
      if (!redemption.valid) {
        throw StateError(redemption.message);
      }
      voucherDiscountCents =
          (redemption.discountZar * 100).clamp(0, grossCents);
      voucherMessage = redemption.message;
    }

    final afterVoucherCents =
        (grossCents - voucherDiscountCents).clamp(0, grossCents);

    // Step 2: Auto-apply closed-loop client ABE Wallet balance before gateway charge.
    var walletAppliedCents = 0;
    var remainingDueCents = afterVoucherCents;
    if (afterVoucherCents > 0) {
      final walletResult = walletService.applyClientWalletAtCheckout(
        clientId: request.clientId,
        bookingTotalCents: afterVoucherCents,
        idempotencyKey: 'wallet:$cleanKey',
        bookingId: request.bookingId,
      );
      walletAppliedCents = walletResult.walletAppliedCents;
      remainingDueCents = walletResult.remainingGatewayDueCents;
    }

    // Step 3: If ABE Wallet + Voucher covers 100%, confirm immediately.
    if (remainingDueCents == 0) {
      final pinView = startLockService.generatePinForConfirmedBooking(
        bookingId: request.bookingId,
        clientId: request.clientId,
        techId: request.techId,
      );
      final receipt = PaymentCheckoutReceipt(
        bookingId: request.bookingId,
        reference: 'ABE_WALLET_${request.bookingId.toUpperCase()}',
        grossTotalZarCents: grossCents,
        voucherDiscountZarCents: voucherDiscountCents,
        walletAppliedZarCents: walletAppliedCents,
        gatewayChargedZarCents: 0,
        provider: PaymentGatewayProvider.abeWallet,
        method: PaymentMethodType.walletFullCover,
        status: 'confirmed',
        idempotencyKey: cleanKey,
        clientBookingPin: pinView.pinCode,
        voucherMessage: voucherMessage,
      );
      _receiptsByKey[cleanKey] = receipt;
      return receipt;
    }

    // Step 4: Enforce PayJustNow feature flag if BNPL was requested.
    if (request.paymentMethod == PaymentMethodType.bnplPayJustNow &&
        !featureFlags.isEnabled(FeatureFlagsService.payJustNowBnpl)) {
      throw StateError(
        'PayJustNow BNPL is currently disabled by feature flag. Choose Card or Instant EFT.',
      );
    }

    final adapter = _resolveAdapter(
      method: request.paymentMethod,
      preferredProvider: request.preferredCardOrEftProvider,
    );

    String? savedAuthCode;
    if (request.savedCardTokenId != null &&
        request.savedCardTokenId!.isNotEmpty) {
      final saved = savedCardsForClient(request.clientId).where(
        (card) => card.id == request.savedCardTokenId,
      );
      if (saved.isNotEmpty) {
        savedAuthCode = saved.first.authorizationCode;
      }
    }

    final session = await adapter.createCheckoutSession(
      bookingId: request.bookingId,
      clientId: request.clientId,
      clientEmail: request.clientEmail,
      amountDueZarCents: remainingDueCents,
      method: request.paymentMethod,
      idempotencyKey: cleanKey,
      saveCardToken: request.saveCardForFutureBookings &&
          request.paymentMethod == PaymentMethodType.card,
      savedCardAuthorizationCode: savedAuthCode,
      metadata: <String, String>{
        'bookingId': request.bookingId,
        'clientId': request.clientId,
        'techId': request.techId,
        'venueType': request.venueSelection.venueType.code,
        'venueId': request.venueSelection.venue.id,
        'city': request.venueSelection.venue.city,
      },
    );

    _sessionsByKey[cleanKey] = session;
    _pendingSnapshotsByKey[cleanKey] = _PendingCheckoutSnapshot(
      request: request,
      grossTotalZarCents: grossCents,
      voucherDiscountZarCents: voucherDiscountCents,
      walletAppliedZarCents: walletAppliedCents,
      remainingDueCents: remainingDueCents,
      voucherMessage: voucherMessage,
    );

    return PaymentCheckoutReceipt(
      bookingId: request.bookingId,
      reference: session.reference,
      grossTotalZarCents: grossCents,
      voucherDiscountZarCents: voucherDiscountCents,
      walletAppliedZarCents: walletAppliedCents,
      gatewayChargedZarCents: remainingDueCents,
      provider: session.provider,
      method: session.method,
      status: 'pending_gateway',
      idempotencyKey: cleanKey,
      session: session,
      voucherMessage: voucherMessage,
    );
  }

  /// Verifies the gateway transaction and finalises the booking idempotently,
  /// saving any tokenised card and generating the client's 4-digit PIN.
  Future<PaymentCheckoutReceipt> confirmGatewayPayment({
    required String idempotencyKey,
  }) async {
    final cleanKey = InputSanitiser.sanitiseText(idempotencyKey, maxLength: 160);
    final existingConfirmed = _receiptsByKey[cleanKey];
    if (existingConfirmed != null && existingConfirmed.isConfirmed) {
      return existingConfirmed;
    }

    final session = _sessionsByKey[cleanKey];
    final snapshot = _pendingSnapshotsByKey[cleanKey];
    if (session == null || snapshot == null) {
      throw StateError(
        'No pending checkout session found for idempotencyKey $cleanKey.',
      );
    }

    final adapter = _resolveAdapter(
      method: session.method,
      preferredProvider: session.provider,
    );
    final verification = await adapter.verifyCheckoutTransaction(
      reference: session.reference,
      expectedAmountZarCents: snapshot.remainingDueCents,
      clientId: snapshot.request.clientId,
      saveCardToken: snapshot.request.saveCardForFutureBookings &&
          session.method == PaymentMethodType.card,
    );

    if (!verification.verified ||
        verification.amountPaidZarCents != snapshot.remainingDueCents) {
      throw StateError(
        verification.failureReason ??
            'Gateway verification failed or paid amount mismatch.',
      );
    }

    final savedToken = verification.cardToken;
    if (savedToken != null) {
      final list = _savedCardsByClient.putIfAbsent(
        snapshot.request.clientId,
        () => <SavedCardToken>[],
      );
      if (!list.any((c) => c.id == savedToken.id)) {
        list.add(savedToken);
      }
    }

    final pinView = startLockService.generatePinForConfirmedBooking(
      bookingId: snapshot.request.bookingId,
      clientId: snapshot.request.clientId,
      techId: snapshot.request.techId,
    );

    final receipt = PaymentCheckoutReceipt(
      bookingId: snapshot.request.bookingId,
      reference: session.reference,
      grossTotalZarCents: snapshot.grossTotalZarCents,
      voucherDiscountZarCents: snapshot.voucherDiscountZarCents,
      walletAppliedZarCents: snapshot.walletAppliedZarCents,
      gatewayChargedZarCents: verification.amountPaidZarCents,
      provider: session.provider,
      method: session.method,
      status: 'confirmed',
      idempotencyKey: cleanKey,
      session: session,
      savedCardToken: savedToken,
      clientBookingPin: pinView.pinCode,
      voucherMessage: snapshot.voucherMessage,
    );

    _receiptsByKey[cleanKey] = receipt;
    return receipt;
  }

  SouthAfricanPaymentGatewayAdapter _resolveAdapter({
    required PaymentMethodType method,
    required PaymentGatewayProvider preferredProvider,
  }) {
    if (method == PaymentMethodType.bnplPayJustNow) {
      return _payJustNowAdapter;
    }
    if (preferredProvider == PaymentGatewayProvider.peachPayments) {
      return _peachAdapter;
    }
    return _paystackAdapter;
  }
}

/// Live breakdown returned prior to payment confirmation.
class CheckoutBreakdownPreview {
  const CheckoutBreakdownPreview({
    required this.grossTotalZarCents,
    required this.voucherDiscountZarCents,
    required this.walletAvailableZarCents,
    required this.walletAppliedZarCents,
    required this.remainingGatewayDueZarCents,
    this.appliedVoucherCode,
    this.voucherMessage,
    this.payJustNowPlan,
  });

  final int grossTotalZarCents;
  final int voucherDiscountZarCents;
  final int walletAvailableZarCents;
  final int walletAppliedZarCents;
  final int remainingGatewayDueZarCents;
  final String? appliedVoucherCode;
  final String? voucherMessage;
  final PayJustNowInstalmentPlan? payJustNowPlan;

  double get grossTotalZar => grossTotalZarCents / 100.0;
  double get voucherDiscountZar => voucherDiscountZarCents / 100.0;
  double get walletAvailableZar => walletAvailableZarCents / 100.0;
  double get walletAppliedZar => walletAppliedZarCents / 100.0;
  double get remainingGatewayDueZar => remainingGatewayDueZarCents / 100.0;
}

class _PendingCheckoutSnapshot {
  const _PendingCheckoutSnapshot({
    required this.request,
    required this.grossTotalZarCents,
    required this.voucherDiscountZarCents,
    required this.walletAppliedZarCents,
    required this.remainingDueCents,
    this.voucherMessage,
  });

  final PaymentCheckoutRequest request;
  final int grossTotalZarCents;
  final int voucherDiscountZarCents;
  final int walletAppliedZarCents;
  final int remainingDueCents;
  final String? voucherMessage;
}
