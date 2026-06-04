// lib/services/database_service.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../models/daily_study_routine_model.dart';
import '../models/habit_model.dart';
import '../models/leaderboard_profile_model.dart';
import '../models/notification_model.dart';
import '../models/study_routine_model.dart';
import '../models/study_session_model.dart';
import '../models/study_target_model.dart';
import 'auto_backup_trigger.dart';
import 'leaderboard_service.dart';
import 'notes_service.dart';

class DatabaseService {
  static const String habitsBox = 'habits';
  static const String settingsBox = 'settings';
  static const String notificationsBox = 'notifications';
  static const String studySessionsBox = 'study_sessions';
  static const String routinesBox = 'study_routines';

  static const String studyTargetsBox = 'study_targets';
  static const String dailyStudyRoutinesBox = 'daily_study_routines';

  static const String _kDefaultStudyTargetId = 'default_study_target';

  static const String leaderboardProfileBox = 'leaderboard_profile';
  static const String _kLeaderboardLastUid = 'leaderboard_last_uid';

  static late Box<Habit> _habitsBox;
  static late Box _settingsBox;
  static late Box<AppNotification> _notificationsBox;
  static late Box<StudySession> _studySessionsBox;
  static late Box<StudyRoutine> _routinesBox;

  static Box<LeaderboardProfileModel>? _leaderboardProfileBox;
  static Box<StudyTarget>? _studyTargetsBox;
  static Box<DailyStudyRoutine>? _dailyStudyRoutinesBox;

  static bool _leaderboardOpenAttemptInProgress = false;
  static bool _studyTargetsOpenAttemptInProgress = false;
  static bool _dailyRoutinesOpenAttemptInProgress = false;

  static Future<void> init() async {
    _habitsBox = await Hive.openBox<Habit>(habitsBox);
    _settingsBox = await Hive.openBox(settingsBox);
    _notificationsBox = await Hive.openBox<AppNotification>(notificationsBox);
    _studySessionsBox = await Hive.openBox<StudySession>(studySessionsBox);
    _routinesBox = await Hive.openBox<StudyRoutine>(routinesBox);

    await _openLeaderboardBoxSafely();
    await _openStudyTargetsBoxSafely();
    await _openDailyStudyRoutinesBoxSafely();

    // 🗑️ Legacy VIP cleanup (one time)
    await _cleanupLegacyVipKeys();

    if (!_settingsBox.containsKey('ad_sound_muted')) {
      await _settingsBox.put('ad_sound_muted', !AppConfig.adSoundEnabled);
    }
    if (!_settingsBox.containsKey('dynamic_translation_enabled')) {
      await _settingsBox.put('dynamic_translation_enabled', false);
    }
    if (!_settingsBox.containsKey('sound_effects_enabled')) {
      await _settingsBox.put('sound_effects_enabled', true);
    }
    if (!_settingsBox.containsKey('tts_enabled')) {
      await _settingsBox.put('tts_enabled', true);
    }
    if (!_settingsBox.containsKey('last_known_level')) {
      await _settingsBox.put('last_known_level', 1);
    }
    if (!_settingsBox.containsKey('custom_categories')) {
      await _settingsBox.put('custom_categories', <String>[]);
    }
    if (!_settingsBox.containsKey('last_missed_dialog_date')) {
      await _settingsBox.put('last_missed_dialog_date', '');
    }
    if (!_settingsBox.containsKey('auto_reset_hour')) {
      await _settingsBox.put('auto_reset_hour', 0);
    }
    if (!_settingsBox.containsKey('auto_reset_minute')) {
      await _settingsBox.put('auto_reset_minute', 0);
    }
    if (!_settingsBox.containsKey('last_seen_notification_time')) {
      await _settingsBox.put('last_seen_notification_time', 0);
    }
    if (!_settingsBox.containsKey('last_config_fetch_time')) {
      await _settingsBox.put('last_config_fetch_time', 0);
    }
    if (!_settingsBox.containsKey('pomodoro_focus_mins')) {
      await _settingsBox.put(
        'pomodoro_focus_mins',
        AppConfig.defaultFocusMinutes,
      );
    }
    if (!_settingsBox.containsKey('pomodoro_short_break_mins')) {
      await _settingsBox.put(
        'pomodoro_short_break_mins',
        AppConfig.defaultShortBreakMinutes,
      );
    }
    if (!_settingsBox.containsKey('pomodoro_long_break_mins')) {
      await _settingsBox.put(
        'pomodoro_long_break_mins',
        AppConfig.defaultLongBreakMinutes,
      );
    }
    if (!_settingsBox.containsKey('custom_study_subjects')) {
      await _settingsBox.put('custom_study_subjects', <String>[]);
    }
    if (!_settingsBox.containsKey('auto_play_enabled')) {
      await _settingsBox.put('auto_play_enabled', false);
    }
    if (!_settingsBox.containsKey('pomodoro_tts_enabled')) {
      await _settingsBox.put('pomodoro_tts_enabled', true);
    }
    if (!_settingsBox.containsKey('keep_screen_on')) {
      await _settingsBox.put('keep_screen_on', true);
    }
    if (!_settingsBox.containsKey('vibrate_on_complete')) {
      await _settingsBox.put('vibrate_on_complete', true);
    }
    if (!_settingsBox.containsKey(_kLeaderboardLastUid)) {
      await _settingsBox.put(_kLeaderboardLastUid, '');
    }

    // ═══════════════════════════════════════════════════════════
    // 🚀 AUTO BACKUP SETTINGS - DEFAULTS
    // ═══════════════════════════════════════════════════════════

    if (!_settingsBox.containsKey('auto_backup_enabled')) {
      await _settingsBox.put('auto_backup_enabled', true);
    }
    if (!_settingsBox.containsKey('auto_backup_frequency')) {
      await _settingsBox.put('auto_backup_frequency', 'every_change');
    }
    // ✅ Default: WiFi + Mobile Data দুটোই
    if (!_settingsBox.containsKey('auto_backup_wifi_only')) {
      await _settingsBox.put('auto_backup_wifi_only', false);
    }
    if (!_settingsBox.containsKey('last_auto_backup_time')) {
      await _settingsBox.put('last_auto_backup_time', 0);
    }
    if (!_settingsBox.containsKey('has_pending_backup')) {
      await _settingsBox.put('has_pending_backup', false);
    }

    if (!_settingsBox.containsKey('psychology_nudges_enabled')) {
      await _settingsBox.put('psychology_nudges_enabled', true);
    }
  }

