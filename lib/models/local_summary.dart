import 'package:hive/hive.dart';

part 'local_summary.g.dart';

@HiveType(typeId: 0)
class LocalSummary extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String content;

  @HiveField(2)
  late DateTime timestamp;

  @HiveField(3)
  late bool isSynced;

  @HiveField(4)
  late String userId;

  @HiveField(5)
  late String title;

  @HiveField(6)
  late List<String> tags;

  @HiveField(7)
  late bool isReadOnly;

  LocalSummary({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.isSynced = false,
    required this.userId,
    this.tags = const [],
    this.isReadOnly = false,
  });

  factory LocalSummary.fromJson(Map<String, dynamic> json) => LocalSummary(
        id: ' ',
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        userId: ' ',
        timestamp: DateTime.now(),
        isReadOnly: false,
      );

  LocalSummary copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? timestamp,
    bool? isSynced,
    String? userId,
    List<String>? tags,
    bool? isReadOnly,
  }) {
    return LocalSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
      tags: tags ?? this.tags,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }

  LocalSummary.empty() {
    id = '';
    title = '';
    content = '';
    timestamp = DateTime.now();
    isSynced = false;
    userId = '';
    tags = [];
    isReadOnly = false;
  }
}
