import '../../../booking/domain/models/booking_modifier.dart';
import '../../../booking/domain/models/booking_venue_models.dart';
import '../../../../core/utils/input_sanitiser.dart';

/// Supported South African payment gateway providers.
enum PaymentGatewayProvider {
  paystack('paystack', 'Paystack South Africa'),
  peachPayments('peach_payments', 'Peach Payments'),
  payJustNow('payjustnow', 'PayJustNow BNPL'),
  abeWallet('abe_wallet', 'ABE Closed-Loop Wallet');

  const PaymentGatewayProvider(this.code, this.displayName);

  final String code;
  final String displayName;
}

/// Supported checkout payment methods in ZAR.
enum PaymentMethodType {
  card('card', 'Debit or Credit Card'),
  instantEft('instant_eft', 'Instant EFT (SA Banks)'),
  bnplPayJustNow('bnpl_payjustnow', 'PayJustNow (3 Interest-Free Instalments)'),
  walletFullCover('wallet_full_cover', 'ABE Wallet & Voucher');

  const PaymentMethodType(this.code, this.label);

  final String code;
  final String label;
}

/// Tokenised card reference returned by Paystack or Peach Payments.
///
/// Raw card numbers (PAN) and CVV values are never stored or transmitted
/// through ABE domain models.
class SavedCardToken {
  SavedCardToken({
    required String id,
    required String clientId,
    required this.provider,
    required String authorizationCode,
    required String last4,
    required String cardBrand,
    required String expiryMonth,
    required String expiryYear,
    String bankName = '',
    DateTime? createdAtUtc,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        clientId = InputSanitiser.sanitiseText(clientId, maxLength: 128),
        authorizationCode = InputSanitiser.sanitiseText(
          authorizationCode,
          maxLength: 160,
        ),
        last4 = _validateLast4(last4),
        cardBrand = InputSanitiser.sanitiseText(cardBrand, maxLength: 40),
        expiryMonth = _validateTwoDigits(expiryMonth, 'expiryMonth'),
        expiryYear = _validateExpiryYear(expiryYear),
        bankName = InputSanitiser.sanitiseText(bankName, maxLength: 80),
        createdAtUtc = (createdAtUtc ?? DateTime.now()).toUtc() {
    if (this.id.isEmpty ||
        this.clientId.isEmpty ||
        this.authorizationCode.isEmpty) {
      throw ArgumentError(
        'SavedCardToken requires non-empty id, clientId, and authorizationCode.',
      );
    }
  }

  final String id;
  final String clientId;
  final PaymentGatewayProvider provider;
  final String authorizationCode;
  final String last4;
  final String cardBrand;
  final String expiryMonth;
  final String expiryYear;
  final String bankName;
  final DateTime createdAtUtc;

  String get maskedLabel => '$cardBrand •••• $last4 (Exp $expiryMonth/$expiryYear)';

  static String _validateLast4(String raw) {
    final clean = InputSanitiser.sanitiseText(raw, maxLength: 8)
        .replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 4) {
      throw ArgumentError.value(raw, 'last4', 'Card last4 must be 4 digits.');
    }
    return clean;
  }

  static String _validateTwoDigits(String raw, String fieldName) {
    final clean = InputSanitiser.sanitiseText(raw, maxLength: 4)
        .replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty || clean.length > 2) {
      throw ArgumentError.value(raw, fieldName, '$fieldName must be 1 or 2 digits.');
    }
    return clean.padLeft(2, '0');
  }

  static String _validateExpiryYear(String raw) {
    final clean = InputSanitiser.sanitiseText(raw, maxLength: 4)
        .replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 2 && clean.length != 4) {
      throw ArgumentError.value(
        raw,
        'expiryYear',
        'expiryYear must be 2 or 4 digits.',
      );
    }
    return clean;
  }
}

/// 3-instalment schedule preview for PayJustNow BNPL checkouts.
class PayJustNowInstalmentPlan {
  const PayJustNowInstalmentPlan({
    required this.totalZarCents,
    required this.firstInstalmentCents,
    required this.secondInstalmentCents,
    required this.thirdInstalmentCents,
  });