  // ─────────────────────────────────────────────
  // 🗑️ LEGACY VIP CLEANUP
  // ─────────────────────────────────────────────

  static Future<void> _cleanupLegacyVipKeys() async {
    const legacyKeys = [
      'is_vip',
      'vip_email',
      'vip_expiry',
      'vip_device_id',
    ];

    for (final key in legacyKeys) {
      if (_settingsBox.containsKey(key)) {
        try {
          await _settingsBox.delete(key);
          debugPrint('🗑️ Removed legacy VIP key: $key');
        } catch (_) {}
      }
    }
  }

  // ─────────────────────────────────────────────
  // SAFE OPEN: Leaderboard
  // ─────────────────────────────────────────────

  static Future<void> _openLeaderboardBoxSafely() async {
    try {
      _leaderboardProfileBox =
      await Hive.openBox<LeaderboardProfileModel>(leaderboardProfileBox);
    } catch (e) {
      _leaderboardProfileBox = null;
      debugPrint('⚠️ Leaderboard box open failed: $e');
    }
  }

  static Future<Box<LeaderboardProfileModel>?> _ensureLeaderboardBox() async {
    final box = _leaderboardProfileBox;
    if (box != null && box.isOpen) return box;
    if (_leaderboardOpenAttemptInProgress) return _leaderboardProfileBox;

    _leaderboardOpenAttemptInProgress = true;
    try {
      await _openLeaderboardBoxSafely();
      return _leaderboardProfileBox;
    } finally {
      _leaderboardOpenAttemptInProgress = false;
    }
  }

  static bool get isLeaderboardAvailable =>
      _leaderboardProfileBox != null && _leaderboardProfileBox!.isOpen;

  // ─────────────────────────────────────────────
  // SAFE OPEN: Study Targets
  // ─────────────────────────────────────────────

  static Future<void> _openStudyTargetsBoxSafely() async {
    try {
      _studyTargetsBox = await Hive.openBox<StudyTarget>(studyTargetsBox);
    } catch (e) {
      _studyTargetsBox = null;
      debugPrint('⚠️ StudyTargets box open failed: $e');
    }
  }

  static Future<Box<StudyTarget>?> _ensureStudyTargetsBox() async {
    final box = _studyTargetsBox;
    if (box != null && box.isOpen) return box;
    if (_studyTargetsOpenAttemptInProgress) return _studyTargetsBox;

    _studyTargetsOpenAttemptInProgress = true;
    try {
      await _openStudyTargetsBoxSafely();
      return _studyTargetsBox;
    } finally {
      _studyTargetsOpenAttemptInProgress = false;
    }
  }

  static bool get isStudyTargetsAvailable =>
      _studyTargetsBox != null && _studyTargetsBox!.isOpen;

  // ─────────────────────────────────────────────
  // SAFE OPEN: Daily Study Routines
  // ─────────────────────────────────────────────

  static Future<void> _openDailyStudyRoutinesBoxSafely() async {
    try {
      _dailyStudyRoutinesBox =
      await Hive.openBox<DailyStudyRoutine>(dailyStudyRoutinesBox);
    } catch (e) {
      _dailyStudyRoutinesBox = null;
      debugPrint('⚠️ DailyStudyRoutines box open failed: $e');
    }
  }

  static Future<Box<DailyStudyRoutine>?> _ensureDailyStudyRoutinesBox() async {
    final box = _dailyStudyRoutinesBox;
    if (box != null && box.isOpen) return box;
    if (_dailyRoutinesOpenAttemptInProgress) return _dailyStudyRoutinesBox;

    _dailyRoutinesOpenAttemptInProgress = true;
    try {
      await _openDailyStudyRoutinesBoxSafely();
      return _dailyStudyRoutinesBox;
    } finally {
      _dailyRoutinesOpenAttemptInProgress = false;
    }
  }

  static bool get isDailyStudyRoutinesAvailable =>
      _dailyStudyRoutinesBox != null && _dailyStudyRoutinesBox!.isOpen;

  // ═══════════════════════════════════════
  // 🏆 LEADERBOARD PROFILE
  // ═══════════════════════════════════════

  static String getLeaderboardLastUid() {
    return _settingsBox.get(_kLeaderboardLastUid, defaultValue: '') as String;
  }

  static Future<void> setLeaderboardLastUid(String uid) async {
    await _settingsBox.put(_kLeaderboardLastUid, uid);
  }

  static LeaderboardProfileModel _normalizeLeaderboardProfile(
      LeaderboardProfileModel p) {
    final safeName = LeaderboardProfileModel.safeDisplayName(p.displayName);
    final safeEmoji = (p.avatarEmoji.trim().isEmpty)
        ? '🙂'
        : LeaderboardProfileModel.safeEmoji(p.avatarEmoji);

    final joinedAtMs = (p.joinedAtMs > 0)
        ? p.joinedAtMs
        : p.createdAt.toUtc().millisecondsSinceEpoch;

    final fixedAvatarIndex = p.avatarIndex < 0 ? 0 : p.avatarIndex;
    final fixedThemeIndex = p.profileThemeIndex < 0 ? 0 : p.profileThemeIndex;

    final needsFix = safeName != p.displayName ||
        safeEmoji != p.avatarEmoji ||
        joinedAtMs != p.joinedAtMs ||
        fixedAvatarIndex != p.avatarIndex ||
        fixedThemeIndex != p.profileThemeIndex;

    if (!needsFix) return p;

    return LeaderboardProfileModel(
      uid: p.uid,
      displayName: safeName,
      tagline: p.tagline,
      bio: p.bio,
      countryCode: p.countryCode,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      isOptedIn: p.isOptedIn,
      showLevel: p.showLevel,
      showBadges: p.showBadges,
      showStudyHours: p.showStudyHours,
      avatarEmoji: safeEmoji,
      avatarIndex: fixedAvatarIndex,
      joinedAtMs: joinedAtMs,
      isInterviewUser: p.isInterviewUser,
      profileThemeIndex: fixedThemeIndex,
      lastCloudSyncAt: p.lastCloudSyncAt,
      cachedRank: p.cachedRank,
      cachedScore: p.cachedScore,
      dailyScore: p.dailyScore,
      weeklyScore: p.weeklyScore,
      lastDailyResetMs: p.lastDailyResetMs,
      lastWeeklyResetMs: p.lastWeeklyResetMs,
      posts: p.posts,
      blockedUsers: p.blockedUsers,
      isProUser: p.isProUser,
      lastActiveMs: p.lastActiveMs,
      unlockedBadges: p.unlockedBadges,
    );
  }

