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
// 🧠 ULTIMATE AI COACH & NEURO-PSYCHOLOGY ENGINE (ERROR-FREE)
// ═══════════════════════════════════════════════════════════════════════════════

class _PsychEngine {
  static final Random _rng = Random();

  // ১. Morning Priming
  static const List<String> _morningMessages = [
    "Wake up! The top 1% are already executing. Secure your first win this {day} with {habit}. ☀️",
    "A blank slate. A new {day}. Control your morning by knocking out {habit} right now.",
    "Don't check social media. Check off {habit}. Build your empire today.",
    "Morning momentum dictates your entire day. Start strong with {habit}. 🌅",
  ];

  // ২. Atomic Habits (Friction Reduction)
  static const List<String> _atomicMessages = [
    "Feeling lazy? Just do {habit} for 2 minutes. That's it. Just start. ⏱️",
    "You don't need motivation. You just need to start. Give {habit} exactly 120 seconds.",
    "Action creates motivation, not the other way around. Start {habit} right now.",
  ];

  // ৩. Weekend Warrior
  static const List<String> _weekendMessages = [
    "It's {day}. Average people take days off from their goals. You are not average. Do {habit}. ⚔️",
    "Weekends destroy weak routines. Protect your {streak}-day streak of {habit} today.",
    "Rest your body, but don't rest your discipline. {habit} still needs to be done.",
  ];

  // ৪. Social Proof & Reality Check
  static const List<String> _realityCheckMessages = [
    "Thousands of people are working on their goals right now. Are you going to let them win? Do {habit}. 🌍",
    "Stop scrolling. Stop delaying. Someone out there is working harder than you. Time for {habit}.",
    "The world doesn't care about your excuses. It only respects execution. Finish {habit}.",
  ];

  // ৫. Dark Psychology & Loss Aversion
  static const List<String> _darkPsychMessages = [
    "Go ahead, skip {habit}. It's easier to stay exactly where you are in life. 🤷‍♂️",
    "⚠️ CODE RED: Your {streak}-day legacy of {habit} is about to be erased tonight. Act now.",
    "Every time you delay {habit}, you train your brain to be a quitter. Break the loop.",
    "Are you really going to surrender to your own mind today? Prove yourself wrong. Do {habit}.",
  ];

  // ৬. Identity & Legacy
  static const List<String> _identityMessages = [
    "You are a master of discipline. {streak} days of {habit} proves it. Don't break the chain today. 👑",
    "You no longer 'try' to do {habit}. It is who you are. Keep building the legacy.",
    "A {streak}-day streak isn't an accident. It's a system. Execute {habit} and keep the system alive."
  ];

  // ৭. The Comeback
  static const List<String> _comebackMessages = [
    "You missed {habit} yesterday. Staying down is the real failure. Rise and execute {habit}. 🛡️",
    "Yesterday's skip was a glitch. Today is the real you. Rebuild the momentum with {habit}.",
    "Everyone falls. Only champions get back up. Start {habit} right now."
  ];

  static String _pick(List<String> list) => list[_rng.nextInt(list.length)];

