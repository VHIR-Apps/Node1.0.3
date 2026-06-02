// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      colorValue: fields[3] as int,
      category: fields[4] as String,
      frequency: fields[5] as String,
      time: fields[6] as String?,
      reminderEnabled: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      completedDates: (fields[9] as List).cast<String>(),
      currentStreak: fields[10] as int,
      bestStreak: fields[11] as int,
      description: fields[12] as String?,
      priority: fields[13] as String,
      startDate: fields[14] as DateTime?,
      endDate: fields[15] as DateTime?,
      dailyGoal: fields[16] as int,
      dailyGoalUnit: fields[17] as String?,
      dailyGoalProgress: fields[18] as int,
      extraGoals: (fields[19] as List?)?.cast<String>(),
      alarmSoundPath: fields[20] as String?,
      alarmDescription: fields[21] as String?,
      alarmEnabled: fields[22] as bool,
      customDays: (fields[23] as List?)?.cast<int>(),
      notes: fields[24] as String?,
      totalCompletions: fields[25] as int,
      lastProgressDate: fields[26] as String?,
      missedReasons: (fields[27] as List?)?.cast<String>(),
      isCustomCategory: fields[28] as bool,
      dailyProgressMap: (fields[29] as Map?)?.cast<String, int>(),
      alarmRepeatCount: fields[30] == null ? 3 : fields[30] as int,
      ttsRepeatCount: fields[31] == null ? 2 : fields[31] as int,
      alarmTime: fields[32] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(33)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.time)
      ..writeByte(7)
      ..write(obj.reminderEnabled)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.completedDates)
      ..writeByte(10)
      ..write(obj.currentStreak)
      ..writeByte(11)
      ..write(obj.bestStreak)
      ..writeByte(12)
      ..write(obj.description)
      ..writeByte(13)
      ..write(obj.priority)
      ..writeByte(14)
      ..write(obj.startDate)
      ..writeByte(15)
      ..write(obj.endDate)
      ..writeByte(16)
      ..write(obj.dailyGoal)
      ..writeByte(17)
      ..write(obj.dailyGoalUnit)
      ..writeByte(18)
      ..write(obj.dailyGoalProgress)
      ..writeByte(19)
      ..write(obj.extraGoals)
      ..writeByte(20)
      ..write(obj.alarmSoundPath)
      ..writeByte(21)
      ..write(obj.alarmDescription)
      ..writeByte(22)
      ..write(obj.alarmEnabled)
      ..writeByte(23)
      ..write(obj.customDays)
      ..writeByte(24)
      ..write(obj.notes)
      ..writeByte(25)
      ..write(obj.totalCompletions)
      ..writeByte(26)
      ..write(obj.lastProgressDate)
      ..writeByte(27)
      ..write(obj.missedReasons)
      ..writeByte(28)
      ..write(obj.isCustomCategory)
      ..writeByte(29)
      ..write(obj.dailyProgressMap)
      ..writeByte(30)
      ..write(obj.alarmRepeatCount)
      ..writeByte(31)
      ..write(obj.ttsRepeatCount)
      ..writeByte(32)
      ..write(obj.alarmTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HabitAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}