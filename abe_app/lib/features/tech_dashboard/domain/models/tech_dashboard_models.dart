import '../../../auth/domain/models/tech_profile.dart';
import '../../../profile/domain/services/tier_progression_service.dart';

/// Summary of a single appointment shown on the Nail Tech Dashboard.
class TechAppointmentSummary {
  const TechAppointmentSummary({
    required this.bookingId,
    required this.clientName,
    required this.lookTitle,
    required this.venueName,
    required this.venueTypeLabel,
    required this.startTimeLabel,
    required this.durationMinutes,
    required this.priceZar,
    required this.status,
  });

  final String bookingId;
  final String clientName;
  final String lookTitle;
  final String venueName;
  final String venueTypeLabel;
  final String startTimeLabel;
  final int durationMinutes;
  final int priceZar;
  final String status;
}

/// Complete data snapshot rendered by [NailTechDashboardScreen].
class TechDashboardSnapshot {
  const TechDashboardSnapshot({
    required this.techProfile,
    required this.venueName,
    required this.todayAppointments,
    required this.chairTurnoverCountToday,
    required this.chairUtilisationPercent,
    required this.pendingPayoutZar,
    required this.stockUpStoreCreditZar,
    required this.tierEvaluation,
  });

  final TechProfile techProfile;
  final String venueName;
  final List<TechAppointmentSummary> todayAppointments;
  final int chairTurnoverCountToday;
  final int chairUtilisationPercent;
  final int pendingPayoutZar;
  final int stockUpStoreCreditZar;
  final TierEvaluationResult tierEvaluation;

  /// Creates a realistic Cape Town / Johannesburg demo snapshot for prototype review.
  factory TechDashboardSnapshot.demo({
    TechProfile? profile,
    TierProgressionService tierService = const TierProgressionService(),
  }) {
    final tech = profile ??
        TechProfile(
          userId: 'tech_zinhle_cpt',
          displayName: 'Zinhle M.',
          tierBadge: TechTierBadge.rising,
          verifiedStudioId: 'venue_cpt_claremont_01',
          city: 'CPT',
          bio: 'BIAB & crisp micro-French specialist in Claremont.',
          pendingStoreCreditZar: 680,
          rating: 4.8,
          completedBookingsCount: 7,
          isApproved: true,
        );

    final evaluation = tierService.evaluate(
      TierEvaluationInput(
        isIdentityAndVenueVerified: tech.isApproved,
        completedBookingsCount: tech.completedBookingsCount,
        averageRating: tech.rating,
        liveCompletionPhotoCount: tech.completedBookingsCount,
      ),
    );

    return TechDashboardSnapshot(
      techProfile: tech,
      venueName: 'The Rose Atelier Studio',
      todayAppointments: const <TechAppointmentSummary>[
        TechAppointmentSummary(
          bookingId: 'bk_today_01',
          clientName: 'Naledi K.',
          lookTitle: 'Sculpted Almond BIAB & Micro French',
          venueName: 'The Rose Atelier Studio',
          venueTypeLabel: 'Verified Studio',
          startTimeLabel: '09:00',
          durationMinutes: 90,
          priceZar: 450,
          status: 'completed',
        ),
        TechAppointmentSummary(
          bookingId: 'bk_today_02',
          clientName: 'Taryn V.',
          lookTitle: 'Rose Quartz Chrome Glaze',
          venueName: 'The Rose Atelier Studio',
          venueTypeLabel: 'Verified Studio',
          startTimeLabel: '11:00',
          durationMinutes: 75,
          priceZar: 380,
          status: 'confirmed',
        ),
        TechAppointmentSummary(
          bookingId: 'bk_today_03',
          clientName: 'Amahle D.',
          lookTitle: 'Soft Gel Extensions + Soak-Off',
          venueName: 'Alabaster Nail Bar (Partner)',
          venueTypeLabel: 'Partner Salon Chair',
          startTimeLabel: '14:15',
          durationMinutes: 120,
          priceZar: 560,
          status: 'confirmed',
        ),
      ],
      chairTurnoverCountToday: 3,
      chairUtilisationPercent: 82,
      pendingPayoutZar: 2450,
      stockUpStoreCreditZar: tech.pendingStoreCreditZar.round(),
      tierEvaluation: evaluation,
    );
  }
}
