// lib/services/notification_service.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit_model.dart';
import '../models/notification_model.dart';
import 'database_service.dart';
import 'timer_notification_service.dart'; // ADDED: pomodoro delegation

// ═══════════════════════════════════════════════════════════════════════════════
// 🧠 REVERSE PSYCHOLOGY & AI COACH ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

class _PsychEngine {
  static final Random _rng = Random();

  static const List<String> _morningMessages = [
    "Morning! Top 1% performers already tackled {habit}. Are you joining them? ☀️",
    "A new day. A blank slate. Build your empire starting with {habit}.",
    "Don't let the day control you. Control the day. Execute {habit} now.",
    "The first win of the day sets the tone. Secure it with {habit}. 🌅",
  ];

  static const List<String> _urgencyMessages = [
    "Your streak is in danger. {habit} must happen today. 🔥",
    "Every winner shows up. Even on bad days. Time for {habit}. 💪",
    "The longer you wait, the harder it gets. Do {habit} right now.",
    "⏰ The clock is ticking. {habit} won't execute itself.",
    "Action creates momentum. Execute {habit} to fuel your day.",
  ];

  static const List<String> _identityMessages = [
    "People who do {habit} daily are 3x more successful. You're one of them.",
    "You're not lazy — you just haven't started {habit} yet. Break the cycle.",
    "Your identity is built one habit at a time. {habit} is your next brick.",
    "Champions don't negotiate with themselves. {habit} — do it.",
    "Will you be a consumer or a creator today? Choose {habit}.",
  ];

  static const List<String> _lossMessages = [
    "⚠️ CODE RED: You haven't done {habit} yet. Your streak dies tonight.",
    "{streak} days of {habit} — all of it erased if you don't act NOW.",
    "🔴 XP at risk: Missing {habit} will cost you heavy points tonight.",
    "Everyone else completed their routines. Why are you lagging behind?",
  ];

  static const List<String> _reverseMessages = [
    "It's fine. Skip {habit}. Average people do it all the time.",
    "Go ahead — skip {habit} again. See how that feels tomorrow morning.",
    "Maybe {habit} isn't for you. Or maybe it is and you're just giving up.",
    "🤷 No pressure. Just know that streaks don't rebuild themselves magically.",
  ];

  static const List<String> _comebackMessages = [
    "You missed {habit} yesterday. That's not who you are. Come back stronger. 💪",
    "Yesterday's skip is not your story. Today's action is. Do {habit}.",
    "Every champion has a comeback moment. Yours starts right now with {habit}.",
    "Your streak broke. That's ok. Rebuild the empire today with {habit}.",
  ];

  static String _pick(List<String> list) =>
      list[_rng.nextInt(list.length)];

  static String _fill(
      String template, {
        required String habitName,
        required int streak,
      }) {
    return template
        .replaceAll('{habit}', habitName)
        .replaceAll('{streak}', '$streak');
  }

  static String buildMessage({
    required Habit habit,
    required _NotifContext ctx,
  }) {
    final streak = habit.currentStreak;
    final missed = habit.wasMissedYesterday();
    final hour = DateTime.now().hour;

    String template;
    if (missed) {
      template = _pick(_comebackMessages);
    } else if (hour < 11) {
      template = _pick(_morningMessages);
    } else if (hour >= 22) {
      template = _pick(_lossMessages);
    } else if (hour >= 19) {
      template = _pick(_reverseMessages);
    } else if (ctx == _NotifContext.smart) {
      template = _pick(_reverseMessages);
    } else if (ctx == _NotifContext.identity) {
      template = _pick(_identityMessages);
    } else {
      template = _pick(_urgencyMessages);
    }

    return _fill(template,
        habitName: habit.name, streak: streak);
  }

