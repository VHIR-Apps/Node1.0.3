// lib/widgets/study_stats_widgets.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../config/app_config.dart';

class StudyStatsView extends StatefulWidget {
  final bool isDark;

  const StudyStatsView({super.key, required this.isDark});

  @override
  State<StudyStatsView> createState() => _StudyStatsViewState();
}

class _StudyStatsViewState extends State<StudyStatsView> {
  int todayMins = 0;
  int weekMins = 0;
  int streak = 0;
  int bestStreak = 0;
  int totalSessions = 0;
  Map<String, int> subjectStats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      todayMins = DatabaseService.getTotalStudyMinutesToday();
      weekMins = DatabaseService.getTotalStudyMinutesThisWeek();
      streak = DatabaseService.getStudyStreak();
      bestStreak = DatabaseService.getBestStudyStreak();
      totalSessions = DatabaseService.getTotalPomodorosCompleted();
      subjectStats = DatabaseService.getStudyTimeBySubject();
    });
  }

  String _formatTime(int totalMinutes) {
    if (totalMinutes < 60) return '${totalMinutes}m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final cardColor = widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    final borderColor = widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ MAIN STATS GRID ═══
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                title: 'Today',
                value: _formatTime(todayMins),
                icon: Icons.today,
                color: const Color(0xFFEF4444),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
              ),
              _buildStatCard(
                title: 'This Week',
                value: _formatTime(weekMins),
                icon: Icons.calendar_view_week,
                color: const Color(0xFF3B82F6),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
              ),
              _buildStatCard(
                title: 'Current Streak',
                value: '$streak Days',
                icon: Icons.local_fire_department,
                color: const Color(0xFFF59E0B),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
              ),
              _buildStatCard(
                title: 'Best Streak',
                value: '$bestStreak Days',
                icon: Icons.emoji_events,
                color: const Color(0xFF10B981),
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ═══ TOTAL SESSIONS ═══
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Total Pomodoros',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$totalSessions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ═══ SUBJECT BREAKDOWN ═══
          Text(
            'Subject Breakdown',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          if (subjectStats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No study sessions yet.\nStart focusing to see your stats!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor.withOpacity(0.5)),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: subjectStats.entries.map((entry) {
                  final subjectName = entry.key;
                  final duration = entry.value;

                  // Find color or use default
                  Color subjColor = AppConfig.predefinedSubjects[subjectName] ?? const Color(0xFF6B7280);

                  // Calculate percentage
                  final totalSubjectMins = subjectStats.values.fold(0, (sum, val) => sum + val);
                  final percentage = totalSubjectMins > 0 ? (duration / totalSubjectMins) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              subjectName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            Text(
                              _formatTime(duration),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: subjColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: widget.isDark ? Colors.white10 : Colors.black12,
                            color: subjColor,
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 40), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}