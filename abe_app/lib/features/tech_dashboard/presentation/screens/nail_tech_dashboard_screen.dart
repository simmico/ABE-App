import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../../auth/domain/models/tech_profile.dart';
import '../../domain/models/tech_dashboard_models.dart';

/// Nail Technician In-App Dashboard displaying Today's Appointments,
/// Chair Turnover stats, Merit Tier Badge progress bar, Pending Payout
/// Balance, and Stock-Up Store credit allowance.
class NailTechDashboardScreen extends StatelessWidget {
  const NailTechDashboardScreen({
    super.key,
    required this.snapshot,
    this.onOpenCalendarSetup,
    this.onOpenPortfolioUpload,
    this.onBack,
  });

  final TechDashboardSnapshot snapshot;
  final VoidCallback? onOpenCalendarSetup;
  final VoidCallback? onOpenPortfolioUpload;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tech = snapshot.techProfile;
    final eval = snapshot.tierEvaluation;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : null,
        title: const Text('Tech Studio Hub'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: <Widget>[
          _buildHeaderCard(context, tech),
          const SizedBox(height: 16),
          _buildTierProgressCard(context, eval.currentTier, eval.nextTier,
              eval.progressToNextTier, eval.nextStepSummary),
          const SizedBox(height: 16),
          _buildMetricsRow(context),
          const SizedBox(height: 16),
          _buildQuickActions(context),
          const SizedBox(height: 22),
          Text(
            "Today's Appointments",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (snapshot.todayAppointments.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BrandConfig.surfaceCard,
                borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                border: Border.all(color: BrandConfig.borderWarm),
              ),
              child: Text(
                'No appointments booked for today yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BrandConfig.textMuted,
                    ),
              ),
            )
          else
            for (final appt in snapshot.todayAppointments) ...<Widget>[
              _buildAppointmentCard(context, appt),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, TechProfile tech) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: BrandConfig.blushSoft,
            child: Text(
              tech.displayName.isNotEmpty
                  ? tech.displayName[0].toUpperCase()
                  : 'T',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: BrandConfig.roseDark,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tech.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '${snapshot.venueName} • ${tech.city}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandConfig.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2EE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '★ ${tech.rating.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: BrandConfig.sageSuccess,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierProgressCard(
    BuildContext context,
    TechTierBadge currentTier,
    TechTierBadge? nextTier,
    double progress,
    String nextStepSummary,
  ) {
    final isPro = currentTier == TechTierBadge.certifiedPro;

    return Container(
      key: const Key('tier_progress_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(
          color: isPro ? BrandConfig.champagne : BrandConfig.borderWarm,
          width: isPro ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPro ? BrandConfig.espresso : BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  currentTier.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isPro
                            ? BrandConfig.surfaceCard
                            : BrandConfig.roseDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                nextTier != null
                    ? 'Next: ${nextTier.label}'
                    : 'Top Tier Unlocked',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: BrandConfig.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: const Key('tier_progress_bar'),
              value: progress,
              minHeight: 8,
              backgroundColor: BrandConfig.blushSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPro ? BrandConfig.champagne : BrandConfig.rosePrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            nextStepSummary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BrandConfig.textMuted,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                tileKey: const Key('pending_payout_tile'),
                label: 'Pending Payout',
                value: 'R${snapshot.pendingPayoutZar}',
                subtitle: 'Weekly auto-payout',
                accentColor: BrandConfig.rosePrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                tileKey: const Key('store_credit_tile'),
                label: 'Stock-Up Credit',
                value: 'R${snapshot.stockUpStoreCreditZar}',
                subtitle: 'Supply Store allowance',
                accentColor: BrandConfig.champagne,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatTile(
          tileKey: const Key('chair_turnover_tile'),
          label: 'Chair Turnover Today',
          value:
              '${snapshot.chairTurnoverCountToday} clients • ${snapshot.chairUtilisationPercent}% utilised',
          subtitle: 'Commercial salon & partner chair bookings',
          accentColor: BrandConfig.sageSuccess,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('dashboard_calendar_button'),
            onPressed: onOpenCalendarSetup,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Studio Hours'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('dashboard_upload_look_button'),
            onPressed: onOpenPortfolioUpload,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const Text('Upload Look'),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    TechAppointmentSummary appt,
  ) {
    final isCompleted = appt.status == 'completed';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: BrandConfig.blushSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              appt.startTimeLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: BrandConfig.roseDark,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  appt.lookTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${appt.clientName} • ${appt.durationMinutes} mins • ${appt.venueName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandConfig.textMuted,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      'R${appt.priceZar}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: BrandConfig.espresso,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFEAF2EE)
                            : BrandConfig.bgCream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: BrandConfig.borderWarm),
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : 'Confirmed',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isCompleted
                                  ? BrandConfig.sageSuccess
                                  : BrandConfig.espresso,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    this.tileKey,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  final Key? tileKey;
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: tileKey,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: BrandConfig.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: BrandConfig.espresso,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandConfig.textMuted,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
