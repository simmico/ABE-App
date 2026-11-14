import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../booking/domain/models/booking_modifier.dart';
import '../../../booking/domain/models/booking_venue_models.dart';
import '../../../portfolio/domain/models/visual_contract_item.dart';
import '../../domain/models/payment_models.dart';
import '../../domain/services/checkout_payment_service.dart';

/// South African ZAR Checkout & Payment Screen.
///
/// Automatically applies promo/apology vouchers and the client's closed-loop
/// ABE Wallet balance before charging the remainder via Paystack / Peach Payments
/// (Card tokenisation or Instant EFT) or PayJustNow BNPL (gated by feature flag).
class CheckoutPaymentScreen extends StatefulWidget {
  const CheckoutPaymentScreen({
    super.key,
    required this.bookingId,
    required this.clientId,
    required this.clientEmail,
    required this.contract,
    required this.quote,
    required this.venueSelection,
    required this.paymentService,
    this.onBack,
    this.onCheckoutConfirmed,
  });

  final String bookingId;
  final String clientId;
  final String clientEmail;
  final VisualContractItem contract;
  final BookingPriceQuote quote;
  final BookingVenueSelection venueSelection;
  final CheckoutPaymentService paymentService;
  final VoidCallback? onBack;
  final void Function(PaymentCheckoutReceipt receipt)? onCheckoutConfirmed;

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  final TextEditingController _voucherController = TextEditingController();
  late String? _appliedVoucherCode;
  PaymentMethodType _selectedMethod = PaymentMethodType.card;
  PaymentGatewayProvider _selectedCardEftProvider =
      PaymentGatewayProvider.paystack;
  bool _saveCardToken = true;
  bool _isProcessing = false;
  String? _errorBanner;
  PaymentCheckoutReceipt? _confirmedReceipt;
  int _attemptNonce = 1;

  String get _checkoutIdempotencyKey =>
      'chk_${widget.bookingId}_${widget.clientId}_v$_attemptNonce';

  String _formatZar(double amount) {
    final rounded = amount.roundToDouble();
    if ((amount - rounded).abs() < 0.005) {
      return 'R${rounded.toStringAsFixed(0)}';
    }
    return 'R${amount.toStringAsFixed(2)}';
  }

  String _humaniseCheckoutError(Object error) {
    final message = error
        .toString()
        .replaceFirst(
          RegExp(r'^(StateError|Bad state|Invalid argument\(s\)|Exception):\s*'),
          '',
        )
        .trim();
    if (message.isEmpty) {
      return 'Could not complete payment right now. Please review your details and try again.';
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _appliedVoucherCode = widget.quote.appliedVoucherCode;
    if (_appliedVoucherCode != null) {
      _voucherController.text = _appliedVoucherCode!;
    }
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  CheckoutBreakdownPreview get _preview {
    return widget.paymentService.previewCheckoutBreakdown(
      clientId: widget.clientId,
      subtotalZar: widget.quote.subtotalPriceZar,
      rawVoucherCode: _appliedVoucherCode,
    );
  }

  void _applyVoucher() {
    setState(() {
      _errorBanner = null;
      _attemptNonce++;
      _appliedVoucherCode = _voucherController.text.trim().isEmpty
          ? null
          : _voucherController.text.trim();
    });
  }

  Future<void> _submitPayment() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _errorBanner = null;
    });

