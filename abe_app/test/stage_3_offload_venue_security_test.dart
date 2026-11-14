import 'package:abe_app/features/booking/domain/models/booking_venue_models.dart';
import 'package:abe_app/features/booking/domain/services/venue_selection_service.dart';
import 'package:abe_app/features/venue/domain/models/commercial_venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = VenueSelectionService();

  group('VenueSelectionService.validateRawBookingPayload (Strict Venue-Only)', () {
    test('accepts valid verified_studio payload with matching verifiedStudioId', () {
      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'venue_cpt_claremont_01',
          'verifiedStudioId': 'venue_cpt_claremont_01',
          'venueName': 'The Rose Atelier Studio',
          'address': '42 Vineyard Road, Claremont, Cape Town',
          'notes': 'Afternoon gel overlay appointment.',
        }),
        returnsNormally,
      );
    });

    test('accepts valid partner_salon_chair payload with partnerSalonChairSlotId', () {
      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'partner_salon_chair',
          'venueId': 'venue_jhb_bryanston_02',
          'partnerSalonChairSlotId': 'chair_jhb_bryanston_am',
          'venueName': 'Champagne Beauty Collective (Partner)',
          'address': '74 Sloane Street, Bryanston, Johannesburg',
          'notes': 'Off-peak empty chair booking.',
        }),
        returnsNormally,
      );
    });

    test('rejects missing, null, or empty commercial venueId', () {
      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'verifiedStudioId': 'venue_cpt_claremont_01',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': null,
          'verifiedStudioId': 'venue_cpt_claremont_01',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': '   ',
          'verifiedStudioId': 'venue_cpt_claremont_01',
        }),
        throwsArgumentError,
      );
    });

    test('rejects unknown or unverified commercial venueId', () {
      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'venue_unknown_999',
          'verifiedStudioId': 'venue_unknown_999',
        }),
        throwsArgumentError,
      );

      final unverifiedVenueService = VenueSelectionService(
        venues: <CommercialVenue>[
          CommercialVenue(
            id: 'venue_cpt_unverified_01',
            name: 'Unverified Nail Bar',
            city: 'CPT',
            suburb: 'Gardens',
            address: '10 Kloof Street, Gardens, Cape Town',
            type: CommercialVenueType.verifiedStudio,
            isVerified: false,
          ),
        ],
      );

      expect(
        () => unverifiedVenueService.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'venue_cpt_unverified_01',
          'verifiedStudioId': 'venue_cpt_unverified_01',
        }),
        throwsArgumentError,
      );
    });

    test('rejects disallowed venueType values including house calls', () {
      const invalidTypes = <String>[
        '',
        'house_call',
        'home_visit',
        'residential',
        'mobile_tech',
        'client_home',
      ];

      for (final invalidType in invalidTypes) {
        expect(
          () => service.validateRawBookingPayload(<String, dynamic>{
            'venueType': invalidType,
            'venueId': 'venue_cpt_claremont_01',
            'verifiedStudioId': 'venue_cpt_claremont_01',
          }),
          throwsArgumentError,
          reason: 'Expected venueType "$invalidType" to be rejected.',
        );
      }
    });

    test('rejects residential and house-call indicators in venueName, address, or notes', () {
      const forbiddenTerms = <String>[
        'house call',
        'house_call',
        'housecall',
        'home visit',
        'home_visit',
        'residential',
        'private home',
        'client address',
        'mobile tech',
      ];

      for (final term in forbiddenTerms) {
        expect(
          () => service.validateRawBookingPayload(<String, dynamic>{
            'venueType': 'verified_studio',
            'venueId': 'venue_cpt_claremont_01',
            'verifiedStudioId': 'venue_cpt_claremont_01',
            'venueName': 'Studio ($term)',
          }),
          throwsArgumentError,
          reason: 'Expected venueName containing "$term" to be rejected.',
        );

        expect(
          () => service.validateRawBookingPayload(<String, dynamic>{
            'venueType': 'verified_studio',
            'venueId': 'venue_cpt_claremont_01',
            'verifiedStudioId': 'venue_cpt_claremont_01',
            'address': '12 Oak Lane, $term',
          }),
          throwsArgumentError,
          reason: 'Expected address containing "$term" to be rejected.',
        );

        expect(
          () => service.validateRawBookingPayload(<String, dynamic>{
            'venueType': 'verified_studio',
            'venueId': 'venue_cpt_claremont_01',
            'verifiedStudioId': 'venue_cpt_claremont_01',
            'notes': 'Please come to my ${term.toUpperCase()} instead.',
          }),
          throwsArgumentError,
          reason: 'Expected notes containing "$term" to be rejected.',
        );
      }
    });

    test('rejects missing, empty, or mismatched verifiedStudioId for verified_studio', () {
      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'venue_cpt_claremont_01',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'venue_cpt_claremont_01',
          'verifiedStudioId': '',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'verified_studio',
          'venueId': 'venue_cpt_claremont_01',
          'verifiedStudioId': 'venue_jhb_sandton_01',
        }),
        throwsArgumentError,
      );
    });

    test('rejects missing or empty partnerSalonChairSlotId for partner salon bookings', () {
      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'partner_salon_chair',
          'venueId': 'venue_cpt_seapoint_02',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'partner_salon_chair',
          'venueId': 'venue_cpt_seapoint_02',
          'partnerSalonChairSlotId': '',
        }),
        throwsArgumentError,
      );

      expect(
        () => service.validateRawBookingPayload(<String, dynamic>{
          'venueType': 'partner_salon',
          'venueId': 'venue_jhb_bryanston_02',
          'partnerSalonChairSlotId': '   ',
        }),
        throwsArgumentError,
      );
    });
  });

  group('VenueSelectionService.validateAndBuildBookingPayload (Strict Venue-Only)', () {
    test('builds Firestore-compliant payload for verified_studio in CPT', () {
      final studio = service
          .listVerifiedVenues(city: 'CPT')
          .firstWhere((v) => v.type == CommercialVenueType.verifiedStudio);
      final selection = service.selectVerifiedStudio(venue: studio);

      final payload = service.validateAndBuildBookingPayload(
        bookingId: 'bk_sec_01',
        clientId: 'client_01',
        techId: 'tech_01',
        visualContractItemId: 'vc_01',
        venueSelection: selection,
        city: 'CPT',
        totalPriceZar: 480,
        totalDurationMinutes: 90,
        scheduledAt: DateTime.utc(2026, 11, 22, 10, 0),
        selectedModifierIds: const <String>['soak_off'],
      );

      final json = payload.toJson();
      expect(json['id'], 'bk_sec_01');
      expect(json['venueType'], 'verified_studio');
      expect(json['venueId'], studio.id);
      expect(json['verifiedStudioId'], studio.id);
      expect(json.containsKey('partnerSalonChairSlotId'), isFalse);
      expect(json['city'], 'CPT');
      expect(json['status'], 'confirmed');
      expect(json['totalPriceZar'], 480);
      expect(json['totalDurationMinutes'], 90);
    });

    test('builds Firestore-compliant payload for partner_salon_chair in JHB', () {
      final partner = service
          .listVerifiedVenues(city: 'JHB')
          .firstWhere((v) => v.type == CommercialVenueType.partnerSalon);
      final slot = service.listAvailablePartnerChairSlots(city: 'JHB').first;
      final selection = service.selectPartnerSalonChair(
        partnerSalon: partner,
        chairSlot: slot,
      );

      final payload = service.validateAndBuildBookingPayload(
        bookingId: 'bk_sec_02',
        clientId: 'client_02',
        techId: 'tech_02',
        visualContractItemId: 'vc_02',
        venueSelection: selection,
        city: 'JHB',
        totalPriceZar: 590,
        totalDurationMinutes: 105,
        scheduledAt: DateTime.utc(2026, 11, 23, 12, 0),
      );

      final json = payload.toJson();
      expect(json['venueType'], 'partner_salon_chair');
      expect(json['venueId'], partner.id);
      expect(json['partnerSalonChairSlotId'], slot.slotId);
      expect(json.containsKey('verifiedStudioId'), isFalse);
      expect(json['city'], 'JHB');
      expect(json['status'], 'confirmed');
    });

    test('rejects unverified venue and mismatched verifiedStudioId in BookingVenueSelection', () {
      final unverifiedVenue = CommercialVenue(
        id: 'venue_unverified_01',
        name: 'Unverified Salon',
        city: 'CPT',
        suburb: 'Sea Point',
        address: '5 Main Road, Sea Point, Cape Town',
        type: CommercialVenueType.verifiedStudio,
        isVerified: false,
      );

      expect(
        () => BookingVenueSelection(
          venueType: BookingVenueType.verifiedStudio,
          venue: unverifiedVenue,
          verifiedStudioId: unverifiedVenue.id,
        ),
        throwsArgumentError,
      );

      final verifiedStudio = service
          .listVerifiedVenues(city: 'CPT')
          .firstWhere((v) => v.type == CommercialVenueType.verifiedStudio);

      expect(
        () => BookingVenueSelection(
          venueType: BookingVenueType.verifiedStudio,
          venue: verifiedStudio,
          verifiedStudioId: 'venue_wrong_id',
        ),
        throwsArgumentError,
      );

      expect(
        () => BookingVenueSelection(
          venueType: BookingVenueType.verifiedStudio,
          venue: verifiedStudio,
          verifiedStudioId: '',
        ),
        throwsArgumentError,
      );
    });

    test('rejects missing partnerSalonChairSlotId and unavailable or mismatched chair slots', () {
      final partner = service
          .listVerifiedVenues(city: 'CPT')
          .firstWhere((v) => v.type == CommercialVenueType.partnerSalon);

      expect(
        () => BookingVenueSelection(
          venueType: BookingVenueType.partnerSalonChair,
          venue: partner,
          partnerSalonChairSlotId: null,
        ),
        throwsArgumentError,
      );

      expect(
        () => BookingVenueSelection(
          venueType: BookingVenueType.partnerSalonChair,
          venue: partner,
          partnerSalonChairSlotId: '   ',
        ),
        throwsArgumentError,
      );

      final unavailableSlot = PartnerSalonChairSlot(
        slotId: 'chair_closed_01',
        venueId: partner.id,
        venueName: partner.name,
        city: partner.city,
        suburb: partner.suburb,
        address: partner.address,
        chairFeeZar: 95,
        windowLabel: 'Tue 09:30 - 11:30',
        isAvailable: false,
      );

      expect(
        () => service.selectPartnerSalonChair(
          partnerSalon: partner,
          chairSlot: unavailableSlot,
        ),
        throwsArgumentError,
      );

      final mismatchedSlot = PartnerSalonChairSlot(
        slotId: 'chair_other_venue_01',
        venueId: 'venue_jhb_bryanston_02',
        venueName: 'Champagne Beauty Collective (Partner)',
        city: 'JHB',
        suburb: 'Bryanston',
        address: '74 Sloane Street, Bryanston, Johannesburg',
        chairFeeZar: 110,
        windowLabel: 'Mon 10:00 - 12:00',
        isAvailable: true,
      );

      expect(
        () => service.selectPartnerSalonChair(
          partnerSalon: partner,
          chairSlot: mismatchedSlot,
        ),
        throwsArgumentError,
      );
    });

    test('rejects residential venue text during validateAndBuildBookingPayload', () {
      final residentialVenue = CommercialVenue(
        id: 'venue_cpt_res_01',
        name: 'Residential Nail Corner',
        city: 'CPT',
        suburb: 'Claremont',
        address: '15 Protea Avenue, Claremont, Cape Town',
        type: CommercialVenueType.verifiedStudio,
        isVerified: true,
      );

      final selection = BookingVenueSelection(
        venueType: BookingVenueType.verifiedStudio,
        venue: residentialVenue,
        verifiedStudioId: residentialVenue.id,
      );

      expect(
        () => service.validateAndBuildBookingPayload(
          bookingId: 'bk_res_01',
          clientId: 'client_01',
          techId: 'tech_01',
          visualContractItemId: 'vc_01',
          venueSelection: selection,
          city: 'CPT',
          totalPriceZar: 450,
          totalDurationMinutes: 75,
          scheduledAt: DateTime.utc(2026, 11, 24, 14, 0),
        ),
        throwsArgumentError,
      );
    });

    test('rejects venue city mismatch, invalid city, and invalid price or duration', () {
      final cptStudio = service
          .listVerifiedVenues(city: 'CPT')
          .firstWhere((v) => v.type == CommercialVenueType.verifiedStudio);
      final selection = service.selectVerifiedStudio(venue: cptStudio);

      expect(
        () => service.validateAndBuildBookingPayload(
          bookingId: 'bk_city_mismatch',
          clientId: 'client_01',
          techId: 'tech_01',
          visualContractItemId: 'vc_01',
          venueSelection: selection,
          city: 'JHB',
          totalPriceZar: 450,
          totalDurationMinutes: 75,
          scheduledAt: DateTime.utc(2026, 11, 24, 14, 0),
        ),
        throwsArgumentError,
      );

      expect(
        () => service.validateAndBuildBookingPayload(
          bookingId: 'bk_bad_city',
          clientId: 'client_01',
          techId: 'tech_01',
          visualContractItemId: 'vc_01',
          venueSelection: selection,
          city: 'DBN',
          totalPriceZar: 450,
          totalDurationMinutes: 75,
          scheduledAt: DateTime.utc(2026, 11, 24, 14, 0),
        ),
        throwsArgumentError,
      );

      expect(
        () => service.validateAndBuildBookingPayload(
          bookingId: 'bk_zero_price',
          clientId: 'client_01',
          techId: 'tech_01',
          visualContractItemId: 'vc_01',
          venueSelection: selection,
          city: 'CPT',
          totalPriceZar: 0,
          totalDurationMinutes: 75,
          scheduledAt: DateTime.utc(2026, 11, 24, 14, 0),
        ),
        throwsArgumentError,
      );

      expect(
        () => service.validateAndBuildBookingPayload(
          bookingId: 'bk_zero_duration',
          clientId: 'client_01',
          techId: 'tech_01',
          visualContractItemId: 'vc_01',
          venueSelection: selection,
          city: 'CPT',
          totalPriceZar: 450,
          totalDurationMinutes: 0,
          scheduledAt: DateTime.utc(2026, 11, 24, 14, 0),
        ),
        throwsArgumentError,
      );
    });
  });
}
