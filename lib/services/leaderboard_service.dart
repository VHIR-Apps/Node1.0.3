// lib/services/leaderboard_service.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/leaderboard_profile_model.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'profile_service.dart';

class LeaderboardServiceException implements Exception {
  final String message;
  final Object? cause;

  const LeaderboardServiceException(this.message, {this.cause});

  @override
  String toString() => 'LeaderboardServiceException: $message';
}

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final int avatarIndex;
  final String? tagline;
  final String? bio;
  final String? countryCode;
  final int joinedAtMs;
  final bool isInterviewUser;
  final int profileThemeIndex;

  final bool showLevel;
  final bool showBadges;
  final bool showStudyHours;

  final int level;
  final int badgesUnlocked;
  final double studyHours;

  final double score;

  final int dailyScore;
  final int weeklyScore;

  final DateTime? updatedAt;

  // 🚀 NEW SOCIAL FIELDS
  final bool isProUser;
  final int lastActiveMs;
  final List<Map<String, dynamic>> posts;
  final List<String> unlockedBadges;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.tagline,
    required this.countryCode,
    required this.showLevel,
    required this.showBadges,
    required this.showStudyHours,
    required this.level,
    required this.badgesUnlocked,
    required this.studyHours,
    required this.score,
    required this.updatedAt,
    this.avatarIndex = 0,
    this.bio,
    this.joinedAtMs = 0,
    this.isInterviewUser = false,
    this.profileThemeIndex = 0,
    this.dailyScore = 0,
    this.weeklyScore = 0,
    this.isProUser = false,
    this.lastActiveMs = 0,
    this.posts = const [],
    this.unlockedBadges = const [],
  });
}

class LeaderboardSnapshot {
  final List<LeaderboardEntry> top;
  final int myRank; // 1-based, -1 if unknown/not ranked
  final double myScore;

  const LeaderboardSnapshot({
    required this.top,
    required this.myRank,
    required this.myScore,
  });
}

enum LeaderboardPeriod { daily, weekly, allTime }

class LeaderboardService {
  LeaderboardService._internal();

  static final LeaderboardService instance = LeaderboardService._internal();

  static const int _schemaVersion = 1;

  static const String _collection = 'leaderboard_v1_users';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double _wLevel = 1000.0;
  static const double _wBadges = 50.0;
  static const double _wStudyHours = 10.0;

  static const double _studyHoursSoftCap = 2000.0;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(_collection);

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _col.doc(uid);

  // ─────────────────────────────────────────────
  // Auth-aware wrapper
  // ─────────────────────────────────────────────

  bool _isAuthRelatedFirestoreError(Object e) {
    if (e is FirebaseAuthException) {
      return e.code == 'invalid-credential' ||
          e.code == 'user-token-expired' ||
          e.code == 'requires-recent-login';
    }

    if (e is FirebaseException) {
      final c = (e.code).toLowerCase();
      if (c == 'permission-denied' || c == 'unauthenticated') return true;
    }

    final msg = e.toString().toLowerCase();
    return msg.contains('missing or insufficient permissions') ||
        msg.contains('permission-denied') ||
        msg.contains('unauthenticated') ||
        msg.contains('invalid or expired') ||
        msg.contains('invalid-credential');
  }

  Future<void> _refreshAuthSessionBestEffort() async {
    try {
      final u = AuthService.instance.currentUser;
      if (u != null) {
        await u.getIdToken(true);
      }
    } catch (e) {
      debugPrint('⚠️ Token refresh failed: $e');
    }

    try {
      await AuthService.instance.ensureSignedInOnDemand(interactive: false);
    } catch (e) {
      debugPrint('⚠️ Silent restore failed: $e');
    }
  }

  Future<T> _runWithAuthRetry<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      if (!_isAuthRelatedFirestoreError(e)) {
        rethrow;
      }

      await _refreshAuthSessionBestEffort();

