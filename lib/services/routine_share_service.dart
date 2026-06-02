// lib/services/routine_share_service.dart
//
// Social sharing/import system for Habits + Study Routines via a single file.
// IMPORTANT:
// - Import adds ONLY Habits + Study Routines.
// - Does NOT modify settings/notes/notifications.
// - Duplicate IDs are handled safely (no overwrite).
//
// UI text: English only.
// State mgmt: none (just helpers).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../models/study_routine_model.dart';
import 'database_service.dart';
import 'sound_service.dart';

class RoutinePackImportResult {
  final int habitsImported;
  final int habitsSkipped;

  final int routinesImported;
  final int routinesSkipped;

  const RoutinePackImportResult({
    required this.habitsImported,
    required this.habitsSkipped,
    required this.routinesImported,
    required this.routinesSkipped,
  });
}

class RoutineShareService {
  RoutineShareService._();

  static const int _schemaVersion = 1;
  static const String _packType = 'habitnode_routine_pack';

  static const Uuid _uuid = Uuid();

  // ─────────────────────────────────────────────
  // EXPORT
  // ─────────────────────────────────────────────

  static Future<void> exportRoutinePack(
      BuildContext context, {
        bool includeHabits = true,
        bool includeStudyRoutines = true,
      }) async {
    try {
      final habits = includeHabits ? DatabaseService.getAllHabits() : <Habit>[];
      final routines = includeStudyRoutines ? DatabaseService.getAllRoutines() : <StudyRoutine>[];

      if (habits.isEmpty && routines.isEmpty) {
        _showSnack(context, 'Nothing to export.', isError: true);
        return;
      }

      final now = DateTime.now().toUtc();
      final payload = <String, dynamic>{
        'type': _packType,
        'schemaVersion': _schemaVersion,
        'app': AppConfig.appName,
        'package': AppConfig.packageName,
        'version': AppConfig.version,
        'exportedAt': now.toIso8601String(),
        'data': <String, dynamic>{
          'habits': habits.map((h) => h.toJson()).toList(),
          'study_routines': routines.map(_encodeStudyRoutine).toList(),
        },
        'counts': <String, dynamic>{
          'habits': habits.length,
          'study_routines': routines.length,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'habitnode_routine_pack_$timestamp.json';

      if (!context.mounted) return;

      _showExportOptionsSheet(
        context: context,
        bytes: bytes,
        fileName: fileName,
        habitCount: habits.length,
        routineCount: routines.length,
        jsonString: jsonString,
      );
    } catch (e) {
      debugPrint('❌ Routine pack export error: $e');
      if (context.mounted) {
        _showSnack(context, 'Export failed. Please try again.', isError: true);
      }
    }
  }

  static void _showExportOptionsSheet({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    required int habitCount,
    required int routineCount,
    required String jsonString,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C2F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, -6),
              )
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppConfig.primaryColor.withOpacity(0.22),
                            AppConfig.primaryColor.withOpacity(0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.file_present_rounded, color: AppConfig.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Routine Pack',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$habitCount habits • $routineCount study routines',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _optionTile(
                  context: ctx,
                  isDark: isDark,
                  icon: Icons.save_alt_rounded,
                  color: AppConfig.infoColor,
                  title: 'Save to Phone',
                  subtitle: 'Save a file you can share later',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _saveToDevice(context, bytes, fileName);
                  },
                ),
                const SizedBox(height: 12),
                _optionTile(
                  context: ctx,
                  isDark: isDark,
                  icon: Icons.share_rounded,
                  color: const Color(0xFF06B6D4),
                  title: 'Share File',
                  subtitle: 'Send to your group (WhatsApp, Telegram, etc.)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareAsFile(context, jsonString, fileName);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _optionTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: () async {
        try {
          HapticFeedback.lightImpact();
          SoundService.playTap();
        } catch (_) {}
        await onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.22 : 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _saveToDevice(
      BuildContext context,
      Uint8List bytes,
      String fileName,
      ) async {
    try {
      String? savedPath;
      try {
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Routine Pack',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: bytes,
        );
      } catch (e) {
        debugPrint('⚠️ FilePicker.saveFile error: $e');
      }

      if (savedPath != null && savedPath.trim().isNotEmpty) {
        // Best-effort manual write for non-SAF paths
        try {
          final f = File(savedPath);
          if (await f.exists()) {
            final len = await f.length();
            if (len == 0) {
              await f.writeAsBytes(bytes, flush: true);
            }
          }
        } catch (_) {}

        try {
          HapticFeedback.mediumImpact();
          SoundService.playSuccess();
        } catch (_) {}

        if (context.mounted) {
          _showSnack(context, 'Saved: $fileName');
        }
        return;
      }

      if (context.mounted) {
        _showSnack(context, 'Save cancelled');
      }
    } catch (e) {
      debugPrint('❌ Save routine pack error: $e');
      if (context.mounted) {
        _showSnack(context, 'Save failed. Try "Share File" instead.', isError: true);
      }
    }
  }

  static Future<void> _shareAsFile(
      BuildContext context,
      String jsonString,
      String fileName,
      ) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonString, flush: true);

      final xFile = XFile(
        file.path,
        mimeType: 'application/json',
        name: fileName,
      );

      final result = await Share.shareXFiles(
        [xFile],
        text: '${AppConfig.appName} Routine Pack',
        subject: '${AppConfig.appName} Routine Pack',
      );

      if (context.mounted && result.status == ShareResultStatus.success) {
        try {
          HapticFeedback.mediumImpact();
          SoundService.playSuccess();
        } catch (_) {}
        _showSnack(context, 'Shared successfully.');
      }
    } catch (e) {
      debugPrint('❌ Share routine pack error: $e');
      if (context.mounted) {
        _showSnack(context, 'Share failed. Please try again.', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────────
  // IMPORT (FIXED: FileType.any + manual validation)
  // ─────────────────────────────────────────────

  static Future<void> importRoutinePack(BuildContext context) async {
    try {
      HapticFeedback.lightImpact();

      // CRITICAL FIX: Use FileType.any to show all files (Android compatibility)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // ✅ Changed from FileType.custom
        withData: true,
        allowMultiple: false,
        dialogTitle: 'Select Routine Pack JSON',
      );

      if (result == null || result.files.isEmpty) {
        if (context.mounted) {
          _showSnack(context, 'No file selected');
        }
        return;
      }

      final picked = result.files.first;

      // Validate file extension manually
      final fileName = picked.name.toLowerCase();
      if (!fileName.endsWith('.json')) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            title: 'Invalid File Type',
            message: 'Please select a JSON file.\n\nSelected: ${picked.name}',
          );
        }
        return;
      }

      String? jsonString;

      // Try bytes first (more reliable)
      if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        try {
          jsonString = utf8.decode(picked.bytes!);
        } catch (e) {
          debugPrint('⚠️ UTF-8 decode error: $e');
        }
      }

