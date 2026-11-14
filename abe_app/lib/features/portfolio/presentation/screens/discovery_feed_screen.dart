import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../auth/domain/models/tech_profile.dart';
import '../../../venue/domain/models/commercial_venue.dart';
import '../../domain/models/visual_contract_item.dart';
import '../widgets/visual_contract_card.dart';

/// Visual Contract Discovery Feed for Cape Town (`CPT`) and Johannesburg (`JHB`).
///
/// Supports instant filtering by City (`All`, `CPT`, `JHB`), Merit Tier Badge
/// (`All`, `Certified Pro ★`, `Verified Tech`, `Rising Tech`), and maximum base
/// price in ZAR, seeded with realistic South African nail portfolios.
class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({
    super.key,
    this.initialCityFilter = 'ALL',
    this.seedItems,
    this.onOpenAuthOrSwitchRole,
    this.onSelectContract,
    this.onOpenTechPortfolioUpload,
  });

  /// Initial city filter: `'ALL'`, `'CPT'`, or `'JHB'`.
  final String initialCityFilter;
  final List<VisualContractItem>? seedItems;
  final VoidCallback? onOpenAuthOrSwitchRole;
  final void Function(VisualContractItem item)? onSelectContract;
  final VoidCallback? onOpenTechPortfolioUpload;

  /// Realistic Cape Town (`CPT`) and Johannesburg (`JHB`) Visual Contract seed data.
  static List<VisualContractItem> buildDefaultSeedCatalog() {
    final standardModifiers = <ContractModifier>[
      ContractModifier(
        id: 'mod_soak_off',
        name: 'Soak-Off / Removal',
        additionalPriceZar: 80,
        additionalDurationMinutes: 30,
      ),
      ContractModifier(
        id: 'mod_extra_length',
        name: 'Extra Length',
        additionalPriceZar: 60,
        additionalDurationMinutes: 15,
      ),
      ContractModifier(
        id: 'mod_nail_repair',
        name: 'Single Nail Repair',
        additionalPriceZar: 45,
        additionalDurationMinutes: 15,
      ),
    ];

    return <VisualContractItem>[
      VisualContractItem(
        id: 'vc_cpt_01',
        techId: 'tech_cpt_01',
        techDisplayName: 'Nadia Jacobs',
        techTierBadge: TechTierBadge.certifiedPro,
        photoUrl: 'https://assets.abe.co.za/cpt/nadia_biab_french.jpg',
        title: 'Sculpted Almond BIAB & Micro French',
        basePriceZar: 450,
        baseDurationMinutes: 90,
        city: 'CPT',
        venueId: 'venue_cpt_seapoint_01',
        venueName: 'Atelier Rose Studio, Sea Point',
        venueType: CommercialVenueType.verifiedStudio,
        styleCategory: 'BIAB & Micro French',
        allowedModifiers: standardModifiers,
      ),
      VisualContractItem(
        id: 'vc_jhb_01',
        techId: 'tech_jhb_01',
        techDisplayName: 'Lerato Khumalo',
        techTierBadge: TechTierBadge.certifiedPro,
        photoUrl: 'https://assets.abe.co.za/jhb/lerato_glazed_gelx.jpg',
        title: 'Champagne Glazed Gel-X Extensions',
        basePriceZar: 520,
        baseDurationMinutes: 105,
        city: 'JHB',
        venueId: 'venue_jhb_rosebank_01',
        venueName: 'House of Alabaster, Rosebank',
        venueType: CommercialVenueType.verifiedStudio,
        styleCategory: 'Gel-X Extensions & Chrome',
        allowedModifiers: standardModifiers,
      ),
      VisualContractItem(
        id: 'vc_cpt_02',
        techId: 'tech_cpt_02',
        techDisplayName: 'Amina Abrahams',
        techTierBadge: TechTierBadge.verified,
        photoUrl: 'https://assets.abe.co.za/cpt/amina_blush_ombre.jpg',
        title: 'Soft Blush Baby Boomer Gel Overlay',
        basePriceZar: 390,
        baseDurationMinutes: 75,
        city: 'CPT',
        venueId: 'venue_cpt_claremont_02',
        venueName: 'Cavendish Lane Nail Bar, Claremont',
        venueType: CommercialVenueType.partnerSalon,
        styleCategory: 'Structured Gel Ombre',
        allowedModifiers: standardModifiers,
      ),
      VisualContractItem(
        id: 'vc_jhb_02',
        techId: 'tech_jhb_02',
        techDisplayName: 'Thando Mokoena',
        techTierBadge: TechTierBadge.verified,
        photoUrl: 'https://assets.abe.co.za/jhb/thando_tortoiseshell.jpg',
        title: 'Espresso & Gold Foil Tortoiseshell Set',
        basePriceZar: 480,
        baseDurationMinutes: 95,
        city: 'JHB',
        venueId: 'venue_jhb_sandton_02',
        venueName: 'Sandton Square Studio, Sandton',
        venueType: CommercialVenueType.verifiedStudio,
        styleCategory: 'Hand-Painted Nail Art',
        allowedModifiers: standardModifiers,
      ),
      VisualContractItem(
        id: 'vc_cpt_03',
        techId: 'tech_cpt_03',
        techDisplayName: 'Chloe van der Merwe',
        techTierBadge: TechTierBadge.rising,
        photoUrl: 'https://assets.abe.co.za/cpt/chloe_clean_cuticle.jpg',
        title: 'Russian Manicure & Sheer Milky BIAB',
        basePriceZar: 340,
        baseDurationMinutes: 60,
        city: 'CPT',
        venueId: 'venue_cpt_century_03',
        venueName: 'Canal Walk Partner Salon, Century City',
        venueType: CommercialVenueType.partnerSalon,
        styleCategory: 'Natural BIAB Overlay',
        allowedModifiers: standardModifiers,
      ),
      VisualContractItem(
        id: 'vc_jhb_03',
        techId: 'tech_jhb_03',
        techDisplayName: 'Zinhle Dlamini',
        techTierBadge: TechTierBadge.rising,
        photoUrl: 'https://assets.abe.co.za/jhb/zinhle_velvet_cateye.jpg',
        title: 'Dusty Rose Magnetic Velvet Cat-Eye',
        basePriceZar: 360,
        baseDurationMinutes: 75,
        city: 'JHB',
        venueId: 'venue_jhb_melville_03',
        venueName: '7th Street Beauty Collective, Melville',
        venueType: CommercialVenueType.partnerSalon,
        styleCategory: 'Magnetic Velvet Gel',
        allowedModifiers: standardModifiers,
      ),
    ];
  }

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  late String _cityFilter;
  TechTierBadge? _selectedBadgeFilter;
  int _maxPriceZar = 600;
  late final List<VisualContractItem> _catalog;

  @override
  void initState() {
    super.initState();
    _cityFilter = widget.initialCityFilter.toUpperCase();
    _catalog =
        widget.seedItems ?? DiscoveryFeedScreen.buildDefaultSeedCatalog();
  }

  List<VisualContractItem> get _filteredItems {
    return _catalog.where((item) {
      if (_cityFilter != 'ALL' && item.city != _cityFilter) {
        return false;
      }
      if (_selectedBadgeFilter != null &&
          item.techTierBadge != _selectedBadgeFilter) {
        return false;
      }
      if (item.basePriceZar > _maxPriceZar) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showContractPreviewModal(VisualContractItem item) {
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      item.techTierBadge.label,
                      style: const TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BrandConfig.roseDark,
                      ),
                    ),
                    Text(
                      '${item.formattedBasePrice} • ${item.formattedBaseDuration}',
                      style: const TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BrandConfig.espresso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Nail Technician: ${item.techDisplayName} • ${item.venueName} (${item.city})',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BrandConfig.bgCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BrandConfig.borderWarm),
                  ),
                  child: Text(
                    'Visual Contract Guarantee: This photo locks in the exact base price (${item.formattedBasePrice}) and appointment duration (${item.formattedBaseDuration}) at ${item.venueName}.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: BrandConfig.espresso,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close Preview'),
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
    final items = _filteredItems;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        title: const Text(BrandConfig.appName),
        actions: <Widget>[
          if (widget.onOpenTechPortfolioUpload != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                key: const Key('feed_open_tech_upload_button'),
                onPressed: widget.onOpenTechPortfolioUpload,
                icon: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 18,
                  color: BrandConfig.roseDark,
                ),
                label: const Text(
                  'Upload Set',
                  style: TextStyle(
                    fontFamily: BrandConfig.bodyFontFamily,
                    fontWeight: FontWeight.w700,
                    color: BrandConfig.roseDark,
                  ),
                ),
              ),
            ),
          if (widget.onOpenAuthOrSwitchRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                key: const Key('feed_switch_role_button'),
                onPressed: widget.onOpenAuthOrSwitchRole,
                icon: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: BrandConfig.espresso,
                ),
                label: const Text(
                  'Account & City',
                  style: TextStyle(
                    fontFamily: BrandConfig.bodyFontFamily,
                    fontWeight: FontWeight.w600,
                    color: BrandConfig.espresso,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Visual Contract Discovery',
                      style: textTheme.displaySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every photo is a binding contract with a fixed Rand price, exact duration, and verified salon location.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildCityFilterRow(),
                    const SizedBox(height: 12),
                    _buildTierFilterRow(),
                    const SizedBox(height: 12),
                    _buildPriceFilterBar(),
                  ],
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(textTheme),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 0.60,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final contract = items[index];
                      return VisualContractCard(
                        key: Key('feed_card_${contract.id}'),
                        item: contract,
                        onTap: () {
                          if (widget.onSelectContract != null) {
                            widget.onSelectContract!(contract);
                          } else {
                            _showContractPreviewModal(contract);
                          }
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityFilterRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _FilterPill(
          key: const Key('filter_city_ALL'),
          label: 'All Cities (CPT & JHB)',
          isSelected: _cityFilter == 'ALL',
          onTap: () => setState(() => _cityFilter = 'ALL'),
        ),
        _FilterPill(
          key: const Key('filter_city_CPT'),
          label: 'Cape Town (CPT)',
          isSelected: _cityFilter == 'CPT',
          onTap: () => setState(() => _cityFilter = 'CPT'),
        ),
        _FilterPill(
          key: const Key('filter_city_JHB'),
          label: 'Johannesburg (JHB)',
          isSelected: _cityFilter == 'JHB',
          onTap: () => setState(() => _cityFilter = 'JHB'),
        ),
      ],
    );
  }

  Widget _buildTierFilterRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _FilterPill(
          key: const Key('filter_badge_ALL'),
          label: 'All Merit Tiers',
          isSelected: _selectedBadgeFilter == null,
          onTap: () => setState(() => _selectedBadgeFilter = null),
        ),
        for (final badge in TechTierBadge.values)
          _FilterPill(
            key: Key('filter_badge_${badge.code}'),
            label: badge.label,
            isSelected: _selectedBadgeFilter == badge,
            onTap: () => setState(() => _selectedBadgeFilter = badge),
          ),
      ],
    );
  }

  Widget _buildPriceFilterBar() {
    const priceCaps = <int>[350, 450, 600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: <Widget>[
          Text(
            'Maximum Base Price: Up to R$_maxPriceZar',
            style: const TextStyle(
              fontFamily: BrandConfig.bodyFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: BrandConfig.espresso,
            ),
          ),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final cap in priceCaps)
                _FilterPill(
                  key: Key('filter_price_$cap'),
                  label: '≤ R$cap',
                  isSelected: _maxPriceZar == cap,
                  onTap: () => setState(() => _maxPriceZar = cap),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.search_off_outlined,
              size: 44,
              color: BrandConfig.rosePrimary,
            ),
            const SizedBox(height: 12),
            Text(
              'No Visual Contracts match these filters',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Reset your city, tier badge, or price cap to view all verified Cape Town and Johannesburg nail sets.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('filter_reset_button'),
              onPressed: () {
                setState(() {
                  _cityFilter = 'ALL';
                  _selectedBadgeFilter = null;
                  _maxPriceZar = 600;
                });
              },
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? BrandConfig.espresso
                : BrandConfig.surfaceCard,
            borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
            border: Border.all(
              color: isSelected
                  ? BrandConfig.espresso
                  : BrandConfig.borderWarm,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: BrandConfig.bodyFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? BrandConfig.surfaceCard
                      : BrandConfig.espresso,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