  static String _getDayName() {
    final weekday = DateTime.now().weekday;
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  static String _fill(String template, {required String habitName, required int streak}) {
    return template
        .replaceAll('{habit}', habitName)
        .replaceAll('{streak}', '$streak')
        .replaceAll('{day}', _getDayName());
  }

  static String buildMessage({
    required Habit habit,
    required _NotifContext ctx,
  }) {
    final streak = habit.currentStreak;
    final missed = habit.wasMissedYesterday();
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekend = now.weekday == 6 || now.weekday == 7;

    String template;

    if (missed || streak == 0) {
      template = _pick(_comebackMessages);
    } else if (isWeekend && hour > 10 && hour < 20) {
      template = _rng.nextBool() ? _pick(_weekendMessages) : _pick(_atomicMessages);
    } else if (streak > 21 && hour < 20) {
      template = _pick(_identityMessages);
    } else if (hour < 11) {
      template = _pick(_morningMessages);
    } else if (hour >= 20 || ctx == _NotifContext.smart) {
      template = _pick(_darkPsychMessages);
    } else {
      final rand = _rng.nextDouble();
      if (rand < 0.35) {
        template = _pick(_atomicMessages);
      } else if (rand < 0.7) {
        template = _pick(_realityCheckMessages);
      } else {
        template = _pick(_darkPsychMessages);
      }
    }

    return _fill(template, habitName: habit.name, streak: streak);
  }

  static String buildTitle({
    required Habit habit,
    required bool isMissed,
  }) {
    final streak = habit.currentStreak;
    final hour = DateTime.now().hour;
    final isWeekend = DateTime.now().weekday >= 6;

    if (isMissed || streak == 0) return "${habit.emoji} The Comeback: ${habit.name}";
    if (hour < 11) return "${habit.emoji} Prime Your Mind: ${habit.name}";
    if (hour >= 20) return "🚨 FINAL CALL: ${habit.name} is dying!";
    if (isWeekend && hour < 18) return "⚔️ Weekend Warrior: ${habit.name}";
    if (streak >= 66) return "${habit.emoji} 👑 God Tier: ${habit.name}";
    if (streak >= 21) return "${habit.emoji} 🧬 Rewired Brain: ${habit.name}";
    if (streak >= 7) return "${habit.emoji} 🔥 Unstoppable: ${habit.name}";

    return "${habit.emoji} Time to Execute: ${habit.name}";
  }
}

enum _NotifContext { urgency, identity, smart, social }

// ═══════════════════════════════════════════════════════════════════════════════
// 🎯 NOTIFICATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

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

  static const String channelHabitReminders = 'habit_reminders_v4';
  static const String channelDailySummary = 'daily_summary_v4';
  static const String channelInstant = 'instant_notifications_v4';
  static const String channelSmartReminders = 'smart_reminders_v4';
  static const String channelHabitAlarm = 'habit_alarm_v4';
  static const String channelPsychology = 'psychology_nudges_v4';

  // ─────────────────────────────────────────────
  // NOTIFICATION IDs
  // ─────────────────────────────────────────────

  static int _reminderId(String habitId) => habitId.hashCode.abs() % 100000;
  static int _smartId(String habitId) => (habitId.hashCode.abs() + 50000) % 100000;
  static int _alarmId(String habitId) => (habitId.hashCode.abs() + 70000) % 100000;
  static int _snoozeAlarmId(String habitId) => (habitId.hashCode.abs() + 80000) % 100000;
  static int _psychId(String habitId) => (habitId.hashCode.abs() + 90000) % 100000;

  static String _getEmojiForType(String type) {
    switch (type.toLowerCase()) {
      case 'achievement':
      case 'milestone': return '🏆';
      case 'streak':
      case 'fire': return '🔥';
      case 'reminder': return '🔔';
      case 'smart': return '💡';
      case 'psychology': return '🧠';
      case 'summary': return '📊';
      case 'alarm': return '⏰';
      case 'warning':
      case 'missed': return '⚠️';
      case 'level_down': return '📉';
      case 'system': return '⚙️';
      case 'pomodoro':
      case 'study':
      case 'timer': return '📚';
      default: return '💬';
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

    const androidSettings = AndroidInitializationSettings(_notificationIcon);
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationTap,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(channelHabitReminders, 'Habit Reminders', importance: Importance.max, playSound: true, enableVibration: true, ledColor: Color(0xFF6C63FF), enableLights: true),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(channelDailySummary, 'Daily Summary', importance: Importance.high, playSound: false, enableVibration: false),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(channelInstant, 'General Notifications', importance: Importance.max, playSound: true, enableVibration: true),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(channelSmartReminders, 'Smart Reminders', importance: Importance.max, playSound: true, enableVibration: true, ledColor: Color(0xFFF59E0B), enableLights: true),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(channelHabitAlarm, 'Habit Alarms', description: 'Full-screen alarms that wake up your screen', importance: Importance.max, playSound: true, enableVibration: true, enableLights: true, showBadge: true, ledColor: Color(0xFFEF4444)),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(channelPsychology, 'Motivation Nudges', importance: Importance.max, playSound: true, enableVibration: true, ledColor: Color(0xFFEF4444), enableLights: true),
      );
    }

