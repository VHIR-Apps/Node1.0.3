// lib/services/auto_backup_trigger.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'database_service.dart';
import 'google_drive_service.dart';

/// 🚀 Auto Backup Trigger - Smart Debouncing Controller
///
/// যেকোনো data change হলে এটা automatically backup trigger করে।
///
/// Features:
/// - Debouncing (একসাথে অনেক change → একবার backup)
/// - Sign-in check
/// - WiFi check
/// - Pending queue (offline support)
/// - Minimum interval protection
class AutoBackupTrigger {
  AutoBackupTrigger._();

  static Timer? _debounceTimer;
  static bool _isBackupRunning = false;
  static String? _lastTriggerReason;
  static int _pendingChangeCount = 0;

  /// একসাথে অনেক change এলে wait করে
  static const Duration _debounceDuration = Duration(seconds: 8);

  /// দুটো backup-এর মাঝে minimum gap
  static const Duration _minBackupInterval = Duration(minutes: 1);

  // ════════════════════════════════════════════════════════
  // 🎯 PUBLIC API
  // ════════════════════════════════════════════════════════

  /// যেকোনো data change হলে এটা call করুন
  static void notifyChange(String reason) {
    _pendingChangeCount++;
    _lastTriggerReason = reason;

    if (kDebugMode) {
      debugPrint(
          '📝 Backup trigger: $reason (pending: $_pendingChangeCount)');
    }

    if (!DatabaseService.isAutoBackupEnabled()) return;

    final frequency = DatabaseService.getAutoBackupFrequency();

    // 'on_exit' frequency → শুধু exit-এ trigger হবে
    if (frequency == 'on_exit') return;

    // 'every_change' এ instant debounced backup
    if (frequency == 'every_change') {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceDuration, () {
        _performBackupSafely();
      });
      return;
    }

    // hourly/daily/weekly → handled by interval logic separately
  }

  /// App exit হলে call করুন
  static Future<void> backupOnExit() async {
    if (!DatabaseService.isAutoBackupEnabled()) return;

    final frequency = DatabaseService.getAutoBackupFrequency();
    if (frequency != 'on_exit' && frequency != 'every_change') return;

    _debounceTimer?.cancel();
    await _performBackupSafely();
  }

  /// App resume হলে pending check করুন
  static Future<void> checkPendingBackup() async {
    if (!DatabaseService.hasPendingBackup()) return;
    if (!DatabaseService.isAutoBackupEnabled()) return;

    debugPrint('🔄 Found pending backup, attempting now...');
    await _performBackupSafely();
  }

  /// Force backup এখনই (settings থেকে call করতে পারেন)
  static Future<bool> forceBackupNow() async {
    _debounceTimer?.cancel();
    return await _performBackupSafely(force: true);
  }

  /// Cleanup
  static void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isBackupRunning = false;
    _pendingChangeCount = 0;
  }

  // ════════════════════════════════════════════════════════
  // 🔒 PRIVATE METHODS
  // ════════════════════════════════════════════════════════

  static Future<bool> _performBackupSafely({bool force = false}) async {
    if (_isBackupRunning) {
      debugPrint('⏸️ Backup already running, skipping');
      return false;
    }

    try {
      // ✅ Sign-in check
      final user = AuthService.instance.currentUser;
      if (user == null) {
        debugPrint('⏸️ Backup skipped: not signed in');
        await DatabaseService.setPendingBackup(true);
        return false;
      }

      // ✅ Minimum interval check
      if (!force) {
        final lastBackupMs = DatabaseService.getLastAutoBackupTime();
        if (lastBackupMs > 0) {
          final timeSince =
              DateTime.now().millisecondsSinceEpoch - lastBackupMs;
          if (timeSince < _minBackupInterval.inMilliseconds) {
            debugPrint(
                '⏸️ Backup skipped: too soon (${timeSince ~/ 1000}s ago)');
            return false;
          }
        }
      }

      // ✅ WiFi check (only Android)
      if (DatabaseService.isAutoBackupWifiOnly() && Platform.isAndroid) {
        final hasNet = await _hasInternet();
        if (!hasNet) {
          debugPrint('⏸️ Backup skipped: no internet');
          await DatabaseService.setPendingBackup(true);
          return false;
        }
      }

      // ✅ Execute backup
      _isBackupRunning = true;
      debugPrint('🚀 Auto backup starting '
          '(reason: $_lastTriggerReason, changes: $_pendingChangeCount)');

      final driveService = GoogleDriveService();
      final result = await driveService.backupAllDataToCloudOnDemand();

      await DatabaseService.setLastAutoBackupTime(
          DateTime.now().millisecondsSinceEpoch);
      await DatabaseService.setPendingBackup(false);

      debugPrint('✅ Auto backup complete: '
          '${result.habits} habits, '
          '${result.notes} notes, '
          '${result.studySessions} sessions, '
          '${result.settingsKeys} settings');

      _pendingChangeCount = 0;
      return true;
    } catch (e) {
      debugPrint('❌ Auto backup failed: $e');
      await DatabaseService.setPendingBackup(true);
      return false;
    } finally {
      _isBackupRunning = false;
    }
  }

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}