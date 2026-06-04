// lib/services/google_drive_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/daily_study_routine_model.dart';
import '../models/habit_model.dart';
import '../models/leaderboard_profile_model.dart';
import '../models/note_model.dart';
import '../models/notification_model.dart';
import '../models/study_routine_model.dart';
import '../models/study_session_model.dart';
import '../models/study_target_model.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'notes_service.dart';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────

class CloudBackupInfo {
  final String fileId;
  final String name;
  final DateTime? modifiedTime;
  final int? sizeBytes;

  const CloudBackupInfo({
    required this.fileId,
    required this.name,
    required this.modifiedTime,
    required this.sizeBytes,
  });
}

class CloudBackupResult {
  final DateTime createdAt;
  final int habits;
  final int notes;
  final int notifications;
  final int studySessions;
  final int studyRoutines;
  final int settingsKeys;
  final int leaderboardProfiles;
  final int studyTargets;
  final int dailyStudyRoutines;

  const CloudBackupResult({
    required this.createdAt,
    required this.habits,
    required this.notes,
    required this.notifications,
    required this.studySessions,
    required this.studyRoutines,
    required this.settingsKeys,
    this.leaderboardProfiles = 0,
    this.studyTargets = 0,
    this.dailyStudyRoutines = 0,
  });
}

class CloudRestoreResult {
  final int habitsImported;
  final int habitsSkipped;
  final int notesImported;
  final int notesSkipped;
  final int notificationsImported;
  final int notificationsSkipped;
  final int studySessionsImported;
  final int studySessionsSkipped;
  final int studyRoutinesImported;
  final int studyRoutinesSkipped;
  final int settingsAdded;
  final int settingsSkipped;
  final int leaderboardProfilesImported;
  final int leaderboardProfilesSkipped;
  final int studyTargetsImported;
  final int studyTargetsSkipped;
  final int dailyStudyRoutinesImported;
  final int dailyStudyRoutinesSkipped;

  const CloudRestoreResult({
    this.habitsImported = 0,
    this.habitsSkipped = 0,
    this.notesImported = 0,
    this.notesSkipped = 0,
    this.notificationsImported = 0,
    this.notificationsSkipped = 0,
    this.studySessionsImported = 0,
    this.studySessionsSkipped = 0,
    this.studyRoutinesImported = 0,
    this.studyRoutinesSkipped = 0,
    this.settingsAdded = 0,
    this.settingsSkipped = 0,
    this.leaderboardProfilesImported = 0,
    this.leaderboardProfilesSkipped = 0,
    this.studyTargetsImported = 0,
    this.studyTargetsSkipped = 0,
    this.dailyStudyRoutinesImported = 0,
    this.dailyStudyRoutinesSkipped = 0,
  });
}

class CloudBackupException implements Exception {
  final String message;
  final Object? cause;

  const CloudBackupException(this.message,
      {this.cause});

  @override
  String toString() =>
      'CloudBackupException: $message';
}

// ─────────────────────────────────────────────
// RESTORE SOURCE — dashboard vs onboarding
// ─────────────────────────────────────────────

enum RestoreSource {
  onboarding, // first install — full overwrite OK
  dashboard,  // user manually signed in — merge only
  splash,     // silent background restore
}

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────

class GoogleDriveService {
  GoogleDriveService();

  static const String _backupFileName =
      'habitnode_cloud_backup.json';
  static const int _schemaVersion = 2;

  static const String _kLastCloudBackupAt =
      'cloud_backup_last_at';
  static const String _kLastCloudRestoreAt =
      'cloud_restore_last_at';

  final AuthService _authService =
      AuthService.instance;

  // ═══════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════

  Future<CloudBackupResult>
  backupAllDataToCloudOnDemand() async {
    return _withDriveApi<CloudBackupResult>(
            (api) async {
          final payload = await _buildBackupPayload();
          final bytes =
          utf8.encode(jsonEncode(payload));

          await _uploadBytesToDrive(api, bytes);

          final createdAt = DateTime.tryParse(
              payload['createdAt'] as String? ??
                  '') ??
              DateTime.now().toUtc();
          final counts = Map<String, dynamic>.from(
              payload['counts'] as Map? ?? {});

          await _setLastBackupTimeLocal(createdAt);

          return CloudBackupResult(
            createdAt: createdAt,
            habits: _asInt(counts['habits']),
            notes: _asInt(counts['notes']),
            notifications:
            _asInt(counts['notifications']),
            studySessions:
            _asInt(counts['study_sessions']),
            studyRoutines:
            _asInt(counts['study_routines']),
            settingsKeys:
            _asInt(counts['settingsKeys']),
            leaderboardProfiles:
            _asInt(counts['leaderboard_profiles']),
            studyTargets:
            _asInt(counts['study_targets']),
            dailyStudyRoutines:
            _asInt(counts['daily_study_routines']),
          );
        });
  }

