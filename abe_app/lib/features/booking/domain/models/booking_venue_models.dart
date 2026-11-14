import '../../../../core/utils/input_sanitiser.dart';
import '../../../venue/domain/models/commercial_venue.dart';

/// Strict Venue-Only booking classification.
///
/// Only commercial studios (`verified_studio`) and off-peak partner salon
/// chairs (`partner_salon_chair`) are permitted. Residential house calls are
/// strictly forbidden.
enum BookingVenueType {
  verifiedStudio('verified_studio', 'Verified Commercial Studio'),
  partnerSalonChair('partner_salon_chair', 'Partner Salon Empty Chair');

  const BookingVenueType(this.code, this.label);

  final String code;
  final String label;

  static BookingVenueType fromCode(String rawCode) {
    final normalised = InputSanitiser.sanitiseText(rawCode, maxLength: 64)
        .toLowerCase();
    if (normalised == 'verified_studio') {
      return BookingVenueType.verifiedStudio;
    }
    if (normalised == 'partner_salon_chair' || normalised == 'partner_salon') {
      return BookingVenueType.partnerSalonChair;
    }
    throw ArgumentError.value(
      rawCode,
      'rawCode',
      'Strict Venue-Only Policy: only verified_studio or partner_salon_chair are allowed.',
    );
  }
}

/// An available off-peak chair slot at a verified Partner Salon in CPT or JHB.
class PartnerSalonChairSlot {
  PartnerSalonChairSlot({
    required String slotId,
    required String venueId,
    required String venueName,
    required String city,
    required String suburb,
    required String address,
    required num chairFeeZar,
    required String windowLabel,
    this.isAvailable = true,
  })  : slotId = InputSanitiser.sanitiseText(slotId, maxLength: 128),
        venueId = InputSanitiser.sanitiseText(venueId, maxLength: 128),
        venueName = InputSanitiser.sanitiseText(venueName, maxLength: 140),
        city = InputSanitiser.validateCityCode(city),
        suburb = InputSanitiser.sanitiseText(suburb, maxLength: 100),
        address = InputSanitiser.sanitiseText(address, maxLength: 240),
        chairFeeZar = InputSanitiser.requireNonNegativeInt(
          chairFeeZar,
          fieldName: 'chairFeeZar',
        ),
        windowLabel = InputSanitiser.sanitiseText(windowLabel, maxLength: 100) {
    if (this.slotId.isEmpty) {
      throw ArgumentError('PartnerSalonChairSlot.slotId cannot be empty.');
    }
    if (this.venueId.isEmpty) {
      throw ArgumentError('PartnerSalonChairSlot.venueId cannot be empty.');
    }
  }

  final String slotId;
  final String venueId;
  final String venueName;
  final String city;
  final String suburb;
  final String address;
  final int chairFeeZar;
  final String windowLabel;
  final bool isAvailable;
}

/// Verified commercial venue selection attached to a booking.
class BookingVenueSelection {
  BookingVenueSelection({
    required this.venueType,
    required this.venue,
    String? verifiedStudioId,
    String? partnerSalonChairSlotId,
  })  : verifiedStudioId = verifiedStudioId == null
            ? null
            : InputSanitiser.sanitiseText(verifiedStudioId, maxLength: 128),
        partnerSalonChairSlotId = partnerSalonChairSlotId == null
            ? null
            : InputSanitiser.sanitiseText(
                partnerSalonChairSlotId,
                maxLength: 128,
              ) {
    if (!venue.isVerified) {
      throw ArgumentError(
        'Strict Venue-Only Policy: unverified venues cannot be booked.',
      );
    }
    if (venueType == BookingVenueType.verifiedStudio) {
      if (this.verifiedStudioId == null || this.verifiedStudioId!.isEmpty) {
        throw ArgumentError(
          'verifiedStudioId is required for verified_studio bookings.',
        );
      }
      if (this.verifiedStudioId != venue.id) {
        throw ArgumentError(
          'verifiedStudioId must match the verified CommercialVenue.id.',
        );
      }
    } else if (venueType == BookingVenueType.partnerSalonChair) {
      if (this.partnerSalonChairSlotId == null ||
          this.partnerSalonChairSlotId!.isEmpty) {
        throw ArgumentError(
          'partnerSalonChairSlotId is required for partner_salon_chair bookings.',
        );
      }
    }
  }

  final BookingVenueType venueType;
  final CommercialVenue venue;
  final String? verifiedStudioId;
  final String? partnerSalonChairSlotId;
}

/// Firestore-ready, security-validated booking payload.
class ValidatedBookingPayload {
  const ValidatedBookingPayload({
    required this.id,
    required this.clientId,
    required this.techId,
    required this.visualContractItemId,
    required this.venueType,
    required this.venueId,
    this.verifiedStudioId,
    this.partnerSalonChairSlotId,
    required this.city,
    required this.status,
    required this.totalPriceZar,
    required this.totalDurationMinutes,
    required this.scheduledAtIso,
    required this.selectedModifierIds,
  });

  final String id;
  final String clientId;
  final String techId;
  final String visualContractItemId;
  final BookingVenueType venueType;
  final String venueId;
  final String? verifiedStudioId;
  final String? partnerSalonChairSlotId;
  final String city;
  final String status;
  final int totalPriceZar;
  final int totalDurationMinutes;
  final String scheduledAtIso;
  final List<String> selectedModifierIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'clientId': clientId,
      'techId': techId,
      'visualContractItemId': visualContractItemId,
      'venueType': venueType.code,
      'venueId': venueId,
      if (verifiedStudioId != null && verifiedStudioId!.isNotEmpty)
        'verifiedStudioId': verifiedStudioId,
      if (partnerSalonChairSlotId != null &&
          partnerSalonChairSlotId!.isNotEmpty)
        'partnerSalonChairSlotId': partnerSalonChairSlotId,
      'city': city,
      'status': status,
      'totalPriceZar': totalPriceZar,
      'totalDurationMinutes': totalDurationMinutes,
      'scheduledAtIso': scheduledAtIso,
      'selectedModifierIds': selectedModifierIds,
    };
  }
}
