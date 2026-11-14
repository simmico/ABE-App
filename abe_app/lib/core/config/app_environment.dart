import '../../core/utils/input_sanitiser.dart';

/// Build flavours for Aqeelah's Beauty Empire (ABE).
enum AbeBuildFlavor {
  dev('dev', 'co.za.abe.abe_app.dev', 'abe-sa-dev', 'ABE Dev'),
  staging(
    'staging',
    'co.za.abe.abe_app.staging',
    'abe-sa-staging',
    'ABE Staging',
  ),
  prod(
    'prod',
    'co.za.abe.abe_app',
    'abe-sa-prod',
    "Aqeelah's Beauty Empire",
  );

  const AbeBuildFlavor(
    this.code,
    this.applicationId,
    this.firebaseProjectId,
    this.displayName,
  );

  final String code;
  final String applicationId;
  final String firebaseProjectId;
  final String displayName;

  static AbeBuildFlavor fromCode(String rawCode) {
    final normalised =
        InputSanitiser.sanitiseText(rawCode, maxLength: 32).toLowerCase();
    for (final flavor in AbeBuildFlavor.values) {
      if (flavor.code == normalised) return flavor;
    }
    if (normalised == 'production') return AbeBuildFlavor.prod;
    throw ArgumentError.value(
      rawCode,
      'ABE_ENV',
      'Unsupported build flavour. Expected dev, staging, or prod.',
    );
  }
}

/// App Check attestation provider configuration per platform.
enum AbeAppCheckAndroidProvider {
  debug,
  playIntegrity,
}

enum AbeAppCheckAppleProvider {
  debug,
  appAttestWithDeviceCheckFallback,
}

enum AbeAppCheckWebProvider {
  debug,
  reCaptchaV3,
}

/// Compile-time and runtime environment configuration for iOS, Android, and Web.
class AbeEnvironmentConfig {
  AbeEnvironmentConfig({
    required this.flavor,
    required String paystackPublicKey,
    required String peachEntityId,
    required String functionsBaseUrl,
    required String reCaptchaV3SiteKey,
    required this.appCheckEnabled,
    required this.appCheckAndroidProvider,
    required this.appCheckAppleProvider,
    required this.appCheckWebProvider,
    required this.remoteConfigMinimumFetchInterval,
  })  : paystackPublicKey =
            InputSanitiser.sanitiseText(paystackPublicKey, maxLength: 160),
        peachEntityId =
            InputSanitiser.sanitiseText(peachEntityId, maxLength: 128),
        functionsBaseUrl =
            InputSanitiser.sanitiseText(functionsBaseUrl, maxLength: 240),
        reCaptchaV3SiteKey =
            InputSanitiser.sanitiseText(reCaptchaV3SiteKey, maxLength: 160) {
    if (this.paystackPublicKey.startsWith('sk_')) {
      throw ArgumentError(
        'Security Violation: Paystack secret keys (sk_*) are forbidden in Flutter client builds.',
      );
    }
    if (!this.functionsBaseUrl.startsWith('https://')) {
      throw ArgumentError('functionsBaseUrl must use HTTPS.');
    }
    if (flavor == AbeBuildFlavor.prod) {
      if (!appCheckEnabled) {
        throw StateError(
          'Production builds must enable Firebase App Check attestation.',
        );
      }
      if (appCheckAndroidProvider == AbeAppCheckAndroidProvider.debug ||
          appCheckAppleProvider == AbeAppCheckAppleProvider.debug ||
          appCheckWebProvider == AbeAppCheckWebProvider.debug) {
        throw StateError(
          'Debug App Check providers are prohibited in production builds.',
        );
      }
      if (this.paystackPublicKey.contains('sandbox_placeholder')) {
        throw StateError(
          'Production builds require a live PAYSTACK_PUBLIC_KEY via --dart-define.',
        );
      }
      if (this.reCaptchaV3SiteKey.isEmpty) {
        throw StateError(
          'Production builds require RECAPTCHA_V3_SITE_KEY for Web App Check.',
        );
      }
    }
  }

  /// Resolves configuration from `--dart-define` values cleanly without secret leakage.
  factory AbeEnvironmentConfig.fromDartDefines({
    String? envOverride,
    String? paystackPublicKeyOverride,
    String? peachEntityIdOverride,
    String? reCaptchaSiteKeyOverride,
  }) {
    const rawEnv = String.fromEnvironment('ABE_ENV', defaultValue: 'dev');
    const rawPaystack = String.fromEnvironment(
      'PAYSTACK_PUBLIC_KEY',
      defaultValue: 'pk_test_abe_sandbox_placeholder',
    );
    const rawPeach = String.fromEnvironment(
      'PEACH_ENTITY_ID',
      defaultValue: '8ac7a4ca_abe_sandbox_entity',
    );
    const rawReCaptcha = String.fromEnvironment(
      'RECAPTCHA_V3_SITE_KEY',
      defaultValue: '',
    );

    final flavor = AbeBuildFlavor.fromCode(envOverride ?? rawEnv);
    final functionsUrl = switch (flavor) {
      AbeBuildFlavor.dev =>
        'https://africa-south1-abe-sa-dev.cloudfunctions.net',
      AbeBuildFlavor.staging =>
        'https://africa-south1-abe-sa-staging.cloudfunctions.net',
      AbeBuildFlavor.prod =>
        'https://africa-south1-abe-sa-prod.cloudfunctions.net',
    };

    final isProd = flavor == AbeBuildFlavor.prod;
    final isDev = flavor == AbeBuildFlavor.dev;

    return AbeEnvironmentConfig(
      flavor: flavor,
      paystackPublicKey: paystackPublicKeyOverride ?? rawPaystack,
      peachEntityId: peachEntityIdOverride ?? rawPeach,
      functionsBaseUrl: functionsUrl,
      reCaptchaV3SiteKey: reCaptchaSiteKeyOverride ?? rawReCaptcha,
      appCheckEnabled: !isDev,
      appCheckAndroidProvider: isDev
          ? AbeAppCheckAndroidProvider.debug
          : AbeAppCheckAndroidProvider.playIntegrity,
      appCheckAppleProvider: isDev
          ? AbeAppCheckAppleProvider.debug
          : AbeAppCheckAppleProvider.appAttestWithDeviceCheckFallback,
      appCheckWebProvider: isDev
          ? AbeAppCheckWebProvider.debug
          : AbeAppCheckWebProvider.reCaptchaV3,
      remoteConfigMinimumFetchInterval:
          isProd ? const Duration(hours: 12) : const Duration(minutes: 1),
    );
  }

  final AbeBuildFlavor flavor;
  final String paystackPublicKey;
  final String peachEntityId;
  final String functionsBaseUrl;
  final String reCaptchaV3SiteKey;
  final bool appCheckEnabled;
  final AbeAppCheckAndroidProvider appCheckAndroidProvider;
  final AbeAppCheckAppleProvider appCheckAppleProvider;
  final AbeAppCheckWebProvider appCheckWebProvider;
  final Duration remoteConfigMinimumFetchInterval;

  bool get isProduction => flavor == AbeBuildFlavor.prod;
}