  // ✅ FIX: RestoreSource parameter
  // Dashboard restore = merge (habits dedup)
  // Settings restore = always try safe keys
  Future<CloudRestoreResult>
  restoreAllDataFromCloudOnDemand({
    RestoreSource source =
        RestoreSource.onboarding,
  }) async {
    return _withDriveApi<CloudRestoreResult>(
            (api) async {
          final Map<String, dynamic> decoded =
          await _downloadAndDecodeBackup(api);

          final schema =
          _asInt(decoded['schemaVersion']);
          if (schema < 1 ||
              schema > _schemaVersion) {
            throw CloudBackupException(
                'Unsupported backup schema version: $schema');
          }

          final data = decoded['data'];
          if (data is! Map<String, dynamic>) {
            throw const CloudBackupException(
                'Backup payload missing data.');
          }

          // ✅ Habits — always merge (dedup by ID)
          final habitResult =
          await _restoreHabits(data['habits']);

          final noteResult =
          await _restoreNotes(data['notes']);

          final notifResult =
          await _restoreNotifications(
              data['notifications']);

          final sessionResult =
          await _restoreStudySessions(
              data['study_sessions']);

          final routineResult =
          await _restoreStudyRoutines(
              data['study_routines']);

          // ✅ FIX: Settings — pass source
          // Dashboard restore-এও safe settings আসবে
          final settingsResult =
          await _restoreSettings(
            data['settings'],
            source: source,
          );

          Map<String, int> leaderboardResult = {
            'imported': 0,
            'skipped': 0
          };
          Map<String, int> studyTargetResult = {
            'imported': 0,
            'skipped': 0
          };
          Map<String, int> dailyRoutineResult = {
            'imported': 0,
            'skipped': 0
          };

          if (schema >= 2) {
            leaderboardResult =
            await _restoreLeaderboardProfiles(
              data['leaderboard_profiles'],
              source: source,
            );
            studyTargetResult =
            await _restoreStudyTargets(
                data['study_targets']);
            dailyRoutineResult =
            await _restoreDailyStudyRoutines(
                data['daily_study_routines']);
          }

          // ✅ FIX: Dashboard restore এর পরে
          // user_name ও user_avatar sync করো
          // যাতে dashboard greeting সঠিক দেখায়
          if (source == RestoreSource.dashboard ||
              source == RestoreSource.splash) {
            await _syncUserNameAndAvatar(
                data['settings']);
          }

          await _setLastRestoreTimeLocal(
              DateTime.now().toUtc());

          return CloudRestoreResult(
            habitsImported:
            habitResult['imported'] ?? 0,
            habitsSkipped:
            habitResult['skipped'] ?? 0,
            notesImported: noteResult['imported'] ?? 0,
            notesSkipped: noteResult['skipped'] ?? 0,
            notificationsImported:
            notifResult['imported'] ?? 0,
            notificationsSkipped:
            notifResult['skipped'] ?? 0,
            studySessionsImported:
            sessionResult['imported'] ?? 0,
            studySessionsSkipped:
            sessionResult['skipped'] ?? 0,
            studyRoutinesImported:
            routineResult['imported'] ?? 0,
            studyRoutinesSkipped:
            routineResult['skipped'] ?? 0,
            settingsAdded:
            settingsResult['imported'] ?? 0,
            settingsSkipped:
            settingsResult['skipped'] ?? 0,
            leaderboardProfilesImported:
            leaderboardResult['imported'] ?? 0,
            leaderboardProfilesSkipped:
            leaderboardResult['skipped'] ?? 0,
            studyTargetsImported:
            studyTargetResult['imported'] ?? 0,
            studyTargetsSkipped:
            studyTargetResult['skipped'] ?? 0,
            dailyStudyRoutinesImported:
            dailyRoutineResult['imported'] ?? 0,
            dailyStudyRoutinesSkipped:
            dailyRoutineResult['skipped'] ?? 0,
          );
        });
  }

  Future<CloudBackupInfo?>
  getExistingBackupInfoOnDemand() async {
    return _withDriveApi<CloudBackupInfo?>(
            (api) async {
          final file =
          await _findBackupFileMeta(api);
          if (file == null) return null;

          final fileId = (file.id ?? '').trim();
          if (fileId.isEmpty) return null;

          final sizeBytes = file.size == null
              ? null
              : int.tryParse(file.size!);

          return CloudBackupInfo(
            fileId: fileId,
            name: (file.name ?? _backupFileName)
                .trim()
                .isEmpty
                ? _backupFileName
                : file.name!,
            modifiedTime: file.modifiedTime,
            sizeBytes: sizeBytes,
          );
        });
  }

  Future<void>
  verifyDriveAccessOnDemand() async {
    await _withDriveApi<void>((api) async {
      await api.about
          .get($fields: 'user(emailAddress)');
    });
  }

