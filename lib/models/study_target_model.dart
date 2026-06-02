// lib/models/study_target_model.dart

import 'package:hive/hive.dart';

part 'study_target_model.g.dart';

@HiveType(typeId: 7) // ✅ NEXT AVAILABLE typeId
class StudyTarget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int dailyTargetMinutes;

  @HiveField(2)
  int weeklyTargetMinutes;

  @HiveField(3)
  Map<String, int> subjectTargets; // subject name → target minutes (weekly)

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  String targetType; // 'daily', 'weekly', 'subject'

  @HiveField(8)
  int reminderHour; // Reminder time (optional)

  @HiveField(9)
  int reminderMinute;

  @HiveField(10)
  bool reminderEnabled;

  StudyTarget({
    required this.id,
    required this.dailyTargetMinutes,
    required this.weeklyTargetMinutes,
    required this.subjectTargets,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.targetType = 'daily',
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.reminderEnabled = false,
  });

  // ═══════════════════════════════════════
  // PROGRESS CALCULATION
  // ═══════════════════════════════════════

  /// Get daily progress percentage (0.0 to 1.0)
  double getDailyProgress(int completedMinutesToday) {
    if (dailyTargetMinutes <= 0) return 0.0;
    return (completedMinutesToday / dailyTargetMinutes).clamp(0.0, 1.0);
  }

  /// Get weekly progress percentage (0.0 to 1.0)
  double getWeeklyProgress(int completedMinutesThisWeek) {
    if (weeklyTargetMinutes <= 0) return 0.0;
    return (completedMinutesThisWeek / weeklyTargetMinutes).clamp(0.0, 1.0);
  }

  /// Get subject progress percentage (0.0 to 1.0)
  double getSubjectProgress(String subject, int completedMinutes) {
    final target = subjectTargets[subject];
    if (target == null || target <= 0) return 0.0;
    return (completedMinutes / target).clamp(0.0, 1.0);
  }

  /// Check if daily target is achieved
  bool isDailyTargetAchieved(int completedMinutesToday) {
    return completedMinutesToday >= dailyTargetMinutes;
  }

  /// Check if weekly target is achieved
  bool isWeeklyTargetAchieved(int completedMinutesThisWeek) {
    return completedMinutesThisWeek >= weeklyTargetMinutes;
  }

  /// Check if subject target is achieved
  bool isSubjectTargetAchieved(String subject, int completedMinutes) {
    final target = subjectTargets[subject];
    if (target == null) return false;
    return completedMinutes >= target;
  }

  // ═══════════════════════════════════════
  // FORMATTED STRINGS
  // ═══════════════════════════════════════

  String getFormattedDailyTarget() {
    final hours = dailyTargetMinutes ~/ 60;
    final mins = dailyTargetMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    } else {
      return '$mins min';
    }
  }

  String getFormattedWeeklyTarget() {
    final hours = weeklyTargetMinutes ~/ 60;
    final mins = weeklyTargetMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    } else {
      return '$mins min';
    }
  }

  String getRemainingDailyTime(int completedMinutesToday) {
    final remaining = (dailyTargetMinutes - completedMinutesToday).clamp(0, 99999);
    final hours = remaining ~/ 60;
    final mins = remaining % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min left';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''} left';
    } else if (mins > 0) {
      return '$mins min left';
    } else {
      return 'Target achieved! 🎉';
    }
  }

  String getRemainingWeeklyTime(int completedMinutesThisWeek) {
    final remaining = (weeklyTargetMinutes - completedMinutesThisWeek).clamp(0, 99999);
    final hours = remaining ~/ 60;
    final mins = remaining % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min left';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''} left';
    } else if (mins > 0) {
      return '$mins min left';
    } else {
      return 'Target achieved! 🎉';
    }
  }

  // ═══════════════════════════════════════
  // COPY WITH
  // ═══════════════════════════════════════

  StudyTarget copyWith({
    String? id,
    int? dailyTargetMinutes,
    int? weeklyTargetMinutes,
    Map<String, int>? subjectTargets,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? targetType,
    int? reminderHour,
    int? reminderMinute,
    bool? reminderEnabled,
  }) {
    return StudyTarget(
      id: id ?? this.id,
      dailyTargetMinutes: dailyTargetMinutes ?? this.dailyTargetMinutes,
      weeklyTargetMinutes: weeklyTargetMinutes ?? this.weeklyTargetMinutes,
      subjectTargets: subjectTargets ?? Map<String, int>.from(this.subjectTargets),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      targetType: targetType ?? this.targetType,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }

  // ═══════════════════════════════════════
  // JSON SERIALIZATION
  // ═══════════════════════════════════════

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dailyTargetMinutes': dailyTargetMinutes,
      'weeklyTargetMinutes': weeklyTargetMinutes,
      'subjectTargets': subjectTargets,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'targetType': targetType,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'reminderEnabled': reminderEnabled,
    };
  }

  factory StudyTarget.fromJson(Map<String, dynamic> json) {
    return StudyTarget(
      id: json['id'] as String? ?? '',
      dailyTargetMinutes: (json['dailyTargetMinutes'] as num?)?.toInt() ?? 120,
      weeklyTargetMinutes: (json['weeklyTargetMinutes'] as num?)?.toInt() ?? 900,
      subjectTargets: (json['subjectTargets'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ) ?? {},
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      targetType: json['targetType'] as String? ?? 'daily',
      reminderHour: (json['reminderHour'] as num?)?.toInt() ?? 20,
      reminderMinute: (json['reminderMinute'] as num?)?.toInt() ?? 0,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
    );
  }
}