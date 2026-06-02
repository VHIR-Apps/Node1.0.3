// lib/models/leaderboard_profile_model.dart

import 'package:hive/hive.dart';

class LeaderboardProfileModel extends HiveObject {
  final String uid;
  String displayName;
  String? tagline;
  String? countryCode;

  final DateTime createdAt;
  DateTime updatedAt;

  bool isOptedIn;
  bool showLevel;
  bool showBadges;
  bool showStudyHours;

  String avatarEmoji;
  int avatarIndex;
  String? bio;

  int joinedAtMs;
  bool isInterviewUser;
  int profileThemeIndex;

  DateTime? lastCloudSyncAt;
  int cachedRank;
  double cachedScore;

  int dailyScore;
  int weeklyScore;
  int lastDailyResetMs;
  int lastWeeklyResetMs;

  // 🚀 NEW SOCIAL FIELDS
  List<Map<String, dynamic>> posts;
  List<String> blockedUsers;
  bool isProUser;
  int lastActiveMs;
  List<String> unlockedBadges;

  LeaderboardProfileModel({
    required this.uid,
    required this.displayName,
    this.tagline,
    this.countryCode,
    required this.createdAt,
    required this.updatedAt,
    required this.isOptedIn,
    required this.showLevel,
    required this.showBadges,
    required this.showStudyHours,
    required this.avatarEmoji,
    required this.avatarIndex,
    this.bio,
    required this.joinedAtMs,
    required this.isInterviewUser,
    required this.profileThemeIndex,
    this.lastCloudSyncAt,
    required this.cachedRank,
    required this.cachedScore,
    required this.dailyScore,
    required this.weeklyScore,
    required this.lastDailyResetMs,
    required this.lastWeeklyResetMs,
    required this.posts,
    required this.blockedUsers,
    required this.isProUser,
    required this.lastActiveMs,
    required this.unlockedBadges,
  });

  factory LeaderboardProfileModel.create({
    required String uid,
    required String displayName,
    String? tagline,
    String? countryCode,
    bool isOptedIn = true,
    bool showLevel = true,
    bool showBadges = true,
    bool showStudyHours = true,
    String avatarEmoji = '🙂',
    int avatarIndex = 0,
    String? bio,
    int? joinedAtMs,
    bool isInterviewUser = false,
    int profileThemeIndex = 0,
  }) {
    final now = DateTime.now();
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final joinMs = joinedAtMs ?? nowMs;

    return LeaderboardProfileModel(
      uid: uid,
      displayName: safeDisplayName(displayName),
      tagline: safeOptionalShortText(tagline, maxLen: 64),
      countryCode: (countryCode?.trim().isEmpty ?? true) ? null : countryCode!.trim().toUpperCase(),
      createdAt: now,
      updatedAt: now,
      isOptedIn: isOptedIn,
      showLevel: showLevel,
      showBadges: showBadges,
      showStudyHours: showStudyHours,
      avatarEmoji: safeEmoji(avatarEmoji),
      avatarIndex: avatarIndex < 0 ? 0 : avatarIndex,
      bio: safeOptionalShortText(bio, maxLen: 220),
      joinedAtMs: joinMs,
      isInterviewUser: isInterviewUser,
      profileThemeIndex: profileThemeIndex < 0 ? 0 : profileThemeIndex,
      lastCloudSyncAt: null,
      cachedRank: -1,
      cachedScore: 0,
      dailyScore: 0,
      weeklyScore: 0,
      lastDailyResetMs: nowMs,
      lastWeeklyResetMs: nowMs,
      posts: [],
      blockedUsers: [],
      isProUser: false,
      lastActiveMs: nowMs,
      unlockedBadges: [],
    );
  }

