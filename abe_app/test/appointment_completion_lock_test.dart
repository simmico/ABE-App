import 'package:abe_app/features/booking/domain/services/appointment_completion_lock_service.dart';
import 'package:abe_app/features/booking/presentation/screens/tech_complete_appointment_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('AppointmentCompletionLockService (Item 13)', () {
    test('rejects gallery uploads and accepts only camera source', () {
      expect(
        () => LiveCaptureSource.requireCamera('gallery'),
        throwsArgumentError,
      );
      expect(
        () => LiveCaptureSource.requireCamera('file_picker'),
        throwsArgumentError,
      );
      expect(
        () => LiveCapturedNailPhoto(
          localCaptureId: 'img_1',
          rawImageBytesBase64: 'YWJj',
          capturedAtUtc: DateTime.utc(2026, 11, 14, 12, 0),
          source: 'gallery',
        ),
        throwsArgumentError,
      );
      expect(
        LiveCaptureSource.requireCamera('camera'),
        equals(LiveCaptureSource.camera),
      );
    });

    test('blocks transition to completed without in_progress status or verified completionPhotoUrl', () {
      final service = AppointmentCompletionLockService();
      service.setBookingStatus('bk_200', 'confirmed');

      expect(
        () => service.completeBookingDirectlyWithVerifiedUrl(
          bookingId: 'bk_200',
          completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_200.jpg',
          photoSource: 'camera',
        ),
        throwsStateError,
      );

      service.setBookingStatus('bk_200', 'in_progress');
      expect(
        () => service.completeBookingDirectlyWithVerifiedUrl(
          bookingId: 'bk_200',
          completionPhotoUrl: '',
          photoSource: 'camera',
        ),
        throwsArgumentError,
      );
      expect(
        () => service.completeBookingDirectlyWithVerifiedUrl(
          bookingId: 'bk_200',
          completionPhotoUrl: 'https://storage.abe.co.za/completions/bk_200.jpg',
          photoSource: 'gallery',
        ),
        throwsArgumentError,
      );
    });

    test('completes online booking and triggers pending payout ledger move', () async {
      final service = AppointmentCompletionLockService();
      service.setBookingStatus('bk_201', 'in_progress');
      String? unlockedBooking;

      final photo = await service.captureLiveCompletionPhoto(
        bookingId: 'bk_201',
        techId: 'tech_cpt_1',
      );
      expect(photo, isNotNull);

      final outcome = await service.submitLiveCompletionPhoto(
        bookingId: 'bk_201',
        techId: 'tech_cpt_1',
        photo: photo!,
        onPayoutUnlocked: (bookingId, url) {
          unlockedBooking = bookingId;
        },
      );

      expect(outcome.completed, isTrue);
      expect(outcome.bookingStatus, equals('completed'));
      expect(outcome.payoutMovedToPendingLedger, isTrue);
      expect(outcome.completionPhotoUrl, isNotNull);
      expect(unlockedBooking, equals('bk_201'));
      expect(service.isPayoutMovedToPendingLedger('bk_201'), isTrue);
    });

    test('queues encrypted offline live photo when signal drops and syncs on recovery', () async {
      final gateway = SimulatedCompletionPhotoUploadGateway(isOnline: false);
      final service = AppointmentCompletionLockService(uploadGateway: gateway);
      service.setBookingStatus('bk_202', 'in_progress');

      final photo = await service.captureLiveCompletionPhoto(
        bookingId: 'bk_202',
        techId: 'tech_jhb_1',
      );

      final offlineOutcome = await service.submitLiveCompletionPhoto(
        bookingId: 'bk_202',
        techId: 'tech_jhb_1',
        photo: photo!,
      );

      expect(offlineOutcome.completed, isFalse);
      expect(offlineOutcome.queuedOffline, isTrue);
      expect(offlineOutcome.bookingStatus, equals('in_progress'));
      expect(offlineOutcome.payoutMovedToPendingLedger, isFalse);
      expect(service.offlineQueue.pendingItems, hasLength(1));

      // Verify payload is encrypted (does not contain raw base64 plaintext)
      final queuedItem = service.offlineQueue.pendingItems.first;
      expect(
        queuedItem.encryptedPayloadBase64.contains(photo.rawImageBytesBase64),
        isFalse,
      );

      // Signal returns
      gateway.isOnline = true;
      final flushed = await service.flushOfflineQueue();
      expect(flushed, hasLength(1));
      expect(flushed.first.completed, isTrue);
      expect(flushed.first.bookingStatus, equals('completed'));
      expect(flushed.first.payoutMovedToPendingLedger, isTrue);
      expect(service.offlineQueue.pendingItems, isEmpty);
    });

    test('rejects http:// URLs, tampered offline queue payloads, and avoids duplicate payout triggers', () async {
      final service = AppointmentCompletionLockService();
      service.setBookingStatus('bk_203', 'in_progress', techId: 'tech_203');

      expect(
        () => service.completeBookingDirectlyWithVerifiedUrl(
          bookingId: 'bk_203',
          completionPhotoUrl: 'http://insecure.abe.co.za/photo.jpg',
          photoSource: 'camera',
        ),
        throwsArgumentError,
      );

      final photo = await service.captureLiveCompletionPhoto(
        bookingId: 'bk_203',
        techId: 'tech_203',
      );

      var payoutCallbacks = 0;
      await service.submitLiveCompletionPhoto(
        bookingId: 'bk_203',
        techId: 'tech_203',
        photo: photo!,
        onPayoutUnlocked: (_, _) => payoutCallbacks++,
      );
      await service.submitLiveCompletionPhoto(
        bookingId: 'bk_203',
        techId: 'tech_203',
        photo: photo,
        onPayoutUnlocked: (_, _) => payoutCallbacks++,
      );
      expect(payoutCallbacks, equals(1));

      final queue = OfflineEncryptedPhotoQueue();
      final item = queue.enqueue(
        bookingId: 'bk_204',
        techId: 'tech_204',
        photo: photo,
      );
      final tampered = QueuedOfflineCompletionPhoto(
        queueId: item.queueId,
        bookingId: item.bookingId,
        techId: item.techId,
        encryptedPayloadBase64: item.encryptedPayloadBase64,
        integrityTag: '00000000',
        capturedAtUtc: item.capturedAtUtc,
        source: item.source,
      );
      expect(() => queue.decryptItem(tampered), throwsStateError);
    });
  });

  group('TechCompleteAppointmentScreen Widget Tests', () {
    testWidgets('captures live photo, handles offline queue, and syncs to complete', (tester) async {
      final gateway = SimulatedCompletionPhotoUploadGateway(isOnline: false);
      final service = AppointmentCompletionLockService(uploadGateway: gateway);
      service.setBookingStatus('bk_ui_comp', 'in_progress');
      AppointmentCompletionOutcome? completedOutcome;

      await tester.pumpWidget(
        MaterialApp(
          home: TechCompleteAppointmentScreen(
            bookingId: 'bk_ui_comp',
            techId: 'tech_ui',
            clientName: 'Amahle D.',
            lookTitle: 'Soft Gel Extensions + Soak-Off',
            netEarningsZar: 476,
            completionService: service,
            onAppointmentCompleted: (outcome) => completedOutcome = outcome,
          ),
        ),
      );

      expect(find.textContaining('Gallery uploads are disabled'), findsOneWidget);

      final captureBtn = find.byKey(const Key('capture_live_photo_button'));
      await tester.ensureVisible(captureBtn);
      await tester.pumpAndSettle();
      await tester.tap(captureBtn);
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('submit_completion_photo_button'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_queue_banner')), findsOneWidget);
      expect(completedOutcome, isNull);

      gateway.isOnline = true;
      final flushBtn = find.byKey(const Key('flush_offline_queue_button'));
      await tester.ensureVisible(flushBtn);
      await tester.pumpAndSettle();
      await tester.tap(flushBtn);
      await tester.pumpAndSettle();

      expect(completedOutcome?.completed, isTrue);
      expect(completedOutcome?.bookingStatus, equals('completed'));
      expect(find.text('Booking Completed & Payout Unlocked'), findsOneWidget);
    });
  });
}
