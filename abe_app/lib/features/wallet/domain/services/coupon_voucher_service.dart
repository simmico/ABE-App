import '../../../../core/utils/input_sanitiser.dart';
import '../models/wallet_ledger_models.dart';

/// Admin Coupon & Voucher Engine with rate-limited validation to prevent
/// promo-code enumeration.
class CouponVoucherService {
  CouponVoucherService({
    DateTime Function()? clock,
    List<PromoCouponRecord>? seedCoupons,
  }) : _clock = clock ?? DateTime.now {
    if (seedCoupons != null) {
      for (final coupon in seedCoupons) {
        _coupons[coupon.code] = coupon;
      }
    } else {
      createOrUpdateCoupon(
        PromoCouponRecord(
          id: 'promo_r1_event',
          code: 'R1_EVENT',
          discountType: VoucherDiscountType.fixedZar,
          discountValue: 100,
          minSpendZar: 250,
          maxRedemptions: 500,
          perUserLimit: 1,
          issuedForReason: 'launch_event',
        ),
      );
    }
  }

  static const int maxValidationAttemptsPerWindow = 10;
  static const Duration validationRateLimitWindow = Duration(minutes: 5);

  final DateTime Function() _clock;
  final Map<String, PromoCouponRecord> _coupons = <String, PromoCouponRecord>{};
  final Map<String, Map<String, int>> _userRedemptionCounts =
      <String, Map<String, int>>{};
  final Map<String, List<DateTime>> _validationAttemptsByActor =
      <String, List<DateTime>>{};
  final Map<String, VoucherValidationOutcome> _redemptionsByKey =
      <String, VoucherValidationOutcome>{};
  int _apologySequence = 0;

  List<PromoCouponRecord> get allCoupons =>
      List<PromoCouponRecord>.unmodifiable(_coupons.values);

  PromoCouponRecord createOrUpdateCoupon(PromoCouponRecord coupon) {
    _coupons[coupon.code] = coupon;
    return coupon;
  }

  PromoCouponRecord setCouponActive(String rawCode, {required bool isActive}) {
    final code = InputSanitiser.sanitiseVoucherCode(rawCode);
    final existing = _coupons[code];
    if (existing == null) {
      throw StateError('Coupon $code does not exist.');
    }
    final updated = existing.copyWith(isActive: isActive);
    _coupons[code] = updated;
    return updated;
  }

  /// Issues a single-use apology voucher automatically when a tech cancels.
  PromoCouponRecord issueTechCancellationApologyVoucher({
    required String bookingId,
    required String clientId,
    int discountZar = 75,
  }) {
    _apologySequence++;
    final cleanBooking = InputSanitiser.sanitiseText(bookingId, maxLength: 18)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final suffix = cleanBooking.isEmpty
        ? _clock().millisecondsSinceEpoch.toString().substring(7)
        : '${cleanBooking}_$_apologySequence';
    final code = InputSanitiser.sanitiseVoucherCode('ABE_CARE_$suffix');
    final voucher = PromoCouponRecord(
      id: 'vch_apology_${_clock().millisecondsSinceEpoch}_$_apologySequence',
      code: code,
      discountType: VoucherDiscountType.fixedZar,
      discountValue: discountZar,
      minSpendZar: 150,
      maxRedemptions: 1,
      perUserLimit: 1,
      expiresAtUtc: _clock().toUtc().add(const Duration(days: 60)),
      issuedForReason: 'tech_cancellation_apology',
      assignedToUserId: clientId,
    );
    _coupons[voucher.code] = voucher;
    return voucher;
  }

