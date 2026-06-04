// lib/services/background_timer_service.dart
//
// FIX: Foreground service notification এখন TimerNotificationService-এর
// same ID (9999) এবং same channel ('pomodoro_timer') ব্যবহার করে।
// ফলে status bar-এ শুধু ১টাই notification থাকবে।

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundTimerService {
  // ─────────────────────────────────────────────
  // IMPORTANT: TimerNotificationService-এর সাথে SAME channel & ID
  // যাতে দুটো notification merge হয়ে একটাই থাকে
  // ─────────────────────────────────────────────
  static const String notificationChannelId = 'pomodoro_timer';
  static const int notificationId = 9999;

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  // ═══════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════
  static Future<void> init() async {
    // Channel creation — TimerNotificationService-ও same channel বানায়,
    // তাই duplicate হবে না, Android same ID-র channel re-create করে না
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId, // 'pomodoro_timer' — same as TimerNotificationService
      'Study Timer',
      description: 'Shows ongoing timer countdown',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId, // 'pomodoro_timer'
        initialNotificationTitle: 'Study Timer',
        initialNotificationContent: 'Preparing...',
        foregroundServiceNotificationId: notificationId, // 9999 — SAME ID
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onBackgroundServiceStart,
        onBackground: (dynamic service) async {
          return true;
        },
      ),
    );

    debugPrint('⚙️ BackgroundTimerService initialized (shared ID: $notificationId)');
  }

  // ═══════════════════════════════════════
  // FOREGROUND CONTROL METHODS
  // ═══════════════════════════════════════

  static Future<void> startTimer(int seconds, String title) async {
    if (!await _service.isRunning()) {
      await _service.startService();
      // Service start হতে সামান্য সময় লাগে
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _service.invoke('start', {
      'seconds': seconds,
      'title': title,
    });
    debugPrint('▶️ BackgroundTimer: startTimer($seconds s, "$title")');
  }

  static void pauseTimer() {
    _service.invoke('pause');
    debugPrint('⏸️ BackgroundTimer: pause');
  }

  static void resumeTimer(int remainingSeconds, String title) {
    _service.invoke('resume', {
      'seconds': remainingSeconds,
      'title': title,
    });
    debugPrint('▶️ BackgroundTimer: resume($remainingSeconds s)');
  }

  static void stopTimer() {
    _service.invoke('stop');
    debugPrint('⏹️ BackgroundTimer: stop');
  }

  // ═══════════════════════════════════════
  // EVENT LISTENERS
  // ═══════════════════════════════════════

  static void onTick(Function(int) callback) {
    _service.on('tick').listen((event) {
      if (event != null && event['remaining'] != null) {
        callback(event['remaining'] as int);
      }
    });
  }

  static void onComplete(Function() callback) {
    _service.on('complete').listen((event) {
      callback();
    });
  }
}

