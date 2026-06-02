import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../screens/weekly_review_screen.dart';
import '../services/sound_service.dart';

class WeeklyCalendarWidget extends StatefulWidget {
  final List<Habit> habits;
  final VoidCallback? onDateTap;

  const WeeklyCalendarWidget({
    super.key,
    required this.habits,
    this.onDateTap,
  });

  @override
  State<WeeklyCalendarWidget> createState() => _WeeklyCalendarWidgetState();
}

class _WeeklyCalendarWidgetState extends State<WeeklyCalendarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(DateTime.now());
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _dateKey(DateTime d) => d.toString().split(' ')[0];
  bool _isToday(DateTime d) => _dateKey(d) == _dateKey(DateTime.now());

  int _getCompletedCount(DateTime d) {
    final key = _dateKey(d);
    return widget.habits.where((h) => h.completedDates.contains(key)).length;
  }

  double _getCompletionPercent(DateTime d) {
    if (widget.habits.isEmpty) return 0;
    return _getCompletedCount(d) / widget.habits.length;
  }

  double _getWeekAverage() {
    if (widget.habits.isEmpty) return 0;
    double total = 0;
    int daysCount = 0;
    for (int i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      if (!day.isAfter(DateTime.now())) {
        total += _getCompletionPercent(day);
        daysCount++;
      }
    }
    return daysCount > 0 ? total / daysCount : 0;
  }

  void _openWeeklyReview() {
    SoundService.playTap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklyReviewScreen(habits: widget.habits),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final weekAvg = _getWeekAverage();

    return FadeTransition(
      opacity: CurvedAnimation(parent: _animController, curve: Curves.easeIn),
      child: GestureDetector(
        onTap: _openWeeklyReview,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C2F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(isDark, weekAvg),

              // Week days
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                child: Row(
                  children: days.map((day) {
                    return Expanded(
                      child: _buildDayCell(day, isDark),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, double weekAvg) {
    final weekRange =
        '${DateFormat('MMM d').format(_weekStart)} — ${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '📅 This Week',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Week average badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: weekAvg >= 0.8
                            ? AppConfig.successColor.withOpacity(0.15)
                            : weekAvg >= 0.5
                            ? AppConfig.warningColor.withOpacity(0.15)
                            : AppConfig.accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(weekAvg * 100).toInt()}% avg',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: weekAvg >= 0.8
                              ? AppConfig.successColor
                              : weekAvg >= 0.5
                              ? AppConfig.warningColor
                              : AppConfig.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  weekRange,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          // View details button
          GestureDetector(
            onTap: _openWeeklyReview,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppConfig.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppConfig.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppConfig.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime day, bool isDark) {
    final isToday = _isToday(day);
    final isFuture = day.isAfter(DateTime.now());
    final completionPercent = _getCompletionPercent(day);
    final completedCount = _getCompletedCount(day);
    final dayName = DateFormat('E').format(day).substring(0, 2);
    final dayNum = day.day.toString();

    // Determine dot color based on completion
    Color dotColor;
    Color? ringColor;
    if (isFuture) {
      dotColor = Colors.transparent;
    } else if (completionPercent >= 1.0) {
      dotColor = AppConfig.successColor;
      ringColor = AppConfig.successColor;
    } else if (completionPercent >= 0.5) {
      dotColor = AppConfig.warningColor;
      ringColor = AppConfig.warningColor;
    } else if (completionPercent > 0) {
      dotColor = AppConfig.accentColor;
      ringColor = AppConfig.accentColor;
    } else {
      dotColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        children: [
          // Day name
          Text(
            dayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isToday
                  ? AppConfig.primaryColor
                  : isFuture
                  ? (isDark ? Colors.white24 : Colors.grey.shade400)
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          const SizedBox(height: 8),

          // Day number with ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Ring background
              if (!isFuture && widget.habits.isNotEmpty && completionPercent > 0)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: completionPercent,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                    isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        ringColor ?? Colors.grey),
                  ),
                ),

              // Day number
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isToday ? 36 : 32,
                height: isToday ? 36 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? AppConfig.primaryColor
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: isToday ? 16 : 14,
                      fontWeight: FontWeight.w900,
                      color: isToday
                          ? Colors.white
                          : isFuture
                          ? (isDark
                          ? Colors.white24
                          : Colors.grey.shade400)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Completion dot
          if (!isFuture && widget.habits.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: completionPercent >= 1.0 ? 10 : 7,
              height: completionPercent >= 1.0 ? 10 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: completionPercent >= 1.0
                    ? [
                  BoxShadow(
                    color: AppConfig.successColor.withOpacity(0.5),
                    blurRadius: 6,
                  )
                ]
                    : null,
              ),
              child: completionPercent >= 1.0
                  ? const Icon(Icons.check_rounded,
                  size: 8, color: Colors.white)
                  : null,
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}