  static LeaderboardProfileModel? getLeaderboardProfileForUid(String uid) {
    try {
      final box = _leaderboardProfileBox;
      if (box == null || !box.isOpen) return null;

      final p = box.get(uid);
      if (p == null) return null;

      final normalized = _normalizeLeaderboardProfile(p);

      if (!identical(normalized, p)) {
        Future.microtask(() async {
          try {
            await saveLeaderboardProfile(normalized);
          } catch (_) {}
        });
      }

      return normalized;
    } catch (e) {
      debugPrint('⚠️ getLeaderboardProfileForUid error: $e');
      return null;
    }
  }

  static bool hasLeaderboardProfileForUid(String uid) {
    try {
      final box = _leaderboardProfileBox;
      if (box == null || !box.isOpen) return false;
      return box.containsKey(uid);
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveLeaderboardProfile(
      LeaderboardProfileModel profile) async {
    try {
      if (profile.uid.trim().isEmpty) return;

      final box = await _ensureLeaderboardBox();
      if (box == null || !box.isOpen) return;

      final normalized = _normalizeLeaderboardProfile(profile);

      await box.put(normalized.uid, normalized);
      await setLeaderboardLastUid(normalized.uid);

      AutoBackupTrigger.notifyChange('profile_updated');
    } catch (e) {
      debugPrint('⚠️ saveLeaderboardProfile error: $e');
    }
  }

  static Future<void> clearLeaderboardProfileForUid(String uid) async {
    try {
      final box = await _ensureLeaderboardBox();
      if (box == null || !box.isOpen) return;

      await box.delete(uid);

      final last = getLeaderboardLastUid();
      if (last == uid) {
        await setLeaderboardLastUid('');
      }
    } catch (e) {
      debugPrint('⚠️ clearLeaderboardProfileForUid error: $e');
    }
  }

  static int getCachedLeaderboardRank(String uid) {
    final profile = getLeaderboardProfileForUid(uid);
    return profile?.cachedRank ?? -1;
  }

  static double getCachedLeaderboardScore(String uid) {
    final profile = getLeaderboardProfileForUid(uid);
    return profile?.cachedScore ?? 0.0;
  }

  static Future<void> updateLeaderboardScoresOnHabitCompletion({
    required int points,
  }) async {
    try {
      if (!LeaderboardService.instance.isLeaderboardEnabledForCurrentUser()) {
        return;
      }
      await LeaderboardService.instance.updateDailyScore(points);
      await LeaderboardService.instance.updateWeeklyScore(points);
      debugPrint('✅ Leaderboard scores updated: +$points');
    } catch (e) {
      debugPrint('⚠️ updateLeaderboardScoresOnHabitCompletion error: $e');
    }
  }

  static Future<void> updateLeaderboardActivityStatus() async {
    final uid = getLeaderboardLastUid();
    if (uid.isEmpty) return;

    final p = getLeaderboardProfileForUid(uid);
    if (p == null) return;

    p.lastActiveMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    p.isProUser = isProUser();

    await saveLeaderboardProfile(p);
  }

  static Future<void> addSocialPost(String text) async {
    final uid = getLeaderboardLastUid();
    if (uid.isEmpty) return;
    final p = getLeaderboardProfileForUid(uid);
    if (p == null) return;

    final post = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text.trim(),
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
    };

    p.posts.insert(0, post);
    if (p.posts.length > 20) p.posts = p.posts.sublist(0, 20);

    await saveLeaderboardProfile(p);

    if (p.isOptedIn) {
      try {
        await LeaderboardService.instance.syncMyProfileToCloud();
      } catch (_) {}
    }

    AutoBackupTrigger.notifyChange('post_added');
  }

  // ═══════════════════════════════════════
  // 🍅 STUDY ROUTINES
  // ═══════════════════════════════════════

  static Future<void> saveRoutine(StudyRoutine routine) async {
    await _routinesBox.put(routine.id, routine);
    AutoBackupTrigger.notifyChange('routine_saved');
  }

  static List<StudyRoutine> getAllRoutines() {
    return _routinesBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static StudyRoutine? getRoutineById(String id) {
    return _routinesBox.get(id);
  }

  static Future<void> updateRoutine(StudyRoutine routine) async {
    await _routinesBox.put(routine.id, routine);
    AutoBackupTrigger.notifyChange('routine_updated');
  }

  static Future<void> deleteRoutine(String id) async {
    await _routinesBox.delete(id);
    AutoBackupTrigger.notifyChange('routine_deleted');
  }

  static Future<void> deleteAllRoutines() async {
    await _routinesBox.clear();
    AutoBackupTrigger.notifyChange('routines_cleared');
  }

  static int getRoutineCount() => _routinesBox.length;

  static int getTotalRoutinesCompleted() {
    int total = 0;
    for (var routine in _routinesBox.values) {
      total += routine.timesCompleted;
    }
    return total;
  }

  // ═══════════════════════════════════════
  // 🎯 STUDY TARGETS
  // ═══════════════════════════════════════

  static StudyTarget? getStudyTargetLocal() {
    try {
      final box = _studyTargetsBox;
      if (box == null || !box.isOpen) return null;
      return box.get(_kDefaultStudyTargetId);
    } catch (e) {
      debugPrint('⚠️ getStudyTargetLocal error: $e');
      return null;
    }
  }

  static Future<StudyTarget> ensureStudyTarget() async {
    final now = DateTime.now();
    final fallback = StudyTarget(
      id: _kDefaultStudyTargetId,
      dailyTargetMinutes: AppConfig.defaultDailyTargetMinutes,
      weeklyTargetMinutes: AppConfig.defaultWeeklyTargetMinutes,
      subjectTargets: <String, int>{},
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final box = await _ensureStudyTargetsBox();
      if (box == null || !box.isOpen) return fallback;

      final existing = box.get(_kDefaultStudyTargetId);
      if (existing != null) return existing;

      await box.put(_kDefaultStudyTargetId, fallback);
      return fallback;
    } catch (e) {
      debugPrint('⚠️ ensureStudyTarget error: $e');
      return fallback;
    }
  }

  static Future<void> saveStudyTarget(StudyTarget target) async {
    try {
      final box = await _ensureStudyTargetsBox();
      if (box == null || !box.isOpen) return;

      final updated = target.copyWith(updatedAt: DateTime.now());
      await box.put(_kDefaultStudyTargetId, updated);
      AutoBackupTrigger.notifyChange('study_target_saved');
    } catch (e) {
      debugPrint('⚠️ saveStudyTarget error: $e');
    }
  }

  static Future<void> setStudyTargets({
    required int dailyMinutes,
    required int weeklyMinutes,
    Map<String, int>? subjectWeeklyTargets,
    bool? isActive,
  }) async {
    try {
      final current = await ensureStudyTarget();
      final updated = current.copyWith(
        dailyTargetMinutes: dailyMinutes,
        weeklyTargetMinutes: weeklyMinutes,
        subjectTargets: subjectWeeklyTargets ?? current.subjectTargets,
        isActive: isActive ?? current.isActive,
        updatedAt: DateTime.now(),
      );
      await saveStudyTarget(updated);
    } catch (e) {
      debugPrint('⚠️ setStudyTargets error: $e');
    }
  }

  static Map<String, int> getStudyMinutesThisWeekBySubject() {
    try {
      final now = DateTime.now();
      final map = <String, int>{};

      for (final s in getFocusSessionsOnly()) {
        if (now.difference(s.completedAt).inDays <= 7) {
          map[s.subjectName] = (map[s.subjectName] ?? 0) + s.durationMinutes;
        }
      }
      return map;
    } catch (e) {
      debugPrint('⚠️ getStudyMinutesThisWeekBySubject error: $e');
      return <String, int>{};
    }
  }

  // ═══════════════════════════════════════
  // 🗓️ DAILY STUDY ROUTINES
  // ═══════════════════════════════════════

  static List<DailyStudyRoutine> getAllDailyStudyRoutines() {
    try {
      final box = _dailyStudyRoutinesBox;
      if (box == null || !box.isOpen) return <DailyStudyRoutine>[];

      final all = box.values.toList();
      all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return all;
    } catch (e) {
      debugPrint('⚠️ getAllDailyStudyRoutines error: $e');
      return <DailyStudyRoutine>[];
    }
  }

  static DailyStudyRoutine? getDailyStudyRoutineById(String id) {
    try {
      final box = _dailyStudyRoutinesBox;
      if (box == null || !box.isOpen) return null;
      return box.get(id);
    } catch (e) {
      debugPrint('⚠️ getDailyStudyRoutineById error: $e');
      return null;
    }
  }

  static Future<void> saveDailyStudyRoutine(DailyStudyRoutine routine) async {
    try {
      final box = await _ensureDailyStudyRoutinesBox();
      if (box != null && box.isOpen) {
        await box.put(routine.id, routine.copyWith(updatedAt: DateTime.now()));
        AutoBackupTrigger.notifyChange('daily_routine_saved');
      }
    } catch (e) {
      debugPrint('⚠️ saveDailyStudyRoutine error: $e');
    }
  }

  static Future<void> deleteDailyStudyRoutine(String id) async {
    try {
      final box = await _ensureDailyStudyRoutinesBox();
      if (box != null && box.isOpen) {
        await box.delete(id);
        AutoBackupTrigger.notifyChange('daily_routine_deleted');
      }
    } catch (e) {
      debugPrint('⚠️ deleteDailyStudyRoutine error: $e');
    }
  }

  static Future<void> setDailyStudyRoutineActive(String id, bool active) async {
    try {
      final r = getDailyStudyRoutineById(id);
      if (r == null) return;

      final updated = r.copyWith(
        isActive: active,
        updatedAt: DateTime.now(),
      );
      await saveDailyStudyRoutine(updated);
    } catch (e) {
      debugPrint('⚠️ setDailyStudyRoutineActive error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 🍅 ADVANCED POMODORO SETTINGS
  // ═══════════════════════════════════════

  static bool getAutoPlayEnabled() =>
      _settingsBox.get('auto_play_enabled', defaultValue: false) as bool;

  static Future<void> setAutoPlayEnabled(bool enabled) async {
    await _settingsBox.put('auto_play_enabled', enabled);
    AutoBackupTrigger.notifyChange('setting_changed');
  }

  static bool getPomodoroTtsEnabled() =>
      _settingsBox.get('pomodoro_tts_enabled', defaultValue: true) as bool;

  static Future<void> setPomodoroTtsEnabled(bool enabled) async {
    await _settingsBox.put('pomodoro_tts_enabled', enabled);
    AutoBackupTrigger.notifyChange('setting_changed');
  }

  static bool getKeepScreenOn() =>
      _settingsBox.get('keep_screen_on', defaultValue: true) as bool;

  static Future<void> setKeepScreenOn(bool enabled) async {
    await _settingsBox.put('keep_screen_on', enabled);
    AutoBackupTrigger.notifyChange('setting_changed');
  }

  static bool getVibrateOnComplete() =>
      _settingsBox.get('vibrate_on_complete', defaultValue: true) as bool;

  static Future<void> setVibrateOnComplete(bool enabled) async {
    await _settingsBox.put('vibrate_on_complete', enabled);
    AutoBackupTrigger.notifyChange('setting_changed');
  }

  // ═══════════════════════════════════════
  // 🍅 STUDY MODE METHODS
  // ═══════════════════════════════════════

  static Future<void> saveStudySession(StudySession session) async {
    await _studySessionsBox.put(session.id, session);

    final today = DateTime.now().toString().split(' ')[0];
    final lastStudyDate = _settingsBox.get('last_study_date', defaultValue: '');

    if (lastStudyDate != today && session.sessionType == 'focus') {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toString()
          .split(' ')[0];
      int currentStreak =
      _settingsBox.get('current_study_streak', defaultValue: 0) as int;

      if (lastStudyDate == yesterday) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }

      await _settingsBox.put('last_study_date', today);
      await _settingsBox.put('current_study_streak', currentStreak);

      int bestStreak =
      _settingsBox.get('best_study_streak', defaultValue: 0) as int;
      if (currentStreak > bestStreak) {
        await _settingsBox.put('best_study_streak', currentStreak);
      }
    }

    AutoBackupTrigger.notifyChange('study_session_saved');
  }

  static List<StudySession> getAllStudySessions() =>
      _studySessionsBox.values.toList();

  static List<StudySession> getFocusSessionsOnly() {
    return _studySessionsBox.values
        .where((s) => s.sessionType == 'focus')
        .toList();
  }

  static int getTotalStudyMinutesToday() {
    final today = DateTime.now().toString().split(' ')[0];
    int total = 0;
    for (var session in getFocusSessionsOnly()) {
      final dateStr = session.completedAt.toString().split(' ')[0];
      if (dateStr == today) {
        total += session.durationMinutes;
      }
    }
    return total;
  }

  static int getTotalStudyMinutesThisWeek() {
    final now = DateTime.now();
    int total = 0;
    for (var session in getFocusSessionsOnly()) {
      if (now.difference(session.completedAt).inDays <= 7) {
        total += session.durationMinutes;
      }
    }
    return total;
  }

  static int getTotalStudyMinutesAllTime() {
    int total = 0;
    for (var session in getFocusSessionsOnly()) {
      total += session.durationMinutes;
    }
    return total;
  }

  static Map<String, int> getStudyTimeBySubject() {
    final map = <String, int>{};
    for (var session in getFocusSessionsOnly()) {
      map[session.subjectName] =
          (map[session.subjectName] ?? 0) + session.durationMinutes;
    }
    return map;
  }

  static int getStudyStreak() =>
      _settingsBox.get('current_study_streak', defaultValue: 0) as int;

  static int getBestStudyStreak() =>
      _settingsBox.get('best_study_streak', defaultValue: 0) as int;

  static int getTotalPomodorosCompleted() => getFocusSessionsOnly().length;

  static int getPomodoroFocusMinutes() => _settingsBox.get(
    'pomodoro_focus_mins',
    defaultValue: AppConfig.defaultFocusMinutes,
  ) as int;

  static int getPomodoroShortBreakMinutes() => _settingsBox.get(
    'pomodoro_short_break_mins',
    defaultValue: AppConfig.defaultShortBreakMinutes,
  ) as int;

  static int getPomodoroLongBreakMinutes() => _settingsBox.get(
    'pomodoro_long_break_mins',
    defaultValue: AppConfig.defaultLongBreakMinutes,
  ) as int;

  static Future<void> setPomodoroSettings({
    required int focusMins,
    required int shortBreakMins,
    required int longBreakMins,
  }) async {
    await _settingsBox.put('pomodoro_focus_mins', focusMins);
    await _settingsBox.put('pomodoro_short_break_mins', shortBreakMins);
    await _settingsBox.put('pomodoro_long_break_mins', longBreakMins);
    AutoBackupTrigger.notifyChange('pomodoro_settings_changed');
  }

  static List<String> getCustomStudySubjects() {
    final raw =
    _settingsBox.get('custom_study_subjects', defaultValue: <dynamic>[]);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  static Future<void> addCustomStudySubject(String subject) async {
    final subjects = getCustomStudySubjects();
    if (!subjects.contains(subject)) {
      subjects.add(subject);
      await _settingsBox.put('custom_study_subjects', subjects);
      AutoBackupTrigger.notifyChange('subject_added');
    }
  }

  static Future<void> removeCustomStudySubject(String subject) async {
    final subjects = getCustomStudySubjects();
    subjects.remove(subject);
    await _settingsBox.put('custom_study_subjects', subjects);
    AutoBackupTrigger.notifyChange('subject_removed');
  }

  // ═══════════════════════════════════════
  // HABIT CRUD
  // ═══════════════════════════════════════

  static List<Habit> getAllHabits() => _habitsBox.values.toList();

  static Habit? getHabitById(String id) {
    try {
      return _habitsBox.get(id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> addHabit(Habit habit) async {
    await _habitsBox.put(habit.id, habit);
    AutoBackupTrigger.notifyChange('habit_added');
  }

  static Future<void> updateHabit(Habit habit) async {
    await _habitsBox.put(habit.id, habit);
    AutoBackupTrigger.notifyChange('habit_updated');
  }

  static Future<void> deleteHabit(String id) async {
    await _habitsBox.delete(id);
    AutoBackupTrigger.notifyChange('habit_deleted');
  }

  static Future<void> deleteAllHabits() async {
    await _habitsBox.clear();
    AutoBackupTrigger.notifyChange('habits_cleared');
  }

  // ═══════════════════════════════════════
  // NOTIFICATION STORAGE
  // ═══════════════════════════════════════

  static Future<void> saveNotification(AppNotification notification) async {
    await _notificationsBox.put(notification.id, notification);
  }

  static List<AppNotification> getAllNotifications() {
    final all = _notificationsBox.values.toList();
    all.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return all;
  }

  static int getUnreadNotificationCount() {
    return _notificationsBox.values.where((n) => !n.isRead).length;
  }

  static Future<void> markNotificationAsRead(String id) async {
    final notif = _notificationsBox.get(id);
    if (notif != null) {
      notif.isRead = true;
      await notif.save();
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    for (var notif in _notificationsBox.values) {
      if (!notif.isRead) {
        notif.isRead = true;
        await notif.save();
      }
    }
  }

  static Future<void> deleteNotification(String id) async {
    await _notificationsBox.delete(id);
  }

  static Future<void> deleteAllNotifications() async {
    await _notificationsBox.clear();
  }

  static AppNotification? getNotificationById(String id) =>
      _notificationsBox.get(id);

  // ═══════════════════════════════════════
  // CUSTOM CATEGORIES
  // ═══════════════════════════════════════

  static List<String> getCustomCategories() {
    final raw = _settingsBox.get('custom_categories', defaultValue: <dynamic>[]);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  static Future<void> saveCustomCategory(String category) async {
    final categories = getCustomCategories();
    if (!categories.contains(category)) {
      categories.add(category);
      await _settingsBox.put('custom_categories', categories);
      AutoBackupTrigger.notifyChange('category_added');
    }
  }

  static Future<void> removeCustomCategory(String category) async {
    final categories = getCustomCategories();
    categories.remove(category);
    await _settingsBox.put('custom_categories', categories);
    AutoBackupTrigger.notifyChange('category_removed');
  }

  // ═══════════════════════════════════════
  // MISSED HABIT DIALOG
  // ═══════════════════════════════════════

  static String getLastMissedDialogDate() =>
      _settingsBox.get('last_missed_dialog_date', defaultValue: '') as String;

  static Future<void> setLastMissedDialogDate(String date) async {
    await _settingsBox.put('last_missed_dialog_date', date);
  }

  static bool shouldShowMissedDialog() {
    if (!AppConfig.enableMissedHabitDialog) return false;
    final today = DateTime.now().toString().split(' ')[0];
    final lastShown = getLastMissedDialogDate();
    return lastShown != today;
  }

  static List<Habit> getMissedHabitsYesterday() {
    final habits = getAllHabits();
    return habits
        .where((h) => h.wasMissedYesterday() && !h.hasReasonForYesterday())
        .toList();
  }

  static String? getMostCommonMissedReason(Habit habit) {
    final reasons = habit.getRecentMissedReasons(14);
    if (reasons.isEmpty) return null;

    final countMap = <String, int>{};
    for (final r in reasons) {
      final reason = r.split(':').skip(1).join(':');
      countMap[reason] = (countMap[reason] ?? 0) + 1;
    }

    String? mostCommon;
    int maxCount = 0;
    for (final entry in countMap.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostCommon = entry.key;
      }
    }
    return mostCommon;
  }

  static String getSmartReminderMessage(Habit habit) {
    final lastReason = habit.getLastMissedReason();
    return AppConfig.getSmartMessage(lastReason ?? 'default', habit.name);
  }

  // ═══════════════════════════════════════
  // AUTO RESET TIME
  // ═══════════════════════════════════════

  static TimeOfDay getAutoResetTime() {
    final hour = _settingsBox.get('auto_reset_hour', defaultValue: 0) as int;
    final minute = _settingsBox.get('auto_reset_minute', defaultValue: 0) as int;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<void> setAutoResetTime(TimeOfDay time) async {
    await _settingsBox.put('auto_reset_hour', time.hour);
    await _settingsBox.put('auto_reset_minute', time.minute);
    AutoBackupTrigger.notifyChange('reset_time_changed');
  }

  static bool shouldResetHabitsNow() {
    final resetTime = getAutoResetTime();
    final now = DateTime.now();
    final lastResetDate =
    _settingsBox.get('last_auto_reset_date', defaultValue: '') as String;
    final today = now.toString().split(' ')[0];

    if (lastResetDate == today) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final resetMinutes = resetTime.hour * 60 + resetTime.minute;

    return nowMinutes >= resetMinutes;
  }

  static Future<void> markAutoResetDone() async {
    final today = DateTime.now().toString().split(' ')[0];
    await _settingsBox.put('last_auto_reset_date', today);
  }

  static Future<void> performAutoReset() async {
    if (!shouldResetHabitsNow()) return;

    final habits = getAllHabits();
    final today = DateTime.now().toString().split(' ')[0];

    for (final habit in habits) {
      if (habit.lastProgressDate != today) {
        habit.dailyGoalProgress = 0;
        habit.lastProgressDate = today;
        await updateHabit(habit);
      }
    }

    await markAutoResetDone();
    debugPrint('✅ Auto reset performed at ${DateTime.now()}');
  }

  // ═══════════════════════════════════════
  // AUTO BACKUP SETTINGS
  // ═══════════════════════════════════════

  static bool isAutoBackupEnabled() =>
      _settingsBox.get('auto_backup_enabled', defaultValue: true) as bool;

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    await _settingsBox.put('auto_backup_enabled', enabled);
  }

  static String getAutoBackupFrequency() => _settingsBox.get(
    'auto_backup_frequency',
    defaultValue: 'every_change',
  ) as String;

  static Future<void> setAutoBackupFrequency(String frequency) async {
    await _settingsBox.put('auto_backup_frequency', frequency);
  }

  static bool isAutoBackupWifiOnly() =>
      _settingsBox.get('auto_backup_wifi_only', defaultValue: false) as bool;

  static Future<void> setAutoBackupWifiOnly(bool wifiOnly) async {
    await _settingsBox.put('auto_backup_wifi_only', wifiOnly);
  }

  static int getLastAutoBackupTime() =>
      _settingsBox.get('last_auto_backup_time', defaultValue: 0) as int;

  static Future<void> setLastAutoBackupTime(int timestampMs) async {
    await _settingsBox.put('last_auto_backup_time', timestampMs);
  }

  static bool hasPendingBackup() =>
      _settingsBox.get('has_pending_backup', defaultValue: false) as bool;

  static Future<void> setPendingBackup(bool pending) async {
    await _settingsBox.put('has_pending_backup', pending);
  }

  // ═══════════════════════════════════════
  // PSYCHOLOGY NUDGES
  // ═══════════════════════════════════════

  static bool arePsychologyNudgesEnabled() => _settingsBox.get(
    'psychology_nudges_enabled',
    defaultValue: true,
  ) as bool;

  static Future<void> setPsychologyNudgesEnabled(bool enabled) async {
    await _settingsBox.put('psychology_nudges_enabled', enabled);
    AutoBackupTrigger.notifyChange('setting_changed');
  }

  // ═══════════════════════════════════════════════════════════
  // 🌟 PRO / SUBSCRIPTION (VIP REMOVED)
  // ═══════════════════════════════════════════════════════════

  static bool isProUser() =>
      _settingsBox.get('is_pro', defaultValue: false) as bool;

  static Future<void> setProUser(bool value) async {
    await _settingsBox.put('is_pro', value);
    if (value) await onPremiumUpgrade();
  }

  static String getPurchasedPlan() =>
      _settingsBox.get('purchased_plan', defaultValue: '') as String;

  static Future<void> setPurchasedPlan(String planId) async {
    await _settingsBox.put('purchased_plan', planId);
  }

  /// ✅ Backward compatible - now same as isProUser
  static bool isProOrVipUser() => isProUser();

  /// ✅ Legacy stubs (always return false/empty - kept for backward compat)
  static bool isVipUser() => false;
  static bool isVipExpired() => true;
  static int getVipExpiry() => 0;
  static int getVipDaysRemaining() => 0;
  static String getVipExpiryFormatted() => '';
  static String getVipEmail() => '';

  // ═══════════════════════════════════════
  // PUSH NOTIFICATION TRACKING
  // ═══════════════════════════════════════

  static int getLastSeenNotificationTime() => _settingsBox.get(
    'last_seen_notification_time',
    defaultValue: 0,
  ) as int;

  static Future<void> setLastSeenNotificationTime(int timestampMs) async {
    await _settingsBox.put('last_seen_notification_time', timestampMs);
  }

  static int getLastConfigFetchTime() =>
      _settingsBox.get('last_config_fetch_time', defaultValue: 0) as int;

  static Future<void> setLastConfigFetchTime(int timestampMs) async {
    await _settingsBox.put('last_config_fetch_time', timestampMs);
  }

  static bool shouldFetchConfig() {
    final lastFetch = getLastConfigFetchTime();
    if (lastFetch == 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final twelveHoursMs = 12 * 60 * 60 * 1000;
    return (now - lastFetch) > twelveHoursMs;
  }

  static bool hasUnseenNotification(int notificationTimestamp) {
    final lastSeen = getLastSeenNotificationTime();
    return notificationTimestamp > lastSeen;
  }

  // ═══════════════════════════════════════
  // THEME
  // ═══════════════════════════════════════

  static String getThemeMode() =>
      _settingsBox.get('theme_mode', defaultValue: 'system') as String;

  static Future<void> setThemeMode(String mode) async {
    await _settingsBox.put('theme_mode', mode);
    AutoBackupTrigger.notifyChange('theme_changed');
  }

  // ═══════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════

  static bool areNotificationsEnabled() =>
      _settingsBox.get('notifications_enabled', defaultValue: true) as bool;

  static Future<void> setNotifications(bool enabled) async {
    await _settingsBox.put('notifications_enabled', enabled);
    AutoBackupTrigger.notifyChange('notification_setting_changed');
  }

  // ═══════════════════════════════════════
  // ADS
  // ═══════════════════════════════════════

  static int getInterstitialCounter() =>
      _settingsBox.get('interstitial_counter', defaultValue: 0) as int;

  static Future<void> incrementInterstitialCounter() async {
    final current = getInterstitialCounter();
    await _settingsBox.put('interstitial_counter', current + 1);
  }

  static Future<void> resetInterstitialCounter() async {
    await _settingsBox.put('interstitial_counter', 0);
  }

  static int getSessionInterstitialCount() =>
      _settingsBox.get('session_interstitial_count', defaultValue: 0) as int;

  static Future<void> setSessionInterstitialCount(int value) async {
    await _settingsBox.put('session_interstitial_count', value);
  }

  static int getLastInterstitialTime() =>
      _settingsBox.get('last_interstitial_time', defaultValue: 0) as int;

  static Future<void> setLastInterstitialTime(int value) async {
    await _settingsBox.put('last_interstitial_time', value);
  }

  static int getRewardedExtraHabits() =>
      _settingsBox.get('rewarded_extra_habits', defaultValue: 0) as int;

  static Future<void> addRewardedExtraHabits(int value) async {
    final current = getRewardedExtraHabits();
    await _settingsBox.put('rewarded_extra_habits', current + value);
  }

  static Future<void> resetSessionAdState() async {
    await _settingsBox.put('session_interstitial_count', 0);
  }

  // ═══════════════════════════════════════
  // STATS
  // ═══════════════════════════════════════

  static int getTotalHabitsCompleted() {
    int total = 0;
    for (var habit in _habitsBox.values) {
      total += habit.completedDates.length;
    }
    return total;
  }

  static int getCurrentStreakTotal() {
    int total = 0;
    for (var habit in _habitsBox.values) {
      total += habit.currentStreak;
    }
    return total;
  }

  static int getBestStreakTotal() {
    int best = 0;
    for (var habit in _habitsBox.values) {
      if (habit.bestStreak > best) best = habit.bestStreak;
    }
    return best;
  }

  static Map<String, int> getHabitsByCategory() {
    final map = <String, int>{};
    for (var habit in _habitsBox.values) {
      map[habit.category] = (map[habit.category] ?? 0) + 1;
    }
    return map;
  }

  static Map<String, int> getHabitsByPriority() {
    final map = <String, int>{};
    for (var habit in _habitsBox.values) {
      map[habit.priority] = (map[habit.priority] ?? 0) + 1;
    }
    return map;
  }

  static int getCompletedCountForDate(String dateStr) {
    int count = 0;
    for (var habit in _habitsBox.values) {
      if (habit.completedDates.contains(dateStr)) count++;
    }
    return count;
  }

  static List<Habit> getHabitsCompletedOnDate(String dateStr) {
    return _habitsBox.values
        .where((h) => h.completedDates.contains(dateStr))
        .toList();
  }

  static Map<int, double> getWeeklyCompletionMap() {
    final now = DateTime.now();
    final map = <int, double>{};
    final totalHabits = _habitsBox.values.length;

    if (totalHabits == 0) return map;

    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: (now.weekday - 1) - i));
      final dateStr = day.toString().split(' ')[0];

      int completed = 0;
      for (var habit in _habitsBox.values) {
        if (habit.completedDates.contains(dateStr)) completed++;
      }

      map[i + 1] = (completed / totalHabits) * 100;
    }

    return map;
  }

  // ═══════════════════════════════════════
  // SOUND & TTS
  // ═══════════════════════════════════════

  static bool areSoundEffectsEnabled() =>
      _settingsBox.get('sound_effects_enabled', defaultValue: true) as bool;

  static Future<void> setSoundEffectsEnabled(bool enabled) async {
    await _settingsBox.put('sound_effects_enabled', enabled);
    AutoBackupTrigger.notifyChange('setting_changed');
  }

  static bool isTtsEnabled() =>
      _settingsBox.get('tts_enabled', defaultValue: true) as bool;

  static Future<void> setTtsEnabled(bool enabled) async {
    await _settingsBox.put('tts_enabled', enabled);
    AutoBackupTrigger.notifyChange('setting_changed');
  }

  // ═══════════════════════════════════════
  // LEVEL TRACKING
  // ═══════════════════════════════════════

  static int getLastKnownLevel() =>
      _settingsBox.get('last_known_level', defaultValue: 1) as int;

  static Future<void> setLastKnownLevel(int level) async {
    await _settingsBox.put('last_known_level', level);
  }

  // ═══════════════════════════════════════
  // USER PROFILE
  // ═══════════════════════════════════════

  static String getUserGoalType() =>
      _settingsBox.get('user_goal_type', defaultValue: '') as String;

  static Future<void> setUserGoalType(String type) async {
    await _settingsBox.put('user_goal_type', type);
    AutoBackupTrigger.notifyChange('profile_changed');
  }

  static String getUserName() =>
      _settingsBox.get('user_name', defaultValue: 'Habit Hero') as String;

  static Future<void> setUserName(String name) async {
    await _settingsBox.put('user_name', name);
    AutoBackupTrigger.notifyChange('profile_changed');
  }

  static String getUserAvatar() =>
      _settingsBox.get('user_avatar', defaultValue: '🦸') as String;

  static Future<void> setUserAvatar(String avatar) async {
    await _settingsBox.put('user_avatar', avatar);
    AutoBackupTrigger.notifyChange('profile_changed');
  }

  // ═══════════════════════════════════════
  // MISC SETTINGS
  // ═══════════════════════════════════════

  static bool isAdSoundMuted() =>
      _settingsBox.get('ad_sound_muted', defaultValue: true) as bool;

  static Future<void> setAdSoundMuted(bool muted) async {
    await _settingsBox.put('ad_sound_muted', muted);
  }

  static String getDetectedCountryCode() =>
      _settingsBox.get('detected_country_code', defaultValue: '') as String;

  static Future<void> setDetectedCountryCode(String code) async {
    await _settingsBox.put('detected_country_code', code);
  }

  static bool isFirstLaunch() =>
      _settingsBox.get('first_launch', defaultValue: true) as bool;

  static Future<void> setFirstLaunchDone() async {
    await _settingsBox.put('first_launch', false);
  }

  static String getLanguageCode() => _settingsBox.get(
    'language_code',
    defaultValue: AppConfig.defaultAppLanguageCode,
  ) as String;

  static Future<void> setLanguageCode(String code) async {
    await _settingsBox.put('language_code', code);
    AutoBackupTrigger.notifyChange('language_changed');
  }

  static bool isDynamicTranslationEnabled() => _settingsBox.get(
    'dynamic_translation_enabled',
    defaultValue: false,
  ) as bool;

  static Future<void> setDynamicTranslationEnabled(bool enabled) async {
    await _settingsBox.put('dynamic_translation_enabled', enabled);
  }

  static bool areStarterGoalsApplied() =>
      _settingsBox.get('starter_goals_applied', defaultValue: false) as bool;

  static Future<void> setStarterGoalsApplied(bool value) async {
    await _settingsBox.put('starter_goals_applied', value);
  }

  static Future<void> addStarterHabits(
      List<Map<String, dynamic>> selectedGoals,
      ) async {
    for (final item in selectedGoals) {
      final habit = Habit(
        id: '${DateTime.now().millisecondsSinceEpoch}_${item['id']}',
        name: item['name'] as String,
        emoji: item['emoji'] as String,
        colorValue: item['color'] as int,
        category: item['category'] as String,
        frequency: 'daily',
        createdAt: DateTime.now(),
      );
      await addHabit(habit);
    }
    await setStarterGoalsApplied(true);
  }

  // ═══════════════════════════════════════
  // ROUTINES (HABIT)
  // ═══════════════════════════════════════

  static String _routineUnlockKey(String routineId) =>
      'routine_unlock_expiry_$routineId';

  static Future<void> unlockRoutineForOneDay(String routineId) async {
    final expiry =
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
    await _settingsBox.put(_routineUnlockKey(routineId), expiry);
  }

  static bool isRoutineUnlocked(String routineId) {
    if (isProUser()) return true;
    final expiry =
    _settingsBox.get(_routineUnlockKey(routineId), defaultValue: 0) as int;
    if (expiry == 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now < expiry;
  }

  static int getRoutineUnlockExpiry(String routineId) {
    return _settingsBox.get(_routineUnlockKey(routineId), defaultValue: 0) as int;
  }

  static Future<void> lockRoutine(String routineId) async {
    await _settingsBox.delete(_routineUnlockKey(routineId));
  }

  static Future<void> cleanupExpiredRoutineUnlocks(
      List<String> routineIds,
      ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in routineIds) {
      final expiry = getRoutineUnlockExpiry(id);
      if (expiry != 0 && expiry <= now) {
        await lockRoutine(id);
      }
    }
  }

  // ═══════════════════════════════════════
  // AD SYSTEM HELPERS
  // ═══════════════════════════════════════

  static Future<void> onPremiumUpgrade() async {
    await resetInterstitialCounter();
    await setSessionInterstitialCount(0);
    await setLastInterstitialTime(0);
    await _settingsBox.put('rewarded_extra_habits', 0);
    await updateLeaderboardActivityStatus();
    debugPrint('🌟 Premium upgrade - ad states cleared');
  }

  static Future<void> onPremiumDowngrade() async {
    await resetInterstitialCounter();
    await setSessionInterstitialCount(0);
    debugPrint('📉 Premium downgrade - ready for ads');
  }

  static bool get isPremium => isProUser();

  static bool canCreateMoreHabits() {
    if (isProUser()) return true;
    final currentCount = getAllHabits().length;
    final extraFromAds = getRewardedExtraHabits();
    final totalAllowed = AppConfig.maxHabitsFree + extraFromAds;
    return currentCount < totalAllowed;
  }

  static int getRemainingHabitSlots() {
    if (isProUser()) return 999;
    final currentCount = getAllHabits().length;
    final extraFromAds = getRewardedExtraHabits();
    final totalAllowed = AppConfig.maxHabitsFree + extraFromAds;
    return (totalAllowed - currentCount).clamp(0, 999);
  }

  static Map<String, dynamic> getPremiumStatus() {
    return {
      'isPremium': isProUser(),
      'isPro': isProUser(),
      'purchasedPlan': getPurchasedPlan(),
    };
  }

  static void printPremiumStatus() {
    final status = getPremiumStatus();
    debugPrint('══════════ PREMIUM STATUS ══════════');
    status.forEach((k, v) => debugPrint('$k: $v'));
    debugPrint('════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════════════
  // NOTES BACKUP INTEGRATION
  // ═══════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getNotesBackupData() async {
    try {
      final notesBackup = await NotesService.getNotesForBackup();
      return {
        'notes': notesBackup,
        'notesCount': notesBackup.length,
      };
    } catch (e) {
      debugPrint('⚠️ Notes backup error: $e');
      return {'notes': [], 'notesCount': 0};
    }
  }

  static Future<void> restoreNotesFromBackup(
      Map<String, dynamic> backupData,
      ) async {
    try {
      final notes = backupData['notes'] as List? ?? [];
      if (notes.isNotEmpty) {
        final restored = await NotesService.restoreNotesFromBackup(
          List<Map<String, dynamic>>.from(notes),
        );
        debugPrint('✅ Restored $restored notes');
      }
    } catch (e) {
      debugPrint('⚠️ Restore notes error: $e');
    }
  }
}