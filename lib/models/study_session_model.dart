import 'package:hive/hive.dart';

part 'study_session_model.g.dart';

@HiveType(typeId: 2)
class StudySession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectName;

  @HiveField(2)
  int subjectColorValue;

  @HiveField(3)
  DateTime startTime;

  @HiveField(4)
  DateTime? endTime;

  @HiveField(5)
  int durationMinutes;

  @HiveField(6)
  String sessionType;

  @HiveField(7)
  DateTime completedAt;

  @HiveField(8)
  int pomodoroCount;

  @HiveField(9)
  bool isCompleted;

  StudySession({
    required this.id,
    required this.subjectName,
    required this.subjectColorValue,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.sessionType,
    required this.completedAt,
    required this.pomodoroCount,
    required this.isCompleted,
  });
}