  // ═══════════════════════════════════════
  // ✅ FIX: Dashboard restore এর পরে
  // user_name ও user_avatar sync
  // ═══════════════════════════════════════

  Future<void> _syncUserNameAndAvatar(
      dynamic settingsData) async {
    try {
      if (settingsData is! Map) return;

      final name =
      settingsData['user_name'] as String?;
      final avatar =
      settingsData['user_avatar'] as String?;

      if (name != null && name.trim().isNotEmpty) {
        await DatabaseService.setUserName(
            name.trim());
        debugPrint(
            '✅ user_name synced: $name');
      }

      if (avatar != null &&
          avatar.trim().isNotEmpty) {
        await DatabaseService.setUserAvatar(
            avatar.trim());
        debugPrint(
            '✅ user_avatar synced: $avatar');
      }
    } catch (e) {
      debugPrint(
          '⚠️ user name/avatar sync error: $e');
    }
  }

  // ═══════════════════════════════════════
  // LOCAL CACHE
  // ═══════════════════════════════════════

  DateTime? getLastBackupTimeLocal() {
    try {
      final box =
      Hive.box(DatabaseService.settingsBox);
      final raw = box.get(_kLastCloudBackupAt,
          defaultValue: '');
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
    } catch (_) {}
    return null;
  }

  DateTime? getLastRestoreTimeLocal() {
    try {
      final box =
      Hive.box(DatabaseService.settingsBox);
      final raw = box.get(_kLastCloudRestoreAt,
          defaultValue: '');
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _setLastBackupTimeLocal(
      DateTime timeUtc) async {
    try {
      final box =
      Hive.box(DatabaseService.settingsBox);
      await box.put(
          _kLastCloudBackupAt,
          timeUtc.toIso8601String());
    } catch (_) {}
  }

  Future<void> _setLastRestoreTimeLocal(
      DateTime timeUtc) async {
    try {
      final box =
      Hive.box(DatabaseService.settingsBox);
      await box.put(
          _kLastCloudRestoreAt,
          timeUtc.toIso8601String());
    } catch (_) {}
  }

  // ═══════════════════════════════════════
  // CORE DRIVE OPERATIONS
  // ═══════════════════════════════════════

  Future<drive.File?> _findBackupFileMeta(
      drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_backupFileName' and trashed=false",
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime,size)',
    );

    final files = result.files;
    if (files == null || files.isEmpty) {
      return null;
    }
    return files.first;
  }

  Future<void> _uploadBytesToDrive(
      drive.DriveApi api, List<int> bytes) async {
    final existingFile =
    await _findBackupFileMeta(api);

    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    if (existingFile?.id != null) {
      final updateMetadata = drive.File()
        ..name = _backupFileName
        ..mimeType = 'application/json';

      await api.files.update(
          updateMetadata, existingFile!.id!,
          uploadMedia: media);
    } else {
      final createMetadata = drive.File()
        ..name = _backupFileName
        ..mimeType = 'application/json'
        ..parents = <String>['appDataFolder'];

      await api.files
          .create(createMetadata, uploadMedia: media);
    }
  }

