// lib/widgets/study_target_card.dart
//
// Premium card UI for Study Targets (Daily + Weekly).
// Material 3, overflow-safe, animated progress, haptic + SFX on important action.
//
// UI text: English only.
// State mgmt: Stateless, uses passed values/callbacks.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/study_target_model.dart';
import '../services/sound_service.dart';

class StudyTargetCard extends StatelessWidget {
  final StudyTarget target;

  /// Completed focus minutes today.
  final int minutesToday;

  /// Completed focus minutes in last 7 days (or current week, depending on your stats logic).
  final int minutesThisWeek;

  /// Optional: subject -> minutes completed this week.
  /// If provided and target.subjectTargets is not empty, we show a compact breakdown.
  final Map<String, int>? minutesBySubjectThisWeek;

  /// Edit / Set targets action.
  final VoidCallback? onEdit;

  final bool isDark;

  const StudyTargetCard({
    super.key,
    required this.target,
    required this.minutesToday,
    required this.minutesThisWeek,
    required this.isDark,
    this.minutesBySubjectThisWeek,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dailyProgress = target.getDailyProgress(minutesToday);
    final weeklyProgress = target.getWeeklyProgress(minutesThisWeek);

    final bg = isDark ? const Color(0xFF151C2F) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.grey.shade200.withOpacity(0.9);

    final accent = AppConfig.primaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 10 : 0,
            sigmaY: isDark ? 10 : 0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bg.withOpacity(isDark ? 0.78 : 1.0),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.30)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(accent: accent),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _progressTile(
                        context: context,
                        title: 'Daily Target',
                        progress: dailyProgress,
                        primaryColor: AppConfig.successColor,
                        valueText:
                        '${_fmtMinutes(minutesToday)} / ${_fmtMinutes(target.dailyTargetMinutes)}',
                        subText: target.getRemainingDailyTime(minutesToday),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _progressTile(
                        context: context,
                        title: 'Weekly Target',
                        progress: weeklyProgress,
                        primaryColor: AppConfig.infoColor,
                        valueText:
                        '${_fmtMinutes(minutesThisWeek)} / ${_fmtMinutes(target.weeklyTargetMinutes)}',
                        subText: target.getRemainingWeeklyTime(minutesThisWeek),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                if ((target.subjectTargets.isNotEmpty) &&
                    (minutesBySubjectThisWeek != null) &&
                    minutesBySubjectThisWeek!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _subjectBreakdown(
                    context: context,
                    isDark: isDark,
                    targets: target.subjectTargets,
                    minutesBySubject: minutesBySubjectThisWeek!,
                  ),
                ],

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onEdit == null
                        ? null
                        : () async {
                      await _tapFeedback();
                      onEdit?.call();
                    },
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: const Text(
                      'Edit Targets',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({required Color accent}) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withOpacity(0.95),
                AppConfig.infoColor.withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.flag_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Study Targets',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Set goals and track your progress',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppConfig.warningColor.withOpacity(isDark ? 0.12 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppConfig.warningColor.withOpacity(isDark ? 0.22 : 0.16),
            ),
          ),
          child: Text(
            target.isActive ? 'Active' : 'Paused',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressTile({
    required BuildContext context,
    required String title,
    required double progress,
    required Color primaryColor,
    required String valueText,
    required String subText,
    required bool isDark,
  }) {
    final safeProgress = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    final bg = isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50;
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: safeProgress),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    CircularProgressIndicator(
                      value: v,
                      strokeWidth: 6,
                      color: primaryColor,
                      strokeCap: StrokeCap.round,
                    ),
                    Text(
                      '${(v * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectBreakdown({
    required BuildContext context,
    required bool isDark,
    required Map<String, int> targets,
    required Map<String, int> minutesBySubject,
  }) {
    final bg = isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50;
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;

    // Keep it compact: show up to 4 subjects (most important: highest target minutes)
    final entries = targets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = entries.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Targets (Weekly)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ...shown.map((e) {
            final subject = e.key;
            final targetMins = e.value;
            final doneMins = minutesBySubject[subject] ?? 0;
            final p = targetMins <= 0 ? 0.0 : (doneMins / targetMins).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Text(
                      subject,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: p,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 6,
                    child: Text(
                      '${_fmtMinutes(doneMins)} / ${_fmtMinutes(targetMins)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (targets.length > 4)
            Text(
              'And ${targets.length - 4} more...',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtMinutes(int minutes) {
    final m = minutes < 0 ? 0 : minutes;
    final h = m ~/ 60;
    final r = m % 60;
    if (h <= 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  static Future<void> _tapFeedback() async {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    try {
      SoundService.playTap();
    } catch (_) {}
  }
}