// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_target_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudyTargetAdapter extends TypeAdapter<StudyTarget> {
  @override
  final int typeId = 7;

  @override
  StudyTarget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudyTarget(
      id: fields[0] as String,
      dailyTargetMinutes: fields[1] as int,
      weeklyTargetMinutes: fields[2] as int,
      subjectTargets: (fields[3] as Map).cast<String, int>(),
      isActive: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      targetType: fields[7] == null ? 'daily' : fields[7] as String,
      reminderHour: fields[8] == null ? 20 : fields[8] as int,
      reminderMinute: fields[9] == null ? 0 : fields[9] as int,
      reminderEnabled: fields[10] == null ? false : fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StudyTarget obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dailyTargetMinutes)
      ..writeByte(2)
      ..write(obj.weeklyTargetMinutes)
      ..writeByte(3)
      ..write(obj.subjectTargets)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.targetType)
      ..writeByte(8)
      ..write(obj.reminderHour)
      ..writeByte(9)
      ..write(obj.reminderMinute)
      ..writeByte(10)
      ..write(obj.reminderEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StudyTargetAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}