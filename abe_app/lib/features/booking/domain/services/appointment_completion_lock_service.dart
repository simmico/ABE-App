import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../../../core/utils/input_sanitiser.dart';

/// Strict capture source enforcing `ImageSource.camera` only.
enum LiveCaptureSource {
  camera('camera');

  const LiveCaptureSource(this.code);
  final String code;

  /// Parses a raw source string and rejects any non-camera source (such as `gallery`).
  static LiveCaptureSource requireCamera(String rawSource) {
    final normalised =
        InputSanitiser.sanitiseText(rawSource, maxLength: 32).toLowerCase();
    if (normalised != 'camera') {
      throw ArgumentError.value(
        rawSource,
        'rawSource',
        'Live Completion Lock: gallery and file uploads are strictly disabled; only camera capture is permitted.',
      );
    }
    return LiveCaptureSource.camera;
  }
}

/// Captured live photo metadata produced exclusively by the device camera.
class LiveCapturedNailPhoto {
  LiveCapturedNailPhoto({
    required String localCaptureId,
    required String rawImageBytesBase64,
    required DateTime capturedAtUtc,
    String source = 'camera',
  })  : localCaptureId =
            InputSanitiser.sanitiseText(localCaptureId, maxLength: 128),
        rawImageBytesBase64 = rawImageBytesBase64.trim(),
        capturedAtUtc = capturedAtUtc.toUtc(),
        source = LiveCaptureSource.requireCamera(source) {
    if (this.localCaptureId.isEmpty || this.rawImageBytesBase64.isEmpty) {
      throw ArgumentError(
        'LiveCapturedNailPhoto requires non-empty localCaptureId and image data.',
      );
    }
  }

  final String localCaptureId;
  final String rawImageBytesBase64;
  final DateTime capturedAtUtc;
  final LiveCaptureSource source;
}

/// Device camera adapter interface (must open native `ImageSource.camera` only).
abstract interface class LiveCameraCaptureAdapter {
  Future<LiveCapturedNailPhoto?> captureFromLiveCamera({
    required String bookingId,
    required String techId,
  });
}

/// Default prototype camera adapter simulating `ImageSource.camera` capture.
class DeviceLiveCameraAdapter implements LiveCameraCaptureAdapter {
  const DeviceLiveCameraAdapter({this.shouldReturnNull = false});

  final bool shouldReturnNull;

  @override
  Future<LiveCapturedNailPhoto?> captureFromLiveCamera({
    required String bookingId,
    required String techId,
  }) async {
    if (shouldReturnNull) return null;
    final cleanBooking = InputSanitiser.sanitiseText(bookingId, maxLength: 64);
    final now = DateTime.now().toUtc();
    final samplePayload = base64Encode(
      utf8.encode(
        'ABE_LIVE_CAM:$cleanBooking:${now.toIso8601String()}',
      ),
    );
    return LiveCapturedNailPhoto(
      localCaptureId: 'cam_${cleanBooking}_${now.millisecondsSinceEpoch}',
      rawImageBytesBase64: samplePayload,
      capturedAtUtc: now,
      source: 'camera',
    );
  }
}

/// Upload gateway interface for live completion photos.
abstract interface class CompletionPhotoUploadGateway {
  Future<String> uploadLivePhoto({
    required String bookingId,
    required String techId,
    required LiveCapturedNailPhoto photo,
  });
}

/// Default prototype upload gateway supporting online/offline simulation.
class SimulatedCompletionPhotoUploadGateway
    implements CompletionPhotoUploadGateway {
  SimulatedCompletionPhotoUploadGateway({this.isOnline = true});

  bool isOnline;

  @override
  Future<String> uploadLivePhoto({
    required String bookingId,
    required String techId,
    required LiveCapturedNailPhoto photo,
  }) async {
    if (!isOnline) {
      throw StateError('Salon cellular signal unavailable; upload deferred.');
    }
    LiveCaptureSource.requireCamera(photo.source.code);
    return 'https://storage.abe.co.za/completions/${bookingId}_${photo.localCaptureId}.jpg';
  }
}

