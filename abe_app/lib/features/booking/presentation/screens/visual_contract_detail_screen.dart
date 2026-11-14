import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../auth/domain/models/tech_profile.dart';
import '../../../portfolio/domain/models/visual_contract_item.dart';
import '../../domain/models/booking_modifier.dart';
import '../../domain/services/booking_calculator_service.dart';

/// Visual Contract Detail & Dynamic Modifier Booking Screen.
///
/// Displays the selected [VisualContractItem], verified commercial salon details,
/// tactile modifier toggles and per-nail steppers (*Soak-Off / Removal*,
/// *Extra Length*, *Single Nail Repair*), promo/courtesy voucher validation,
/// and an animated sticky bottom bar showing live **Total Price (`R...`)**
/// and **Total Duration (`... mins`)**.
class VisualContractDetailScreen extends StatefulWidget {
  const VisualContractDetailScreen({
    super.key,
    required this.contract,
    this.calculatorService = const BookingCalculatorService(),
    this.customModifiers,
    this.onConfirmBooking,
    this.onBack,
  });

  final VisualContractItem contract;
  final BookingCalculatorService calculatorService;
  final List<BookingModifier>? customModifiers;
  final void Function(BookingPriceQuote quote)? onConfirmBooking;
  final VoidCallback? onBack;

  @override
  State<VisualContractDetailScreen> createState() =>
      _VisualContractDetailScreenState();
}

