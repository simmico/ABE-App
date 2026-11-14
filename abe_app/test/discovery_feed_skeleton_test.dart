import 'package:abe_app/core/config/brand_config.dart';
import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/portfolio/presentation/widgets/discovery_feed_skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DiscoveryFeedSkeleton & EmptyState Widget Tests', () {
    testWidgets(
      'DiscoveryFeedSkeletonCard and DiscoveryFeedSkeletonGrid render cleanly with Warm Luxury tokens',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: const Scaffold(
              backgroundColor: BrandConfig.bgCream,
              body: SingleChildScrollView(
                child: DiscoveryFeedSkeletonGrid(
                  itemCount: 2,
                  crossAxisCount: 2,
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('discovery_feed_skeleton_grid')),
          findsOneWidget,
        );
        expect(find.byType(DiscoveryFeedSkeletonCard), findsNWidgets(2));

        await tester.pumpAndSettle();
        expect(find.byType(DiscoveryFeedSkeletonCard), findsNWidgets(2));
      },
    );

    testWidgets(
      'DiscoveryEmptyStateIllustration renders default copy and invokes reset callback',
      (WidgetTester tester) async {
        bool resetTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: Scaffold(
              backgroundColor: BrandConfig.bgCream,
              body: DiscoveryEmptyStateIllustration(
                onResetFilters: () {
                  resetTapped = true;
                },
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('discovery_empty_state_illustration')),
          findsOneWidget,
        );
        expect(find.text('No matching nail looks found'), findsOneWidget);
        expect(
          find.text('Verified studio & partner salon bookings only'),
          findsOneWidget,
        );
        expect(find.text('CPT • JHB'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('discovery_empty_state_reset_button')),
        );
        await tester.pump();

        expect(resetTapped, isTrue);
      },
    );
  });
}
