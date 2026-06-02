// lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
import 'screens/splash_screen.dart';
import 'screens/study_mode_screen.dart';
import 'services/advanced_pomodoro_service.dart';
import 'services/alarm_service.dart';
import 'services/auth_service.dart';
import 'services/badge_service.dart';
import 'services/backup_service.dart';
import 'services/database_service.dart';
import 'services/google_drive_service.dart';
import 'services/notes_service.dart';
import 'services/notification_service.dart';
import 'services/remote_config_service.dart';
import 'services/sound_service.dart';
import 'services/timer_notification_service.dart';
import 'services/timer_persistence_service.dart';
import 'services/tts_service.dart';
import 'widgets/badge_unlock_dialog.dart';
import 'widgets/error_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ═══════════════════════════════════════
// ALARM STATE & AUTOMATION FLAGS
// ═══════════════════════════════════════

Timer? _alarmPollTimer;
bool _isAlarmScreenOpen = false;
bool _hasHandledColdStart = false; // 🚀 Automation Flag

final ValueNotifier<_FatalError?> _fatalErrorVN =
ValueNotifier<_FatalError?>(null);

class _FatalError {
  final Object error;
  final StackTrace stack;
  const _FatalError(this.error, this.stack);
}

// ═══════════════════════════════════════
// MAIN
// ═══════════════════════════════════════

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    _setupErrorHandlers();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await Hive.initFlutter();

    // Register Hive adapters
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
    await RemoteConfigService.init();

    // 🚀 FIX: Added 'await' so Sound & TTS engines are fully loaded before app starts!
    await SoundService.init();
    await TtsService.init();

    await TimerPersistenceService.init();
    await TimerNotificationService.init();
    await AdvancedPomodoroService.init();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ═══════════════════════════════════════
    // 🎯 NOTIFICATION HANDLERS SETUP
    // ═══════════════════════════════════════

    NotificationService.onAlarmNotificationTapped = _handleAlarmNavigation;

    NotificationService.onAlarmActionTapped = (actionId, habitId) {
      _handleAlarmActionTap(actionId: actionId, habitId: habitId);
    };

    NotificationService.onGeneralActionTapped = (actionId, payload) {
      _handleQuickActionTap(actionId, payload);
    };

    NotificationService.onNotificationTapped = (payload) {
      _handleGeneralNotificationTap(payload);
    };

    AlarmService.onAlarmTriggered = _openAlarmScreen;

    await NotificationService.init();
    BadgeService.onBadgeUnlocked = _handleBadgeUnlocked;
    await DatabaseService.performAutoReset();
    _loadSavedTheme();

    // 🚀 Start Automation Engine immediately
    _checkInitialAlarmLaunchDetails();

    runApp(const HabitNodeApp());
  }, (error, stack) {
    _handleUncaughtError(error, stack);
  });
}

// ═══════════════════════════════════════
// 🎯 QUICK ACTION HANDLER
// ═══════════════════════════════════════

