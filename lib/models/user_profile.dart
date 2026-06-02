/// Simple User Profile model
/// NO HIVE - NO CODE GENERATION - NO .g.dart FILE NEEDED
class UserProfile {
  String name;
  String avatarEmoji;
  DateTime joinedDate;
  int totalHabitsCompleted;
  int currentStreak;
  int longestStreak;
  String? motto;

  UserProfile({
    required this.name,
    this.avatarEmoji = '😊',
    required this.joinedDate,
    this.totalHabitsCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.motto,
  });

  factory UserProfile.defaultProfile() {
    return UserProfile(
      name: 'Habit Hero',
      avatarEmoji: '🦸',
      joinedDate: DateTime.now(),
      motto: 'Building better habits daily!',
    );
  }

  int get daysSinceJoined {
    return DateTime.now().difference(joinedDate).inDays;
  }

  int get level {
    if (totalHabitsCompleted < 10) return 1;
    if (totalHabitsCompleted < 30) return 2;
    if (totalHabitsCompleted < 60) return 3;
    if (totalHabitsCompleted < 100) return 4;
    if (totalHabitsCompleted < 200) return 5;
    return 6;
  }

  String get levelTitle {
    switch (level) {
      case 1: return 'Beginner';
      case 2: return 'Starter';
      case 3: return 'Achiever';
      case 4: return 'Pro';
      case 5: return 'Master';
      default: return 'Legend';
    }
  }

  int get xpForNextLevel {
    switch (level) {
      case 1: return 10;
      case 2: return 30;
      case 3: return 60;
      case 4: return 100;
      case 5: return 200;
      default: return 500;
    }
  }

  double get levelProgress {
    return (totalHabitsCompleted / xpForNextLevel).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatarEmoji': avatarEmoji,
      'joinedDate': joinedDate.toIso8601String(),
      'totalHabitsCompleted': totalHabitsCompleted,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'motto': motto,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? 'Habit Hero',
      avatarEmoji: json['avatarEmoji'] ?? '🦸',
      joinedDate: json['joinedDate'] != null
          ? DateTime.parse(json['joinedDate'])
          : DateTime.now(),
      totalHabitsCompleted: json['totalHabitsCompleted'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      motto: json['motto'],
    );
  }
}