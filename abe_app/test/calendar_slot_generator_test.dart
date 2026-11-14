import 'package:abe_app/core/theme/abe_theme.dart';
import 'package:abe_app/features/calendar/domain/models/calendar_models.dart';
import 'package:abe_app/features/calendar/domain/services/slot_generator_service.dart';
import 'package:abe_app/features/calendar/presentation/screens/tech_calendar_setup_screen.dart';
import 'package:abe_app/features/calendar/presentation/widgets/client_slot_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const service = SlotGeneratorService();

  group('SlotGeneratorService Unit Tests', () {
    test('returns empty list on non-working days', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_1');
      // 2026-11-16 is a Monday (day off in defaultStudio).
      final monday = DateTime(2026, 11, 16);
      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: monday,
        totalServiceDurationMinutes: 90,
      );
      expect(slots, isEmpty);
    });

    test('prevents overlapping slots around lunch break and closing time', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_1');
      // 2026-11-17 is a Tuesday (09:00 - 17:30, lunch 13:00 - 13:45).
      final tuesday = DateTime(2026, 11, 17);
      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 90,
      );

      final lunchStart = DateTime(2026, 11, 17, 13, 0);
      final lunchEnd = DateTime(2026, 11, 17, 13, 45);
      final closing = DateTime(2026, 11, 17, 17, 30);

      for (final slot in slots) {
        final overlapsLunch =
            slot.startTime.isBefore(lunchEnd) && lunchStart.isBefore(slot.endTime);
        expect(overlapsLunch, isFalse);
        expect(slot.endTime.isAfter(closing), isFalse);
      }

      // 11:30 + 90m = 13:00 (valid, touches lunch start without overlapping)
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 30)),
        isTrue,
      );
      // 11:45 + 90m = 13:15 (overlaps lunch)
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 11, 45)),
        isFalse,
      );
      // 16:00 + 90m = 17:30 (valid)
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 16, 0)),
        isTrue,
      );
      // 16:15 + 90m = 17:45 (past closing)
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 16, 15)),
        isFalse,
      );
    });

    test('enforces cleanup buffer before and after existing active bookings', () {
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_1');
      final tuesday = DateTime(2026, 11, 17);
      final existing = <ExistingCalendarBooking>[
        ExistingCalendarBooking(
          bookingId: 'bk_1',
          startTime: DateTime(2026, 11, 17, 10, 30),
          endTime: DateTime(2026, 11, 17, 12, 0),
          status: 'confirmed',
        ),
        ExistingCalendarBooking(
          bookingId: 'bk_cancelled',
          startTime: DateTime(2026, 11, 17, 14, 0),
          endTime: DateTime(2026, 11, 17, 15, 30),
          status: 'cancelled_by_client',
        ),
      ];

      // 60-minute service with 15-minute cleanup buffer.
      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 60,
        existingBookings: existing,
      );

      // 09:15 + 60m = 10:15 (+ 15m buffer = 10:30) -> valid
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 9, 15)),
        isTrue,
      );
      // 09:30 + 60m = 10:30 (+ 15m buffer = 10:45 > 10:30) -> blocked by buffer
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 9, 30)),
        isFalse,
      );
      // 12:00 -> blocked because existing ends at 12:00 and needs 15m cleanup
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 12, 0)),
        isFalse,
      );
      // 12:15 -> 12:15 + 60m = 13:15 overlaps lunch (13:00-13:45), so also blocked
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 12, 15)),
        isFalse,
      );
      // Cancelled booking at 14:00 does NOT block 14:00
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 14, 0)),
        isTrue,
      );
    });

    test('respects date-specific blocked windows and filters past slots', () {
      final base = TechAvailabilitySchedule.defaultStudio(techId: 'tech_1');
      final tuesday = DateTime(2026, 11, 17);
      final schedule = base.copyWith(
        blockedWindowsByDate: <String, List<TimeRange>>{
          '2026-11-17': <TimeRange>[
            TimeRange(startMinutes: 14 * 60, endMinutes: 16 * 60),
          ],
        },
      );

      final slots = service.generateAvailableSlots(
        schedule: schedule,
        date: tuesday,
        totalServiceDurationMinutes: 60,
        now: DateTime(2026, 11, 17, 10, 0),
      );

      // 09:00 and 10:00 are not after `now` (10:00)
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 10, 0)),
        isFalse,
      );
      // 10:15 is after 10:00
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 10, 15)),
        isTrue,
      );
      // 14:30 overlaps manual block (14:00 - 16:00)
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 14, 30)),
        isFalse,
      );
      // 16:00 is open after the block
      expect(
        slots.any((s) => s.startTime == DateTime(2026, 11, 17, 16, 0)),
        isTrue,
      );
    });
  });

  group('Calendar Presentation Widget Tests', () {
    testWidgets('TechCalendarSetupScreen toggles day, blocks time, and saves',
        (WidgetTester tester) async {
      TechAvailabilitySchedule? saved;
      final initial = TechAvailabilitySchedule.defaultStudio(techId: 'tech_1');

      await tester.pumpWidget(
        MaterialApp(
          theme: AbeTheme.lightTheme,
          home: TechCalendarSetupScreen(
            initialSchedule: initial,
            onSave: (schedule) => saved = schedule,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('day_switch_1')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('add_block_time_button')),
        200,
      );
      await tester.tap(find.byKey(const Key('add_block_time_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_studio_hours_button')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.weeklyHours[DateTime.monday]!.isWorkingDay, isTrue);
      expect(saved!.blockedWindowsByDate, isNotEmpty);
    });

    testWidgets('ClientSlotPickerSheet selects slot and triggers confirmation',
        (WidgetTester tester) async {
      AppointmentSlot? confirmed;
      final schedule = TechAvailabilitySchedule.defaultStudio(techId: 'tech_1');
      final tuesday = DateTime(2026, 11, 17);

      await tester.pumpWidget(
        MaterialApp(
          theme: AbeTheme.lightTheme,
          home: Scaffold(
            body: ClientSlotPickerSheet(
              schedule: schedule,
              totalServiceDurationMinutes: 90,
              initialDate: tuesday,
              onSlotConfirmed: (slot) => confirmed = slot,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('slot_chip_09:00')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_slot_button')));
      await tester.pumpAndSettle();

      expect(confirmed, isNotNull);
      expect(confirmed!.formattedRange, '09:00 - 10:30');
    });
  });
}
