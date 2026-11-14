import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/auth/domain/models/tech_profile.dart';
import 'package:abe_app/features/portfolio/domain/models/visual_contract_item.dart';
import 'package:abe_app/features/portfolio/presentation/widgets/visual_contract_card.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('VisualContractCard Widget Tests', () {
    testWidgets(
      'renders hard-coded base price, exact duration, Certified Pro badge, and verified commercial venue tag',
      (WidgetTester tester) async {
        final sampleContract = VisualContractItem(
          id: 'vc_cpt_001',
          techId: 'tech_cpt_aqeelah_01',
          techDisplayName: 'Nadia Jacobs',
          techTierBadge: TechTierBadge.certifiedPro,
          photoUrl: 'https://assets.abe.co.za/nails/french_biab.jpg',
          title: 'Sculpted Almond BIAB & Micro French',
          basePriceZar: 450,
          baseDurationMinutes: 90,
          city: 'CPT',
          venueId: 'venue_cpt_seapoint_01',
          venueName: 'Atelier Rose Studio, Sea Point',
          venueType: CommercialVenueType.verifiedStudio,
          allowedModifiers: <ContractModifier>[
            ContractModifier(
              id: 'mod_soak_off',
              name: 'Soak-Off / Removal',
              additionalPriceZar: 80,
              additionalDurationMinutes: 30,
            ),
            ContractModifier(
              id: 'mod_extra_length',
              name: 'Extra Length',
              additionalPriceZar: 60,
              additionalDurationMinutes: 15,
            ),
          ],
        );

        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                child: VisualContractCard(
                  item: sampleContract,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('R450'), findsOneWidget);
        expect(find.text('90 mins'), findsOneWidget);
        expect(find.text('Certified Pro ★'), findsOneWidget);
        expect(
          find.text('Atelier Rose Studio, Sea Point • Verified Studio'),
          findsOneWidget,
        );
        expect(
          find.text('Sculpted Almond BIAB & Micro French'),
          findsOneWidget,
        );
        expect(find.text('Nadia Jacobs'), findsOneWidget);
        expect(find.text('+2 add-ons'), findsOneWidget);

        await tester.tap(find.byType(VisualContractCard));
        await tester.pump();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'renders Rising Tech and Verified Tech merit badges accurately',
      (WidgetTester tester) async {
        final risingContract = VisualContractItem(
          id: 'vc_jhb_002',
          techId: 'tech_jhb_02',
          techDisplayName: 'Thando Mokoena',
          techTierBadge: TechTierBadge.rising,
          photoUrl: 'https://assets.abe.co.za/nails/rose_chrome.jpg',
          title: 'Dusty Rose Chrome Gel Overlay',
          basePriceZar: 380,
          baseDurationMinutes: 75,
          city: 'JHB',
          venueId: 'venue_jhb_rosebank_01',
          venueName: 'The Velvet Chair Bar, Rosebank',
          venueType: CommercialVenueType.partnerSalon,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AbeTheme.lightTheme,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                child: VisualContractCard(item: risingContract),
              ),
            ),
          ),
        );

        expect(find.text('R380'), findsOneWidget);
        expect(find.text('75 mins'), findsOneWidget);
        expect(find.text('Rising Tech'), findsOneWidget);
        expect(find.text('JHB'), findsOneWidget);
        expect(
          find.text('The Velvet Chair Bar, Rosebank • Partner Salon Chair'),
          findsOneWidget,
        );
      },
    );
  });
}
