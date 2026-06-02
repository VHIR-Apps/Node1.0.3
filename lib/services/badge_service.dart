// lib/services/badge_service.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../models/badge_model.dart';
import '../models/habit_model.dart';
import '../models/study_session_model.dart';
import 'database_service.dart';
import 'sound_service.dart';

class BadgeService {
  static const String _boxName = 'badges';
  static late Box _badgeBox;

  // Callback for when badge is unlocked (UI shows dialog)
  static Function(BadgeDefinition badge)? onBadgeUnlocked;

  // ── Phase 2: Callback for level down (UI shows snackbar / effect) ──
  static Function(int oldLevel, int newLevel)? onLevelDown;

  // ═══════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════

  static Future<void> init() async {
    _badgeBox = await Hive.openBox(_boxName);
    await _trackAppUsage();
    debugPrint(
      '✅ BadgeService initialized — '
          '${getUnlockedCount()}/${AllBadges.getAll().length} badges unlocked',
    );
  }

  // ═══════════════════════════════════════
  // UNLOCKED BADGES
  // ═══════════════════════════════════════

  static List<UnlockedBadge> getUnlockedBadges() {
    final raw = _badgeBox.get('unlocked_badges', defaultValue: <dynamic>[]);
    if (raw is List) {
      return raw
          .map((e) {
        if (e is Map) {
          return UnlockedBadge.fromJson(Map<String, dynamic>.from(e));
        }
        return null;
      })
          .whereType<UnlockedBadge>()
          .toList();
    }
    return [];
  }

  static bool isBadgeUnlocked(String badgeId) {
    return getUnlockedBadges().any((b) => b.badgeId == badgeId);
  }

  static int getUnlockedCount() => getUnlockedBadges().length;
  static int getTotalCount() => AllBadges.getAll().length;

  static Future<void> _unlockBadge(String badgeId) async {
    if (isBadgeUnlocked(badgeId)) return;

    final badge = AllBadges.getById(badgeId);
    if (badge == null) return;

    final unlocked = getUnlockedBadges();
    unlocked.add(UnlockedBadge(badgeId: badgeId, unlockedAt: DateTime.now()));

    await _badgeBox.put(
      'unlocked_badges',
      unlocked.map((b) => b.toJson()).toList(),
    );

    await addXp(badge.xpReward);
    SoundService.playLevelUp();
    onBadgeUnlocked?.call(badge);

    debugPrint('🏆 Badge unlocked: ${badge.name} (+${badge.xpReward} XP)');
  }

  // ═══════════════════════════════════════
  // XP SYSTEM — Phase 2: subtractXp + level down detection
  // ═══════════════════════════════════════

  static int getXp() => _badgeBox.get('total_xp', defaultValue: 0) as int;

  /// Add XP and detect level UP.
  static Future<void> addXp(int amount) async {
    if (amount <= 0) return;

    final currentXp = getXp();
    final newXp = currentXp + amount;
    final oldLevel = AppConfig.getLevelFromXp(currentXp);
    final newLevel = AppConfig.getLevelFromXp(newXp);

    await _badgeBox.put('total_xp', newXp);

    if (newLevel > oldLevel) {
      debugPrint('🎉 Level Up! $oldLevel → $newLevel');
      // Level up sound is played by dashboard when it detects the change.
    }
  }

  /// Phase 2: Subtract XP when a habit is missed.
  /// XP cannot go below 0.
  /// Detects level DOWN and fires [onLevelDown] callback.
  static Future<void> subtractXp(int amount) async {
    if (amount <= 0) return;

    final currentXp = getXp();
    final newXp = (currentXp - amount).clamp(0, 999999);
    final oldLevel = AppConfig.getLevelFromXp(currentXp);
    final newLevel = AppConfig.getLevelFromXp(newXp);

    await _badgeBox.put('total_xp', newXp);

    debugPrint('📉 XP deducted: -$amount  ($currentXp → $newXp)');

    if (newLevel < oldLevel) {
      debugPrint('⬇️ Level Down! $oldLevel → $newLevel');
      // Update last known level so dashboard can show the animation.
      await DatabaseService.setLastKnownLevel(newLevel);
      onLevelDown?.call(oldLevel, newLevel);
    }
  }

