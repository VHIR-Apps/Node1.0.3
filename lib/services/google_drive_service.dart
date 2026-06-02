// lib/services/google_drive_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../models/note_model.dart';
import '../models/notification_model.dart';
import '../models/study_routine_model.dart';
import '../models/study_session_model.dart';
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

  const CloudBackupResult({
    required this.createdAt,
    required this.habits,
    required this.notes,
    required this.notifications,
    required this.studySessions,
    required this.studyRoutines,
    required this.settingsKeys,
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
  });
}

class CloudBackupException implements Exception {
  final String message;
  final Object? cause;

  const CloudBackupException(this.message, {this.cause});

  @override
  String toString() => 'CloudBackupException: $message';
}

// ─────────────────────────────────────────────
// SERVICE IMPLEMENTATION
// ─────────────────────────────────────────────

class GoogleDriveService {
  GoogleDriveService();

  static const String _backupFileName = 'habitnode_cloud_backup.json';
  static const int _schemaVersion = 1;

  // Local keys (Hive settings) to show status without Drive check
  static const String _kLastCloudBackupAt = 'cloud_backup_last_at';
  static const String _kLastCloudRestoreAt = 'cloud_restore_last_at';

  final AuthService _authService = AuthService.instance;

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  /// Performs a full backup of all app data to the Google Drive `appDataFolder`.
  /// This is a user-driven action and will trigger sign-in/permission prompts if needed.
  Future<CloudBackupResult> backupAllDataToCloudOnDemand() async {
    return _withDriveApi<CloudBackupResult>((api) async {
      final payload = await _buildBackupPayload();
      final bytes = utf8.encode(jsonEncode(payload));

      await _uploadBytesToDrive(api, bytes);

      final createdAt =
          DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
              DateTime.now().toUtc();
      final counts =
      Map<String, dynamic>.from(payload['counts'] as Map? ?? {});

      await _setLastBackupTimeLocal(createdAt);

      return CloudBackupResult(
        createdAt: createdAt,
        habits: (counts['habits'] as num?)?.toInt() ?? 0,
        notes: (counts['notes'] as num?)?.toInt() ?? 0,
        notifications: (counts['notifications'] as num?)?.toInt() ?? 0,
        studySessions: (counts['study_sessions'] as num?)?.toInt() ?? 0,
        studyRoutines: (counts['study_routines'] as num?)?.toInt() ?? 0,
        settingsKeys: (counts['settingsKeys'] as num?)?.toInt() ?? 0,
      );
    });
  }

  /// Downloads the latest backup file and merges its data with the local database.
  /// Skips items that already exist to prevent duplicates.
  Future<CloudRestoreResult> restoreFromCloudMergeOnDemand() async {
    return _withDriveApi<CloudRestoreResult>((api) async {
      final Map<String, dynamic> decoded = await _downloadAndDecodeBackup(api);

      final schema = (decoded['schemaVersion'] as num?)?.toInt() ?? 0;
      if (schema != _schemaVersion) {
        throw CloudBackupException('Unsupported backup schema version: $schema');
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const CloudBackupException('Backup payload missing data.');
      }

      // Restore each data type
      final habitResult = await _restoreHabits(data['habits']);
      final noteResult = await _restoreNotes(data['notes']);
      final notifResult = await _restoreNotifications(data['notifications']);
      final sessionResult = await _restoreStudySessions(data['study_sessions']);
      final routineResult = await _restoreStudyRoutines(data['study_routines']);
      final settingsResult = await _restoreSettings(data['settings']);

      await _setLastRestoreTimeLocal(DateTime.now().toUtc());

      return CloudRestoreResult(
        habitsImported: habitResult['imported'] ?? 0,
        habitsSkipped: habitResult['skipped'] ?? 0,
        notesImported: noteResult['imported'] ?? 0,
        notesSkipped: noteResult['skipped'] ?? 0,
        notificationsImported: notifResult['imported'] ?? 0,
        notificationsSkipped: notifResult['skipped'] ?? 0,
        studySessionsImported: sessionResult['imported'] ?? 0,
        studySessionsSkipped: sessionResult['skipped'] ?? 0,
        studyRoutinesImported: routineResult['imported'] ?? 0,
        studyRoutinesSkipped: routineResult['skipped'] ?? 0,
        settingsAdded: settingsResult['imported'] ?? 0,
        settingsSkipped: settingsResult['skipped'] ?? 0,
      );
    });
  }

