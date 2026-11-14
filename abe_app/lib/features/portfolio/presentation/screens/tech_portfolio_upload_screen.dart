import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../../core/utils/input_sanitiser.dart';
import '../../../auth/domain/models/tech_profile.dart';
import '../../../booking/domain/models/booking_modifier.dart';
import '../../../venue/domain/models/commercial_venue.dart';
import '../../data/repositories/visual_contract_repository.dart';
import '../../domain/models/visual_contract_item.dart';

/// Preset studio nail photography option for previewing and uploading Visual Contracts.
class StudioPhotoSample {
  const StudioPhotoSample({
    required this.id,
    required this.label,
    required this.photoUrl,
    required this.styleCategory,
  });

  final String id;
  final String label;
  final String photoUrl;
  final String styleCategory;
}

/// Tech Portfolio Upload Screen (`TechPortfolioUploadScreen`).
///
/// Allows verified nail technicians in Cape Town (`CPT`) and Johannesburg (`JHB`)
/// to select a crisp `4:5` photo of their nail work, lock in a fixed base price
/// in ZAR and base duration in minutes, link a verified commercial studio or
/// partner salon, and toggle which optional modifiers apply to that look.
class TechPortfolioUploadScreen extends StatefulWidget {
  const TechPortfolioUploadScreen({
    super.key,
    this.techId = 'tech_cpt_01',
    this.techDisplayName = 'Nadia Jacobs',
    this.techTierBadge = TechTierBadge.certifiedPro,
    this.initialCity = 'CPT',
    this.availableVenues,
    this.repository,
    this.onContractPublished,
    this.onBack,
  });

  final String techId;
  final String techDisplayName;
  final TechTierBadge techTierBadge;
  final String initialCity;
  final List<CommercialVenue>? availableVenues;
  final VisualContractRepository? repository;
  final void Function(VisualContractItem createdContract)? onContractPublished;
  final VoidCallback? onBack;

  /// Minimum and maximum bounds for Visual Contract base prices and durations.
  static const int minBasePriceZar = 150;
  static const int maxBasePriceZar = 5000;
  static const int minBaseDurationMinutes = 30;
  static const int maxBaseDurationMinutes = 300;

  static const List<StudioPhotoSample> studioPhotoSamples = <StudioPhotoSample>[
    StudioPhotoSample(
      id: 'sample_biab_french',
      label: 'Almond BIAB & Micro French (4:5 Studio Crop)',
      photoUrl: 'https://assets.abe.co.za/studio/almond_biab_french_4x5.jpg',
      styleCategory: 'BIAB & Micro French',
    ),
    StudioPhotoSample(
      id: 'sample_glazed_gelx',
      label: 'Champagne Glazed Gel-X Extensions (4:5 Studio Crop)',
      photoUrl: 'https://assets.abe.co.za/studio/champagne_gelx_4x5.jpg',
      styleCategory: 'Gel-X Extensions & Chrome',
    ),
    StudioPhotoSample(
      id: 'sample_velvet_cateye',
      label: 'Dusty Rose Velvet Cat-Eye Set (4:5 Studio Crop)',
      photoUrl: 'https://assets.abe.co.za/studio/dusty_rose_cateye_4x5.jpg',
      styleCategory: 'Magnetic Velvet Gel',
    ),
    StudioPhotoSample(
      id: 'sample_tortoiseshell_art',
      label: 'Espresso & Gold Foil Hand-Painted Art (4:5 Studio Crop)',
      photoUrl: 'https://assets.abe.co.za/studio/espresso_gold_art_4x5.jpg',
      styleCategory: 'Hand-Painted Nail Art',
    ),
  ];

