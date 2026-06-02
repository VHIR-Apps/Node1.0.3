// lib/models/notification_model.dart

import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 1)
class AppNotification extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String body;

  @HiveField(3)
  DateTime receivedAt;

  @HiveField(4)
  bool isRead;

  @HiveField(5)
  String type;

  @HiveField(6)
  String? payload;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.isRead = false,
    this.type = 'local',
    this.payload,
  });

  void markAsRead() {
    isRead = true;
    save();
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(receivedAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${receivedAt.day}/${receivedAt.month}/${receivedAt.year}';
  }

  String get emoji {
    switch (type) {
      case 'push':
        return '📢';
      case 'alarm':
        return '⏰';
      case 'reminder':
        return '🔔';
      default:
        return '💬';
    }
  }
}