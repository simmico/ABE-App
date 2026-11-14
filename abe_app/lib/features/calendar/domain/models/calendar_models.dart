import '../../../../core/utils/input_sanitiser.dart';

/// Represents a minute-of-day interval `[startMinutes, endMinutes)` within a single day.
class TimeRange {
  TimeRange({
    required this.startMinutes,
    required this.endMinutes,
  }) {
    if (startMinutes < 0 || startMinutes >= 1440) {
      throw ArgumentError.value(
        startMinutes,
        'startMinutes',
        'Must be between 0 and 1439.',
      );
    }
    if (endMinutes <= startMinutes || endMinutes > 1440) {
      throw ArgumentError.value(
        endMinutes,
        'endMinutes',
        'Must be greater than startMinutes and at most 1440.',
      );
    }
  }

  /// Minutes from midnight (`0` = 00:00, `540` = 09:00).
  final int startMinutes;

  /// Minutes from midnight (`1020` = 17:00, `1440` = 24:00).
  final int endMinutes;

  int get durationMinutes => endMinutes - startMinutes;

  /// Returns true if this interval overlaps [other] (touching endpoints do not overlap).
  bool overlaps(TimeRange other) {
    return startMinutes < other.endMinutes && other.startMinutes < endMinutes;
  }

  /// Returns true if this interval fully contains [other].
  bool contains(TimeRange other) {
    return startMinutes <= other.startMinutes && endMinutes >= other.endMinutes;
  }

  String formatStart() => formatMinutesOfDay(startMinutes);

  String formatEnd() => formatMinutesOfDay(endMinutes);

  String formatRange() => '${formatStart()} - ${formatEnd()}';

  static String formatMinutesOfDay(int minutes) {
    final clamped = minutes.clamp(0, 1440);
    final hours = (clamped ~/ 60).toString().padLeft(2, '0');
    final mins = (clamped % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is TimeRange &&
        other.startMinutes == startMinutes &&
        other.endMinutes == endMinutes;
  }

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);
}

/// Weekly working hours and recurring breaks for a single day of the week.
class DayWorkingHours {
  DayWorkingHours({
    required this.weekday,
    required this.isWorkingDay,
    this.workingWindow,
    List<TimeRange> breakWindows = const <TimeRange>[],
  }) : breakWindows = List<TimeRange>.unmodifiable(breakWindows) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(
        weekday,
        'weekday',
        'Weekday must be between 1 (Monday) and 7 (Sunday).',
      );
    }
    if (isWorkingDay && workingWindow == null) {
      throw ArgumentError(
        'A working day must define a valid workingWindow.',
      );
    }
  }

  /// ISO weekday (`1` = Monday through `7` = Sunday).
  final int weekday;
  final bool isWorkingDay;
  final TimeRange? workingWindow;
  final List<TimeRange> breakWindows;

  String get weekdayLabel {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Day $weekday';
    }
  }

  DayWorkingHours copyWith({
    bool? isWorkingDay,
    TimeRange? workingWindow,
    List<TimeRange>? breakWindows,
  }) {
    final nextWorking = isWorkingDay ?? this.isWorkingDay;
    return DayWorkingHours(
      weekday: weekday,
      isWorkingDay: nextWorking,
      workingWindow: nextWorking ? (workingWindow ?? this.workingWindow) : null,
      breakWindows: breakWindows ?? this.breakWindows,
    );
  }

  factory DayWorkingHours.fromJson(Map<String, dynamic> json) {
    final isWorking = json['isWorkingDay'] as bool? ?? false;
    final rawWindow = json['workingWindow'] as Map<String, dynamic>?;
    final rawBreaks = (json['breakWindows'] as List<dynamic>?) ?? <dynamic>[];
    return DayWorkingHours(
      weekday: (json['weekday'] as num?)?.toInt() ?? DateTime.monday,
      isWorkingDay: isWorking,
      workingWindow: rawWindow != null ? TimeRange.fromJson(rawWindow) : null,
      breakWindows: rawBreaks
          .whereType<Map<String, dynamic>>()
          .map(TimeRange.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weekday': weekday,
      'isWorkingDay': isWorkingDay,
      'workingWindow': workingWindow?.toJson(),
      'breakWindows': breakWindows.map((b) => b.toJson()).toList(),
    };
  }
}

/// Complete availability schedule for a Nail Technician.
class TechAvailabilitySchedule {
  TechAvailabilitySchedule({
    required String techId,
    required Map<int, DayWorkingHours> weeklyHours,
    Map<String, List<TimeRange>> blockedWindowsByDate =
        const <String, List<TimeRange>>{},
    this.cleanupBufferMinutes = 15,
    this.slotStepMinutes = 15,
  })  : techId = InputSanitiser.sanitiseText(techId, maxLength: 128),
        weeklyHours = Map<int, DayWorkingHours>.unmodifiable(weeklyHours),
        blockedWindowsByDate = Map<String, List<TimeRange>>.unmodifiable(
          blockedWindowsByDate.map(
            (key, value) => MapEntry<String, List<TimeRange>>(
              InputSanitiser.sanitiseText(key, maxLength: 16),
              List<TimeRange>.unmodifiable(value),
            ),
          ),
        ) {
    if (this.techId.isEmpty) {
      throw ArgumentError('TechAvailabilitySchedule.techId cannot be empty.');
    }
    if (cleanupBufferMinutes < 0 || cleanupBufferMinutes > 60) {
      throw ArgumentError.value(
        cleanupBufferMinutes,
        'cleanupBufferMinutes',
        'Cleanup buffer must be between 0 and 60 minutes.',
      );
    }
    if (slotStepMinutes < 5 || slotStepMinutes > 60) {
      throw ArgumentError.value(
        slotStepMinutes,
        'slotStepMinutes',
        'Slot step must be between 5 and 60 minutes.',
      );
    }
  }

