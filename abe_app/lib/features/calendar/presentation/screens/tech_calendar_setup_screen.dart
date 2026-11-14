import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/models/calendar_models.dart';

/// Nail Technician screen for configuring weekly studio hours, cleanup buffers,
/// and date-specific blocked time windows.
class TechCalendarSetupScreen extends StatefulWidget {
  const TechCalendarSetupScreen({
    super.key,
    required this.initialSchedule,
    this.onSave,
    this.onBack,
  });

  final TechAvailabilitySchedule initialSchedule;
  final ValueChanged<TechAvailabilitySchedule>? onSave;
  final VoidCallback? onBack;

  @override
  State<TechCalendarSetupScreen> createState() =>
      _TechCalendarSetupScreenState();
}

class _TechCalendarSetupScreenState extends State<TechCalendarSetupScreen> {
  late Map<int, DayWorkingHours> _weeklyHours;
  late Map<String, List<TimeRange>> _blockedWindowsByDate;
  late int _cleanupBufferMinutes;
  DateTime _selectedBlockDate = DateTime.now().add(const Duration(days: 1));
  final int _blockStartMinutes = 11 * 60;
  final int _blockEndMinutes = 13 * 60;

  static const List<int> _startOptions = <int>[
    7 * 60,
    8 * 60,
    9 * 60,
    10 * 60,
    11 * 60,
  ];

  static const List<int> _endOptions = <int>[
    15 * 60,
    16 * 60,
    17 * 60,
    17 * 60 + 30,
    18 * 60,
    19 * 60,
  ];

  static const List<int> _bufferOptions = <int>[10, 15, 20, 30];

  @override
  void initState() {
    super.initState();
    _weeklyHours = Map<int, DayWorkingHours>.from(
      widget.initialSchedule.weeklyHours,
    );
    _blockedWindowsByDate = widget.initialSchedule.blockedWindowsByDate.map(
      (key, value) => MapEntry<String, List<TimeRange>>(
        key,
        List<TimeRange>.from(value),
      ),
    );
    _cleanupBufferMinutes = widget.initialSchedule.cleanupBufferMinutes;
  }

  TechAvailabilitySchedule _buildSchedule() {
    return widget.initialSchedule.copyWith(
      weeklyHours: _weeklyHours,
      blockedWindowsByDate: _blockedWindowsByDate,
      cleanupBufferMinutes: _cleanupBufferMinutes,
    );
  }

