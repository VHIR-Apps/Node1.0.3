// lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // ✅ FIX: স্প্ল্যাশ স্ক্রিন রিমুভ করার জন্য ইমপোর্ট করা হলো
import 'package:hive_flutter/hive_flutter.dart';

import 'config/app_config.dart';
import 'config/theme_config.dart';
import 'firebase_options.dart';
import 'models/daily_study_routine_model.dart';
import 'models/habit_model.dart';
import 'models/leaderboard_profile_model.dart';
import 'models/notification_model.dart';
import 'models/study_routine_model.dart';
import 'models/study_session_model.dart';
import 'models/study_target_model.dart';
import 'screens/alarm_screen.dart';
// ✅ FIX: InboxScreen এর ইম্পোর্ট রিমুভ করা হয়েছে কারণ ইনবক্সে অটোমেটিক আর যাবে না
import 'screens/splash_screen.dart';
import 'screens/study_mode_screen.dart';
import 'services/advanced_pomodoro_service.dart';
import 'services/alarm_service.dart';
import 'services/auth_service.dart';
import 'services/auto_backup_trigger.dart';
import 'services/backup_service.dart';
import 'services/badge_service.dart';
import 'services/chat_notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/database_service.dart';
import 'services/google_drive_service.dart';
import 'services/lock_screen_service.dart';
import 'services/notes_service.dart';
import 'services/notification_service.dart';
import 'services/remote_config_service.dart';
import 'services/sound_service.dart';
import 'services/timer_notification_service.dart';
import 'services/timer_persistence_service.dart';
import 'services/tts_service.dart';
import 'widgets/badge_unlock_dialog.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ═══════════════════════════════════════
// ALARM STATE & FLAGS
// ═══════════════════════════════════════

Timer? _alarmPollTimer;
bool _isAlarmScreenOpen = false;
bool _hasHandledColdStart = false;

// ═══════════════════════════════════════
// 🌐 OFFLINE / RECOVERABLE ERROR CHECK
// ═══════════════════════════════════════

bool _isRecoverableError(Object error) {
  return true;
}

Future<bool> _hasNetworkConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ═══════════════════════════════════════
// 🎯 PAYLOAD DETECTION HELPERS
// ═══════════════════════════════════════

bool _isAlarmPayload(String payload) {
  return payload.startsWith('alarm:');
}

bool _isPomodoroPayload(String payload) {
  return payload == TimerNotificationService.payloadTimer ||
      payload == TimerNotificationService.payloadComplete;
}

bool _isChatPayload(String payload) {
  return payload == 'chat_message' ||
      payload.startsWith('chat:') ||
      payload.startsWith('message:');
}

bool _isSystemPayload(String payload) {
  return payload == 'daily_summary' ||
      payload == 'level_down' ||
      payload == 'pomodoro' ||
      _isAlarmPayload(payload) ||
      _isPomodoroPayload(payload) ||
      _isChatPayload(payload) ||
      payload.startsWith('evening_nudge:');
}

// ═══════════════════════════════════════
// MAIN
// ═══════════════════════════════════════

