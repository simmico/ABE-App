import 'package:abe_app/features/calendar/domain/models/calendar_models.dart';
import 'package:abe_app/features/calendar/domain/services/slot_generator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SlotGeneratorService();

  // 2026-11-17 is a Tuesday: 09:00 - 17:30, lunch 13:00 - 13:45,
  // 15-minute cleanup buffer, 15-minute slot step.
  final tuesday = DateTime(2026, 11, 17);
  // 2026-11-21 is a Saturday: 09:00 - 15:00, no recurring lunch break.
  final saturday = DateTime(2026, 11, 21);

  group('SlotGeneratorService: 60-minute bookings', () {
    test('respects lunch break boundaries without requiring cleanup buffer against lunch', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_60');
      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 60,
      );

      // 12:00 - 13:00 touches lunch start (13:00) and is valid.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 12, 0)),
        isTrue,
      );
      // 12:15 - 13:15 overlaps lunch and is excluded.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 12, 15)),
        isFalse,
      );
      // 13:30 - 14:30 overlaps lunch end (13:45) and is excluded.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 13, 30)),
        isFalse,
      );
      // 13:45 - 14:45 starts right at lunch end and is valid.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 13, 45)),
        isTrue,
      );
    });

    test('enforces 15-minute cleanup buffer before and after an existing appointment', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_60');
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_60_mid_morning',
          startTime: DateTime(2026, 11, 17, 10, 30),
          endTime: DateTime(2026, 11, 17, 11, 30),
        ),
      ];

      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 60,
        existingBookings: existing,
      );

      // Before: 09:15 - 10:15 (+ 15m cleanup = 10:30) fits exactly.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 9, 15)),
        isTrue,
      );
      // Before: 09:30 - 10:30 (+ 15m cleanup = 10:45) encroaches on 10:30 booking.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 9, 30)),
        isFalse,
      );

      // After: 11:30 - 12:30 violates cleanup buffer after 11:30.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 30)),
        isFalse,
      );
      // After: 11:45 - 12:45 starts 15m after 11:30 and ends before 13:00 lunch.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 45)),
        isTrue,
      );
      // After: 12:00 - 13:00 touches lunch start and is also valid.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 12, 0)),
        isTrue,
      );
    });

    test('fits a single 60-minute slot into a tight 90-minute gap between two bookings', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_60');
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_1',
          startTime: DateTime(2026, 11, 17, 10, 0),
          endTime: DateTime(2026, 11, 17, 11, 0),
        ),
        ExistingCalendarBooking(
          bookingId: 'bk_2',
          startTime: DateTime(2026, 11, 17, 12, 30),
          endTime: DateTime(2026, 11, 17, 13, 0),
        ),
      ];

      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 60,
        existingBookings: existing,
      );

      // 11:00 + 15m buffer = 11:15 start; 11:15 + 60m = 12:15; + 15m buffer = 12:30.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 15)),
        isTrue,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 0)),
        isFalse,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 30)),
        isFalse,
      );
    });

    test('enforces end-of-day cutoff at 17:30', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_60');
      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 60,
      );

      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 16, 30)),
        isTrue,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 16, 45)),
        isFalse,
      );
    });
  });

  group('SlotGeneratorService: 90-minute bookings', () {
    test('handles lunch break and existing appointment interaction', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_90');
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_morning',
          startTime: DateTime(2026, 11, 17, 11, 0),
          endTime: DateTime(2026, 11, 17, 12, 0),
        ),
        ExistingCalendarBooking(
          bookingId: 'bk_afternoon',
          startTime: DateTime(2026, 11, 17, 14, 30),
          endTime: DateTime(2026, 11, 17, 15, 30),
        ),
      ];

      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 90,
        existingBookings: existing,
      );

      // Morning before 11:00: 09:15 - 10:45 (+ 15m buffer = 11:00) is valid.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 9, 15)),
        isTrue,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 9, 30)),
        isFalse,
      );

      // Morning after 12:00: earliest is 12:15, which ends at 13:45 (overlaps lunch).
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 12, 15)),
        isFalse,
      );

      // Afternoon after 15:30: 15:45 - 17:15 and 16:00 - 17:30 are valid.
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 15, 45)),
        isTrue,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 16, 0)),
        isTrue,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 16, 15)),
        isFalse,
      );
    });

    test('supports custom 0-minute and 30-minute cleanup buffers for back-to-back fitting', () {
      final baseSchedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_buf');
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_mid',
          startTime: DateTime(2026, 11, 17, 10, 30),
          endTime: DateTime(2026, 11, 17, 11, 30),
        ),
      ];

      final zeroBufferSlots = service.generateAvailableSlots(
        schedule: baseSchedule.copyWith(cleanupBufferMinutes: 0),
        date: tuesday,
        totalServiceDurationMinutes: 90,
        existingBookings: existing,
      );
      // With 0m buffer: 09:00 - 10:30 and 11:30 - 13:00 both fit back-to-back.
      expect(
        zeroBufferSlots.any((s) => s.startTime == DateTime(2026, 11, 17, 9, 0)),
        isTrue,
      );
      expect(
        zeroBufferSlots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 30)),
        isTrue,
      );

      final thirtyBufferSlots = service.generateAvailableSlots(
        schedule: baseSchedule.copyWith(cleanupBufferMinutes: 30),
        date: tuesday,
        totalServiceDurationMinutes: 90,
        existingBookings: existing,
      );
      // With 30m buffer: 09:00 + 90m + 30m = 11:00 > 10:30, so no morning slot fits.
      expect(
        thirtyBufferSlots.any((s) => s.startTime.isBefore(DateTime(2026, 11, 17, 13, 0))),
        isFalse,
      );
    });
  });

  group('SlotGeneratorService: 135-minute bookings', () {
    test('respects lunch break and end-of-day cutoffs on an empty Tuesday', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_135');
      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 135,
      );

      // Morning: 10:45 + 135m = 13:00 (valid), 11:00 + 135m = 13:15 (overlaps lunch).
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 10, 45)),
        isTrue,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 0)),
        isFalse,
      );

      // Afternoon: 13:45 + 135m = 16:00 (valid), 15:15 + 135m = 17:30 (valid).
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 13, 45)),
        isTrue,
      );
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 15, 15)),
        isTrue,
      );
      // 15:30 + 135m = 17:45 (past 17:30 closing).
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 15, 30)),
        isFalse,
      );
    });

    test('blocks entire morning when an early booking leaves insufficient time around lunch', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_135');
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_early',
          startTime: DateTime(2026, 11, 17, 10, 0),
          endTime: DateTime(2026, 11, 17, 11, 0),
        ),
      ];

      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 135,
        existingBookings: existing,
      );

      // Before 10:00 is only 60m; after 11:15 to 13:00 is only 105m.
      final morningSlots = slots.where(
        (s) => s.startTime.isBefore(DateTime(2026, 11, 17, 13, 0)),
      );
      expect(morningSlots, isEmpty);

      // Afternoon remains open from 13:45 through 15:15.
      expect(
        slots.first.startTime,
        equals(DateTime(2026, 11, 17, 13, 45)),
      );
      expect(
        slots.last.startTime,
        equals(DateTime(2026, 11, 17, 15, 15)),
      );
    });

    test('fits an exact 135-minute slot between two Saturday bookings with buffers', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_135');
      // Saturday is 09:00 - 15:00 with no lunch break.
      // Booking 1 ends 10:00 -> earliest start is 10:15.
      // Booking 2 starts 12:45 -> latest end is 12:30.
      // 10:15 to 12:30 is exactly 135 minutes.
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_sat_1',
          startTime: DateTime(2026, 11, 21, 9, 0),
          endTime: DateTime(2026, 11, 21, 10, 0),
        ),
        ExistingCalendarBooking(
          bookingId: 'bk_sat_2',
          startTime: DateTime(2026, 11, 21, 12, 45),
          endTime: DateTime(2026, 11, 21, 14, 0),
        ),
      ];

      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: saturday,
        totalServiceDurationMinutes: 135,
        existingBookings: existing,
      );

      expect(slots.length, equals(1));
      expect(slots.single.startTime, equals(DateTime(2026, 11, 21, 10, 15)));
      expect(slots.single.endTime, equals(DateTime(2026, 11, 21, 12, 30)));
      expect(slots.single.serviceDurationMinutes, equals(135));
    });

    test('isSlotAvailable and cancelled bookings behave consistently for 135-minute slots', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_135');
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_cancelled_tech',
          startTime: DateTime(2026, 11, 17, 9, 30),
          endTime: DateTime(2026, 11, 17, 11, 30),
          status: 'cancelled_by_tech',
        ),
      ];

      final isMorningOpen = service.isSlotAvailable(
        schedule: schedule,
        slotStart: DateTime(2026, 11, 17, 9, 0),
        totalServiceDurationMinutes: 135,
        existingBookings: existing,
        now: DateTime(2026, 11, 17, 8, 30),
      );
      expect(isMorningOpen, isTrue);

      final isPastSlotBlocked = service.isSlotAvailable(
        schedule: schedule,
        slotStart: DateTime(2026, 11, 17, 9, 0),
        totalServiceDurationMinutes: 135,
        existingBookings: existing,
        now: DateTime(2026, 11, 17, 9, 0),
      );
      expect(isPastSlotBlocked, isFalse);
    });
  });
}
