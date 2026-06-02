import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/sound_service.dart';

class WeeklyReviewScreen extends StatefulWidget {
  final List<Habit> habits;
  const WeeklyReviewScreen({super.key, required this.habits});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _statsAnimController;
  late AnimationController _cardAnimController;
  late DateTime _weekStart;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekStart = _getWeekStart(DateTime.now());

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _statsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _statsAnimController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  String _dateKey(DateTime d) => d.toString().split(' ')[0];
  bool _isToday(DateTime d) => _dateKey(d) == _dateKey(DateTime.now());
  bool _isSelected(DateTime d) => _dateKey(d) == _dateKey(_selectedDate);

  int _getCompletedCount(DateTime d) {
    final key = _dateKey(d);
    return widget.habits.where((h) => h.completedDates.contains(key)).length;
  }

  double _getCompletionPercent(DateTime d) {
    if (widget.habits.isEmpty) return 0;
    return _getCompletedCount(d) / widget.habits.length;
  }

  List<Habit> _getCompletedHabits(DateTime d) {
    final key = _dateKey(d);
    return widget.habits.where((h) => h.completedDates.contains(key)).toList();
  }

  List<Habit> _getMissedHabits(DateTime d) {
    final key = _dateKey(d);
    return widget.habits.where((h) => !h.completedDates.contains(key)).toList();
  }

  double _getWeekAverage() {
    if (widget.habits.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      if (!day.isAfter(DateTime.now())) {
        total += _getCompletionPercent(day);
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  int _getPerfectDays() {
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      if (!day.isAfter(DateTime.now()) && _getCompletionPercent(day) >= 1.0) {
        count++;
      }
    }
    return count;
  }

  int _getTotalCompletedThisWeek() {
    int total = 0;
    for (int i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      if (!day.isAfter(DateTime.now())) {
        total += _getCompletedCount(day);
      }
    }
    return total;
  }

  String _getBestDay() {
    double best = -1;
    DateTime bestDay = _weekStart;
    for (int i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      if (!day.isAfter(DateTime.now())) {
        final p = _getCompletionPercent(day);
        if (p > best) {
          best = p;
          bestDay = day;
        }
      }
    }
    return DateFormat('EEEE').format(bestDay);
  }

  void _previousWeek() {
    HapticFeedback.lightImpact();
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _selectedDate = _weekStart;
      _animController.reset();
      _animController.forward();
      _cardAnimController.reset();
      _cardAnimController.forward();
    });
  }

  void _nextWeek() {
    final next = _weekStart.add(const Duration(days: 7));
    if (next.isAfter(DateTime.now().add(const Duration(days: 7)))) return;
    HapticFeedback.lightImpact();
    setState(() {
      _weekStart = next;
      _selectedDate = next;
      _animController.reset();
      _animController.forward();
      _cardAnimController.reset();
      _cardAnimController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final weekAvg = _getWeekAverage();
    final perfectDays = _getPerfectDays();
    final totalCompleted = _getTotalCompletedThisWeek();
    final bestDay = _getBestDay();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════
          // GRADIENT APP BAR
          // ═══════════════════════════════════════
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF181B44) : AppConfig.primaryColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildGradientHeader(
                  isDark, weekAvg, perfectDays, totalCompleted, bestDay),
            ),
          ),

