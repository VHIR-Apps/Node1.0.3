// lib/services/timer_notification_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TimerNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // ═══════════════════════════════════════
  // NOTIFICATION IDs
  // ═══════════════════════════════════════
  static const int _timerNotificationId = 9999;
  static const int _completionNotificationId = 9998;

  // ═══════════════════════════════════════
  // CHANNEL IDs
  // ═══════════════════════════════════════
  static const String _timerChannelId = 'pomodoro_timer';
  static const String _completionChannelId = 'pomodoro_complete';

  // ═══════════════════════════════════════
  // 🚀 PUBLIC PAYLOAD CONSTANTS
  // main.dart এই same value চেক করে routing করবে
  // ═══════════════════════════════════════
  static const String payloadTimer = 'pomodoro_timer_active';
  static const String payloadComplete = 'pomodoro_session_complete';

  // ═══════════════════════════════════════
  // INITIALIZE
  // ═══════════════════════════════════════
  static Future<void> init() async {
    if (_isInitialized) return;

    // ✅ এই plugin-এর initialize handler set করছি না
    // কারণ NotificationService এই একই plugin instance initialize করে
    // এবং সব tap handle করে main.dart-এ pass করে

    await _createNotificationChannels();

    _isInitialized = true;
    debugPrint('✅ TimerNotificationService initialized');
  }

  // ═══════════════════════════════════════
  // CREATE NOTIFICATION CHANNELS
  // ═══════════════════════════════════════
  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Timer channel (silent, ongoing)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _timerChannelId,
        'Study Timer',
        description: 'Shows ongoing timer countdown',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    // Completion channel (with sound)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _completionChannelId,
        'Timer Complete',
        description: 'Notifies when timer completes',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // ═══════════════════════════════════════
  // SHOW TIMER NOTIFICATION
  // ═══════════════════════════════════════
  static Future<void> showTimerNotification({
    required String title,
    required String timeText,
    required String stateEmoji,
    required int remainingSeconds,
    required bool isRunning,
  }) async {
    if (!_isInitialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _timerChannelId,
      'Study Timer',
      channelDescription: 'Shows ongoing timer countdown',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.progress,
      visibility: NotificationVisibility.public,
      colorized: true,
      color: _getColorForState(title),
      styleInformation: BigTextStyleInformation(
        '$stateEmoji $title\n⏱️ $timeText remaining',
        contentTitle: '$stateEmoji $title',
        summaryText: isRunning ? 'Timer running...' : 'Timer paused',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _timerNotificationId,
      '$stateEmoji $title',
      '⏱️ $timeText remaining',
      details,
      payload: payloadTimer, // 🚀 'pomodoro_timer_active'
    );
  }

  // ═══════════════════════════════════════
  // UPDATE NOTIFICATION
  // ═══════════════════════════════════════
  static Future<void> updateTimerNotification({
    required String title,
    required int remainingSeconds,
    required bool isRunning,
  }) async {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    String stateEmoji = '🍅';
    if (title.contains('Focus')) {
      stateEmoji = '🎯';
    } else if (title.contains('Short')) {
      stateEmoji = '☕';
    } else if (title.contains('Long')) {
      stateEmoji = '🌴';
    }

    await showTimerNotification(
      title: title,
      timeText: timeText,
      stateEmoji: stateEmoji,
      remainingSeconds: remainingSeconds,
      isRunning: isRunning,
    );
  }

  // ═══════════════════════════════════════
  // SHOW COMPLETION NOTIFICATION
  // ═══════════════════════════════════════
  static Future<void> showCompletionNotification({
    required String title,
    required String body,
    required bool isFocusComplete,
  }) async {
    if (!_isInitialized) await init();

    await cancelTimerNotification();

    final androidDetails = AndroidNotificationDetails(
      _completionChannelId,
      'Timer Complete',
      channelDescription: 'Notifies when timer completes',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      colorized: true,
      color:
      isFocusComplete ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _completionNotificationId,
      title,
      body,
      details,
      payload: payloadComplete, // 🚀 'pomodoro_session_complete'
    );
  }

  // ═══════════════════════════════════════
  // CANCEL
  // ═══════════════════════════════════════
  static Future<void> cancelTimerNotification() async {
    await _notifications.cancel(_timerNotificationId);
    debugPrint('🔕 Timer notification cancelled');
  }

  static Future<void> cancelAll() async {
    await _notifications.cancel(_timerNotificationId);
    await _notifications.cancel(_completionNotificationId);
    debugPrint('🔕 All timer notifications cancelled');
  }

  // ═══════════════════════════════════════
  // GET COLOR
  // ═══════════════════════════════════════
  static Color _getColorForState(String title) {
    if (title.contains('Focus')) return const Color(0xFFEF4444);
    if (title.contains('Short')) return const Color(0xFF10B981);
    if (title.contains('Long')) return const Color(0xFF3B82F6);
    return const Color(0xFF6B7280);
  }
}