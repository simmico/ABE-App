import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/models/dispute_and_audit_models.dart';
import '../../domain/services/dispute_resolution_service.dart';

/// Built-In 3-Photo Dispute Support Queue for Dispute Support Staff & Admins.
///
/// Displays side-by-side:
/// 1. Booked Visual Contract Portfolio Photo
/// 2. Tech's Live In-App Completion Photo
/// 3. Client's Dispute Photo
/// with 1-click buttons to credit the client's ABE Wallet or release payout to the tech.
class DisputeSupportQueueScreen extends StatefulWidget {
  const DisputeSupportQueueScreen({
    super.key,
    required this.actorId,
    required this.actorUacGroup,
    required this.disputeService,
    this.actorIsActive = true,
    this.onBack,
  });

  final String actorId;
  final String actorUacGroup;
  final DisputeResolutionService disputeService;
  final bool actorIsActive;
  final VoidCallback? onBack;

  @override
  State<DisputeSupportQueueScreen> createState() =>
      _DisputeSupportQueueScreenState();
}

class _DisputeSupportQueueScreenState extends State<DisputeSupportQueueScreen> {
  String? _statusMessage;
  bool _isError = false;

  void _resolveRefund(DisputeTicket ticket) {
    try {
      widget.disputeService.resolveCreditClientWallet(
        ticketId: ticket.id,
        actorId: widget.actorId,
        actorUacGroup: widget.actorUacGroup,
        actorIsActive: widget.actorIsActive,
        idempotencyKey: 'disp_refund_${ticket.id}',
      );
      setState(() {
        _isError = false;
        _statusMessage =
            'Dispute ${ticket.id} resolved: credited client ABE Wallet.';
      });
    } catch (_) {
      setState(() {
        _isError = true;
        _statusMessage =
            'Unable to credit client wallet. Dispute resolution access required.';
      });
    }
  }

  void _resolveReleasePayout(DisputeTicket ticket) {
    try {
      widget.disputeService.resolveReleasePayoutToTech(
        ticketId: ticket.id,
        actorId: widget.actorId,
        actorUacGroup: widget.actorUacGroup,
        actorIsActive: widget.actorIsActive,
        idempotencyKey: 'disp_payout_${ticket.id}',
      );
      setState(() {
        _isError = false;
        _statusMessage =
            'Dispute ${ticket.id} resolved: released payout to nail technician.';
      });
    } catch (_) {
      setState(() {
        _isError = true;
        _statusMessage =
            'Unable to release tech payout. Dispute resolution access required.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    List<DisputeTicket> tickets = const <DisputeTicket>[];
    String? accessError;

    try {
      tickets = widget.disputeService.getTicketsForStaff(
        actorId: widget.actorId,
        actorUacGroup: widget.actorUacGroup,
        isActive: widget.actorIsActive,
      );
    } catch (_) {
      accessError =
          'Access denied: active dispute support permission is required.';
    }

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('dispute_queue_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Dispute Queue'),
      ),
      body: SafeArea(
        child: accessError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BrandConfig.errorSoft,
                      borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                      border: Border.all(color: BrandConfig.errorTerracotta),
                    ),
                    child: Text(
                      accessError,
                      key: const Key('dispute_access_denied_text'),
                      style: textTheme.titleMedium?.copyWith(
                        color: BrandConfig.espresso,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: <Widget>[
                  Text(
                    'Compare the booked Visual Contract, the tech live camera proof, and the client complaint photo side-by-side.',
                    style: textTheme.bodyMedium,
                  ),
                  if (_statusMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const Key('dispute_status_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isError
                              ? BrandConfig.errorSoft
                              : BrandConfig.sageSoft,
                          borderRadius:
                              BorderRadius.circular(BrandConfig.inputRadius),
                          border: Border.all(
                            color: _isError
                                ? BrandConfig.errorTerracotta
                                : BrandConfig.sageSuccess,
                          ),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: textTheme.bodySmall?.copyWith(
                            color: BrandConfig.espresso,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (final ticket in tickets) ...<Widget>[
                    _buildTicketCard(textTheme, ticket),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildTicketCard(TextTheme textTheme, DisputeTicket ticket) {
    final isResolved = ticket.status.startsWith('resolved_');

    return Container(
      key: Key('dispute_card_${ticket.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Ticket ${ticket.id} • Booking ${ticket.bookingId}',
                  style: textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isResolved
                      ? BrandConfig.sageSoft
                      : BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
                child: Text(
                  isResolved ? 'Resolved' : 'Needs Review',
                  style: textTheme.labelMedium?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(ticket.clientReason, style: textTheme.bodyMedium),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = <Widget>[
                _PhotoComparisonTile(
                  label: '1. Booked Contract',
                  url: ticket.portfolioPhotoUrl,
                  accent: BrandConfig.champagne,
                ),
                _PhotoComparisonTile(
                  label: '2. Live Camera Proof',
                  url: ticket.techLiveCompletionPhotoUrl,
                  accent: BrandConfig.sageSuccess,
                ),
                _PhotoComparisonTile(
                  label: '3. Client Dispute',
                  url: ticket.clientComplaintPhotoUrl,
                  accent: BrandConfig.rosePrimary,
                ),
              ];
              if (constraints.maxWidth < 460) {
                return SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tiles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) => SizedBox(width: 154, child: tiles[idx]),
                  ),
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 8),
                  Expanded(child: tiles[1]),
                  const SizedBox(width: 8),
                  Expanded(child: tiles[2]),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (!isResolved)
            LayoutBuilder(
              builder: (context, constraints) {
                final refundButton = OutlinedButton(
                  key: Key('dispute_refund_client_${ticket.id}'),
                  onPressed: () => _resolveRefund(ticket),
                  child: const Text('Credit Client Wallet'),
                );
                final releaseButton = ElevatedButton(
                  key: Key('dispute_release_tech_${ticket.id}'),
                  onPressed: () => _resolveReleasePayout(ticket),
                  child: const Text('Release Tech Payout'),
                );
                if (constraints.maxWidth < 400) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      refundButton,
                      const SizedBox(height: 8),
                      releaseButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: refundButton),
                    const SizedBox(width: 10),
                    Expanded(child: releaseButton),
                  ],
                );
              },
            )
          else if (ticket.resolutionNotes != null)
            Text(
              ticket.resolutionNotes!,
              style: textTheme.bodySmall?.copyWith(
                color: BrandConfig.espresso,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoComparisonTile extends StatelessWidget {
  const _PhotoComparisonTile({
    required this.label,
    required this.url,
    required this.accent,
  });

  final String label;
  final String url;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BrandConfig.bgCream,
        borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.photo_library_outlined, size: 22, color: accent),
          const SizedBox(height: 6),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: BrandConfig.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            url.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