  void touchUpdated() {
    updatedAt = DateTime.now();
    lastActiveMs = DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  // 🚀 THE MISSING copyWith METHOD RESTORED
  LeaderboardProfileModel copyWith({
    String? displayName,
    String? tagline,
    String? countryCode,
    bool? isOptedIn,
    bool? showLevel,
    bool? showBadges,
    bool? showStudyHours,
    String? avatarEmoji,
    int? avatarIndex,
    String? bio,
    int? joinedAtMs,
    bool? isInterviewUser,
    int? profileThemeIndex,
    DateTime? lastCloudSyncAt,
    int? cachedRank,
    double? cachedScore,
    int? dailyScore,
    int? weeklyScore,
    int? lastDailyResetMs,
    int? lastWeeklyResetMs,
    List<Map<String, dynamic>>? posts,
    List<String>? blockedUsers,
    bool? isProUser,
    int? lastActiveMs,
    List<String>? unlockedBadges,
  }) {
    return LeaderboardProfileModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      tagline: tagline == null ? this.tagline : safeOptionalShortText(tagline, maxLen: 64),
      countryCode: countryCode ?? this.countryCode,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isOptedIn: isOptedIn ?? this.isOptedIn,
      showLevel: showLevel ?? this.showLevel,
      showBadges: showBadges ?? this.showBadges,
      showStudyHours: showStudyHours ?? this.showStudyHours,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      bio: bio == null ? this.bio : safeOptionalShortText(bio, maxLen: 220),
      joinedAtMs: joinedAtMs ?? this.joinedAtMs,
      isInterviewUser: isInterviewUser ?? this.isInterviewUser,
      profileThemeIndex: profileThemeIndex ?? this.profileThemeIndex,
      lastCloudSyncAt: lastCloudSyncAt ?? this.lastCloudSyncAt,
      cachedRank: cachedRank ?? this.cachedRank,
      cachedScore: cachedScore ?? this.cachedScore,
      dailyScore: dailyScore ?? this.dailyScore,
      weeklyScore: weeklyScore ?? this.weeklyScore,
      lastDailyResetMs: lastDailyResetMs ?? this.lastDailyResetMs,
      lastWeeklyResetMs: lastWeeklyResetMs ?? this.lastWeeklyResetMs,
      posts: posts ?? this.posts,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isProUser: isProUser ?? this.isProUser,
      lastActiveMs: lastActiveMs ?? this.lastActiveMs,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
    );
  }

  Map<String, dynamic> toCloudMap({
    required int level,
    required int badgesUnlocked,
    required double studyHours,
    required double score,
  }) {
    final nowUtc = DateTime.now().toUtc();
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'tagline': tagline,
      'bio': bio,
      'countryCode': countryCode,
      'avatarEmoji': avatarEmoji,
      'avatarIndex': avatarIndex,
      'joinedAtMs': joinedAtMs,
      'isInterviewUser': isInterviewUser,
      'profileThemeIndex': profileThemeIndex,
      'prefs': <String, dynamic>{
        'showLevel': showLevel,
        'showBadges': showBadges,
        'showStudyHours': showStudyHours,
      },
      'metrics': <String, dynamic>{
        'level': level,
        'badgesUnlocked': badgesUnlocked,
        'studyHours': studyHours,
        'score': score,
      },
      'dailyScore': dailyScore,
      'weeklyScore': weeklyScore,
      'lastDailyResetMs': lastDailyResetMs,
      'lastWeeklyResetMs': lastWeeklyResetMs,
      'posts': posts,
      'blockedUsers': blockedUsers,
      'isProUser': isProUser,
      'lastActiveMs': lastActiveMs,
      'unlockedBadges': unlockedBadges,
      'updatedAt': nowUtc.toIso8601String(),
      'updatedAtMs': nowUtc.millisecondsSinceEpoch,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'createdAtMs': createdAt.toUtc().millisecondsSinceEpoch,
    };
  }

  static String safeDisplayName(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'HabitNode User';
    if (v.length <= 24) return v;
    return v.substring(0, 24);
  }

  static String safeEmoji(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '🙂';
    return v;
  }

  static String? safeOptionalShortText(String? raw, {required int maxLen}) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    if (v.length <= maxLen) return v;
    return v.substring(0, maxLen);
  }
}

class LeaderboardProfileModelAdapter extends TypeAdapter<LeaderboardProfileModel> {
  @override
  final int typeId = 6;