  /// Phase 2: Calculate XP deduction for a missed habit.
  /// Deduction scales with priority and streak to create meaningful loss.
  static int calculateMissedXpDeduction(Habit habit) {
    // Base deduction by priority
    int base;
    switch (habit.priority.toLowerCase()) {
      case 'critical':
        base = 20;
        break;
      case 'high':
        base = 15;
        break;
      case 'medium':
        base = 10;
        break;
      case 'low':
        base = 5;
        break;
      default:
        base = 10;
    }

    // Streak multiplier — longer streaks mean more to lose
    final streak = habit.currentStreak;
    double multiplier = 1.0;
    if (streak >= 30) {
      multiplier = 2.0;
    } else if (streak >= 14) {
      multiplier = 1.5;
    } else if (streak >= 7) {
      multiplier = 1.2;
    }

    return (base * multiplier).round();
  }

  /// Phase 2: Called when a habit is confirmed missed (no completion yesterday).
  /// Deducts XP once per habit per day.
  static Future<void> onHabitMissed(Habit habit) async {
    final today = DateTime.now().toString().split(' ')[0];
    final key = 'xp_deducted_${habit.id}_$today';

    // Prevent double-deduction in the same day
    final alreadyDeducted = _badgeBox.get(key, defaultValue: false) as bool;
    if (alreadyDeducted) return;

    await _badgeBox.put(key, true);

    final deduction = calculateMissedXpDeduction(habit);
    await subtractXp(deduction);

    debugPrint(
      '📉 Habit missed: ${habit.name} → -$deduction XP '
          '(priority: ${habit.priority}, streak: ${habit.currentStreak})',
    );
  }

  /// Phase 2: Process all missed habits from yesterday at app startup.
  /// Called once per day automatically.
  static Future<void> processMissedHabitsXpDeduction() async {
    final today = DateTime.now().toString().split(' ')[0];
    final processedKey = 'xp_missed_processed_$today';

    final alreadyProcessed =
    _badgeBox.get(processedKey, defaultValue: false) as bool;
    if (alreadyProcessed) return;

    await _badgeBox.put(processedKey, true);

    final habits = DatabaseService.getAllHabits();
    for (final habit in habits) {
      if (habit.wasMissedYesterday()) {
        await onHabitMissed(habit);
      }
    }

    debugPrint('✅ Daily missed XP deduction processed.');
  }

  static int getLevel() => AppConfig.getLevelFromXp(getXp());
  static double getLevelProgress() => AppConfig.getLevelProgress(getXp());
  static Map<String, String> getLevelInfo() => AppConfig.getLevelInfo(getLevel());
  static int getXpForNextLevel() => AppConfig.getXpForNextLevel(getXp());

  // ═══════════════════════════════════════
  // APP USAGE TRACKING
  // ═══════════════════════════════════════

  static Future<void> _trackAppUsage() async {
    final today = DateTime.now().toString().split(' ')[0];
    final lastUsageDate =
    _badgeBox.get('last_usage_date', defaultValue: '') as String;

    if (lastUsageDate == today) return;

    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toString()
        .split(' ')[0];

    int consecutiveDays =
    _badgeBox.get('consecutive_app_days', defaultValue: 0) as int;

    if (lastUsageDate == yesterday) {
      consecutiveDays++;
    } else if (lastUsageDate != today) {
      consecutiveDays = 1;
    }

    await _badgeBox.put('last_usage_date', today);
    await _badgeBox.put('consecutive_app_days', consecutiveDays);

    List<String> usageDays = List<String>.from(
      _badgeBox.get('all_usage_days', defaultValue: <String>[]) as List,
    );
    if (!usageDays.contains(today)) {
      usageDays.add(today);
      await _badgeBox.put('all_usage_days', usageDays);
    }
  }

  static int getConsecutiveAppDays() {
    return _badgeBox.get('consecutive_app_days', defaultValue: 0) as int;
  }

  // ═══════════════════════════════════════
  // STAT COUNTERS
  // ═══════════════════════════════════════

  static int _getCounter(String key) =>
      _badgeBox.get(key, defaultValue: 0) as int;

  static Future<void> _incrementCounter(String key) async {
    await _badgeBox.put(key, _getCounter(key) + 1);
  }

