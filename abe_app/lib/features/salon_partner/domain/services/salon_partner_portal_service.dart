import '../../../../core/utils/input_sanitiser.dart';
import '../../../booking/domain/models/booking_venue_models.dart';

/// Salon Partner "Empty Chair" Portal service for commercial salons in CPT and JHB.
class SalonPartnerPortalService {
  SalonPartnerPortalService({
    List<PartnerSalonChairSlot>? seedSlots,
  }) {
    final seed = seedSlots ?? _buildDefaultSlots();
    for (final slot in seed) {
      _slots[slot.slotId] = slot;
    }
  }

  final Map<String, PartnerSalonChairSlot> _slots =
      <String, PartnerSalonChairSlot>{};
  final Map<String, int> _chairBookingsCount = <String, int>{
    'chair_cpt_claremont_am': 4,
    'chair_jhb_bryanston_am': 3,
  };

  List<PartnerSalonChairSlot> getSlotsForCity(String cityFilter) {
    final clean = cityFilter.trim().toUpperCase();
    return _slots.values
        .where((s) => clean == 'ALL' || s.city == clean)
        .toList();
  }

  int bookingsCountForSlot(String slotId) => _chairBookingsCount[slotId] ?? 0;

  int get totalGuaranteedChairRevenueZar {
    var total = 0;
    for (final slot in _slots.values) {
      total += slot.chairFeeZar * bookingsCountForSlot(slot.slotId);
    }
    return total;
  }

  PartnerSalonChairSlot publishEmptyChairSlot({
    required String slotId,
    required String venueId,
    required String venueName,
    required String city,
    required String suburb,
    required String address,
    required int chairFeeZar,
    required String windowLabel,
  }) {
    final cleanVenueName = InputSanitiser.sanitiseText(venueName, maxLength: 120);
    final cleanSuburb = InputSanitiser.sanitiseText(suburb, maxLength: 80);
    final cleanWindow = InputSanitiser.sanitiseText(windowLabel, maxLength: 120);
    if (cleanVenueName.isEmpty || cleanSuburb.isEmpty || cleanWindow.isEmpty) {
      throw ArgumentError(
        'Commercial venue name, suburb, and quiet window are required.',
      );
    }
    final validFee = InputSanitiser.requireNonNegativeInt(
      chairFeeZar,
      fieldName: 'chairFeeZar',
      strictlyPositive: true,
    );
    final cleanAddress = InputSanitiser.sanitiseText(address, maxLength: 240);
    if (cleanAddress.isEmpty ||
        RegExp(
          r'\b(house\s*call|home\s*visit|residential|client\s*home|private\s*residence)\b',
          caseSensitive: false,
        ).hasMatch(cleanAddress)) {
      throw ArgumentError(
        'Strict Venue-Only Policy: only commercial salon addresses are accepted.',
      );
    }

    final slot = PartnerSalonChairSlot(
      slotId: slotId,
      venueId: venueId,
      venueName: cleanVenueName,
      city: city,
      suburb: cleanSuburb,
      address: cleanAddress,
      chairFeeZar: validFee,
      windowLabel: cleanWindow,
      isAvailable: true,
    );
    _slots[slot.slotId] = slot;
    return slot;
  }

  PartnerSalonChairSlot toggleSlotAvailability(
    String slotId, {
    required bool isAvailable,
  }) {
    final cleanId = InputSanitiser.sanitiseText(slotId, maxLength: 128);
    final existing = _slots[cleanId];
    if (existing == null) {
      throw StateError('Chair slot $cleanId not found.');
    }
    final updated = PartnerSalonChairSlot(
      slotId: existing.slotId,
      venueId: existing.venueId,
      venueName: existing.venueName,
      city: existing.city,
      suburb: existing.suburb,
      address: existing.address,
      chairFeeZar: existing.chairFeeZar,
      windowLabel: existing.windowLabel,
      isAvailable: isAvailable,
    );
    _slots[cleanId] = updated;
    return updated;
  }

  static List<PartnerSalonChairSlot> _buildDefaultSlots() {
    return <PartnerSalonChairSlot>[
      PartnerSalonChairSlot(
        slotId: 'chair_cpt_claremont_am',
        venueId: 'venue_cpt_claremont_02',
        venueName: 'Cavendish Lane Nail Bar',
        city: 'CPT',
        suburb: 'Claremont',
        address: '14 Cavendish Street, Claremont, Cape Town',
        chairFeeZar: 120,
        windowLabel: 'Tue & Wed • 09:00 to 13:00',
        isAvailable: true,
      ),
      PartnerSalonChairSlot(
        slotId: 'chair_jhb_bryanston_am',
        venueId: 'venue_jhb_bryanston_02',
        venueName: 'Champagne Beauty Collective',
        city: 'JHB',
        suburb: 'Bryanston',
        address: '74 Sloane Street, Bryanston, Johannesburg',
        chairFeeZar: 140,
        windowLabel: 'Mon to Thu • 10:00 to 14:00',
        isAvailable: true,
      ),
    ];
  }
}