          // ═══════════════════════════════════════
          // WEEK NAVIGATION
          // ═══════════════════════════════════════
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: CurvedAnimation(
                  parent: _animController, curve: Curves.easeIn),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildWeekNav(isDark),
              ),
            ),
          ),

          // ═══════════════════════════════════════
          // STATS ROW
          // ═══════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildStatsRow(isDark, weekAvg, perfectDays, totalCompleted),
            ),
          ),

          // ═══════════════════════════════════════
          // DAY SELECTOR
          // ═══════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildDaySelector(isDark, days),
            ),
          ),

          // ═══════════════════════════════════════
          // SELECTED DAY DETAIL
          // ═══════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildDayDetail(isDark),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // GRADIENT HEADER
  // ═══════════════════════════════════════

  Widget _buildGradientHeader(bool isDark, double weekAvg, int perfectDays,
      int totalCompleted, String bestDay) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFF7C3AED), const Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -30,
            right: -30,
            child: Opacity(
              opacity: 0.08,
              child: Icon(Icons.calendar_month_rounded,
                  size: 200, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Opacity(
              opacity: 0.06,
              child: Icon(Icons.auto_graph_rounded,
                  size: 150, color: Colors.white),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    '📅 Weekly Review',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your week at a glance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Big progress ring
                  Row(
                    children: [
                      // Progress ring
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 90,
                              height: 90,
                              child: CircularProgressIndicator(
                                value: weekAvg,
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withOpacity(0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  weekAvg >= 0.8
                                      ? const Color(0xFF00E676)
                                      : weekAvg >= 0.5
                                      ? const Color(0xFFFFB300)
                                      : const Color(0xFFFF6B6B),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(weekAvg * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'avg',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _headerStat('🏆', '$perfectDays Perfect Days'),
                            const SizedBox(height: 8),
                            _headerStat('✅', '$totalCompleted Tasks Done'),
                            const SizedBox(height: 8),
                            _headerStat('⭐', 'Best: $bestDay'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // WEEK NAVIGATION
  // ═══════════════════════════════════════

  Widget _buildWeekNav(bool isDark) {
    final range =
        '${DateFormat('MMM d').format(_weekStart)} — ${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left_rounded, _previousWeek, isDark),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_weekStart),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  range,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          _navBtn(Icons.chevron_right_rounded, _nextWeek, isDark),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 24,
            color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  // ═══════════════════════════════════════
  // ANIMATED STATS ROW
  // ═══════════════════════════════════════

  Widget _buildStatsRow(
      bool isDark, double avg, int perfect, int completed) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _statsAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      )),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
          parent: _statsAnimController,
          curve: const Interval(0.0, 0.5),
        )),
        child: Row(
          children: [
            _statCard(
              icon: Icons.percent_rounded,
              label: 'Average',
              value: '${(avg * 100).toInt()}%',
              color: AppConfig.primaryColor,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _statCard(
              icon: Icons.star_rounded,
              label: 'Perfect',
              value: '$perfect',
              color: AppConfig.successColor,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _statCard(
              icon: Icons.check_circle_rounded,
              label: 'Done',
              value: '$completed',
              color: const Color(0xFFFF6A00),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.06 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // ELEVATED DAY SELECTOR
  // ═══════════════════════════════════════

  Widget _buildDaySelector(bool isDark, List<DateTime> days) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2F) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: days.asMap().entries.map((entry) {
          final i = entry.key;
          final day = entry.value;
          final isToday = _isToday(day);
          final isSelected = _isSelected(day);
          final isFuture = day.isAfter(DateTime.now());
          final percent = _getCompletionPercent(day);

          // Stagger animation
          final slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _cardAnimController,
            curve: Interval(
              0.1 + (i * 0.08),
              0.6 + (i * 0.05),
              curve: Curves.easeOutBack,
            ),
          ));

          return Expanded(
            child: SlideTransition(
              position: slideAnim,
              child: GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                  HapticFeedback.selectionClick();
                  SoundService.playTap();
                  setState(() => _selectedDate = day);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF6C63FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isSelected
                        ? null
                        : (percent >= 1.0 && !isFuture
                        ? AppConfig.successColor.withOpacity(0.1)
                        : Colors.transparent),
                    borderRadius: BorderRadius.circular(16),
                    border: isToday && !isSelected
                        ? Border.all(
                      color: AppConfig.primaryColor.withOpacity(0.5),
                      width: 2,
                    )
                        : null,
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: AppConfig.primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(day).substring(0, 2),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white70
                              : isFuture
                              ? (isDark ? Colors.white24 : Colors.grey.shade400)
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? Colors.white
                              : isFuture
                              ? (isDark ? Colors.white24 : Colors.grey.shade400)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isFuture && widget.habits.isNotEmpty)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: percent >= 1.0 ? 12 : 8,
                          height: percent >= 1.0 ? 12 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : percent >= 1.0
                                ? AppConfig.successColor
                                : percent >= 0.5
                                ? AppConfig.warningColor
                                : percent > 0
                                ? AppConfig.accentColor
                                : (isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.shade300),
                            boxShadow: percent >= 1.0 && !isSelected
                                ? [
                              BoxShadow(
                                color: AppConfig.successColor
                                    .withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ]
                                : null,
                          ),
                          child: percent >= 1.0 && !isSelected
                              ? const Icon(Icons.check_rounded,
                              size: 8, color: Colors.white)
                              : null,
                        )
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════
  // DAY DETAIL
  // ═══════════════════════════════════════

  Widget _buildDayDetail(bool isDark) {
    final isFuture = _selectedDate.isAfter(DateTime.now());
    final completed = _getCompletedHabits(_selectedDate);
    final missed = _getMissedHabits(_selectedDate);
    final percent = _getCompletionPercent(_selectedDate);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey(_dateKey(_selectedDate)),
        padding: const EdgeInsets.all(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConfig.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: AppConfig.primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM d, yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isFuture && widget.habits.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: percent >= 1.0
                            ? [const Color(0xFF00C853), const Color(0xFF00E676)]
                            : percent >= 0.5
                            ? [const Color(0xFFFF8F00), const Color(0xFFFFB300)]
                            : [const Color(0xFFFF5252), const Color(0xFFFF6B6B)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (percent >= 1.0
                              ? AppConfig.successColor
                              : AppConfig.accentColor)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '${(percent * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            if (isFuture) ...[
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    const Text('🔮', style: TextStyle(fontSize: 50)),
                    const SizedBox(height: 12),
                    Text(
                      'Future dates not available yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else if (widget.habits.isEmpty) ...[
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    const Text('📝', style: TextStyle(fontSize: 50)),
                    const SizedBox(height: 12),
                    Text(
                      'No habits tracked yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              const SizedBox(height: 16),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 12,
                  backgroundColor:
                  isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percent >= 1.0
                        ? AppConfig.successColor
                        : percent >= 0.5
                        ? AppConfig.warningColor
                        : AppConfig.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${completed.length} of ${widget.habits.length} habits completed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 20),

              // 🎉 Perfect day celebration
              if (percent >= 1.0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.successColor.withOpacity(0.15),
                        const Color(0xFFFFD700).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppConfig.successColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('🌟', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Perfect Day!',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppConfig.successColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All habits completed — amazing! 🔥',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Completed habits
              if (completed.isNotEmpty) ...[
                _sectionTitle('✅ Completed (${completed.length})',
                    AppConfig.successColor),
                const SizedBox(height: 10),
                ...completed
                    .map((h) => _buildPremiumHabitTile(h, true, isDark)),
              ],

              // Missed habits
              if (missed.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                    '❌ Missed (${missed.length})', AppConfig.accentColor),
                const SizedBox(height: 10),
                ...missed
                    .map((h) => _buildPremiumHabitTile(h, false, isDark)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }

  // ═══════════════════════════════════════
  // PREMIUM HABIT TILE
  // ═══════════════════════════════════════

  Widget _buildPremiumHabitTile(Habit habit, bool isCompleted, bool isDark) {
    final color = Color(habit.colorValue);
    final missedReason =
    !isCompleted ? habit.getMissedReason(_dateKey(_selectedDate)) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCompleted
            ? color.withOpacity(isDark ? 0.12 : 0.06)
            : (isDark ? const Color(0xFF1A2138) : const Color(0xFFFFF5F5)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? color.withOpacity(0.3)
              : Colors.red.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompleted ? color : Colors.red).withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? LinearGradient(
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.15),
                ],
              )
                  : null,
              color: isCompleted ? null : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(habit.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration:
                    isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: color,
                    color: isCompleted
                        ? (isDark ? Colors.white54 : Colors.black45)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        habit.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    if (habit.currentStreak > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '🔥 ${habit.currentStreak}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (missedReason != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💭', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            missedReason,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppConfig.successColor.withOpacity(0.15)
                  : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.close_rounded,
              color: isCompleted ? AppConfig.successColor : Colors.red,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}