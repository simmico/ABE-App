import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/booking/domain/services/venue_selection_service.dart';
import 'package:abe_app/features/booking/presentation/widgets/venue_confirmation_card.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final service = VenueSelectionService();

  group('VenueSelectionService Strict Venue-Only Policy Tests', () {
    test('builds valid booking payload for verified_studio', () {
      final cptStudio = service
          .listVerifiedVenues(city: 'CPT')
          .firstWhere((v) => v.type == CommercialVenueType.verifiedStudio);
      final selection = service.selectVerifiedStudio(venue: cptStudio);

      final payload = service.validateAndBuildBookingPayload(
        bookingId: 'bk_studio_01',
        clientId: 'cli_01',
        techId: 'tech_01',
        visualContractItemId: 'vc_01',
        venueSelection: selection,
        city: 'CPT',
        totalPriceZar: 450,
        totalDurationMinutes: 90,
        scheduledAt: DateTime(2026, 11, 20, 10, 0),
      );

      final json = payload.toJson();
      expect(json['venueType'], 'verified_studio');
      expect(json['venueId'], cptStudio.id);
      expect(json['verifiedStudioId'], cptStudio.id);
      expect(json['city'], 'CPT');
    });

    test('builds valid booking payload for partner_salon_chair', () {
      final jhbPartner = service
          .listVerifiedVenues(city: 'JHB')
          .firstWhere((v) => v.type == CommercialVenueType.partnerSalon);
      final chairSlot =
          service.listAvailablePartnerChairSlots(city: 'JHB').first;
      final selection = service.selectPartnerSalonChair(
        partnerSalon: jhbPartner,
        chairSlot: chairSlot,
      );

      final payload = service.validateAndBuildBookingPayload(
        bookingId: 'bk_partner_01',
        clientId: 'cli_02',
        techId: 'tech_02',
        visualContractItemId: 'vc_02',
        venueSelection: selection,
        city: 'JHB',
        totalPriceZar: 520,
        totalDurationMinutes: 105,
        scheduledAt: DateTime(2026, 11, 21, 11, 0),
      );

      final json = payload.toJson();
      expect(json['venueType'], 'partner_salon_chair');
      expect(json['venueId'], jhbPartner.id);
      expect(json['partnerSalonChairSlotId'], chairSlot.slotId);
    });

    test('rejects house_call, missing venueId, and unverified venues', () {
      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'house_call',
          'venueId': 'venue_cpt_claremont_01',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': '',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'unverified_home_salon',
          'verifiedStudioId': 'unverified_home_salon',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'venue_cpt_claremont_01',
          'verifiedStudioId': 'venue_cpt_claremont_01',
          'notes': 'Client asked for a residential home visit instead',
        }),
        throwsArgumentError,
      );
    });
  });

  group('VenueConfirmationCard Widget Tests', () {
    testWidgets('renders verified commercial venue details and switch callback',
        (WidgetTester tester) async {
      var switched = false;
      final cptPartner = service
          .listVerifiedVenues(city: 'CPT')
          .firstWhere((v) => v.type == CommercialVenueType.partnerSalon);
      final chairSlot =
          service.listAvailablePartnerChairSlots(city: 'CPT').first;
      final selection = service.selectPartnerSalonChair(
        partnerSalon: cptPartner,
        chairSlot: chairSlot,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AbeTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: VenueConfirmationCard(
                selection: selection,
                partnerChairSlot: chairSlot,
                onChangeVenue: () => switched = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Verified Commercial Venue'), findsOneWidget);
      expect(find.text('Alabaster Nail Bar (Partner)'), findsOneWidget);
      expect(find.textContaining('Empty Chair Window:'), findsOneWidget);

      await tester.tap(find.byKey(const Key('change_venue_button')));
      await tester.pumpAndSettle();
      expect(switched, isTrue);
    });
  });
}