      try {
        return await op();
      } catch (e2) {
        if (_isAuthRelatedFirestoreError(e2)) {
          throw LeaderboardServiceException(
            'Invalid or expired sign-in session. Please sign in again.',
            cause: e2,
          );
        }
        rethrow;
      }
    }
  }

  // ─────────────────────────────────────────────
  // Score
  // ─────────────────────────────────────────────

  double computeScore({
    required int level,
    required int badgesUnlocked,
    required double studyHours,
  }) {
    final safeLevel = max(0, level);
    final safeBadges = max(0, badgesUnlocked);
    final safeHours = studyHours.isFinite ? max(0.0, studyHours) : 0.0;

    final cappedHours = _softCap(safeHours, _studyHoursSoftCap);
    final score = (safeLevel * _wLevel) +
        (safeBadges * _wBadges) +
        (cappedHours * _wStudyHours);

    return score.isFinite ? max(0.0, score) : 0.0;
  }

  double _softCap(double value, double cap) {
    if (value <= cap) return value;
    final extra = value - cap;
    return cap + sqrt(extra);
  }

  int computeDailyScore({
    required int level,
    required int badgesUnlocked,
    required double studyHours,
  }) {
    final score = computeScore(
      level: level,
      badgesUnlocked: badgesUnlocked,
      studyHours: studyHours,
    );
    return score.toInt();
  }

  int computeWeeklyScore({
    required int level,
    required int badgesUnlocked,
    required double studyHours,
  }) {
    final score = computeScore(
      level: level,
      badgesUnlocked: badgesUnlocked,
      studyHours: studyHours,
    );
    return score.toInt();
  }

  // ─────────────────────────────────────────────
  // Auto-Reset Logic
  // ─────────────────────────────────────────────

  bool _needsDailyReset(int lastResetMs) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    const dayMs = 24 * 60 * 60 * 1000;
    return (now - lastResetMs) > dayMs;
  }

  // ✅ প্রতি রবিবার রাত ১২ টায় রিসেট করার লজিক
  bool _needsWeeklyReset(int lastResetMs) {
    if (lastResetMs <= 0) return true;
    final now = DateTime.now();
    final lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetMs);

    int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
    DateTime lastSunday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysToSubtract));

    return lastReset.isBefore(lastSunday);
  }

  Future<LeaderboardProfileModel> _autoResetScores(
      LeaderboardProfileModel profile,
      ) async {
    var updated = profile;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (_needsDailyReset(profile.lastDailyResetMs)) {
      debugPrint('🔄 Daily score reset triggered');
      updated = updated.copyWith(
        dailyScore: 0,
        lastDailyResetMs: nowMs,
      );
    }

    if (_needsWeeklyReset(profile.lastWeeklyResetMs)) {
      debugPrint('🔄 Weekly score reset triggered');
      updated = updated.copyWith(
        weeklyScore: 0,
        lastWeeklyResetMs: nowMs,
      );
    }

    if (!identical(updated, profile)) {
      try {
        await DatabaseService.saveLeaderboardProfile(updated);
      } catch (e) {
        debugPrint('⚠️ Failed to save auto-reset profile: $e');
      }
    }

    return updated;
  }

  // ─────────────────────────────────────────────
  // Local
  // ─────────────────────────────────────────────

  LeaderboardProfileModel? getLocalMyProfile() {
    final uid = AuthService.instance.uid;
    if (uid == null || uid.isEmpty) return null;
    return DatabaseService.getLeaderboardProfileForUid(uid);
  }

  bool isLeaderboardEnabledForCurrentUser() {
    final uid = AuthService.instance.uid;
    if (uid == null || uid.isEmpty) return false;
    final p = DatabaseService.getLeaderboardProfileForUid(uid);
    return p != null && p.isOptedIn;
  }

  Map<String, dynamic> getCurrentLocalMetrics() {
    final level = ProfileService.getLevel();
    final badges = ProfileService.getBadgesUnlocked();
    final studyMinutes = DatabaseService.getTotalStudyMinutesAllTime();
    final hours = (studyMinutes / 60.0);

    final score = computeScore(
      level: level,
      badgesUnlocked: badges,
      studyHours: hours,
    );

    return <String, dynamic>{
      'level': level,
      'badgesUnlocked': badges,
      'studyMinutes': studyMinutes,
      'studyHours': hours,
      'score': score,
    };
  }

  Future<void> updateDailyScore(int points) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final profile = DatabaseService.getLeaderboardProfileForUid(user.uid);
    if (profile == null || !profile.isOptedIn) return;

    try {
      final resetProfile = await _autoResetScores(profile);
      final newDailyScore = max(0, resetProfile.dailyScore + points);
      final updated = resetProfile.copyWith(dailyScore: newDailyScore);
      await DatabaseService.saveLeaderboardProfile(updated);

      debugPrint('✅ Daily score updated: +$points → $newDailyScore');

      Future.microtask(() async {
        try {
          await syncMyProfileToCloud();
        } catch (e) {
          debugPrint('⚠️ Daily score cloud sync failed: $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ updateDailyScore error: $e');
    }
  }

  Future<void> updateWeeklyScore(int points) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final profile = DatabaseService.getLeaderboardProfileForUid(user.uid);
    if (profile == null || !profile.isOptedIn) return;

    try {
      final resetProfile = await _autoResetScores(profile);
      final newWeeklyScore = max(0, resetProfile.weeklyScore + points);
      final updated = resetProfile.copyWith(weeklyScore: newWeeklyScore);
      await DatabaseService.saveLeaderboardProfile(updated);

      debugPrint('✅ Weekly score updated: +$points → $newWeeklyScore');

      Future.microtask(() async {
        try {
          await syncMyProfileToCloud();
        } catch (e) {
          debugPrint('⚠️ Weekly score cloud sync failed: $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ updateWeeklyScore error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Policy-safe Opt-out / Delete
  // ─────────────────────────────────────────────

  Future<void> hideMyProfileFromLeaderboard() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw const LeaderboardServiceException(
        'Please sign in to manage your leaderboard profile.',
      );
    }

    final uid = user.uid;
    final local = DatabaseService.getLeaderboardProfileForUid(uid);
    if (local == null) {
      throw const LeaderboardServiceException(
        'Leaderboard profile not found on this device.',
      );
    }

    final now = DateTime.now();
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final joinedAtMs = (local.joinedAtMs > 0)
        ? local.joinedAtMs
        : local.createdAt.toUtc().millisecondsSinceEpoch;

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'uid': uid,
      'isOptedIn': false,

      'displayName': LeaderboardProfileModel.safeDisplayName(local.displayName),
      'avatarEmoji': LeaderboardProfileModel.safeEmoji(local.avatarEmoji),
      'avatarIndex': max(0, local.avatarIndex),

      'tagline': null,
      'bio': null,
      'countryCode': null,

      'joinedAtMs': joinedAtMs,

      'isInterviewUser': false,
      'profileThemeIndex': max(0, local.profileThemeIndex),

      'showLevel': false,
      'showBadges': false,
      'showStudyHours': false,

      'level': 0,
      'badgesUnlocked': 0,
      'studyHours': 0.0,
      'score': 0.0,

      'dailyScore': 0,
      'weeklyScore': 0,
      'lastDailyResetMs': nowMs,
      'lastWeeklyResetMs': nowMs,

      // 🚀 Social fields cleared for privacy
      'posts': [],
      'blockedUsers': [],
      'isProUser': false,
      'lastActiveMs': nowMs,
      'unlockedBadges': [],

      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': nowMs,
      'createdAtMs': local.createdAt.millisecondsSinceEpoch,
      'createdAtIso': local.createdAt.toUtc().toIso8601String(),
    };

    try {
      await _runWithAuthRetry(
            () => _doc(uid).set(payload, SetOptions(merge: true)),
      );

      local.isOptedIn = false;
      local.showLevel = false;
      local.showBadges = false;
      local.showStudyHours = false;

      local.cachedRank = -1;
      local.cachedScore = 0.0;

      local.dailyScore = 0;
      local.weeklyScore = 0;
      local.lastDailyResetMs = nowMs;
      local.lastWeeklyResetMs = nowMs;

      if (local.joinedAtMs <= 0) {
        local.joinedAtMs = joinedAtMs;
      }

      local.lastCloudSyncAt = DateTime.now();
      local.touchUpdated();

      await DatabaseService.saveLeaderboardProfile(local);
    } catch (e) {
      if (e is LeaderboardServiceException) rethrow;
      throw LeaderboardServiceException(
        'Failed to turn off leaderboard.',
        cause: e,
      );
    }
  }

  Future<void> deleteMyLeaderboardProfileFromCloud({
    bool alsoClearLocalProfile = false,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw const LeaderboardServiceException(
        'Please sign in to manage your leaderboard profile.',
      );
    }

    final uid = user.uid;

    try {
      await _runWithAuthRetry(() => _doc(uid).delete());

      if (alsoClearLocalProfile) {
        await DatabaseService.clearLeaderboardProfileForUid(uid);
      } else {
        final local = DatabaseService.getLeaderboardProfileForUid(uid);
        if (local != null) {
          final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

          local.isOptedIn = false;
          local.cachedRank = -1;
          local.cachedScore = 0.0;

          local.dailyScore = 0;
          local.weeklyScore = 0;
          local.lastDailyResetMs = nowMs;
          local.lastWeeklyResetMs = nowMs;

          local.lastCloudSyncAt = DateTime.now();
          local.touchUpdated();
          await DatabaseService.saveLeaderboardProfile(local);
        }
      }
    } catch (e) {
      if (e is LeaderboardServiceException) rethrow;
      throw LeaderboardServiceException(
        'Failed to delete cloud leaderboard profile.',
        cause: e,
      );
    }
  }

  // ─────────────────────────────────────────────
  // Sync (Create/Update)
  // ─────────────────────────────────────────────

  Future<void> syncMyProfileToCloud() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw const LeaderboardServiceException(
        'Please sign in to use the leaderboard.',
      );
    }

    final uid = user.uid;
    final profile = DatabaseService.getLeaderboardProfileForUid(uid);
    if (profile == null) {
      throw const LeaderboardServiceException(
        'Please create your leaderboard profile first.',
      );
    }

    if (!profile.isOptedIn) {
      await hideMyProfileFromLeaderboard();
      return;
    }

    final resetProfile = await _autoResetScores(profile);

    final metrics = getCurrentLocalMetrics();
    final level = (metrics['level'] as int?) ?? 0;
    final badgesUnlocked = (metrics['badgesUnlocked'] as int?) ?? 0;
    final studyHours = (metrics['studyHours'] as double?) ?? 0.0;
    final score = (metrics['score'] as double?) ?? 0.0;

    final now = DateTime.now();
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final joinedAtMs = (resetProfile.joinedAtMs > 0)
        ? resetProfile.joinedAtMs
        : resetProfile.createdAt.toUtc().millisecondsSinceEpoch;

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'uid': uid,

      'displayName':
      LeaderboardProfileModel.safeDisplayName(resetProfile.displayName),
      'avatarEmoji':
      LeaderboardProfileModel.safeEmoji(resetProfile.avatarEmoji),
      'avatarIndex': max(0, resetProfile.avatarIndex),
      'tagline': (resetProfile.tagline?.trim().isEmpty ?? true)
          ? null
          : resetProfile.tagline?.trim(),
      'bio': (resetProfile.bio?.trim().isEmpty ?? true)
          ? null
          : resetProfile.bio?.trim(),
      'countryCode': (resetProfile.countryCode?.trim().isEmpty ?? true)
          ? null
          : resetProfile.countryCode?.trim().toUpperCase(),

      'joinedAtMs': joinedAtMs,
      'isInterviewUser': resetProfile.isInterviewUser,
      'profileThemeIndex': max(0, resetProfile.profileThemeIndex),

      'isOptedIn': true,

      'showLevel': resetProfile.showLevel,
      'showBadges': resetProfile.showBadges,
      'showStudyHours': resetProfile.showStudyHours,

      'level': max(0, level),
      'badgesUnlocked': max(0, badgesUnlocked),
      'studyHours': double.parse(studyHours.toStringAsFixed(2)),
      'score': double.parse(score.toStringAsFixed(2)),

      'dailyScore': max(0, resetProfile.dailyScore),
      'weeklyScore': max(0, resetProfile.weeklyScore),
      'lastDailyResetMs': resetProfile.lastDailyResetMs,
      'lastWeeklyResetMs': resetProfile.lastWeeklyResetMs,

      // 🚀 Syncing Social Fields
      'posts': resetProfile.posts,
      'blockedUsers': resetProfile.blockedUsers,
      'isProUser': resetProfile.isProUser,
      'lastActiveMs': resetProfile.lastActiveMs,
      'unlockedBadges': resetProfile.unlockedBadges,

      'createdAtMs': resetProfile.createdAt.millisecondsSinceEpoch,
      'createdAtIso': resetProfile.createdAt.toUtc().toIso8601String(),

      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': nowMs,
    };

    try {
      await _runWithAuthRetry(
            () => _doc(uid).set(payload, SetOptions(merge: true)),
      );

      resetProfile.cachedScore = score;
      resetProfile.lastCloudSyncAt = DateTime.now();
      if (resetProfile.joinedAtMs <= 0) {
        resetProfile.joinedAtMs = joinedAtMs;
      }
      resetProfile.touchUpdated();
      await DatabaseService.saveLeaderboardProfile(resetProfile);
    } catch (e) {
      if (e is LeaderboardServiceException) rethrow;
      throw LeaderboardServiceException(
        'Failed to sync leaderboard profile.',
        cause: e,
      );
    }
  }

  // ─────────────────────────────────────────────
  // Fetch leaderboard by period
  // ─────────────────────────────────────────────

  Future<List<LeaderboardEntry>> fetchTopByPeriod({
    required LeaderboardPeriod period,
    int limit = 50,
  }) async {
    final safeLimit = limit.clamp(5, 200);

    String orderByField;
    switch (period) {
      case LeaderboardPeriod.daily:
        orderByField = 'dailyScore';
        break;
      case LeaderboardPeriod.weekly:
        orderByField = 'weeklyScore';
        break;
      case LeaderboardPeriod.allTime:
        orderByField = 'score';
        break;
    }

    try {
      final snap = await _runWithAuthRetry(
            () => _col
            .where('isOptedIn', isEqualTo: true)
            .orderBy(orderByField, descending: true)
            .orderBy('updatedAtMs', descending: true)
            .limit(safeLimit)
            .get(),
      );

      return snap.docs
          .map((d) => _entryFromDoc(d))
          .whereType<LeaderboardEntry>()
          .toList();
    } catch (e) {
      if (e is LeaderboardServiceException) rethrow;
      throw LeaderboardServiceException(
        'Failed to load leaderboard.',
        cause: e,
      );
    }
  }

  Future<List<LeaderboardEntry>> fetchTop({int limit = 50}) async {
    return fetchTopByPeriod(period: LeaderboardPeriod.allTime, limit: limit);
  }

  Future<List<LeaderboardEntry>> fetchDailyLeaderboard({int limit = 50}) async {
    return fetchTopByPeriod(period: LeaderboardPeriod.daily, limit: limit);
  }

  Future<List<LeaderboardEntry>> fetchWeeklyLeaderboard({
    int limit = 50,
  }) async {
    return fetchTopByPeriod(period: LeaderboardPeriod.weekly, limit: limit);
  }

  // ─────────────────────────────────────────────
  // Fetch rank by period
  // ─────────────────────────────────────────────

  Future<int> fetchMyRankByPeriod({
    required String uid,
    required LeaderboardPeriod period,
    required double myScore,
    int fallbackScanLimit = 500,
  }) async {
    final score = myScore.isFinite ? myScore : 0.0;
    if (score <= 0) return -1;

    String orderByField;
    switch (period) {
      case LeaderboardPeriod.daily:
        orderByField = 'dailyScore';
        break;
      case LeaderboardPeriod.weekly:
        orderByField = 'weeklyScore';
        break;
      case LeaderboardPeriod.allTime:
        orderByField = 'score';
        break;
    }

    try {
      final query = _col
          .where('isOptedIn', isEqualTo: true)
          .where(orderByField, isGreaterThan: score);

      final agg = await _runWithAuthRetry(() => query.count().get());

      final dynamic c = (agg as dynamic).count;
      final int higher = (c is int) ? c : ((c as int?) ?? 0);

      return higher + 1;
    } catch (e) {
      debugPrint('⚠️ Rank count query failed, fallback to scan: $e');
    }

    try {
      final snap = await _runWithAuthRetry(
            () => _col
            .where('isOptedIn', isEqualTo: true)
            .orderBy(orderByField, descending: true)
            .orderBy('updatedAtMs', descending: true)
            .limit(fallbackScanLimit.clamp(50, 2000))
            .get(),
      );

      final docs = snap.docs;
      for (int i = 0; i < docs.length; i++) {
        if ((docs[i].data()['uid'] as String?) == uid) {
          return i + 1;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Rank scan fallback failed: $e');
    }

    return -1;
  }

  Future<int> fetchMyRankExact({
    required String uid,
    required double myScore,
    int fallbackScanLimit = 500,
  }) async {
    return fetchMyRankByPeriod(
      uid: uid,
      period: LeaderboardPeriod.allTime,
      myScore: myScore,
      fallbackScanLimit: fallbackScanLimit,
    );
  }

  Future<LeaderboardSnapshot> getLeaderboardSnapshot({
    int topLimit = 50,
    bool syncBeforeFetch = true,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw const LeaderboardServiceException(
        'Please sign in to view the leaderboard.',
      );
    }

    final uid = user.uid;
    final profile = DatabaseService.getLeaderboardProfileForUid(uid);
    if (profile == null) {
      throw const LeaderboardServiceException(
        'Please create your leaderboard profile first.',
      );
    }
    if (!profile.isOptedIn) {
      throw const LeaderboardServiceException(
        'Leaderboard is turned off for this profile.',
      );
    }

    try {
      await user.getIdToken(true);
    } catch (_) {}

    final metrics = getCurrentLocalMetrics();
    final myScore = (metrics['score'] as double?) ?? 0.0;

    if (syncBeforeFetch) {
      try {
        await syncMyProfileToCloud();
      } catch (e) {
        debugPrint('⚠️ Leaderboard sync skipped/failed: $e');
      }
    }

    final top = await fetchTop(limit: topLimit);

    final myRank = await fetchMyRankExact(
      uid: uid,
      myScore: myScore,
      fallbackScanLimit: 500,
    );

    try {
      profile.cachedRank = myRank;
      profile.cachedScore = myScore;
      profile.lastCloudSyncAt = DateTime.now();
      profile.touchUpdated();
      await DatabaseService.saveLeaderboardProfile(profile);
    } catch (e) {
      debugPrint('⚠️ Failed to cache leaderboard rank locally: $e');
    }

    return LeaderboardSnapshot(
      top: top,
      myRank: myRank,
      myScore: myScore,
    );
  }

  // ─────────────────────────────────────────────
  // Decode entry
  // ─────────────────────────────────────────────

  LeaderboardEntry? _entryFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    try {
      final data = doc.data();

      final uid = (data['uid'] as String?) ?? doc.id;

      final displayName =
      (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'HabitNode User';

      final avatarEmoji =
      (data['avatarEmoji'] as String?)?.trim().isNotEmpty == true
          ? (data['avatarEmoji'] as String).trim()
          : '🙂';

      final avatarIndex = (data['avatarIndex'] as num?)?.toInt() ?? 0;

      final tagline = (data['tagline'] as String?)?.trim();
      final bio = (data['bio'] as String?)?.trim();

      final countryCode = (data['countryCode'] as String?)?.trim();

      final joinedAtMs = (data['joinedAtMs'] as num?)?.toInt() ?? 0;
      final isInterviewUser = (data['isInterviewUser'] as bool?) ?? false;
      final profileThemeIndex = (data['profileThemeIndex'] as num?)?.toInt() ?? 0;

      final showLevel = (data['showLevel'] as bool?) ?? true;
      final showBadges = (data['showBadges'] as bool?) ?? true;
      final showStudyHours = (data['showStudyHours'] as bool?) ?? true;

      final level = (data['level'] as num?)?.toInt() ?? 0;
      final badgesUnlocked = (data['badgesUnlocked'] as num?)?.toInt() ?? 0;
      final studyHours = (data['studyHours'] as num?)?.toDouble() ?? 0.0;
      final score = (data['score'] as num?)?.toDouble() ?? 0.0;

      final dailyScore = (data['dailyScore'] as num?)?.toInt() ?? 0;
      final weeklyScore = (data['weeklyScore'] as num?)?.toInt() ?? 0;

      // 🚀 NEW SOCIAL FIELDS EXTRACTED
      final isProUser = (data['isProUser'] as bool?) ?? false;
      final lastActiveMs = (data['lastActiveMs'] as num?)?.toInt() ?? 0;

      final postsRaw = data['posts'] as List?;
      final postsList = postsRaw?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

      final badgesRaw = data['unlockedBadges'] as List?;
      final badgesList = badgesRaw?.map((e) => e.toString()).toList() ?? [];

      DateTime? updatedAt;
      final ts = data['updatedAt'];
      if (ts is Timestamp) updatedAt = ts.toDate();

      return LeaderboardEntry(
        uid: uid,
        displayName: displayName,
        avatarEmoji: avatarEmoji,
        avatarIndex: max(0, avatarIndex),
        tagline: (tagline == null || tagline.isEmpty) ? null : tagline,
        bio: (bio == null || bio.isEmpty) ? null : bio,
        countryCode: (countryCode == null || countryCode.isEmpty)
            ? null
            : countryCode.toUpperCase(),
        joinedAtMs: joinedAtMs,
        isInterviewUser: isInterviewUser,
        profileThemeIndex: max(0, profileThemeIndex),
        showLevel: showLevel,
        showBadges: showBadges,
        showStudyHours: showStudyHours,
        level: max(0, level),
        badgesUnlocked: max(0, badgesUnlocked),
        studyHours: studyHours.isFinite ? max(0.0, studyHours) : 0.0,
        score: score.isFinite ? max(0.0, score) : 0.0,
        dailyScore: max(0, dailyScore),
        weeklyScore: max(0, weeklyScore),
        updatedAt: updatedAt,
        // 🚀 NEW FIELDS ADDED TO ENTRY
        isProUser: isProUser,
        lastActiveMs: lastActiveMs,
        posts: postsList,
        unlockedBadges: badgesList,
      );
    } catch (e) {
      debugPrint('⚠️ Invalid leaderboard document skipped (${doc.id}): $e');
      return null;
    }
  }
}