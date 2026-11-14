import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/auth/domain/models/tech_profile.dart';
import 'package:abe_app/features/profile/domain/services/tier_progression_service.dart';
import 'package:abe_app/features/tech_dashboard/domain/models/tech_dashboard_models.dart';
import 'package:abe_app/features/tech_dashboard/presentation/screens/nail_tech_dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const service = TierProgressionService();

  group('TierProgressionService Unit Tests', () {
    test('returns Rising Tech when under booking threshold or unverified', () {
      final unverified = service.evaluate(
        const TierEvaluationInput(
          isIdentityAndVenueVerified: false,
          completedBookingsCount: 15,
          averageRating: 4.9,
          liveCompletionPhotoCount: 15,
        ),
      );
      expect(unverified.currentTier, TechTierBadge.rising);
      expect(unverified.progressToNextTier, 0.0);

      final rising = service.evaluate(
        const TierEvaluationInput(
          isIdentityAndVenueVerified: true,
          completedBookingsCount: 6,
          averageRating: 4.8,
          liveCompletionPhotoCount: 6,
        ),
      );
      expect(rising.currentTier, TechTierBadge.rising);
      expect(rising.nextTier, TechTierBadge.verified);
      expect(rising.progressToNextTier, closeTo(0.6, 0.001));
    });

    test('unlocks Verified Tech at 10 bookings, >= 4.5 rating, 100% live photos',
        () {
      final verified = service.evaluate(
        const TierEvaluationInput(
          isIdentityAndVenueVerified: true,
          completedBookingsCount: 10,
          averageRating: 4.5,
          liveCompletionPhotoCount: 10,
        ),
      );
      expect(verified.currentTier, TechTierBadge.verified);
      expect(verified.nextTier, TechTierBadge.certifiedPro);

      // Missing 1 live completion photo prevents Verified Tech unlock.
      final missingPhoto = service.evaluate(
        const TierEvaluationInput(
          isIdentityAndVenueVerified: true,
          completedBookingsCount: 10,
          averageRating: 4.9,
          liveCompletionPhotoCount: 9,
        ),
      );
      expect(missingPhoto.currentTier, TechTierBadge.rising);
    });

    test('unlocks Certified Pro via Aqeelah audition or sustained milestone', () {
      final auditionPro = service.evaluate(
        const TierEvaluationInput(
          isIdentityAndVenueVerified: true,
          completedBookingsCount: 2,
          averageRating: 4.9,
          liveCompletionPhotoCount: 2,
          hasAqeelahAuditionApproval: true,
        ),
      );
      expect(auditionPro.currentTier, TechTierBadge.certifiedPro);
      expect(auditionPro.unlockedViaAudition, isTrue);
      expect(auditionPro.nextTier, isNull);

      final sustainedPro = service.evaluate(
        const TierEvaluationInput(
          isIdentityAndVenueVerified: true,
          completedBookingsCount: 52,
          averageRating: 4.9,
          liveCompletionPhotoCount: 52,
        ),
      );
      expect(sustainedPro.currentTier, TechTierBadge.certifiedPro);
      expect(sustainedPro.unlockedViaAudition, isFalse);
    });
  });

  group('NailTechDashboardScreen Widget Tests', () {
    testWidgets(
        'renders tier progress, pending payout, store credit, chair turnover, and today appointments',
        (WidgetTester tester) async {
      final snapshot = TechDashboardSnapshot.demo();
      var calendarOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AbeTheme.lightTheme,
          home: NailTechDashboardScreen(
            snapshot: snapshot,
            onOpenCalendarSetup: () => calendarOpened = true,
          ),
        ),
      );

      expect(find.text('Tech Studio Hub'), findsOneWidget);
      expect(find.text('Rising Tech'), findsOneWidget);
      expect(find.byKey(const Key('tier_progress_bar')), findsOneWidget);
      expect(find.text('R2450'), findsOneWidget);
      expect(find.text('R680'), findsOneWidget);
      expect(find.text('3 clients • 82% utilised'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sculpted Almond BIAB & Micro French'),
        200,
      );
      expect(
        find.text('Sculpted Almond BIAB & Micro French'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('dashboard_calendar_button')));
      await tester.pumpAndSettle();
      expect(calendarOpened, isTrue);
    });
  });
}
