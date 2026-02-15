// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_quiz_question.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalQuizQuestionAdapter extends TypeAdapter<LocalQuizQuestion> {
  @override
  final int typeId = 2;

  @override
  LocalQuizQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalQuizQuestion(
      question: fields[0] as String,
      options: (fields[1] as List).cast<String>(),
      correctAnswer: fields[2] as String,
      explanation: fields[3] as String?,
      questionType: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalQuizQuestion obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.question)
      ..writeByte(1)
      ..write(obj.options)
      ..writeByte(2)
      ..write(obj.correctAnswer)
      ..writeByte(3)
      ..write(obj.explanation)
      ..writeByte(4)
      ..write(obj.questionType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalQuizQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