      // Fallback to path
      if ((jsonString == null || jsonString.trim().isEmpty) &&
          picked.path != null &&
          picked.path!.trim().isNotEmpty) {
        try {
          final f = File(picked.path!);
          if (await f.exists()) {
            jsonString = await f.readAsString();
          }
        } catch (e) {
          debugPrint('⚠️ File read error: $e');
        }
      }

      if (jsonString == null || jsonString.trim().isEmpty) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            title: 'Empty File',
            message: 'The selected file is empty or unreadable.\n\nPlease select a valid routine pack.',
          );
        }
        return;
      }

      // Parse JSON
      dynamic decoded;
      try {
        decoded = jsonDecode(jsonString);
      } catch (e) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            title: 'Invalid JSON',
            message: 'The file is not a valid JSON file.\n\nError: ${e.toString()}',
          );
        }
        return;
      }

      if (decoded is! Map<String, dynamic>) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            title: 'Invalid Format',
            message: 'The file does not contain a valid routine pack.',
          );
        }
        return;
      }

      // Validate pack type and schema
      final type = (decoded['type'] as String?) ?? '';
      final schema = (decoded['schemaVersion'] as num?)?.toInt() ?? 0;

      if (type != _packType) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            title: 'Not a Routine Pack',
            message:
            'This file is not a HabitNode routine pack.\n\nExpected type: $_packType\nFound: $type',
          );
        }
        return;
      }

      if (schema != _schemaVersion) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            title: 'Unsupported Version',
            message:
            'This routine pack was created with a different app version.\n\nSupported version: $_schemaVersion\nFile version: $schema',
          );
        }
        return;
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            title: 'Missing Data',
            message: 'The routine pack is missing data.',
          );
        }
        return;
      }

      final habitsRaw = data['habits'];
      final routinesRaw = data['study_routines'];

      final existingHabitIds = DatabaseService.getAllHabits().map((h) => h.id).toSet();
      final existingRoutineIds = DatabaseService.getAllRoutines().map((r) => r.id).toSet();

      int habitsImported = 0;
      int habitsSkipped = 0;
      int routinesImported = 0;
      int routinesSkipped = 0;

      // Import Habits
      if (habitsRaw is List) {
        for (final item in habitsRaw) {
          try {
            final map = Map<String, dynamic>.from(item as Map);
            final originalId = (map['id'] as String?)?.trim();
            final safeId = (originalId == null || originalId.isEmpty) ? _uuid.v4() : originalId;

            // No overwrite: if exists, generate new id
            final newId = existingHabitIds.contains(safeId) ? _uuid.v4() : safeId;
            map['id'] = newId;

            // If createdAt is missing or invalid, set now
            final createdAtRaw = map['createdAt'];
            if (createdAtRaw == null) {
              map['createdAt'] = DateTime.now().toIso8601String();
            }

            final habit = Habit.fromJson(map);
            await DatabaseService.addHabit(habit);
            existingHabitIds.add(habit.id);
            habitsImported++;
          } catch (e) {
            habitsSkipped++;
            debugPrint('⚠️ Habit import skipped: $e');
          }
        }
      }

      // Import Study Routines
      if (routinesRaw is List) {
        for (final item in routinesRaw) {
          try {
            final map = Map<String, dynamic>.from(item as Map);

            final rawId = (map['id'] as String?)?.trim();
            final safeId = (rawId == null || rawId.isEmpty) ? _uuid.v4() : rawId;
            final newId = existingRoutineIds.contains(safeId) ? _uuid.v4() : safeId;

            map['id'] = newId;

            final routine = _decodeStudyRoutine(map);
            await DatabaseService.saveRoutine(routine);
            existingRoutineIds.add(routine.id);
            routinesImported++;
          } catch (e) {
            routinesSkipped++;
            debugPrint('⚠️ Study routine import skipped: $e');
          }
        }
      }

      final importResult = RoutinePackImportResult(
        habitsImported: habitsImported,
        habitsSkipped: habitsSkipped,
        routinesImported: routinesImported,
        routinesSkipped: routinesSkipped,
      );

      if (!context.mounted) return;

      try {
        HapticFeedback.heavyImpact();
        SoundService.playSuccess();
      } catch (_) {}

      await _showImportResultDialog(context, importResult);
    } catch (e) {
      debugPrint('❌ Routine pack import error: $e');
      if (context.mounted) {
        await _showErrorDialog(
          context: context,
          title: 'Import Failed',
          message: 'An unexpected error occurred.\n\n${e.toString()}',
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // PREMIUM ERROR DIALOG
  // ─────────────────────────────────────────────

  static Future<void> _showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.mediumImpact();

    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppConfig.errorColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppConfig.errorColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // IMPORT RESULT DIALOG
  // ─────────────────────────────────────────────

  static Future<void> _showImportResultDialog(
      BuildContext context,
      RoutinePackImportResult r,
      ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConfig.successColor.withOpacity(0.85),
                    AppConfig.successColor.withOpacity(0.65),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Import Complete',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _resultRow(
                    isDark: isDark,
                    label: 'Habits imported',
                    value: '${r.habitsImported}',
                    color: AppConfig.successColor,
                  ),
                  const SizedBox(height: 10),
                  _resultRow(
                    isDark: isDark,
                    label: 'Habits skipped',
                    value: '${r.habitsSkipped}',
                    color: AppConfig.warningColor,
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 16),
                  _resultRow(
                    isDark: isDark,
                    label: 'Study routines imported',
                    value: '${r.routinesImported}',
                    color: AppConfig.successColor,
                  ),
                  const SizedBox(height: 10),
                  _resultRow(
                    isDark: isDark,
                    label: 'Study routines skipped',
                    value: '${r.routinesSkipped}',
                    color: AppConfig.warningColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConfig.infoColor.withOpacity(isDark ? 0.10 : 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppConfig.infoColor.withOpacity(isDark ? 0.20 : 0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppConfig.infoColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only habits and study routines were imported. Your settings and other data were not changed.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _resultRow({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.25),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SERIALIZATION: StudyRoutine
  // ─────────────────────────────────────────────

  static Map<String, dynamic> _encodeStudyRoutine(StudyRoutine r) {
    return <String, dynamic>{
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
      'sessions': r.sessions
          .map(
            (s) => <String, dynamic>{
          'subjectName': s.subjectName,
          'subjectColorValue': s.subjectColorValue,
          'durationMinutes': s.durationMinutes,
          'includeBreak': s.includeBreak,
          'breakDurationMinutes': s.breakDurationMinutes,
          'customMessage': s.customMessage,
          'order': s.order,
          'emoji': s.emoji,
        },
      )
          .toList(),
    };
  }

  static StudyRoutine _decodeStudyRoutine(Map<String, dynamic> map) {
    final sessionsList = <RoutineSession>[];

    final rawSessions = map['sessions'];
    if (rawSessions is List) {
      for (final item in rawSessions) {
        try {
          final sMap = Map<String, dynamic>.from(item as Map);
          sessionsList.add(
            RoutineSession(
              subjectName: (sMap['subjectName'] as String?) ?? 'Other',
              subjectColorValue: (sMap['subjectColorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
              durationMinutes: (sMap['durationMinutes'] as num?)?.toInt() ?? 25,
              includeBreak: (sMap['includeBreak'] as bool?) ?? true,
              breakDurationMinutes: (sMap['breakDurationMinutes'] as num?)?.toInt() ?? 5,
              customMessage: sMap['customMessage'] as String?,
              order: (sMap['order'] as num?)?.toInt() ?? 0,
              emoji: (sMap['emoji'] as String?) ?? '📖',
            ),
          );
        } catch (e) {
          debugPrint('⚠️ RoutineSession decode skipped: $e');
        }
      }
    }

    final id = (map['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('Routine id missing');
    }

    final createdAt = DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now();

    return StudyRoutine(
      id: id,
      name: (map['name'] as String?) ?? 'Routine',
      sessions: sessionsList,
      createdAt: createdAt,
      isActive: (map['isActive'] as bool?) ?? false,
      totalDurationMinutes: (map['totalDurationMinutes'] as num?)?.toInt() ?? 0,
      description: map['description'] as String?,
      autoPlayEnabled: (map['autoPlayEnabled'] as bool?) ?? true,
      ttsEnabled: (map['ttsEnabled'] as bool?) ?? true,
      timesCompleted: (map['timesCompleted'] as num?)?.toInt() ?? 0,
      lastPlayedAt: map['lastPlayedAt'] == null
          ? null
          : DateTime.tryParse(map['lastPlayedAt'] as String),
      emoji: (map['emoji'] as String?) ?? '📚',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
    );
  }

  // ─────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────

  static void _showSnack(
      BuildContext context,
      String message, {
        bool isError = false,
      }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppConfig.errorColor : null,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}