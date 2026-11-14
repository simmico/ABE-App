import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../domain/services/salon_partner_portal_service.dart';

/// Salon Partner "Empty Chair" Portal for independent commercial salons in CPT & JHB.
class SalonPartnerPortalScreen extends StatefulWidget {
  const SalonPartnerPortalScreen({
    super.key,
    required this.portalService,
    this.initialCity = 'ALL',
    this.onBack,
  });

  final SalonPartnerPortalService portalService;
  final String initialCity;
  final VoidCallback? onBack;

  @override
  State<SalonPartnerPortalScreen> createState() =>
      _SalonPartnerPortalScreenState();
}

class _SalonPartnerPortalScreenState extends State<SalonPartnerPortalScreen> {
  late String _cityFilter;
  final TextEditingController _salonNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(
    text: '88 Main Road, Sea Point, Cape Town',
  );
  final TextEditingController _windowController =
      TextEditingController(text: 'Wed & Thu • 10:00 to 14:00');
  final TextEditingController _feeController =
      TextEditingController(text: '130');
  String _publishCity = 'CPT';
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _cityFilter = widget.initialCity.toUpperCase();
    if (_cityFilter == 'JHB') _publishCity = 'JHB';
  }

  @override
  void dispose() {
    _salonNameController.dispose();
    _addressController.dispose();
    _windowController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _handlePublishChair() {
    final name = InputSanitiser.sanitiseText(
      _salonNameController.text,
      maxLength: 120,
    );
    final address = InputSanitiser.sanitiseText(
      _addressController.text,
      maxLength: 200,
    );
    final fee = int.tryParse(_feeController.text.trim()) ?? 0;
    if (name.isEmpty || address.isEmpty || fee <= 0) {
      setState(() {
        _isError = true;
        _statusMessage =
            'Enter a commercial salon name, street address, and positive chair fee.';
      });
      return;
    }

    final city = _publishCity == 'JHB' ? 'JHB' : 'CPT';
    final seq = DateTime.now().millisecondsSinceEpoch;
    try {
      widget.portalService.publishEmptyChairSlot(
        slotId: 'chair_${city.toLowerCase()}_$seq',
        venueId: 'venue_${city.toLowerCase()}_$seq',
        venueName: name,
        city: city,
        suburb: city == 'CPT' ? 'Sea Point' : 'Rosebank',
        address: address,
        chairFeeZar: fee,
        windowLabel: _windowController.text.trim(),
      );
      _salonNameController.clear();
      setState(() {
        _isError = false;
        _statusMessage = 'Published Empty Chair slot for $name ($city).';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage =
            'Only verified commercial salon addresses are accepted.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final slots = widget.portalService.getSlotsForCity(_cityFilter);

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('salon_portal_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Empty Chair Salon Portal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BrandConfig.surfaceCard,
                borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                border: Border.all(color: BrandConfig.champagne),
                boxShadow: BrandConfig.softCardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Guaranteed Chair Revenue',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'R${widget.portalService.totalGuaranteedChairRevenueZar}',
                          key: const Key('salon_guaranteed_revenue_value'),
                          style: textTheme.displaySmall?.copyWith(
                            fontFamily: BrandConfig.bodyFontFamily,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: BrandConfig.sageSoft,
                      borderRadius:
                          BorderRadius.circular(BrandConfig.pillRadius),
                    ),
                    child: Text(
                      'Verified Commercial Venues',
                      style: textTheme.labelMedium?.copyWith(
                        color: BrandConfig.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final city in const <String>['ALL', 'CPT', 'JHB'])
                  ChoiceChip(
                    key: Key('salon_city_filter_$city'),
                    label: Text(city),
                    selected: _cityFilter == city,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => setState(() => _cityFilter = city),
                  ),
              ],
            ),
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError
                        ? BrandConfig.errorSoft
                        : BrandConfig.sageSoft,
                    borderRadius:
                        BorderRadius.circular(BrandConfig.inputRadius),
                    border: Border.all(
                      color: _isError
                          ? BrandConfig.errorTerracotta
                          : BrandConfig.sageSuccess,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandConfig.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('List an Off-Peak Empty Chair', style: textTheme.headlineMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final city in const <String>['CPT', 'JHB'])
                  ChoiceChip(
                    key: Key('salon_publish_city_$city'),
                    label: Text('$city Salon'),
                    selected: _publishCity == city,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => setState(() => _publishCity = city),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('salon_name_input'),
              controller: _salonNameController,
              decoration: const InputDecoration(
                labelText: 'Commercial Salon Name',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('salon_address_input'),
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Commercial Street Address (CPT / JHB)',
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final windowField = TextField(
                  controller: _windowController,
                  decoration: const InputDecoration(
                    labelText: 'Quiet Window',
                  ),
                );
                final feeField = TextField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chair Fee (ZAR)',
                  ),
                );
                if (constraints.maxWidth < 420) {
                  return Column(
                    children: <Widget>[
                      windowField,
                      const SizedBox(height: 10),
                      feeField,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(flex: 2, child: windowField),
                    const SizedBox(width: 8),
                    Expanded(child: feeField),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('salon_publish_chair_button'),
                onPressed: _handlePublishChair,
                child: Text('Publish Empty Chair Slot ($_publishCity)'),
              ),
            ),
            const SizedBox(height: 18),
            Text('Active Partner Chair Slots', style: textTheme.headlineMedium),
            const SizedBox(height: 10),
            if (slots.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BrandConfig.surfaceCard,
                  borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                  border: Border.all(color: BrandConfig.borderWarm),
                ),
                child: Text(
                  'No partner chair slots listed for this city yet.',
                  style: textTheme.bodyMedium,
                ),
              ),
            for (final slot in slots)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BrandConfig.surfaceCard,
                  borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                  border: Border.all(color: BrandConfig.borderWarm),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${slot.venueName} (${slot.city})',
                            style: textTheme.titleSmall,
                          ),
                          Text(
                            '${slot.windowLabel} • R${slot.chairFeeZar} chair fee • '
                            '${widget.portalService.bookingsCountForSlot(slot.slotId)} bookings',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Availability for ${slot.venueName}',
                      toggled: slot.isAvailable,
                      child: Switch(
                        key: Key('salon_slot_switch_${slot.slotId}'),
                        value: slot.isAvailable,
                        onChanged: (next) {
                          widget.portalService.toggleSlotAvailability(
                            slot.slotId,
                            isAvailable: next,
                          );
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