  @override
  LeaderboardProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }

    final createdAt = (fields[4] as DateTime?) ?? DateTime.now();
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    final postsRaw = fields[23] as List?;
    final parsedPosts = postsRaw?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    final blockedRaw = fields[24] as List?;
    final parsedBlocked = blockedRaw?.map((e) => e.toString()).toList() ?? [];

    final badgesRaw = fields[27] as List?;
    final parsedBadges = badgesRaw?.map((e) => e.toString()).toList() ?? [];

    return LeaderboardProfileModel(
      uid: (fields[0] as String?) ?? '',
      displayName: (fields[1] as String?) ?? 'HabitNode User',
      tagline: fields[2] as String?,
      countryCode: fields[3] as String?,
      createdAt: createdAt,
      updatedAt: (fields[5] as DateTime?) ?? DateTime.now(),
      isOptedIn: (fields[6] as bool?) ?? false,
      showLevel: (fields[7] as bool?) ?? true,
      showBadges: (fields[8] as bool?) ?? true,
      showStudyHours: (fields[9] as bool?) ?? true,
      avatarEmoji: (fields[10] as String?) ?? '🙂',
      lastCloudSyncAt: fields[11] as DateTime?,
      cachedRank: (fields[12] as int?) ?? -1,
      cachedScore: (fields[13] as double?) ?? 0.0,
      avatarIndex: (fields[14] as int?) ?? 0,
      bio: fields[15] as String?,
      joinedAtMs: (fields[16] as int?) ?? createdAt.toUtc().millisecondsSinceEpoch,
      isInterviewUser: (fields[17] as bool?) ?? false,
      profileThemeIndex: (fields[18] as int?) ?? 0,
      dailyScore: (fields[19] as int?) ?? 0,
      weeklyScore: (fields[20] as int?) ?? 0,
      lastDailyResetMs: (fields[21] as int?) ?? nowMs,
      lastWeeklyResetMs: (fields[22] as int?) ?? nowMs,
      posts: parsedPosts,
      blockedUsers: parsedBlocked,
      isProUser: (fields[25] as bool?) ?? false,
      lastActiveMs: (fields[26] as int?) ?? nowMs,
      unlockedBadges: parsedBadges,
    );
  }

  @override
  void write(BinaryWriter writer, LeaderboardProfileModel obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)..write(obj.uid)
      ..writeByte(1)..write(obj.displayName)
      ..writeByte(2)..write(obj.tagline)
      ..writeByte(3)..write(obj.countryCode)
      ..writeByte(4)..write(obj.createdAt)
      ..writeByte(5)..write(obj.updatedAt)
      ..writeByte(6)..write(obj.isOptedIn)
      ..writeByte(7)..write(obj.showLevel)
      ..writeByte(8)..write(obj.showBadges)
      ..writeByte(9)..write(obj.showStudyHours)
      ..writeByte(10)..write(obj.avatarEmoji)
      ..writeByte(11)..write(obj.lastCloudSyncAt)
      ..writeByte(12)..write(obj.cachedRank)
      ..writeByte(13)..write(obj.cachedScore)
      ..writeByte(14)..write(obj.avatarIndex)
      ..writeByte(15)..write(obj.bio)
      ..writeByte(16)..write(obj.joinedAtMs)
      ..writeByte(17)..write(obj.isInterviewUser)
      ..writeByte(18)..write(obj.profileThemeIndex)
      ..writeByte(19)..write(obj.dailyScore)
      ..writeByte(20)..write(obj.weeklyScore)
      ..writeByte(21)..write(obj.lastDailyResetMs)
      ..writeByte(22)..write(obj.lastWeeklyResetMs)
      ..writeByte(23)..write(obj.posts)
      ..writeByte(24)..write(obj.blockedUsers)
      ..writeByte(25)..write(obj.isProUser)
      ..writeByte(26)..write(obj.lastActiveMs)
      ..writeByte(27)..write(obj.unlockedBadges);
  }
}