  static int getEarlyCompletions() => _getCounter('early_completions');
  static int getDawnCompletions() => _getCounter('dawn_completions');
  static int getNightCompletions() => _getCounter('night_completions');
  static int getMidnightCompletions() => _getCounter('midnight_completions');
  static int getComebackCount() => _getCounter('comeback_count');
  static int getAlarmCompletions() => _getCounter('alarm_completions');
  static int getMissedReasonsSubmitted() =>
      _getCounter('missed_reasons_submitted');
  static int getDailyGoalsMet() => _getCounter('daily_goals_met');
  static int getPerfectDayStreak() =>
      _badgeBox.get('perfect_day_streak', defaultValue: 0) as int;

  // ═══════════════════════════════════════
  // BADGE CHECK
  // ═══════════════════════════════════════

  static Future<void> checkAllBadges() async {
    if (!AppConfig.enableBadges) return;

    final habits = DatabaseService.getAllHabits();
    final totalCompleted = DatabaseService.getTotalHabitsCompleted();

    await _checkStreakBadges(habits);
    await _checkCompletionBadges(totalCompleted);
    await _checkPerfectionBadges(habits);
    await _checkRecoveryBadges();
    await _checkTimeBasedBadges();
    await _checkVarietyBadges(habits);
    await _checkSpecialBadges(habits);
    await _checkStudyBadges();
  }

  // ═══════════════════════════════════════
  // STUDY BADGES
  // ═══════════════════════════════════════

  static Future<void> onStudySessionCompleted(StudySession session) async {
    if (session.sessionType == 'focus') {
      await addXp(session.durationMinutes * 2);

      final hour = session.completedAt.hour;
      if (hour >= AppConfig.badgeNightOwlHour || hour < 4) {
        await _incrementCounter('study_night_owl_count');
      }
      if (hour < AppConfig.badgeEarlyBirdHour && hour >= 4) {
        await _incrementCounter('study_early_bird_count');
      }

      if (session.pomodoroCount >= AppConfig.badgeMarathonPomodoros) {
        await _unlockBadge('study_marathon');
      }
    }
    await checkAllBadges();
  }

  static Future<void> _checkStudyBadges() async {
    final totalMins = DatabaseService.getTotalStudyMinutesAllTime();
    final totalHours = totalMins / 60;

    if (totalMins > 0) await _unlockBadge('study_first_focus');
    if (totalHours >= AppConfig.badgeStudyStarterHours) {
      await _unlockBadge('study_1_hour');
    }
    if (totalHours >= AppConfig.badgeBookwormHours) {
      await _unlockBadge('study_10_hours');
    }
    if (totalHours >= AppConfig.badgeScholarHours) {
      await _unlockBadge('study_50_hours');
    }

    final streak = DatabaseService.getBestStudyStreak();
    if (streak >= AppConfig.badgeStudyStreak7) {
      await _unlockBadge('study_streak_7');
    }
    if (streak >= AppConfig.badgeStudyStreak30) {
      await _unlockBadge('study_streak_30');
    }

    if (_getCounter('study_night_owl_count') >= 5) {
      await _unlockBadge('study_night_owl');
    }
    if (_getCounter('study_early_bird_count') >= 5) {
      await _unlockBadge('study_early_bird');
    }

    final subjectMap = DatabaseService.getStudyTimeBySubject();
    for (final entry in subjectMap.entries) {
      if ((entry.value / 60) >= AppConfig.badgeSubjectMasterHours) {
        await _unlockBadge('study_subject_master');
        break;
      }
    }
  }

  // ═══════════════════════════════════════
  // STREAK BADGES
  // ═══════════════════════════════════════

  static Future<void> _checkStreakBadges(List<Habit> habits) async {
    int bestStreak = 0;
    for (final h in habits) {
      final s = h.currentStreak > h.bestStreak ? h.currentStreak : h.bestStreak;
      if (s > bestStreak) bestStreak = s;
    }

    const thresholds = {
      3: 'streak_3',
      7: 'streak_7',
      14: 'streak_14',
      30: 'streak_30',
      60: 'streak_60',
      100: 'streak_100',
      200: 'streak_200',
      365: 'streak_365',
    };

    for (final entry in thresholds.entries) {
      if (bestStreak >= entry.key) await _unlockBadge(entry.value);
    }
  }

