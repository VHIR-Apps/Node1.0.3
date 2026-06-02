// lib/models/note_model.dart

import 'package:hive_flutter/hive_flutter.dart';

part 'note_model.g.dart';

// 🆕 typeId: 5 (Next available)
@HiveType(typeId: 5)
class Note extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String content;

  @HiveField(3)
  late DateTime createdAt;

  @HiveField(4)
  late DateTime updatedAt;

  @HiveField(5)
  late String color; // HEX color

  @HiveField(6)
  late int priority; // 0=Normal, 1=Important, 2=Urgent

  @HiveField(7)
  late bool isPinned;

  @HiveField(8)
  late List<String> tags;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.color = '#FFB300',
    this.priority = 0,
    this.isPinned = false,
    this.tags = const [],
  });

  // Helper methods
  String get wordCount {
    return content.split(' ').where((word) => word.isNotEmpty).length.toString();
  }

  String get charCount {
    return content.length.toString();
  }

  String get preview {
    return content.length > 100 ? content.substring(0, 100) + '...' : content;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'color': color,
      'priority': priority,
      'isPinned': isPinned,
      'tags': tags,
    };
  }

  static Note fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : json['createdAt'] ?? DateTime.now(),
      updatedAt: json['updatedAt'] is String
          ? DateTime.parse(json['updatedAt'])
          : json['updatedAt'] ?? DateTime.now(),
      color: json['color'] ?? '#FFB300',
      priority: json['priority'] ?? 0,
      isPinned: json['isPinned'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}