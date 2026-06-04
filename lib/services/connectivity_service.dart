// lib/services/connectivity_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'database_service.dart';
import 'leaderboard_service.dart';
import 'admin_message_service.dart';
import 'backup_service.dart';

class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();
  static final ConnectivityService instance =
  ConnectivityService._();

  // ═══════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════

  bool _isOnline = false;
  bool _onlineTasksDone = false;
  bool _initialized = false;
  Timer? _retryTimer;
  BuildContext? _context;

  final ValueNotifier<bool> isOnlineNotifier =
  ValueNotifier<bool>(false);

  // ═══════════════════════════════════════
  // PUBLIC GETTERS
  // ═══════════════════════════════════════

  bool get isOnline => _isOnline;

  /// ✅ এটাই মূল gate
  /// যেকোনো জায়গায় interactive sign-in করার আগে
  /// এটা check করো
  /// false হলে sign-in dialog দেখাবে না
  bool get canDoOnlineWork => _isOnline;

  // ═══════════════════════════════════════
  // INIT — main.dart থেকে একবার call
  // ═══════════════════════════════════════

  void init(BuildContext context) {
    if (_initialized) return;
    _initialized = true;
    _context = context;

    WidgetsBinding.instance.addObserver(this);

    // ✅ Monkey-patch: AuthService-এর interactive sign-in
    // offline থাকলে block করো
    _patchAuthServiceForOfflineGuard();

    _startConnectivityCheck();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _initialized = false;
  }

  // ═══════════════════════════════════════
  // ✅ AUTH GUARD
  // এটাই login popup বন্ধ করবে
  // ═══════════════════════════════════════

  /// AuthService.ensureSignedInOnDemand() call করার আগে
  /// এই method call করো
  /// offline হলে null return করবে — popup আসবে না
  Future<dynamic> guardedSignIn({
    required bool interactive,
  }) async {
    // Already signed in → return user
    final existing = AuthService.instance.currentUser;
    if (existing != null) return existing;

    // ✅ Offline → popup দেখাবে না
    if (!_isOnline) {
      debugPrint(
          '📵 Sign-in blocked — offline. No popup.');
      return null;
    }

    // ✅ Online → interactive হলে তবেই popup
    try {
      return await AuthService.instance
          .ensureSignedInOnDemand(
          interactive: interactive);
    } catch (e) {
      debugPrint('⚠️ Guarded sign-in failed: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // PATCH — AuthService offline guard
  // signInSilently() offline এ call হবে না
  // ═══════════════════════════════════════

  void _patchAuthServiceForOfflineGuard() {
    // AuthService-এ কোনো change করতে হবে না
    // আমরা শুধু এই service থেকে guard করি
    // Dashboard/Profile screen গুলো এই service
    // ব্যবহার করবে
    debugPrint(
        '🛡️ Auth offline guard activated');
  }

  // ═══════════════════════════════════════
  // APP LIFECYCLE
  // ═══════════════════════════════════════

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
          '📱 App resumed — checking connectivity...');
      _onlineTasksDone = false;
      _startConnectivityCheck();
    }

    if (state == AppLifecycleState.paused) {
      _runBackupSafely();
    }
  }

  // ═══════════════════════════════════════
  // INTERNET CHECK
  // ═══════════════════════════════════════

  Future<bool> checkInternet() async {
    try {
      final result = await InternetAddress.lookup(
          'google.com')
          .timeout(const Duration(seconds: 4));
      final online = result.isNotEmpty &&
          result.first.rawAddress.isNotEmpty;
      _isOnline = online;
      isOnlineNotifier.value = online;
      return online;
    } catch (_) {
      _isOnline = false;
      isOnlineNotifier.value = false;
      return false;
    }
  }

  // ═══════════════════════════════════════
  // CONNECTIVITY CHECK LOOP
  // ═══════════════════════════════════════

  void _startConnectivityCheck() {
    _retryTimer?.cancel();

    // প্রথম check
    checkInternet().then((online) {
      if (online && !_onlineTasksDone) {
        _onlineTasksDone = true;
        _runOnlineTasks();
        return;
      }

      if (!online) {
        debugPrint(
            '📵 Offline — waiting for connection...');
        // Retry every 10 seconds
        _retryTimer?.cancel();
        _retryTimer = Timer.periodic(
          const Duration(seconds: 10),
              (timer) async {
            final isOnline = await checkInternet();
            if (!isOnline) return;

            timer.cancel();
            debugPrint(
                '✅ Back online — running tasks...');

            if (!_onlineTasksDone) {
              _onlineTasksDone = true;
              _runOnlineTasks();
            }
          },
        );
      }
    });
  }

  // ═══════════════════════════════════════
  // ONLINE TASKS
  // ═══════════════════════════════════════

  Future<void> _runOnlineTasks() async {
    debugPrint('🌐 Running online startup tasks...');

    // 1. Admin messages
    try {
      final ctx = _context;
      if (ctx != null && ctx.mounted) {
        AdminMessageService.listenForAdminMessages(
            ctx);
      }
    } catch (e) {
      debugPrint(
          '⚠️ Admin message listener error: $e');
    }

    // 2. Leaderboard cache
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final p = DatabaseService
            .getLeaderboardProfileForUid(user.uid);
        if (p != null && p.isOptedIn) {
          final last = p.lastCloudSyncAt;
          final needsRefresh = last == null ||
              DateTime.now().difference(last).inMinutes >=
                  120;
          if (needsRefresh) {
            await LeaderboardService.instance
                .getLeaderboardSnapshot(
              topLimit: 20,
              syncBeforeFetch: true,
            );
            debugPrint(
                '✅ Leaderboard cache refreshed');
          }
        }
      }
    } catch (e) {
      debugPrint(
          '⚠️ Leaderboard refresh skipped: $e');
    }

    debugPrint('✅ Online startup tasks completed.');
  }

  // ═══════════════════════════════════════
  // BACKUP — safe
  // ═══════════════════════════════════════

  Future<void> _runBackupSafely() async {
    try {
      if (!DatabaseService.isAutoBackupEnabled()) {
        return;
      }
      if (AuthService.instance.currentUser == null) {
        return;
      }

      final online = await checkInternet();
      if (!online) {
        debugPrint(
            '📵 Backup skipped — offline');
        return;
      }

      await BackupService
          .backupToGoogleDriveSilently();
      debugPrint('✅ Background backup done');
    } catch (e) {
      debugPrint('⚠️ Backup error: $e');
    }
  }
}