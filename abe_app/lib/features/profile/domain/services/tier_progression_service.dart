import '../../../auth/domain/models/tech_profile.dart';

/// Configurable thresholds for merit tier progression on ABE.
class TierProgressionThresholds {
  const TierProgressionThresholds({
    this.verifiedMinBookings = 10,
    this.verifiedMinRating = 4.5,
    this.verifiedRequiredLivePhotoRate = 1.0,
    this.certifiedProSustainedMinBookings = 50,
    this.certifiedProSustainedMinRating = 4.85,
  });

  final int verifiedMinBookings;
  final double verifiedMinRating;
  final double verifiedRequiredLivePhotoRate;
  final int certifiedProSustainedMinBookings;
  final double certifiedProSustainedMinRating;
}

/// Metrics used to evaluate a Nail Technician's merit tier badge.
class TierEvaluationInput {
  const TierEvaluationInput({
    required this.isIdentityAndVenueVerified,
    required this.completedBookingsCount,
    required this.averageRating,
    required this.liveCompletionPhotoCount,
    this.hasAqeelahAuditionApproval = false,
  });

  final bool isIdentityAndVenueVerified;
  final int completedBookingsCount;
  final double averageRating;
  final int liveCompletionPhotoCount;

  /// Fast-track unlock granted by Aqeelah in the Admin Portal after a live
  /// physical or video skill audition.
  final bool hasAqeelahAuditionApproval;
}

/// Result of evaluating a technician's merit tier and progress towards the next badge.
class TierEvaluationResult {
  const TierEvaluationResult({
    required this.currentTier,
    required this.nextTier,
    required this.progressToNextTier,
    required this.livePhotoComplianceRate,
    required this.unlockedViaAudition,
    required this.nextStepSummary,
  });

  final TechTierBadge currentTier;
  final TechTierBadge? nextTier;
  final double progressToNextTier;
  final double livePhotoComplianceRate;
  final bool unlockedViaAudition;
  final String nextStepSummary;
}

/// Evaluates merit tier progression across *Rising Tech*, *Verified Tech*,
/// and *Certified Pro ★*.
class TierProgressionService {
  const TierProgressionService({
    this.thresholds = const TierProgressionThresholds(),
  });

  final TierProgressionThresholds thresholds;

  TierEvaluationResult evaluate(TierEvaluationInput input) {
    if (input.completedBookingsCount < 0) {
      throw ArgumentError.value(
        input.completedBookingsCount,
        'completedBookingsCount',
        'Completed bookings count cannot be negative.',
      );
    }
    if (input.liveCompletionPhotoCount < 0) {
      throw ArgumentError.value(
        input.liveCompletionPhotoCount,
        'liveCompletionPhotoCount',
        'Live completion photo count cannot be negative.',
      );
    }

    final livePhotoRate = input.completedBookingsCount == 0
        ? 1.0
        : (input.liveCompletionPhotoCount / input.completedBookingsCount)
            .clamp(0.0, 1.0);

    if (!input.isIdentityAndVenueVerified) {
      return TierEvaluationResult(
        currentTier: TechTierBadge.rising,
        nextTier: TechTierBadge.verified,
        progressToNextTier: 0.0,
        livePhotoComplianceRate: livePhotoRate,
        unlockedViaAudition: false,
        nextStepSummary:
            'Complete identity and commercial venue verification to unlock bookings.',
      );
    }

    final qualifiesSustainedPro =
        input.completedBookingsCount >=
                thresholds.certifiedProSustainedMinBookings &&
            input.averageRating >= thresholds.certifiedProSustainedMinRating &&
            livePhotoRate >= thresholds.verifiedRequiredLivePhotoRate;

    if (input.hasAqeelahAuditionApproval || qualifiesSustainedPro) {
      return TierEvaluationResult(
        currentTier: TechTierBadge.certifiedPro,
        nextTier: null,
        progressToNextTier: 1.0,
        livePhotoComplianceRate: livePhotoRate,
        unlockedViaAudition: input.hasAqeelahAuditionApproval,
        nextStepSummary: input.hasAqeelahAuditionApproval
            ? 'Certified Pro unlocked via Aqeelah\'s skill audition sign-off.'
            : 'Top merit tier achieved through sustained 5-star craft.',
      );
    }

    final qualifiesVerified =
        input.completedBookingsCount >= thresholds.verifiedMinBookings &&
            input.averageRating >= thresholds.verifiedMinRating &&
            livePhotoRate >= thresholds.verifiedRequiredLivePhotoRate;

    if (qualifiesVerified) {
      final proProgress = (input.completedBookingsCount /
              thresholds.certifiedProSustainedMinBookings)
          .clamp(0.0, 1.0);
      final remainingForPro = (thresholds.certifiedProSustainedMinBookings -
              input.completedBookingsCount)
          .clamp(0, thresholds.certifiedProSustainedMinBookings);
      return TierEvaluationResult(
        currentTier: TechTierBadge.verified,
        nextTier: TechTierBadge.certifiedPro,
        progressToNextTier: proProgress,
        livePhotoComplianceRate: livePhotoRate,
        unlockedViaAudition: false,
        nextStepSummary:
            'Complete $remainingForPro more bookings at ${thresholds.certifiedProSustainedMinRating}+ rating, or book Aqeelah\'s skill audition.',
      );
    }

    final bookingProgress =
        (input.completedBookingsCount / thresholds.verifiedMinBookings)
            .clamp(0.0, 1.0);
    final remainingForVerified =
        (thresholds.verifiedMinBookings - input.completedBookingsCount)
            .clamp(0, thresholds.verifiedMinBookings);

    String summary;
    if (livePhotoRate < thresholds.verifiedRequiredLivePhotoRate) {
      summary =
          'Maintain 100% live in-app completion photos to qualify for Verified Tech.';
    } else if (input.averageRating < thresholds.verifiedMinRating &&
        input.completedBookingsCount >= thresholds.verifiedMinBookings) {
      summary =
          'Reach a ${thresholds.verifiedMinRating}+ average rating to unlock Verified Tech.';
    } else {
      summary =
          'Complete $remainingForVerified more bookings with ${thresholds.verifiedMinRating}+ rating and 100% live photos.';
    }

    return TierEvaluationResult(
      currentTier: TechTierBadge.rising,
      nextTier: TechTierBadge.verified,
      progressToNextTier: bookingProgress,
      livePhotoComplianceRate: livePhotoRate,
      unlockedViaAudition: false,
      nextStepSummary: summary,
    );
  }
}
