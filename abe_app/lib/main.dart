import 'package:material_ui/material_ui.dart';

import 'core/config/brand_config.dart';
import 'core/theme/abe_theme.dart';
import 'core/uac/uac_permission_matrix.dart';
import 'features/auth/presentation/screens/role_city_onboarding_screen.dart';
import 'features/auth/presentation/screens/welcome_auth_screen.dart';
import 'features/portfolio/presentation/screens/discovery_feed_screen.dart';

void main() {
  runApp(const AbeApp());
}

enum _AbeStageOneRoute {
  discoveryFeed,
  welcomeAuth,
  onboarding,
}

/// Root application widget for Aqeelah's Beauty Empire (ABE).
class AbeApp extends StatefulWidget {
  const AbeApp({super.key});

  @override
  State<AbeApp> createState() => _AbeAppState();
}

class _AbeAppState extends State<AbeApp> {
  _AbeStageOneRoute _currentRoute = _AbeStageOneRoute.discoveryFeed;
  String _activeCityFilter = 'ALL';
  String _userFullName = 'Aqeelah';
  String _userEmail = 'aqeelah@abe.co.za';

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
      case _AbeStageOneRoute.welcomeAuth:
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
                  ? _AbeStageOneRoute.onboarding
                  : _AbeStageOneRoute.discoveryFeed;
            });
          },
          onBrowseFeedDirectly: () {
            setState(() {
              _currentRoute = _AbeStageOneRoute.discoveryFeed;
            });
          },
        );
      case _AbeStageOneRoute.onboarding:
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
              _currentRoute = _AbeStageOneRoute.discoveryFeed;
            });
          },
        );
      case _AbeStageOneRoute.discoveryFeed:
        return DiscoveryFeedScreen(
          key: ValueKey<String>('feed_$_activeCityFilter'),
          initialCityFilter: _activeCityFilter,
          onOpenAuthOrSwitchRole: () {
            setState(() {
              _currentRoute = _AbeStageOneRoute.welcomeAuth;
            });
          },
        );
    }
  }
}
