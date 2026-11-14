import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/services/appointment_completion_lock_service.dart';

/// Appointment Completion Lock screen for Nail Technicians.
///
/// Strictly enforces live in-app camera capture (`ImageSource.camera` only,
/// zero gallery upload option) of the finished nails before a booking can
/// transition from `in_progress` to `completed` and unlock earnings.
/// Supports local encrypted queue fallback when salon cell signal drops.
class TechCompleteAppointmentScreen extends StatefulWidget {
  const TechCompleteAppointmentScreen({
    super.key,
    required this.bookingId,
    required this.techId,
    required this.clientName,
    required this.lookTitle,
    required this.netEarningsZar,
    required this.completionService,
    this.onAppointmentCompleted,
    this.onBack,
  });

  final String bookingId;
  final String techId;
  final String clientName;
  final String lookTitle;
  final int netEarningsZar;
  final AppointmentCompletionLockService completionService;
  final void Function(AppointmentCompletionOutcome outcome)?
      onAppointmentCompleted;
  final VoidCallback? onBack;

  @override
  State<TechCompleteAppointmentScreen> createState() =>
      _TechCompleteAppointmentScreenState();
}

class _TechCompleteAppointmentScreenState
    extends State<TechCompleteAppointmentScreen> {
  LiveCapturedNailPhoto? _capturedPhoto;
  AppointmentCompletionOutcome? _lastOutcome;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleLiveCameraCapture() async {
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final captured =
          await widget.completionService.captureLiveCompletionPhoto(
        bookingId: widget.bookingId,
        techId: widget.techId,
      );

      if (!mounted) return;
      setState(() {
        if (captured == null) {
          _errorMessage =
              'Live camera capture was cancelled. Take a live photo of the finished nails to continue.';
        } else {
          _capturedPhoto = captured;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to access live camera right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _handleSubmitCompletion() async {
    final photo = _capturedPhoto;
    if (photo == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final outcome = await widget.completionService.submitLiveCompletionPhoto(
        bookingId: widget.bookingId,
        techId: widget.techId,
        photo: photo,
      );
      if (!mounted) return;
      setState(() {
        _lastOutcome = outcome;
      });
      if (outcome.completed) {
        widget.onAppointmentCompleted?.call(outcome);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not complete booking. Confirm the appointment is in progress and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleFlushOfflineQueue() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final outcomes = await widget.completionService.flushOfflineQueue();
      if (!mounted) return;

      final matching = outcomes.where(
        (o) =>
            o.bookingStatus == 'completed' ||
            widget.completionService.statusForBooking(widget.bookingId) ==
                'completed',
      );
      final selected = matching.isNotEmpty
          ? matching.first
          : (outcomes.isNotEmpty ? outcomes.last : null);
      setState(() {
        if (selected != null) {
          _lastOutcome = selected;
        }
      });

      if (selected != null && selected.completed) {
        widget.onAppointmentCompleted?.call(selected);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not sync queued live photo yet. Please try again once signal improves.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pendingQueue = widget.completionService.offlineQueue.pendingItems;
    final isCompleted =
        widget.completionService.statusForBooking(widget.bookingId) ==
            'completed';

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('complete_appointment_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Complete Appointment'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: <Widget>[
            _buildSummaryCard(textTheme),
            const SizedBox(height: 16),
            _buildCameraLockCard(textTheme, isCompleted),
            if (pendingQueue.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _buildOfflineQueueCard(textTheme, pendingQueue.length),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('completion_error_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BrandConfig.errorSoft,
                    borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
                    border: Border.all(color: BrandConfig.errorTerracotta),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandConfig.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            if (_lastOutcome != null) ...<Widget>[
              const SizedBox(height: 14),
              _buildOutcomeBanner(textTheme, _lastOutcome!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(TextTheme textTheme) {
    return Container(
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
                child: Text(
                  'Live Camera Lock',
                  style: textTheme.labelMedium?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandConfig.sageSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
                child: Text(
                  'Net Payout: R${widget.netEarningsZar}',
                  style: textTheme.labelLarge?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.lookTitle, style: textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Client: ${widget.clientName} • Booking ${widget.bookingId}',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLockCard(TextTheme textTheme, bool isCompleted) {
    final hasPhoto = _capturedPhoto != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(
          color: isCompleted ? BrandConfig.sageSuccess : BrandConfig.borderWarm,
        ),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Finished Nails Proof (Live Camera Only)',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Gallery uploads are disabled. Capture a live in-app photo of the finished set to complete this booking and unlock your payout.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Container(
            key: const Key('live_camera_viewfinder_frame'),
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasPhoto ? BrandConfig.blushSoft : BrandConfig.bgCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasPhoto
                    ? BrandConfig.rosePrimary
                    : BrandConfig.borderWarm,
                width: 1.4,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  hasPhoto
                      ? Icons.check_circle_outline_rounded
                      : Icons.photo_camera_outlined,
                  size: 42,
                  color: hasPhoto
                      ? BrandConfig.sageSuccess
                      : BrandConfig.roseDark,
                ),
                const SizedBox(height: 10),
                Text(
                  hasPhoto
                      ? 'Live Camera Photo Ready'
                      : 'Native In-App Camera Viewfinder',
                  style: textTheme.titleMedium?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPhoto
                      ? 'Source: camera • ${_capturedPhoto!.localCaptureId}'
                      : 'Live Camera Only • Gallery Upload Disabled',
                  style: textTheme.bodySmall?.copyWith(
                    color: BrandConfig.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('capture_live_photo_button'),
              onPressed:
                  (_isCapturing || isCompleted) ? null : _handleLiveCameraCapture,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(
                _isCapturing
                    ? 'Opening Live Camera...'
                    : hasPhoto
                        ? 'Retake Live Camera Photo'
                        : 'Take Live Nail Photo',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('submit_completion_photo_button'),
              onPressed: (hasPhoto && !_isSubmitting && !isCompleted)
                  ? _handleSubmitCompletion
                  : null,
              icon: const Icon(Icons.verified_outlined),
              label: Text(
                isCompleted
                    ? 'Booking Completed & Payout Unlocked'
                    : _isSubmitting
                        ? 'Submitting Live Proof...'
                        : 'Complete Appointment & Unlock Payout',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineQueueCard(TextTheme textTheme, int pendingCount) {
    return Container(
      key: const Key('offline_queue_banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandConfig.champagneSoft,
        borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
        border: Border.all(color: BrandConfig.champagne),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Encrypted Offline Queue ($pendingCount pending)',
            style: textTheme.titleSmall?.copyWith(
              color: BrandConfig.espresso,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live photo saved securely with capture timestamp. Sync when salon signal returns to release payout.',
            style: textTheme.bodySmall?.copyWith(color: BrandConfig.textMuted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('flush_offline_queue_button'),
              onPressed: _isSubmitting ? null : _handleFlushOfflineQueue,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Sync Queued Live Photo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeBanner(
    TextTheme textTheme,
    AppointmentCompletionOutcome outcome,
  ) {
    final isSuccess = outcome.completed;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('completion_outcome_banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSuccess ? BrandConfig.sageSoft : BrandConfig.blushSoft,
          borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
          border: Border.all(
            color: isSuccess ? BrandConfig.sageSuccess : BrandConfig.champagne,
          ),
        ),
        child: Text(
          outcome.message,
          style: textTheme.bodySmall?.copyWith(
            color: BrandConfig.espresso,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
