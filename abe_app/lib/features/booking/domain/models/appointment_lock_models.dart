import '../../../../core/utils/input_sanitiser.dart';

/// Server-side 4-digit PIN record stored in `booking_pins/{bookingId}`.
///
/// Strictly readable ONLY by the client who owns the booking (`clientId`),
/// never exposed to the nail technician via client-side queries.
class BookingPinRecord {
  BookingPinRecord({
    required String bookingId,
    required String clientId,
    required String techId,
    required String pinCode,
    int failedAttempts = 0,
    this.lockedUntilUtc,
    this.supportAlertTriggered = false,
    this.biometricVerified = false,
    this.pinVerified = false,
    this.verifiedAtUtc,
    DateTime? createdAtUtc,
  })  : bookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128),
        clientId = InputSanitiser.sanitiseText(clientId, maxLength: 128),
        techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        pinCode = _validatePinFormat(pinCode),
        failedAttempts = InputSanitiser.requireNonNegativeInt(
          failedAttempts,
          fieldName: 'failedAttempts',
        ),
        createdAtUtc = (createdAtUtc ?? DateTime.now()).toUtc() {
    if (this.bookingId.isEmpty ||
        this.clientId.isEmpty ||
        this.techId.isEmpty) {
      throw ArgumentError(
        'BookingPinRecord requires non-empty bookingId, clientId, and techId.',
      );
    }
  }

  final String bookingId;
  final String clientId;
  final String techId;
  final String pinCode;
  final int failedAttempts;
  final DateTime? lockedUntilUtc;
  final bool supportAlertTriggered;
  final bool biometricVerified;
  final bool pinVerified;
  final DateTime? verifiedAtUtc;
  final DateTime createdAtUtc;

  static String _validatePinFormat(String rawPin) {
    final trimmed = rawPin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      throw ArgumentError.value(
        rawPin,
        'pinCode',
        'Booking PIN must be exactly 4 numeric digits.',
      );
    }
    return trimmed;
  }

  bool isLockedAt(DateTime now) {
    final lockedUntil = lockedUntilUtc;
    if (lockedUntil == null) return false;
    return now.toUtc().isBefore(lockedUntil);
  }

  BookingPinRecord copyWith({
    int? failedAttempts,
    DateTime? lockedUntilUtc,
    bool clearLockedUntil = false,
    bool? supportAlertTriggered,
    bool? biometricVerified,
    bool? pinVerified,
    DateTime? verifiedAtUtc,
  }) {
    return BookingPinRecord(
      bookingId: bookingId,
      clientId: clientId,
      techId: techId,
      pinCode: pinCode,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntilUtc:
          clearLockedUntil ? null : (lockedUntilUtc ?? this.lockedUntilUtc),
      supportAlertTriggered:
          supportAlertTriggered ?? this.supportAlertTriggered,
      biometricVerified: biometricVerified ?? this.biometricVerified,
      pinVerified: pinVerified ?? this.pinVerified,
      verifiedAtUtc: verifiedAtUtc ?? this.verifiedAtUtc,
      createdAtUtc: createdAtUtc,
    );
  }

  Map<String, dynamic> toServerStorageJson() {
    return <String, dynamic>{
      'bookingId': bookingId,
      'clientId': clientId,
      'techId': techId,
      'pinCode': pinCode,
      'failedAttempts': failedAttempts,
      if (lockedUntilUtc != null)
        'lockedUntilIso': lockedUntilUtc!.toUtc().toIso8601String(),
      'supportAlertTriggered': supportAlertTriggered,
      'biometricVerified': biometricVerified,
      'pinVerified': pinVerified,
      if (verifiedAtUtc != null)
        'verifiedAtIso': verifiedAtUtc!.toUtc().toIso8601String(),
      'createdAtIso': createdAtUtc.toIso8601String(),
    };
  }
}

/// Client-only view of the booking PIN returned to the booking owner.
class ClientBookingPinView {
  const ClientBookingPinView({
    required this.bookingId,
    required this.clientId,
    required this.pinCode,
    required this.isLocked,
    required this.pinVerified,
  });

  final String bookingId;
  final String clientId;
  final String pinCode;
  final bool isLocked;
  final bool pinVerified;
}

/// Non-secret status visible to the assigned technician (never includes `pinCode`).
class TechBookingLockStatus {
  const TechBookingLockStatus({
    required this.bookingId,
    required this.failedAttempts,
    required this.maxAttempts,
    required this.isLocked,
    required this.lockedUntilUtc,
    required this.biometricVerified,
    required this.pinVerified,
    required this.supportAlertTriggered,
  });

  final String bookingId;
  final int failedAttempts;
  final int maxAttempts;
  final bool isLocked;
  final DateTime? lockedUntilUtc;
  final bool biometricVerified;
  final bool pinVerified;
  final bool supportAlertTriggered;

  int get remainingAttempts =>
      (maxAttempts - failedAttempts).clamp(0, maxAttempts);
}

/// Security alert raised to Support / Admin when brute-force PIN entry triggers a 15-minute lockout.
class SupportSecurityAlert {
  SupportSecurityAlert({
    required String id,
    required String bookingId,
    required String clientId,
    required String techId,
    required String alertType,
    required String message,
    required DateTime createdAtUtc,
    this.isResolved = false,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        bookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128),
        clientId = InputSanitiser.sanitiseText(clientId, maxLength: 128),
        techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        alertType = InputSanitiser.sanitiseText(alertType, maxLength: 64),
        message = InputSanitiser.sanitiseText(message, maxLength: 400),
        createdAtUtc = createdAtUtc.toUtc() {
    if (this.id.isEmpty ||
        this.bookingId.isEmpty ||
        this.clientId.isEmpty ||
        this.techId.isEmpty ||
        this.alertType.isEmpty ||
        this.message.isEmpty) {
      throw ArgumentError(
        'SupportSecurityAlert requires non-empty id, bookingId, clientId, techId, alertType, and message.',
      );
    }
  }

  final String id;
  final String bookingId;
  final String clientId;
  final String techId;
  final String alertType;
  final String message;
  final DateTime createdAtUtc;
  final bool isResolved;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookingId': bookingId,
      'clientId': clientId,
      'techId': techId,
      'alertType': alertType,
      'message': message,
      'createdAtIso': createdAtUtc.toIso8601String(),
      'isResolved': isResolved,
    };
  }
}

/// Outcome returned when attempting to start an appointment via Biometric + 4-Digit PIN.
class AppointmentStartOutcome {
  const AppointmentStartOutcome({
    required this.success,
    required this.bookingStatus,
    required this.message,
    required this.remainingAttempts,
    required this.isLocked,
    this.lockedUntilUtc,
    this.supportAlertTriggered = false,
  });

  final bool success;
  final String bookingStatus;
  final String message;
  final int remainingAttempts;
  final bool isLocked;
  final DateTime? lockedUntilUtc;
  final bool supportAlertTriggered;
}
