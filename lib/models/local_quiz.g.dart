// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_quiz.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalQuizAdapter extends TypeAdapter<LocalQuiz> {
  @override
  final int typeId = 1;

  @override
  LocalQuiz read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalQuiz(
      id: fields[0] as String,
      title: fields[1] as String,
      questions: (fields[2] as List).cast<LocalQuizQuestion>(),
      timestamp: fields[3] as DateTime,
      isSynced: fields[4] as bool,
      userId: fields[5] as String,
      scores: (fields[6] as List?)?.cast<double>(),
      isReadOnly: fields[7] as bool,
      publicDeckId: fields[8] as String?,
      creatorName: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalQuiz obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.questions)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.isSynced)
      ..writeByte(5)
      ..write(obj.userId)
      ..writeByte(6)
      ..write(obj.scores)
      ..writeByte(7)
      ..write(obj.isReadOnly)
      ..writeByte(8)
      ..write(obj.publicDeckId)
      ..writeByte(9)
      ..write(obj.creatorName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalQuizAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