  /// Validates a promo code with sliding-window rate limiting per [userId] / [rateLimitActorKey].
  VoucherValidationOutcome validateCoupon({
    required String rawCode,
    required String userId,
    required int subtotalZar,
    String? rateLimitActorKey,
  }) {
    final now = _clock().toUtc();
    final cleanUserId = InputSanitiser.sanitiseText(userId, maxLength: 128);
    if (cleanUserId.isEmpty) {
      return const VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        message: 'Sign in to validate a voucher code.',
      );
    }
    if (subtotalZar < 0) {
      return const VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        message: 'Booking subtotal cannot be negative.',
      );
    }
    final actorKey = InputSanitiser.sanitiseText(
      rateLimitActorKey ?? cleanUserId,
      maxLength: 128,
    );
    if (_isRateLimited(actorKey, now)) {
      return const VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        rateLimited: true,
        message:
            'Too many voucher checks in a short time. Please wait 5 minutes before trying again.',
      );
    }

    late final String cleanCode;
    try {
      cleanCode = InputSanitiser.sanitiseVoucherCode(rawCode);
    } catch (_) {
      return const VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        message: 'Enter a valid promo or apology voucher code.',
      );
    }

    final coupon = _coupons[cleanCode];
    if (coupon == null) {
      return VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        message: 'Voucher code $cleanCode was not found.',
      );
    }

    if (!coupon.isActive) {
      return VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        coupon: coupon,
        message: 'Voucher code $cleanCode is currently paused.',
      );
    }

    if (coupon.expiresAtUtc != null && now.isAfter(coupon.expiresAtUtc!)) {
      return VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        coupon: coupon,
        message: 'Voucher code $cleanCode has expired.',
      );
    }

    if (coupon.assignedToUserId != null &&
        coupon.assignedToUserId!.isNotEmpty &&
        coupon.assignedToUserId != cleanUserId) {
      return VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        coupon: coupon,
        message: 'This apology voucher is tied to another client account.',
      );
    }

    if (coupon.currentRedemptions >= coupon.maxRedemptions) {
      return VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        coupon: coupon,
        message: 'Voucher code $cleanCode has reached its maximum redemptions.',
      );
    }

    final userUses = _userRedemptionCounts[cleanCode]?[cleanUserId] ?? 0;
    if (userUses >= coupon.perUserLimit) {
      return VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        coupon: coupon,
        message: 'You have already reached the redemption limit for $cleanCode.',
      );
    }

    if (subtotalZar < coupon.minSpendZar) {
      return VoucherValidationOutcome(
        valid: false,
        discountZar: 0,
        coupon: coupon,
        message:
            'Minimum booking spend of R${coupon.minSpendZar} is required for $cleanCode.',
      );
    }

    final discountZar = coupon.computeDiscountZar(subtotalZar);
    return VoucherValidationOutcome(
      valid: true,
      discountZar: discountZar,
      coupon: coupon,
      message: 'Voucher $cleanCode applied: R$discountZar off.',
    );
  }

  /// Validates and atomically redeems a promo code for [userId].
  VoucherValidationOutcome redeemCoupon({
    required String rawCode,
    required String userId,
    required int subtotalZar,
    String? rateLimitActorKey,
    String? idempotencyKey,
  }) {
    final cleanKey = idempotencyKey != null
        ? InputSanitiser.sanitiseText(idempotencyKey, maxLength: 160)
        : '';
    if (cleanKey.isNotEmpty) {
      final existing = _redemptionsByKey[cleanKey];
      if (existing != null) return existing;
    }

    final cleanUserId = InputSanitiser.sanitiseText(userId, maxLength: 128);
    final outcome = validateCoupon(
      rawCode: rawCode,
      userId: cleanUserId,
      subtotalZar: subtotalZar,
      rateLimitActorKey: rateLimitActorKey,
    );
    if (!outcome.valid || outcome.coupon == null) {
      return outcome;
    }

    final coupon = outcome.coupon!;
    final updated = coupon.copyWith(
      currentRedemptions: coupon.currentRedemptions + 1,
    );
    _coupons[coupon.code] = updated;

    final userMap =
        _userRedemptionCounts.putIfAbsent(coupon.code, () => <String, int>{});
    userMap[cleanUserId] = (userMap[cleanUserId] ?? 0) + 1;

    final result = VoucherValidationOutcome(
      valid: true,
      discountZar: outcome.discountZar,
      coupon: updated,
      message: outcome.message,
    );
    if (cleanKey.isNotEmpty) {
      _redemptionsByKey[cleanKey] = result;
    }
    return result;
  }

  bool _isRateLimited(String actorKey, DateTime now) {
    final windowStart = now.subtract(validationRateLimitWindow);
    final timestamps = _validationAttemptsByActor.putIfAbsent(
      actorKey,
      () => <DateTime>[],
    );
    timestamps.removeWhere((ts) => ts.isBefore(windowStart));
    if (timestamps.length >= maxValidationAttemptsPerWindow) {
      return true;
    }
    timestamps.add(now);
    return false;
  }
}