  /// Checks for an existing backup file in the `appDataFolder` without downloading it.
  Future<CloudBackupInfo?> getExistingBackupInfoOnDemand() async {
    return _withDriveApi<CloudBackupInfo?>((api) async {
      final file = await _findBackupFileMeta(api);
      if (file == null) return null;

      final fileId = (file.id ?? '').trim();
      if (fileId.isEmpty) return null;

      final sizeBytes = file.size == null ? null : int.tryParse(file.size!);

      return CloudBackupInfo(
        fileId: fileId,
        name: (file.name ?? _backupFileName).trim().isEmpty
            ? _backupFileName
            : file.name!,
        modifiedTime: file.modifiedTime,
        sizeBytes: sizeBytes,
      );
    });
  }

  /// Checks if the Drive API is accessible with the current credentials.
  Future<void> verifyDriveAccessOnDemand() async {
    await _withDriveApi<void>((api) async {
      await api.about.get($fields: 'user(emailAddress)');
    });
  }

  // ─────────────────────────────────────────────
  // LOCAL CACHE FOR UI
  // ─────────────────────────────────────────────

  DateTime? getLastBackupTimeLocal() {
    try {
      final box = Hive.box(DatabaseService.settingsBox);
      final raw = box.get(_kLastCloudBackupAt, defaultValue: '');
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  DateTime? getLastRestoreTimeLocal() {
    try {
      final box = Hive.box(DatabaseService.settingsBox);
      final raw = box.get(_kLastCloudRestoreAt, defaultValue: '');
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  Future<void> _setLastBackupTimeLocal(DateTime timeUtc) async {
    try {
      final box = Hive.box(DatabaseService.settingsBox);
      await box.put(_kLastCloudBackupAt, timeUtc.toIso8601String());
    } catch (_) {}
  }

  Future<void> _setLastRestoreTimeLocal(DateTime timeUtc) async {
    try {
      final box = Hive.box(DatabaseService.settingsBox);
      await box.put(_kLastCloudRestoreAt, timeUtc.toIso8601String());
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // PRIVATE: CORE DRIVE OPERATIONS
  // ─────────────────────────────────────────────

  Future<drive.File?> _findBackupFileMeta(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_backupFileName' and trashed=false",
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime,size)',
    );
    return result.files?.firstOrNull;
  }

  Future<void> _uploadBytesToDrive(drive.DriveApi api, List<int> bytes) async {
    final existingFile = await _findBackupFileMeta(api);

    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    // FIXED BUG: Google Drive API throws an error if you pass `parents` when updating an existing file.
    // So we separate the metadata for Create and Update.
    if (existingFile?.id != null) {
      // Update existing file (NO parents field)
      final updateMetadata = drive.File()
        ..name = _backupFileName
        ..mimeType = 'application/json';

      await api.files.update(updateMetadata, existingFile!.id!, uploadMedia: media);
    } else {
      // Create new file (MUST include parents field)
      final createMetadata = drive.File()
        ..name = _backupFileName
        ..mimeType = 'application/json'
        ..parents = <String>['appDataFolder'];

      await api.files.create(createMetadata, uploadMedia: media);
    }
  }

  Future<Map<String, dynamic>> _downloadAndDecodeBackup(
      drive.DriveApi api) async {
    final fileMeta = await _findBackupFileMeta(api);
    if (fileMeta?.id == null) {
      throw const CloudBackupException('No cloud backup was found.');
    }

    final media = await api.files.get(
      fileMeta!.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      bytesBuilder.add(chunk);
    }
    final bytes = bytesBuilder.takeBytes();

    if (bytes.isEmpty) {
      throw const CloudBackupException('Backup file is empty.');
    }

    final jsonString = utf8.decode(bytes);
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw const CloudBackupException('Invalid backup format.');
    }
    return decoded;
  }

  // ─────────────────────────────────────────────
  // PRIVATE: PAYLOAD BUILDERS (BACKUP)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildBackupPayload() async {
    final now = DateTime.now().toUtc();
    final data = <String, dynamic>{
      'habits': _getHabitsForBackup(),
      'notes': _getNotesForBackup(),
      'notifications': _getNotificationsForBackup(),
      'study_sessions': _getStudySessionsForBackup(),
      'study_routines': _getStudyRoutinesForBackup(),
      'settings': _getSettingsForBackup(),
    };

    return <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'app': AppConfig.appName,
      'package': AppConfig.packageName,
      'version': AppConfig.version,
      'createdAt': now.toIso8601String(),
      'data': data,
      'counts': {
        'habits': (data['habits'] as List).length,
        'notes': (data['notes'] as List).length,
        'notifications': (data['notifications'] as List).length,
        'study_sessions': (data['study_sessions'] as List).length,
        'study_routines': (data['study_routines'] as List).length,
        'settingsKeys': (data['settings'] as Map).length,
      },
    };
  }

  List<Map<String, dynamic>> _getHabitsForBackup() =>
      DatabaseService.getAllHabits().map((h) => h.toJson()).toList();

  List<Map<String, dynamic>> _getNotesForBackup() =>
      NotesService.getAllNotes().map((n) => n.toJson()).toList();

  List<Map<String, dynamic>> _getNotificationsForBackup() {
    return DatabaseService.getAllNotifications().map((n) {
      return {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'receivedAt': n.receivedAt.toIso8601String(),
        'isRead': n.isRead,
        'type': n.type,
        'payload': n.payload,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getStudySessionsForBackup() {
    return DatabaseService.getAllStudySessions().map((s) {
      return {
        'id': s.id,
        'subjectName': s.subjectName,
        'subjectColorValue': s.subjectColorValue,
        'startTime': s.startTime.toIso8601String(),
        'endTime': s.endTime?.toIso8601String(),
        'durationMinutes': s.durationMinutes,
        'sessionType': s.sessionType,
        'completedAt': s.completedAt.toIso8601String(),
        'pomodoroCount': s.pomodoroCount,
        'isCompleted': s.isCompleted,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getStudyRoutinesForBackup() {
    return DatabaseService.getAllRoutines().map((r) {
      return {
        'id': r.id,
        'name': r.name,
        'createdAt': r.createdAt.toIso8601String(),
        'isActive': r.isActive,
        'totalDurationMinutes': r.totalDurationMinutes,
        'description': r.description,
        'autoPlayEnabled': r.autoPlayEnabled,
        'ttsEnabled': r.ttsEnabled,
        'timesCompleted': r.timesCompleted,
        'lastPlayedAt': r.lastPlayedAt?.toIso8601String(),
        'emoji': r.emoji,
        'colorValue': r.colorValue,
        'sessions': r.sessions.map((rs) {
          return {
            'subjectName': rs.subjectName,
            'subjectColorValue': rs.subjectColorValue,
            'durationMinutes': rs.durationMinutes,
            'includeBreak': rs.includeBreak,
            'breakDurationMinutes': rs.breakDurationMinutes,
            'customMessage': rs.customMessage,
            'order': rs.order,
            'emoji': rs.emoji,
          };
        }).toList(),
      };
    }).toList();
  }

  Map<String, dynamic> _getSettingsForBackup() {
    final settingsBox = Hive.box(DatabaseService.settingsBox);
    final rawSettings = settingsBox.toMap();
    final safeSettings = <String, dynamic>{};
    for (final entry in rawSettings.entries) {
      safeSettings[entry.key.toString()] = _jsonSafe(entry.value);
    }
    return safeSettings;
  }

  // ─────────────────────────────────────────────
  // PRIVATE: DATA MERGERS (RESTORE)
  // ─────────────────────────────────────────────

  Future<Map<String, int>> _restoreHabits(dynamic rawData) async {
    if (rawData is! List) return {'imported': 0, 'skipped': 0};
    int imported = 0, skipped = 0;
    final existingIds = DatabaseService.getAllHabits().map((h) => h.id).toSet();

    for (final item in rawData) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String?;
        if (id == null || id.isEmpty || existingIds.contains(id)) {
          skipped++;
          continue;
        }
        await DatabaseService.addHabit(Habit.fromJson(map));
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint('Drive restore: Habit skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>> _restoreNotes(dynamic rawData) async {
    if (rawData is! List) return {'imported': 0, 'skipped': 0};
    int imported = 0, skipped = 0;
    final notesBox = Hive.box<Note>('notes');

    for (final item in rawData) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String?;
        if (id == null || id.isEmpty || NotesService.getNoteById(id) != null) {
          skipped++;
          continue;
        }
        await notesBox.put(id, Note.fromJson(map));
        imported++;
      } catch (e) {
        skipped++;
        debugPrint('Drive restore: Note skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>> _restoreNotifications(dynamic rawData) async {
    if (rawData is! List) return {'imported': 0, 'skipped': 0};
    int imported = 0, skipped = 0;
    final notifBox = Hive.box<AppNotification>(DatabaseService.notificationsBox);
    final existingIds =
    DatabaseService.getAllNotifications().map((n) => n.id).toSet();

    for (final item in rawData) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String?;
        if (id == null || id.isEmpty || existingIds.contains(id)) {
          skipped++;
          continue;
        }
        final n = AppNotification(
          id: id,
          title: (map['title'] as String?) ?? '',
          body: (map['body'] as String?) ?? '',
          receivedAt: DateTime.tryParse(map['receivedAt'] as String? ?? '') ?? DateTime.now(),
          isRead: (map['isRead'] as bool?) ?? false,
          type: (map['type'] as String?) ?? 'local',
          payload: map['payload'] as String?,
        );
        await notifBox.put(id, n);
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint('Drive restore: Notification skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>> _restoreStudySessions(dynamic rawData) async {
    if (rawData is! List) return {'imported': 0, 'skipped': 0};
    int imported = 0, skipped = 0;
    final box = Hive.box<StudySession>(DatabaseService.studySessionsBox);
    final existingIds =
    DatabaseService.getAllStudySessions().map((s) => s.id).toSet();

    for (final item in rawData) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String?;
        if (id == null || id.isEmpty || existingIds.contains(id)) {
          skipped++;
          continue;
        }
        final s = StudySession(
          id: id,
          subjectName: (map['subjectName'] as String?) ?? 'Other',
          subjectColorValue: (map['subjectColorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
          startTime: DateTime.tryParse(map['startTime'] as String? ?? '') ?? DateTime.now(),
          endTime: map['endTime'] == null ? null : DateTime.tryParse(map['endTime'] as String),
          durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
          sessionType: (map['sessionType'] as String?) ?? 'focus',
          completedAt: DateTime.tryParse(map['completedAt'] as String? ?? '') ?? DateTime.now(),
          pomodoroCount: (map['pomodoroCount'] as num?)?.toInt() ?? 0,
          isCompleted: (map['isCompleted'] as bool?) ?? true,
        );
        await box.put(id, s);
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint('Drive restore: StudySession skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>> _restoreStudyRoutines(dynamic rawData) async {
    if (rawData is! List) return {'imported': 0, 'skipped': 0};
    int imported = 0, skipped = 0;
    final box = Hive.box<StudyRoutine>(DatabaseService.routinesBox);
    final existingIds =
    DatabaseService.getAllRoutines().map((r) => r.id).toSet();

    for (final item in rawData) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String?;
        if (id == null || id.isEmpty || existingIds.contains(id)) {
          skipped++;
          continue;
        }

        final sessionsList = <RoutineSession>[];
        if (map['sessions'] is List) {
          for (final sItem in map['sessions']) {
            final sMap = Map<String, dynamic>.from(sItem as Map);
            sessionsList.add(RoutineSession(
              subjectName: (sMap['subjectName'] as String?) ?? 'Other',
              subjectColorValue: (sMap['subjectColorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
              durationMinutes: (sMap['durationMinutes'] as num?)?.toInt() ?? 25,
              includeBreak: (sMap['includeBreak'] as bool?) ?? true,
              breakDurationMinutes: (sMap['breakDurationMinutes'] as num?)?.toInt() ?? 5,
              customMessage: sMap['customMessage'] as String?,
              order: (sMap['order'] as num?)?.toInt() ?? 0,
              emoji: (sMap['emoji'] as String?) ?? '📖',
            ));
          }
        }

        final routine = StudyRoutine(
          id: id,
          name: (map['name'] as String?) ?? 'Routine',
          sessions: sessionsList,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
          isActive: (map['isActive'] as bool?) ?? false,
          totalDurationMinutes: (map['totalDurationMinutes'] as num?)?.toInt() ?? 0,
          description: map['description'] as String?,
          autoPlayEnabled: (map['autoPlayEnabled'] as bool?) ?? true,
          ttsEnabled: (map['ttsEnabled'] as bool?) ?? true,
          timesCompleted: (map['timesCompleted'] as num?)?.toInt() ?? 0,
          lastPlayedAt: map['lastPlayedAt'] == null ? null : DateTime.tryParse(map['lastPlayedAt'] as String),
          emoji: (map['emoji'] as String?) ?? '📚',
          colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
        );
        await box.put(id, routine);
        existingIds.add(id);
        imported++;
      } catch (e) {
        skipped++;
        debugPrint('Drive restore: StudyRoutine skipped: $e');
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>> _restoreSettings(dynamic rawData) async {
    if (rawData is! Map) return {'imported': 0, 'skipped': 0};
    int imported = 0, skipped = 0;

    final isFirstInstall = DatabaseService.isFirstLaunch();
    final settingsBox = Hive.box(DatabaseService.settingsBox);

    for (final entry in rawData.entries) {
      final key = entry.key.toString();

      if (_isSensitiveSettingKey(key)) {
        skipped++;
        continue;
      }

      final incomingValue = entry.value;
      final exists = settingsBox.containsKey(key);

      if (!exists) {
        try {
          await settingsBox.put(key, incomingValue);
          imported++;
        } catch (e) {
          skipped++;
          debugPrint('Drive restore: Setting key skipped ($key): $e');
        }
        continue;
      }

      if (isFirstInstall && _shouldOverwriteSettingOnFirstInstall(key)) {
        try {
          await settingsBox.put(key, incomingValue);
          imported++;
        } catch (e) {
          skipped++;
          debugPrint('Drive restore: Setting overwrite skipped ($key): $e');
        }
        continue;
      }

      skipped++;
    }
    return {'imported': imported, 'skipped': skipped};
  }

  // ─────────────────────────────────────────────
  // PRIVATE: AUTH & API WRAPPER
  // ─────────────────────────────────────────────

  Future<T> _withDriveApi<T>(
      Future<T> Function(drive.DriveApi api) action, {
        bool didRetry401 = false,
        bool didRepairScope = false,
      }) async {
    http.BaseClient? client;

    try {
      client = await _authService.getAuthenticatedClient(
        interactive: true,
        forceConsent: didRepairScope,
        forceRefresh: didRetry401 || didRepairScope,
      );

      final api = drive.DriveApi(client);
      return await action(api);
    } catch (e) {
      if (e is CloudBackupException) rethrow;

      final status = _tryReadStatusCode(e);

      if (status == 401 && !didRetry401) {
        try { client?.close(); } catch (_) {}
        return _withDriveApi<T>(action, didRetry401: true, didRepairScope: didRepairScope);
      }

      if (_looksLikeInsufficientPermissions(e) && !didRepairScope) {
        try { client?.close(); } catch (_) {}
        return _withDriveApi<T>(action, didRetry401: didRetry401, didRepairScope: true);
      }

      throw _mapDriveError(e);
    } finally {
      try { client?.close(); } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE: ERROR MAPPING & UTILITIES
  // ─────────────────────────────────────────────

  bool _isSensitiveSettingKey(String key) {
    const sensitiveKeys = {
      'is_pro', 'purchased_plan',
      'is_vip', 'vip_email', 'vip_expiry', 'vip_device_id',
      'interstitial_counter', 'session_interstitial_count',
      'last_interstitial_time', 'rewarded_extra_habits',
      'leaderboard_last_uid',
    };
    return sensitiveKeys.contains(key);
  }

  bool _shouldOverwriteSettingOnFirstInstall(String key) {
    if (_isSensitiveSettingKey(key)) return false;
    const safeKeys = {
      'first_launch', 'user_name', 'user_avatar', 'user_goal_type',
      'theme_mode', 'language_code', 'dynamic_translation_enabled',
      'sound_effects_enabled', 'tts_enabled', 'notifications_enabled',
      'keep_screen_on', 'vibrate_on_complete', 'auto_reset_hour',
      'auto_reset_minute', 'last_known_level', 'starter_goals_applied',
      'custom_categories', 'custom_study_subjects', 'pomodoro_focus_mins',
      'pomodoro_short_break_mins', 'pomodoro_long_break_mins',
      'pomodoro_tts_enabled', 'auto_play_enabled', 'detected_country_code',
    };
    if (safeKeys.contains(key)) return true;
    if (key.startsWith('routine_unlock_expiry_')) return true;
    return false;
  }

  static dynamic _jsonSafe(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool || value is String) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is List) return value.map((e) => _jsonSafe(e)).toList();
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        out[entry.key.toString()] = _jsonSafe(entry.value);
      }
      return out;
    }
    return value.toString();
  }

  int? _tryReadStatusCode(Object e) {
    final dynamic d = e;
    try {
      if (d.status is int) return d.status;
    } catch (_) {}
    final s = e.toString();
    final match = RegExp(r'\b(400|401|403|404|409|413|429|5\d\d)\b').firstMatch(s);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  String _tryReadApiMessage(Object e) {
    final dynamic d = e;
    try {
      if (d.message is String && d.message.trim().isNotEmpty) return d.message.trim();
    } catch (_) {}
    return e.toString();
  }

  List<String> _tryReadApiReasons(Object e) {
    final reasons = <String>[];
    final dynamic d = e;
    try {
      if (d.errors is List) {
        for (final it in d.errors) {
          try {
            final dynamic item = it;
            if (item.reason is String && item.reason.trim().isNotEmpty) {
              reasons.add(item.reason.trim());
            } else if (it is Map && it['reason'] is String) {
              reasons.add(it['reason']);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    final msg = _tryReadApiMessage(e).toLowerCase();
    const known = ['insufficientPermissions', 'accessNotConfigured', 'storageQuotaExceeded', 'dailyLimitExceeded', 'userRateLimitExceeded', 'rateLimitExceeded', 'appNotAuthorizedToUseDrive', 'forbidden'];
    for (final k in known) {
      if (msg.contains(k.toLowerCase())) reasons.add(k);
    }
    return reasons.map((e) => e.toLowerCase().trim()).toSet().toList();
  }

  bool _looksLikeDeveloperConfigError(Object e) => e.toString().toLowerCase().contains('apiexception: 10');

  bool _looksLikeInsufficientPermissions(Object e) {
    if (_tryReadStatusCode(e) != 403) return false;
    final reasons = _tryReadApiReasons(e);
    return reasons.contains('insufficientpermissions') || _tryReadApiMessage(e).toLowerCase().contains('insufficient permission');
  }

  bool _looksLikeStorageQuotaExceeded(Object e) {
    if (_tryReadStatusCode(e) != 403) return false;
    return _tryReadApiReasons(e).contains('storagequotaexceeded');
  }

  bool _looksLikeAccessNotConfigured(Object e) {
    if (_tryReadStatusCode(e) != 403) return false;
    return _tryReadApiReasons(e).contains('accessnotconfigured') || _tryReadApiMessage(e).toLowerCase().contains('api has not been used');
  }

  bool _looksLikeRateLimit(Object e) {
    if (_tryReadStatusCode(e) == 429) return true;
    final reasons = _tryReadApiReasons(e);
    return reasons.any((r) => r.contains('limitexceeded'));
  }

  CloudBackupException _mapDriveError(Object e) {
    if (e is CloudBackupException) return e;
    if (e is AuthServiceException) return CloudBackupException(e.message, cause: e);

    if (_looksLikeRateLimit(e)) return CloudBackupException('Too many requests. Please try again in a moment.', cause: e);
    if (_looksLikeAccessNotConfigured(e)) return CloudBackupException('Google Drive API is not enabled for this project.', cause: e);
    if (_looksLikeStorageQuotaExceeded(e)) return CloudBackupException('Google Drive storage is full. Free up space and try again.', cause: e);
    if (_looksLikeInsufficientPermissions(e)) return CloudBackupException('Google Drive permission was not granted.', cause: e);

    final status = _tryReadStatusCode(e);
    if (status == 401) return CloudBackupException('Your Google session has expired. Please sign in again.', cause: e);
    if (status == 404) return CloudBackupException('No cloud backup was found.', cause: e);

    if (e.toString().toLowerCase().contains('socketexception')) {
      return CloudBackupException('No internet connection. Please try again.', cause: e);
    }

    return CloudBackupException('A cloud storage error occurred.', cause: e);
  }
}