  final String techId;
  final Map<int, DayWorkingHours> weeklyHours;

  /// Date-specific blocked windows keyed by `'YYYY-MM-DD'`.
  final Map<String, List<TimeRange>> blockedWindowsByDate;

  /// Sanitisation and workstation reset buffer added between consecutive bookings.
  final int cleanupBufferMinutes;

  /// Interval between candidate start times (e.g. every 15 or 30 minutes).
  final int slotStepMinutes;

  static String dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Creates a sensible default Tuesday-Saturday studio schedule (09:00 - 17:30, 13:00 - 13:45 lunch).
  factory TechAvailabilitySchedule.defaultStudio({required String techId}) {
    final defaultWindow = TimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60 + 30);
    final lunchBreak = TimeRange(startMinutes: 13 * 60, endMinutes: 13 * 60 + 45);
    return TechAvailabilitySchedule(
      techId: techId,
      weeklyHours: <int, DayWorkingHours>{
        DateTime.monday: DayWorkingHours(
          weekday: DateTime.monday,
          isWorkingDay: false,
        ),
        DateTime.tuesday: DayWorkingHours(
          weekday: DateTime.tuesday,
          isWorkingDay: true,
          workingWindow: defaultWindow,
          breakWindows: <TimeRange>[lunchBreak],
        ),
        DateTime.wednesday: DayWorkingHours(
          weekday: DateTime.wednesday,
          isWorkingDay: true,
          workingWindow: defaultWindow,
          breakWindows: <TimeRange>[lunchBreak],
        ),
        DateTime.thursday: DayWorkingHours(
          weekday: DateTime.thursday,
          isWorkingDay: true,
          workingWindow: defaultWindow,
          breakWindows: <TimeRange>[lunchBreak],
        ),
        DateTime.friday: DayWorkingHours(
          weekday: DateTime.friday,
          isWorkingDay: true,
          workingWindow: defaultWindow,
          breakWindows: <TimeRange>[lunchBreak],
        ),
        DateTime.saturday: DayWorkingHours(
          weekday: DateTime.saturday,
          isWorkingDay: true,
          workingWindow: TimeRange(startMinutes: 9 * 60, endMinutes: 15 * 60),
        ),
        DateTime.sunday: DayWorkingHours(
          weekday: DateTime.sunday,
          isWorkingDay: false,
        ),
      },
    );
  }

  TechAvailabilitySchedule copyWith({
    Map<int, DayWorkingHours>? weeklyHours,
    Map<String, List<TimeRange>>? blockedWindowsByDate,
    int? cleanupBufferMinutes,
    int? slotStepMinutes,
  }) {
    return TechAvailabilitySchedule(
      techId: techId,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      blockedWindowsByDate: blockedWindowsByDate ?? this.blockedWindowsByDate,
      cleanupBufferMinutes: cleanupBufferMinutes ?? this.cleanupBufferMinutes,
      slotStepMinutes: slotStepMinutes ?? this.slotStepMinutes,
    );
  }
}

/// Lightweight representation of an existing booking that occupies a tech's calendar.
class ExistingCalendarBooking {
  ExistingCalendarBooking({
    required String bookingId,
    required this.startTime,
    required this.endTime,
    String status = 'confirmed',
  })  : bookingId = InputSanitiser.sanitiseText(bookingId, maxLength: 128),
        status = InputSanitiser.sanitiseText(status, maxLength: 40) {
    if (this.bookingId.isEmpty) {
      throw ArgumentError('ExistingCalendarBooking.bookingId cannot be empty.');
    }
    if (!endTime.isAfter(startTime)) {
      throw ArgumentError('ExistingCalendarBooking.endTime must be after startTime.');
    }
  }

  final String bookingId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  /// Cancelled bookings release their chair time back into the slot pool.
  bool get blocksCalendar => !status.startsWith('cancelled');
}

/// An open, bookable appointment slot generated for a specific Visual Contract duration.
class AppointmentSlot {
  const AppointmentSlot({
    required this.startTime,
    required this.endTime,
    required this.serviceDurationMinutes,
    required this.cleanupBufferMinutes,
  });

  final DateTime startTime;
  final DateTime endTime;
  final int serviceDurationMinutes;
  final int cleanupBufferMinutes;

  String get formattedStartTime {
    final hours = startTime.hour.toString().padLeft(2, '0');
    final mins = startTime.minute.toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  String get formattedEndTime {
    final hours = endTime.hour.toString().padLeft(2, '0');
    final mins = endTime.minute.toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  String get formattedRange => '$formattedStartTime - $formattedEndTime';

  @override
  bool operator ==(Object other) {
    return other is AppointmentSlot &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.serviceDurationMinutes == serviceDurationMinutes &&
        other.cleanupBufferMinutes == cleanupBufferMinutes;
  }

  @override
  int get hashCode => Object.hash(
        startTime,
        endTime,
        serviceDurationMinutes,
        cleanupBufferMinutes,
      );
}
