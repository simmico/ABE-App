import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/models/appointment_lock_models.dart';
import '../../domain/services/appointment_start_lock_service.dart';

/// Appointment Start Security Lock screen for Nail Technicians.
///
/// Enforces the two-factor start invariant:
/// 1. Device Biometric / Selfie verification (`local_auth` adapter), AND
/// 2. Client's randomised 4-digit booking PIN (rate-limited to 5 failed attempts,
///    then locked for 15 minutes with Support/Admin alert).
class TechStartAppointmentScreen extends StatefulWidget {
  const TechStartAppointmentScreen({
    super.key,
    required this.bookingId,
    required this.techId,
    required this.clientName,
    required this.lookTitle,
    required this.venueName,
    required this.priceZar,
    required this.durationMinutes,
    required this.lockService,
    this.onAppointmentStarted,
    this.onBack,
  });

  final String bookingId;
  final String techId;
  final String clientName;
  final String lookTitle;
  final String venueName;
  final int priceZar;
  final int durationMinutes;
  final AppointmentStartLockService lockService;
  final void Function(AppointmentStartOutcome outcome)? onAppointmentStarted;
  final VoidCallback? onBack;

  @override
  State<TechStartAppointmentScreen> createState() =>
      _TechStartAppointmentScreenState();
}

