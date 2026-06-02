// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_routine_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudyRoutineAdapter extends TypeAdapter<StudyRoutine> {
  @override
  final int typeId = 3;

  @override
  StudyRoutine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudyRoutine(
      id: fields[0] as String,
      name: fields[1] as String,
      sessions: (fields[2] as List).cast<RoutineSession>(),
      createdAt: fields[3] as DateTime,
      isActive: fields[4] as bool,
      totalDurationMinutes: fields[5] as int,
      description: fields[6] as String?,
      autoPlayEnabled: fields[7] as bool,
      ttsEnabled: fields[8] as bool,
      timesCompleted: fields[9] as int,
      lastPlayedAt: fields[10] as DateTime?,
      emoji: fields[11] as String,
      colorValue: fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StudyRoutine obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sessions)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.totalDurationMinutes)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.autoPlayEnabled)
      ..writeByte(8)
      ..write(obj.ttsEnabled)
      ..writeByte(9)
      ..write(obj.timesCompleted)
      ..writeByte(10)
      ..write(obj.lastPlayedAt)
      ..writeByte(11)
      ..write(obj.emoji)
      ..writeByte(12)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyRoutineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoutineSessionAdapter extends TypeAdapter<RoutineSession> {
  @override
  final int typeId = 4;

  @override
  RoutineSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutineSession(
      subjectName: fields[0] as String,
      subjectColorValue: fields[1] as int,
      durationMinutes: fields[2] as int,
      includeBreak: fields[3] as bool,
      breakDurationMinutes: fields[4] as int,
      customMessage: fields[5] as String?,
      order: fields[6] as int,
      emoji: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RoutineSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.subjectName)
      ..writeByte(1)
      ..write(obj.subjectColorValue)
      ..writeByte(2)
      ..write(obj.durationMinutes)
      ..writeByte(3)
      ..write(obj.includeBreak)
      ..writeByte(4)
      ..write(obj.breakDurationMinutes)
      ..writeByte(5)
      ..write(obj.customMessage)
      ..writeByte(6)
      ..write(obj.order)
      ..writeByte(7)
      ..write(obj.emoji);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