Future<void> _handleQuickActionTap(String actionId, String payload) async {
  debugPrint('⚡ Quick Action: $actionId for payload: $payload');

  final cleanPayload = payload.startsWith('alarm:')
      ? payload.replaceFirst('alarm:', '')
      : payload;

  if (actionId == 'mark_done') {
    final habit = DatabaseService.getHabitById(cleanPayload);

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
}

// ═══════════════════════════════════════
// 🎯 SMART ROUTING HANDLER
// ═══════════════════════════════════════

void _handleGeneralNotificationTap(String payload) {
  final nav = navigatorKey.currentState;

  if (nav == null) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _handleGeneralNotificationTap(payload);
    });
    return;
  }

  if (payload.contains('study') ||
      payload.contains('pomodoro') ||
      payload.contains('timer') ||
      payload.contains('focus')) {
    // 🚀 FIX: Clear previous screens so it doesn't get stuck on dashboard!
    nav.popUntil((route) => route.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => const StudyModeScreen()));
    return;
  }

  if (payload == 'daily_summary') {
    nav.popUntil((route) => route.isFirst);
    return;
  }

  try {
    final habit = DatabaseService.getHabitById(payload);
    if (habit != null) {
      nav.popUntil((route) => route.isFirst);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (nav.context.mounted) {
          ScaffoldMessenger.of(nav.context).showSnackBar(
            SnackBar(
              content: Text('${habit.emoji} ${habit.name}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(habit.colorValue),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
      return;
    }
  } catch (e) {
    debugPrint('⚠️ Habit lookup error: $e');
  }

  nav.popUntil((route) => route.isFirst);
}

// ═══════════════════════════════════════
// ALARM ACTION — SILENT HANDLER
// ═══════════════════════════════════════

Future<void> _handleAlarmActionTap({
  required String actionId,
  required String habitId,
}) async {
  try {
    await NotificationService.cancelAlarmNotification(habitId);
  } catch (_) {}

  try {
    await AlarmService.handleAlarmActionFromNotification(
      actionId: actionId,
      habitId: habitId,
    );
  } catch (e) {
    debugPrint('❌ Alarm action error: $e');
  }

  if (actionId == 'snooze') {
    final habit = DatabaseService.getHabitById(habitId);
    if (habit != null) {
      await NotificationService.scheduleSnoozeAlarm(habit: habit);
    }
  }

  if (actionId == 'dismiss') {
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
    }
  }

  if (_isAlarmScreenOpen) {
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) nav.pop();
    _isAlarmScreenOpen = false;
  }
}

// ═══════════════════════════════════════
// ERROR HANDLERS
// ═══════════════════════════════════════

void _setupErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    final stack = details.stack ?? StackTrace.current;
    if (!_isDebugMode()) _handleUncaughtError(details.exception, stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (!_isDebugMode()) {
      _handleUncaughtError(error, stack);
      return true;
    }
    return false;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (_isDebugMode()) return ErrorWidget(details.exception);
    return Material(
      color: const Color(0xFF0B1020),
      child: Center(
        child: ErrorScreen(
          title: 'Oops!',
          message: 'Something went wrong.',
          errorCode: 'UI_ERROR',
          onRetry: _restartApp,
          showBackButton: false,
          showRetryButton: true,
        ),
      ),
    );
  };
}

bool _isDebugMode() {
  bool isDebug = false;
  assert(() {
    isDebug = true;
    return true;
  }());
  return isDebug;
}

String _prettyFatalMessage(Object error) {
  final raw = error.toString();
  if (raw.contains('AuthServiceException:')) return raw.replaceAll('AuthServiceException:', '').trim();
  if (raw.contains('LeaderboardServiceException:')) return raw.replaceAll('LeaderboardServiceException:', '').trim();
  final lower = raw.toLowerCase();
  if (lower.contains('apiexception: 10')) return 'Unable to sign in. Google Sign-In is not configured correctly.';
  if (lower.contains('invalid-credential')) return 'Invalid or expired sign-in session. Please sign in again.';
  return 'An unexpected error occurred. Please try again.';
}

void _handleUncaughtError(Object error, StackTrace stack) {
  _fatalErrorVN.value = _FatalError(error, stack);
}

void _restartApp() {
  _fatalErrorVN.value = null;
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
  );
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

// ═══════════════════════════════════════
// 🚀 AUTOMATION ENGINE: COLD START — ALARM LAUNCH DETECTION
// ═══════════════════════════════════════

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

    // 🚀 INSTANT LOCK-SCREEN AUTOMATION (No Delays)
    if (payload.startsWith('alarm:')) {
      final habitId = payload.replaceFirst('alarm:', '');
      if (actionId != null && (actionId == 'dismiss' || actionId == 'snooze')) {
        await _handleAlarmActionTap(actionId: actionId, habitId: habitId);
        return;
      }
      // সরাসরি অ্যালার্ম স্ক্রিনে নিয়ে যাবে
      _handleAlarmNavigation(habitId);
      return;
    }

    // ⏳ অন্যান্য নোটিফিকেশনের ক্ষেত্রে একটু ডেল দেওয়া হলো যাতে ড্যাশবোর্ড লোড হতে পারে
    await Future.delayed(const Duration(milliseconds: 1000));

    if (actionId != null) {
      _handleQuickActionTap(actionId, payload);
      return;
    }

    _handleGeneralNotificationTap(payload);
  } catch (e) {
    debugPrint('❌ Initial launch error: $e');
  }
}