  factory PayJustNowInstalmentPlan.fromTotalCents(int totalZarCents) {
    final validTotal = InputSanitiser.requireNonNegativeInt(
      totalZarCents,
      fieldName: 'totalZarCents',
      strictlyPositive: true,
    );
    final baseInstalment = validTotal ~/ 3;
    final remainder = validTotal - (baseInstalment * 3);
    return PayJustNowInstalmentPlan(
      totalZarCents: validTotal,
      firstInstalmentCents: baseInstalment + remainder,
      secondInstalmentCents: baseInstalment,
      thirdInstalmentCents: baseInstalment,
    );
  }

  final int totalZarCents;
  final int firstInstalmentCents;
  final int secondInstalmentCents;
  final int thirdInstalmentCents;

  double get firstInstalmentZar => firstInstalmentCents / 100.0;
  double get secondInstalmentZar => secondInstalmentCents / 100.0;
  double get thirdInstalmentZar => thirdInstalmentCents / 100.0;
}

/// Input payload to initiate a booking checkout session.
class PaymentCheckoutRequest {
  PaymentCheckoutRequest({
    required String bookingId,
    required String clientId,
    required String techId,
    required String clientEmail,
    required this.quote,
    required this.venueSelection,
    required this.paymentMethod,
    this.preferredCardOrEftProvider = PaymentGatewayProvider.paystack,
    String? voucherCode,
    this.saveCardForFutureBookings = false,
    String? savedCardTokenId,
    required String idempotencyKey,
  })  : bookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128),
        clientId = InputSanitiser.sanitiseText(clientId, maxLength: 128),
        techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        clientEmail = InputSanitiser.sanitiseText(clientEmail, maxLength: 160),
        voucherCode = voucherCode == null
            ? null
            : InputSanitiser.sanitiseText(voucherCode, maxLength: 40),
        savedCardTokenId = savedCardTokenId == null
            ? null
            : InputSanitiser.sanitiseText(savedCardTokenId, maxLength: 128),
        idempotencyKey = InputSanitiser.sanitiseText(
          idempotencyKey,
          maxLength: 160,
        ) {
    if (this.bookingId.isEmpty ||
        this.clientId.isEmpty ||
        this.techId.isEmpty ||
        this.clientEmail.isEmpty ||
        this.idempotencyKey.isEmpty) {
      throw ArgumentError(
        'PaymentCheckoutRequest requires bookingId, clientId, techId, clientEmail, and idempotencyKey.',
      );
    }
    final emailPattern = RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[A-Za-z]{2,}$');
    if (!emailPattern.hasMatch(this.clientEmail)) {
      throw ArgumentError.value(
        clientEmail,
        'clientEmail',
        'A valid client email address is required for ZAR gateway receipts.',
      );
    }
    if (preferredCardOrEftProvider == PaymentGatewayProvider.payJustNow &&
        paymentMethod != PaymentMethodType.bnplPayJustNow) {
      throw ArgumentError(
        'PayJustNow provider may only be used with PaymentMethodType.bnplPayJustNow.',
      );
    }
  }

  final String bookingId;
  final String clientId;
  final String techId;
  final String clientEmail;
  final BookingPriceQuote quote;
  final BookingVenueSelection venueSelection;
  final PaymentMethodType paymentMethod;
  final PaymentGatewayProvider preferredCardOrEftProvider;
  final String? voucherCode;
  final bool saveCardForFutureBookings;
  final String? savedCardTokenId;
  final String idempotencyKey;
}

