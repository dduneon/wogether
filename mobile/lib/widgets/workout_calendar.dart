import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/calendar_api.dart';
import '../utils/theme.dart';

class WorkoutCalendarWidget extends StatefulWidget {
  const WorkoutCalendarWidget({super.key});

  @override
  State<WorkoutCalendarWidget> createState() => _WorkoutCalendarWidgetState();
}

class _WorkoutCalendarWidgetState extends State<WorkoutCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  Set<String> get _workoutDates => Set<String>.from((_data?['workout_dates'] as List?) ?? []);
  int get _streak => (_data?['streak'] as int?) ?? 0;

  Map<String, List> get _logsByDate {
    final raw = (_data?['logs_by_date'] as Map?) ?? {};
    return raw.map((k, v) => MapEntry(k as String, v as List));
  }

  @override
  void initState() {
    super.initState();
    _loadMonth(_focusedDay);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() { _loading = true; });
    try {
      final d = await CalendarApi.getWorkoutCalendar(year: month.year, month: month.month);
      print('[Calendar] loaded: dates=${d['workout_dates']}, streak=${d['streak']}');
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      print('[Calendar] error: $e');
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  bool _hasWorkout(DateTime day) {
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _workoutDates.contains(key);
  }

  String _dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Widget? _dayCell(DateTime day, {required bool isToday, required bool isSelected}) {
    final hasWorkout = _hasWorkout(day);
    if (!hasWorkout && !isToday && !isSelected) return null;

    Color? bgColor;
    Color textColor;
    Color? borderColor;

    if (isSelected && hasWorkout) {
      bgColor = WColors.purple;
      textColor = Colors.white;
      borderColor = null;
    } else if (isSelected) {
      bgColor = WColors.purple.withValues(alpha: 0.5);
      textColor = Colors.white;
      borderColor = null;
    } else if (hasWorkout && isToday) {
      bgColor = WColors.purple.withValues(alpha: 0.3);
      textColor = WColors.purpleL;
      borderColor = WColors.purple.withValues(alpha: 0.7);
    } else if (hasWorkout) {
      bgColor = WColors.purple.withValues(alpha: 0.18);
      textColor = WColors.purpleL;
      borderColor = WColors.purple.withValues(alpha: 0.4);
    } else {
      // isToday only, no workout
      bgColor = WColors.purple.withValues(alpha: 0.1);
      textColor = WColors.purpleL;
      borderColor = WColors.purple.withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
          if (hasWorkout)
            Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : WColors.purple,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: WColors.purple.withValues(alpha: 0.7), blurRadius: 4)],
              ),
            ),
        ],
      ),
    );
  }

  List _selectedLogs() {
    if (_selectedDay == null) return [];
    return _logsByDate[_dateKey(_selectedDay!)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WColors.bg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Text('📅 ', style: TextStyle(fontSize: 16)),
                Text('운동 달력',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WColors.text)),
                const SizedBox(width: 10),
                if (_streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0x33a855f7), Color(0x2222d3ee)]),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: WColors.purple.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '🔥 $_streak일 연속',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WColors.purpleL),
                    ),
                  ),
              ],
            ),
          ),

          // 달력
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime(2024),
            lastDay: DateTime(2027),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: WColors.text),
              leftChevronIcon: Icon(Icons.chevron_left_rounded, color: WColors.textMuted, size: 20),
              rightChevronIcon: Icon(Icons.chevron_right_rounded, color: WColors.textMuted, size: 20),
              headerPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WColors.textMuted),
              weekendStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WColors.textMuted),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(fontSize: 13, color: WColors.textMuted),
              weekendTextStyle: TextStyle(fontSize: 13, color: WColors.textMuted),
              todayDecoration: BoxDecoration(
                color: WColors.purple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: WColors.purple.withValues(alpha: 0.5)),
              ),
              todayTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: WColors.purpleL),
              selectedDecoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFa855f7), Color(0xFF22d3ee)],
                ),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              cellMargin: const EdgeInsets.all(4),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, _) => _dayCell(day, isToday: false, isSelected: false),
              todayBuilder: (ctx, day, _) => _dayCell(day, isToday: true, isSelected: false),
              selectedBuilder: (ctx, day, _) => _dayCell(day, isToday: false, isSelected: true),
            ),
            onDaySelected: (selected, focused) {
              if (_hasWorkout(selected)) {
                setState(() {
                  _selectedDay = isSameDay(_selectedDay, selected) ? null : selected;
                  _focusedDay = focused;
                });
              }
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _selectedDay = null;
              _loadMonth(focused);
            },
          ),

          // 선택한 날 로그
          if (_selectedDay != null) ...[
            Divider(color: WColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                '${_dateKey(_selectedDay!)} · ${_selectedLogs().length}회 운동',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: WColors.textMuted, letterSpacing: 0.5),
              ),
            ),
            ..._selectedLogs().map((log) => _LogTile(log: log as Map)),
          ],

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (!_loading && _error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text('오류: $_error', style: TextStyle(fontSize: 11, color: WColors.textMuted)),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final imageUrl = log['representative_image_url'] as String?;
    final crewName = log['crew_name'] as String? ?? '크루';
    final caption = log['caption'] as String?;
    final likeCount = (log['like_count'] as int?) ?? 0;
    final timestamp = log['timestamp'] as String?;
    String timeStr = '';
    if (timestamp != null) {
      try {
        final dt = DateTime.parse(timestamp).toLocal();
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 48, height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 48, height: 48, color: WColors.border),
                    errorWidget: (_, __, ___) => _PlaceholderBox(),
                  )
                : _PlaceholderBox(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crewName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WColors.text)),
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(caption,
                      style: TextStyle(fontSize: 12, color: WColors.textMuted),
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 3),
                Text(
                  '$timeStr${likeCount > 0 ? ' · ❤️ $likeCount' : ''}',
                  style: TextStyle(fontSize: 11, color: WColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: WColors.border,
      borderRadius: BorderRadius.circular(8),
    ),
    alignment: Alignment.center,
    child: const Text('🏋️', style: TextStyle(fontSize: 22)),
  );
}