  /// Default verified commercial venues in CPT and JHB (Zero House Calls).
  static List<CommercialVenue> defaultVerifiedVenues() {
    return <CommercialVenue>[
      CommercialVenue(
        id: 'venue_cpt_seapoint_01',
        name: 'Atelier Rose Studio, Sea Point',
        city: 'CPT',
        suburb: 'Sea Point',
        address: '142 Regent Road, Sea Point, Cape Town',
        type: CommercialVenueType.verifiedStudio,
        isVerified: true,
      ),
      CommercialVenue(
        id: 'venue_cpt_claremont_02',
        name: 'Cavendish Lane Nail Bar, Claremont',
        city: 'CPT',
        suburb: 'Claremont',
        address: '18 Dreyer Street, Claremont, Cape Town',
        type: CommercialVenueType.partnerSalon,
        isVerified: true,
        emptyChairFeeZar: 65,
      ),
      CommercialVenue(
        id: 'venue_jhb_rosebank_01',
        name: 'House of Alabaster, Rosebank',
        city: 'JHB',
        suburb: 'Rosebank',
        address: '24 Cradock Avenue, Rosebank, Johannesburg',
        type: CommercialVenueType.verifiedStudio,
        isVerified: true,
      ),
      CommercialVenue(
        id: 'venue_jhb_sandton_02',
        name: 'Sandton Square Studio, Sandton',
        city: 'JHB',
        suburb: 'Sandton',
        address: '88 Maude Street, Sandton, Johannesburg',
        type: CommercialVenueType.verifiedStudio,
        isVerified: true,
      ),
    ];
  }

  @override
  State<TechPortfolioUploadScreen> createState() =>
      _TechPortfolioUploadScreenState();
}

