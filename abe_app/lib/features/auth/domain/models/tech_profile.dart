import '../../../../core/utils/input_sanitiser.dart';

/// Merit tier badges for Nail Technicians on ABE.
enum TechTierBadge {
  /// Entry tier upon onboarding and commercial venue verification.
  rising('rising', 'Rising Tech'),

  /// Unlocked after completing bookings with high ratings and live completion photos.
  verified('verified', 'Verified Tech'),

  /// Highest standard, unlocked via sustained performance or Aqeelah's live skill audition.
  certifiedPro('certified_pro', 'Certified Pro ★');

  const TechTierBadge(this.code, this.label);

  final String code;
  final String label;

  static TechTierBadge fromCode(String rawCode) {
    for (final badge in TechTierBadge.values) {
      if (badge.code == rawCode.trim()) {
        return badge;
      }
    }
    return TechTierBadge.rising;
  }
}

/// Domain model for a Nail Technician's verified profile and merit tier.
class TechProfile {
  TechProfile({
    required String userId,
    required String displayName,
    required this.tierBadge,
    required String verifiedStudioId,
    required String city,
    String bio = '',
    num pendingStoreCreditZar = 0,
    num rating = 5.0,
    num completedBookingsCount = 0,
    this.isApproved = true,
  })  : userId = InputSanitiser.sanitiseText(userId, maxLength: 128),
        displayName = InputSanitiser.sanitiseText(displayName, maxLength: 120),
        verifiedStudioId =
            InputSanitiser.sanitiseText(verifiedStudioId, maxLength: 128),
        city = InputSanitiser.validateCityCode(city),
        bio = InputSanitiser.sanitiseText(bio, maxLength: 500),
        pendingStoreCreditZar = InputSanitiser.requireNonNegativeDouble(
          pendingStoreCreditZar,
          fieldName: 'pendingStoreCreditZar',
        ),
        rating = InputSanitiser.requireNonNegativeDouble(
          rating,
          fieldName: 'rating',
        ),
        completedBookingsCount = InputSanitiser.requireNonNegativeInt(
          completedBookingsCount,
          fieldName: 'completedBookingsCount',
        ) {
    if (this.userId.isEmpty) {
      throw ArgumentError('TechProfile.userId cannot be empty.');
    }
    if (this.displayName.isEmpty) {
      throw ArgumentError('TechProfile.displayName cannot be empty.');
    }
    if (this.verifiedStudioId.isEmpty) {
      throw ArgumentError(
        'TechProfile.verifiedStudioId cannot be empty (Strict Venue-Only Policy).',
      );
    }
  }

  final String userId;
  final String displayName;
  final TechTierBadge tierBadge;

  /// Every Nail Technician must be linked to a verified commercial studio or partner salon.
  final String verifiedStudioId;

  /// Launch city (`'CPT'` or `'JHB'`).
  final String city;

  final String bio;

  /// Pending earnings available to spend in the Phase 2 Stock-Up Supply Store.
  final double pendingStoreCreditZar;

  final double rating;
  final int completedBookingsCount;
  final bool isApproved;

  factory TechProfile.fromJson(Map<String, dynamic> json) {
    return TechProfile(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      tierBadge: TechTierBadge.fromCode((json['tierBadge'] ?? 'rising').toString()),
      verifiedStudioId: (json['verifiedStudioId'] ?? '').toString(),
      city: (json['city'] ?? 'CPT').toString(),
      bio: (json['bio'] ?? '').toString(),
      pendingStoreCreditZar: (json['pendingStoreCreditZar'] as num?) ?? 0,
      rating: (json['rating'] as num?) ?? 5.0,
      completedBookingsCount: (json['completedBookingsCount'] as num?) ?? 0,
      isApproved: json['isApproved'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'tierBadge': tierBadge.code,
      'verifiedStudioId': verifiedStudioId,
      'city': city,
      'bio': bio,
      'pendingStoreCreditZar': pendingStoreCreditZar,
      'rating': rating,
      'completedBookingsCount': completedBookingsCount,
      'isApproved': isApproved,
    };
  }
}
