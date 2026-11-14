import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/auth/domain/models/tech_profile.dart';
import 'package:abe_app/features/portfolio/data/repositories/visual_contract_repository.dart';
import 'package:abe_app/features/portfolio/domain/models/visual_contract_item.dart';
import 'package:abe_app/features/portfolio/presentation/screens/tech_portfolio_upload_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('VisualContractRepository Validation & Sanitisation Tests', () {
    test('sanitises XSS tags, replaces em-dashes, and persists valid contract', () {
      final repo = VisualContractRepository();
      final initialCount = repo.items.length;

      final created = repo.createVisualContract(
        techId: 'tech_cpt_01',
        techDisplayName: 'Nadia Jacobs',
        techTierBadge: TechTierBadge.certifiedPro,
        photoUrl: 'https://assets.abe.co.za/cpt/nadia_new.jpg',
        title: '<script>alert(1)</script>Sculpted BIAB \u2014 Rose Gold',
        basePriceZar: 480,
        baseDurationMinutes: 90,
        venueId: 'venue_cpt_seapoint_01',
      );

      expect(created.title, 'Sculpted BIAB - Rose Gold');
      expect(created.title.contains('\u2014'), isFalse);
      expect(created.city, 'CPT');
      expect(repo.items.length, initialCount + 1);
      expect(repo.items.first.id, created.id);
    });

    test('rejects below-minimum price, out-of-bounds duration, and unverified venues', () {
      final repo = VisualContractRepository();

      // Price below R150
      expect(
        () => repo.createVisualContract(
          techId: 'tech_cpt_01',
          techDisplayName: 'Nadia Jacobs',
          techTierBadge: TechTierBadge.certifiedPro,
          photoUrl: 'https://assets.abe.co.za/cpt/nadia_new.jpg',
          title: 'Classic Gel Overlay',
          basePriceZar: 90,
          baseDurationMinutes: 60,
          venueId: 'venue_cpt_seapoint_01',
        ),
        throwsArgumentError,
      );

      // Duration above 300 minutes
      expect(
        () => repo.createVisualContract(
          techId: 'tech_cpt_01',
          techDisplayName: 'Nadia Jacobs',
          techTierBadge: TechTierBadge.certifiedPro,
          photoUrl: 'https://assets.abe.co.za/cpt/nadia_new.jpg',
          title: 'Classic Gel Overlay',
          basePriceZar: 400,
          baseDurationMinutes: 420,
          venueId: 'venue_cpt_seapoint_01',
        ),
        throwsArgumentError,
      );

      // Unknown / unverified residential venue (Zero House Calls invariant)
      expect(
        () => repo.createVisualContract(
          techId: 'tech_cpt_01',
          techDisplayName: 'Nadia Jacobs',
          techTierBadge: TechTierBadge.certifiedPro,
          photoUrl: 'https://assets.abe.co.za/cpt/nadia_new.jpg',
          title: 'Classic Gel Overlay',
          basePriceZar: 400,
          baseDurationMinutes: 75,
          venueId: 'unverified_residential_house_01',
        ),
        throwsArgumentError,
      );

      // Title mentioning house calls
      expect(
        () => repo.createVisualContract(
          techId: 'tech_cpt_01',
          techDisplayName: 'Nadia Jacobs',
          techTierBadge: TechTierBadge.certifiedPro,
          photoUrl: 'https://assets.abe.co.za/cpt/nadia_new.jpg',
          title: 'VIP House Call Nail Set',
          basePriceZar: 450,
          baseDurationMinutes: 90,
          venueId: 'venue_cpt_seapoint_01',
        ),
        throwsArgumentError,
      );
    });
  });

  group('TechPortfolioUploadScreen Widget Tests', () {
    testWidgets(
      'validates inputs and publishes a new Visual Contract to repository',
      (WidgetTester tester) async {
        final repo = VisualContractRepository();
        VisualContractItem? published;

        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: TechPortfolioUploadScreen(
              repository: repo,
              onContractPublished: (item) {
                published = item;
              },
            ),
          ),
        );

        // Attempt publish with empty title -> shows validation error
        final publishBtn = find.byKey(const Key('portfolio_publish_button'));
        await tester.ensureVisible(publishBtn);
        await tester.pumpAndSettle();
        await tester.tap(publishBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('portfolio_validation_error')),
          findsOneWidget,
        );
        expect(published, isNull);

        // Fill valid title, price, and duration
        final titleInput = find.byKey(const Key('portfolio_title_input'));
        await tester.ensureVisible(titleInput);
        await tester.pumpAndSettle();
        await tester.enterText(
          titleInput,
          'Rose Gold Glazed Almond BIAB',
        );
        await tester.enterText(
          find.byKey(const Key('portfolio_base_price_input')),
          '510',
        );
        await tester.enterText(
          find.byKey(const Key('portfolio_base_duration_input')),
          '105',
        );
        await tester.pumpAndSettle();

        // Live stamp updates
        expect(find.text('Live Contract Stamp: R510'), findsOneWidget);

        // Publish contract
        await tester.ensureVisible(publishBtn);
        await tester.pumpAndSettle();
        await tester.tap(publishBtn);
        await tester.pumpAndSettle();

        expect(published, isNotNull);
        expect(published!.title, 'Rose Gold Glazed Almond BIAB');
        expect(published!.basePriceZar, 510);
        expect(published!.baseDurationMinutes, 105);
        expect(published!.allowedModifiers.length, 3);
      },
    );
  });
}
