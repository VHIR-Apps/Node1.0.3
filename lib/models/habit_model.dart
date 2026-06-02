// lib/models/habit_model.dart

import 'package:hive/hive.dart';

part 'habit_model.g.dart';

@HiveType(typeId: 0)
class Habit {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String emoji;

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  String category;

  @HiveField(5)
  String frequency;

  @HiveField(6)
  String? time;

  @HiveField(7)
  bool reminderEnabled;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  List<String> completedDates;

  @HiveField(10)
  int currentStreak;

  @HiveField(11)
  int bestStreak;

  @HiveField(12)
  String? description;

  @HiveField(13)
  String priority;

  @HiveField(14)
  DateTime? startDate;

  @HiveField(15)
  DateTime? endDate;

  @HiveField(16)
  int dailyGoal;

  @HiveField(17)
  String? dailyGoalUnit;

  @HiveField(18)
  int dailyGoalProgress;

  @HiveField(19)
  List<String>? extraGoals;

  @HiveField(20)
  String? alarmSoundPath;

  @HiveField(21)
  String? alarmDescription;

  @HiveField(22)
  bool alarmEnabled;

  @HiveField(23)
  List<int>? customDays;

  @HiveField(24)
  String? notes;

  @HiveField(25)
  int totalCompletions;

  @HiveField(26)
  String? lastProgressDate;

  @HiveField(27)
  List<String>? missedReasons;

  @HiveField(28)
  bool isCustomCategory;

  @HiveField(29)
  Map<String, int>? dailyProgressMap;

  @HiveField(30)
  int alarmRepeatCount;

  @HiveField(31)
  int ttsRepeatCount;