  void _toggleDay(int weekday, bool enabled) {
    final current = _weeklyHours[weekday];
    final fallbackWindow = TimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60);
    setState(() {
      _weeklyHours[weekday] = DayWorkingHours(
        weekday: weekday,
        isWorkingDay: enabled,
        workingWindow:
            enabled ? (current?.workingWindow ?? fallbackWindow) : null,
        breakWindows: current?.breakWindows ?? const <TimeRange>[],
      );
    });
  }

  void _updateWorkingWindow(int weekday, int startMins, int endMins) {
    if (endMins <= startMins) return;
    final current = _weeklyHours[weekday];
    if (current == null) return;
    setState(() {
      _weeklyHours[weekday] = current.copyWith(
        isWorkingDay: true,
        workingWindow: TimeRange(startMinutes: startMins, endMinutes: endMins),
      );
    });
  }

  void _toggleLunchBreak(int weekday, bool hasLunch) {
    final current = _weeklyHours[weekday];
    if (current == null || !current.isWorkingDay) return;
    setState(() {
      _weeklyHours[weekday] = current.copyWith(
        breakWindows: hasLunch
            ? <TimeRange>[
                TimeRange(startMinutes: 13 * 60, endMinutes: 13 * 60 + 45),
              ]
            : const <TimeRange>[],
      );
    });
  }

  void _addBlockedWindow() {
    if (_blockEndMinutes <= _blockStartMinutes) return;
    final key = TechAvailabilitySchedule.dateKey(_selectedBlockDate);
    final existing = List<TimeRange>.from(
      _blockedWindowsByDate[key] ?? const <TimeRange>[],
    );
    existing.add(
      TimeRange(startMinutes: _blockStartMinutes, endMinutes: _blockEndMinutes),
    );
    setState(() {
      _blockedWindowsByDate[key] = existing;
    });
  }

  void _removeBlockedWindow(String dateKey, int index) {
    final existing = List<TimeRange>.from(
      _blockedWindowsByDate[dateKey] ?? const <TimeRange>[],
    );
    if (index < 0 || index >= existing.length) return;
    existing.removeAt(index);
    setState(() {
      if (existing.isEmpty) {
        _blockedWindowsByDate.remove(dateKey);
      } else {
        _blockedWindowsByDate[dateKey] = existing;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeDaysCount =
        _weeklyHours.values.where((day) => day.isWorkingDay).length;

    return Scaffold(
      backgroundColor: BrandConfig.bgCream,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Studio Calendar & Hours'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: <Widget>[
                _buildCleanupBufferCard(context),
                const SizedBox(height: 16),
                Text(
                  'Weekly Studio Hours',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Clients only see open slots that fit their full look duration plus your sanitisation buffer.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BrandConfig.textMuted,
                      ),
                ),
                const SizedBox(height: 12),
                for (var weekday = DateTime.monday;
                    weekday <= DateTime.sunday;
                    weekday++) ...<Widget>[
                  _buildDayCard(context, weekday),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                _buildBlockTimeCard(context),
              ],
            ),
          ),
          _buildBottomSaveBar(context, activeDaysCount),
        ],
      ),
    );
  }

  Widget _buildCleanupBufferCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Workstation Reset Buffer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Time reserved automatically after every client for desk sanitisation.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BrandConfig.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bufferOptions.map((mins) {
              final selected = _cleanupBufferMinutes == mins;
              return ChoiceChip(
                label: Text('$mins mins'),
                selected: selected,
                selectedColor: BrandConfig.blushSoft,
                onSelected: (_) {
                  setState(() {
                    _cleanupBufferMinutes = mins;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, int weekday) {
    final day = _weeklyHours[weekday] ??
        DayWorkingHours(weekday: weekday, isWorkingDay: false);
    final window = day.workingWindow;
    final hasLunch = day.breakWindows.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      day.weekdayLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.isWorkingDay && window != null
                          ? window.formatRange()
                          : 'Day Off',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: day.isWorkingDay
                                ? BrandConfig.sageSuccess
                                : BrandConfig.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: ValueKey<String>('day_switch_$weekday'),
                value: day.isWorkingDay,
                activeThumbColor: BrandConfig.rosePrimary,
                onChanged: (value) => _toggleDay(weekday, value),
              ),
            ],
          ),
          if (day.isWorkingDay && window != null) ...<Widget>[
            const Divider(height: 18, color: BrandConfig.borderWarm),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _startOptions.contains(window.startMinutes)
                        ? window.startMinutes
                        : _startOptions.first,
                    decoration: const InputDecoration(
                      labelText: 'Opens',
                      isDense: true,
                    ),
                    items: _startOptions
                        .map(
                          (mins) => DropdownMenuItem<int>(
                            value: mins,
                            child: Text(TimeRange.formatMinutesOfDay(mins)),
                          ),
                        )
                        .toList(),
                    onChanged: (nextStart) {
                      if (nextStart != null) {
                        _updateWorkingWindow(
                          weekday,
                          nextStart,
                          window.endMinutes,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _endOptions.contains(window.endMinutes)
                        ? window.endMinutes
                        : _endOptions.last,
                    decoration: const InputDecoration(
                      labelText: 'Closes',
                      isDense: true,
                    ),
                    items: _endOptions
                        .map(
                          (mins) => DropdownMenuItem<int>(
                            value: mins,
                            child: Text(TimeRange.formatMinutesOfDay(mins)),
                          ),
                        )
                        .toList(),
                    onChanged: (nextEnd) {
                      if (nextEnd != null) {
                        _updateWorkingWindow(
                          weekday,
                          window.startMinutes,
                          nextEnd,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilterChip(
              label: const Text('Lunch Break (13:00 - 13:45)'),
              selected: hasLunch,
              selectedColor: BrandConfig.blushSoft,
              onSelected: (selected) => _toggleLunchBreak(weekday, selected),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockTimeCard(BuildContext context) {
    final dateKey = TechAvailabilitySchedule.dateKey(_selectedBlockDate);
    final allBlockedEntries = _blockedWindowsByDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandConfig.surfaceCard,
        borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
        border: Border.all(color: BrandConfig.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Block Specific Time Off',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reserve personal time or stock-up errands on a specific date.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BrandConfig.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedBlockDate = _selectedBlockDate.add(
                        const Duration(days: 1),
                      );
                    });
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('Date: $dateKey'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                key: const Key('add_block_time_button'),
                onPressed: _addBlockedWindow,
                child: const Text('Block 11:00 - 13:00'),
              ),
            ],
          ),
          if (allBlockedEntries.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final entry in allBlockedEntries)
              for (var i = 0; i < entry.value.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.event_busy_outlined,
                        size: 16,
                        color: BrandConfig.roseDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${entry.key} (${entry.value[i].formatRange()})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove blocked window',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => _removeBlockedWindow(entry.key, i),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar(BuildContext context, int activeDaysCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: BrandConfig.surfaceCard,
        border: Border(top: BorderSide(color: BrandConfig.borderWarm)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$activeDaysCount active studio days',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '$_cleanupBufferMinutes min reset buffer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BrandConfig.textMuted,
                        ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              key: const Key('save_studio_hours_button'),
              onPressed: () {
                final updated = _buildSchedule();
                widget.onSave?.call(updated);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Studio calendar hours saved.'),
                  ),
                );
              },
              child: const Text('Save Studio Hours'),
            ),
          ],
        ),
      ),
    );
  }
}
