import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../../core/uac/uac_permission_matrix.dart';
import '../../../../core/utils/input_sanitiser.dart';

/// Role and City Onboarding selector for Aqeelah's Beauty Empire (ABE).
///
/// Lets new users select their launch city (`CPT` or `JHB`) and their primary
/// marketplace role (`client`, `tech`, or `salon_partner`), enforcing commercial
/// studio verification for Nail Technicians and Salon Partners.
class RoleCityOnboardingScreen extends StatefulWidget {
  const RoleCityOnboardingScreen({
    super.key,
    required this.userFullName,
    required this.userEmail,
    required this.onCompleted,
  });

  final String userFullName;
  final String userEmail;

  final void Function({
    required String selectedCity,
    required AbeUacGroupId selectedRole,
    String? commercialVenueName,
  }) onCompleted;

  @override
  State<RoleCityOnboardingScreen> createState() =>
      _RoleCityOnboardingScreenState();
}

class _RoleCityOnboardingScreenState extends State<RoleCityOnboardingScreen> {
  String _selectedCity = 'CPT';
  AbeUacGroupId _selectedRole = AbeUacGroupId.client;
  final TextEditingController _venueController = TextEditingController();
  String? _venueError;

  @override
  void dispose() {
    _venueController.dispose();
    super.dispose();
  }

  bool get _requiresCommercialVenue =>
      _selectedRole == AbeUacGroupId.tech ||
      _selectedRole == AbeUacGroupId.salonPartner;

  void _completeOnboarding() {
    String? sanitisedVenue;
    if (_requiresCommercialVenue) {
      sanitisedVenue = InputSanitiser.sanitiseText(
        _venueController.text,
        maxLength: 140,
      );
      if (sanitisedVenue.length < 3) {
        setState(() {
          _venueError =
              'Please enter your commercial studio or partner salon name (no house calls).';
        });
        return;
      }
    }

    setState(() {
      _venueError = null;
    });

    widget.onCompleted(
      selectedCity: _selectedCity,
      selectedRole: _selectedRole,
      commercialVenueName: sanitisedVenue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        title: const Text('Select City & Role'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Welcome, ${widget.userFullName}',
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose your launch hub and how you will use Aqeelah\'s Beauty Empire.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '1. Choose Your Launch City',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _CitySelectorCard(
                          key: const Key('onboarding_city_cpt'),
                          cityCode: 'CPT',
                          title: 'Cape Town',
                          subtitle: 'Sea Point, Claremont, Century City & surrounds',
                          isSelected: _selectedCity == 'CPT',
                          onTap: () => setState(() => _selectedCity = 'CPT'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CitySelectorCard(
                          key: const Key('onboarding_city_jhb'),
                          cityCode: 'JHB',
                          title: 'Johannesburg',
                          subtitle: 'Sandton, Rosebank, Melville & surrounds',
                          isSelected: _selectedCity == 'JHB',
                          onTap: () => setState(() => _selectedCity = 'JHB'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '2. Choose Your Account Role',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _RoleOptionTile(
                    key: const Key('onboarding_role_client'),
                    title: 'Client (Book Verified Nail Looks)',
                    description:
                        'Browse fixed-price Visual Contracts, toggle optional add-ons, and book instant slots at verified studios.',
                    icon: Icons.spa_outlined,
                    isSelected: _selectedRole == AbeUacGroupId.client,
                    onTap: () =>
                        setState(() => _selectedRole = AbeUacGroupId.client),
                  ),
                  const SizedBox(height: 10),
                  _RoleOptionTile(
                    key: const Key('onboarding_role_tech'),
                    title: 'Nail Technician (Studio or Partner Chair)',
                    description:
                        'Publish Visual Contract sets with upfront pricing, earn Verified and Certified Pro badges, and receive protected payouts.',
                    icon: Icons.brush_outlined,
                    isSelected: _selectedRole == AbeUacGroupId.tech,
                    onTap: () =>
                        setState(() => _selectedRole = AbeUacGroupId.tech),
                  ),
                  const SizedBox(height: 10),
                  _RoleOptionTile(
                    key: const Key('onboarding_role_salon'),
                    title: 'Commercial Salon Partner (Empty Chair Host)',
                    description:
                        'List quiet mid-week nail stations for vetted ABE Nail Technicians and earn passive station fees per booking.',
                    icon: Icons.storefront_outlined,
                    isSelected: _selectedRole == AbeUacGroupId.salonPartner,
                    onTap: () => setState(
                      () => _selectedRole = AbeUacGroupId.salonPartner,
                    ),
                  ),
                  if (_requiresCommercialVenue) ...<Widget>[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BrandConfig.surfaceCard,
                        borderRadius:
                            BorderRadius.circular(BrandConfig.cardRadius),
                        border: Border.all(color: BrandConfig.borderWarm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Commercial Studio or Salon Verification',
                            style: textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'For client and technician safety, residential house calls are strictly prohibited.',
                            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('onboarding_venue_name_field'),
                            controller: _venueController,
                            decoration: InputDecoration(
                              labelText: 'Commercial Studio or Partner Salon Name',
                              hintText: 'e.g. Atelier Rose Studio, Sea Point',
                              errorText: _venueError,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    key: const Key('onboarding_continue_button'),
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Enter ${_selectedCity == 'CPT' ? 'Cape Town' : 'Johannesburg'} Studio Feed',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CitySelectorCard extends StatelessWidget {
  const _CitySelectorCard({
    super.key,
    required this.cityCode,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String cityCode;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? BrandConfig.blushSoft : BrandConfig.surfaceCard,
            borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
            border: Border.all(
              color: isSelected
                  ? BrandConfig.rosePrimary
                  : BrandConfig.borderWarm,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? BrandConfig.rosePrimary
                          : BrandConfig.bgCream,
                      borderRadius:
                          BorderRadius.circular(BrandConfig.pillRadius),
                    ),
                    child: Text(
                      cityCode,
                      style: TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? BrandConfig.surfaceCard
                            : BrandConfig.espresso,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: BrandConfig.roseDark,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: BrandConfig.headingFontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BrandConfig.espresso,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: BrandConfig.bodyFontFamily,
                  fontSize: 12,
                  color: BrandConfig.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOptionTile extends StatelessWidget {
  const _RoleOptionTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? BrandConfig.blushSoft : BrandConfig.surfaceCard,
            borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
            border: Border.all(
              color: isSelected
                  ? BrandConfig.rosePrimary
                  : BrandConfig.borderWarm,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandConfig.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BrandConfig.borderWarm),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? BrandConfig.roseDark
                      : BrandConfig.espresso,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BrandConfig.espresso,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontSize: 13,
                        height: 1.4,
                        color: BrandConfig.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? BrandConfig.roseDark : BrandConfig.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
