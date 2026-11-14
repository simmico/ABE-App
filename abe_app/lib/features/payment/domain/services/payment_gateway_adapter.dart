import '../../../../core/utils/input_sanitiser.dart';
import '../models/payment_models.dart';

/// Contract implemented by South African payment gateway adapters
/// (Paystack South Africa, Peach Payments, and PayJustNow BNPL).
///
/// Only public publishable identifiers may be configured in Flutter client
/// code. Secret keys and webhook secrets belong strictly inside Firebase
/// Functions environment secrets.
abstract interface class SouthAfricanPaymentGatewayAdapter {
  PaymentGatewayProvider get provider;

  Future<GatewayCheckoutSession> createCheckoutSession({
    required String bookingId,
    required String clientId,
    required String clientEmail,
    required int amountDueZarCents,
    required PaymentMethodType method,
    required String idempotencyKey,
    bool saveCardToken = false,
    String? savedCardAuthorizationCode,
    Map<String, String> metadata = const <String, String>{},
  });

  Future<GatewayVerificationResponse> verifyCheckoutTransaction({
    required String reference,
    required int expectedAmountZarCents,
    required String clientId,
    bool saveCardToken = false,
  });
}

/// Paystack South Africa adapter supporting ZAR Card tokenisation and Instant EFT.
class PaystackGatewayAdapter implements SouthAfricanPaymentGatewayAdapter {
  PaystackGatewayAdapter({
    String publicKey = 'pk_test_abe_sandbox_placeholder',
    this.callbackUrl = 'https://abe.co.za/checkout/callback',
  }) : publicKey = InputSanitiser.sanitiseText(publicKey, maxLength: 160) {
    if (!callbackUrl.startsWith('https://')) {
      throw ArgumentError('Paystack callbackUrl must use HTTPS.');
    }
    if (this.publicKey.startsWith('sk_')) {
      throw ArgumentError(
        'Security Violation: Paystack secret keys (sk_*) must never be placed in Flutter client code.',
      );
    }
  }

  final String publicKey;
  final String callbackUrl;

  @override
  PaymentGatewayProvider get provider => PaymentGatewayProvider.paystack;

  @override
  Future<GatewayCheckoutSession> createCheckoutSession({
    required String bookingId,
    required String clientId,
    required String clientEmail,
    required int amountDueZarCents,
    required PaymentMethodType method,
    required String idempotencyKey,
    bool saveCardToken = false,
    String? savedCardAuthorizationCode,
    Map<String, String> metadata = const <String, String>{},
  }) async {
    if (method != PaymentMethodType.card &&
        method != PaymentMethodType.instantEft) {
      throw ArgumentError(
        'Paystack South Africa supports Card and Instant EFT methods only.',
      );
    }

    final validAmount = InputSanitiser.requireNonNegativeInt(
      amountDueZarCents,
      fieldName: 'amountDueZarCents',
      strictlyPositive: true,
    );
    final cleanRef = 'ABE_PS_${_shortSafeRef(bookingId, idempotencyKey)}';
    final channel = method == PaymentMethodType.instantEft ? 'eft' : 'card';

    return GatewayCheckoutSession(
      sessionId: 'ps_sess_$cleanRef',
      provider: provider,
      method: method,
      reference: cleanRef,
      authorizationUrl: 'https://checkout.paystack.com/$cleanRef',
      amountDueZarCents: validAmount,
      idempotencyKey: idempotencyKey,
      metadata: <String, String>{
        ...metadata,
        'currency': 'ZAR',
        'channel': channel,
        'saveCardToken': saveCardToken.toString(),
        if (savedCardAuthorizationCode != null &&
            savedCardAuthorizationCode.isNotEmpty)
          'reusableAuthorization': 'true',
      },
    );
  }

