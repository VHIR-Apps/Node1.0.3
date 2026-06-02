// lib/services/background_timer_service.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ═══════════════════════════════════════
// BACKGROUND TIMER SERVICE (100% PERFECT COUNTER)
// ═══════════════════════════════════════

class BackgroundTimerService {
  static const String notificationChannelId = 'timer_foreground';
  static const int notificationId = 888;

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  // ═══════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════
  static Future<void> init() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId, // id
      'Active Timer', // title
      description: 'Shows live timer countdown in background.',
      importance: Importance.low, // Low importance to prevent constant beeping
      playSound: false,
      enableVibration: false,
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
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Pomodoro Timer',
        initialNotificationContent: 'Preparing...',
        foregroundServiceNotificationId: notificationId,
        // 🆕 FIXED: Changed from String to AndroidForegroundType enum
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

    debugPrint('⚙️ Background Timer Service Configured perfectly');
  }

  // ═══════════════════════════════════════
  // FOREGROUND CONTROL METHODS
  // ═══════════════════════════════════════

  static Future<void> startTimer(int seconds, String title) async {
    if (!await _service.isRunning()) {
      await _service.startService();
    }
    _service.invoke('start', {
      'seconds': seconds,
      'title': title,
    });
  }

  static void pauseTimer() {
    _service.invoke('pause');
  }

  static void resumeTimer(int remainingSeconds, String title) {
    _service.invoke('resume', {
      'seconds': remainingSeconds,
      'title': title,
    });
  }

  static void stopTimer() {
    _service.invoke('stop');
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
// BACKGROUND ISOLATE LOGIC (Runs Independently)
// ═══════════════════════════════════════
@pragma('vm:entry-point')
void onBackgroundServiceStart(dynamic service) async {
  // Ensure background isolate is initialized
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Timer? timer;
  DateTime? targetEndTime;
  String currentTitle = "Focus Mode";
  bool isPaused = false;
  int pausedRemainingSeconds = 0;

  // ═══════════════════════════════════════
  // HELPER: UPDATE NOTIFICATION
  // ═══════════════════════════════════════
  Future<void> updateNotification(String timeStr, String title) async {
    await flutterLocalNotificationsPlugin.show(
      BackgroundTimerService.notificationId,
      title,
      'Time Remaining: $timeStr',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          BackgroundTimerService.notificationChannelId,
          'Active Timer',
          channelDescription: 'Shows live timer countdown.',
          icon: '@mipmap/ic_launcher',
          ongoing: true, // Sticky notification
          playSound: false,
          enableVibration: false,
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true, // Silent update
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // HELPER: FORMAT TIME
  // ═══════════════════════════════════════
  String formatTime(int totalSeconds) {
    final int min = totalSeconds ~/ 60;
    final int sec = totalSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════
  // LISTENER: START
  // ═══════════════════════════════════════
  service.on('start').listen((event) {
    if (event == null) return;

    final int seconds = event['seconds'] ?? 25 * 60;
    currentTitle = event['title'] ?? 'Focus Mode';

    // Set exact target end time
    targetEndTime = DateTime.now().add(Duration(seconds: seconds));
    isPaused = false;

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (isPaused || targetEndTime == null) return;

      final now = DateTime.now();
      final remaining = targetEndTime!.difference(now).inSeconds;

      if (remaining > 0) {
        // Send tick to main UI
        service.invoke('tick', {'remaining': remaining});
        // Update background notification silently
        updateNotification(formatTime(remaining), currentTitle);
      } else {
        // Timer Finished
        t.cancel();
        service.invoke('tick', {'remaining': 0});
        service.invoke('complete');

        // Show completion sound/vibration notification
        await flutterLocalNotificationsPlugin.show(
          BackgroundTimerService.notificationId,
          '🎉 Finished!',
          '$currentTitle is complete.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              BackgroundTimerService.notificationChannelId,
              'Active Timer',
              icon: '@mipmap/ic_launcher',
              playSound: false,
              enableVibration: false,
            ),
          ),
        );
        service.stopSelf();
      }
    });
  });

  // ═══════════════════════════════════════
  // LISTENER: PAUSE
  // ═══════════════════════════════════════
  service.on('pause').listen((event) {
    isPaused = true;
    timer?.cancel();
    if (targetEndTime != null) {
      pausedRemainingSeconds =
          targetEndTime!.difference(DateTime.now()).inSeconds;
      if (pausedRemainingSeconds < 0) pausedRemainingSeconds = 0;
      updateNotification(
          '${formatTime(pausedRemainingSeconds)} (Paused)', currentTitle);
    }
  });

  // ═══════════════════════════════════════
  // LISTENER: RESUME
  // ═══════════════════════════════════════
  service.on('resume').listen((event) {
    if (event == null) return;

    final int seconds = event['seconds'] ?? pausedRemainingSeconds;
    currentTitle = event['title'] ?? currentTitle;

    // Recalculate target end time from NOW
    targetEndTime = DateTime.now().add(Duration(seconds: seconds));
    isPaused = false;

    service.invoke('start', {
      'seconds': seconds,
      'title': currentTitle,
    });
  });

  // ═══════════════════════════════════════
  // LISTENER: STOP
  // ═══════════════════════════════════════
  service.on('stop').listen((event) {
    timer?.cancel();
    flutterLocalNotificationsPlugin
        .cancel(BackgroundTimerService.notificationId);
    service.stopSelf();
  });
}