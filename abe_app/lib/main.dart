import 'package:material_ui/material_ui.dart';

import 'core/config/brand_config.dart';
import 'core/theme/abe_theme.dart';
import 'core/uac/uac_permission_matrix.dart';
import 'features/auth/presentation/screens/role_city_onboarding_screen.dart';
import 'features/auth/presentation/screens/welcome_auth_screen.dart';
import 'features/booking/presentation/screens/visual_contract_detail_screen.dart';
import 'features/portfolio/data/repositories/visual_contract_repository.dart';
import 'features/portfolio/domain/models/visual_contract_item.dart';
import 'features/portfolio/presentation/screens/discovery_feed_screen.dart';
import 'features/portfolio/presentation/screens/tech_portfolio_upload_screen.dart';

void main() {
  runApp(const AbeApp());
}

enum _AbePrototypeRoute {
  discoveryFeed,
  visualContractDetail,
  techPortfolioUpload,
  welcomeAuth,
  onboarding,
}

/// Root application widget for Aqeelah's Beauty Empire (ABE).
///
/// Connects Stage 1 and Stage 2 screens (`DiscoveryFeedScreen`,
/// `VisualContractDetailScreen`, `TechPortfolioUploadScreen`,
/// `WelcomeAuthScreen`, and `RoleCityOnboardingScreen`) into a unified
/// clickable prototype for Rio and Aqeelah.
class AbeApp extends StatefulWidget {
  const AbeApp({super.key});

  @override
  State<AbeApp> createState() => _AbeAppState();
}

class _AbeAppState extends State<AbeApp> {
  final VisualContractRepository _repository = VisualContractRepository();
  _AbePrototypeRoute _currentRoute = _AbePrototypeRoute.discoveryFeed;
  String _activeCityFilter = 'ALL';
  String _userFullName = 'Aqeelah';
  String _userEmail = 'aqeelah@abe.co.za';
  VisualContractItem? _selectedContract;
  int _catalogVersion = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: BrandConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AbeTheme.lightTheme,
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentRoute) {
      case _AbePrototypeRoute.welcomeAuth:
        return WelcomeAuthScreen(
          onAuthenticated: ({
            required String fullName,
            required String email,
            required bool isNewRegistration,
          }) {
            setState(() {
              _userFullName = fullName;
              _userEmail = email;
              _currentRoute = isNewRegistration
                  ? _AbePrototypeRoute.onboarding
                  : _AbePrototypeRoute.discoveryFeed;
            });
          },
          onBrowseFeedDirectly: () {
            setState(() {
              _currentRoute = _AbePrototypeRoute.discoveryFeed;
            });
          },
        );
      case _AbePrototypeRoute.onboarding:
        return RoleCityOnboardingScreen(
          userFullName: _userFullName,
          userEmail: _userEmail,
          onCompleted: ({
            required String selectedCity,
            required AbeUacGroupId selectedRole,
            String? commercialVenueName,
          }) {
            setState(() {
              _activeCityFilter = selectedCity;
              _currentRoute = selectedRole == AbeUacGroupId.tech
                  ? _AbePrototypeRoute.techPortfolioUpload
                  : _AbePrototypeRoute.discoveryFeed;
            });
          },
        );
      case _AbePrototypeRoute.visualContractDetail:
        final activeContract =
            _selectedContract ?? _repository.items.first;
        return VisualContractDetailScreen(
          key: ValueKey<String>('detail_${activeContract.id}'),
          contract: activeContract,
          onBack: () {
            setState(() {
              _currentRoute = _AbePrototypeRoute.discoveryFeed;
            });
          },
          onConfirmBooking: (_) {
            setState(() {
              _currentRoute = _AbePrototypeRoute.discoveryFeed;
            });
          },
        );
      case _AbePrototypeRoute.techPortfolioUpload:
        return TechPortfolioUploadScreen(
          repository: _repository,
          initialCity: _activeCityFilter == 'JHB' ? 'JHB' : 'CPT',
          onBack: () {
            setState(() {
              _currentRoute = _AbePrototypeRoute.discoveryFeed;
            });
          },
          onContractPublished: (createdContract) {
            setState(() {
              _catalogVersion++;
              _selectedContract = createdContract;
              _currentRoute = _AbePrototypeRoute.discoveryFeed;
            });
          },
        );
      case _AbePrototypeRoute.discoveryFeed:
        return DiscoveryFeedScreen(
          key: ValueKey<String>('feed_${_activeCityFilter}_$_catalogVersion'),
          initialCityFilter: _activeCityFilter,
          seedItems: _repository.items,
          onOpenAuthOrSwitchRole: () {
            setState(() {
              _currentRoute = _AbePrototypeRoute.welcomeAuth;
            });
          },
          onSelectContract: (contract) {
            setState(() {
              _selectedContract = contract;
              _currentRoute = _AbePrototypeRoute.visualContractDetail;
            });
          },
          onOpenTechPortfolioUpload: () {
            setState(() {
              _currentRoute = _AbePrototypeRoute.techPortfolioUpload;
            });
          },
        );
    }
  }
}