  @HiveField(32)
  String? alarmTime;

  Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.category,
    this.frequency = 'daily',
    this.time,
    this.reminderEnabled = false,
    required this.createdAt,
    List<String>? completedDates,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.description,
    this.priority = 'medium',
    this.startDate,
    this.endDate,
    this.dailyGoal = 1,
    this.dailyGoalUnit,
    this.dailyGoalProgress = 0,
    this.extraGoals,
    this.alarmSoundPath,
    this.alarmDescription,
    this.alarmEnabled = false,
    this.customDays,
    this.notes,
    this.totalCompletions = 0,
    this.lastProgressDate,
    this.missedReasons,
    this.isCustomCategory = false,
    this.dailyProgressMap,
    this.alarmRepeatCount = 3,
    this.ttsRepeatCount = 2,
    this.alarmTime,
  }) : completedDates = completedDates ?? [];

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  String _getTodayString() {
    return DateTime.now().toString().split(' ')[0];
  }

  int getTodayProgress() {
    final today = _getTodayString();
    if (lastProgressDate != today) return 0;
    if (dailyProgressMap != null &&
        dailyProgressMap!.containsKey(today)) {
      return dailyProgressMap![today] ?? 0;
    }
    return dailyGoalProgress;
  }

  void _setTodayProgress(int value) {
    final today = _getTodayString();
    dailyGoalProgress = value;
    lastProgressDate = today;
    dailyProgressMap ??= {};
    dailyProgressMap![today] = value;
  }

  // ─────────────────────────────────────────────
  // COMPLETION
  // ─────────────────────────────────────────────

  bool isCompletedToday() {
    final today = _getTodayString();
    if (dailyGoal > 1) {
      return getTodayProgress() >= dailyGoal;
    }
    return completedDates.contains(today);
  }

  /// Returns: 0 = normal increment, 1 = just completed, 2 = already complete
  int incrementProgress() {
    final today = _getTodayString();
    if (lastProgressDate != today) {
      dailyGoalProgress = 0;
      lastProgressDate = today;
    }
    final currentProgress = getTodayProgress();
    if (currentProgress >= dailyGoal) return 2;

    final newProgress = currentProgress + 1;
    _setTodayProgress(newProgress);

    if (newProgress >= dailyGoal) {
      if (!completedDates.contains(today)) {
        completedDates.add(today);
        totalCompletions++;
        _updateStreak();
      }
      return 1;
    }
    return 0;
  }

  /// Returns: true if was completed and now undone
  bool decrementProgress() {
    final today = _getTodayString();
    if (lastProgressDate != today) return false;

    final currentProgress = getTodayProgress();
    final wasCompleted = currentProgress >= dailyGoal;

    if (currentProgress > 0) {
      final newProgress = currentProgress - 1;
      _setTodayProgress(newProgress);
      if (wasCompleted && newProgress < dailyGoal) {
        completedDates.remove(today);
        if (totalCompletions > 0) totalCompletions--;
        _updateStreak();
        return true;
      }
    }
    return false;
  }

  void toggleComplete() {
    final today = _getTodayString();
    if (dailyGoal > 1) {
      incrementProgress();
    } else {
      if (completedDates.contains(today)) {
        completedDates.remove(today);
        if (totalCompletions > 0) totalCompletions--;
        _setTodayProgress(0);
      } else {
        completedDates.add(today);
        totalCompletions++;
        _setTodayProgress(1);
      }
      _updateStreak();
    }
  }

  void forceComplete() {
    final today = _getTodayString();
    if (!completedDates.contains(today)) {
      completedDates.add(today);
      totalCompletions++;
    }
    _setTodayProgress(dailyGoal);
    _updateStreak();
  }

  void forceUncomplete() {
    final today = _getTodayString();
    if (completedDates.contains(today)) {
      completedDates.remove(today);
      if (totalCompletions > 0) totalCompletions--;
    }
    _setTodayProgress(0);
    _updateStreak();
  }

  int getProgressForDate(String dateStr) {
    if (dailyProgressMap != null &&
        dailyProgressMap!.containsKey(dateStr)) {
      return dailyProgressMap![dateStr] ?? 0;
    }
    if (completedDates.contains(dateStr)) return dailyGoal;
    return 0;
  }

  // ─────────────────────────────────────────────
  // STREAK
  // ─────────────────────────────────────────────

  void _updateStreak() {
    if (completedDates.isEmpty) {
      currentStreak = 0;
      return;
    }
    completedDates.sort();
    int streak = 1;
    DateTime previousDate = DateTime.parse(completedDates.last);

    for (int i = completedDates.length - 2; i >= 0; i--) {
      final currentDate = DateTime.parse(completedDates[i]);
      final difference = previousDate.difference(currentDate).inDays;
      if (difference == 1) {
        streak++;
        previousDate = currentDate;
      } else {
        break;
      }
    }
    currentStreak = streak;
    if (streak > bestStreak) bestStreak = streak;
  }

  // ─────────────────────────────────────────────
  // COMPLETION RATES
  // ─────────────────────────────────────────────

  double getWeeklyCompletionRate() {
    final now = DateTime.now();
    int completedCount = 0;
    for (int i = 0; i < 7; i++) {
      final date =
      now.subtract(Duration(days: i)).toString().split(' ')[0];
      if (completedDates.contains(date)) completedCount++;
    }
    return (completedCount / 7) * 100;
  }

  double getMonthlyCompletionRate() {
    final now = DateTime.now();
    int completedCount = 0;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (int i = 0; i < daysInMonth; i++) {
      final date =
      DateTime(now.year, now.month, i + 1).toString().split(' ')[0];
      if (completedDates.contains(date)) completedCount++;
    }
    return (completedCount / daysInMonth) * 100;
  }

  // ─────────────────────────────────────────────
  // DAILY GOAL HELPERS
  // ─────────────────────────────────────────────

  double getDailyGoalPercent() {
    if (dailyGoal <= 0) return 0;
    return (getTodayProgress() / dailyGoal * 100).clamp(0.0, 100.0);
  }

  bool isDailyGoalMet() {
    return getTodayProgress() >= dailyGoal;
  }

  // ✅ FIX: .clamp() returns num — cast to int explicitly
  void incrementDailyGoalProgress([int amount = 1]) {
    final current = getTodayProgress();
    _setTodayProgress(
      (current + amount).clamp(0, dailyGoal * 2).toInt(),
    );
  }

  void resetDailyGoalProgress() {
    _setTodayProgress(0);
  }

  // ─────────────────────────────────────────────
  // ACTIVE / EXPIRED
  // ─────────────────────────────────────────────

  bool isActiveToday() {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    if (frequency == 'custom' &&
        customDays != null &&
        customDays!.isNotEmpty) {
      return customDays!.contains(now.weekday);
    }
    return true;
  }

  bool isExpired() {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  int get daysActive {
    return DateTime.now().difference(createdAt).inDays + 1;
  }

  double get overallCompletionRate {
    if (daysActive <= 0) return 0;
    return (completedDates.length / daysActive * 100).clamp(0.0, 100.0);
  }

  // ─────────────────────────────────────────────
  // MISSED REASON HELPERS
  // ─────────────────────────────────────────────

  void addMissedReason(String date, String reason) {
    missedReasons ??= [];
    missedReasons!.removeWhere((r) => r.startsWith('$date:'));
    missedReasons!.add('$date:$reason');
  }

  String? getMissedReason(String date) {
    if (missedReasons == null) return null;
    for (final r in missedReasons!) {
      if (r.startsWith('$date:')) {
        return r.split(':').skip(1).join(':');
      }
    }
    return null;
  }

  String? getLastMissedReason() {
    if (missedReasons == null || missedReasons!.isEmpty) return null;
    return missedReasons!.last.split(':').skip(1).join(':');
  }

  List<String> getRecentMissedReasons([int days = 7]) {
    if (missedReasons == null) return [];
    final now = DateTime.now();
    final results = <String>[];
    for (int i = 1; i <= days; i++) {
      final date =
      now.subtract(Duration(days: i)).toString().split(' ')[0];
      final reason = getMissedReason(date);
      if (reason != null) results.add('$date:$reason');
    }
    return results;
  }

  bool wasMissedYesterday() {
    final yesterday =
    DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = yesterday.toString().split(' ')[0];
    if (createdAt.isAfter(yesterday)) return false;
    if (startDate != null && yesterday.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null && yesterday.isAfter(endDate!)) return false;
    if (frequency == 'custom' &&
        customDays != null &&
        customDays!.isNotEmpty) {
      if (!customDays!.contains(yesterday.weekday)) return false;
    }
    return !completedDates.contains(yesterdayStr);
  }

  bool hasReasonForYesterday() {
    final yesterday =
    DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = yesterday.toString().split(' ')[0];
    return getMissedReason(yesterdayStr) != null;
  }

  // ─────────────────────────────────────────────
  // PRIORITY HELPERS
  // ─────────────────────────────────────────────

  int get priorityColorValue {
    switch (priority) {
      case 'critical':
        return 0xFFEF4444;
      case 'high':
        return 0xFFF97316;
      case 'medium':
        return 0xFFEAB308;
      case 'low':
        return 0xFF22C55E;
      default:
        return 0xFFEAB308;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'critical':
        return '🔴 Critical';
      case 'high':
        return '🟠 High';
      case 'medium':
        return '🟡 Medium';
      case 'low':
        return '🟢 Low';
      default:
        return '🟡 Medium';
    }
  }

  // ─────────────────────────────────────────────
  // JSON
  // ─────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorValue': colorValue,
      'category': category,
      'frequency': frequency,
      'time': time,
      'reminderEnabled': reminderEnabled,
      'createdAt': createdAt.toIso8601String(),
      'completedDates': completedDates.toList(),
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'description': description,
      'priority': priority,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'dailyGoal': dailyGoal,
      'dailyGoalUnit': dailyGoalUnit,
      'dailyGoalProgress': dailyGoalProgress,
      'extraGoals': extraGoals,
      'alarmSoundPath': alarmSoundPath,
      'alarmDescription': alarmDescription,
      'alarmEnabled': alarmEnabled,
      'customDays': customDays,
      'notes': notes,
      'totalCompletions': totalCompletions,
      'lastProgressDate': lastProgressDate,
      'missedReasons': missedReasons,
      'isCustomCategory': isCustomCategory,
      'dailyProgressMap': dailyProgressMap,
      'alarmRepeatCount': alarmRepeatCount,
      'ttsRepeatCount': ttsRepeatCount,
      'alarmTime': alarmTime,
    };
  }

  factory Habit.fromJson(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] as String? ?? 'Unnamed',
      emoji: map['emoji'] as String? ?? '✅',
      colorValue: map['colorValue'] as int? ?? 0xFF6C63FF,
      category: map['category'] as String? ?? 'Other',
      frequency: map['frequency'] as String? ?? 'daily',
      time: map['time'] as String?,
      reminderEnabled: map['reminderEnabled'] as bool? ?? false,
      createdAt: DateTime.tryParse(
        map['createdAt'] as String? ?? '',
      ) ??
          DateTime.now(),
      completedDates: (map['completedDates'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      currentStreak: map['currentStreak'] as int? ?? 0,
      bestStreak: map['bestStreak'] as int? ?? 0,
      description: map['description'] as String?,
      priority: map['priority'] as String? ?? 'medium',
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'] as String)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'] as String)
          : null,
      dailyGoal: map['dailyGoal'] as int? ?? 1,
      dailyGoalUnit: map['dailyGoalUnit'] as String?,
      dailyGoalProgress: map['dailyGoalProgress'] as int? ?? 0,
      extraGoals: (map['extraGoals'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      alarmSoundPath: map['alarmSoundPath'] as String?,
      alarmDescription: map['alarmDescription'] as String?,
      alarmEnabled: map['alarmEnabled'] as bool? ?? false,
      customDays: (map['customDays'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      notes: map['notes'] as String?,
      totalCompletions: map['totalCompletions'] as int? ?? 0,
      lastProgressDate: map['lastProgressDate'] as String?,
      missedReasons: (map['missedReasons'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      isCustomCategory: map['isCustomCategory'] as bool? ?? false,
      dailyProgressMap:
      (map['dailyProgressMap'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)),
      alarmRepeatCount: map['alarmRepeatCount'] as int? ?? 3,
      ttsRepeatCount: map['ttsRepeatCount'] as int? ?? 2,
      alarmTime: map['alarmTime'] as String?,
    );
  }
}