/// Encrypted offline queue record stored locally if salon cell signal drops.
class QueuedOfflineCompletionPhoto {
  const QueuedOfflineCompletionPhoto({
    required this.queueId,
    required this.bookingId,
    required this.techId,
    required this.encryptedPayloadBase64,
    required this.integrityTag,
    required this.capturedAtUtc,
    required this.source,
    this.isSynced = false,
    this.uploadedPhotoUrl,
  });

  final String queueId;
  final String bookingId;
  final String techId;
  final String encryptedPayloadBase64;
  final String integrityTag;
  final DateTime capturedAtUtc;
  final LiveCaptureSource source;
  final bool isSynced;
  final String? uploadedPhotoUrl;

  QueuedOfflineCompletionPhoto markSynced(String photoUrl) {
    return QueuedOfflineCompletionPhoto(
      queueId: queueId,
      bookingId: bookingId,
      techId: techId,
      encryptedPayloadBase64: encryptedPayloadBase64,
      integrityTag: integrityTag,
      capturedAtUtc: capturedAtUtc,
      source: source,
      isSynced: true,
      uploadedPhotoUrl: photoUrl,
    );
  }
}

/// Local encrypted queue for live camera captures taken in low-signal salons.
class OfflineEncryptedPhotoQueue {
  OfflineEncryptedPhotoQueue({String? encryptionSecret})
      : _secretBytes = utf8.encode(
          encryptionSecret ?? 'abe_local_completion_vault_key_v1',
        );

  final List<int> _secretBytes;
  final List<QueuedOfflineCompletionPhoto> _items =
      <QueuedOfflineCompletionPhoto>[];

  List<QueuedOfflineCompletionPhoto> get items =>
      List<QueuedOfflineCompletionPhoto>.unmodifiable(_items);

  List<QueuedOfflineCompletionPhoto> get pendingItems =>
      List<QueuedOfflineCompletionPhoto>.unmodifiable(
        _items.where((item) => !item.isSynced),
      );

  QueuedOfflineCompletionPhoto enqueue({
    required String bookingId,
    required String techId,
    required LiveCapturedNailPhoto photo,
  }) {
    final plaintextJson = jsonEncode(<String, dynamic>{
      'localCaptureId': photo.localCaptureId,
      'bookingId': bookingId,
      'techId': techId,
      'source': photo.source.code,
      'capturedAtIso': photo.capturedAtUtc.toIso8601String(),
      'payload': photo.rawImageBytesBase64,
    });
    final plainBytes = utf8.encode(plaintextJson);
    final nonce = List<int>.generate(
      16,
      (i) => Random.secure().nextInt(256),
    );
    final cipherBytes = _xorWithKeystream(plainBytes, nonce);
    final combined = Uint8List.fromList(<int>[...nonce, ...cipherBytes]);
    final encodedCipher = base64Encode(combined);
    final tag = _computeIntegrityTag(combined);

    final record = QueuedOfflineCompletionPhoto(
      queueId: 'offline_${bookingId}_${photo.capturedAtUtc.millisecondsSinceEpoch}',
      bookingId: bookingId,
      techId: techId,
      encryptedPayloadBase64: encodedCipher,
      integrityTag: tag,
      capturedAtUtc: photo.capturedAtUtc,
      source: photo.source,
    );
    _items.removeWhere(
      (existing) => !existing.isSynced && existing.bookingId == bookingId,
    );
    _items.add(record);
    return record;
  }

