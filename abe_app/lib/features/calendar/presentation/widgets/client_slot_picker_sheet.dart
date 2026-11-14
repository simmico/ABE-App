import 'package:material_ui/material_ui.dart';

import '../../../../core/config/brand_config.dart';
import '../../domain/models/calendar_models.dart';
import '../../domain/services/slot_generator_service.dart';

/// Bottom-sheet / modal picker allowing clients to select an open date and
/// duration-aware appointment slot for their chosen Visual Contract.
class ClientSlotPickerSheet extends StatefulWidget {
  const ClientSlotPickerSheet({
    super.key,
    required this.schedule,
    required this.totalServiceDurationMinutes,
    this.existingBookings = const <ExistingCalendarBooking>[],
    this.initialDate,
    this.now,
    this.daysToShow = 7,
    this.slotGenerator = const SlotGeneratorService(),
    required this.onSlotConfirmed,
  });

  final TechAvailabilitySchedule schedule;
  final int totalServiceDurationMinutes;
  final List<ExistingCalendarBooking> existingBookings;
  final DateTime? initialDate;
  final DateTime? now;
  final int daysToShow;
  final SlotGeneratorService slotGenerator;
  final ValueChanged<AppointmentSlot> onSlotConfirmed;

  @override
  State<ClientSlotPickerSheet> createState() => _ClientSlotPickerSheetState();
}

class _ClientSlotPickerSheetState extends State<ClientSlotPickerSheet> {
  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  AppointmentSlot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? widget.now ?? DateTime.now();
    final startDay = DateTime(base.year, base.month, base.day);
    _dates = List<DateTime>.generate(
      widget.daysToShow,
      (index) => startDay.add(Duration(days: index)),
    );
    _selectedDate = _dates.first;
    for (final date in _dates) {
      if (_slotsForDate(date).isNotEmpty) {
        _selectedDate = date;
        break;
      }
    }
  }

  List<AppointmentSlot> _slotsForDate(DateTime date) {
    return widget.slotGenerator.generateAvailableSlots(
      schedule: widget.schedule,
      date: date,
      totalServiceDurationMinutes: widget.totalServiceDurationMinutes,
      existingBookings: widget.existingBookings,
      now: widget.now,
    );
  }

  static String _shortWeekday(int weekday) {
    const names = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return names[weekday] ?? '';
  }

  static String _shortMonth(int month) {
    const names = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    };
    return names[month] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final openSlots = _slotsForDate(_selectedDate);

    return Container(
      decoration: const BoxDecoration(
        color: BrandConfig.bgCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BrandConfig.borderWarm,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose Your Chair Time',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BrandConfig.blushSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${widget.totalServiceDurationMinutes} mins total look duration',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: BrandConfig.roseDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final date = _dates[index];
                    final isSelected = date == _selectedDate;
                    final hasOpen = _slotsForDate(date).isNotEmpty;

                    return GestureDetector(
                      key: Key('date_chip_${TechAvailabilitySchedule.dateKey(date)}'),
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                          _selectedSlot = null;
                        });
                      },
                      child: Container(
                        width: 68,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? BrandConfig.rosePrimary
                              : BrandConfig.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? BrandConfig.rosePrimary
                                : BrandConfig.borderWarm,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              _shortWeekday(date.weekday),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: isSelected
                                        ? BrandConfig.surfaceCard
                                        : BrandConfig.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${date.day} ${_shortMonth(date.month)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: isSelected
                                        ? BrandConfig.surfaceCard
                                        : BrandConfig.espresso,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? BrandConfig.surfaceCard
                                    : (hasOpen
                                        ? BrandConfig.sageSuccess
                                        : BrandConfig.borderWarm),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (openSlots.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: BrandConfig.surfaceCard,
                    borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
                    border: Border.all(color: BrandConfig.borderWarm),
                  ),
                  child: Text(
                    'No open chairs on this date. Select another day above.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BrandConfig.textMuted,
                        ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: openSlots.map((slot) {
                        final isSelected = _selectedSlot == slot;
                        return ChoiceChip(
                          key: Key('slot_chip_${slot.formattedStartTime}'),
                          label: Text(slot.formattedStartTime),
                          selected: isSelected,
                          selectedColor: BrandConfig.rosePrimary,
                          backgroundColor: BrandConfig.surfaceCard,
                          labelStyle: TextStyle(
                            fontFamily: BrandConfig.bodyFontFamily,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? BrandConfig.surfaceCard
                                : BrandConfig.espresso,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedSlot = slot;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('confirm_slot_button'),
                  onPressed: _selectedSlot == null
                      ? null
                      : () => widget.onSlotConfirmed(_selectedSlot!),
                  child: Text(
                    _selectedSlot == null
                        ? 'Select a Time Slot'
                        : 'Confirm ${_selectedSlot!.formattedRange}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
