// lib/screens/statistics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/database_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  List<Habit> _habits = [];
  String _selectedView = 'week';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _habits = DatabaseService.getAllHabits();
    });
  }

  // ═══════════════════════════════════════
  // ROADBLOCK ANALYSIS LOGIC (NEW & ADVANCED)
  // ═══════════════════════════════════════
  Map<String, int> _getAggregateMissedReasons() {
    final countMap = <String, int>{};
    for (final habit in _habits) {
      try {
        // গত ৩০ দিনের মিস হওয়ার কারণগুলো নিচ্ছি
        final reasons = habit.getRecentMissedReasons(30);
        for (final r in reasons) {
          final parts = r.split(':');
          if (parts.length > 1) {
            final reason = parts.skip(1).join(':').trim();
            countMap[reason] = (countMap[reason] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('Error parsing missed reasons: $e');
      }
    }
    return countMap;
  }

  String _getAIAdvice(String topReason) {
    final r = topReason.toLowerCase();
    if (r.contains('busy') || r.contains('time') || r.contains('work') || r.contains('meeting')) {
      return "Time management is your biggest hurdle. Try the '2-Minute Rule' — scale your habit down so it only takes 2 minutes on busy days. Just show up!";
    } else if (r.contains('forgot') || r.contains('remember')) {
      return "Memory seems to be the issue. Set a louder alarm or use 'Habit Stacking' (do this habit immediately after something you already do daily like brushing teeth).";
    } else if (r.contains('sick') || r.contains('tired') || r.contains('health') || r.contains('sleep')) {
      return "Health first! It's absolutely okay to rest. When you recover, start with 50% effort to slowly regain your momentum without burning out.";
    } else if (r.contains('lazy') || r.contains('motivation') || r.contains('mood') || r.contains('feel')) {
      return "Motivation follows action, not the other way around. Don't wait for the 'mood' — use the 5-Second Rule and just force yourself to start!";
    } else if (r.contains('distracted') || r.contains('phone')) {
      return "Distractions are stealing your focus. Try putting your phone in another room or turning on 'Do Not Disturb' before starting your habit.";
    }
    return "Awareness is the first step to improvement. Now that you know '$topReason' is holding you back, create a solid backup plan for tomorrow!";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(child: _buildScoreCard(isDark)),
          SliverToBoxAdapter(child: _buildOverviewCards(isDark)),

          // 🚀 NEW: AI Coach & Roadblock Analysis
          SliverToBoxAdapter(child: _buildObstaclesAnalysis(isDark)),

          SliverToBoxAdapter(child: _buildInsightsCard(isDark)),
          SliverToBoxAdapter(child: _buildViewSelector(isDark)),
          SliverToBoxAdapter(child: _buildChart(isDark)),
          SliverToBoxAdapter(child: _buildHeatmapCalendar(isDark)),
          SliverToBoxAdapter(child: _buildCategoryBreakdown(isDark)),
          SliverToBoxAdapter(child: _buildPriorityBreakdown(isDark)),
          SliverToBoxAdapter(child: _buildHabitBreakdown(isDark)),
          SliverToBoxAdapter(child: _buildStreakLeaderboard(isDark)),
          SliverToBoxAdapter(child: _buildConsistencyScore(isDark)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════
  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Text(
          '📊 Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF151C2F)]
                  : [AppConfig.primaryColor.withAlpha(15), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // ROADBLOCK & FAILURE ANALYSIS CARD (🚀 NEW)
  // ═══════════════════════════════════════
  Widget _buildObstaclesAnalysis(bool isDark) {
    final reasonsMap = _getAggregateMissedReasons();
    if (reasonsMap.isEmpty) return const SizedBox.shrink(); // কোনো মিস করার রিজন না থাকলে হাইড থাকবে

    final sorted = reasonsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalMissed = sorted.fold<int>(0, (sum, item) => sum + item.value);
    final topReason = sorted.first.key;
    final topReasonCount = sorted.first.value;
    final topReasonPercent = (topReasonCount / totalMissed) * 100;

    final advice = _getAIAdvice(topReason);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2A1015), const Color(0xFF1C0D12)]
                : [const Color(0xFFFFF0F2), const Color(0xFFFFF5F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.redAccent.withAlpha(40), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withAlpha(isDark ? 20 : 10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Roadblock Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Why you missed habits in the last 30 days:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // Progress Bars for Reasons
            ...sorted.take(4).map((entry) {
              final percent = (entry.value / totalMissed) * 100;
              final isTop = entry.key == topReason;
              final color = isTop ? Colors.redAccent : (isDark ? Colors.white54 : Colors.grey.shade600);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isTop ? FontWeight.w800 : FontWeight.w600,
                          color: isTop ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 8,
                          backgroundColor: color.withAlpha(20),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${entry.value}x',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            Divider(color: Colors.redAccent.withAlpha(30)),
            const SizedBox(height: 16),

            // 🧠 AI Coach Feedback Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withAlpha(40) : Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConfig.primaryColor.withAlpha(30)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🧠', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Coach Advice',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          advice,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // HABIT SCORE (Overall Performance)
  // ═══════════════════════════════════════
  Widget _buildScoreCard(bool isDark) {
    final score = _calculateOverallScore();
    final scoreLabel = _getScoreLabel(score);
    final scoreColor = _getScoreColor(score);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scoreColor.withAlpha(isDark ? 40 : 20), scoreColor.withAlpha(isDark ? 20 : 10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scoreColor.withAlpha(40)),
        ),
        child: Row(
          children: [
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
                      value: score / 100,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scoreColor.withAlpha(25),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.toInt()}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'SCORE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scoreLabel['title']!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scoreLabel['subtitle']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scoreColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      scoreLabel['emoji']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // OVERVIEW CARDS
  // ═══════════════════════════════════════
  Widget _buildOverviewCards(bool isDark) {
    final totalCompleted = DatabaseService.getTotalHabitsCompleted();
    final currentStreak = DatabaseService.getCurrentStreakTotal();
    final bestStreak = DatabaseService.getBestStreakTotal();
    final totalHabits = _habits.length;

    int totalActiveDays = 0;
    Set<String> activeDates = {};
    for (final h in _habits) {
      activeDates.addAll(h.completedDates);
    }
    totalActiveDays = activeDates.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard('✅', 'Completed', totalCompleted.toString(), AppConfig.successColor, isDark),
              const SizedBox(width: 10),
              _buildStatCard('🔥', 'Best Streak', '$bestStreak days', Colors.orange, isDark),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatCard('📋', 'Active Habits', totalHabits.toString(), AppConfig.primaryColor, isDark),
              const SizedBox(width: 10),
              _buildStatCard('📅', 'Active Days', totalActiveDays.toString(), AppConfig.infoColor, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String title, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(isDark ? 10 : 15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // INSIGHTS CARD
  // ═══════════════════════════════════════
  Widget _buildInsightsCard(bool isDark) {
    final insights = _generateInsights();
    if (insights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E1B4B), const Color(0xFF252250)]
                : [const Color(0xFFF3F0FF), const Color(0xFFF5F3FF)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppConfig.primaryColor.withAlpha(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Quick Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight['emoji']!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight['text']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // VIEW SELECTOR (Week/Month/Year)
  // ═══════════════════════════════════════
  Widget _buildViewSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildViewTab('Week', 'week', isDark),
            _buildViewTab('Month', 'month', isDark),
            _buildViewTab('Year', 'year', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab(String label, String view, bool isDark) {
    final isSelected = _selectedView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedView = view);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppConfig.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: AppConfig.primaryColor.withAlpha(40), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // CHART
  // ═══════════════════════════════════════
  Widget _buildChart(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(isDark ? 15 : 8), blurRadius: 15, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '📈 Completion Rate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                ),
                const Spacer(),
                Text(
                  _selectedView == 'week' ? 'Last 7 days' : _selectedView == 'month' ? 'This month' : 'This year',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _selectedView == 'week'
                  ? _buildWeekChart(isDark)
                  : _selectedView == 'month'
                  ? _buildMonthChart(isDark)
                  : _buildYearChart(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekChart(bool isDark) {
    final data = _getWeekData();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}%',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                if (value % 25 != 0) return const SizedBox.shrink();
                return Text('${value.toInt()}%', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(days[value.toInt()], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black45)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          final percent = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: percent,
                gradient: LinearGradient(
                  colors: [
                    AppConfig.primaryColor.withAlpha(180),
                    AppConfig.primaryColor,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 22,
                borderRadius: BorderRadius.circular(8),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100,
                  color: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade100,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthChart(bool isDark) {
    final spots = _getMonthData();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                if (value % 25 != 0) return const SizedBox.shrink();
                return Text('${value.toInt()}%', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt() + 1}', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: [AppConfig.primaryColor.withAlpha(180), AppConfig.primaryColor]),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppConfig.primaryColor.withAlpha(40), AppConfig.primaryColor.withAlpha(5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearChart(bool isDark) {
    final spots = _getYearData();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                if (value % 25 != 0) return const SizedBox.shrink();
                return Text('${value.toInt()}%', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Text(months[value.toInt()], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.black38));
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: [AppConfig.primaryColor.withAlpha(180), AppConfig.primaryColor]),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(radius: 3, color: AppConfig.primaryColor, strokeColor: Colors.white, strokeWidth: 1.5);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // HEATMAP
  // ═══════════════════════════════════════
  Widget _buildHeatmapCalendar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 15 : 8), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🗓️ Activity Heatmap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                const Spacer(),
                _buildHeatmapLegend('Less', Colors.grey.shade300, isDark),
                const SizedBox(width: 3),
                _buildHeatmapLegend('', AppConfig.successColor.withAlpha(76), isDark),
                const SizedBox(width: 3),
                _buildHeatmapLegend('', AppConfig.successColor.withAlpha(153), isDark),
                const SizedBox(width: 3),
                _buildHeatmapLegend('More', AppConfig.successColor, isDark),
              ],
            ),
            const SizedBox(height: 16),
            _buildHeatmap(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(bool isDark) {
    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(const Duration(days: 90));

    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: List.generate(91, (index) {
        DateTime date = startDate.add(Duration(days: index));
        return _buildHeatmapCell(date, isDark);
      }),
    );
  }

  Widget _buildHeatmapLegend(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38)),
        const SizedBox(width: 2),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      ],
    );
  }

  Widget _buildHeatmapCell(DateTime date, bool isDark) {
    String dateStr = date.toString().split(' ')[0];
    int completedCount = _habits.where((h) => h.completedDates.contains(dateStr)).length;

    Color color;
    if (completedCount == 0) {
      color = isDark ? Colors.white.withAlpha(8) : Colors.grey.shade200;
    } else if (completedCount <= 2) {
      color = AppConfig.successColor.withAlpha(76);
    } else if (completedCount <= 4) {
      color = AppConfig.successColor.withAlpha(153);
    } else {
      color = AppConfig.successColor;
    }

    return Tooltip(
      message: '${DateFormat('MMM d').format(date)}: $completedCount habits',
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.5)),
      ),
    );
  }

  // ═══════════════════════════════════════
  // CATEGORY BREAKDOWN (Pie-like)
  // ═══════════════════════════════════════
  Widget _buildCategoryBreakdown(bool isDark) {
    final categoryMap = DatabaseService.getHabitsByCategory();
    if (categoryMap.isEmpty) return const SizedBox.shrink();

    final total = categoryMap.values.fold<int>(0, (a, b) => a + b);
    final categoryColors = {
      'Health': const Color(0xFFEF4444),
      'Fitness': const Color(0xFFF97316),
      'Study': const Color(0xFF3B82F6),
      'Work': const Color(0xFF8B5CF6),
      'Mindfulness': const Color(0xFF14B8A6),
      'Finance': const Color(0xFFEAB308),
      'Social': const Color(0xFFEC4899),
      'Spiritual': const Color(0xFF059669),
      'Self-Care': const Color(0xFF06B6D4),
      'Other': const Color(0xFF64748B),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 15 : 8), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📂 By Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            ...categoryMap.entries.map((entry) {
              final percent = (entry.value / total * 100);
              final color = categoryColors[entry.key] ?? AppConfig.primaryColor;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(entry.key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))),
                    Text('${entry.value}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: percent / 100, minHeight: 6, backgroundColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(color)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // PRIORITY BREAKDOWN
  // ═══════════════════════════════════════
  Widget _buildPriorityBreakdown(bool isDark) {
    final priorityMap = DatabaseService.getHabitsByPriority();
    if (priorityMap.isEmpty) return const SizedBox.shrink();

    final priorityInfo = {
      'low': {'emoji': '🟢', 'label': 'Low', 'color': const Color(0xFF22C55E)},
      'medium': {'emoji': '🟡', 'label': 'Medium', 'color': const Color(0xFFEAB308)},
      'high': {'emoji': '🟠', 'label': 'High', 'color': const Color(0xFFF97316)},
      'critical': {'emoji': '🔴', 'label': 'Critical', 'color': const Color(0xFFEF4444)},
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 15 : 8), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚡ By Priority', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            Row(
              children: ['low', 'medium', 'high', 'critical'].map((p) {
                final info = priorityInfo[p]!;
                final count = priorityMap[p] ?? 0;
                final color = info['color'] as Color;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withAlpha(isDark ? 20 : 12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withAlpha(30)),
                    ),
                    child: Column(
                      children: [
                        Text(info['emoji'] as String, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                        Text(info['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // HABIT BREAKDOWN
  // ═══════════════════════════════════════
  Widget _buildHabitBreakdown(bool isDark) {
    if (_habits.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 15 : 8), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Habit Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            ..._habits.map((habit) => _buildHabitProgressRow(habit, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitProgressRow(Habit habit, bool isDark) {
    final weekRate = habit.getWeeklyCompletionRate();
    final color = Color(habit.colorValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(habit.emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(habit.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
                    ),
                    Text('${weekRate.toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: weekRate / 100,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('🔥 ${habit.currentStreak}d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade400)),
                    const SizedBox(width: 8),
                    Text('🏆 ${habit.bestStreak}d best', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38)),
                    const Spacer(),
                    Text(habit.priorityLabel, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // STREAK LEADERBOARD
  // ═══════════════════════════════════════
  Widget _buildStreakLeaderboard(bool isDark) {
    if (_habits.isEmpty) return const SizedBox.shrink();

    final sorted = List<Habit>.from(_habits)..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
    final top = sorted.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 15 : 8), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏆 Streak Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 14),
            ...top.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final habit = entry.value;
              final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? Colors.amber.withAlpha(isDark ? 15 : 10)
                        : (isDark ? Colors.white.withAlpha(5) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(14),
                    border: rank == 1 ? Border.all(color: Colors.amber.withAlpha(40)) : null,
                  ),
                  child: Row(
                    children: [
                      Text(medals[rank - 1], style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Text(habit.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(habit.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF5E00)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('🔥 ${habit.currentStreak}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // CONSISTENCY SCORE
  // ═══════════════════════════════════════
  Widget _buildConsistencyScore(bool isDark) {
    if (_habits.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    int last30Completed = 0;
    int last30Total = 0;

    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i)).toString().split(' ')[0];
      for (final h in _habits) {
        last30Total++;
        if (h.completedDates.contains(date)) last30Completed++;
      }
    }

    final consistency = last30Total > 0 ? (last30Completed / last30Total * 100) : 0.0;
    final color = _getScoreColor(consistency);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withAlpha(isDark ? 25 : 15), color.withAlpha(isDark ? 10 : 5)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: consistency / 100,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Text('${consistency.toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('30-Day Consistency', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text('$last30Completed/$last30Total completions in the last 30 days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // DATA HELPERS
  // ═══════════════════════════════════════
  List<double> _getWeekData() {
    List<double> data = List.filled(7, 0);
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      DateTime day = weekStart.add(Duration(days: i));
      String dateStr = day.toString().split(' ')[0];
      int total = _habits.length;
      int completed = _habits.where((h) => h.completedDates.contains(dateStr)).length;
      data[i] = total > 0 ? (completed / total) * 100 : 0;
    }
    return data;
  }

  List<FlSpot> _getMonthData() {
    List<FlSpot> spots = [];
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    for (int i = 0; i < daysInMonth; i++) {
      DateTime day = DateTime(now.year, now.month, i + 1);
      if (day.isAfter(now)) break;
      String dateStr = day.toString().split(' ')[0];
      int total = _habits.length;
      int completed = _habits.where((h) => h.completedDates.contains(dateStr)).length;
      double percentage = total > 0 ? (completed / total) * 100 : 0;
      spots.add(FlSpot(i.toDouble(), percentage));
    }
    return spots;
  }

  List<FlSpot> _getYearData() {
    List<FlSpot> spots = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 12; i++) {
      int totalCompleted = 0;
      int totalDays = 0;
      int daysInMonth = DateTime(now.year, i + 2, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime date = DateTime(now.year, i + 1, day);
        if (date.isAfter(now)) break;
        String dateStr = date.toString().split(' ')[0];
        totalDays++;
        int completed = _habits.where((h) => h.completedDates.contains(dateStr)).length;
        totalCompleted += completed;
      }

      double percentage = (totalDays > 0 && _habits.isNotEmpty)
          ? (totalCompleted / (totalDays * _habits.length)) * 100
          : 0;
      spots.add(FlSpot(i.toDouble(), percentage));
    }
    return spots;
  }

  double _calculateOverallScore() {
    if (_habits.isEmpty) return 0;

    double weeklyAvg = 0;
    for (final h in _habits) {
      weeklyAvg += h.getWeeklyCompletionRate();
    }
    weeklyAvg /= _habits.length;

    double streakBonus = 0;
    for (final h in _habits) {
      if (h.currentStreak >= 30) streakBonus += 10;
      else if (h.currentStreak >= 14) streakBonus += 7;
      else if (h.currentStreak >= 7) streakBonus += 5;
      else if (h.currentStreak >= 3) streakBonus += 2;
    }
    streakBonus = (streakBonus / _habits.length).clamp(0, 15);

    return (weeklyAvg * 0.85 + streakBonus).clamp(0, 100);
  }

  Map<String, String> _getScoreLabel(double score) {
    if (score >= 90) return {'title': 'Outstanding! 🌟', 'subtitle': 'You\'re crushing your habits like a pro!', 'emoji': '🏆 Elite Performer'};
    if (score >= 75) return {'title': 'Great Job! 💪', 'subtitle': 'Strong consistency, keep pushing!', 'emoji': '⭐ High Achiever'};
    if (score >= 50) return {'title': 'Good Progress! 📈', 'subtitle': 'Building momentum, stay focused!', 'emoji': '🎯 On Track'};
    if (score >= 25) return {'title': 'Keep Going! 🚀', 'subtitle': 'Every small step counts!', 'emoji': '🌱 Growing'};
    return {'title': 'Getting Started 🌅', 'subtitle': 'Start with one habit, build from there.', 'emoji': '✨ Beginning'};
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF22C55E);
    if (score >= 75) return const Color(0xFF10B981);
    if (score >= 50) return const Color(0xFFEAB308);
    if (score >= 25) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  List<Map<String, String>> _generateInsights() {
    List<Map<String, String>> insights = [];
    if (_habits.isEmpty) return insights;

    // Best habit
    Habit? bestHabit;
    double bestRate = 0;
    for (final h in _habits) {
      final rate = h.getWeeklyCompletionRate();
      if (rate > bestRate) {
        bestRate = rate;
        bestHabit = h;
      }
    }
    if (bestHabit != null && bestRate > 0) {
      insights.add({'emoji': '🌟', 'text': 'Your best habit this week is "${bestHabit.name}" with ${bestRate.toInt()}% completion!'});
    }

    // Worst habit
    Habit? worstHabit;
    double worstRate = 100;
    for (final h in _habits) {
      final rate = h.getWeeklyCompletionRate();
      if (rate < worstRate) {
        worstRate = rate;
        worstHabit = h;
      }
    }
    if (worstHabit != null && worstRate < 50 && _habits.length > 1) {
      insights.add({'emoji': '⚠️', 'text': '"${worstHabit.name}" needs attention — only ${worstRate.toInt()}% this week.'});
    }

    // Streak info
    final bestStreak = DatabaseService.getBestStreakTotal();
    if (bestStreak >= 7) {
      insights.add({'emoji': '🔥', 'text': 'Amazing $bestStreak-day streak! Consistency is your superpower!'});
    }

    // Total completed
    final totalCompleted = DatabaseService.getTotalHabitsCompleted();
    if (totalCompleted >= 100) {
      insights.add({'emoji': '🎉', 'text': 'You\'ve completed habits $totalCompleted times! That\'s incredible dedication.'});
    }

    return insights.take(3).toList();
  }
}