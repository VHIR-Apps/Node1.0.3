// lib/models/daily_study_routine_model.dart
//
// Daily/Weekly Study Routine system (separate from Pomodoro "StudyRoutine").
// This model represents recurring study blocks users can save and follow.
//
// Hive rules:
// - New typeIds must be 7+ (next available).
// - Do not touch existing typeIds.
// This file introduces:
// - DailyStudyRoutine: typeId 8
// - DailyStudyBlock: typeId 9
//
// UI text: English only (model contains only data; formatting helpers are English).

import 'package:hive/hive.dart';

part 'daily_study_routine_model.g.dart';

@HiveType(typeId: 9) // ✅ New typeId (7+). Do not change once released.
class DailyStudyBlock extends HiveObject {
  @HiveField(0)
  String id;

  /// Example: "Math", "Physics"
  @HiveField(1)
  String subjectName;

  /// ARGB color value.
  @HiveField(2)
  int subjectColorValue;

  /// Minutes from midnight. Example: 06:30 => 390
  @HiveField(3)
  int startMinuteOfDay;

  /// Minutes from midnight. Example: 08:00 => 480
  @HiveField(4)
  int endMinuteOfDay;

  /// ISO weekday numbers: 1=Mon ... 7=Sun
  /// If empty => treated as "Every day" by UI helpers.
  @HiveField(5)
  List<int> weekDays;

  @HiveField(6)
  bool isEnabled;

  /// Optional note shown in UI (e.g., "Mock test", "Chapter 3").
  @HiveField(7)
  String? note;

  DailyStudyBlock({
    required this.id,
    required this.subjectName,
    required this.subjectColorValue,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.weekDays,
    required this.isEnabled,
    this.note,
  });

  int get durationMinutes {
    final d = endMinuteOfDay - startMinuteOfDay;
    if (d <= 0) return 0;
    return d;
  }

  bool get isValidTimeRange =>
      startMinuteOfDay >= 0 &&
          endMinuteOfDay >= 0 &&
          startMinuteOfDay <= 24 * 60 &&
          endMinuteOfDay <= 24 * 60 &&
          endMinuteOfDay > startMinuteOfDay;

  DailyStudyBlock copyWith({
    String? id,
    String? subjectName,
    int? subjectColorValue,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    List<int>? weekDays,
    bool? isEnabled,
    String? note,
  }) {
    return DailyStudyBlock(
      id: id ?? this.id,
      subjectName: subjectName ?? this.subjectName,
      subjectColorValue: subjectColorValue ?? this.subjectColorValue,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
      weekDays: weekDays ?? List<int>.from(this.weekDays),
      isEnabled: isEnabled ?? this.isEnabled,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subjectName': subjectName,
      'subjectColorValue': subjectColorValue,
      'startMinuteOfDay': startMinuteOfDay,
      'endMinuteOfDay': endMinuteOfDay,
      'weekDays': weekDays,
      'isEnabled': isEnabled,
      'note': note,
    };
  }

  factory DailyStudyBlock.fromJson(Map<String, dynamic> json) {
    final rawDays = json['weekDays'];
    final days = <int>[];
    if (rawDays is List) {
      for (final d in rawDays) {
        final v = (d is num) ? d.toInt() : int.tryParse(d.toString());
        if (v != null && v >= 1 && v <= 7) days.add(v);
      }
    }

    return DailyStudyBlock(
      id: (json['id'] as String?)?.trim() ?? '',
      subjectName: (json['subjectName'] as String?)?.trim().isNotEmpty == true
          ? (json['subjectName'] as String).trim()
          : 'General',
      subjectColorValue: (json['subjectColorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
      startMinuteOfDay: (json['startMinuteOfDay'] as num?)?.toInt() ?? 0,
      endMinuteOfDay: (json['endMinuteOfDay'] as num?)?.toInt() ?? 0,
      weekDays: days,
      isEnabled: json['isEnabled'] as bool? ?? true,
      note: (json['note'] as String?)?.trim(),
    );
  }

  // Formatting helpers (English)
  static String formatMinuteOfDay(int minuteOfDay) {
    final m = minuteOfDay.clamp(0, 24 * 60);
    final hh24 = m ~/ 60;
    final mm = m % 60;

    final isPm = hh24 >= 12;
    int hh12 = hh24 % 12;
    if (hh12 == 0) hh12 = 12;

    final mmStr = mm.toString().padLeft(2, '0');
    final suffix = isPm ? 'PM' : 'AM';
    return '$hh12:$mmStr $suffix';
  }

  String get formattedTimeRange {
    return '${formatMinuteOfDay(startMinuteOfDay)} - ${formatMinuteOfDay(endMinuteOfDay)}';
  }

  String get formattedWeekDays {
    if (weekDays.isEmpty) return 'Every day';

    const short = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    final unique = weekDays.toSet().toList()..sort();
    return unique.map((d) => short[d] ?? '?').join(', ');
  }
}

@HiveType(typeId: 8) // ✅ New typeId (7+). Do not change once released.
class DailyStudyRoutine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Optional accent color for the routine card.
  @HiveField(2)
  int colorValue;

  /// A list of recurring blocks (time + subject + weekdays).
  @HiveField(3)
  List<DailyStudyBlock> blocks;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  /// Optional note for the entire routine (e.g., "Exam prep schedule").
  @HiveField(7)
  String? description;

  DailyStudyRoutine({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.blocks,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  int get totalPlannedMinutes {
    int total = 0;
    for (final b in blocks) {
      if (!b.isEnabled) continue;
      total += b.durationMinutes;
    }
    return total;
  }

  int get enabledBlocksCount => blocks.where((b) => b.isEnabled).length;

  DailyStudyRoutine copyWith({
    String? id,
    String? name,
    int? colorValue,
    List<DailyStudyBlock>? blocks,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
  }) {
    return DailyStudyRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      blocks: blocks ?? List<DailyStudyBlock>.from(this.blocks),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'blocks': blocks.map((b) => b.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
    };
  }

  factory DailyStudyRoutine.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    final blocks = <DailyStudyBlock>[];
    if (rawBlocks is List) {
      for (final item in rawBlocks) {
        try {
          if (item is Map) {
            blocks.add(DailyStudyBlock.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {
          // Skip invalid blocks
        }
      }
    }

    final createdAt = DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now();
    final updatedAt = DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? createdAt;

    return DailyStudyRoutine(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'My Study Routine',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
      blocks: blocks,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: createdAt,
      updatedAt: updatedAt,
      description: (json['description'] as String?)?.trim(),
    );
  }
}