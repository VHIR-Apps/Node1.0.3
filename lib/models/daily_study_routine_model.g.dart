// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_study_routine_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyStudyBlockAdapter extends TypeAdapter<DailyStudyBlock> {
  @override
  final int typeId = 9;

  @override
  DailyStudyBlock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyStudyBlock(
      id: fields[0] as String,
      subjectName: fields[1] as String,
      subjectColorValue: fields[2] as int,
      startMinuteOfDay: fields[3] as int,
      endMinuteOfDay: fields[4] as int,
      weekDays: (fields[5] as List).cast<int>(),
      isEnabled: fields[6] as bool,
      note: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyStudyBlock obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subjectName)
      ..writeByte(2)
      ..write(obj.subjectColorValue)
      ..writeByte(3)
      ..write(obj.startMinuteOfDay)
      ..writeByte(4)
      ..write(obj.endMinuteOfDay)
      ..writeByte(5)
      ..write(obj.weekDays)
      ..writeByte(6)
      ..write(obj.isEnabled)
      ..writeByte(7)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyStudyBlockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyStudyRoutineAdapter extends TypeAdapter<DailyStudyRoutine> {
  @override
  final int typeId = 8;

  @override
  DailyStudyRoutine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyStudyRoutine(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      blocks: (fields[3] as List).cast<DailyStudyBlock>(),
      isActive: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      description: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyStudyRoutine obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.blocks)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyStudyRoutineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
