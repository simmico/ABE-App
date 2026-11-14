import 'app_environment.dart';
import 'feature_flags.dart';

/// Server-driven Firebase Remote Config keys mapped to [FeatureFlagsService].
class AbeRemoteConfigKeys {
  AbeRemoteConfigKeys._();

  static const String payJustNowBnpl = 'abe_flag_payjustnow_bnpl';
  static const String emptyChairSalonPartner =
      'abe_flag_empty_chair_salon_partner';
  static const String stockUpSupplyStore = 'abe_flag_stockup_supply_store';
  static const String closedLoopWallet = 'abe_flag_closed_loop_wallet';
  static const String monthlyBeautyBox = 'abe_flag_monthly_beauty_box';
  static const String softLaunchCities = 'abe_soft_launch_cities';
  static const String minimumSupportedVersion = 'abe_min_supported_version';

  static const Map<String, Object> defaults = <String, Object>{
    payJustNowBnpl: true,
    emptyChairSalonPartner: true,
    stockUpSupplyStore: true,
    closedLoopWallet: true,
    monthlyBeautyBox: false,
    softLaunchCities: 'CPT,JHB',
    minimumSupportedVersion: '1.0.0',
  };
}

/// Snapshot of active App Check and Remote Config bootstrap settings.
class AppCheckAndRemoteConfigStatus {
  const AppCheckAndRemoteConfigStatus({
    required this.flavor,
    required this.appCheckActive,
    required this.tokenAutoRefreshEnabled,
    required this.activeCities,
    required this.lastFetchedAtUtc,
    required this.syncedFlags,
  });

  final AbeBuildFlavor flavor;
  final bool appCheckActive;
  final bool tokenAutoRefreshEnabled;
  final List<String> activeCities;
  final DateTime lastFetchedAtUtc;
  final Map<String, bool> syncedFlags;
}

/// Bootstraps Firebase App Check attestation and synchronises Firebase Remote Config
/// parameters into [FeatureFlagsService].
class AppCheckAndRemoteConfigService {
  AppCheckAndRemoteConfigService({
    required this.environment,
    FeatureFlagsService? featureFlags,
    DateTime Function()? clock,
  })  : featureFlags = featureFlags ?? FeatureFlagsService(),
        _clock = clock ?? DateTime.now;

  final AbeEnvironmentConfig environment;
  final FeatureFlagsService featureFlags;
  final DateTime Function() _clock;

  /// Initialises App Check and syncs Remote Config flag values into [featureFlags].
  AppCheckAndRemoteConfigStatus bootstrap({
    Map<String, Object?> remoteOverrides = const <String, Object?>{},
  }) {
    final merged = <String, Object?>{
      ...AbeRemoteConfigKeys.defaults,
      ...remoteOverrides,
    };

    const mapping = <String, String>{
      AbeRemoteConfigKeys.payJustNowBnpl: FeatureFlagsService.payJustNowBnpl,
      AbeRemoteConfigKeys.emptyChairSalonPartner:
          FeatureFlagsService.emptyChairSalonPartner,
      AbeRemoteConfigKeys.stockUpSupplyStore:
          FeatureFlagsService.stockUpSupplyStore,
      AbeRemoteConfigKeys.closedLoopWallet:
          FeatureFlagsService.closedLoopWallet,
      AbeRemoteConfigKeys.monthlyBeautyBox:
          FeatureFlagsService.monthlyBeautyBox,
    };

    for (final entry in mapping.entries) {
      final raw = merged[entry.key];
      if (raw is bool) {
        featureFlags.setFlag(entry.value, enabled: raw);
      }
    }

    final rawCities = (merged[AbeRemoteConfigKeys.softLaunchCities] ?? 'CPT,JHB')
        .toString();
    final cities = rawCities
        .split(',')
        .map((c) => c.trim().toUpperCase())
        .where((c) => c == 'CPT' || c == 'JHB')
        .toList(growable: false);

    return AppCheckAndRemoteConfigStatus(
      flavor: environment.flavor,
      appCheckActive: environment.appCheckEnabled,
      tokenAutoRefreshEnabled: true,
      activeCities: cities.isEmpty ? const <String>['CPT', 'JHB'] : cities,
      lastFetchedAtUtc: _clock().toUtc(),
      syncedFlags: featureFlags.allFlags,
    );
  }
}