class _VisualContractDetailScreenState
    extends State<VisualContractDetailScreen> {
  late final List<BookingModifier> _modifiers;
  final Map<String, int> _selectedQuantities = <String, int>{};
  final TextEditingController _voucherController = TextEditingController();
  String? _appliedVoucherInput;

  @override
  void initState() {
    super.initState();
    _modifiers = widget.customModifiers ??
        widget.calculatorService.resolveModifiersForContract(widget.contract);
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  BookingPriceQuote get _currentQuote {
    return widget.calculatorService.calculateQuote(
      contract: widget.contract,
      modifiers: _modifiers,
      selectedQuantities: _selectedQuantities,
      rawVoucherCode: _appliedVoucherInput,
    );
  }

  void _toggleModifier(BookingModifier modifier) {
    setState(() {
      final current = _selectedQuantities[modifier.id] ?? 0;
      if (current > 0) {
        _selectedQuantities[modifier.id] = 0;
      } else {
        _selectedQuantities[modifier.id] = 1;
      }
    });
  }

  void _adjustModifierQuantity(BookingModifier modifier, int delta) {
    setState(() {
      final current = _selectedQuantities[modifier.id] ?? 0;
      final next = (current + delta).clamp(0, modifier.maxQuantity);
      _selectedQuantities[modifier.id] = next;
    });
  }

  void _applyVoucherCode([String? presetCode]) {
    setState(() {
      if (presetCode != null) {
        _voucherController.text = presetCode;
      }
      _appliedVoucherInput = _voucherController.text.trim();
    });
  }

  void _clearVoucherCode() {
    setState(() {
      _voucherController.clear();
      _appliedVoucherInput = null;
    });
  }

  void _handleConfirmTap(BookingPriceQuote quote) {
    if (widget.onConfirmBooking != null) {
      widget.onConfirmBooking!(quote);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BrandConfig.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: BrandConfig.blushSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_outlined,
                        color: BrandConfig.sageSuccess,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Visual Contract Locked In',
                        style: textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.contract.title} with ${widget.contract.techDisplayName}',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Commercial Venue: ${widget.contract.venueName} (${widget.contract.city})',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BrandConfig.bgCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BrandConfig.borderWarm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Total Contract Price',
                            style: TextStyle(
                              fontFamily: BrandConfig.bodyFontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: BrandConfig.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quote.formattedTotalPayable,
                            key: const Key('modal_confirmed_total_price'),
                            style: const TextStyle(
                              fontFamily: BrandConfig.bodyFontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: BrandConfig.espresso,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          const Text(
                            'Locked Duration',
                            style: TextStyle(
                              fontFamily: BrandConfig.bodyFontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: BrandConfig.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quote.formattedTotalDuration,
                            key: const Key('modal_confirmed_total_duration'),
                            style: const TextStyle(
                              fontFamily: BrandConfig.bodyFontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: BrandConfig.espresso,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your unique 4-digit appointment start PIN will be generated once your time slot is confirmed at ${widget.contract.venueName}.',
                  style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const Key('modal_done_button'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _currentQuote;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('booking_detail_back_button'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Discovery Feed',
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Visual Contract Booking'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildContractHeroHeader(textTheme),
              const SizedBox(height: 18),
              _buildVenueGuaranteeBanner(textTheme),
              const SizedBox(height: 24),
              _buildModifiersSection(textTheme),
              const SizedBox(height: 24),
              _buildVoucherSection(textTheme, quote),
              const SizedBox(height: 24),
              _buildPriceBreakdownCard(textTheme, quote),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildStickyBottomBar(quote),
    );
  }

  Widget _buildContractHeroHeader(TextTheme textTheme) {
    final item = widget.contract;
    final isCertifiedPro = item.techTierBadge == TechTierBadge.certifiedPro;

    return Container(
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.largeCardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  BrandConfig.blushSoft,
                  Color(0xFFEED5D9),
                  Color(0xFFE5C8C0),
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xE6FFFFFF),
                          shape: BoxShape.circle,
                          border: Border.all(color: BrandConfig.borderWarm),
                        ),
                        child: const Icon(
                          Icons.spa_outlined,
                          color: BrandConfig.roseDark,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.styleCategory,
                        style: const TextStyle(
                          fontFamily: BrandConfig.bodyFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BrandConfig.espresso,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCertifiedPro
                          ? BrandConfig.espresso
                          : BrandConfig.surfaceCard,
                      borderRadius:
                          BorderRadius.circular(BrandConfig.pillRadius),
                      border: Border.all(
                        color: isCertifiedPro
                            ? BrandConfig.champagne
                            : BrandConfig.borderWarm,
                      ),
                    ),
                    child: Text(
                      item.techTierBadge.label,
                      style: TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCertifiedPro
                            ? BrandConfig.surfaceCard
                            : BrandConfig.espresso,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: BrandConfig.surfaceCard,
                      borderRadius:
                          BorderRadius.circular(BrandConfig.pillRadius),
                      border: Border.all(color: BrandConfig.borderWarm),
                    ),
                    child: Text(
                      BrandConfig.cityDisplayNames[item.city] ?? item.city,
                      style: const TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: BrandConfig.espresso,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: BrandConfig.roseDark,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Nail Technician: ${item.techDisplayName}',
                        style: const TextStyle(
                          fontFamily: BrandConfig.bodyFontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BrandConfig.espresso,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    _InfoPill(
                      icon: Icons.payments_outlined,
                      label: 'Base Look: ${item.formattedBasePrice}',
                    ),
                    _InfoPill(
                      icon: Icons.schedule_outlined,
                      label: 'Base Time: ${item.formattedBaseDuration}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueGuaranteeBanner(TextTheme textTheme) {
    final item = widget.contract;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: BrandConfig.blushSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: BrandConfig.sageSuccess,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${item.venueName} • ${item.venueType.label}',
                  style: const TextStyle(
                    fontFamily: BrandConfig.bodyFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BrandConfig.espresso,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  BrandConfig.venueSafetyStatement,
                  style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifiersSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Optional Studio Add-Ons',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Toggle any extras you need below. The total Rand price and appointment duration update immediately.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        if (_modifiers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BrandConfig.surfaceCard,
              borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
              border: Border.all(color: BrandConfig.borderWarm),
            ),
            child: Text(
              'No extra add-ons are needed for this Visual Contract look.',
              style: textTheme.bodyMedium,
            ),
          )
        else
          for (final modifier in _modifiers) ...<Widget>[
            _buildModifierCard(modifier),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildModifierCard(BookingModifier modifier) {
    final quantity = _selectedQuantities[modifier.id] ?? 0;
    final isSelected = quantity > 0;
    final isPerNail = modifier.type == BookingModifierType.perNailCount;

    return Semantics(
      button: true,
      toggled: isSelected,
      label:
          '${modifier.name}, ${modifier.formattedSummary}, ${isSelected ? 'selected quantity $quantity' : 'not selected'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('modifier_row_${modifier.id}'),
          borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
          onTap: () => _toggleModifier(modifier),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? BrandConfig.blushSoft
                  : BrandConfig.surfaceCard,
              borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
              border: Border.all(
                color: isSelected
                    ? BrandConfig.rosePrimary
                    : BrandConfig.borderWarm,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              modifier.name,
                              style: const TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: BrandConfig.espresso,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? BrandConfig.espresso
                                  : BrandConfig.bgCream,
                              borderRadius: BorderRadius.circular(
                                BrandConfig.pillRadius,
                              ),
                            ),
                            child: Text(
                              modifier.formattedSummary,
                              style: TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? BrandConfig.surfaceCard
                                    : BrandConfig.espresso,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (modifier.subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          modifier.subtitle,
                          style: const TextStyle(
                            fontFamily: BrandConfig.bodyFontFamily,
                            fontSize: 13,
                            color: BrandConfig.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isPerNail)
                  _buildPerNailStepper(modifier, quantity)
                else
                  _buildToggleIndicator(isSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleIndicator(bool isSelected) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected ? BrandConfig.rosePrimary : BrandConfig.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                isSelected ? BrandConfig.rosePrimary : BrandConfig.borderWarm,
            width: 1.5,
          ),
        ),
        child: Icon(
          isSelected ? Icons.check : Icons.add,
          size: 16,
          color: isSelected ? BrandConfig.surfaceCard : BrandConfig.espresso,
        ),
      ),
    );
  }

  Widget _buildPerNailStepper(BookingModifier modifier, int quantity) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: Key('modifier_decrement_${modifier.id}'),
          onPressed: quantity > 0
              ? () => _adjustModifierQuantity(modifier, -1)
              : null,
          tooltip: 'Decrease ${modifier.name} count',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.remove_circle_outline),
          color: BrandConfig.espresso,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 28),
          alignment: Alignment.center,
          child: Text(
            '$quantity',
            key: Key('modifier_quantity_${modifier.id}'),
            style: const TextStyle(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: BrandConfig.espresso,
            ),
          ),
        ),
        IconButton(
          key: Key('modifier_increment_${modifier.id}'),
          onPressed: quantity < modifier.maxQuantity
              ? () => _adjustModifierQuantity(modifier, 1)
              : null,
          tooltip: 'Increase ${modifier.name} count',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.add_circle_outline),
          color: BrandConfig.roseDark,
        ),
      ],
    );
  }

  Widget _buildVoucherSection(TextTheme textTheme, BookingPriceQuote quote) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Promo or Courtesy Voucher',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Have an ABE welcome code or a tech-cancellation courtesy voucher? Apply it below.',
            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('booking_voucher_input'),
                  controller: _voucherController,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _applyVoucherCode(),
                  decoration: const InputDecoration(
                    labelText: 'Voucher Code',
                    hintText: 'e.g. ABEWELCOME50',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                key: const Key('booking_voucher_apply_button'),
                onPressed: () => _applyVoucherCode(),
                child: const Text('Apply'),
              ),
              if (_appliedVoucherInput != null &&
                  _appliedVoucherInput!.isNotEmpty) ...<Widget>[
                const SizedBox(width: 6),
                IconButton(
                  key: const Key('booking_voucher_clear_button'),
                  tooltip: 'Clear voucher code',
                  onPressed: _clearVoucherCode,
                  icon: const Icon(Icons.close),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final preset
                  in widget.calculatorService.voucherCatalog)
                ActionChip(
                  key: Key('voucher_preset_${preset.code}'),
                  label: Text('${preset.code} (-R${preset.discountAmountZar})'),
                  onPressed: () => _applyVoucherCode(preset.code),
                ),
            ],
          ),
          if (quote.voucherMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Semantics(
              container: true,
              liveRegion: true,
              child: Container(
                key: const Key('booking_voucher_message'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: quote.isVoucherValid
                      ? const Color(0x1A5E8C76)
                      : const Color(0x1AB85450),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: quote.isVoucherValid
                        ? BrandConfig.sageSuccess
                        : BrandConfig.errorTerracotta,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      quote.isVoucherValid
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: quote.isVoucherValid
                          ? BrandConfig.sageSuccess
                          : BrandConfig.errorTerracotta,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quote.voucherMessage!,
                        style: const TextStyle(
                          fontFamily: BrandConfig.bodyFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BrandConfig.espresso,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard(
    TextTheme textTheme,
    BookingPriceQuote quote,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Visual Contract Breakdown',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _BreakdownRow(
            label:
                'Base Look (${widget.contract.formattedBaseDuration})',
            value: 'R${quote.basePriceZar}',
          ),
          for (final item in quote.selectedLineItems) ...<Widget>[
            const SizedBox(height: 8),
            _BreakdownRow(
              label: item.quantity > 1
                  ? '${item.modifier.name} x${item.quantity} (+${item.lineDurationMinutes} mins)'
                  : '${item.modifier.name} (+${item.lineDurationMinutes} mins)',
              value: '+R${item.linePriceZar}',
            ),
          ],
          if (quote.voucherDiscountZar > 0) ...<Widget>[
            const SizedBox(height: 8),
            _BreakdownRow(
              label: 'Voucher (${quote.appliedVoucherCode})',
              value: '-R${quote.voucherDiscountZar}',
              isHighlight: true,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _BreakdownRow(
            label: 'Total Locked Duration',
            value: quote.formattedTotalDuration,
            isBold: true,
          ),
          const SizedBox(height: 6),
          _BreakdownRow(
            label: 'Total Payable Today',
            value: quote.formattedTotalPayable,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(BookingPriceQuote quote) {
    return Container(
      decoration: const BoxDecoration(
        color: BrandConfig.surfaceCard,
        border: Border(
          top: BorderSide(color: BrandConfig.borderWarm, width: 1),
        ),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Total Price & Duration',
                        style: TextStyle(
                          fontFamily: BrandConfig.bodyFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BrandConfig.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Row(
                          key: ValueKey<String>(
                            '${quote.totalPayableZar}_${quote.totalDurationMinutes}',
                          ),
                          children: <Widget>[
                            Text(
                              quote.formattedTotalPayable,
                              key: const Key('booking_sticky_total_price'),
                              style: const TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: BrandConfig.espresso,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: BrandConfig.roseDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              quote.formattedTotalDuration,
                              key: const Key('booking_sticky_total_duration'),
                              style: const TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: BrandConfig.roseDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                key: const Key('booking_confirm_button'),
                onPressed: () => _handleConfirmTap(quote),
                child: const Text('Confirm Visual Contract'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BrandConfig.bgCream,
        borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: BrandConfig.espresso),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BrandConfig.espresso,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isBold;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final color = isHighlight ? BrandConfig.sageSuccess : BrandConfig.espresso;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? color : BrandConfig.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontFamily: BrandConfig.bodyFontFamily,
            fontSize: isBold ? 15 : 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