  /// Decrypts and verifies integrity and identity binding of a queued offline capture.
  LiveCapturedNailPhoto decryptItem(QueuedOfflineCompletionPhoto item) {
    final combined = base64Decode(item.encryptedPayloadBase64);
    if (combined.length <= 16) {
      throw StateError('Corrupted encrypted offline photo payload.');
    }
    final expectedTag = _computeIntegrityTag(combined);
    if (expectedTag != item.integrityTag) {
      throw StateError('Offline photo integrity verification failed.');
    }
    final nonce = combined.sublist(0, 16);
    final cipherBytes = combined.sublist(16);
    final plainBytes = _xorWithKeystream(cipherBytes, nonce);
    final decoded =
        jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;

    if ((decoded['bookingId'] ?? '').toString() != item.bookingId ||
        (decoded['techId'] ?? '').toString() != item.techId) {
      throw StateError('Offline photo booking/tech binding mismatch.');
    }

    return LiveCapturedNailPhoto(
      localCaptureId: (decoded['localCaptureId'] ?? '').toString(),
      rawImageBytesBase64: (decoded['payload'] ?? '').toString(),
      capturedAtUtc: DateTime.parse(decoded['capturedAtIso'].toString()),
      source: (decoded['source'] ?? '').toString(),
    );
  }

  void markItemSynced(String queueId, String uploadedPhotoUrl) {
    final idx = _items.indexWhere((element) => element.queueId == queueId);
    if (idx >= 0) {
      _items[idx] = _items[idx].markSynced(uploadedPhotoUrl);
    }
  }

  List<int> _xorWithKeystream(List<int> input, List<int> nonce) {
    final out = List<int>.filled(input.length, 0);
    for (var i = 0; i < input.length; i++) {
      final keyByte = _secretBytes[i % _secretBytes.length];
      final nonceByte = nonce[i % nonce.length];
      final mix = (keyByte ^ nonceByte ^ (i & 0xFF)) & 0xFF;
      out[i] = input[i] ^ mix;
    }
    return out;
  }