void main() async {
  runZonedGuarded(() async {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // ✅ FIX: স্প্ল্যাশ স্ক্রিন প্রিজার্ভ করা হলো
    _setupErrorHandlers();

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('⚠️ Firebase init warning (offline?): $e');
    }

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(HabitAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(AppNotificationAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(StudySessionAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(StudyRoutineAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(RoutineSessionAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(LeaderboardProfileModelAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(StudyTargetAdapter());
    if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(DailyStudyBlockAdapter());
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(DailyStudyRoutineAdapter());

    await DatabaseService.init();
    await NotesService.init();

    try {
      await RemoteConfigService.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('RemoteConfig init timed out'),
      );
    } catch (e) {
      debugPrint('⚠️ RemoteConfig skipped (offline?): $e');
    }

    await SoundService.init();
    await TtsService.init();
    await TimerPersistenceService.init();
    await TimerNotificationService.init();
    await AdvancedPomodoroService.init();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    NotificationService.onAlarmNotificationTapped = _handleAlarmNavigation;
    NotificationService.onAlarmActionTapped = (actionId, habitId) {
      if (actionId != null && habitId != null) {
        _handleAlarmActionTap(actionId: actionId, habitId: habitId);
      }
    };
    NotificationService.onGeneralActionTapped = (actionId, payload) {
      if (actionId != null && payload != null) {
        _handleQuickActionTap(actionId, payload);
      }
    };
    NotificationService.onNotificationTapped = (payload) {
      if (payload == null) return;
      if (_isAlarmPayload(payload)) {
        final habitId = payload.replaceFirst('alarm:', '');
        _handleAlarmNavigation(habitId);
        return;
      }
      _handleGeneralNotificationTap(payload);
    };

    await NotificationService.init();

    try {
      await ChatNotificationService.instance.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('ChatNotification timed out'),
      );
    } catch (e) {
      debugPrint('⚠️ ChatNotification skipped (offline?): $e');
    }

    ChatNotificationService.instance.onNotificationTap = (peerUid) {
      // Intentionally left empty — User wants to stay on Dashboard
    };

    AuthService.instance.userNotifier.addListener(() {
      _onAuthStateChanged();
    });

    if (AuthService.instance.currentUser != null) {
      _startChatListenerIfOnline();
    }

    BadgeService.onBadgeUnlocked = _handleBadgeUnlocked;

    try {
      await DatabaseService.performAutoReset();
    } catch (e) {
      debugPrint('⚠️ Auto reset failed: $e');
    }

    _loadSavedTheme();

    Widget initialScreen = const SplashScreen();

    try {
      final details = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        final actionId = details.notificationResponse?.actionId;

        if (payload != null) {
          if (_isAlarmPayload(payload)) {
            final habitId = payload.replaceFirst('alarm:', '');
            if (actionId == 'dismiss' || actionId == 'snooze') {
              _hasHandledColdStart = true;
              final String safeActionId = actionId ?? ''; // ✅ FIX: Null safety error fixed
              Future.delayed(const Duration(milliseconds: 2000), () {
                _handleAlarmActionTap(actionId: safeActionId, habitId: habitId);
              });
            } else {
              final habit = DatabaseService.getHabitById(habitId);
              if (habit != null) {
                await LockScreenService.enableForAlarm();
                initialScreen = AlarmScreen(habit: habit);
                _hasHandledColdStart = true;
                FlutterNativeSplash.remove(); // ✅ FIX: স্প্ল্যাশ স্ক্রিন বাইপাস
              }
            }
          }

          if (!_hasHandledColdStart && _isPomodoroPayload(payload)) {
            initialScreen = const StudyModeScreen();
            _hasHandledColdStart = true;
            FlutterNativeSplash.remove(); // ✅ FIX: স্প্ল্যাশ স্ক্রিন বাইপাস
          }

          if (!_hasHandledColdStart && _isChatPayload(payload)) {
            // initialScreen stays default (Dashboard)
            _hasHandledColdStart = true;
          }

          if (!_hasHandledColdStart && payload.startsWith('evening_nudge:')) {
            _hasHandledColdStart = true;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Cold start detection error: $e');
    }

    if (!_hasHandledColdStart) {
      await LockScreenService.forceDisable();
      _checkInitialAlarmLaunchDetails();
    }

    runApp(HabitNodeApp(initialScreen: initialScreen));
  }, (error, stack) {
    _handleUncaughtError(error, stack);
  });
}

Future<void> _startChatListenerIfOnline() async {
  final isOnline = await _hasNetworkConnection();
  if (isOnline) {
    try {
      ChatNotificationService.instance.startInboxListener();
    } catch (e) {
      debugPrint('⚠️ Chat listener start failed: $e');
    }
  }
}

void _onAuthStateChanged() {
  final user = AuthService.instance.currentUser;
  if (user != null) {
    _startChatListenerIfOnline();
  } else {
    try {
      ChatNotificationService.instance.stopInboxListener();
      ChatNotificationService.instance.resetState();
    } catch (_) {}
  }
}

Future<void> _handleQuickActionTap(String actionId, String payload) async {
  final cleanPayload = _isAlarmPayload(payload) ? payload.replaceFirst('alarm:', '') : payload;

  if (actionId == 'mark_done') {
    final habitId = cleanPayload.replaceFirst('evening_nudge:', '');
    final habit = DatabaseService.getHabitById(habitId);
    if (habit != null && !habit.isCompletedToday()) {
      final today = DateTime.now().toString().split(' ')[0];
      habit.completedDates.add(today);
      habit.currentStreak++;
      if (habit.currentStreak > habit.bestStreak) {
        habit.bestStreak = habit.currentStreak;
      }
      habit.lastProgressDate = today;
      await DatabaseService.updateHabit(habit);
      try { await BadgeService.onHabitCompleted(habit); } catch (_) {}
      try { SoundService.playSuccess(); } catch (_) {}
      await NotificationService.cancelHabitReminder(habit);
    }
    return;
  }

  if (actionId == 'start_now') {
    _handleGeneralNotificationTap(cleanPayload);
    return;
  }

  if (actionId == 'dismiss' || actionId == 'snooze') {
    await _handleAlarmActionTap(actionId: actionId, habitId: cleanPayload);
  }
}

void _handleGeneralNotificationTap(String payload) {
  final nav = navigatorKey.currentState;

  if (nav == null) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _handleGeneralNotificationTap(payload);
    });
    return;
  }

  if (_isAlarmPayload(payload)) {
    final habitId = payload.replaceFirst('alarm:', '');
    _handleAlarmNavigation(habitId);
    return;
  }

  if (_isPomodoroPayload(payload)) {
    nav.push(MaterialPageRoute(builder: (_) => const StudyModeScreen()));
    return;
  }

  if (_isChatPayload(payload)) {
    return; // ✅ FIX: চ্যাট নোটিফিকেশনে চাপ দিলে ড্যাশবোর্ডেই বসে থাকবে
  }

  if (payload.startsWith('evening_nudge:')) {
    final habitId = payload.replaceFirst('evening_nudge:', '');
    debugPrint('Navigated from evening nudge for habit: $habitId');
    return;
  }

  if (payload == 'daily_summary' || payload == 'level_down') {
    return;
  }

  if (!_isSystemPayload(payload)) {
    try {
      final habitId = payload.replaceFirst('evening_nudge:', '');
      final habit = DatabaseService.getHabitById(habitId);
      if (habit != null) {
        try {
          final ctx = nav.context;
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).clearSnackBars();
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Row(children: [
                Text(habit.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text(habit.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
              ]),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(habit.colorValue),
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}

Future<void> _handleAlarmActionTap({required String actionId, required String habitId}) async {
  try { await NotificationService.cancelAlarmNotification(habitId); } catch (_) {}
  try { await AlarmService.stopAlarm(); } catch (_) {}

  if (actionId == 'snooze') {
    final habit = DatabaseService.getHabitById(habitId);
    if (habit != null) {
      await NotificationService.scheduleSnoozeAlarm(habit: habit, delay: const Duration(minutes: 5));
    }
  }

  if (actionId == 'dismiss') {
    final habit = DatabaseService.getHabitById(habitId);
    if (habit != null && !habit.isCompletedToday()) {
      final today = DateTime.now().toString().split(' ')[0];
      habit.completedDates.add(today);
      habit.currentStreak++;
      if (habit.currentStreak > habit.bestStreak) habit.bestStreak = habit.currentStreak;
      habit.lastProgressDate = today;
      await DatabaseService.updateHabit(habit);
      try { await BadgeService.onHabitCompleted(habit); } catch (_) {}
    }
  }

  await LockScreenService.disableAfterAlarm();

  if (_isAlarmScreenOpen) {
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) nav.pop();
    _isAlarmScreenOpen = false;
  }
}

void _setupErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('⚠️ Flutter error (handled): ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('⚠️ Platform error (handled): $error');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (_isDebugMode()) return ErrorWidget(details.exception);

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😅', style: TextStyle(fontSize: isDark ? 20 : 18)),
              const SizedBox(width: 10),
              Flexible(child: Text('This section had a small issue.\nThe rest of the app works fine!', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, height: 1.4))),
            ],
          ),
        );
      },
    );
  };
}

