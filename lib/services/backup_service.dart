// lib/services/backup_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/habit_model.dart';
import 'auth_service.dart';
import 'badge_service.dart';
import 'database_service.dart';
import 'google_drive_service.dart';
import 'sound_service.dart';

class BackupService {
  // ═══════════════════════════════════════════════════════════
  // GOOGLE DRIVE BACKUP (CLOUD)
  // ═══════════════════════════════════════════════════════════

  /// Backup all data to Google Drive (with permission request)
  static Future<void> backupToGoogleDrive(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    NavigatorState? navigator;
    if (context.mounted) {
      navigator = Navigator.of(context, rootNavigator: true);
    }

    try {
      // Show loading dialog
      if (navigator?.context.mounted ?? false) {
        showDialog(
          context: navigator!.context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Backing up to Google Drive...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Perform backup
      final result = await backupToGoogleDriveSilently();

      // Close loading dialog
      if (navigator?.context.mounted ?? false) {
        navigator!.pop();
      }

      // Show success dialog
      if (context.mounted) {
        SoundService.playSuccess();
        _showCloudBackupSuccessDialog(context, result);
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (navigator?.context.mounted ?? false) {
        navigator!.pop();
      }

      // Show error
      final errorMessage = _extractCloudErrorMessage(
        e,
        fallback:
        'Backup failed. Please check your internet connection and try again.',
      );

      debugPrint('❌ Google Drive backup error: $e');

      if (context.mounted) {
        _showSnack(context, errorMessage, isError: true);
      }
    }
  }

  /// Restore data from Google Drive
  static Future<void> restoreFromGoogleDrive(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    NavigatorState? navigator;
    if (context.mounted) {
      navigator = Navigator.of(context, rootNavigator: true);
    }

    try {
      // Show loading dialog
      if (navigator?.context.mounted ?? false) {
        showDialog(
          context: navigator!.context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Restoring from Google Drive...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Perform restore
      final result = await restoreFromGoogleDriveSilently();

      // Close loading dialog
      if (navigator?.context.mounted ?? false) {
        navigator!.pop();
      }

      // Show success dialog
      if (context.mounted) {
        SoundService.playSuccess();
        _showCloudRestoreSuccessDialog(context, result);
      }
    } catch (e) {
      // Close loading dialog
      if (navigator?.context.mounted ?? false) {
        navigator!.pop();
      }

      // Show error
      final errorMessage = _extractCloudErrorMessage(
        e,
        fallback:
        'Restore failed. Please check your internet connection or backup file.',
      );

      debugPrint('❌ Google Drive restore error: $e');

      if (context.mounted) {
        _showSnack(context, errorMessage, isError: true);
      }
    }
  }

  /// Silent cloud backup for onboarding / background flows.
  /// No dialog or snackbar.
  static Future<CloudBackupResult> backupToGoogleDriveSilently() async {
    try {
      final driveService = GoogleDriveService();
      return await driveService.backupAllDataToCloudOnDemand();
    } catch (e) {
      debugPrint('❌ Silent Google Drive backup error: $e');
      rethrow;
    }
  }

  /// Silent cloud restore for onboarding / locked entry flow.
  /// No dialog or snackbar.
  static Future<CloudRestoreResult> restoreFromGoogleDriveSilently() async {
    try {
      final driveService = GoogleDriveService();
      final result = await driveService.restoreFromCloudMergeOnDemand();

      if (result.habitsImported > 0) {
        try {
          await BadgeService.checkAllBadges();
        } catch (badgeError) {
          debugPrint('⚠️ Badge recheck after silent restore failed: $badgeError');
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ Silent Google Drive restore error: $e');
      rethrow;
    }
  }

  /// Silent backup detection for onboarding / splash flows.
  /// No sign-in UI here unless underlying auth flow requires it.
  static Future<CloudBackupInfo?> getExistingGoogleDriveBackupInfo() async {
    try {
      final driveService = GoogleDriveService();
      return await driveService.getExistingBackupInfoOnDemand();
    } catch (e) {
      debugPrint('❌ Google Drive backup detection error: $e');
      rethrow;
    }
  }

  /// Returns true if a Google Drive backup exists for the current signed-in user.
  static Future<bool> hasExistingGoogleDriveBackup() async {
    try {
      final info = await getExistingGoogleDriveBackupInfo();
      return info != null;
    } catch (e) {
      debugPrint('❌ hasExistingGoogleDriveBackup error: $e');
      rethrow;
    }
  }

  /// Get last cloud backup time (local cache, no network call)
  static DateTime? getLastCloudBackupTime() {
    try {
      final driveService = GoogleDriveService();
      return driveService.getLastBackupTimeLocal();
    } catch (_) {
      return null;
    }
  }

  /// Get last cloud restore time (local cache, no network call)
  static DateTime? getLastCloudRestoreTime() {
    try {
      final driveService = GoogleDriveService();
      return driveService.getLastRestoreTimeLocal();
    } catch (_) {
      return null;
    }
  }

  static String getReadableCloudBackupTimestamp(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final local = dateTime.toLocal();
      final y = local.year.toString().padLeft(4, '0');
      final m = local.month.toString().padLeft(2, '0');
      final d = local.day.toString().padLeft(2, '0');
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$y-$m-$d  $hh:$mm';
    } catch (_) {
      return 'Unknown';
    }
  }

  static String getReadableCloudBackupInfo(CloudBackupInfo? info) {
    if (info == null) return 'No cloud backup found';

    try {
      final modified = info.modifiedTime == null
          ? null
          : getReadableCloudBackupTimestamp(info.modifiedTime);

      final sizeBytes = info.sizeBytes;
      String? sizeText;
      if (sizeBytes != null && sizeBytes > 0) {
        final kb = sizeBytes / 1024.0;
        if (kb < 1024) {
          sizeText = '${kb.toStringAsFixed(0)} KB';
        } else {
          sizeText = '${(kb / 1024.0).toStringAsFixed(1)} MB';
        }
      }

      final parts = <String>[
        'Backup found',
        if (modified != null && modified.isNotEmpty) modified,
        if (sizeText != null && sizeText.isNotEmpty) sizeText,
      ];

      return parts.join(' • ');
    } catch (_) {
      return 'Backup found';
    }
  }

  static String _extractCloudErrorMessage(
      Object e, {
        required String fallback,
      }) {
    if (e is CloudBackupException) {
      return e.message;
    }
    if (e is AuthServiceException) {
      return e.message;
    }

    final raw = e.toString();
    final cleaned = raw
        .replaceAll('CloudBackupException:', '')
        .replaceAll('AuthServiceException:', '')
        .trim();

    if (cleaned.isNotEmpty && cleaned != raw) {
      return cleaned;
    }

    return fallback;
  }

  // ─────────────────────────────────────────────
  // Success Dialogs
  // ─────────────────────────────────────────────

  static void _showCloudBackupSuccessDialog(
      BuildContext context,
      CloudBackupResult result,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                color: Colors.green,
                size: 52,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Backup Complete!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your data is safely stored in Google Drive.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                  isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _cloudStatRow('📋 Habits', '${result.habits}', Colors.blue, isDark),
                  const SizedBox(height: 8),
                  _cloudStatRow('📝 Notes', '${result.notes}', Colors.purple, isDark),
                  const SizedBox(height: 8),
                  _cloudStatRow(
                    '📚 Study Data',
                    '${result.studySessions + result.studyRoutines}',
                    Colors.orange,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _cloudStatRow(
                    '⚙️ Settings',
                    '${result.settingsKeys}',
                    Colors.teal,
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showCloudRestoreSuccessDialog(
      BuildContext context,
      CloudRestoreResult result,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_download_rounded,
                color: Colors.blue,
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Restore Complete!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                  isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _importStatRow(
                    '✅ Habits',
                    '${result.habitsImported} imported',
                    Colors.green,
                    isDark,
                  ),
                  if (result.habitsSkipped > 0) ...[
                    const SizedBox(height: 8),
                    _importStatRow(
                      '⏭️ Skipped',
                      '${result.habitsSkipped} (duplicates)',
                      Colors.orange,
                      isDark,
                    ),
                  ],
                  if (result.notesImported > 0) ...[
                    const SizedBox(height: 8),
                    _importStatRow(
                      '📝 Notes',
                      '${result.notesImported} restored',
                      Colors.purple,
                      isDark,
                    ),
                  ],
                  if (result.settingsAdded > 0) ...[
                    const SizedBox(height: 8),
                    _importStatRow(
                      '⚙️ Settings',
                      '${result.settingsAdded} restored',
                      Colors.teal,
                      isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _cloudStatRow(
      String label,
      String value,
      Color color,
      bool isDark,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOCAL EXPORT BACKUP (PHONE STORAGE)
  // ═══════════════════════════════════════════════════════════
  static Future<void> exportBackup(BuildContext context) async {
    try {
      final habits = DatabaseService.getAllHabits();
      if (habits.isEmpty) {
        _showSnack(context, 'No habits to export.', isError: true);
        return;
      }

      final List<Map<String, dynamic>> habitsJson =
      habits.map((h) => h.toJson()).toList();

      final notesBackupData = await DatabaseService.getNotesBackupData();

      final exportData = {
        'app': AppConfig.appName,
        'version': AppConfig.version,
        'exportDate': DateTime.now().toIso8601String(),
        'habitCount': habits.length,
        'habits': habitsJson,
        'notes': notesBackupData['notes'],
        'notesCount': notesBackupData['notesCount'],
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${AppConfig.backupFilePrefix}$timestamp${AppConfig.backupFileExtension}';

      if (!context.mounted) return;

      _showExportOptionsSheet(
        context: context,
        bytes: bytes,
        fileName: fileName,
        jsonString: jsonString,
        habitCount: habits.length,
      );
    } catch (e) {
      debugPrint('Export error: $e');
      if (context.mounted) {
        _showSnack(context, 'Export failed: $e', isError: true);
      }
    }
  }

  static void _showExportOptionsSheet({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    required String jsonString,
    required int habitCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.2),
                          Colors.teal.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.backup_rounded,
                      color: Colors.green,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Backup',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$habitCount habits ready to export',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildExportOption(
                icon: Icons.save_alt_rounded,
                color: Colors.blue,
                title: 'Save to Phone',
                subtitle: 'Choose a folder to save the backup file',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  _saveToDevice(context, bytes, fileName, habitCount);
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                icon: Icons.share_rounded,
                color: Colors.teal,
                title: 'Share File',
                subtitle: 'Send via WhatsApp, Gmail, Drive, etc.',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  _shareBackupFile(context, jsonString, fileName, habitCount);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildExportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(isDark ? 0.2 : 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _saveToDevice(
      BuildContext context,
      Uint8List bytes,
      String fileName,
      int habitCount,
      ) async {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${AppConfig.appName} Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (savedPath != null) {
        final file = File(savedPath);
        await file.writeAsBytes(bytes, flush: true);

        SoundService.playSuccess();
        if (context.mounted) {
          _showSaveSuccessDialog(context, savedPath, habitCount);
        }
      } else if (context.mounted) {
        _showSnack(context, 'Save cancelled');
      }
    } catch (e) {
      debugPrint('Save to device error: $e');
      if (context.mounted) {
        _showSnack(
          context,
          'Save failed. Try "Share File" instead.',
          isError: true,
        );
      }
    }
  }

  static Future<void> _shareBackupFile(
      BuildContext context,
      String jsonString,
      String fileName,
      int habitCount,
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
        text: '${AppConfig.appName} Backup ($habitCount habits)',
        subject: '${AppConfig.appName} Backup',
      );

      if (context.mounted && result.status == ShareResultStatus.success) {
        SoundService.playSuccess();
        _showSnack(context, 'Backup shared successfully.');
      }
    } catch (e) {
      debugPrint('Share error: $e');
      if (context.mounted) {
        _showSnack(context, 'Share failed: $e', isError: true);
      }
    }
  }

  static void _showSaveSuccessDialog(
      BuildContext context,
      String path,
      int habitCount,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String displayPath = path;
    if (path.contains('/storage/emulated/0/')) {
      displayPath =
          path.replaceFirst('/storage/emulated/0/', 'Internal Storage › ');
    }
    if (path.contains('Android/data/')) {
      final idx = path.indexOf('files/');
      if (idx != -1) {
        displayPath = 'App Files › ${path.substring(idx + 6)}';
      }
    }
    displayPath = displayPath.replaceAll('/', ' › ');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 52,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Backup Saved!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$habitCount habits exported successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                  isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        size: 16,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Saved to:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayPath,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOCAL IMPORT BACKUP
  // ═══════════════════════════════════════════════════════════
  static Future<void> importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (context.mounted) {
          _showSnack(context, 'No file selected');
        }
        return;
      }

      final pickedFile = result.files.first;
      String? jsonString;

      if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
        jsonString = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        final file = File(pickedFile.path!);
        if (await file.exists()) {
          jsonString = await file.readAsString();
        }
      }

      if (jsonString == null || jsonString.trim().isEmpty) {
        if (context.mounted) {
          _showSnack(context, 'File is empty or unreadable', isError: true);
        }
        return;
      }

      if (!pickedFile.name.endsWith('.json') &&
          !jsonString.trim().startsWith('{')) {
        if (context.mounted) {
          _showSnack(
            context,
            'Please select a valid JSON backup file',
            isError: true,
          );
        }
        return;
      }

      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> habitsJson = jsonData['habits'] ?? [];

      if (habitsJson.isEmpty) {
        if (context.mounted) {
          _showSnack(context, 'No habits found in backup file', isError: true);
        }
        return;
      }

      int imported = 0;
      int skipped = 0;

      final existingIds = DatabaseService.getAllHabits().map((h) => h.id).toSet();

      for (final item in habitsJson) {
        try {
          final map = Map<String, dynamic>.from(item);
          final id = map['id'] as String? ??
              DateTime.now().millisecondsSinceEpoch.toString();

          if (existingIds.contains(id)) {
            skipped++;
            continue;
          }

          final habit = Habit.fromJson(map);
          await DatabaseService.addHabit(habit);
          imported++;
        } catch (e) {
          debugPrint('Failed to import habit: $e');
          skipped++;
        }
      }

      int notesRestored = 0;
      if (jsonData.containsKey('notes')) {
        try {
          await DatabaseService.restoreNotesFromBackup(jsonData);
          final notesList = jsonData['notes'] as List? ?? [];
          notesRestored = notesList.length;
        } catch (e) {
          debugPrint('⚠️ Notes restore error: $e');
        }
      }

      if (imported > 0) {
        try {
          await BadgeService.checkAllBadges();
        } catch (_) {}
      }

      if (context.mounted) {
        SoundService.playSuccess();
        _showImportSuccessDialog(
          context,
          imported,
          skipped,
          habitsJson.length,
          notesRestored,
        );
      }
    } catch (e) {
      debugPrint('Import error: $e');
      if (context.mounted) {
        _showSnack(
          context,
          'Import failed: Invalid backup file format',
          isError: true,
        );
      }
    }
  }

  static void _showImportSuccessDialog(
      BuildContext context,
      int imported,
      int skipped,
      int total,
      int notesRestored,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                color: Colors.blue,
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Import Complete!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                  isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _importStatRow(
                    '✅ Imported',
                    '$imported habits',
                    Colors.green,
                    isDark,
                  ),
                  if (skipped > 0) ...[
                    const SizedBox(height: 8),
                    _importStatRow(
                      '⏭️ Skipped',
                      '$skipped (already exist)',
                      Colors.orange,
                      isDark,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _importStatRow(
                    '📦 Total in file',
                    '$total habits',
                    Colors.blue,
                    isDark,
                  ),
                  if (notesRestored > 0) ...[
                    const SizedBox(height: 8),
                    _importStatRow(
                      '📝 Notes',
                      '$notesRestored restored',
                      Colors.purple,
                      isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _importStatRow(
      String label,
      String value,
      Color color,
      bool isDark,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SHARE STATS
  // ═══════════════════════════════════════════════════════════
  static Future<void> shareStats(BuildContext context) async {
    try {
      final habits = DatabaseService.getAllHabits();
      final total = habits.length;
      final completedToday = habits.where((h) => h.isCompletedToday()).length;
      final totalCompleted = DatabaseService.getTotalHabitsCompleted();

      int bestStreak = 0;
      for (final h in habits) {
        if (h.bestStreak > bestStreak) bestStreak = h.bestStreak;
      }

      final stats = '''
📊 ${AppConfig.appName} - My Stats
━━━━━━━━━━━━━━━━━━━━━
📋 Total Habits: $total
✅ Completed Today: $completedToday/$total
🏆 Total Completions: $totalCompleted
🔥 Best Streak: $bestStreak days
━━━━━━━━━━━━━━━━━━━━━

${AppConfig.shareMessage}
''';

      await Share.share(stats);
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Share failed: $e', isError: true);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  static void _showSnack(
      BuildContext context,
      String message, {
        bool isError = false,
      }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppConfig.errorColor : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}