import '../../../../core/utils/input_sanitiser.dart';

/// Allowed commercial venue classifications under the Strict Venue-Only Policy.
///
/// Residential home visits and house calls are strictly prohibited across ABE.
enum CommercialVenueType {
  /// A verified commercial nail studio or salon where the tech works permanently.
  verifiedStudio('verified_studio', 'Verified Studio'),

  /// An independent partner salon offering idle stations ("Empty Chairs") during quiet hours.
  partnerSalon('partner_salon', 'Partner Salon Chair');

  const CommercialVenueType(this.code, this.label);

  final String code;
  final String label;

  static CommercialVenueType fromCode(String rawCode) {
    final normalised = InputSanitiser.sanitiseText(rawCode, maxLength: 64);
    for (final value in CommercialVenueType.values) {
      if (value.code == normalised) {
        return value;
      }
    }
    throw ArgumentError.value(
      rawCode,
      'rawCode',
      'Invalid venue type. Only verified_studio or partner_salon are permitted (Zero House Calls).',
    );
  }
}

/// Domain model for a verified commercial salon or studio in Cape Town (`CPT`) or Johannesburg (`JHB`).
class CommercialVenue {
  CommercialVenue({
    required String id,
    required String name,
    required String city,
    required String suburb,
    required String address,
    required this.type,
    required this.isVerified,
    num emptyChairFeeZar = 0,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        name = InputSanitiser.sanitiseText(name, maxLength: 140),
        city = InputSanitiser.validateCityCode(city),
        suburb = InputSanitiser.sanitiseText(suburb, maxLength: 100),
        address = InputSanitiser.sanitiseText(address, maxLength: 240),
        emptyChairFeeZar = InputSanitiser.requireNonNegativeInt(
          emptyChairFeeZar,
          fieldName: 'emptyChairFeeZar',
        ) {
    if (this.id.isEmpty) {
      throw ArgumentError('CommercialVenue.id cannot be empty.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError('CommercialVenue.name cannot be empty.');
    }
    if (this.address.isEmpty) {
      throw ArgumentError('CommercialVenue.address cannot be empty.');
    }
    final lowerAddr = '${this.name} ${this.address}'.toLowerCase();
    if (lowerAddr.contains('house call') ||
        lowerAddr.contains('home visit') ||
        lowerAddr.contains('mobile tech')) {
      throw ArgumentError(
        'Strict Venue-Only Policy violation: residential or house-call venues are prohibited.',
      );
    }
  }

  final String id;
  final String name;

  /// Launch city code: `'CPT'` or `'JHB'`.
  final String city;

  final String suburb;
  final String address;
  final CommercialVenueType type;
  final bool isVerified;

  /// Optional chair fee in ZAR when booked as an Empty Chair partner salon.
  final int emptyChairFeeZar;

  factory CommercialVenue.fromJson(Map<String, dynamic> json) {
    return CommercialVenue(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      city: (json['city'] ?? 'CPT').toString(),
      suburb: (json['suburb'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      type: CommercialVenueType.fromCode((json['type'] ?? '').toString()),
      isVerified: json['isVerified'] as bool? ?? false,
      emptyChairFeeZar: (json['emptyChairFeeZar'] as num?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'city': city,
      'suburb': suburb,
      'address': address,
      'type': type.code,
      'isVerified': isVerified,
      'emptyChairFeeZar': emptyChairFeeZar,
    };
  }
}