    try {
      final preview = _preview;
      final effectiveMethod = preview.remainingGatewayDueZarCents == 0
          ? PaymentMethodType.walletFullCover
          : _selectedMethod;

      final request = PaymentCheckoutRequest(
        bookingId: widget.bookingId,
        clientId: widget.clientId,
        techId: widget.contract.techId,
        clientEmail: widget.clientEmail,
        quote: widget.quote,
        venueSelection: widget.venueSelection,
        paymentMethod: effectiveMethod,
        preferredCardOrEftProvider: _selectedCardEftProvider,
        voucherCode: preview.appliedVoucherCode,
        saveCardForFutureBookings: _saveCardToken,
        idempotencyKey: _checkoutIdempotencyKey,
      );

      var receipt = await widget.paymentService.initiateCheckout(request);
      if (!receipt.isConfirmed) {
        receipt = await widget.paymentService.confirmGatewayPayment(
          idempotencyKey: _checkoutIdempotencyKey,
        );
      }

      if (!mounted) return;
      setState(() {
        _confirmedReceipt = receipt;
        _isProcessing = false;
      });
      widget.onCheckoutConfirmed?.call(receipt);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorBanner = _humaniseCheckoutError(error);
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = _preview;
    final payJustNowEnabled = widget.paymentService.featureFlags.isEnabled(
      FeatureFlagsService.payJustNowBnpl,
    );

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        backgroundColor: BrandConfig.bgCream,
        surfaceTintColor: Colors.transparent,
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('checkout_back_button'),
                tooltip: 'Back to booking summary',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: Text(
          'Secure ZAR Checkout',
          style: textTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: _confirmedReceipt != null
            ? _buildConfirmationView(textTheme, _confirmedReceipt!)
            : _buildCheckoutForm(textTheme, preview, payJustNowEnabled),
      ),
    );
  }

  Widget _buildCheckoutForm(
    TextTheme textTheme,
    CheckoutBreakdownPreview preview,
    bool payJustNowEnabled,
  ) {
    final dueZar = preview.remainingGatewayDueZar;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildBookingAndVenueCard(textTheme),
          const SizedBox(height: 16),
          _buildVoucherAndWalletCard(textTheme, preview),
          const SizedBox(height: 16),
          if (preview.remainingGatewayDueZarCents > 0) ...<Widget>[
            _buildGatewaySelectionCard(
              textTheme,
              preview,
              payJustNowEnabled,
            ),
            const SizedBox(height: 16),
          ],
          if (_errorBanner != null) ...<Widget>[
            Semantics(
              container: true,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BrandConfig.errorSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
                  border: Border.all(color: BrandConfig.errorTerracotta),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline_rounded,
                      color: BrandConfig.errorTerracotta,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorBanner!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: BrandConfig.espresso,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: ElevatedButton(
              key: const Key('checkout_pay_button'),
              onPressed: _isProcessing ? null : _submitPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandConfig.roseDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
              ),
              child: Text(
                _isProcessing
                    ? 'Processing payment...'
                    : (preview.remainingGatewayDueZarCents == 0
                        ? 'Confirm Booking with ABE Wallet'
                        : 'Pay ${_formatZar(dueZar)} Securely'),
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingAndVenueCard(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.contract.title,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'With ${widget.contract.techDisplayName} • ${widget.quote.totalDurationMinutes} mins',
            style: textTheme.bodyMedium?.copyWith(color: BrandConfig.textMuted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BrandConfig.sageSoft,
              borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: BrandConfig.sageSuccess,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verified Commercial Venue: ${widget.venueSelection.venue.name} '
                    '(${widget.venueSelection.venue.city})',
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandConfig.espresso,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherAndWalletCard(
    TextTheme textTheme,
    CheckoutBreakdownPreview preview,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text('Wallet & Promo Voucher', style: textTheme.titleMedium),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('checkout_voucher_input'),
                  controller: _voucherController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _applyVoucher(),
                  decoration: InputDecoration(
                    labelText: 'Promo or apology voucher code',
                    hintText: 'e.g. ABE_CARE_50',
                    filled: true,
                    fillColor: BrandConfig.bgCream,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(BrandConfig.inputRadius),
                      borderSide:
                          const BorderSide(color: Color(0xFFA89592)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: const Key('checkout_apply_voucher_button'),
                onPressed: _applyVoucher,
                child: const Text('Apply'),
              ),
            ],
          ),
          if (preview.voucherMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                preview.voucherMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: preview.voucherDiscountZarCents > 0
                      ? const Color(0xFF3D6B55)
                      : BrandConfig.espresso,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Divider(height: 24, color: BrandConfig.borderWarm),
          _priceRow(
            textTheme,
            'Visual Contract Subtotal',
            _formatZar(preview.grossTotalZar),
          ),
          if (preview.voucherDiscountZarCents > 0) ...<Widget>[
            const SizedBox(height: 6),
            _priceRow(
              textTheme,
              'Voucher Discount',
              '-${_formatZar(preview.voucherDiscountZar)}',
              valueColor: const Color(0xFF3D6B55),
            ),
          ],
          const SizedBox(height: 6),
          _priceRow(
            textTheme,
            'ABE Wallet Auto-Applied (Available ${_formatZar(preview.walletAvailableZar)})',
            '-${_formatZar(preview.walletAppliedZar)}',
            valueColor: preview.walletAppliedZarCents > 0
                ? const Color(0xFF3D6B55)
                : BrandConfig.textMuted,
          ),
          const Divider(height: 20, color: BrandConfig.borderWarm),
          _priceRow(
            textTheme,
            'Remaining Due Today',
            _formatZar(preview.remainingGatewayDueZar),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildGatewaySelectionCard(
    TextTheme textTheme,
    CheckoutBreakdownPreview preview,
    bool payJustNowEnabled,
  ) {
    final plan = preview.payJustNowPlan;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text('South African Payment Method', style: textTheme.titleMedium),
          ),
          const SizedBox(height: 12),
          _methodOption(
            key: const Key('payment_method_card'),
            method: PaymentMethodType.card,
            title: 'Debit or Credit Card',
            subtitle: 'Visa & Mastercard in ZAR with secure card tokenisation',
            icon: Icons.credit_card_rounded,
          ),
          const SizedBox(height: 10),
          _methodOption(
            key: const Key('payment_method_eft'),
            method: PaymentMethodType.instantEft,
            title: 'Instant EFT (SA Banks)',
            subtitle: 'FNB, Capitec, Standard Bank, Absa, Nedbank & TymeBank',
            icon: Icons.account_balance_outlined,
          ),
          if (payJustNowEnabled && plan != null) ...<Widget>[
            const SizedBox(height: 10),
            _methodOption(
              key: const Key('payment_method_payjustnow'),
              method: PaymentMethodType.bnplPayJustNow,
              title: 'PayJustNow BNPL (0% Interest)',
              subtitle:
                  '3 monthly instalments of R${plan.firstInstalmentZar.toStringAsFixed(2)}',
              icon: Icons.calendar_view_week_rounded,
            ),
          ],
          if (_selectedMethod == PaymentMethodType.card ||
              _selectedMethod == PaymentMethodType.instantEft) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Gateway Processor',
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('gateway_provider_paystack'),
                  label: const Text('Paystack ZA'),
                  selected:
                      _selectedCardEftProvider == PaymentGatewayProvider.paystack,
                  selectedColor: BrandConfig.blushSoft,
                  onSelected: (_) => setState(() {
                    _attemptNonce++;
                    _selectedCardEftProvider = PaymentGatewayProvider.paystack;
                  }),
                ),
                ChoiceChip(
                  key: const Key('gateway_provider_peach'),
                  label: const Text('Peach Payments'),
                  selected: _selectedCardEftProvider ==
                      PaymentGatewayProvider.peachPayments,
                  selectedColor: BrandConfig.blushSoft,
                  onSelected: (_) => setState(() {
                    _attemptNonce++;
                    _selectedCardEftProvider =
                        PaymentGatewayProvider.peachPayments;
                  }),
                ),
              ],
            ),
          ],
          if (_selectedMethod == PaymentMethodType.card) ...<Widget>[
            const SizedBox(height: 8),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                key: const Key('checkout_save_card_switch'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: BrandConfig.roseDark,
                title: const Text('Save card securely for faster rebooking'),
                subtitle: const Text(
                  'Card details are tokenised by the gateway; raw numbers are never stored.',
                ),
                value: _saveCardToken,
                onChanged: (value) => setState(() => _saveCardToken = value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _methodOption({
    required Key key,
    required PaymentMethodType method,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selectedMethod == method;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: '$title, $subtitle',
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
        onTap: () => setState(() {
          _attemptNonce++;
          _selectedMethod = method;
        }),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? BrandConfig.blushSoft : BrandConfig.bgCream,
            borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
            border: Border.all(
              color: selected ? BrandConfig.roseDark : const Color(0xFFA89592),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: selected ? BrandConfig.roseDark : BrandConfig.espresso,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: BrandConfig.espresso,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BrandConfig.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? BrandConfig.roseDark : BrandConfig.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationView(
    TextTheme textTheme,
    PaymentCheckoutReceipt receipt,
  ) {
    final pinDigitsLabel = receipt.clientBookingPin == null
        ? ''
        : receipt.clientBookingPin!.split('').join(' ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: BrandConfig.surfaceCard,
          borderRadius: BorderRadius.circular(BrandConfig.largeCardRadius),
          border: Border.all(color: BrandConfig.borderWarm),
          boxShadow: BrandConfig.softCardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF3D6B55),
              size: 48,
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                'Booking Confirmed',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reference: ${receipt.reference} (${receipt.provider.displayName})',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: BrandConfig.textMuted),
            ),
            const SizedBox(height: 20),
            if (receipt.clientBookingPin != null)
              Container(
                key: const Key('checkout_confirmed_pin_card'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                  border: Border.all(color: BrandConfig.roseDark),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Your 4-Digit Appointment Start PIN',
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: '4-digit start PIN: $pinDigitsLabel',
                      child: ExcludeSemantics(
                        child: Text(
                          receipt.clientBookingPin!,
                          style: textTheme.headlineLarge?.copyWith(
                            fontFamily: BrandConfig.bodyFontFamily,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            color: BrandConfig.espresso,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Share this PIN only when you are seated at the verified venue.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(
    TextTheme textTheme,
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    final style = (isBold ? textTheme.titleMedium : textTheme.bodyMedium)
        ?.copyWith(
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(child: Text(label, style: style)),
        Text(
          value,
          style: style?.copyWith(
            color: valueColor ?? BrandConfig.espresso,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
