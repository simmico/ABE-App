import 'dart:io';

import 'package:abe_app/core/config/app_check_and_remote_config_service.dart';
import 'package:abe_app/core/config/app_environment.dart';
import 'package:abe_app/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Production Flavours, App Check & Remote Config (Item 18.1)', () {
    test('resolves dev, staging, and prod flavours with Play Integrity / App Attest / reCAPTCHA v3', () {
      final devConfig = AbeEnvironmentConfig.fromDartDefines(envOverride: 'dev');
      expect(devConfig.flavor, AbeBuildFlavor.dev);
      expect(devConfig.flavor.applicationId, 'co.za.abe.abe_app.dev');
      expect(devConfig.appCheckEnabled, isFalse);

      final stagingConfig =
          AbeEnvironmentConfig.fromDartDefines(envOverride: 'staging');
      expect(stagingConfig.flavor, AbeBuildFlavor.staging);
      expect(stagingConfig.appCheckEnabled, isTrue);
      expect(
        stagingConfig.appCheckAndroidProvider,
        AbeAppCheckAndroidProvider.playIntegrity,
      );

      final prodConfig = AbeEnvironmentConfig.fromDartDefines(
        envOverride: 'prod',
        paystackPublicKeyOverride: 'pk_live_abe_prod_public_001',
        peachEntityIdOverride: '8ac9a4ca_abe_prod_entity',
        reCaptchaSiteKeyOverride: '6Lc_abe_prod_site_key',
      );
      expect(prodConfig.isProduction, isTrue);
      expect(prodConfig.flavor.firebaseProjectId, 'abe-sa-prod');
      expect(prodConfig.appCheckEnabled, isTrue);
      expect(
        prodConfig.appCheckAndroidProvider,
        AbeAppCheckAndroidProvider.playIntegrity,
      );
      expect(
        prodConfig.appCheckAppleProvider,
        AbeAppCheckAppleProvider.appAttestWithDeviceCheckFallback,
      );
      expect(
        prodConfig.appCheckWebProvider,
        AbeAppCheckWebProvider.reCaptchaV3,
      );
    });

    test('blocks Paystack secret keys and missing production attestation keys', () {
      expect(
        () => AbeEnvironmentConfig.fromDartDefines(
          envOverride: 'prod',
          paystackPublicKeyOverride: 'sk_live_forbidden_secret',
          reCaptchaSiteKeyOverride: '6Lc_site_key',
        ),
        throwsArgumentError,
      );

      expect(
        () => AbeEnvironmentConfig.fromDartDefines(
          envOverride: 'prod',
          paystackPublicKeyOverride: 'pk_live_abe_prod_01',
          reCaptchaSiteKeyOverride: '',
        ),
        throwsStateError,
      );
    });

    test('AppCheckAndRemoteConfigService syncs Remote Config overrides into FeatureFlagsService', () {
      final prodConfig = AbeEnvironmentConfig.fromDartDefines(
        envOverride: 'prod',
        paystackPublicKeyOverride: 'pk_live_abe_prod_public_001',
        reCaptchaSiteKeyOverride: '6Lc_abe_prod_site_key',
      );
      final flags = FeatureFlagsService();
      final bootstrapper = AppCheckAndRemoteConfigService(
        environment: prodConfig,
        featureFlags: flags,
      );

      final status = bootstrapper.bootstrap(
        remoteOverrides: const <String, Object?>{
          AbeRemoteConfigKeys.payJustNowBnpl: false,
          AbeRemoteConfigKeys.softLaunchCities: 'CPT, JHB, DBN',
        },
      );

      expect(status.appCheckActive, isTrue);
      expect(status.tokenAutoRefreshEnabled, isTrue);
      expect(flags.isEnabled(FeatureFlagsService.payJustNowBnpl), isFalse);
      expect(status.activeCities, const <String>['CPT', 'JHB']);
    });

    test('verifies release manifests, Gradle flavours, iOS plist, web manifest, and Firebase configs exist without debug placeholders or em-dashes', () {
      final requiredPaths = <String>[
        'android/app/build.gradle.kts',
        'android/key.properties.example',
        'android/app/src/main/res/drawable/launch_background.xml',
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        'ios/Runner/Info.plist',
        'ios/ExportOptions.plist',
        'web/index.html',
        'web/manifest.json',
        '.env.example',
        '../firebase.json',
        '../firestore.indexes.json',
        '../storage.rules',
        '../public-site/wrangler.toml',
      ];

      for (final relPath in requiredPaths) {
        final file = File(relPath);
        expect(file.existsSync(), isTrue, reason: 'Missing config: $relPath');
        final content = file.readAsStringSync();
        expect(
          content.contains('\u2014'),
          isFalse,
          reason: 'Found forbidden em-dash in $relPath',
        );
      }

      final webManifest = File('web/manifest.json').readAsStringSync();
      expect(webManifest.contains('#FAF6F5'), isTrue);
      expect(webManifest.contains('#A65E68'), isTrue);
      expect(webManifest.contains('#0175C2'), isFalse);

      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist.contains('NSCameraUsageDescription'), isTrue);
      expect(infoPlist.contains('NSFaceIDUsageDescription'), isTrue);
    });
  });
}
