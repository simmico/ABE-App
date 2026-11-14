import '../models/calendar_models.dart';

/// Duration-aware slot generator for Aqeelah's Beauty Empire (ABE).
///
/// Calculates open appointment slots from a technician's weekly working hours,
/// lunch breaks, date-specific blocked windows, existing active bookings,
/// workstation cleanup buffers, and the exact total minutes of the selected
/// Visual Contract plus any toggled modifiers.
class SlotGeneratorService {
  const SlotGeneratorService();

  /// Generates all non-overlapping [AppointmentSlot]s for [date] that can
  /// accommodate [totalServiceDurationMinutes].
  List<AppointmentSlot> generateAvailableSlots({
    required TechAvailabilitySchedule schedule,
    required DateTime date,
    required int totalServiceDurationMinutes,
    List<ExistingCalendarBooking> existingBookings =
        const <ExistingCalendarBooking>[],
    DateTime? now,
  }) {
    if (totalServiceDurationMinutes <= 0) {
      throw ArgumentError.value(
        totalServiceDurationMinutes,
        'totalServiceDurationMinutes',
        'Total service duration must be greater than zero.',
      );
    }

    final dayConfig = schedule.weeklyHours[date.weekday];
    if (dayConfig == null ||
        !dayConfig.isWorkingDay ||
        dayConfig.workingWindow == null) {
      return const <AppointmentSlot>[];
    }

    final workingWindow = dayConfig.workingWindow!;
    final dayStart = DateTime(date.year, date.month, date.day);
    final dateKey = TechAvailabilitySchedule.dateKey(dayStart);

    // Non-booking blocks: recurring breaks and date-specific manual blocks.
    final staticBlockedRanges = <TimeRange>[
      ...dayConfig.breakWindows,
      ...(schedule.blockedWindowsByDate[dateKey] ?? const <TimeRange>[]),
    ];

    // Active bookings on this date converted into minute-of-day ranges.
    final dayEnd = dayStart.add(const Duration(days: 1));
    final activeBookingRanges = <TimeRange>[];
    for (final booking in existingBookings) {
      if (!booking.blocksCalendar) continue;
      if (!booking.endTime.isAfter(dayStart) || !booking.startTime.isBefore(dayEnd)) {
        continue;
      }

      final clampedStart = booking.startTime.isBefore(dayStart)
          ? 0
          : booking.startTime.difference(dayStart).inMinutes;
      final clampedEnd = booking.endTime.isAfter(dayEnd)
          ? 1440
          : booking.endTime.difference(dayStart).inMinutes;
      if (clampedEnd > clampedStart) {
        activeBookingRanges.add(
          TimeRange(startMinutes: clampedStart, endMinutes: clampedEnd),
        );
      }
    }

    final buffer = schedule.cleanupBufferMinutes;
    final step = schedule.slotStepMinutes;
    final slots = <AppointmentSlot>[];

    for (var cursor = workingWindow.startMinutes;
        cursor + totalServiceDurationMinutes <= workingWindow.endMinutes;
        cursor += step) {
      final candidateStart = dayStart.add(Duration(minutes: cursor));
      if (now != null && !candidateStart.isAfter(now)) {
        continue;
      }

      final serviceEnd = cursor + totalServiceDurationMinutes;
      final serviceRange = TimeRange(
        startMinutes: cursor,
        endMinutes: serviceEnd,
      );

      // 1. Check against lunch breaks and manual blocked periods.
      final hitsStaticBlock = staticBlockedRanges.any(serviceRange.overlaps);
      if (hitsStaticBlock) {
        continue;
      }

      // 2. Check against existing bookings + cleanup buffer on both sides:
      //    - New service cannot start until existing booking + buffer finishes.
      //    - New service + buffer cannot run into an existing booking's start.
      final hitsBooking = activeBookingRanges.any((bookingRange) {
        final existingWithBuffer = TimeRange(
          startMinutes: bookingRange.startMinutes,
          endMinutes: (bookingRange.endMinutes + buffer).clamp(0, 1440),
        );
        final candidateWithBuffer = TimeRange(
          startMinutes: cursor,
          endMinutes: (serviceEnd + buffer).clamp(0, 1440),
        );
        return serviceRange.overlaps(existingWithBuffer) ||
            candidateWithBuffer.overlaps(bookingRange);
      });
      if (hitsBooking) {
        continue;
      }

      slots.add(
        AppointmentSlot(
          startTime: candidateStart,
          endTime: dayStart.add(Duration(minutes: serviceEnd)),
          serviceDurationMinutes: totalServiceDurationMinutes,
          cleanupBufferMinutes: buffer,
        ),
      );
    }

    return List<AppointmentSlot>.unmodifiable(slots);
  }

  /// Verifies that a chosen [slotStart] is still open before committing a booking.
  bool isSlotAvailable({
    required TechAvailabilitySchedule schedule,
    required DateTime slotStart,
    required int totalServiceDurationMinutes,
    List<ExistingCalendarBooking> existingBookings =
        const <ExistingCalendarBooking>[],
    DateTime? now,
  }) {
    final slots = generateAvailableSlots(
      schedule: schedule,
      date: slotStart,
      totalServiceDurationMinutes: totalServiceDurationMinutes,
      existingBookings: existingBookings,
      now: now,
    );
    return slots.any((slot) => slot.startTime == slotStart);
  }
}
