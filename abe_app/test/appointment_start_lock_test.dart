import 'dart:math';

import 'package:abe_app/features/booking/domain/models/appointment_lock_models.dart';
import 'package:abe_app/features/booking/domain/services/appointment_start_lock_service.dart';
import 'package:abe_app/features/booking/presentation/screens/tech_start_appointment_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _MutableClock {
  _MutableClock(this.now);
  DateTime now;
  DateTime call() => now;
}

class _ConfigurableBiometricAdapter implements BiometricVerificationAdapter {
  _ConfigurableBiometricAdapter({this.shouldPass = true});
  bool shouldPass;

  @override
  Future<bool> authenticateTech({
    required String techId,
    required String reason,
  }) async {
    return shouldPass;
  }
}

void main() {
  group('AppointmentStartLockService (Item 12)', () {
    test('generates unique 4-digit PIN readable only by the owning client', () {
      final service = AppointmentStartLockService(secureRandom: Random(42));
      final clientView = service.generatePinForConfirmedBooking(
        bookingId: 'bk_100',
        clientId: 'client_naledi',
        techId: 'tech_zinhle',
      );

      expect(RegExp(r'^\d{4}$').hasMatch(clientView.pinCode), isTrue);

      final retrieved = service.getPinForClient(
        bookingId: 'bk_100',
        requesterId: 'client_naledi',
      );
      expect(retrieved.pinCode, equals(clientView.pinCode));

      expect(
        () => service.getPinForClient(
          bookingId: 'bk_100',
          requesterId: 'tech_zinhle',
        ),
        throwsStateError,
      );
      expect(
        () => service.getPinForClient(
          bookingId: 'bk_100',
          requesterId: 'stranger_user',
        ),
        throwsStateError,
      );
    });

    test('rejects PIN submission until biometric check passes', () async {
      final adapter = _ConfigurableBiometricAdapter(shouldPass: false);
      final service = AppointmentStartLockService(
        secureRandom: Random(7),
        biometricAdapter: adapter,
      );

      final pinView = service.generatePinForConfirmedBooking(
        bookingId: 'bk_101',
        clientId: 'client_1',
        techId: 'tech_1',
      );

      final beforeBio = service.submitPinAndStartAppointment(
        bookingId: 'bk_101',
        techId: 'tech_1',
        enteredPin: pinView.pinCode,
      );
      expect(beforeBio.success, isFalse);
      expect(beforeBio.bookingStatus, equals('confirmed'));

      final failedBio = await service.verifyTechBiometric(
        bookingId: 'bk_101',
        techId: 'tech_1',
      );
      expect(failedBio, isFalse);

      adapter.shouldPass = true;
      final passedBio = await service.verifyTechBiometric(
        bookingId: 'bk_101',
        techId: 'tech_1',
      );
      expect(passedBio, isTrue);

      final started = service.submitPinAndStartAppointment(
        bookingId: 'bk_101',
        techId: 'tech_1',
        enteredPin: pinView.pinCode,
      );
      expect(started.success, isTrue);
      expect(started.bookingStatus, equals('in_progress'));
    });

    test('locks PIN entry for 15 minutes after 5 failed attempts and alerts Support/Admin', () async {
      final clock = _MutableClock(DateTime.utc(2026, 11, 14, 10, 0));
      final service = AppointmentStartLockService(
        secureRandom: Random(19),
        clock: clock.call,
      );

      final pinView = service.generatePinForConfirmedBooking(
        bookingId: 'bk_102',
        clientId: 'client_2',
        techId: 'tech_2',
      );
      await service.verifyTechBiometric(bookingId: 'bk_102', techId: 'tech_2');

      final wrongPin = pinView.pinCode == '9876' ? '1234' : '9876';

      for (var i = 1; i <= 4; i++) {
        final attempt = service.submitPinAndStartAppointment(
          bookingId: 'bk_102',
          techId: 'tech_2',
          enteredPin: wrongPin,
        );
        expect(attempt.success, isFalse);
        expect(attempt.isLocked, isFalse);
        expect(attempt.remainingAttempts, equals(5 - i));
      }

      final fifthAttempt = service.submitPinAndStartAppointment(
        bookingId: 'bk_102',
        techId: 'tech_2',
        enteredPin: wrongPin,
      );
      expect(fifthAttempt.success, isFalse);
      expect(fifthAttempt.isLocked, isTrue);
      expect(fifthAttempt.remainingAttempts, equals(0));
      expect(fifthAttempt.supportAlertTriggered, isTrue);
      expect(service.supportAlerts, hasLength(1));
      expect(service.supportAlerts.first.alertType, equals('pin_lockout'));

      // Even the correct PIN is rejected while locked within 15 minutes.
      clock.now = clock.now.add(const Duration(minutes: 10));
      final duringLockout = service.submitPinAndStartAppointment(
        bookingId: 'bk_102',
        techId: 'tech_2',
        enteredPin: pinView.pinCode,
      );
      expect(duringLockout.success, isFalse);
      expect(duringLockout.isLocked, isTrue);
      expect(service.statusForBooking('bk_102'), equals('confirmed'));

      // After 15 minutes pass, lockout lifts and requires fresh biometric verification before PIN.
      clock.now = clock.now.add(const Duration(minutes: 6));
      final beforeReBio = service.submitPinAndStartAppointment(
        bookingId: 'bk_102',
        techId: 'tech_2',
        enteredPin: pinView.pinCode,
      );
      expect(beforeReBio.success, isFalse);
      expect(beforeReBio.isLocked, isFalse);

      await service.verifyTechBiometric(bookingId: 'bk_102', techId: 'tech_2');
      final afterLockout = service.submitPinAndStartAppointment(
        bookingId: 'bk_102',
        techId: 'tech_2',
        enteredPin: pinView.pinCode,
      );
      expect(afterLockout.success, isTrue);
      expect(afterLockout.bookingStatus, equals('in_progress'));

      // Repeat call is idempotent and does not re-lock or overwrite state.
      final repeatCall = service.submitPinAndStartAppointment(
        bookingId: 'bk_102',
        techId: 'tech_2',
        enteredPin: wrongPin,
      );
      expect(repeatCall.success, isTrue);
      expect(repeatCall.bookingStatus, equals('in_progress'));
    });

    test('denies unassigned technicians from reading status, verifying biometrics, or starting', () async {
      final service = AppointmentStartLockService(secureRandom: Random(21));
      final pinView = service.generatePinForConfirmedBooking(
        bookingId: 'bk_103',
        clientId: 'client_3',
        techId: 'tech_owner',
      );

      expect(
        () => service.getTechLockStatus(
          bookingId: 'bk_103',
          techId: 'tech_intruder',
        ),
        throwsStateError,
      );
      await expectLater(
        service.verifyTechBiometric(
          bookingId: 'bk_103',
          techId: 'tech_intruder',
        ),
        throwsStateError,
      );
      expect(
        () => service.submitPinAndStartAppointment(
          bookingId: 'bk_103',
          techId: 'tech_intruder',
          enteredPin: pinView.pinCode,
        ),
        throwsStateError,
      );
    });

    test('sanitises SupportSecurityAlert and rejects empty/negative invalid fields', () {
      final alert = SupportSecurityAlert(
        id: 'alert_1',
        bookingId: 'bk_1',
        clientId: 'c_1',
        techId: 't_1',
        alertType: 'pin_lockout',
        message: '<script>evil()</script>Lockout \u2014 triggered',
        createdAtUtc: DateTime.utc(2026, 11, 14),
      );
      expect(alert.message, equals('Lockout - triggered'));

      expect(
        () => SupportSecurityAlert(
          id: '<script>x</script>',
          bookingId: 'bk_1',
          clientId: 'c_1',
          techId: 't_1',
          alertType: 'pin_lockout',
          message: 'Locked',
          createdAtUtc: DateTime.utc(2026, 11, 14),
        ),
        throwsArgumentError,
      );
    });
  });

  group('TechStartAppointmentScreen Widget Tests', () {
    testWidgets('requires biometric verification then valid 4-digit PIN to start', (tester) async {
      final service = AppointmentStartLockService(secureRandom: Random(5));
      final pinView = service.generatePinForConfirmedBooking(
        bookingId: 'bk_ui_1',
        clientId: 'client_ui',
        techId: 'tech_ui',
      );
      AppointmentStartOutcome? capturedOutcome;

      await tester.pumpWidget(
        MaterialApp(
          home: TechStartAppointmentScreen(
            bookingId: 'bk_ui_1',
            techId: 'tech_ui',
            clientName: 'Naledi K.',
            lookTitle: 'Sculpted Almond BIAB & Micro French',
            venueName: 'The Rose Atelier Studio, Claremont',
            priceZar: 450,
            durationMinutes: 90,
            lockService: service,
            onAppointmentStarted: (outcome) => capturedOutcome = outcome,
          ),
        ),
      );

      // Step 1: Verify biometric
      final bioButton = find.byKey(const Key('start_biometric_button'));
      await tester.ensureVisible(bioButton);
      await tester.tap(bioButton);
      await tester.pumpAndSettle();
      expect(find.text('Verified'), findsOneWidget);

      // Step 2: Tap 4 digits of the client PIN on keypad
      for (final digit in pinView.pinCode.split('')) {
        final keyFinder = find.byKey(Key('pin_digit_$digit'));
        await tester.ensureVisible(keyFinder);
        await tester.tap(keyFinder);
        await tester.pump();
      }

      final submitBtn = find.byKey(const Key('start_appointment_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(capturedOutcome?.success, isTrue);
      expect(capturedOutcome?.bookingStatus, equals('in_progress'));
      expect(find.text('Appointment In Progress'), findsOneWidget);
    });

    testWidgets('displays 15-minute lockout banner after 5 wrong PIN attempts', (tester) async {
      final service = AppointmentStartLockService(secureRandom: Random(8));
      final pinView = service.generatePinForConfirmedBooking(
        bookingId: 'bk_ui_2',
        clientId: 'client_ui_2',
        techId: 'tech_ui_2',
      );
      await service.verifyTechBiometric(
        bookingId: 'bk_ui_2',
        techId: 'tech_ui_2',
      );
      final wrongPin = pinView.pinCode == '1234' ? '5678' : '1234';

      await tester.pumpWidget(
        MaterialApp(
          home: TechStartAppointmentScreen(
            bookingId: 'bk_ui_2',
            techId: 'tech_ui_2',
            clientName: 'Taryn V.',
            lookTitle: 'Rose Quartz Chrome Glaze',
            venueName: 'House of Alabaster, Rosebank',
            priceZar: 380,
            durationMinutes: 75,
            lockService: service,
          ),
        ),
      );

      for (var attempt = 0; attempt < 5; attempt++) {
        for (final digit in wrongPin.split('')) {
          final keyFinder = find.byKey(Key('pin_digit_$digit'));
          await tester.ensureVisible(keyFinder);
          await tester.tap(keyFinder);
          await tester.pump();
        }
        final submitBtn =
            find.byKey(const Key('start_appointment_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('pin_lockout_banner')), findsOneWidget);
      expect(service.supportAlerts, hasLength(1));
    });
  });
}