  @override
  Future<GatewayVerificationResponse> verifyCheckoutTransaction({
    required String reference,
    required int expectedAmountZarCents,
    required String clientId,
    bool saveCardToken = false,
  }) async {
    final cleanRef = InputSanitiser.sanitiseText(reference, maxLength: 128);
    if (!cleanRef.startsWith('ABE_PS_')) {
      return GatewayVerificationResponse(
        verified: false,
        provider: provider,
        reference: cleanRef,
        amountPaidZarCents: 0,
        failureReason: 'Invalid Paystack transaction reference.',
      );
    }

    final token = saveCardToken
        ? SavedCardToken(
            id: 'tok_ps_${cleanRef.toLowerCase()}',
            clientId: clientId,
            provider: provider,
            authorizationCode: 'AUTH_${cleanRef}_ZAR',
            last4: '4242',
            cardBrand: 'Visa',
            expiryMonth: '08',
            expiryYear: '29',
            bankName: 'FNB South Africa',
          )
        : null;

    return GatewayVerificationResponse(
      verified: true,
      provider: provider,
      reference: cleanRef,
      amountPaidZarCents: expectedAmountZarCents,
      cardToken: token,
    );
  }
}

/// Peach Payments / PayGate South Africa adapter for Card tokenisation and Instant EFT.
class PeachPaymentsGatewayAdapter implements SouthAfricanPaymentGatewayAdapter {
  PeachPaymentsGatewayAdapter({
    String entityId = '8ac7a4ca_abe_sandbox_entity',
    this.shopperResultUrl = 'https://abe.co.za/checkout/peach-return',
  }) : entityId = InputSanitiser.sanitiseText(entityId, maxLength: 128) {
    if (!shopperResultUrl.startsWith('https://')) {
      throw ArgumentError('Peach Payments shopperResultUrl must use HTTPS.');
    }
  }

  final String entityId;
  final String shopperResultUrl;

  @override
  PaymentGatewayProvider get provider => PaymentGatewayProvider.peachPayments;

  @override
  Future<GatewayCheckoutSession> createCheckoutSession({
    required String bookingId,
    required String clientId,
    required String clientEmail,
    required int amountDueZarCents,
    required PaymentMethodType method,
    required String idempotencyKey,
    bool saveCardToken = false,
    String? savedCardAuthorizationCode,
    Map<String, String> metadata = const <String, String>{},
  }) async {
    if (method != PaymentMethodType.card &&
        method != PaymentMethodType.instantEft) {
      throw ArgumentError(
        'Peach Payments supports Card and Instant EFT methods only.',
      );
    }

    final validAmount = InputSanitiser.requireNonNegativeInt(
      amountDueZarCents,
      fieldName: 'amountDueZarCents',
      strictlyPositive: true,
    );
    final cleanRef = 'ABE_PP_${_shortSafeRef(bookingId, idempotencyKey)}';

    return GatewayCheckoutSession(
      sessionId: 'pp_checkout_$cleanRef',
      provider: provider,
      method: method,
      reference: cleanRef,
      authorizationUrl: 'https://eu-test.oppwa.com/v1/checkouts/$cleanRef',
      amountDueZarCents: validAmount,
      idempotencyKey: idempotencyKey,
      metadata: <String, String>{
        ...metadata,
        'currency': 'ZAR',
        'entityId': entityId,
        'paymentType': 'DB',
        'createRegistration': saveCardToken.toString(),
      },
    );
  }

  @override
  Future<GatewayVerificationResponse> verifyCheckoutTransaction({
    required String reference,
    required int expectedAmountZarCents,
    required String clientId,
    bool saveCardToken = false,
  }) async {
    final cleanRef = InputSanitiser.sanitiseText(reference, maxLength: 128);
    if (!cleanRef.startsWith('ABE_PP_')) {
      return GatewayVerificationResponse(
        verified: false,
        provider: provider,
        reference: cleanRef,
        amountPaidZarCents: 0,
        failureReason: 'Invalid Peach Payments checkout reference.',
      );
    }

    final token = saveCardToken
        ? SavedCardToken(
            id: 'tok_pp_${cleanRef.toLowerCase()}',
            clientId: clientId,
            provider: provider,
            authorizationCode: 'REG_${cleanRef}_ZAR',
            last4: '5555',
            cardBrand: 'Mastercard',
            expiryMonth: '11',
            expiryYear: '28',
            bankName: 'Standard Bank',
          )
        : null;

    return GatewayVerificationResponse(
      verified: true,
      provider: provider,
      reference: cleanRef,
      amountPaidZarCents: expectedAmountZarCents,
      cardToken: token,
    );
  }
}

