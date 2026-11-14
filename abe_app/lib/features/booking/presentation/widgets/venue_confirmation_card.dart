import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/models/booking_venue_models.dart';

/// Displays the verified commercial venue inside the booking checkout flow,
/// reinforcing ABE's Strict Venue-Only Policy (Zero House Calls).
class VenueConfirmationCard extends StatelessWidget {
  const VenueConfirmationCard({
    super.key,
    required this.selection,
    this.partnerChairSlot,
    this.onChangeVenue,
  });

  final BookingVenueSelection selection;
  final PartnerSalonChairSlot? partnerChairSlot;
  final VoidCallback? onChangeVenue;

  @override
  Widget build(BuildContext context) {
    final venue = selection.venue;
    final isPartnerChair =
        selection.venueType == BookingVenueType.partnerSalonChair;

    return Container(
      key: const Key('venue_confirmation_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D2B2123),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: BrandConfig.sageSuccess,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Verified Commercial Venue',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: BrandConfig.sageSuccess,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  venue.city,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BrandConfig.roseDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            venue.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${venue.suburb}, ${venue.city} • ${selection.venueType.label}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BrandConfig.roseDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: BrandConfig.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  venue.address,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BrandConfig.textMuted,
                      ),
                ),
              ),
            ],
          ),
          if (isPartnerChair && partnerChairSlot != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BrandConfig.bgCream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BrandConfig.borderWarm),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.event_seat_outlined,
                    size: 16,
                    color: BrandConfig.champagne,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Empty Chair Window: ${partnerChairSlot!.windowLabel} (Chair fee R${partnerChairSlot!.chairFeeZar})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BrandConfig.espresso,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Safety lock: commercial salons only, zero house calls.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandConfig.textMuted,
                      ),
                ),
              ),
              if (onChangeVenue != null)
                TextButton(
                  key: const Key('change_venue_button'),
                  onPressed: onChangeVenue,
                  child: const Text('Switch Venue'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