// ═══════════════════════════════════════
// ALARM NAVIGATION
// ═══════════════════════════════════════

void _handleAlarmNavigation(String habitId) {
  if (_isAlarmScreenOpen) return;
  _alarmPollTimer?.cancel();

  // প্রথম চেষ্টাতেই ডাটাবেস রেডি থাকলে সরাসরি ওপেন হবে
  if (_tryOpenAlarmForHabit(habitId)) return;

  // অ্যাপ পুরোপুরি কিল (Killed) থাকলে ডাটাবেস লোড হতে সময় লাগতে পারে, তাই পোলিং করবে
  int attempts = 0;
  _alarmPollTimer = Timer.periodic(
    const Duration(milliseconds: 200),
        (timer) {
      attempts++;
      if (attempts > 20) {
        timer.cancel(); // ৪ সেকেন্ড পর হাল ছেড়ে দিবে
        return;
      }
      if (_tryOpenAlarmForHabit(habitId)) timer.cancel();
    },
  );
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
  } catch (e) {
    debugPrint('⏳ DB not ready: $e');
  }
  return false;
}

void _openAlarmScreen(Habit habit) {
  if (_isAlarmScreenOpen) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  NotificationService.cancelAlarmNotification(habit.id).catchError((_) {});
  AlarmService.startAlarm(habit).catchError((e) {});

  _isAlarmScreenOpen = true;

  nav.push<void>(
    PageRouteBuilder(
      opaque: true,
      barrierDismissible: false,
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          AlarmScreen(habit: habit),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 150), // 🚀 ফাস্ট অ্যানিমেশন
      reverseTransitionDuration: const Duration(milliseconds: 150),
    ),
  ).then((_) {
    _isAlarmScreenOpen = false;
  });
}

// ═══════════════════════════════════════
// AUTO BACKUP SERVICE
// ═══════════════════════════════════════

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
        case 'every_exit': shouldRun = true; break;
        case 'weekly': shouldRun = lastBackupMs == 0 || (nowMs - lastBackupMs) >= _weeklyMs; break;
        case 'daily':
        default: shouldRun = lastBackupMs == 0 || (nowMs - lastBackupMs) >= _dailyMs; break;
      }

      if (!shouldRun) return;
      if (DatabaseService.isAutoBackupWifiOnly() && Platform.isAndroid) {
        final isOnWifi = await _isOnWifi();
        if (!isOnWifi) return;
      }

      _isRunning = true;
      try {
        final driveService = GoogleDriveService();
        await driveService.backupAllDataToCloudOnDemand();
        await DatabaseService.setLastAutoBackupTime(nowMs);
      } catch (_) {}
    } finally {
      _isRunning = false;
    }
  }

  static Future<bool> _isOnWifi() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

// ═══════════════════════════════════════
// APP WIDGET
// ═══════════════════════════════════════

class HabitNodeApp extends StatefulWidget {
  const HabitNodeApp({super.key});

  @override
  State<HabitNodeApp> createState() => _HabitNodeAppState();
}

class _HabitNodeAppState extends State<HabitNodeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try { _fatalErrorVN.dispose(); } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        _AutoBackupService.runIfNeeded().catchError((_) {});
        break;
      case AppLifecycleState.resumed:
        _refreshThemeOnResume();
        break;
      default:
        break;
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
      if (themeNotifier.value != newMode) themeNotifier.value = newMode;
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
          home: const SplashScreen(),
          builder: (context, child) {
            return ValueListenableBuilder<_FatalError?>(
              valueListenable: _fatalErrorVN,
              builder: (context, fatal, __) {
                final base = child ?? const SizedBox.shrink();
                if (fatal == null) return base;
                return Stack(
                  children: [
                    base,
                    Positioned.fill(
                      child: Material(
                        color: const Color(0xFF0B1020),
                        child: ErrorScreen(
                          title: 'Error',
                          message: _prettyFatalMessage(fatal.error),
                          errorCode: fatal.error.runtimeType.toString(),
                          onRetry: _restartApp,
                          onGoBack: null,
                          showBackButton: false,
                          showRetryButton: true,
                          customIcon: '⚠️',
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}