  String _computeIntegrityTag(List<int> data) {
    var hash = 0x811C9DC5;
    for (final byte in data) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    for (final secretByte in _secretBytes) {
      hash ^= secretByte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// Outcome of attempting to complete an appointment with a live camera photo.
class AppointmentCompletionOutcome {
  const AppointmentCompletionOutcome({
    required this.completed,
    required this.queuedOffline,
    required this.bookingStatus,
    required this.payoutMovedToPendingLedger,
    required this.message,
    this.completionPhotoUrl,
    this.offlineQueueId,
  });

  final bool completed;
  final bool queuedOffline;
  final String bookingStatus;
  final bool payoutMovedToPendingLedger;
  final String message;
  final String? completionPhotoUrl;
  final String? offlineQueueId;
}

/// Enforces the Appointment Completion Lock:
/// - Only `ImageSource.camera` captures are accepted (gallery disabled).
/// - A booking cannot transition from `in_progress` to `completed`, nor move
///   earnings to the tech's pending payout ledger, without a verified `completionPhotoUrl`.
/// - Falls back to [OfflineEncryptedPhotoQueue] when salon cell signal drops.
class AppointmentCompletionLockService {
  AppointmentCompletionLockService({
    LiveCameraCaptureAdapter? cameraAdapter,
    CompletionPhotoUploadGateway? uploadGateway,
    OfflineEncryptedPhotoQueue? offlineQueue,
  })  : _cameraAdapter = cameraAdapter ?? const DeviceLiveCameraAdapter(),
        _uploadGateway =
            uploadGateway ?? SimulatedCompletionPhotoUploadGateway(),
        _offlineQueue = offlineQueue ?? OfflineEncryptedPhotoQueue();

  final LiveCameraCaptureAdapter _cameraAdapter;
  final CompletionPhotoUploadGateway _uploadGateway;
  final OfflineEncryptedPhotoQueue _offlineQueue;

  final Map<String, String> _bookingStatuses = <String, String>{};
  final Map<String, String> _bookingTechOwners = <String, String>{};
  final Map<String, String> _verifiedCompletionPhotoUrls = <String, String>{};
  final Set<String> _payoutUnlockedBookingIds = <String>{};

  OfflineEncryptedPhotoQueue get offlineQueue => _offlineQueue;

  String statusForBooking(String bookingId) =>
      _bookingStatuses[bookingId] ?? 'confirmed';

  String? completionPhotoUrlForBooking(String bookingId) =>
      _verifiedCompletionPhotoUrls[bookingId];

  bool isPayoutMovedToPendingLedger(String bookingId) =>
      _payoutUnlockedBookingIds.contains(bookingId);

  /// Registers or updates the current booking status (must be `in_progress` to complete).
  void setBookingStatus(String bookingId, String status, {String? techId}) {
    final cleanId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    final cleanStatus = InputSanitiser.sanitiseText(status, maxLength: 40);
    _bookingStatuses[cleanId] = cleanStatus;
    if (techId != null) {
      final cleanTech = InputSanitiser.sanitiseText(techId, maxLength: 128);
      if (cleanTech.isNotEmpty) {
        _bookingTechOwners[cleanId] = cleanTech;
      }
    }
  }

  /// Opens the live in-app camera only (zero gallery option) and captures finished nails.
  Future<LiveCapturedNailPhoto?> captureLiveCompletionPhoto({
    required String bookingId,
    required String techId,
  }) {
    return _cameraAdapter.captureFromLiveCamera(
      bookingId: bookingId,
      techId: techId,
    );
  }

  /// Submits a live camera photo to complete an `in_progress` booking.
  ///
  /// Rejects non-`in_progress` bookings and any non-camera source. If upload
  /// fails due to weak salon signal, encrypts and queues locally without
  /// releasing the payout until sync finishes.
  Future<AppointmentCompletionOutcome> submitLiveCompletionPhoto({
    required String bookingId,
    required String techId,
    required LiveCapturedNailPhoto photo,
    void Function(String bookingId, String completionPhotoUrl)?
        onPayoutUnlocked,
  }) async {
    final cleanBookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    final cleanTechId = InputSanitiser.sanitiseText(techId, maxLength: 128);
    if (cleanBookingId.isEmpty || cleanTechId.isEmpty) {
      throw ArgumentError('bookingId and techId are required.');
    }
    final assignedTech = _bookingTechOwners[cleanBookingId];
    if (assignedTech != null && assignedTech != cleanTechId) {
      throw StateError(
        'Access denied: only the assigned technician may complete booking $cleanBookingId.',
      );
    }

    // Enforce ImageSource.camera only.
    LiveCaptureSource.requireCamera(photo.source.code);

    final currentStatus = statusForBooking(cleanBookingId);
    if (currentStatus == 'completed' &&
        _payoutUnlockedBookingIds.contains(cleanBookingId)) {
      return AppointmentCompletionOutcome(
        completed: true,
        queuedOffline: false,
        bookingStatus: 'completed',
        payoutMovedToPendingLedger: true,
        completionPhotoUrl: _verifiedCompletionPhotoUrls[cleanBookingId],
        message: 'Booking is already completed with a verified live photo.',
      );
    }
    if (currentStatus != 'in_progress') {
      throw StateError(
        'Cannot complete booking $cleanBookingId from status "$currentStatus". '
        'Biometric and 4-digit PIN start lock must transition it to in_progress first.',
      );
    }

    late final String uploadedUrl;
    try {
      uploadedUrl = await _uploadGateway.uploadLivePhoto(
        bookingId: cleanBookingId,
        techId: cleanTechId,
        photo: photo,
      );
    } catch (_) {
      final queued = _offlineQueue.enqueue(
        bookingId: cleanBookingId,
        techId: cleanTechId,
        photo: photo,
      );
      return AppointmentCompletionOutcome(
        completed: false,
        queuedOffline: true,
        bookingStatus: currentStatus,
        payoutMovedToPendingLedger: false,
        offlineQueueId: queued.queueId,
        message:
            'Weak salon signal detected. Live camera photo encrypted and queued locally with timestamp. Booking will complete once signal returns.',
      );
    }

    return _finaliseBookingCompletion(
      bookingId: cleanBookingId,
      completionPhotoUrl: uploadedUrl,
      onPayoutUnlocked: onPayoutUnlocked,
    );
  }

  /// Enforces backend rule: explicitly blocks any direct transition to `completed`
  /// without a verified HTTPS `completionPhotoUrl` and `'camera'` source.
  AppointmentCompletionOutcome completeBookingDirectlyWithVerifiedUrl({
    required String bookingId,
    required String? completionPhotoUrl,
    required String? photoSource,
    void Function(String bookingId, String completionPhotoUrl)?
        onPayoutUnlocked,
  }) {
    final cleanBookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128);
    if (statusForBooking(cleanBookingId) != 'in_progress') {
      throw StateError(
        'Booking $cleanBookingId must be in_progress before completion.',
      );
    }
    LiveCaptureSource.requireCamera(photoSource ?? '');
    final cleanUrl =
        InputSanitiser.sanitiseText(completionPhotoUrl ?? '', maxLength: 500);
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('https://')) {
      throw ArgumentError(
        'A verified HTTPS completionPhotoUrl is required before transitioning to completed.',
      );
    }

    return _finaliseBookingCompletion(
      bookingId: cleanBookingId,
      completionPhotoUrl: cleanUrl,
      onPayoutUnlocked: onPayoutUnlocked,
    );
  }

  /// Flushes queued encrypted offline live photos once connectivity returns.
  Future<List<AppointmentCompletionOutcome>> flushOfflineQueue({
    void Function(String bookingId, String completionPhotoUrl)?
        onPayoutUnlocked,
  }) async {
    final results = <AppointmentCompletionOutcome>[];
    for (final item in _offlineQueue.pendingItems) {
      if (statusForBooking(item.bookingId) != 'in_progress') {
        continue;
      }
      try {
        final photo = _offlineQueue.decryptItem(item);
        final uploadedUrl = await _uploadGateway.uploadLivePhoto(
          bookingId: item.bookingId,
          techId: item.techId,
          photo: photo,
        );
        _offlineQueue.markItemSynced(item.queueId, uploadedUrl);
        results.add(
          _finaliseBookingCompletion(
            bookingId: item.bookingId,
            completionPhotoUrl: uploadedUrl,
            onPayoutUnlocked: onPayoutUnlocked,
          ),
        );
      } catch (e) {
        results.add(
          AppointmentCompletionOutcome(
            completed: false,
            queuedOffline: true,
            bookingStatus: statusForBooking(item.bookingId),
            payoutMovedToPendingLedger: false,
            offlineQueueId: item.queueId,
            message: 'Sync deferred: $e',
          ),
        );
      }
    }
    return results;
  }

  AppointmentCompletionOutcome _finaliseBookingCompletion({
    required String bookingId,
    required String completionPhotoUrl,
    void Function(String bookingId, String completionPhotoUrl)?
        onPayoutUnlocked,
  }) {
    if (_payoutUnlockedBookingIds.contains(bookingId)) {
      return AppointmentCompletionOutcome(
        completed: true,
        queuedOffline: false,
        bookingStatus: statusForBooking(bookingId),
        payoutMovedToPendingLedger: true,
        completionPhotoUrl: _verifiedCompletionPhotoUrls[bookingId],
        message: 'Booking already completed and payout unlocked.',
      );
    }

    final cleanUrl =
        InputSanitiser.sanitiseText(completionPhotoUrl, maxLength: 500);
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('https://')) {
      throw StateError(
        'Completion blocked: verified HTTPS completionPhotoUrl is required.',
      );
    }
    _bookingStatuses[bookingId] = 'completed';
    _verifiedCompletionPhotoUrls[bookingId] = cleanUrl;
    _payoutUnlockedBookingIds.add(bookingId);
    onPayoutUnlocked?.call(bookingId, cleanUrl);

    return AppointmentCompletionOutcome(
      completed: true,
      queuedOffline: false,
      bookingStatus: 'completed',
      payoutMovedToPendingLedger: true,
      completionPhotoUrl: cleanUrl,
      message:
          'Live completion photo verified. Appointment completed and earnings moved to pending payout ledger.',
    );
  }
}
