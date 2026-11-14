import '../../../../core/utils/input_sanitiser.dart';

/// Foundation schema for the 3-Photo Dispute Resolution Ticket.
///
/// Compares side-by-side:
/// 1. [portfolioPhotoUrl] (The booked Visual Contract look),
/// 2. [techLiveCompletionPhotoUrl] (The tech's in-app live camera completion photo),
/// 3. [clientComplaintPhotoUrl] (The client's submitted dispute photo).
class DisputeTicket {
  DisputeTicket({
    required String id,
    required String bookingId,
    required String clientId,
    required String techId,
    required String portfolioPhotoUrl,
    required String techLiveCompletionPhotoUrl,
    required String clientComplaintPhotoUrl,
    required String clientReason,
    String status = 'open',
    String? resolutionNotes,
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        bookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128),
        clientId = InputSanitiser.sanitiseText(clientId, maxLength: 128),
        techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        portfolioPhotoUrl =
            InputSanitiser.sanitiseText(portfolioPhotoUrl, maxLength: 500),
        techLiveCompletionPhotoUrl = InputSanitiser.sanitiseText(
          techLiveCompletionPhotoUrl,
          maxLength: 500,
        ),
        clientComplaintPhotoUrl = InputSanitiser.sanitiseText(
          clientComplaintPhotoUrl,
          maxLength: 500,
        ),
        clientReason = InputSanitiser.sanitiseText(clientReason, maxLength: 800),
        status = InputSanitiser.sanitiseText(status, maxLength: 40),
        resolutionNotes = resolutionNotes != null
            ? InputSanitiser.sanitiseText(resolutionNotes, maxLength: 800)
            : null {
    if (this.id.isEmpty || this.bookingId.isEmpty) {
      throw ArgumentError('DisputeTicket id and bookingId cannot be empty.');
    }
  }

  final String id;
  final String bookingId;
  final String clientId;
  final String techId;
  final String portfolioPhotoUrl;
  final String techLiveCompletionPhotoUrl;
  final String clientComplaintPhotoUrl;
  final String clientReason;
  final String status;
  final String? resolutionNotes;

  factory DisputeTicket.fromJson(Map<String, dynamic> json) {
    return DisputeTicket(
      id: (json['id'] ?? '').toString(),
      bookingId: (json['bookingId'] ?? '').toString(),
      clientId: (json['clientId'] ?? '').toString(),
      techId: (json['techId'] ?? '').toString(),
      portfolioPhotoUrl: (json['portfolioPhotoUrl'] ?? '').toString(),
      techLiveCompletionPhotoUrl:
          (json['techLiveCompletionPhotoUrl'] ?? '').toString(),
      clientComplaintPhotoUrl:
          (json['clientComplaintPhotoUrl'] ?? '').toString(),
      clientReason: (json['clientReason'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      resolutionNotes: json['resolutionNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookingId': bookingId,
      'clientId': clientId,
      'techId': techId,
      'portfolioPhotoUrl': portfolioPhotoUrl,
      'techLiveCompletionPhotoUrl': techLiveCompletionPhotoUrl,
      'clientComplaintPhotoUrl': clientComplaintPhotoUrl,
      'clientReason': clientReason,
      'status': status,
      if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
    };
  }
}

/// Immutable audit log entry recorded whenever an admin, support agent, or
/// warehouse supplier executes a privileged action.
class StaffAuditLog {
  StaffAuditLog({
    required String id,
    required String actorId,
    required String actorUacGroup,
    required String action,
    required String targetId,
    required String timestampIso,
    String notes = '',
  })  : id = InputSanitiser.sanitiseText(id, maxLength: 128),
        actorId = InputSanitiser.sanitiseText(actorId, maxLength: 128),
        actorUacGroup =
            InputSanitiser.sanitiseText(actorUacGroup, maxLength: 64),
        action = InputSanitiser.sanitiseText(action, maxLength: 120),
        targetId = InputSanitiser.sanitiseText(targetId, maxLength: 128),
        timestampIso = InputSanitiser.sanitiseText(timestampIso, maxLength: 64),
        notes = InputSanitiser.sanitiseText(notes, maxLength: 500) {
    if (this.id.isEmpty ||
        this.actorId.isEmpty ||
        this.action.isEmpty ||
        this.targetId.isEmpty) {
      throw ArgumentError(
        'StaffAuditLog requires non-empty id, actorId, action, and targetId.',
      );
    }
  }

  final String id;
  final String actorId;
  final String actorUacGroup;
  final String action;
  final String targetId;
  final String timestampIso;
  final String notes;

  factory StaffAuditLog.fromJson(Map<String, dynamic> json) {
    return StaffAuditLog(
      id: (json['id'] ?? '').toString(),
      actorId: (json['actorId'] ?? '').toString(),
      actorUacGroup: (json['actorUacGroup'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      targetId: (json['targetId'] ?? '').toString(),
      timestampIso: (json['timestampIso'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'actorId': actorId,
      'actorUacGroup': actorUacGroup,
      'action': action,
      'targetId': targetId,
      'timestampIso': timestampIso,
      'notes': notes,
    };
  }
}