    _initialized = true;
    debugPrint('✅ AI NotificationService initialized');
  }

  static Future<String?> getInitialPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
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

  static void _handleNotificationTap(NotificationResponse response) {
    final String? payload = response.payload;
    final String? actionId = response.actionId;

    debugPrint('🔔 Tap | payload: "$payload" | action: "$actionId"');

    if (payload == null) return;

    if (payload.startsWith('alarm:')) {
      _launchPayloadHandled = true;
      final habitId = payload.replaceFirst('alarm:', '');

      if (actionId != null && (actionId == 'dismiss' || actionId == 'snooze')) {
        onAlarmActionTapped?.call(actionId, habitId);
        return;
      }

      onAlarmNotificationTapped?.call(habitId);
      return;
    }

    if (actionId != null) {
      onGeneralActionTapped?.call(actionId, payload);
      return;
    }

    onNotificationTapped?.call(payload);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚀 BACKGROUND TAP HANDLER
  // ═══════════════════════════════════════════════════════════════════════════

  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationTap(NotificationResponse response) async {
    debugPrint('🔔 Background tap | action: ${response.actionId}');

    final actionId = response.actionId;
    final payload = response.payload;

    if (payload == null || actionId == null) return;

    if (actionId == 'mark_done' || actionId == 'dismiss') {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        final dir = await path_provider.getApplicationDocumentsDirectory();
        Hive.init(dir.path);

        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(HabitAdapter());
        }

        final cleanPayload = payload.startsWith('alarm:') ? payload.replaceFirst('alarm:', '') : payload.replaceFirst('evening_nudge:', '');

        final box = await Hive.openBox<Habit>('habits');

        Habit? targetHabit;
        for (var h in box.values) {
          if (h.id == cleanPayload) {
            targetHabit = h;
            break;
          }
        }

        if (targetHabit != null && !targetHabit.isCompletedToday()) {
          final today = DateTime.now().toString().split(' ')[0];
          targetHabit.completedDates.add(today);
          targetHabit.currentStreak++;

          if (targetHabit.currentStreak > targetHabit.bestStreak) {
            targetHabit.bestStreak = targetHabit.currentStreak;
          }

          targetHabit.lastProgressDate = today;
          await box.put(targetHabit.id, targetHabit);
          debugPrint('✅ Background: Habit done — ${targetHabit.name}');
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

  static Future<bool> requestPermission({bool isSilent = false, bool isAlarm = false}) async {
    if (isSilent) return (await Permission.notification.status).isGranted;
    return (await Permission.notification.request()).isGranted;
  }

  static Future<bool> canScheduleExactAlarms() async {
    try { return (await Permission.scheduleExactAlarm.status).isGranted; } catch (_) { return false; }
  }

  static Future<bool> requestExactAlarmPermissionUserDriven() async {
    try { final st = await Permission.scheduleExactAlarm.request(); return st.isGranted; } catch (_) { return false; }
  }

  static Future<void> promptAlarmPermissionsIfNeeded() async {
    await requestPermission(isSilent: false, isAlarm: true);
    await requestExactAlarmPermissionUserDriven();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 HABIT REMINDER + ALARM SCHEDULER
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> scheduleHabitReminder(Habit habit, {bool isSilent = false}) async {
    if (!DatabaseService.areNotificationsEnabled()) return;
    if (!habit.reminderEnabled && !habit.alarmEnabled) return;

    await init();

    final granted = await requestPermission(isSilent: isSilent, isAlarm: habit.alarmEnabled);
    if (!granted) return;

    if (habit.reminderEnabled) {
      await _scheduleDailyNotification(habit: habit, timeStr: habit.time);
    }

    if (habit.alarmEnabled) {
      await _scheduleFullScreenAlarm(habit: habit);
    }
  }

  static Future<void> _scheduleDailyNotification({required Habit habit, required String? timeStr}) async {
    if (timeStr == null || timeStr.trim().isEmpty) return;

    final parts = timeStr.split(':');
    if (parts.length != 2) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));

    if (scheduledDate.isBefore(now) || habit.isCompletedToday()) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final message = _PsychEngine.buildMessage(habit: habit, ctx: _NotifContext.urgency);
    final title = _PsychEngine.buildTitle(habit: habit, isMissed: habit.wasMissedYesterday());

    final androidDetails = AndroidNotificationDetails(
      channelHabitReminders, 'Habit Reminders', importance: Importance.max, priority: Priority.max, icon: _notificationIcon, color: Color(habit.colorValue), enableVibration: true, playSound: true, autoCancel: true,
      styleInformation: BigTextStyleInformation(message, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true),
      actions: const [
        AndroidNotificationAction('mark_done', '✅ I Did It', showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction('start_now', '🚀 Start Now', showsUserInterface: true, cancelNotification: true),
      ],
    );

    final exactAllowed = await canScheduleExactAlarms();

    try {
      await _plugin.zonedSchedule(
        _reminderId(habit.id), title, message, scheduledDate, NotificationDetails(android: androidDetails),
        androidScheduleMode: exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: habit.id,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('❌ Reminder schedule failed: $e');
    }
  }

  static Future<void> _scheduleFullScreenAlarm({required Habit habit}) async {
    final timeStr = habit.alarmTime ?? habit.time;
    if (timeStr == null || timeStr.trim().isEmpty) return;

    final parts = timeStr.split(':');
    if (parts.length != 2) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));

    if (scheduledDate.isBefore(now) || habit.isCompletedToday()) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final title = '${habit.emoji} ${habit.name}';
    final body = habit.alarmDescription?.trim().isNotEmpty == true ? habit.alarmDescription! : 'Time to build your habit! Tap to open.';

    final androidDetails = AndroidNotificationDetails(
      channelHabitAlarm, 'Habit Alarms', channelDescription: 'High priority alarms for habits', importance: Importance.max, priority: Priority.max, fullScreenIntent: true, category: AndroidNotificationCategory.alarm, visibility: NotificationVisibility.public, audioAttributesUsage: AudioAttributesUsage.alarm, icon: _notificationIcon, color: Color(habit.colorValue), playSound: true, enableVibration: true, autoCancel: false, ongoing: true, enableLights: true,
      styleInformation: BigTextStyleInformation(body, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true),
      actions: const [
        AndroidNotificationAction('dismiss', '✓ I\'m Doing It', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('snooze', '⏰ Snooze 5 min', showsUserInterface: false, cancelNotification: true),
      ],
    );

    try {
      await _plugin.zonedSchedule(
        _alarmId(habit.id), title, body, scheduledDate, NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'alarm:${habit.id}',
        matchDateTimeComponents: DateTimeComponents.time,
      );
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
      if (!habit.reminderEnabled && !habit.alarmEnabled) continue;
      await scheduleHabitReminder(habit, isSilent: true);
    }

    await scheduleEveningPsychologyNudges();
    debugPrint('✅ All AI reminders rescheduled');
  }

  static Future<void> rescheduleAllWithSmartMessages() async => await rescheduleAllReminders();

  // ═══════════════════════════════════════════════════════════════════════════
  // PSYCHOLOGY NUDGES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> sendPsychologyNudge(Habit habit) async {
    if (!DatabaseService.areNotificationsEnabled() || habit.isCompletedToday()) return;

    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final missed = habit.wasMissedYesterday();
    final ctx = missed ? _NotifContext.urgency : (DateTime.now().hour >= 20 ? _NotifContext.smart : _NotifContext.identity);

    final message = _PsychEngine.buildMessage(habit: habit, ctx: ctx);
    final title = _PsychEngine.buildTitle(habit: habit, isMissed: missed);

    final androidDetails = AndroidNotificationDetails(
      channelPsychology, 'Motivation Nudges', importance: Importance.max, priority: Priority.max, icon: _notificationIcon, color: const Color(0xFFEF4444), enableVibration: true, playSound: true,
      styleInformation: BigTextStyleInformation(message, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true, summaryText: '🧠 AI Coach'),
      actions: const [
        AndroidNotificationAction('start_now', '🔥 Prove It Now', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('mark_done', '✅ Mission Accomplished', showsUserInterface: false, cancelNotification: true),
      ],
    );

    try {
      await _plugin.show(_psychId(habit.id), title, message, NotificationDetails(android: androidDetails), payload: habit.id);
      await _saveNotificationToDb(title: title, body: message, type: 'psychology', payload: habit.id);
    } catch (e) {
      debugPrint('❌ Psychology nudge failed: $e');
    }
  }

  static Future<void> sendPsychologyNudgesForIncompleteHabits() async {
    if (!DatabaseService.areNotificationsEnabled()) return;

    for (final habit in DatabaseService.getAllHabits()) {
      if (!habit.isCompletedToday()) {
        await sendPsychologyNudge(habit);
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  static Future<void> scheduleEveningPsychologyNudges() async {
    if (!DatabaseService.areNotificationsEnabled()) return;
    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final now = tz.TZDateTime.now(tz.local);

    for (final habit in DatabaseService.getAllHabits()) {
      if (habit.isCompletedToday()) continue;

      var evening = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);

      if (evening.isBefore(now)) {
        evening = evening.add(const Duration(days: 1));
      }

      final message = _PsychEngine.buildMessage(habit: habit, ctx: _NotifContext.smart);
      final title = _PsychEngine.buildTitle(habit: habit, isMissed: false);

      final androidDetails = AndroidNotificationDetails(
        channelPsychology, 'Motivation Nudges', importance: Importance.max, priority: Priority.max, icon: _notificationIcon, color: const Color(0xFF6C63FF),
        styleInformation: BigTextStyleInformation(message, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true),
        actions: const [
          AndroidNotificationAction('start_now', '🚀 Execute Now', showsUserInterface: true, cancelNotification: true),
          AndroidNotificationAction('mark_done', '✅ Done', showsUserInterface: false, cancelNotification: true),
        ],
      );

      final exactAllowed = await canScheduleExactAlarms();

      try {
        await _plugin.zonedSchedule(
          (habit.id.hashCode.abs() + 95000) % 100000, title, message, evening, NotificationDetails(android: androidDetails),
          androidScheduleMode: exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'evening_nudge:${habit.id}', // ✅ ROUTING PAYLOAD FIXED
        );
      } catch (e) {
        debugPrint('❌ Evening nudge failed: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WARNING NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> sendXpLossWarning({required Habit habit, required int xpAtRisk}) async {
    if (!DatabaseService.areNotificationsEnabled() || habit.isCompletedToday()) return;

    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final title = "📉 $xpAtRisk XP at Risk: ${habit.emoji} ${habit.name}";
    final body = "You haven't done ${habit.name} today. Miss it and lose $xpAtRisk XP — plus your ${habit.currentStreak}-day streak breaks. Complete it now.";

    final androidDetails = AndroidNotificationDetails(
      channelPsychology, 'Motivation Nudges', importance: Importance.max, priority: Priority.max, icon: _notificationIcon, color: const Color(0xFFEF4444),
      styleInformation: BigTextStyleInformation(body, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true),
      actions: const [
        AndroidNotificationAction('start_now', '🛡️ Defend Streak', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('mark_done', '✅ Done It', showsUserInterface: false, cancelNotification: true),
      ],
    );

    try {
      await _plugin.show((habit.id.hashCode.abs() + 97000) % 100000, title, body, NotificationDetails(android: androidDetails), payload: habit.id);
      await _saveNotificationToDb(title: title, body: body, type: 'warning', payload: habit.id);
    } catch (e) {
      debugPrint('❌ XP loss warning failed: $e');
    }
  }

  static Future<void> sendLevelDownNotification({required int oldLevel, required int newLevel}) async {
    if (!DatabaseService.areNotificationsEnabled()) return;
    await init();
    if (!(await requestPermission(isSilent: true))) return;

    final title = '📉 Level Down: $oldLevel → $newLevel';
    final body = "Your level dropped from $oldLevel to $newLevel due to missed habits. Complete your habits today to rebuild your rank. Every champion has a setback. Come back stronger. 💪";

    final androidDetails = AndroidNotificationDetails(
      channelPsychology, 'Motivation Nudges', importance: Importance.max, priority: Priority.max, icon: _notificationIcon, color: const Color(0xFFEF4444),
      styleInformation: BigTextStyleInformation(body, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true),
    );

    try {
      await _plugin.show(99990, title, body, NotificationDetails(android: androidDetails), payload: 'level_down');
      await _saveNotificationToDb(title: title, body: body, type: 'level_down', payload: null);
    } catch (e) {
      debugPrint('❌ Level down notification failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SNOOZE ALARM
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> scheduleSnoozeAlarm({required Habit habit, Duration delay = const Duration(minutes: 5)}) async {
    await init();
    if (!DatabaseService.areNotificationsEnabled()) return;
    if (!(await requestPermission(isSilent: true, isAlarm: true))) return;

    final scheduledTime = tz.TZDateTime.from(DateTime.now().add(delay), tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelHabitAlarm, 'Habit Alarms', channelDescription: 'Snoozed habit alarm', importance: Importance.max, priority: Priority.max, fullScreenIntent: true, category: AndroidNotificationCategory.alarm, visibility: NotificationVisibility.public, audioAttributesUsage: AudioAttributesUsage.alarm, icon: _notificationIcon, color: Color(habit.colorValue), enableVibration: true, playSound: true, autoCancel: false, ongoing: true,
      actions: const [
        AndroidNotificationAction('dismiss', '✓ I\'m Doing It', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('snooze', '⏰ Snooze Again', showsUserInterface: false, cancelNotification: true),
      ],
    );

    try {
      await _plugin.zonedSchedule(
        _snoozeAlarmId(habit.id), '💤 Snoozed: ${habit.emoji} ${habit.name}', 'Time to act! Don\'t skip this habit.', scheduledTime, NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'alarm:${habit.id}',
      );
    } catch (e) {
      debugPrint('❌ Snooze failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANCEL
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> cancelAlarmNotification(String habitId) async => await _plugin.cancel(_alarmId(habitId));
  static Future<void> cancelSnoozeAlarmNotification(String habitId) async => await _plugin.cancel(_snoozeAlarmId(habitId));

  static Future<void> cancelHabitReminder(Habit habit) async {
    await _plugin.cancel(_reminderId(habit.id));
    await _plugin.cancel(_smartId(habit.id));
    await _plugin.cancel(_psychId(habit.id));
    await _plugin.cancel(_alarmId(habit.id));
    await _plugin.cancel(_snoozeAlarmId(habit.id));
  }

  static Future<void> dismissAlarmForToday(Habit habit) async {
    await init();
    await _plugin.cancel(_alarmId(habit.id));
    await _plugin.cancel(_snoozeAlarmId(habit.id));
    if (habit.alarmEnabled) await _scheduleFullScreenAlarm(habit: habit);
  }

  static Future<void> cancelAllReminders() async => await _plugin.cancelAll();

  // ═══════════════════════════════════════════════════════════════════════════
  // SMART REMINDERS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> sendSmartReminder(Habit habit) async {
    if (!DatabaseService.areNotificationsEnabled() || habit.isCompletedToday()) return;

    await init();
    if (!(await requestPermission(isSilent: false, isAlarm: false))) return;

    final title = _PsychEngine.buildTitle(habit: habit, isMissed: habit.wasMissedYesterday());
    final message = _PsychEngine.buildMessage(habit: habit, ctx: _NotifContext.smart);

    final androidDetails = AndroidNotificationDetails(
      channelSmartReminders, 'Smart Reminders', importance: Importance.max, priority: Priority.max, icon: _notificationIcon, color: Color(habit.colorValue), enableVibration: true, playSound: true,
      styleInformation: BigTextStyleInformation(message, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true),
      actions: const [
        AndroidNotificationAction('mark_done', '✅ Done', showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction('start_now', '🚀 Start', showsUserInterface: true, cancelNotification: true),
      ],
    );

    try {
      await _plugin.show(_smartId(habit.id), title, message, NotificationDetails(android: androidDetails), payload: habit.id);
      await _saveNotificationToDb(title: title, body: message, type: 'smart', payload: habit.id);
    } catch (e) {
      debugPrint('❌ Smart reminder failed: $e');
    }
  }

  static Future<void> scheduleSmartRemindersForMissedHabits() async {
    if (!DatabaseService.areNotificationsEnabled()) return;

    for (final habit in DatabaseService.getAllHabits()) {
      if (!habit.isCompletedToday() && habit.wasMissedYesterday() && habit.hasReasonForYesterday() && habit.reminderEnabled && habit.time != null) {
        await sendSmartReminder(habit);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INSTANT NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> showInstantNotification({required String title, required String body, String type = 'local', String? payload, bool saveToDb = true}) async {
    await init();
    if (!(await requestPermission(isSilent: false, isAlarm: false))) return;

    final emoji = _getEmojiForType(type);
    final displayTitle = title.startsWith(emoji) ? title : '$emoji $title';

    final androidDetails = AndroidNotificationDetails(
      channelInstant, 'General Notifications', importance: Importance.max, priority: Priority.max, icon: _notificationIcon, color: const Color(0xFF6C63FF),
      styleInformation: BigTextStyleInformation(body, htmlFormatBigText: true, contentTitle: '<b>$displayTitle</b>', htmlFormatContentTitle: true),
    );

    await _plugin.show(DateTime.now().millisecondsSinceEpoch % 100000, displayTitle, body, NotificationDetails(android: androidDetails), payload: payload);
    if (saveToDb) await _saveNotificationToDb(title: displayTitle, body: body, type: type, payload: payload);
  }

  static Future<void> showPomodoroNotification({required String title, required String body}) async {
    await TimerNotificationService.showCompletionNotification(title: title, body: body, isFocusComplete: true);
  }

  static Future<void> _saveNotificationToDb({required String title, required String body, required String type, required String? payload}) async {
    try {
      final appNotif = AppNotification(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, body: body, receivedAt: DateTime.now(), isRead: false, type: type, payload: payload ?? '');
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
    if (!(await requestPermission(isSilent: false, isAlarm: false))) return;

    final now = tz.TZDateTime.now(tz.local);
    var eveningTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);

    if (eveningTime.isBefore(now)) {
      eveningTime = eveningTime.add(const Duration(days: 1));
    }

    const String title = '📊 Daily Summary';
    const String body = 'Check how you did today! Review your habits and build your streaks.';

    final androidDetails = AndroidNotificationDetails(
      channelDailySummary, 'Daily Summary', importance: Importance.high, priority: Priority.high, icon: _notificationIcon, color: const Color(0xFF6C63FF), playSound: true, enableVibration: true,
      styleInformation: BigTextStyleInformation(body, htmlFormatBigText: true, contentTitle: '<b>$title</b>', htmlFormatContentTitle: true),
    );

    final exactAllowed = await canScheduleExactAlarms();

    try {
      await _plugin.zonedSchedule(
        99999, title, body, eveningTime, NotificationDetails(android: androidDetails),
        androidScheduleMode: exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'daily_summary',
      );
    } catch (e) {
      debugPrint('❌ Daily summary failed: $e');
    }
  }
}