  // ═══════════════════════════════════════
  // COMPLETION BADGES
  // ═══════════════════════════════════════

  static Future<void> _checkCompletionBadges(int total) async {
    const thresholds = {
      1: 'complete_1',
      10: 'complete_10',
      50: 'complete_50',
      100: 'complete_100',
      250: 'complete_250',
      500: 'complete_500',
      1000: 'complete_1000',
      2500: 'complete_2500',
    };

    for (final entry in thresholds.entries) {
      if (total >= entry.key) await _unlockBadge(entry.value);
    }
  }

  // ═══════════════════════════════════════
  // PERFECTION BADGES
  // ═══════════════════════════════════════

  static Future<void> _checkPerfectionBadges(List<Habit> habits) async {
    if (habits.isEmpty) return;

    final now = DateTime.now();
    int perfectStreak = 0;

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toString().split(' ')[0];

      bool allCompleted = true;
      int activeCount = 0;

      for (final h in habits) {
        if (h.createdAt.isAfter(date)) continue;
        if (h.startDate != null && date.isBefore(h.startDate!)) continue;
        if (h.endDate != null && date.isAfter(h.endDate!)) continue;

        if (h.frequency == 'custom' && h.customDays != null) {
          if (!h.customDays!.contains(date.weekday)) continue;
        }

        activeCount++;
        if (!h.completedDates.contains(dateStr)) {
          allCompleted = false;
          break;
        }
      }

      if (activeCount > 0 && allCompleted) {
        perfectStreak++;
      } else {
        break;
      }
    }

    await _badgeBox.put('perfect_day_streak', perfectStreak);

    const thresholds = {
      1: 'perfect_1',
      7: 'perfect_7',
      14: 'perfect_14',
      30: 'perfect_30',
      90: 'perfect_90',
    };