// ═══════════════════════════════════════
// BACKGROUND ISOLATE LOGIC
//
// ⚠️ KEY CHANGE: Foreground service notification এবং
// TimerNotificationService দুটোই ID 9999 ব্যবহার করে।
// তাই Android OS দুটোকে একটা notification হিসেবে দেখায়।
//
// Background isolate-এ notification update করলে
// TimerNotificationService-এর notification overwrite হয়
// এবং vice versa। এতে সবসময় শুধু ১টাই থাকে।
// ═══════════════════════════════════════
@pragma('vm:entry-point')
void onBackgroundServiceStart(dynamic service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin localNotif =
  FlutterLocalNotificationsPlugin();

  Timer? countdownTimer;
  DateTime? targetEndTime;
  bool isPaused = false;
  int pausedRemainingSeconds = 0;
  String currentTitle = 'Focus Mode';

  // Payload constant — same as TimerNotificationService.payloadTimer
  const String timerPayload = 'pomodoro_timer_active';

  // ─────────────────────────────────────────────
  // HELPER: Notification update — SAME ID & channel
  // as TimerNotificationService so they merge into ONE
  // ─────────────────────────────────────────────
  Future<void> updateNotification(String timeStr, String title, bool isRunning) async {
    String stateEmoji = '🍅';
    if (title.contains('Focus')) {
      stateEmoji = '🎯';
    } else if (title.contains('Short')) {
      stateEmoji = '☕';
    } else if (title.contains('Long')) {
      stateEmoji = '🌴';
    }

    await localNotif.show(
      BackgroundTimerService.notificationId, // 9999 — SAME ID
      '$stateEmoji $title',
      '⏱️ $timeStr remaining',
      NotificationDetails(
        android: AndroidNotificationDetails(
          BackgroundTimerService.notificationChannelId, // 'pomodoro_timer'
          'Study Timer',
          channelDescription: 'Shows ongoing timer countdown',
          icon: '@mipmap/ic_launcher',
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          playSound: false,
          enableVibration: false,
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          silent: true,
          category: AndroidNotificationCategory.progress,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(
            '$stateEmoji $title\n⏱️ $timeStr remaining',
            contentTitle: '$stateEmoji $title',
            summaryText: isRunning ? 'Timer running...' : 'Timer paused',
          ),
        ),
      ),
      payload: timerPayload, // 'pomodoro_timer_active'
    );
  }

  // ─────────────────────────────────────────────
  // HELPER: Format seconds → MM:SS
  // ─────────────────────────────────────────────
  String formatTime(int totalSeconds) {
    final int min = totalSeconds ~/ 60;
    final int sec = totalSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────
  // START LISTENER
  // ─────────────────────────────────────────────
  service.on('start').listen((event) async {
    if (event == null) return;

    final int seconds = event['seconds'] as int? ?? 25 * 60;
    currentTitle = event['title'] as String? ?? 'Focus Mode';

    targetEndTime = DateTime.now().add(Duration(seconds: seconds));
    isPaused = false;

    countdownTimer?.cancel();

    debugPrint('⏱️ Background isolate: timer started ($seconds s)');

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (isPaused || targetEndTime == null) return;

      final now = DateTime.now();
      final remaining = targetEndTime!.difference(now).inSeconds;

      if (remaining > 0) {
        // Main isolate-এ tick event পাঠাও
        service.invoke('tick', {'remaining': remaining});

        // Notification update — same ID 9999, same channel
        // TimerNotificationService-এর notification overwrite করবে
        await updateNotification(formatTime(remaining), currentTitle, true);
      } else {
        // Timer শেষ!
        t.cancel();
        service.invoke('tick', {'remaining': 0});
        service.invoke('complete');
        debugPrint('✅ Background isolate: timer complete');

        // Notification cancel — main isolate completion notification দেখাবে
        await localNotif.cancel(BackgroundTimerService.notificationId);
        service.stopSelf();
      }
    });
  });

  // ─────────────────────────────────────────────
  // PAUSE LISTENER
  // ─────────────────────────────────────────────
  service.on('pause').listen((event) async {
    isPaused = true;
    countdownTimer?.cancel();

    if (targetEndTime != null) {
      pausedRemainingSeconds =
          targetEndTime!.difference(DateTime.now()).inSeconds;
      if (pausedRemainingSeconds < 0) pausedRemainingSeconds = 0;
    }

    // Paused state notification update
    await updateNotification(
      '${formatTime(pausedRemainingSeconds)} (Paused)',
      currentTitle,
      false,
    );

    debugPrint('⏸️ Background isolate: paused ($pausedRemainingSeconds s left)');
  });

  // ─────────────────────────────────────────────
  // RESUME LISTENER
  // ─────────────────────────────────────────────
  service.on('resume').listen((event) {
    if (event == null) return;

    final int seconds = event['seconds'] as int? ?? pausedRemainingSeconds;
    currentTitle = event['title'] as String? ?? currentTitle;

    targetEndTime = DateTime.now().add(Duration(seconds: seconds));
    isPaused = false;

    // Re-trigger start logic
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (isPaused || targetEndTime == null) return;

      final now = DateTime.now();
      final remaining = targetEndTime!.difference(now).inSeconds;

      if (remaining > 0) {
        service.invoke('tick', {'remaining': remaining});
        await updateNotification(formatTime(remaining), currentTitle, true);
      } else {
        t.cancel();
        service.invoke('tick', {'remaining': 0});
        service.invoke('complete');
        await localNotif.cancel(BackgroundTimerService.notificationId);
        service.stopSelf();
      }
    });

    debugPrint('▶️ Background isolate: resumed ($seconds s)');
  });

  // ─────────────────────────────────────────────
  // STOP LISTENER
  // ─────────────────────────────────────────────
  service.on('stop').listen((event) async {
    countdownTimer?.cancel();
    isPaused = true;
    await localNotif.cancel(BackgroundTimerService.notificationId);
    service.stopSelf();
    debugPrint('⏹️ Background isolate: stopped');
  });
}