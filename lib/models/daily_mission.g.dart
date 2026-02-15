// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_mission.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyMissionAdapter extends TypeAdapter<DailyMission> {
  @override
  final int typeId = 21;

  @override
  DailyMission read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyMission(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      flashcardIds: (fields[2] as List).cast<String>(),
      miniQuizTopic: fields[3] as String?,
      isCompleted: fields[4] as bool,
      estimatedTimeMinutes: fields[5] as int,
      momentumReward: fields[6] as int,
      difficultyLevel: fields[7] as int,
      completionScore: fields[8] as double,
      title: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DailyMission obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.flashcardIds)
      ..writeByte(3)
      ..write(obj.miniQuizTopic)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.estimatedTimeMinutes)
      ..writeByte(6)
      ..write(obj.momentumReward)
      ..writeByte(7)
      ..write(obj.difficultyLevel)
      ..writeByte(8)
      ..write(obj.completionScore)
      ..writeByte(9)
      ..write(obj.title);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyMissionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