    for (final entry in thresholds.entries) {
      if (perfectStreak >= entry.key) await _unlockBadge(entry.value);
    }
  }

  // ═══════════════════════════════════════
  // RECOVERY BADGES
  // ═══════════════════════════════════════

  static Future<void> _checkRecoveryBadges() async {
    final count = getComebackCount();
    const thresholds = {
      1: 'comeback_1',
      3: 'comeback_3',
      5: 'comeback_5',
      10: 'comeback_10',
    };

    for (final entry in thresholds.entries) {
      if (count >= entry.key) await _unlockBadge(entry.value);
    }
  }

  // ═══════════════════════════════════════
  // TIME-BASED BADGES
  // ═══════════════════════════════════════

  static Future<void> _checkTimeBasedBadges() async {
    if (getEarlyCompletions() >= 5) await _unlockBadge('early_5');
    if (getDawnCompletions() >= 15) await _unlockBadge('early_15');
    if (getNightCompletions() >= 5) await _unlockBadge('night_5');
    if (getMidnightCompletions() >= 15) await _unlockBadge('night_15');
  }

  // ═══════════════════════════════════════
  // VARIETY BADGES
  // ═══════════════════════════════════════

  static Future<void> _checkVarietyBadges(List<Habit> habits) async {
    final activeCount = habits.where((h) => h.isActiveToday()).length;
    const thresholds = {
      3: 'variety_3',
      5: 'variety_5',
      8: 'variety_8',
      10: 'variety_10',
    };

    for (final entry in thresholds.entries) {
      if (activeCount >= entry.key) await _unlockBadge(entry.value);
    }
  }

  // ═══════════════════════════════════════
  // SPECIAL BADGES
  // ═══════════════════════════════════════

  static Future<void> _checkSpecialBadges(List<Habit> habits) async {
    final categories = habits.map((h) => h.category).toSet();
    if (categories.length >= 8) await _unlockBadge('explorer');

    if (getAlarmCompletions() >= AppConfig.alarmHeroThreshold) {
      await _unlockBadge('alarm_hero');
    }

    if (getMissedReasonsSubmitted() >= AppConfig.noExcuseThreshold) {
      await _unlockBadge('no_excuse');
    }

    final appDays = getConsecutiveAppDays();
    if (appDays >= 7) await _unlockBadge('app_7');
    if (appDays >= 30) await _unlockBadge('app_30');
    if (appDays >= 100) await _unlockBadge('app_100');
    if (appDays >= 365) await _unlockBadge('app_365');

    final habitsWithNotes = habits
        .where((h) => h.notes != null && h.notes!.trim().isNotEmpty)
        .length;
    if (habitsWithNotes >= AppConfig.selfAwareThreshold) {
      await _unlockBadge('self_aware');
    }

    if (getDailyGoalsMet() >= AppConfig.goalCrusherThreshold) {
      await _unlockBadge('goal_crusher');
    }
  }

  // ═══════════════════════════════════════
  // EVENT TRACKERS
  // ═══════════════════════════════════════

  static Future<void> onHabitCompleted(Habit habit) async {
    final now = DateTime.now();

    if (now.hour < 6) {
      await _incrementCounter('dawn_completions');
      await _incrementCounter('early_completions');
    } else if (now.hour < 8) {
      await _incrementCounter('early_completions');
    } else if (now.hour >= 22 && now.hour < 24) {
      await _incrementCounter('night_completions');
    } else if (now.hour >= 0 && now.hour < 4) {
      await _incrementCounter('midnight_completions');
      await _incrementCounter('night_completions');
    }

    if (habit.dailyGoal > 1 && habit.isDailyGoalMet()) {
      await _incrementCounter('daily_goals_met');
    } else if (habit.dailyGoal <= 1) {
      await _incrementCounter('daily_goals_met');
    }

    if (habit.wasMissedYesterday()) {
      await _incrementCounter('comeback_count');
    }

    // +5 XP per completion
    await addXp(5);

    await checkAllBadges();
  }

  static Future<void> onAlarmCompleted() async {
    await _incrementCounter('alarm_completions');
    await checkAllBadges();
  }

  static Future<void> onMissedReasonSubmitted() async {
    await _incrementCounter('missed_reasons_submitted');
    await checkAllBadges();
  }

  // ═══════════════════════════════════════
  // BADGE PROGRESS FOR UI
  // ═══════════════════════════════════════

  static double getBadgeProgress(BadgeDefinition badge) {
    final habits = DatabaseService.getAllHabits();
    int current = 0;

    switch (badge.category) {
      case BadgeCategory.streak:
        for (final h in habits) {
          final s =
          h.currentStreak > h.bestStreak ? h.currentStreak : h.bestStreak;
          if (s > current) current = s;
        }
        break;

      case BadgeCategory.completion:
        current = DatabaseService.getTotalHabitsCompleted();
        break;

      case BadgeCategory.perfection:
        current = getPerfectDayStreak();
        break;

      case BadgeCategory.recovery:
        current = getComebackCount();
        break;

      case BadgeCategory.timeBased:
        if (badge.id.startsWith('early_5')) {
          current = getEarlyCompletions();
        } else if (badge.id.startsWith('early_15')) {
          current = getDawnCompletions();
        } else if (badge.id.startsWith('night_5')) {
          current = getNightCompletions();
        } else if (badge.id.startsWith('night_15')) {
          current = getMidnightCompletions();
        }
        break;

      case BadgeCategory.variety:
        current = habits.where((h) => h.isActiveToday()).length;
        break;

      case BadgeCategory.special:
        if (badge.id == 'explorer') {
          current = habits.map((h) => h.category).toSet().length;
        } else if (badge.id == 'alarm_hero') {
          current = getAlarmCompletions();
        } else if (badge.id == 'no_excuse') {
          current = getMissedReasonsSubmitted();
        } else if (badge.id.startsWith('app_')) {
          current = getConsecutiveAppDays();
        } else if (badge.id == 'self_aware') {
          current = habits
              .where(
                  (h) => h.notes != null && h.notes!.trim().isNotEmpty)
              .length;
        } else if (badge.id == 'goal_crusher') {
          current = getDailyGoalsMet();
        }
        break;
    }

    return (current / badge.threshold).clamp(0.0, 1.0);
  }

  static String getBadgeProgressText(BadgeDefinition badge) {
    final progress = getBadgeProgress(badge);
    final current = (progress * badge.threshold).round();
    return '$current / ${badge.threshold}';
  }
}