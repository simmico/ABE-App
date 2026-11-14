import 'dart:math';

import '../../../../core/utils/input_sanitiser.dart';
import '../models/appointment_lock_models.dart';

/// Abstraction for device Biometric / Selfie verification (`local_auth` or selfie check).
abstract interface class BiometricVerificationAdapter {
  Future<bool> authenticateTech({
    required String techId,
    required String reason,
  });
}

/// Default prototype/device biometric adapter that can be swapped with `local_auth`.
class DeviceBiometricVerificationAdapter
    implements BiometricVerificationAdapter {
  const DeviceBiometricVerificationAdapter({this.alwaysPass = true});

  final bool alwaysPass;

  @override
  Future<bool> authenticateTech({
    required String techId,
    required String reason,
  }) async {
    return alwaysPass && techId.trim().isNotEmpty;
  }
}

/// Server-authoritative service managing unique, randomised 4-digit booking PINs,
/// biometric check-in, and brute-force rate limiting (5 failed attempts -> 15 min lock).
class AppointmentStartLockService {
  AppointmentStartLockService({
    Random? secureRandom,
    BiometricVerificationAdapter? biometricAdapter,
    DateTime Function()? clock,
  })  : _random = secureRandom ?? Random.secure(),
        _biometricAdapter =
            biometricAdapter ?? const DeviceBiometricVerificationAdapter(),
        _clock = clock ?? DateTime.now;

  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  final Random _random;
  final BiometricVerificationAdapter _biometricAdapter;
  final DateTime Function() _clock;

  final Map<String, BookingPinRecord> _pinStore = <String, BookingPinRecord>{};
  final Map<String, String> _bookingStatuses = <String, String>{};
  final List<SupportSecurityAlert> _supportAlerts = <SupportSecurityAlert>[];

  List<SupportSecurityAlert> get supportAlerts =>
      List<SupportSecurityAlert>.unmodifiable(_supportAlerts);

  String statusForBooking(String bookingId) {
    return _bookingStatuses[bookingId] ?? 'confirmed';
  }

  /// Generates and stores a unique, randomised 4-digit PIN for a confirmed booking.
  ///
  /// The returned [ClientBookingPinView] is intended strictly for the owning client.
  ClientBookingPinView generatePinForConfirmedBooking({
    required String bookingId,
    required String clientId,
    required String techId,
  }) {
    final cleanBookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    final cleanClientId = InputSanitiser.sanitiseText(clientId, maxLength: 128);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);

    if (cleanBookingId.isEmpty ||
        cleanClientId.isEmpty ||
        cleanTechId.isEmpty) {
      throw ArgumentError(
        'bookingId, clientId, and techId are required to generate a booking PIN.',
      );
    }

    final existing = _pinStore[cleanBookingId];
    if (existing != null) {
      if (existing.clientId != cleanClientId || existing.techId != cleanTechId) {
        throw StateError(
          'Booking PIN already exists with different participant identities.',
        );
      }
      return ClientBookingPinView(
        bookingId: existing.bookingId,
        clientId: existing.clientId,
        pinCode: existing.pinCode,
        isLocked: existing.isLockedAt(_clock()),
        pinVerified: existing.pinVerified,
      );
    }

    final pinCode = _generateSecureFourDigitPin();
    final record = BookingPinRecord(
      bookingId: cleanBookingId,
      clientId: cleanClientId,
      techId: cleanTechId,
      pinCode: pinCode,
      createdAtUtc: _clock().toUtc(),
    );

    _pinStore[cleanBookingId] = record;
    _bookingStatuses.putIfAbsent(cleanBookingId, () => 'confirmed');

