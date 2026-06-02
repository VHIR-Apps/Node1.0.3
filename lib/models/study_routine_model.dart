// lib/models/study_routine_model.dart

import 'package:hive/hive.dart';

part 'study_routine_model.g.dart';

/// 🍅 Study Routine - Contains multiple study sessions
/// typeId: 3 (Next available)
@HiveType(typeId: 3)
class StudyRoutine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<RoutineSession> sessions;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  int totalDurationMinutes;

  @HiveField(6)
  String? description;

  @HiveField(7)
  bool autoPlayEnabled;

  @HiveField(8)
  bool ttsEnabled;

  @HiveField(9)
  int timesCompleted;

  @HiveField(10)
  DateTime? lastPlayedAt;

  @HiveField(11)
  String emoji;

  @HiveField(12)
  int colorValue;

  StudyRoutine({
    required this.id,
    required this.name,
    required this.sessions,
    required this.createdAt,
    this.isActive = false,
    this.totalDurationMinutes = 0,
    this.description,
    this.autoPlayEnabled = true,
    this.ttsEnabled = true,
    this.timesCompleted = 0,
    this.lastPlayedAt,
    this.emoji = '📚',
    this.colorValue = 0xFF6C63FF,
  }) {
    _calculateTotalDuration();
  }

  void _calculateTotalDuration() {
    totalDurationMinutes = 0;
    for (var session in sessions) {
      totalDurationMinutes += session.durationMinutes;
      if (session.includeBreak) {
        totalDurationMinutes += session.breakDurationMinutes;
      }
    }
  }

  void updateTotalDuration() {
    _calculateTotalDuration();
  }

  String getFormattedDuration() {
    final hours = totalDurationMinutes ~/ 60;
    final mins = totalDurationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  int get totalFocusMinutes {
    int total = 0;
    for (var session in sessions) {
      total += session.durationMinutes;
    }
    return total;
  }

  int get totalBreakMinutes {
    int total = 0;
    for (var session in sessions) {
      if (session.includeBreak) {
        total += session.breakDurationMinutes;
      }
    }
    return total;
  }

  int get sessionCount => sessions.length;

  StudyRoutine copyWith({
    String? id,
    String? name,
    List<RoutineSession>? sessions,
    DateTime? createdAt,
    bool? isActive,
    int? totalDurationMinutes,
    String? description,
    bool? autoPlayEnabled,
    bool? ttsEnabled,
    int? timesCompleted,
    DateTime? lastPlayedAt,
    String? emoji,
    int? colorValue,
  }) {
    return StudyRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      sessions: sessions ?? List.from(this.sessions),
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      description: description ?? this.description,
      autoPlayEnabled: autoPlayEnabled ?? this.autoPlayEnabled,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      timesCompleted: timesCompleted ?? this.timesCompleted,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

/// 🍅 Routine Session - Individual subject session within a routine
/// typeId: 4 (Next available)
@HiveType(typeId: 4)
class RoutineSession {
  @HiveField(0)
  String subjectName;

  @HiveField(1)
  int subjectColorValue;

  @HiveField(2)
  int durationMinutes;

  @HiveField(3)
  bool includeBreak;

  @HiveField(4)
  int breakDurationMinutes;

  @HiveField(5)
  String? customMessage;

  @HiveField(6)
  int order;

  @HiveField(7)
  String emoji;

  RoutineSession({
    required this.subjectName,
    required this.subjectColorValue,
    required this.durationMinutes,
    this.includeBreak = true,
    this.breakDurationMinutes = 5,
    this.customMessage,
    this.order = 0,
    this.emoji = '📖',
  });

  String getStartMessage() {
    if (customMessage != null && customMessage!.isNotEmpty) {
      return customMessage!;
    }
    return 'Starting $subjectName session. Focus for $durationMinutes minutes.';
  }

  String getBreakMessage() {
    return '$subjectName session completed. Take a $breakDurationMinutes minute break.';
  }

  String getEndMessage() {
    return '$subjectName session completed. Great work!';
  }

  String getFormattedDuration() {
    String main = '${durationMinutes}m';
    if (includeBreak) {
      return '$main + ${breakDurationMinutes}m break';
    }
    return main;
  }

  int get totalDuration => durationMinutes + (includeBreak ? breakDurationMinutes : 0);

  RoutineSession copyWith({
    String? subjectName,
    int? subjectColorValue,
    int? durationMinutes,
    bool? includeBreak,
    int? breakDurationMinutes,
    String? customMessage,
    int? order,
    String? emoji,
  }) {
    return RoutineSession(
      subjectName: subjectName ?? this.subjectName,
      subjectColorValue: subjectColorValue ?? this.subjectColorValue,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      includeBreak: includeBreak ?? this.includeBreak,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      customMessage: customMessage ?? this.customMessage,
      order: order ?? this.order,
      emoji: emoji ?? this.emoji,
    );
  }
}