class _TechStartAppointmentScreenState
    extends State<TechStartAppointmentScreen> {
  String _enteredPin = '';
  bool _isVerifyingBiometric = false;
  late TechBookingLockStatus _status;
  AppointmentStartOutcome? _lastOutcome;
  String? _biometricError;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  void _refreshStatus() {
    _status = widget.lockService.getTechLockStatus(
      bookingId: widget.bookingId,
      techId: widget.techId,
    );
  }

  Future<void> _handleBiometricCheck() async {
    setState(() {
      _isVerifyingBiometric = true;
      _biometricError = null;
    });

    try {
      final passed = await widget.lockService.verifyTechBiometric(
        bookingId: widget.bookingId,
        techId: widget.techId,
      );

      if (!mounted) return;
      setState(() {
        _refreshStatus();
        if (!passed) {
          _biometricError =
              'Biometric check did not pass. Please verify FaceID, fingerprint, or selfie again.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _biometricError =
            'Biometric verification failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingBiometric = false;
        });
      }
    }
  }

  void _appendDigit(String digit) {
    if (_status.isLocked || !_status.biometricVerified || _status.pinVerified) {
      return;
    }
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
    });
  }

  void _backspaceDigit() {
    if (_enteredPin.isEmpty || _status.isLocked || _status.pinVerified) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _clearPin() {
    if (_status.isLocked || _status.pinVerified) return;
    setState(() {
      _enteredPin = '';
    });
  }

  void _submitPin() {
    final outcome = widget.lockService.submitPinAndStartAppointment(
      bookingId: widget.bookingId,
      techId: widget.techId,
      enteredPin: _enteredPin,
    );

    setState(() {
      _lastOutcome = outcome;
      _refreshStatus();
      if (!outcome.success) {
        _enteredPin = '';
      }
    });

    if (outcome.success) {
      widget.onAppointmentStarted?.call(outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canTypePin =
        _status.biometricVerified && !_status.isLocked && !_status.pinVerified;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                key: const Key('start_appointment_back_button'),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Appointment Check-In'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: <Widget>[
            _buildBookingSummaryCard(textTheme),
            const SizedBox(height: 16),
            _buildBiometricStepCard(textTheme),
            const SizedBox(height: 16),
            _buildPinLockCard(textTheme, canTypePin),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummaryCard(TextTheme textTheme) {
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
                  'Visual Contract',
                  style: textTheme.labelMedium?.copyWith(
                    color: BrandConfig.roseDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'R${widget.priceZar} • ${widget.durationMinutes} mins',
                style: textTheme.labelLarge?.copyWith(
                  color: BrandConfig.espresso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.lookTitle,
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Client: ${widget.clientName} • ${widget.venueName}',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricStepCard(TextTheme textTheme) {
    final verified = _status.biometricVerified;

    return Container(
      key: const Key('biometric_step_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(
          color: verified ? BrandConfig.sageSuccess : BrandConfig.borderWarm,
          width: verified ? 1.4 : 1,
        ),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                verified
                    ? Icons.verified_user_rounded
                    : Icons.fingerprint_rounded,
                color: verified
                    ? BrandConfig.sageSuccess
                    : BrandConfig.rosePrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Step 1: Biometric Verification',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: verified
                      ? BrandConfig.sageSoft
                      : BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.pillRadius),
                ),
                child: Text(
                  verified ? 'Verified' : 'Required',
                  style: textTheme.labelMedium?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verified
                ? 'Technician identity confirmed for this venue booking.'
                : 'Confirm your identity with FaceID, fingerprint, or live selfie before entering the client PIN.',
            style: textTheme.bodyMedium,
          ),
          if (_biometricError != null) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _biometricError!,
                style: textTheme.bodySmall?.copyWith(
                  color: BrandConfig.errorTerracotta,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (!verified) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('start_biometric_button'),
                onPressed: _isVerifyingBiometric ? null : _handleBiometricCheck,
                icon: const Icon(Icons.face_retouching_natural_rounded),
                label: Text(
                  _isVerifyingBiometric
                      ? 'Verifying Identity...'
                      : 'Verify Biometric / Selfie',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinLockCard(TextTheme textTheme, bool canTypePin) {
    final isLocked = _status.isLocked;
    final pinVerified = _status.pinVerified;

    return Container(
      key: const Key('pin_step_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(
          color: pinVerified
              ? BrandConfig.sageSuccess
              : isLocked
                  ? BrandConfig.errorTerracotta
                  : BrandConfig.borderWarm,
        ),
        boxShadow: BrandConfig.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                pinVerified
                    ? Icons.lock_open_rounded
                    : Icons.pin_outlined,
                color: pinVerified
                    ? BrandConfig.sageSuccess
                    : isLocked
                        ? BrandConfig.errorTerracotta
                        : BrandConfig.espresso,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Step 2: Client 4-Digit Booking PIN',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ask the client for the 4-digit PIN displayed on their ABE booking screen. No PIN means no payout.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Semantics(
            label: pinVerified
                ? '4-digit client PIN verified'
                : '${_enteredPin.length} of 4 PIN digits entered',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List<Widget>.generate(4, (index) {
                  final hasDigit = index < _enteredPin.length;
                  final char = pinVerified
                      ? '✓'
                      : hasDigit
                          ? _enteredPin[index]
                          : '';
                  return Container(
                    key: Key('pin_box_$index'),
                    width: 56,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pinVerified
                          ? BrandConfig.sageSoft
                          : hasDigit
                              ? BrandConfig.blushSoft
                              : BrandConfig.bgCream,
                      borderRadius:
                          BorderRadius.circular(BrandConfig.inputRadius),
                      border: Border.all(
                        color: pinVerified
                            ? BrandConfig.sageSuccess
                            : hasDigit
                                ? BrandConfig.rosePrimary
                                : BrandConfig.borderWarm,
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      char,
                      style: textTheme.displaySmall?.copyWith(
                        fontFamily: BrandConfig.bodyFontFamily,
                        fontWeight: FontWeight.w700,
                        color: BrandConfig.espresso,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isLocked)
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('pin_lockout_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BrandConfig.errorSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
                  border: Border.all(color: BrandConfig.errorTerracotta),
                ),
                child: Text(
                  'PIN entry is locked for 15 minutes after 5 failed attempts. Support and Admin have been notified.',
                  style: textTheme.bodySmall?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else if (_lastOutcome != null)
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('pin_outcome_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastOutcome!.success
                      ? BrandConfig.sageSoft
                      : BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
                  border: Border.all(
                    color: _lastOutcome!.success
                        ? BrandConfig.sageSuccess
                        : BrandConfig.rosePrimary,
                  ),
                ),
                child: Text(
                  _lastOutcome!.message,
                  style: textTheme.bodySmall?.copyWith(
                    color: BrandConfig.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Text(
              'Attempts remaining before 15-minute lockout: ${_status.remainingAttempts} of ${_status.maxAttempts}',
              style: textTheme.bodySmall?.copyWith(
                color: BrandConfig.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 14),
          _buildNumericKeypad(canTypePin),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('start_appointment_submit_button'),
              onPressed: canTypePin && _enteredPin.length == 4
                  ? _submitPin
                  : null,
              child: Text(
                pinVerified
                    ? 'Appointment In Progress'
                    : 'Verify PIN & Start Appointment',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad(bool enabled) {
    Widget digitButton(String digit) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: OutlinedButton(
            key: Key('pin_digit_$digit'),
            onPressed: enabled ? () => _appendDigit(digit) : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              backgroundColor: BrandConfig.bgCream,
            ),
            child: Text(
              digit,
              style: const TextStyle(
                fontFamily: BrandConfig.bodyFontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            digitButton('1'),
            digitButton('2'),
            digitButton('3'),
          ],
        ),
        Row(
          children: <Widget>[
            digitButton('4'),
            digitButton('5'),
            digitButton('6'),
          ],
        ),
        Row(
          children: <Widget>[
            digitButton('7'),
            digitButton('8'),
            digitButton('9'),
          ],
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: OutlinedButton(
                  key: const Key('pin_clear_button'),
                  onPressed: enabled ? _clearPin : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    backgroundColor: BrandConfig.bgCream,
                  ),
                  child: const Text('Clear'),
                ),
              ),
            ),
            digitButton('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Semantics(
                  label: 'Delete digit',
                  button: true,
                  excludeSemantics: true,
                  child: OutlinedButton(
                    key: const Key('pin_backspace_button'),
                    onPressed: enabled ? _backspaceDigit : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 52),
                      backgroundColor: BrandConfig.bgCream,
                    ),
                    child: const Icon(Icons.backspace_outlined, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