bool _isDebugMode() {
  bool isDebug = false;
  assert(() { isDebug = true; return true; }());
  return isDebug;
}

void _handleUncaughtError(Object error, StackTrace stack) {
  debugPrint('⚠️ App error (gracefully handled): $error');
}

void _loadSavedTheme() {
  try {
    final savedTheme = DatabaseService.getThemeMode();
    switch (savedTheme) {
      case 'light': themeNotifier.value = ThemeMode.light; break;
      case 'dark': themeNotifier.value = ThemeMode.dark; break;
      default: themeNotifier.value = ThemeMode.system;
    }
  } catch (e) {
    themeNotifier.value = ThemeMode.system;
  }
}

void _handleBadgeUnlocked(dynamic badge) {
  Future.delayed(const Duration(milliseconds: 500), () {
    final nav = navigatorKey.currentState;
    if (nav == null || !nav.context.mounted || _isAlarmScreenOpen) return;
    BadgeUnlockDialog.show(nav.context, badge);
  });
}

void _checkInitialAlarmLaunchDetails() async {
  if (_hasHandledColdStart) return;
  _hasHandledColdStart = true;

  try {
    final details = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return;

    final response = details.notificationResponse;
    final String? payload = response?.payload;
    final String? actionId = response?.actionId;

    if (payload == null) return;

    if (_isAlarmPayload(payload)) {
      final habitId = payload.replaceFirst('alarm:', '');
      if (actionId == 'dismiss' || actionId == 'snooze') {
        final String safeActionId = actionId ?? ''; // ✅ FIX: Null safety
        await _handleAlarmActionTap(actionId: safeActionId, habitId: habitId);
        return;
      }
      _handleAlarmNavigation(habitId);
      return;
    }

    if (_isPomodoroPayload(payload)) {
      await Future.delayed(const Duration(milliseconds: 1500));
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const StudyModeScreen()));
      return;
    }

    if (_isChatPayload(payload) || payload.startsWith('evening_nudge:')) return;

    if (actionId != null) {
      final String safeActionId = actionId;
      await Future.delayed(const Duration(milliseconds: 1500));
      await _handleQuickActionTap(safeActionId, payload);
      return;
    }
  } catch (e) {
    debugPrint('❌ Launch details error: $e');
  }
}

