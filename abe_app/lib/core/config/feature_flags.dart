import 'package:flutter/foundation.dart';

/// Feature flags controlling Phase 1 MVP and Phase 2 expansion capabilities.
///
/// Phase 1 MVP features are enabled by default for the Cape Town (CPT) and
/// Johannesburg (JHB) dual-city launch. Phase 2 expansion modules can be
/// toggled live from the Admin Dashboard without redeploying the mobile binary.
class FeatureFlagsService extends ChangeNotifier {
  FeatureFlagsService({
    Map<String, bool>? initialFlags,
  }) : _flags = initialFlags != null
            ? Map<String, bool>.from(initialFlags)
            : Map<String, bool>.from(_defaultFlags);

  // Phase 1 MVP Feature Keys
  static const String visualContractFeed = 'mvp.visual_contract_feed';
  static const String strictVenueOnlyBooking = 'mvp.strict_venue_only_booking';
  static const String biometricPinStartLock = 'mvp.biometric_pin_start_lock';
  static const String liveCameraCompletionLock =
      'mvp.live_camera_completion_lock';
  static const String closedLoopWallet = 'mvp.closed_loop_wallet';
  static const String emptyChairSalonPartner = 'mvp.empty_chair_salon_partner';
  static const String payJustNowBnpl = 'mvp.payjustnow_bnpl';

  // Phase 2 Expansion Feature Keys (Deferred from MVP by default)
  static const String stockUpSupplyStore = 'phase2.stock_up_supply_store';
  static const String monthlyBeautyBox = 'phase2.monthly_beauty_box';
  static const String squadAndBridalPackages =
      'phase2.squad_and_bridal_packages';
  static const String wigsAndLashesCategories =
      'phase2.wigs_and_lashes_categories';

  static const Map<String, bool> _defaultFlags = <String, bool>{
    visualContractFeed: true,
    strictVenueOnlyBooking: true,
    biometricPinStartLock: true,
    liveCameraCompletionLock: true,
    closedLoopWallet: true,
    emptyChairSalonPartner: true,
    payJustNowBnpl: true,
    stockUpSupplyStore: false,
    monthlyBeautyBox: false,
    squadAndBridalPackages: false,
    wigsAndLashesCategories: false,
  };

  final Map<String, bool> _flags;

  /// Returns whether [flagKey] is currently active.
  bool isEnabled(String flagKey) => _flags[flagKey] ?? false;

  /// Updates a feature flag at runtime and notifies listeners.
  void setFlag(String flagKey, {required bool enabled}) {
    if (_flags[flagKey] != enabled) {
      _flags[flagKey] = enabled;
      notifyListeners();
    }
  }

  /// Snapshot of all current feature flags.
  Map<String, bool> get allFlags => Map<String, bool>.unmodifiable(_flags);
}
