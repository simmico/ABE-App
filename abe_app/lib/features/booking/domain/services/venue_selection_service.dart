import '../../../../core/utils/input_sanitiser.dart';
import '../../../venue/domain/models/commercial_venue.dart';
import '../models/booking_venue_models.dart';

/// Enforces ABE's Strict Venue-Only Policy (Zero House Calls) during booking
/// venue selection and payload validation.
class VenueSelectionService {
  VenueSelectionService({
    List<CommercialVenue>? venues,
    List<PartnerSalonChairSlot>? partnerChairSlots,
  })  : _venues = venues ?? defaultVerifiedVenues(),
        _partnerChairSlots =
            partnerChairSlots ?? defaultPartnerChairSlots();

  final List<CommercialVenue> _venues;
  final List<PartnerSalonChairSlot> _partnerChairSlots;

  static const List<String> _forbiddenResidentialTerms = <String>[
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

  /// Seeded verified commercial venues in Cape Town (`CPT`) and Johannesburg (`JHB`).
  static List<CommercialVenue> defaultVerifiedVenues() {
    return <CommercialVenue>[
      CommercialVenue(
        id: 'venue_cpt_claremont_01',
        name: 'The Rose Atelier Studio',
        city: 'CPT',
        suburb: 'Claremont',
        address: '42 Vineyard Road, Claremont, Cape Town',
        type: CommercialVenueType.verifiedStudio,
        isVerified: true,
        emptyChairFeeZar: 0,
      ),
      CommercialVenue(
        id: 'venue_cpt_seapoint_02',
        name: 'Alabaster Nail Bar (Partner)',
        city: 'CPT',
        suburb: 'Sea Point',
        address: '118 Regent Road, Sea Point, Cape Town',
        type: CommercialVenueType.partnerSalon,
        isVerified: true,
        emptyChairFeeZar: 95,
      ),
      CommercialVenue(
        id: 'venue_jhb_sandton_01',
        name: 'Rosebank Velvet Nail Lounge',
        city: 'JHB',
        suburb: 'Rosebank',
        address: '19 Cradock Avenue, Rosebank, Johannesburg',
        type: CommercialVenueType.verifiedStudio,
        isVerified: true,
        emptyChairFeeZar: 0,
      ),
      CommercialVenue(
        id: 'venue_jhb_bryanston_02',
        name: 'Champagne Beauty Collective (Partner)',
        city: 'JHB',
        suburb: 'Bryanston',
        address: '74 Sloane Street, Bryanston, Johannesburg',
        type: CommercialVenueType.partnerSalon,
        isVerified: true,
        emptyChairFeeZar: 110,
      ),
    ];
  }

  /// Seeded off-peak Empty Chair slots at verified Partner Salons.
  static List<PartnerSalonChairSlot> defaultPartnerChairSlots() {
    return <PartnerSalonChairSlot>[
      PartnerSalonChairSlot(
        slotId: 'chair_cpt_seapoint_am',
        venueId: 'venue_cpt_seapoint_02',
        venueName: 'Alabaster Nail Bar (Partner)',
        city: 'CPT',
        suburb: 'Sea Point',
        address: '118 Regent Road, Sea Point, Cape Town',
        chairFeeZar: 95,
        windowLabel: 'Tue - Thu • 09:30 - 14:30',
        isAvailable: true,
      ),
      PartnerSalonChairSlot(
        slotId: 'chair_jhb_bryanston_am',
        venueId: 'venue_jhb_bryanston_02',
        venueName: 'Champagne Beauty Collective (Partner)',
        city: 'JHB',
        suburb: 'Bryanston',
        address: '74 Sloane Street, Bryanston, Johannesburg',
        chairFeeZar: 110,
        windowLabel: 'Mon - Wed • 10:00 - 15:00',
        isAvailable: true,
      ),
    ];
  }

  List<CommercialVenue> listVerifiedVenues({String? city}) {
    final normalisedCity =
        city == null ? null : InputSanitiser.validateCityCode(city);
    return _venues
        .where(
          (venue) =>
              venue.isVerified &&
              (normalisedCity == null || venue.city == normalisedCity),
        )
        .toList(growable: false);
  }

  List<PartnerSalonChairSlot> listAvailablePartnerChairSlots({
    String? city,
  }) {
    final normalisedCity =
        city == null ? null : InputSanitiser.validateCityCode(city);
    return _partnerChairSlots
        .where(
          (slot) =>
              slot.isAvailable &&
              (normalisedCity == null || slot.city == normalisedCity),
        )
        .toList(growable: false);
  }

  CommercialVenue? findVerifiedVenueById(String venueId) {
    final cleanId = InputSanitiser.sanitiseText(venueId, maxLength: 128);
    for (final venue in _venues) {
      if (venue.id == cleanId && venue.isVerified) {
        return venue;
      }
    }
    return null;
  }

  BookingVenueSelection selectVerifiedStudio({
    required CommercialVenue venue,
  }) {
    if (venue.type != CommercialVenueType.verifiedStudio) {
      throw ArgumentError(
        'Selected venue must be a verified_studio commercial salon.',
      );
    }
    return BookingVenueSelection(
      venueType: BookingVenueType.verifiedStudio,
      venue: venue,
      verifiedStudioId: venue.id,
    );
  }

  BookingVenueSelection selectPartnerSalonChair({
    required CommercialVenue partnerSalon,
    required PartnerSalonChairSlot chairSlot,
  }) {
    if (partnerSalon.type != CommercialVenueType.partnerSalon) {
      throw ArgumentError(
        'Selected venue must be a partner_salon commercial location.',
      );
    }
    if (!chairSlot.isAvailable) {
      throw ArgumentError('Selected partner salon chair slot is unavailable.');
    }
    if (chairSlot.venueId != partnerSalon.id) {
      throw ArgumentError(
        'PartnerSalonChairSlot.venueId does not match the selected partnerSalon.',
      );
    }
    return BookingVenueSelection(
      venueType: BookingVenueType.partnerSalonChair,
      venue: partnerSalon,
      partnerSalonChairSlotId: chairSlot.slotId,
    );
  }

  /// Validates all booking fields and enforces the Strict Venue-Only Policy
  /// before returning a Firestore-ready [ValidatedBookingPayload].
  ValidatedBookingPayload validateAndBuildBookingPayload({
    required String bookingId,
    required String clientId,
    required String techId,
    required String visualContractItemId,
    required BookingVenueSelection venueSelection,
    required String city,
    required int totalPriceZar,
    required int totalDurationMinutes,
    required DateTime scheduledAt,
    List<String> selectedModifierIds = const <String>[],
  }) {
    final cleanId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    final cleanClientId = InputSanitiser.sanitiseText(clientId, maxLength: 128);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    final cleanContractId =
        InputSanitiser.sanitiseText(visualContractItemId, maxLength: 128);
    final validCity = InputSanitiser.validateCityCode(city);

    if (cleanId.isEmpty ||
        cleanClientId.isEmpty ||
        cleanTechId.isEmpty ||
        cleanContractId.isEmpty) {
      throw ArgumentError('Booking identifiers cannot be empty.');
    }
    if (totalPriceZar <= 0) {
      throw ArgumentError.value(
        totalPriceZar,
        'totalPriceZar',
        'Booking totalPriceZar must be greater than zero.',
      );
    }
    if (totalDurationMinutes <= 0) {
      throw ArgumentError.value(
        totalDurationMinutes,
        'totalDurationMinutes',
        'Booking totalDurationMinutes must be greater than zero.',
      );
    }
    if (!venueSelection.venue.isVerified) {
      throw ArgumentError(
        'Strict Venue-Only Policy: venue must be verified before booking.',
      );
    }
    if (venueSelection.venue.city != validCity) {
      throw ArgumentError(
        'Venue city (${venueSelection.venue.city}) does not match booking city ($validCity).',
      );
    }
    _rejectResidentialText(
      '${venueSelection.venue.name} ${venueSelection.venue.address}',
    );

    final cleanModifiers = selectedModifierIds
        .map((id) => InputSanitiser.sanitiseText(id, maxLength: 80))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    return ValidatedBookingPayload(
      id: cleanId,
      clientId: cleanClientId,
      techId: cleanTechId,
      visualContractItemId: cleanContractId,
      venueType: venueSelection.venueType,
      venueId: venueSelection.venue.id,
      verifiedStudioId: venueSelection.verifiedStudioId,
      partnerSalonChairSlotId: venueSelection.partnerSalonChairSlotId,
      city: validCity,
      status: 'confirmed',
      totalPriceZar: totalPriceZar,
      totalDurationMinutes: totalDurationMinutes,
      scheduledAtIso: scheduledAt.toUtc().toIso8601String(),
      selectedModifierIds: cleanModifiers,
    );
  }

  /// Validates a raw JSON booking payload against the Strict Venue-Only invariant.
  void validateRawBookingPayload(Map<String, dynamic> payload) {
    final rawVenueType = (payload['venueType'] ?? '').toString();
    final venueType = BookingVenueType.fromCode(rawVenueType);

    final rawVenueId =
        InputSanitiser.sanitiseText((payload['venueId'] ?? '').toString());
    if (rawVenueId.isEmpty) {
      throw ArgumentError(
        'Strict Venue-Only Policy violation: venueId is required.',
      );
    }

    final matchedVenue = findVerifiedVenueById(rawVenueId);
    if (matchedVenue == null || !matchedVenue.isVerified) {
      throw ArgumentError(
        'Strict Venue-Only Policy violation: venueId "$rawVenueId" is not a verified commercial venue.',
      );
    }

    if (venueType == BookingVenueType.verifiedStudio) {
      final studioId = InputSanitiser.sanitiseText(
        (payload['verifiedStudioId'] ?? '').toString(),
      );
      if (studioId.isEmpty || studioId != rawVenueId) {
        throw ArgumentError(
          'Strict Venue-Only Policy violation: verifiedStudioId must match venueId.',
        );
      }
    } else {
      final chairSlotId = InputSanitiser.sanitiseText(
        (payload['partnerSalonChairSlotId'] ?? '').toString(),
      );
      if (chairSlotId.isEmpty) {
        throw ArgumentError(
          'Strict Venue-Only Policy violation: partnerSalonChairSlotId is required for partner salon bookings.',
        );
      }
    }

    _rejectResidentialText(
      '${payload['venueName'] ?? ''} ${payload['address'] ?? ''} ${payload['notes'] ?? ''}',
    );
  }

  void _rejectResidentialText(String rawText) {
    final lower = rawText.toLowerCase();
    for (final term in _forbiddenResidentialTerms) {
      if (lower.contains(term)) {
        throw ArgumentError(
          'Strict Venue-Only Policy violation: residential or house-call bookings are strictly prohibited.',
        );
      }
    }
  }
}