void _handleAlarmNavigation(String habitId) {
  if (_isAlarmScreenOpen) return;
  _alarmPollTimer?.cancel();

  unawaited(LockScreenService.enableForAlarm());

  if (_tryOpenAlarmForHabit(habitId)) return;

  int attempts = 0;
  _alarmPollTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
    attempts++;
    if (attempts > 20) {
      timer.cancel();
      return;
    }
    if (_tryOpenAlarmForHabit(habitId)) timer.cancel();
  });
}

bool _tryOpenAlarmForHabit(String habitId) {
  final nav = navigatorKey.currentState;
  if (nav == null) return false;
  try {
    final habit = DatabaseService.getHabitById(habitId);
    if (habit != null) {
      _openAlarmScreen(habit);
      return true;
    }
  } catch (_) {}
  return false;
}

void _openAlarmScreen(Habit habit) {
  if (_isAlarmScreenOpen) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  NotificationService.cancelAlarmNotification(habit.id).catchError((_) {});
  _isAlarmScreenOpen = true;
  FlutterNativeSplash.remove(); // ✅ FIX: স্প্ল্যাশ স্ক্রিন রিমুভ করা হলো

  nav.push<void>(PageRouteBuilder(
    opaque: true,
    barrierDismissible: false,
    fullscreenDialog: true,
    pageBuilder: (context, animation, _) => AlarmScreen(habit: habit),
    transitionsBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
    },
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
  )).then((_) {
    _isAlarmScreenOpen = false;
    unawaited(LockScreenService.disableAfterAlarm());
  });
}

class _AutoBackupService {
  static bool _isRunning = false;
  static const int _dailyMs = 24 * 60 * 60 * 1000;
  static const int _weeklyMs = 7 * 24 * 60 * 60 * 1000;

