import 'package:hive/hive.dart';

part 'daily_mission.g.dart';

@HiveType(typeId: 21)
class DailyMission extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  List<String> flashcardIds;

  @HiveField(3)
  String? miniQuizTopic;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  int estimatedTimeMinutes;

  @HiveField(6)
  int momentumReward;

  @HiveField(7)
  int difficultyLevel; // 1 to 5

  @HiveField(8)
  double completionScore; // 0.0 to 1.0

  @HiveField(9)
  String title;


  DailyMission({
    required this.id,
    required this.date,
    required this.flashcardIds,
    this.miniQuizTopic,
    required this.isCompleted,
    required this.estimatedTimeMinutes,
    required this.momentumReward,
    required this.difficultyLevel,
    required this.completionScore,
    required this.title,
  });
}