/// Checkout session returned by the selected SA payment adapter.
class GatewayCheckoutSession {
  GatewayCheckoutSession({
    required String sessionId,
    required this.provider,
    required this.method,
    required String reference,
    required String authorizationUrl,
    required int amountDueZarCents,
    required String idempotencyKey,
    this.instalmentPlan,
    this.status = 'pending',
    Map<String, String> metadata = const <String, String>{},
  })  : sessionId = InputSanitiser.sanitiseText(sessionId, maxLength: 128),
        reference = InputSanitiser.sanitiseText(reference, maxLength: 128),
        authorizationUrl = InputSanitiser.sanitiseText(
          authorizationUrl,
          maxLength: 500,
        ),
        amountDueZarCents = InputSanitiser.requireNonNegativeInt(
          amountDueZarCents,
          fieldName: 'amountDueZarCents',
        ),
        idempotencyKey = InputSanitiser.sanitiseText(
          idempotencyKey,
          maxLength: 160,
        ),
        metadata = Map<String, String>.unmodifiable(metadata) {
    if (this.amountDueZarCents > 0 &&
        !this.authorizationUrl.startsWith('https://')) {
      throw ArgumentError(
        'Gateway authorizationUrl must use HTTPS.',
      );
    }
  }

  final String sessionId;
  final PaymentGatewayProvider provider;
  final PaymentMethodType method;
  final String reference;
  final String authorizationUrl;
  final int amountDueZarCents;
  final String idempotencyKey;
  final PayJustNowInstalmentPlan? instalmentPlan;
  final String status;
  final Map<String, String> metadata;

  double get amountDueZar => amountDueZarCents / 100.0;
}

/// Outcome returned when verifying a payment gateway transaction.
class GatewayVerificationResponse {
  const GatewayVerificationResponse({
    required this.verified,
    required this.provider,
    required this.reference,
    required this.amountPaidZarCents,
    this.cardToken,
    this.failureReason,
  });

  final bool verified;
  final PaymentGatewayProvider provider;
  final String reference;
  final int amountPaidZarCents;
  final SavedCardToken? cardToken;
  final String? failureReason;
}

/// Final idempotent receipt for a completed checkout (wallet + voucher + gateway).
class PaymentCheckoutReceipt {
  PaymentCheckoutReceipt({
    required String bookingId,
    required String reference,
    required int grossTotalZarCents,
    required int voucherDiscountZarCents,
    required int walletAppliedZarCents,
    required int gatewayChargedZarCents,
    required this.provider,
    required this.method,
    required this.status,
    required String idempotencyKey,
    this.session,
    this.savedCardToken,
    this.clientBookingPin,
    this.voucherMessage,
    DateTime? createdAtUtc,
  })  : bookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128),
        reference = InputSanitiser.sanitiseText(reference, maxLength: 128),
        grossTotalZarCents = InputSanitiser.requireNonNegativeInt(
          grossTotalZarCents,
          fieldName: 'grossTotalZarCents',
        ),
        voucherDiscountZarCents = InputSanitiser.requireNonNegativeInt(
          voucherDiscountZarCents,
          fieldName: 'voucherDiscountZarCents',
        ),
        walletAppliedZarCents = InputSanitiser.requireNonNegativeInt(
          walletAppliedZarCents,
          fieldName: 'walletAppliedZarCents',
        ),
        gatewayChargedZarCents = InputSanitiser.requireNonNegativeInt(
          gatewayChargedZarCents,
          fieldName: 'gatewayChargedZarCents',
        ),
        idempotencyKey = InputSanitiser.sanitiseText(
          idempotencyKey,
          maxLength: 160,
        ),
        createdAtUtc = (createdAtUtc ?? DateTime.now()).toUtc();

  final String bookingId;
  final String reference;
  final int grossTotalZarCents;
  final int voucherDiscountZarCents;
  final int walletAppliedZarCents;
  final int gatewayChargedZarCents;
  final PaymentGatewayProvider provider;
  final PaymentMethodType method;
  final String status;
  final String idempotencyKey;
  final GatewayCheckoutSession? session;
  final SavedCardToken? savedCardToken;
  final String? clientBookingPin;
  final String? voucherMessage;
  final DateTime createdAtUtc;

  bool get isConfirmed => status == 'confirmed';
  double get grossTotalZar => grossTotalZarCents / 100.0;
  double get voucherDiscountZar => voucherDiscountZarCents / 100.0;
  double get walletAppliedZar => walletAppliedZarCents / 100.0;
  double get gatewayChargedZar => gatewayChargedZarCents / 100.0;
}