  Future<Map<String, dynamic>>
  _downloadAndDecodeBackup(
      drive.DriveApi api) async {
    final fileMeta =
    await _findBackupFileMeta(api);
    if (fileMeta?.id == null) {
      throw const CloudBackupException(
          'No cloud backup was found.');
    }

    final media = await api.files.get(
      fileMeta!.id!,
      downloadOptions:
      drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytesBuilder =
    BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      bytesBuilder.add(chunk);
    }
    final bytes = bytesBuilder.takeBytes();

    if (bytes.isEmpty) {
      throw const CloudBackupException(
          'Backup file is empty.');
    }

    final jsonString = utf8.decode(bytes);
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw const CloudBackupException(
          'Invalid backup format.');
    }
    return decoded;
  }

  // ═══════════════════════════════════════
  // BACKUP PAYLOAD BUILDERS
  // ═══════════════════════════════════════

  Future<Map<String, dynamic>>
  _buildBackupPayload() async {
    final now = DateTime.now().toUtc();

    final data = <String, dynamic>{
      'habits': _getHabitsForBackup(),
      'notes': _getNotesForBackup(),
      'notifications':
      _getNotificationsForBackup(),
      'study_sessions':
      _getStudySessionsForBackup(),
      'study_routines':
      _getStudyRoutinesForBackup(),
      'settings': _getSettingsForBackup(),
      'leaderboard_profiles':
      _getLeaderboardProfilesForBackup(),
      'study_targets':
      _getStudyTargetsForBackup(),
      'daily_study_routines':
      _getDailyStudyRoutinesForBackup(),
    };

    return <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'app': AppConfig.appName,
      'package': AppConfig.packageName,
      'version': AppConfig.version,
      'createdAt': now.toIso8601String(),
      'data': data,
      'counts': {
        'habits':
        (data['habits'] as List).length,
        'notes':
        (data['notes'] as List).length,
        'notifications':
        (data['notifications'] as List)
            .length,
        'study_sessions':
        (data['study_sessions'] as List)
            .length,
        'study_routines':
        (data['study_routines'] as List)
            .length,
        'settingsKeys':
        (data['settings'] as Map).length,
        'leaderboard_profiles':
        (data['leaderboard_profiles']
        as List)
            .length,
        'study_targets':
        (data['study_targets'] as List)
            .length,
        'daily_study_routines':
        (data['daily_study_routines']
        as List)
            .length,
      },
    };
  }

  List<Map<String, dynamic>>
  _getHabitsForBackup() =>
      DatabaseService.getAllHabits()
          .map((h) => h.toJson())
          .toList();

  List<Map<String, dynamic>>
  _getNotesForBackup() =>
      NotesService.getAllNotes()
          .map((n) => n.toJson())
          .toList();

  List<Map<String, dynamic>>
  _getNotificationsForBackup() {
    return DatabaseService.getAllNotifications()
        .map((n) {
      return {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'receivedAt':
        n.receivedAt.toIso8601String(),
        'isRead': n.isRead,
        'type': n.type,
        'payload': n.payload,
      };
    }).toList();
  }

  List<Map<String, dynamic>>
  _getStudySessionsForBackup() {
    return DatabaseService.getAllStudySessions()
        .map((s) {
      return {
        'id': s.id,
        'subjectName': s.subjectName,
        'subjectColorValue':
        s.subjectColorValue,
        'startTime':
        s.startTime.toIso8601String(),
        'endTime':
        s.endTime?.toIso8601String(),
        'durationMinutes': s.durationMinutes,
        'sessionType': s.sessionType,
        'completedAt':
        s.completedAt.toIso8601String(),
        'pomodoroCount': s.pomodoroCount,
        'isCompleted': s.isCompleted,
      };
    }).toList();
  }

  List<Map<String, dynamic>>
  _getStudyRoutinesForBackup() {
    return DatabaseService.getAllRoutines()
        .map((r) {
      return {
        'id': r.id,
        'name': r.name,
        'createdAt':
        r.createdAt.toIso8601String(),
        'isActive': r.isActive,
        'totalDurationMinutes':
        r.totalDurationMinutes,
        'description': r.description,
        'autoPlayEnabled': r.autoPlayEnabled,
        'ttsEnabled': r.ttsEnabled,
        'timesCompleted': r.timesCompleted,
        'lastPlayedAt':
        r.lastPlayedAt?.toIso8601String(),
        'emoji': r.emoji,
        'colorValue': r.colorValue,
        'sessions': r.sessions.map((rs) {
          return {
            'subjectName': rs.subjectName,
            'subjectColorValue':
            rs.subjectColorValue,
            'durationMinutes':
            rs.durationMinutes,
            'includeBreak': rs.includeBreak,
            'breakDurationMinutes':
            rs.breakDurationMinutes,
            'customMessage': rs.customMessage,
            'order': rs.order,
            'emoji': rs.emoji,
          };
        }).toList(),
      };
    }).toList();
  }

  Map<String, dynamic>
  _getSettingsForBackup() {
    final settingsBox =
    Hive.box(DatabaseService.settingsBox);
    final rawSettings = settingsBox.toMap();
    final safeSettings = <String, dynamic>{};
    for (final entry in rawSettings.entries) {
      safeSettings[entry.key.toString()] =
          _jsonSafe(entry.value);
    }
    return safeSettings;
  }

  List<Map<String, dynamic>>
  _getLeaderboardProfilesForBackup() {
    try {
      if (!DatabaseService
          .isLeaderboardAvailable) return [];

      final box = Hive.box<LeaderboardProfileModel>(
          DatabaseService.leaderboardProfileBox);
      return box.values.map((p) {
        return {
          'uid': p.uid,
          'displayName': p.displayName,
          'tagline': p.tagline,
          'bio': p.bio,
          'countryCode': p.countryCode,
          'createdAt':
          p.createdAt.toIso8601String(),
          'updatedAt':
          p.updatedAt.toIso8601String(),
          'isOptedIn': p.isOptedIn,
          'showLevel': p.showLevel,
          'showBadges': p.showBadges,
          'showStudyHours': p.showStudyHours,
          'avatarEmoji': p.avatarEmoji,
          'avatarIndex': p.avatarIndex,
          'joinedAtMs': p.joinedAtMs,
          'isInterviewUser': p.isInterviewUser,
          'profileThemeIndex':
          p.profileThemeIndex,
          'lastCloudSyncAt':
          p.lastCloudSyncAt
              ?.toIso8601String(),
          'cachedRank': p.cachedRank,
          'cachedScore': p.cachedScore,
          'dailyScore': p.dailyScore,
          'weeklyScore': p.weeklyScore,
          'lastDailyResetMs':
          p.lastDailyResetMs,
          'lastWeeklyResetMs':
          p.lastWeeklyResetMs,
          'posts': p.posts,
          'blockedUsers': p.blockedUsers,
          'isProUser': p.isProUser,
          'lastActiveMs': p.lastActiveMs,
          'unlockedBadges': p.unlockedBadges,
        };
      }).toList();
    } catch (e) {
      debugPrint(
          '⚠️ Leaderboard backup error: $e');
      return [];
    }
  }

  List<Map<String, dynamic>>
  _getStudyTargetsForBackup() {
    try {
      if (!DatabaseService
          .isStudyTargetsAvailable) return [];

      final box = Hive.box<StudyTarget>(
          DatabaseService.studyTargetsBox);
      return box.values.map((t) {
        return {
          'id': t.id,
          'dailyTargetMinutes':
          t.dailyTargetMinutes,
          'weeklyTargetMinutes':
          t.weeklyTargetMinutes,
          'subjectTargets': Map<String, int>.from(
              t.subjectTargets),
          'isActive': t.isActive,
          'createdAt':
          t.createdAt.toIso8601String(),
          'updatedAt':
          t.updatedAt.toIso8601String(),
        };
      }).toList();
    } catch (e) {
      debugPrint(
          '⚠️ StudyTargets backup error: $e');
      return [];
    }
  }

  List<Map<String, dynamic>>
  _getDailyStudyRoutinesForBackup() {
    try {
      if (!DatabaseService
          .isDailyStudyRoutinesAvailable) {
        return [];
      }

      final box = Hive.box<DailyStudyRoutine>(
          DatabaseService.dailyStudyRoutinesBox);
      return box.values
          .map((r) => r.toJson())
          .toList();
    } catch (e) {
      debugPrint(
          '⚠️ DailyStudyRoutines backup error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // RESTORE METHODS
  // ═══════════════════════════════════════

  Future<Map<String, int>> _restoreHabits(
      dynamic rawData) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;
    final box =
    Hive.box<Habit>(DatabaseService.habitsBox);
    final existingIds = DatabaseService
        .getAllHabits()
        .map((h) => h.id)
        .toSet();

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);
        final id = map['id'] as String?;
        if (id == null ||
            id.isEmpty ||
            existingIds.contains(id)) {
          skipped++;
          continue;
        }
        await box.put(id, Habit.fromJson(map));
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: Habit skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>> _restoreNotes(
      dynamic rawData) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;
    final notesBox =
    Hive.box<Note>('notes');

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);
        final id = map['id'] as String?;
        if (id == null ||
            id.isEmpty ||
            NotesService.getNoteById(id) != null) {
          skipped++;
          continue;
        }
        await notesBox.put(
            id, Note.fromJson(map));
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: Note skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>>
  _restoreNotifications(
      dynamic rawData) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;
    final notifBox = Hive.box<AppNotification>(
        DatabaseService.notificationsBox);
    final existingIds = DatabaseService
        .getAllNotifications()
        .map((n) => n.id)
        .toSet();

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);
        final id = map['id'] as String?;
        if (id == null ||
            id.isEmpty ||
            existingIds.contains(id)) {
          skipped++;
          continue;
        }
        final n = AppNotification(
          id: id,
          title:
          (map['title'] as String?) ?? '',
          body: (map['body'] as String?) ?? '',
          receivedAt: DateTime.tryParse(
              map['receivedAt']
              as String? ??
                  '') ??
              DateTime.now(),
          isRead:
          (map['isRead'] as bool?) ?? false,
          type:
          (map['type'] as String?) ?? 'local',
          payload: map['payload'] as String?,
        );
        await notifBox.put(id, n);
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: Notification skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>>
  _restoreStudySessions(
      dynamic rawData) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;
    final box = Hive.box<StudySession>(
        DatabaseService.studySessionsBox);
    final existingIds = DatabaseService
        .getAllStudySessions()
        .map((s) => s.id)
        .toSet();

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);
        final id = map['id'] as String?;
        if (id == null ||
            id.isEmpty ||
            existingIds.contains(id)) {
          skipped++;
          continue;
        }
        final s = StudySession(
          id: id,
          subjectName:
          (map['subjectName'] as String?) ??
              'Other',
          subjectColorValue: _asInt(
              map['subjectColorValue'],
              0xFF6C63FF),
          startTime: DateTime.tryParse(
              map['startTime']
              as String? ??
                  '') ??
              DateTime.now(),
          endTime: map['endTime'] == null
              ? null
              : DateTime.tryParse(
              map['endTime'] as String),
          durationMinutes:
          _asInt(map['durationMinutes']),
          sessionType:
          (map['sessionType'] as String?) ??
              'focus',
          completedAt: DateTime.tryParse(
              map['completedAt']
              as String? ??
                  '') ??
              DateTime.now(),
          pomodoroCount:
          _asInt(map['pomodoroCount']),
          isCompleted:
          (map['isCompleted'] as bool?) ??
              true,
        );
        await box.put(id, s);
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: StudySession skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>>
  _restoreStudyRoutines(
      dynamic rawData) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;
    final box = Hive.box<StudyRoutine>(
        DatabaseService.routinesBox);
    final existingIds = DatabaseService
        .getAllRoutines()
        .map((r) => r.id)
        .toSet();

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);
        final id = map['id'] as String?;
        if (id == null ||
            id.isEmpty ||
            existingIds.contains(id)) {
          skipped++;
          continue;
        }

        final sessionsList =
        <RoutineSession>[];
        if (map['sessions'] is List) {
          for (final sItem
          in map['sessions']) {
            if (sItem is! Map) continue;
            final sMap =
            Map<String, dynamic>.from(
                sItem);
            sessionsList.add(RoutineSession(
              subjectName:
              (sMap['subjectName']
              as String?) ??
                  'Other',
              subjectColorValue: _asInt(
                  sMap['subjectColorValue'],
                  0xFF6C63FF),
              durationMinutes: _asInt(
                  sMap['durationMinutes'], 25),
              includeBreak:
              (sMap['includeBreak']
              as bool?) ??
                  true,
              breakDurationMinutes: _asInt(
                  sMap['breakDurationMinutes'],
                  5),
              customMessage:
              sMap['customMessage']
              as String?,
              order: _asInt(sMap['order']),
              emoji: (sMap['emoji']
              as String?) ??
                  '📖',
            ));
          }
        }

        final routine = StudyRoutine(
          id: id,
          name:
          (map['name'] as String?) ??
              'Routine',
          sessions: sessionsList,
          createdAt: DateTime.tryParse(
              map['createdAt']
              as String? ??
                  '') ??
              DateTime.now(),
          isActive:
          (map['isActive'] as bool?) ??
              false,
          totalDurationMinutes: _asInt(
              map['totalDurationMinutes']),
          description:
          map['description'] as String?,
          autoPlayEnabled:
          (map['autoPlayEnabled']
          as bool?) ??
              true,
          ttsEnabled:
          (map['ttsEnabled'] as bool?) ??
              true,
          timesCompleted:
          _asInt(map['timesCompleted']),
          lastPlayedAt:
          map['lastPlayedAt'] == null
              ? null
              : DateTime.tryParse(
              map['lastPlayedAt']
              as String),
          emoji:
          (map['emoji'] as String?) ??
              '📚',
          colorValue: _asInt(
              map['colorValue'], 0xFF6C63FF),
        );
        await box.put(id, routine);
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: StudyRoutine skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>>
  _restoreLeaderboardProfiles(
      dynamic rawData, {
        RestoreSource source =
            RestoreSource.onboarding,
      }) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);
        final uid =
        (map['uid'] as String?)?.trim();
        if (uid == null || uid.isEmpty) {
          skipped++;
          continue;
        }

        // ✅ FIX: Dashboard restore —
        // existing profile থাকলে skip করবো না
        // overwrite করবো
        // কারণ cloud-এ latest আছে
        final profile =
        LeaderboardProfileModel(
          uid: uid,
          displayName:
          (map['displayName']
          as String?) ??
              'User',
          tagline:
          map['tagline'] as String?,
          bio: map['bio'] as String?,
          countryCode:
          map['countryCode'] as String?,
          createdAt: DateTime.tryParse(
              map['createdAt']
              as String? ??
                  '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(
              map['updatedAt']
              as String? ??
                  '') ??
              DateTime.now(),
          isOptedIn:
          (map['isOptedIn'] as bool?) ??
              false,
          showLevel:
          (map['showLevel'] as bool?) ??
              true,
          showBadges:
          (map['showBadges'] as bool?) ??
              true,
          showStudyHours:
          (map['showStudyHours']
          as bool?) ??
              true,
          avatarEmoji:
          (map['avatarEmoji']
          as String?) ??
              '🙂',
          avatarIndex:
          _asInt(map['avatarIndex']),
          joinedAtMs:
          _asInt(map['joinedAtMs']),
          isInterviewUser:
          (map['isInterviewUser']
          as bool?) ??
              false,
          profileThemeIndex:
          _asInt(map['profileThemeIndex']),
          lastCloudSyncAt:
          map['lastCloudSyncAt'] == null
              ? null
              : DateTime.tryParse(
              map['lastCloudSyncAt']
              as String),
          cachedRank:
          _asInt(map['cachedRank'], -1),
          cachedScore:
          _asDouble(map['cachedScore']),
          dailyScore:
          _asInt(map['dailyScore']),
          weeklyScore:
          _asInt(map['weeklyScore']),
          lastDailyResetMs:
          _asInt(map['lastDailyResetMs']),
          lastWeeklyResetMs:
          _asInt(map['lastWeeklyResetMs']),
          posts: _asPostList(map['posts']),
          blockedUsers:
          _asStringList(
              map['blockedUsers']),
          isProUser:
          (map['isProUser'] as bool?) ??
              false,
          lastActiveMs:
          _asInt(map['lastActiveMs']),
          unlockedBadges:
          _asStringList(
              map['unlockedBadges']),
        );

        await DatabaseService
            .saveLeaderboardProfile(profile);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: Leaderboard profile skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>>
  _restoreStudyTargets(
      dynamic rawData) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);

        final target = StudyTarget(
          id: (map['id'] as String?) ??
              'default_study_target',
          dailyTargetMinutes: _asInt(
              map['dailyTargetMinutes'], 60),
          weeklyTargetMinutes: _asInt(
              map['weeklyTargetMinutes'], 420),
          subjectTargets:
          _asStringIntMap(
              map['subjectTargets']),
          isActive:
          (map['isActive'] as bool?) ??
              true,
          createdAt: DateTime.tryParse(
              map['createdAt']
              as String? ??
                  '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(
              map['updatedAt']
              as String? ??
                  '') ??
              DateTime.now(),
        );

        await DatabaseService
            .saveStudyTarget(target);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: StudyTarget skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>>
  _restoreDailyStudyRoutines(
      dynamic rawData) async {
    if (rawData is! List) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;

    for (final item in rawData) {
      try {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final map =
        Map<String, dynamic>.from(item);
        final routine =
        DailyStudyRoutine.fromJson(map);
        if (routine.id.trim().isEmpty) {
          skipped++;
          continue;
        }

        await DatabaseService
            .saveDailyStudyRoutine(routine);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint(
            'Restore: DailyStudyRoutine skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  // ✅ FIX: Settings restore
  // Dashboard restore-এও safe settings আসবে
  Future<Map<String, int>> _restoreSettings(
      dynamic rawData, {
        RestoreSource source =
            RestoreSource.onboarding,
      }) async {
    if (rawData is! Map) {
      return {'imported': 0, 'skipped': 0};
    }
    int imported = 0, skipped = 0;

    final isFirstInstall =
    DatabaseService.isFirstLaunch();
    final settingsBox =
    Hive.box(DatabaseService.settingsBox);

    for (final entry in rawData.entries) {
      final key = entry.key.toString();

      // Sensitive keys — কখনো restore করবো না
      if (_isSensitiveSettingKey(key)) {
        skipped++;
        continue;
      }

      final incomingValue = entry.value;
      final exists =
      settingsBox.containsKey(key);

      // Key নেই → add করো
      if (!exists) {
        try {
          await settingsBox.put(
              key, incomingValue);
          imported++;
        } catch (e) {
          skipped++;
        }
        continue;
      }

      // ✅ FIX: Dashboard/Splash restore —
      // safe settings overwrite করো
      // user_name, user_avatar, theme ইত্যাদি
      final shouldOverwrite =
          isFirstInstall ||
              source == RestoreSource.dashboard ||
              source == RestoreSource.splash;

      if (shouldOverwrite &&
          _shouldOverwriteSettingOnDashboardRestore(
              key)) {
        try {
          await settingsBox.put(
              key, incomingValue);
          imported++;
        } catch (e) {
          skipped++;
        }
        continue;
      }

      skipped++;
    }
    return {'imported': imported, 'skipped': skipped};
  }

  // ═══════════════════════════════════════
  // AUTH WRAPPER
  // ═══════════════════════════════════════

  Future<T> _withDriveApi<T>(
      Future<T> Function(drive.DriveApi api)
      action, {
        bool didRetry401 = false,
        bool didRepairScope = false,
      }) async {
    http.BaseClient? client;

    try {
      client =
      await _authService.getAuthenticatedClient(
        interactive: true,
        forceConsent: didRepairScope,
        forceRefresh:
        didRetry401 || didRepairScope,
      );

      final api = drive.DriveApi(client);
      return await action(api);
    } catch (e) {
      if (e is CloudBackupException) rethrow;

      final status = _tryReadStatusCode(e);

      if (status == 401 && !didRetry401) {
        try {
          client?.close();
        } catch (_) {}
        return _withDriveApi<T>(
          action,
          didRetry401: true,
          didRepairScope: didRepairScope,
        );
      }

      if (_looksLikeInsufficientPermissions(e) &&
          !didRepairScope) {
        try {
          client?.close();
        } catch (_) {}
        return _withDriveApi<T>(
          action,
          didRetry401: didRetry401,
          didRepairScope: true,
        );
      }

      throw _mapDriveError(e);
    } finally {
      try {
        client?.close();
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  bool _isSensitiveSettingKey(String key) {
    const sensitiveKeys = {
      'is_pro',
      'purchased_plan',
      'interstitial_counter',
      'session_interstitial_count',
      'last_interstitial_time',
      'rewarded_extra_habits',
      'leaderboard_last_uid',
    };
    return sensitiveKeys.contains(key);
  }

  // ✅ FIX: Dashboard restore-এও
  // এই keys overwrite হবে
  bool _shouldOverwriteSettingOnDashboardRestore(
      String key) {
    if (_isSensitiveSettingKey(key)) {
      return false;
    }
    // ✅ Profile-related settings
    // Dashboard sign-in এর পরে এগুলো আসা দরকার
    const dashboardSafeKeys = {
      'user_name',
      'user_avatar',
      'user_goal_type',
      'theme_mode',
      'language_code',
      'dynamic_translation_enabled',
      'sound_effects_enabled',
      'tts_enabled',
      'notifications_enabled',
      'keep_screen_on',
      'vibrate_on_complete',
      'auto_reset_hour',
      'auto_reset_minute',
      'last_known_level',
      'starter_goals_applied',
      'custom_categories',
      'custom_study_subjects',
      'pomodoro_focus_mins',
      'pomodoro_short_break_mins',
      'pomodoro_long_break_mins',
      'pomodoro_tts_enabled',
      'auto_play_enabled',
      'detected_country_code',
      'auto_backup_enabled',
      'auto_backup_frequency',
      'auto_backup_wifi_only',
      'psychology_nudges_enabled',
    };
    if (dashboardSafeKeys.contains(key)) {
      return true;
    }
    if (key.startsWith('routine_unlock_expiry_')) {
      return true;
    }
    return false;
  }

  static dynamic _jsonSafe(dynamic value) {
    if (value == null) return null;
    if (value is num ||
        value is bool ||
        value is String) return value;
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is List) {
      return value
          .map((e) => _jsonSafe(e))
          .toList();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        out[entry.key.toString()] =
            _jsonSafe(entry.value);
      }
      return out;
    }
    return value.toString();
  }

  static int _asInt(dynamic value,
      [int fallback = 0]) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static double _asDouble(dynamic value,
      [double fallback = 0.0]) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static List<String> _asStringList(
      dynamic value) {
    if (value is! List) return <String>[];
    return value.map((e) => e.toString()).toList();
  }

  static List<Map<String, dynamic>>
  _asPostList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        out.add(
            Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static Map<String, int> _asStringIntMap(
      dynamic value) {
    final out = <String, int>{};
    if (value is Map) {
      for (final entry in value.entries) {
        out[entry.key.toString()] =
            _asInt(entry.value);
      }
    }
    return out;
  }

  int? _tryReadStatusCode(Object e) {
    final dynamic d = e;
    try {
      if (d.status is int) return d.status;
    } catch (_) {}
    final s = e.toString();
    final match = RegExp(
        r'\b(400|401|403|404|409|413|429|5\d\d)\b')
        .firstMatch(s);
    return match != null
        ? int.tryParse(match.group(0)!)
        : null;
  }

  String _tryReadApiMessage(Object e) {
    final dynamic d = e;
    try {
      if (d.message is String &&
          d.message.trim().isNotEmpty) {
        return d.message.trim();
      }
    } catch (_) {}
    return e.toString();
  }

  bool _looksLikeInsufficientPermissions(
      Object e) {
    if (_tryReadStatusCode(e) != 403) {
      return false;
    }
    return _tryReadApiMessage(e)
        .toLowerCase()
        .contains('insufficient permission');
  }

  bool _looksLikeStorageQuotaExceeded(
      Object e) {
    if (_tryReadStatusCode(e) != 403) {
      return false;
    }
    return _tryReadApiMessage(e)
        .toLowerCase()
        .contains('storagequotaexceeded');
  }

  CloudBackupException _mapDriveError(
      Object e) {
    if (e is CloudBackupException) return e;
    if (e is AuthServiceException) {
      return CloudBackupException(e.message,
          cause: e);
    }

    if (_looksLikeStorageQuotaExceeded(e)) {
      return CloudBackupException(
        'Google Drive storage is full.',
        cause: e,
      );
    }
    if (_looksLikeInsufficientPermissions(e)) {
      return CloudBackupException(
        'Google Drive permission was not granted.',
        cause: e,
      );
    }

    final status = _tryReadStatusCode(e);
    if (status == 401) {
      return CloudBackupException(
        'Your Google session has expired. Please sign in again.',
        cause: e,
      );
    }
    if (status == 404) {
      return CloudBackupException(
          'No cloud backup was found.',
          cause: e);
    }

    if (e
        .toString()
        .toLowerCase()
        .contains('socketexception')) {
      return CloudBackupException(
        'No internet connection.',
        cause: e,
      );
    }

    return CloudBackupException(
        'A cloud storage error occurred.',
        cause: e);
  }
}