  static String buildTitle({
    required Habit habit,
    required bool isMissed,
  }) {
    final streak = habit.currentStreak;
    final hour = DateTime.now().hour;

    if (isMissed)
      return "${habit.emoji} Comeback Time: ${habit.name}";
    if (hour < 11)
      return "${habit.emoji} Morning Target: ${habit.name}";
    if (hour >= 22)
      return "🚨 CRITICAL: ${habit.name} is pending!";
    if (streak >= 30) {
      return "${habit.emoji} 🔥 $streak-Day Warrior: ${habit.name}";
    }
    if (streak >= 7) {
      return "${habit.emoji} 🔥 $streak-Day Streak: ${habit.name}";
    }
    if (streak > 0) {
      return "${habit.emoji} Protect the Streak: ${habit.name}";
    }
    return "${habit.emoji} Time to Execute: ${habit.name}";
  }
}

enum _NotifContext { urgency, identity, smart, social }

// ═══════════════════════════════════════════════════════════════════════════════
// 🎯 NOTIFICATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const String _notificationIcon = '@mipmap/ic_launcher';

  // ─────────────────────────────────────────────
  // CALLBACK HANDLERS
  // ─────────────────────────────────────────────

  static Function(String habitId)? onAlarmNotificationTapped;
  static Function(String actionId, String habitId)? onAlarmActionTapped;
  static Function(String payload)? onNotificationTapped;
  static Function(String actionId, String payload)? onGeneralActionTapped;

  static bool _launchPayloadHandled = false;
  static bool get launchPayloadHandled => _launchPayloadHandled;

  // ─────────────────────────────────────────────
  // CHANNEL IDs
  // ─────────────────────────────────────────────

  static const String channelHabitReminders = 'habit_reminders_v3';
  static const String channelDailySummary = 'daily_summary_v3';
  static const String channelInstant = 'instant_notifications_v3';
  static const String channelSmartReminders = 'smart_reminders_v3';
  static const String channelHabitAlarm = 'habit_alarm_v3';
  static const String channelPsychology = 'psychology_nudges_v3';

  // ─────────────────────────────────────────────
  // NOTIFICATION IDs
  // ─────────────────────────────────────────────

  static int _reminderId(String habitId) =>
      habitId.hashCode.abs() % 100000;

  static int _smartId(String habitId) =>
      (habitId.hashCode.abs() + 50000) % 100000;

  static int _alarmId(String habitId) =>
      (habitId.hashCode.abs() + 70000) % 100000;

  static int _snoozeAlarmId(String habitId) =>
      (habitId.hashCode.abs() + 80000) % 100000;

  static int _psychId(String habitId) =>
      (habitId.hashCode.abs() + 90000) % 100000;

  static String _getEmojiForType(String type) {
    switch (type.toLowerCase()) {
      case 'achievement':
      case 'milestone':
        return '🏆';
      case 'streak':
      case 'fire':
        return '🔥';
      case 'reminder':
        return '🔔';
      case 'smart':
        return '💡';
      case 'psychology':
        return '🧠';
      case 'summary':
        return '📊';
      case 'alarm':
        return '⏰';
      case 'warning':
      case 'missed':
        return '⚠️';
      case 'level_down':
        return '📉';
      case 'system':
        return '⚙️';
      case 'pomodoro':
      case 'study':
      case 'timer':
        return '📚';
      default:
        return '💬';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚀 INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> init() async {
    if (_initialized) return;

    tzData.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    } catch (e) {
      debugPrint('❌ Timezone init failed: $e');
    }

    const androidSettings =
    AndroidInitializationSettings(_notificationIcon);
    const initSettings =
    InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
      _handleBackgroundNotificationTap,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelHabitReminders,
          'Habit Reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelDailySummary,
          'Daily Summary',
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelInstant,
          'General Notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelSmartReminders,
          'Smart Reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelHabitAlarm,
          'Habit Alarms',
          description:
          'Full-screen alarms that wake up your screen',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelPsychology,
          'Motivation Nudges',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  static Future<String?> getInitialPayload() async {
    try {
      final details =
      await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('❌ getInitialPayload error: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 FOREGROUND NOTIFICATION TAP HANDLER
  // ═══════════════════════════════════════════════════════════════════════════

  static void _handleNotificationTap(
      NotificationResponse response) {
    final String? payload = response.payload;
    final String? actionId = response.actionId;

    debugPrint(
      '🔔 Tap | payload: "$payload" | action: "$actionId"',
    );

    if (payload == null) return;

    // Alarm notification
    if (payload.startsWith('alarm:')) {
      _launchPayloadHandled = true;
      final habitId = payload.replaceFirst('alarm:', '');

      if (actionId != null &&
          (actionId == 'dismiss' || actionId == 'snooze')) {
        onAlarmActionTapped?.call(actionId, habitId);
        return;
      }

      onAlarmNotificationTapped?.call(habitId);
      return;
    }

    // Action button tap
    if (actionId != null) {
      onGeneralActionTapped?.call(actionId, payload);
      return;
    }

    // Normal notification tap
    onNotificationTapped?.call(payload);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚀 BACKGROUND TAP HANDLER
  // ═══════════════════════════════════════════════════════════════════════════

  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationTap(
      NotificationResponse response,
      ) async {
    debugPrint(
        '🔔 Background tap | action: ${response.actionId}');

    final actionId = response.actionId;
    final payload = response.payload;

    if (payload == null || actionId == null) return;

    if (actionId == 'mark_done' || actionId == 'dismiss') {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        final dir = await path_provider
            .getApplicationDocumentsDirectory();
        Hive.init(dir.path);

        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(HabitAdapter());
        }

        final cleanPayload = payload.startsWith('alarm:')
            ? payload.replaceFirst('alarm:', '')
            : payload;

        final box = await Hive.openBox<Habit>('habits');

        Habit? targetHabit;
        for (var h in box.values) {
          if (h.id == cleanPayload) {
            targetHabit = h;
            break;
          }
        }

        if (targetHabit != null &&
            !targetHabit.isCompletedToday()) {
          final today =
          DateTime.now().toString().split(' ')[0];
          targetHabit.completedDates.add(today);
          targetHabit.currentStreak++;

          if (targetHabit.currentStreak >
              targetHabit.bestStreak) {
            targetHabit.bestStreak =
                targetHabit.currentStreak;
          }

          targetHabit.lastProgressDate = today;
          await box.put(targetHabit.id, targetHabit);
          debugPrint(
            '✅ Background: Habit done — ${targetHabit.name}',
          );
        }

        await box.close();
      } catch (e) {
        debugPrint('❌ Background error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔐 PERMISSIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> requestPermission({
    bool isSilent = false,
    bool isAlarm = false,
  }) async {
    if (isSilent) {
      return (await Permission.notification.status).isGranted;
    }
    return (await Permission.notification.request()).isGranted;
  }

  static Future<bool> canScheduleExactAlarms() async {
    try {
      return (await Permission.scheduleExactAlarm.status)
          .isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool>
  requestExactAlarmPermissionUserDriven() async {
    try {
      final st =
      await Permission.scheduleExactAlarm.request();
      return st.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<void>
  promptAlarmPermissionsIfNeeded() async {
    await requestPermission(
        isSilent: false, isAlarm: true);
    await requestExactAlarmPermissionUserDriven();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 HABIT REMINDER + ALARM SCHEDULER
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> scheduleHabitReminder(
      Habit habit, {
        bool isSilent = false,
      }) async {
    if (!DatabaseService.areNotificationsEnabled()) return;
    if (!habit.reminderEnabled && !habit.alarmEnabled) return;

    await init();

    final granted = await requestPermission(
      isSilent: isSilent,
      isAlarm: habit.alarmEnabled,
    );
    if (!granted) return;

    if (habit.reminderEnabled) {
      await _scheduleDailyNotification(
          habit: habit, timeStr: habit.time);
    }

    if (habit.alarmEnabled) {
      await _scheduleFullScreenAlarm(habit: habit);
    }
  }

  // ─────────────────────────────────────────────
  // DAILY REMINDER
  // ─────────────────────────────────────────────

  static Future<void> _scheduleDailyNotification({
    required Habit habit,
    required String? timeStr,
  }) async {
    if (timeStr == null || timeStr.trim().isEmpty) return;

    final parts = timeStr.split(':');
    if (parts.length != 2) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (scheduledDate.isBefore(now) ||
        habit.isCompletedToday()) {
      scheduledDate =
          scheduledDate.add(const Duration(days: 1));
    }

    final message = _PsychEngine.buildMessage(
      habit: habit,
      ctx: _NotifContext.urgency,
    );
    final title = _PsychEngine.buildTitle(
      habit: habit,
      isMissed: habit.wasMissedYesterday(),
    );

    final androidDetails = AndroidNotificationDetails(
      channelHabitReminders,
      'Habit Reminders',
      importance: Importance.max,
      priority: Priority.max,
      icon: _notificationIcon,
      color: Color(habit.colorValue),
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
      ),
      actions: const [
        AndroidNotificationAction(
          'mark_done',
          '✅ I Did It',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'start_now',
          '🚀 Start Now',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final exactAllowed = await canScheduleExactAlarms();

    try {
      await _plugin.zonedSchedule(
        _reminderId(habit.id),
        title,
        message,
        scheduledDate,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation
            .absoluteTime,
        payload: habit.id,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
          '✅ Reminder: ${habit.name} @ $timeStr');
    } catch (e) {
      debugPrint('❌ Reminder schedule failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  // FULL-SCREEN ALARM
  // ─────────────────────────────────────────────

  static Future<void> _scheduleFullScreenAlarm({
    required Habit habit,
  }) async {
    final timeStr = habit.alarmTime ?? habit.time;
    if (timeStr == null || timeStr.trim().isEmpty) return;

    final parts = timeStr.split(':');
    if (parts.length != 2) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (scheduledDate.isBefore(now) ||
        habit.isCompletedToday()) {
      scheduledDate =
          scheduledDate.add(const Duration(days: 1));
    }

    final title = '${habit.emoji} ${habit.name}';
    final body =
    habit.alarmDescription?.trim().isNotEmpty == true
        ? habit.alarmDescription!
        : 'Time to build your habit! Tap to open.';

    final androidDetails = AndroidNotificationDetails(
      channelHabitAlarm,
      'Habit Alarms',
      channelDescription: 'High priority alarms for habits',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      icon: _notificationIcon,
      color: Color(habit.colorValue),
      playSound: true,
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      enableLights: true,
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
      ),
      actions: const [
        AndroidNotificationAction(
          'dismiss',
          '✓ I\'m Doing It',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze',
          '⏰ Snooze 5 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.zonedSchedule(
        _alarmId(habit.id),
        title,
        body,
        scheduledDate,
        NotificationDetails(android: androidDetails),
        androidScheduleMode:
        AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation
            .absoluteTime,
        payload: 'alarm:${habit.id}',
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
          '✅ Alarm: ${habit.name} @ $timeStr');
    } catch (e) {
      debugPrint('❌ Alarm schedule failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESCHEDULE ALL
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> rescheduleAllReminders() async {
    await _plugin.cancelAll();
    if (!DatabaseService.areNotificationsEnabled()) return;

    for (final habit in DatabaseService.getAllHabits()) {
      if (!habit.reminderEnabled && !habit.alarmEnabled)
        continue;
      await scheduleHabitReminder(habit, isSilent: true);
    }

    await scheduleEveningPsychologyNudges();
    debugPrint('✅ All reminders rescheduled');
  }

  static Future<void>
  rescheduleAllWithSmartMessages() async =>
      await rescheduleAllReminders();

  // ═══════════════════════════════════════════════════════════════════════════
  // PSYCHOLOGY NUDGES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> sendPsychologyNudge(Habit habit) async {
    if (!DatabaseService.areNotificationsEnabled() ||
        habit.isCompletedToday()) return;

    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final missed = habit.wasMissedYesterday();
    final ctx = missed
        ? _NotifContext.urgency
        : (DateTime.now().hour >= 20
        ? _NotifContext.smart
        : _NotifContext.identity);

    final message =
    _PsychEngine.buildMessage(habit: habit, ctx: ctx);
    final title = _PsychEngine.buildTitle(
        habit: habit, isMissed: missed);

    final androidDetails = AndroidNotificationDetails(
      channelPsychology,
      'Motivation Nudges',
      importance: Importance.max,
      priority: Priority.max,
      icon: _notificationIcon,
      color: const Color(0xFFEF4444),
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        summaryText: '🧠 AI Coach',
      ),
      actions: const [
        AndroidNotificationAction(
          'start_now',
          '🔥 Prove It Now',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'mark_done',
          '✅ Mission Accomplished',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.show(
        _psychId(habit.id),
        title,
        message,
        NotificationDetails(android: androidDetails),
        payload: habit.id,
      );
      await _saveNotificationToDb(
        title: title,
        body: message,
        type: 'psychology',
        payload: habit.id,
      );
    } catch (e) {
      debugPrint('❌ Psychology nudge failed: $e');
    }
  }

  static Future<void>
  sendPsychologyNudgesForIncompleteHabits() async {
    if (!DatabaseService.areNotificationsEnabled()) return;

    for (final habit in DatabaseService.getAllHabits()) {
      if (!habit.isCompletedToday() &&
          habit.isActiveToday()) {
        await sendPsychologyNudge(habit);
        await Future.delayed(
            const Duration(milliseconds: 400));
      }
    }
  }

  static Future<void>
  scheduleEveningPsychologyNudges() async {
    if (!DatabaseService.areNotificationsEnabled()) return;
    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final now = tz.TZDateTime.now(tz.local);

    for (final habit in DatabaseService.getAllHabits()) {
      if (!habit.isActiveToday()) continue;

      var evening = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        20,
        0,
      );

      if (evening.isBefore(now) ||
          (habit.isCompletedToday() &&
              evening.day == now.day)) {
        evening = evening.add(const Duration(days: 1));
      }

      final message = _PsychEngine.buildMessage(
        habit: habit,
        ctx: _NotifContext.smart,
      );
      final title = _PsychEngine.buildTitle(
          habit: habit, isMissed: false);

      final androidDetails = AndroidNotificationDetails(
        channelPsychology,
        'Motivation Nudges',
        importance: Importance.max,
        priority: Priority.max,
        icon: _notificationIcon,
        color: const Color(0xFF6C63FF),
        styleInformation: BigTextStyleInformation(
          message,
          htmlFormatBigText: true,
          contentTitle: '<b>$title</b>',
          htmlFormatContentTitle: true,
        ),
        actions: const [
          AndroidNotificationAction(
            'start_now',
            '🚀 Execute Now',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'mark_done',
            '✅ Done',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final exactAllowed = await canScheduleExactAlarms();

      try {
        await _plugin.zonedSchedule(
          (habit.id.hashCode.abs() + 95000) % 100000,
          title,
          message,
          evening,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: exactAllowed
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation
              .absoluteTime,
          payload: habit.id,
        );
      } catch (e) {
        debugPrint('❌ Evening nudge failed: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WARNING NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> sendXpLossWarning({
    required Habit habit,
    required int xpAtRisk,
  }) async {
    if (!DatabaseService.areNotificationsEnabled() ||
        habit.isCompletedToday()) return;

    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final title =
        "📉 $xpAtRisk XP at Risk: ${habit.emoji} ${habit.name}";
    final body =
        "You haven't done ${habit.name} today. Miss it and lose $xpAtRisk XP — plus your ${habit.currentStreak}-day streak breaks. Complete it now.";

    final androidDetails = AndroidNotificationDetails(
      channelPsychology,
      'Motivation Nudges',
      importance: Importance.max,
      priority: Priority.max,
      icon: _notificationIcon,
      color: const Color(0xFFEF4444),
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
      ),
      actions: const [
        AndroidNotificationAction(
          'start_now',
          '🛡️ Defend Streak',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'mark_done',
          '✅ Done It',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.show(
        (habit.id.hashCode.abs() + 97000) % 100000,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: habit.id,
      );
      await _saveNotificationToDb(
        title: title,
        body: body,
        type: 'warning',
        payload: habit.id,
      );
    } catch (e) {
      debugPrint('❌ XP loss warning failed: $e');
    }
  }

  static Future<void> sendLevelDownNotification({
    required int oldLevel,
    required int newLevel,
  }) async {
    if (!DatabaseService.areNotificationsEnabled()) return;
    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final title = '📉 Level Down: $oldLevel → $newLevel';
    final body =
        "Your level dropped from $oldLevel to $newLevel due to missed habits. "
        "Complete your habits today to rebuild your rank. "
        "Every champion has a setback. Come back stronger. 💪";

    final androidDetails = AndroidNotificationDetails(
      channelPsychology,
      'Motivation Nudges',
      importance: Importance.max,
      priority: Priority.max,
      icon: _notificationIcon,
      color: const Color(0xFFEF4444),
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
      ),
    );

    try {
      await _plugin.show(
        99990,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: 'level_down',
      );
      await _saveNotificationToDb(
        title: title,
        body: body,
        type: 'level_down',
        payload: null,
      );
    } catch (e) {
      debugPrint('❌ Level down notification failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SNOOZE ALARM
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> scheduleSnoozeAlarm({
    required Habit habit,
    Duration delay = const Duration(minutes: 5),
  }) async {
    await init();
    if (!DatabaseService.areNotificationsEnabled()) return;
    if (!(await requestPermission(
        isSilent: true, isAlarm: true))) return;

    final scheduledTime = tz.TZDateTime.from(
        DateTime.now().add(delay), tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelHabitAlarm,
      'Habit Alarms',
      channelDescription: 'Snoozed habit alarm',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      icon: _notificationIcon,
      color: Color(habit.colorValue),
      enableVibration: true,
      playSound: true,
      autoCancel: false,
      ongoing: true,
      actions: const [
        AndroidNotificationAction(
          'dismiss',
          '✓ I\'m Doing It',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze',
          '⏰ Snooze Again',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.zonedSchedule(
        _snoozeAlarmId(habit.id),
        '💤 Snoozed: ${habit.emoji} ${habit.name}',
        'Time to act! Don\'t skip this habit.',
        scheduledTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode:
        AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation
            .absoluteTime,
        payload: 'alarm:${habit.id}',
      );
      debugPrint(
          '✅ Snooze set: ${delay.inMinutes} min');
    } catch (e) {
      debugPrint('❌ Snooze failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANCEL
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> cancelAlarmNotification(
      String habitId) async =>
      await _plugin.cancel(_alarmId(habitId));

  static Future<void> cancelSnoozeAlarmNotification(
      String habitId) async =>
      await _plugin.cancel(_snoozeAlarmId(habitId));

  static Future<void> cancelHabitReminder(
      Habit habit) async {
    await _plugin.cancel(_reminderId(habit.id));
    await _plugin.cancel(_smartId(habit.id));
    await _plugin.cancel(_psychId(habit.id));
    await _plugin.cancel(_alarmId(habit.id));
    await _plugin.cancel(_snoozeAlarmId(habit.id));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISMISS ALARM FOR TODAY
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> dismissAlarmForToday(
      Habit habit) async {
    await init();
    await _plugin.cancel(_alarmId(habit.id));
    await _plugin.cancel(_snoozeAlarmId(habit.id));
    debugPrint('✅ Alarm dismissed: ${habit.name}');

    if (habit.alarmEnabled) {
      await _scheduleFullScreenAlarm(habit: habit);
      debugPrint(
          '✅ Tomorrow alarm rescheduled: ${habit.name}');
    }
  }

  static Future<void> cancelAllReminders() async =>
      await _plugin.cancelAll();

  // ═══════════════════════════════════════════════════════════════════════════
  // SMART REMINDERS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> sendSmartReminder(Habit habit) async {
    if (!DatabaseService.areNotificationsEnabled() ||
        habit.isCompletedToday()) return;

    await init();
    if (!(await requestPermission(
        isSilent: false, isAlarm: false))) return;

    final title = _PsychEngine.buildTitle(
      habit: habit,
      isMissed: habit.wasMissedYesterday(),
    );
    final message = _PsychEngine.buildMessage(
      habit: habit,
      ctx: _NotifContext.smart,
    );

    final androidDetails = AndroidNotificationDetails(
      channelSmartReminders,
      'Smart Reminders',
      importance: Importance.max,
      priority: Priority.max,
      icon: _notificationIcon,
      color: Color(habit.colorValue),
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
      ),
      actions: const [
        AndroidNotificationAction(
          'mark_done',
          '✅ Done',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'start_now',
          '🚀 Start',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.show(
        _smartId(habit.id),
        title,
        message,
        NotificationDetails(android: androidDetails),
        payload: habit.id,
      );
      await _saveNotificationToDb(
        title: title,
        body: message,
        type: 'smart',
        payload: habit.id,
      );
    } catch (e) {
      debugPrint('❌ Smart reminder failed: $e');
    }
  }

  static Future<void>
  scheduleSmartRemindersForMissedHabits() async {
    if (!DatabaseService.areNotificationsEnabled()) return;

    for (final habit in DatabaseService.getAllHabits()) {
      if (!habit.isCompletedToday() &&
          habit.wasMissedYesterday() &&
          habit.hasReasonForYesterday() &&
          habit.reminderEnabled &&
          habit.time != null) {
        await sendSmartReminder(habit);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INSTANT NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String type = 'local',
    String? payload,
    bool saveToDb = true,
  }) async {
    await init();
    if (!(await requestPermission(
        isSilent: false, isAlarm: false))) return;

    final emoji = _getEmojiForType(type);
    final displayTitle =
    title.startsWith(emoji) ? title : '$emoji $title';

    final androidDetails = AndroidNotificationDetails(
      channelInstant,
      'General Notifications',
      importance: Importance.max,
      priority: Priority.max,
      icon: _notificationIcon,
      color: const Color(0xFF6C63FF),
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: '<b>$displayTitle</b>',
        htmlFormatContentTitle: true,
      ),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      displayTitle,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );

    if (saveToDb) {
      await _saveNotificationToDb(
        title: displayTitle,
        body: body,
        type: type,
        payload: payload,
      );
    }
  }

  // ─────────────────────────────────────────────
  // POMODORO NOTIFICATION
  //
  // FIXED: আর নিজে notification show করে না।
  // TimerNotificationService (ID: 9999) একাই
  // pomodoro notification handle করে।
  // এই method শুধু সেখানে delegate করে।
  // Duplicate notification এর সমস্যা দূর হয়।
  // ─────────────────────────────────────────────
  static Future<void> showPomodoroNotification({
    required String title,
    required String body,
  }) async {
    // Delegate to TimerNotificationService
    // যাতে শুধু একটাই notification (ID: 9999) থাকে
    await TimerNotificationService.showCompletionNotification(
      title: title,
      body: body,
      isFocusComplete: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATABASE HELPER
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> _saveNotificationToDb({
    required String title,
    required String body,
    required String type,
    required String? payload,
  }) async {
    try {
      final appNotif = AppNotification(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
        title: title,
        body: body,
        receivedAt: DateTime.now(),
        isRead: false,
        type: type,
        payload: payload ?? '',
      );
      await DatabaseService.saveNotification(appNotif);
    } catch (e) {
      debugPrint('❌ Save notification DB failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DAILY SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> scheduleDailySummary() async {
    await init();
    if (!(await requestPermission(
        isSilent: false, isAlarm: false))) return;

    final now = tz.TZDateTime.now(tz.local);
    var eveningTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20,
      0,
    );

    if (eveningTime.isBefore(now)) {
      eveningTime =
          eveningTime.add(const Duration(days: 1));
    }

    const String title = '📊 Daily Summary';
    const String body =
        'Check how you did today! Review your habits and build your streaks.';

    final androidDetails = AndroidNotificationDetails(
      channelDailySummary,
      'Daily Summary',
      importance: Importance.high,
      priority: Priority.high,
      icon: _notificationIcon,
      color: const Color(0xFF6C63FF),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
      ),
    );

    final exactAllowed = await canScheduleExactAlarms();

    try {
      await _plugin.zonedSchedule(
        99999,
        title,
        body,
        eveningTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation
            .absoluteTime,
        payload: 'daily_summary',
      );
    } catch (e) {
      debugPrint('❌ Daily summary failed: $e');
    }
  }
}