import 'package:abe_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'AbeApp launches into Visual Contract Discovery Feed and filters CPT and JHB looks',
    (WidgetTester tester) async {
      await tester.pumpWidget(const AbeApp());

      expect(find.text("Aqeelah's Beauty Empire"), findsOneWidget);
      expect(find.text('Visual Contract Discovery'), findsOneWidget);
      expect(find.text('Cape Town (CPT)'), findsOneWidget);
      expect(find.text('Johannesburg (JHB)'), findsOneWidget);

      // Filter by Cape Town (CPT)
      await tester.tap(find.byKey(const Key('filter_city_CPT')));
      await tester.pump();

      expect(
        find.text('Sculpted Almond BIAB & Micro French'),
        findsOneWidget,
      );

      // Navigate to Welcome / Auth screen
      await tester.tap(find.byKey(const Key('feed_switch_role_button')));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    },
  );
}