/// PayJustNow Buy-Now-Pay-Later (3 interest-free monthly instalments) adapter.
class PayJustNowBnplAdapter implements SouthAfricanPaymentGatewayAdapter {
  PayJustNowBnplAdapter({
    String merchantId = 'abe_za_sandbox_merchant',
    this.callbackUrl = 'https://abe.co.za/checkout/payjustnow-callback',
  }) : merchantId = InputSanitiser.sanitiseText(merchantId, maxLength: 128) {
    if (!callbackUrl.startsWith('https://')) {
      throw ArgumentError('PayJustNow callbackUrl must use HTTPS.');
    }
  }

  final String merchantId;
  final String callbackUrl;

  @override
  PaymentGatewayProvider get provider => PaymentGatewayProvider.payJustNow;

  @override
  Future<GatewayCheckoutSession> createCheckoutSession({
    required String bookingId,
    required String clientId,
    required String clientEmail,
    required int amountDueZarCents,
    required PaymentMethodType method,
    required String idempotencyKey,
    bool saveCardToken = false,
    String? savedCardAuthorizationCode,
    Map<String, String> metadata = const <String, String>{},
  }) async {
    if (method != PaymentMethodType.bnplPayJustNow) {
      throw ArgumentError(
        'PayJustNowBnplAdapter only supports PaymentMethodType.bnplPayJustNow.',
      );
    }

    final validAmount = InputSanitiser.requireNonNegativeInt(
      amountDueZarCents,
      fieldName: 'amountDueZarCents',
      strictlyPositive: true,
    );
    final plan = PayJustNowInstalmentPlan.fromTotalCents(validAmount);
    final cleanRef = 'ABE_PJN_${_shortSafeRef(bookingId, idempotencyKey)}';

    return GatewayCheckoutSession(
      sessionId: 'pjn_order_$cleanRef',
      provider: provider,
      method: method,
      reference: cleanRef,
      authorizationUrl: 'https://sandbox.payjustnow.com/checkout/$cleanRef',
      amountDueZarCents: validAmount,
      idempotencyKey: idempotencyKey,
      instalmentPlan: plan,
      metadata: <String, String>{
        ...metadata,
        'currency': 'ZAR',
        'merchantId': merchantId,
        'instalments': '3',
        'firstInstalmentCents': plan.firstInstalmentCents.toString(),
      },
    );
  }

  @override
  Future<GatewayVerificationResponse> verifyCheckoutTransaction({
    required String reference,
    required int expectedAmountZarCents,
    required String clientId,
    bool saveCardToken = false,
  }) async {
    final cleanRef = InputSanitiser.sanitiseText(reference, maxLength: 128);
    if (!cleanRef.startsWith('ABE_PJN_')) {
      return GatewayVerificationResponse(
        verified: false,
        provider: provider,
        reference: cleanRef,
        amountPaidZarCents: 0,
        failureReason: 'Invalid PayJustNow order reference.',
      );
    }

    return GatewayVerificationResponse(
      verified: true,
      provider: provider,
      reference: cleanRef,
      amountPaidZarCents: expectedAmountZarCents,
    );
  }
}

String _shortSafeRef(String bookingId, String idempotencyKey) {
  final cleanBooking = InputSanitiser.sanitiseText(bookingId, maxLength: 32)
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final cleanKey = InputSanitiser.sanitiseText(idempotencyKey, maxLength: 32)
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final bPart = cleanBooking.isEmpty
      ? 'BK'
      : cleanBooking.substring(0, cleanBooking.length.clamp(0, 12));
  final kPart = cleanKey.isEmpty
      ? 'IDEM'
      : cleanKey.substring(0, cleanKey.length.clamp(0, 12));
  return '${bPart}_$kPart';
}