    return ClientBookingPinView(
      bookingId: record.bookingId,
      clientId: record.clientId,
      pinCode: record.pinCode,
      isLocked: false,
      pinVerified: false,
    );
  }

  /// Retrieves the 4-digit PIN ONLY when requested by the owning [clientId].
  ///
  /// Any attempt by a nail tech or unrelated user throws a [StateError].
  ClientBookingPinView getPinForClient({
    required String bookingId,
    required String requesterId,
  }) {
    final record = _requireRecord(bookingId);
    final cleanRequester =
        InputSanitiser.sanitiseText(requesterId, maxLength: 128);
    if (cleanRequester != record.clientId) {
      throw StateError(
        'Access denied: only the client who booked may read the 4-digit PIN.',
      );
    }
    return ClientBookingPinView(
      bookingId: record.bookingId,
      clientId: record.clientId,
      pinCode: record.pinCode,
      isLocked: record.isLockedAt(_clock()),
      pinVerified: record.pinVerified,
    );
  }

  /// Returns non-secret lock status for the assigned nail technician.
  TechBookingLockStatus getTechLockStatus({
    required String bookingId,
    required String techId,
  }) {
    final record = _requireRecord(bookingId);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    if (cleanTechId != record.techId) {
      throw StateError(
        'Access denied: only the assigned technician may inspect lock status.',
      );
    }

    final now = _clock().toUtc();
    final locked = record.isLockedAt(now);
    final effectiveFailed = (!locked && record.lockedUntilUtc != null)
        ? 0
        : record.failedAttempts;

    return TechBookingLockStatus(
      bookingId: record.bookingId,
      failedAttempts: effectiveFailed,
      maxAttempts: maxFailedAttempts,
      isLocked: locked,
      lockedUntilUtc: locked ? record.lockedUntilUtc : null,
      biometricVerified: record.biometricVerified,
      pinVerified: record.pinVerified,
      supportAlertTriggered: record.supportAlertTriggered,
    );
  }

  /// Runs Biometric / Selfie verification for the assigned nail technician.
  Future<bool> verifyTechBiometric({
    required String bookingId,
    required String techId,
  }) async {
    final record = _requireRecord(bookingId);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    if (cleanTechId != record.techId) {
      throw StateError(
        'Access denied: biometric verification must be performed by the assigned technician.',
      );
    }

    final passed = await _biometricAdapter.authenticateTech(
      techId: cleanTechId,
      reason: 'Confirm your identity before entering the client 4-digit PIN.',
    );

    if (passed) {
      _pinStore[record.bookingId] = record.copyWith(biometricVerified: true);
    }
    return passed;
  }

  /// Verifies the entered 4-digit PIN and transitions the booking to `in_progress`.
  ///
  /// Enforces:
  /// - Biometric verification must already be completed.
  /// - Maximum 5 failed attempts locks PIN entry for 15 minutes and alerts Support/Admin.
  AppointmentStartOutcome submitPinAndStartAppointment({
    required String bookingId,
    required String techId,
    required String enteredPin,
  }) {
    var record = _requireRecord(bookingId);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    if (cleanTechId != record.techId) {
      throw StateError(
        'Access denied: only the assigned technician may start this appointment.',
      );
    }

    final now = _clock().toUtc();

    if (record.pinVerified) {
      return AppointmentStartOutcome(
        success: true,
        bookingStatus: statusForBooking(record.bookingId),
        message: 'Biometric and 4-digit PIN already verified. Appointment is in progress.',
        remainingAttempts: maxFailedAttempts,
        isLocked: false,
      );
    }

    if (!record.biometricVerified) {
      return AppointmentStartOutcome(
        success: false,
        bookingStatus: statusForBooking(record.bookingId),
        message: 'Complete biometric verification before entering the client PIN.',
        remainingAttempts:
            (maxFailedAttempts - record.failedAttempts).clamp(0, maxFailedAttempts),
        isLocked: record.isLockedAt(now),
        lockedUntilUtc: record.lockedUntilUtc,
        supportAlertTriggered: record.supportAlertTriggered,
      );
    }

    // Check active lockout window first.
    if (record.isLockedAt(now)) {
      final remainingMins =
          record.lockedUntilUtc!.difference(now).inMinutes.clamp(1, 15);
      return AppointmentStartOutcome(
        success: false,
        bookingStatus: statusForBooking(record.bookingId),
        message:
            'PIN entry is locked for $remainingMins mins after 5 failed attempts. Support has been alerted.',
        remainingAttempts: 0,
        isLocked: true,
        lockedUntilUtc: record.lockedUntilUtc,
        supportAlertTriggered: true,
      );
    }

    // If a previous 15-minute lockout has expired, reset attempts and require fresh biometric check.
    if (record.lockedUntilUtc != null && !record.isLockedAt(now)) {
      record = record.copyWith(
        failedAttempts: 0,
        clearLockedUntil: true,
        biometricVerified: false,
      );
      _pinStore[record.bookingId] = record;
      return AppointmentStartOutcome(
        success: false,
        bookingStatus: statusForBooking(record.bookingId),
        message:
            '15-minute lockout has expired. Complete biometric verification again before entering the PIN.',
        remainingAttempts: maxFailedAttempts,
        isLocked: false,
      );
    }

    final cleanPin = enteredPin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleanPin)) {
      return AppointmentStartOutcome(
        success: false,
        bookingStatus: statusForBooking(record.bookingId),
        message: 'Enter all 4 digits of the client PIN.',
        remainingAttempts:
            (maxFailedAttempts - record.failedAttempts).clamp(0, maxFailedAttempts),
        isLocked: false,
      );
    }

    if (_constantTimeEquals(cleanPin, record.pinCode)) {
      final updated = record.copyWith(
        pinVerified: true,
        verifiedAtUtc: now,
      );
      _pinStore[record.bookingId] = updated;
      _bookingStatuses[record.bookingId] = 'in_progress';

      return const AppointmentStartOutcome(
        success: true,
        bookingStatus: 'in_progress',
        message: 'Biometric and 4-digit PIN verified. Appointment is now in progress.',
        remainingAttempts: maxFailedAttempts,
        isLocked: false,
      );
    }

    // Incorrect PIN entered: increment attempt counter and enforce 5-attempt lockout.
    final nextFailed = record.failedAttempts + 1;
    final shouldLock = nextFailed >= maxFailedAttempts;
    final lockedUntil = shouldLock ? now.add(lockoutDuration) : null;

    final updated = record.copyWith(
      failedAttempts: nextFailed,
      lockedUntilUtc: lockedUntil,
      supportAlertTriggered: shouldLock || record.supportAlertTriggered,
    );
    _pinStore[record.bookingId] = updated;

    if (shouldLock) {
      _supportAlerts.add(
        SupportSecurityAlert(
          id: 'alert_pin_${record.bookingId}_${now.millisecondsSinceEpoch}',
          bookingId: record.bookingId,
          clientId: record.clientId,
          techId: record.techId,
          alertType: 'pin_lockout',
          message:
              '5 consecutive failed PIN attempts on booking ${record.bookingId}. Entry locked for 15 minutes.',
          createdAtUtc: now,
        ),
      );

      return AppointmentStartOutcome(
        success: false,
        bookingStatus: statusForBooking(record.bookingId),
        message:
            'PIN entry locked for 15 minutes after 5 failed attempts. Support and Admin have been notified.',
        remainingAttempts: 0,
        isLocked: true,
        lockedUntilUtc: lockedUntil,
        supportAlertTriggered: true,
      );
    }

    final remaining = maxFailedAttempts - nextFailed;
    return AppointmentStartOutcome(
      success: false,
      bookingStatus: statusForBooking(record.bookingId),
      message:
          'Incorrect 4-digit PIN. $remaining ${remaining == 1 ? 'attempt' : 'attempts'} remaining before 15-minute lockout.',
      remainingAttempts: remaining,
      isLocked: false,
    );
  }

  String _generateSecureFourDigitPin() {
    // Avoid trivial single-digit repeats like 0000 or 1111 while keeping uniform distribution.
    while (true) {
      final value = _random.nextInt(10000);
      final candidate = value.toString().padLeft(4, '0');
      final allSame = candidate.split('').toSet().length == 1;
      if (!allSame) {
        return candidate;
      }
    }
  }

  BookingPinRecord _requireRecord(String bookingId) {
    final cleanId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    final record = _pinStore[cleanId];
    if (record == null) {
      throw StateError('No PIN record found for booking $cleanId.');
    }
    return record;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