  static Future<void> runIfNeeded() async {
    if (_isRunning) return;
    try {
      if (!DatabaseService.isAutoBackupEnabled()) return;
      final user = AuthService.instance.currentUser;
      if (user == null) return;
      final habits = DatabaseService.getAllHabits();
      if (habits.isEmpty) return;

      final frequency = DatabaseService.getAutoBackupFrequency();
      final lastBackupMs = DatabaseService.getLastAutoBackupTime();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      bool shouldRun = false;
      switch (frequency) {
        case 'every_exit':
        case 'on_exit': shouldRun = true; break;
        case 'weekly': shouldRun = lastBackupMs == 0 || (nowMs - lastBackupMs) >= _weeklyMs; break;
        case 'daily': shouldRun = lastBackupMs == 0 || (nowMs - lastBackupMs) >= _dailyMs; break;
        default: return;
      }

      if (!shouldRun) return;

      final isOnline = await _hasNetworkConnection();
      if (!isOnline) return;

      if (DatabaseService.isAutoBackupWifiOnly() && Platform.isAndroid) {
        final isOnWifi = await _isOnWifi();
        if (!isOnWifi) return;
      }

      _isRunning = true;
      try {
        final driveService = GoogleDriveService();
        await driveService.backupAllDataToCloudOnDemand().timeout(const Duration(seconds: 30), onTimeout: () => throw TimeoutException('Auto backup timed out'));
        await DatabaseService.setLastAutoBackupTime(nowMs);
      } catch (e) {
        debugPrint('⚠️ Auto backup failed: $e');
      }
    } finally {
      _isRunning = false;
    }
  }

  static Future<bool> _isOnWifi() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

class HabitNodeApp extends StatefulWidget {
  final Widget initialScreen;
  const HabitNodeApp({super.key, required this.initialScreen});

  @override
  State<HabitNodeApp> createState() => _HabitNodeAppState();
}

class _HabitNodeAppState extends State<HabitNodeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSilentRestoreOnAppLaunch();
    });
  }

  Future<void> _triggerSilentRestoreOnAppLaunch() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final isOnline = await _hasNetworkConnection();
    if (!isOnline) return;

    final localProfile = DatabaseService.getLeaderboardProfileForUid(user.uid);
    if (localProfile != null) return;

    try {
      final driveService = GoogleDriveService();
      await driveService.restoreAllDataFromCloudOnDemand().timeout(const Duration(seconds: 20), onTimeout: () => throw TimeoutException('Silent restore timed out'));
    } catch (e) {
      debugPrint('⚠️ Silent restore failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatNotificationService.instance.stopAllListeners().catchError((_) {});
    AutoBackupTrigger.dispose();
    ConnectivityService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        _AutoBackupService.runIfNeeded().catchError((_) {});
        AutoBackupTrigger.backupOnExit().catchError((_) {});
        if (!_isAlarmScreenOpen) {
          unawaited(LockScreenService.disableAfterAlarm());
        }
        try { ChatNotificationService.instance.setActiveChatPeer(null); } catch (_) {}
        break;
      case AppLifecycleState.resumed:
        _refreshThemeOnResume();
        AutoBackupTrigger.checkPendingBackup().catchError((_) {});
        if (AuthService.instance.currentUser != null) {
          _startChatListenerIfOnline();
        }
        break;
      case AppLifecycleState.detached:
        try { ChatNotificationService.instance.stopAllListeners().catchError((_) {}); } catch (_) {}
        break;
      default: break;
    }
  }

  void _refreshThemeOnResume() {
    try {
      final savedTheme = DatabaseService.getThemeMode();
      ThemeMode newMode;
      switch (savedTheme) {
        case 'light': newMode = ThemeMode.light; break;
        case 'dark': newMode = ThemeMode.dark; break;
        default: newMode = ThemeMode.system;
      }
      if (themeNotifier.value != newMode) {
        themeNotifier.value = newMode;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _) {
        return MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          themeMode: currentTheme,
          theme: ThemeConfig.lightTheme,
          darkTheme: ThemeConfig.darkTheme,
          navigatorKey: navigatorKey,
          home: widget.initialScreen,
          builder: (context, child) {
            ConnectivityService.instance.init(context);
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}