class _TechPortfolioUploadScreenState extends State<TechPortfolioUploadScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController =
      TextEditingController(text: '450');
  final TextEditingController _durationController =
      TextEditingController(text: '90');

  late final VisualContractRepository _repository;
  late final List<CommercialVenue> _venues;
  late final List<BookingModifier> _modifierPresets;
  final Set<String> _enabledModifierIds = <String>{
    'mod_soak_off',
    'mod_extra_length',
    'mod_nail_repair',
  };

  late StudioPhotoSample _selectedPhoto;
  late String _selectedCity;
  late CommercialVenue _selectedVenue;
  String? _validationErrorMessage;
  VisualContractItem? _lastPublishedContract;

  @override
  void initState() {
    super.initState();
    _selectedPhoto = TechPortfolioUploadScreen.studioPhotoSamples.first;
    _venues = widget.availableVenues ??
        widget.repository?.verifiedVenues ??
        TechPortfolioUploadScreen.defaultVerifiedVenues();
    _repository = widget.repository ??
        VisualContractRepository(verifiedVenues: _venues);
    _selectedCity = widget.initialCity.toUpperCase() == 'JHB' ? 'JHB' : 'CPT';
    _selectedVenue = _venues.firstWhere(
      (v) => v.city == _selectedCity && v.isVerified,
      orElse: () => _venues.first,
    );
    _modifierPresets = BookingModifier.standardPresets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  List<CommercialVenue> get _cityVenues => _venues
      .where((v) => v.city == _selectedCity && v.isVerified)
      .toList(growable: false);

  void _selectCity(String cityCode) {
    setState(() {
      _selectedCity = cityCode;
      final matching = _cityVenues;
      if (matching.isNotEmpty) {
        _selectedVenue = matching.first;
      }
      _validationErrorMessage = null;
    });
  }

  void _toggleModifierPreset(String modifierId) {
    setState(() {
      if (_enabledModifierIds.contains(modifierId)) {
        _enabledModifierIds.remove(modifierId);
      } else {
        _enabledModifierIds.add(modifierId);
      }
      _validationErrorMessage = null;
    });
  }

  void _handlePublish() {
    final rawTitle = InputSanitiser.sanitiseText(
      _titleController.text,
      maxLength: 140,
    );
    if (rawTitle.length < 4) {
      setState(() {
        _validationErrorMessage =
            'Please enter a descriptive look title of at least 4 characters.';
      });
      return;
    }

    final parsedPrice = int.tryParse(_priceController.text.trim());
    if (parsedPrice == null ||
        parsedPrice < TechPortfolioUploadScreen.minBasePriceZar ||
        parsedPrice > TechPortfolioUploadScreen.maxBasePriceZar) {
      setState(() {
        _validationErrorMessage =
            'Base price must be between R${TechPortfolioUploadScreen.minBasePriceZar} and R${TechPortfolioUploadScreen.maxBasePriceZar}.';
      });
      return;
    }

    final parsedDuration = int.tryParse(_durationController.text.trim());
    if (parsedDuration == null ||
        parsedDuration < TechPortfolioUploadScreen.minBaseDurationMinutes ||
        parsedDuration > TechPortfolioUploadScreen.maxBaseDurationMinutes) {
      setState(() {
        _validationErrorMessage =
            'Base duration must be between ${TechPortfolioUploadScreen.minBaseDurationMinutes} and ${TechPortfolioUploadScreen.maxBaseDurationMinutes} minutes.';
      });
      return;
    }

    if (!_selectedVenue.isVerified) {
      setState(() {
        _validationErrorMessage =
            'Every Visual Contract must link to a verified commercial studio or partner salon.';
      });
      return;
    }

    final selectedModifiers = _modifierPresets
        .where((m) => _enabledModifierIds.contains(m.id))
        .map((m) => m.toContractModifier())
        .toList(growable: false);

    final VisualContractItem created;
    try {
      created = _repository.createVisualContract(
        techId: widget.techId,
        techDisplayName: widget.techDisplayName,
        techTierBadge: widget.techTierBadge,
        photoUrl: _selectedPhoto.photoUrl,
        title: rawTitle,
        basePriceZar: parsedPrice,
        baseDurationMinutes: parsedDuration,
        venueId: _selectedVenue.id,
        styleCategory: _selectedPhoto.styleCategory,
        allowedModifiers: selectedModifiers,
      );
    } on ArgumentError catch (error) {
      setState(() {
        _validationErrorMessage = error.message?.toString() ??
            'Could not publish Visual Contract. Please check your inputs.';
      });
      return;
    }

    setState(() {
      _validationErrorMessage = null;
      _lastPublishedContract = created;
    });

    if (widget.onContractPublished != null) {
      widget.onContractPublished!(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final previewPrice = int.tryParse(_priceController.text.trim()) ?? 450;
    final previewDuration = int.tryParse(_durationController.text.trim()) ?? 90;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('portfolio_upload_back_button'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('New Visual Contract'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Publish a Visual Contract Set',
                style: textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a crisp 4:5 photo of your nail work, lock in the exact Rand price and duration, and select which optional add-ons clients can toggle.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _buildPhotoSelectorCard(
                textTheme,
                previewPrice: previewPrice,
                previewDuration: previewDuration,
              ),
              const SizedBox(height: 20),
              _buildContractDetailsCard(textTheme),
              const SizedBox(height: 20),
              _buildVenueLinkCard(textTheme),
              const SizedBox(height: 20),
              _buildModifiersToggleCard(textTheme),
              if (_validationErrorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                Semantics(
                  container: true,
                  liveRegion: true,
                  child: Container(
                    key: const Key('portfolio_validation_error'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x1AB85450),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BrandConfig.errorTerracotta),
                    ),
                    child: Text(
                      _validationErrorMessage!,
                      style: const TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BrandConfig.espresso,
                      ),
                    ),
                  ),
                ),
              ],
              if (_lastPublishedContract != null) ...<Widget>[
                const SizedBox(height: 16),
                Semantics(
                  container: true,
                  liveRegion: true,
                  child: Container(
                    key: const Key('portfolio_published_banner'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x1A5E8C76),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BrandConfig.sageSuccess),
                    ),
                    child: Text(
                      'Published "${_lastPublishedContract!.title}" (${_lastPublishedContract!.formattedBasePrice} • ${_lastPublishedContract!.formattedBaseDuration}) at ${_lastPublishedContract!.venueName}.',
                      style: const TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BrandConfig.espresso,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const Key('portfolio_publish_button'),
                onPressed: _handlePublish,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Publish Visual Contract'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSelectorCard(
    TextTheme textTheme, {
    required int previewPrice,
    required int previewDuration,
  }) {
    return Container(
      key: const Key('portfolio_photo_selector_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '1. Studio Nail Photography (4:5 Aspect Ratio)',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Select a verified studio photo of your completed work. Clients book this exact look.',
            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BrandConfig.borderWarm),
              gradient: const LinearGradient(
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
                      const Icon(
                        Icons.camera_enhance_outlined,
                        color: BrandConfig.roseDark,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedPhoto.label,
                        textAlign: TextAlign.center,
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
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xF2FAF6F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BrandConfig.borderWarm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'Live Contract Stamp: R$previewPrice',
                            key: const Key('portfolio_live_price_stamp'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: BrandConfig.bodyFontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: BrandConfig.espresso,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$previewDuration mins • $_selectedCity',
                            key: const Key('portfolio_live_duration_stamp'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: BrandConfig.bodyFontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: BrandConfig.roseDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final sample
                  in TechPortfolioUploadScreen.studioPhotoSamples)
                ChoiceChip(
                  key: Key('photo_sample_chip_${sample.id}'),
                  label: Text(sample.styleCategory),
                  selected: _selectedPhoto.id == sample.id,
                  onSelected: (_) {
                    setState(() {
                      _selectedPhoto = sample;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContractDetailsCard(TextTheme textTheme) {
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
            '2. Fixed Base Price & Appointment Duration',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'No hidden surprises: set the exact Rand price and minutes required to recreate this photo.',
            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('portfolio_title_input'),
            controller: _titleController,
            onChanged: (_) => setState(() => _validationErrorMessage = null),
            decoration: const InputDecoration(
              labelText: 'Visual Contract Look Title',
              hintText: 'e.g. Sculpted Almond BIAB & Micro French',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('portfolio_base_price_input'),
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Base Price (ZAR)',
                    prefixText: 'R ',
                    hintText: '450',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('portfolio_base_duration_input'),
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Base Duration (mins)',
                    suffixText: 'mins',
                    hintText: '90',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVenueLinkCard(TextTheme textTheme) {
    final venuesForCity = _cityVenues;

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
            '3. Verified Commercial Studio or Partner Salon',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            BrandConfig.venueSafetyStatement,
            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const Key('upload_city_CPT'),
                label: const Text('Cape Town (CPT)'),
                selected: _selectedCity == 'CPT',
                onSelected: (_) => _selectCity('CPT'),
              ),
              ChoiceChip(
                key: const Key('upload_city_JHB'),
                label: const Text('Johannesburg (JHB)'),
                selected: _selectedCity == 'JHB',
                onSelected: (_) => _selectCity('JHB'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final venue in venuesForCity) ...<Widget>[
            Semantics(
              button: true,
              selected: _selectedVenue.id == venue.id,
              child: InkWell(
                key: Key('upload_venue_option_${venue.id}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selectedVenue = venue),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedVenue.id == venue.id
                        ? BrandConfig.blushSoft
                        : BrandConfig.bgCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedVenue.id == venue.id
                          ? BrandConfig.rosePrimary
                          : BrandConfig.borderWarm,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _selectedVenue.id == venue.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _selectedVenue.id == venue.id
                            ? BrandConfig.roseDark
                            : BrandConfig.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              venue.name,
                              style: const TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: BrandConfig.espresso,
                              ),
                            ),
                            Text(
                              '${venue.type.label} • ${venue.address}',
                              style: const TextStyle(
                                fontFamily: BrandConfig.bodyFontFamily,
                                fontSize: 12,
                                color: BrandConfig.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildModifiersToggleCard(TextTheme textTheme) {
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
            '4. Optional Add-On Modifiers Offered',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Toggle which add-ons clients are allowed to select when booking this set.',
            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final mod in _modifierPresets) ...<Widget>[
            Semantics(
              button: true,
              toggled: _enabledModifierIds.contains(mod.id),
              child: InkWell(
                key: Key('portfolio_modifier_toggle_${mod.id}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggleModifierPreset(mod.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _enabledModifierIds.contains(mod.id)
                        ? BrandConfig.blushSoft
                        : BrandConfig.bgCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _enabledModifierIds.contains(mod.id)
                          ? BrandConfig.rosePrimary
                          : BrandConfig.borderWarm,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _enabledModifierIds.contains(mod.id)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: _enabledModifierIds.contains(mod.id)
                            ? BrandConfig.roseDark
                            : BrandConfig.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mod.name,
                          style: const TextStyle(
                            fontFamily: BrandConfig.bodyFontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: BrandConfig.espresso,
                          ),
                        ),
                      ),
                      Text(
                        mod.formattedSummary,
                        style: const TextStyle(
                          fontFamily: BrandConfig.bodyFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: BrandConfig.roseDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
