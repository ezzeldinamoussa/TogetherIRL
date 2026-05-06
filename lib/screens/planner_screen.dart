// ─────────────────────────────────────────────────────────────
// planner_screen.dart  –  Day itinerary view
// Mirrors the React <DayPlanner> component
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/models.dart';
import '../models/sample_data.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  static final DateTime _today = DateTime(2026, 3, 8);

  DateTime _focusedDay = DateTime(2026, 3, 8);
  DateTime _selectedDay = DateTime(2026, 3, 8);

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<ItineraryStop> get _currentItinerary {
    for (final entry in sampleItinerariesByDate.entries) {
      if (_isSameDate(entry.key, _selectedDay)) return entry.value;
    }
    return [];
  }

  void _goToToday() => setState(() {
        _selectedDay = _today;
        _focusedDay = _today;
      });

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  List<Map<String, String>> _getCalendarEventsForDay(DateTime day) {
    for (final entry in sampleCalendarEvents.entries) {
      if (_isSameDate(entry.key, day)) return entry.value;
    }
    return [];
  }

  List<dynamic> _getEventMarkersForDay(DateTime day) =>
      _getCalendarEventsForDay(day);

  void _openCalendarDialog() {
    showDialog(
      context: context,
      builder: (context) {
        DateTime tempFocusedDay = _focusedDay;
        DateTime tempSelectedDay = _selectedDay;
        bool showDayDetails = false;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedEvents = _getCalendarEventsForDay(tempSelectedDay);

              return Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top row: title + close whole calendar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select a Date',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Calendar
                      TableCalendar<dynamic>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: tempFocusedDay,
                        selectedDayPredicate: (day) {
                          return isSameDay(tempSelectedDay, day);
                        },
                        eventLoader: _getEventMarkersForDay,
                        onDaySelected: (selectedDay, focusedDay) {
                          setDialogState(() {
                            tempSelectedDay = selectedDay;
                            tempFocusedDay = focusedDay;
                            showDayDetails = true;
                          });

                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        calendarFormat: CalendarFormat.month,
                        calendarStyle: CalendarStyle(
                          todayDecoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 1,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Details panel inside same popup
                      if (showDayDetails)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Plans for ${tempSelectedDay.month}/${tempSelectedDay.day}/${tempSelectedDay.year}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        showDayDetails = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close, size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (selectedEvents.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No events planned for this day.',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                )
                              else
                                ...selectedEvents.map((event) {
                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      leading: const Icon(Icons.event_note),
                                      title: Text(event['title'] ?? ''),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Time: ${event['time'] ?? ''}'),
                                          Text(
                                              'Group: ${event['group'] ?? ''}'),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = _currentItinerary;
    final hasItinerary = itinerary.isNotEmpty;
    final totalDistance = itinerary.fold<double>(
      0,
      (sum, s) => sum + double.parse(s.distance.replaceAll(' mi', '')),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date header row ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthName(_selectedDay.month)} ${_selectedDay.day}, ${_selectedDay.year}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _goToToday,
                child: const Text('Today'),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _openCalendarDialog,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_month,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasItinerary) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryStat(
                      icon: Icons.place,
                      label: 'Total distance',
                      value: '${totalDistance.toStringAsFixed(1)} mi',
                    ),
                    _SummaryStat(
                      icon: Icons.attach_money,
                      label: 'Est. budget',
                      value: r'$35–45',
                    ),
                    _SummaryStat(
                      icon: Icons.schedule,
                      label: 'Duration',
                      value: '~5 hrs',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const SectionTitle('Itinerary'),
            const SizedBox(height: 12),

            ...itinerary.asMap().entries.map((entry) {
              final i = entry.key;
              final stop = entry.value;
              final isLast = i == itinerary.length - 1;

              return Column(
                children: [
                  _ItineraryCard(stop: stop, index: i),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 28),
                          Container(
                            width: 2,
                            height: 24,
                            color: AppTheme.border,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.directions_walk,
                            size: 14,
                            color: AppTheme.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          SubTitle('${itinerary[i + 1].distance} walk'),
                        ],
                      ),
                    ),
                ],
              );
            }),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Start Navigation'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate Plan'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 64, color: AppTheme.border),
                  const SizedBox(height: 16),
                  const Text(
                    'No hangout planned',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SubTitle('Tap the calendar to pick a day with plans,\nor use Today to jump back.'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          SubTitle(label),
        ],
      );
}

class _ItineraryCard extends StatelessWidget {
  final dynamic stop;
  final int index;

  const _ItineraryCard({required this.stop, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: NetImage(stop.imageUrl),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppBadge(stop.type, color: AppTheme.primary),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${stop.matchScore}% match',
                        style: const TextStyle(
                          color: AppTheme.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  stop.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Detail(Icons.schedule, stop.time),
                    _Detail(Icons.timer_outlined, stop.duration),
                    _Detail(Icons.place_outlined, stop.distance),
                    _Detail(Icons.attach_money, stop.priceRange),
                    _Detail(Icons.star, stop.rating.toString()),
                  ],
                ),
                const SizedBox(height: 8),
                SubTitle(stop.address),
                _PhotoQuestsSection(stopId: stop.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoQuestsSection extends StatelessWidget {
  final String stopId;
  const _PhotoQuestsSection({required this.stopId});

  @override
  Widget build(BuildContext context) {
    final quests = stopPhotoQuests[stopId];
    if (quests == null || quests.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt_outlined,
                    size: 14, color: AppTheme.green),
                const SizedBox(width: 6),
                Text(
                  'Photo ideas here',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...quests.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.mutedForeground)),
                    Expanded(
                      child: Text(q,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedForeground)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Detail(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.mutedForeground),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      );
}

