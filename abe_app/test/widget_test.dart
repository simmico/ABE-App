import 'package:abe_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'AbeApp Stage 1 & 2 prototype navigates DiscoveryFeed -> VisualContractDetail -> TechPortfolioUpload',
    (WidgetTester tester) async {
      await tester.pumpWidget(const AbeApp());

      expect(find.text("Aqeelah's Beauty Empire"), findsOneWidget);
      expect(find.text('Visual Contract Discovery'), findsOneWidget);
      expect(find.text('Cape Town (CPT)'), findsOneWidget);
      expect(find.text('Johannesburg (JHB)'), findsOneWidget);

      // Filter by Cape Town (CPT)
      await tester.tap(find.byKey(const Key('filter_city_CPT')));
      await tester.pumpAndSettle();

      expect(
        find.text('Sculpted Almond BIAB & Micro French'),
        findsOneWidget,
      );

      // Tap first Visual Contract card -> navigates to VisualContractDetailScreen
      final firstCardFinder = find.byKey(const Key('feed_card_vc_cpt_01'));
      await tester.ensureVisible(firstCardFinder);
      await tester.pumpAndSettle();
      await tester.tap(firstCardFinder);
      await tester.pumpAndSettle();

      expect(find.text('Visual Contract Booking'), findsOneWidget);
      expect(find.text('Optional Studio Add-Ons'), findsOneWidget);

      // Tap back to return to DiscoveryFeedScreen
      await tester.tap(find.byKey(const Key('booking_detail_back_button')));
      await tester.pumpAndSettle();

      expect(find.text('Visual Contract Discovery'), findsOneWidget);

      // Tap Upload Set to open TechPortfolioUploadScreen
      await tester.tap(find.byKey(const Key('feed_open_tech_upload_button')));
      await tester.pumpAndSettle();

      expect(find.text('Publish a Visual Contract Set'), findsOneWidget);

      // Return to DiscoveryFeedScreen and open Account & City
      await tester.tap(find.byKey(const Key('portfolio_upload_back_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feed_switch_role_button')));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    },
  );
}
