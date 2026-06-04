// lib/services/alarm_service.dart

import 'package:flutter/foundation.dart';

import 'sound_service.dart';
import 'tts_service.dart';
import '../models/habit_model.dart';

class AlarmService {
  static bool _isRinging = false;
  static bool get isRinging => _isRinging;

  // ─────────────────────────────────────────────
  // START ALARM
  // ─────────────────────────────────────────────

  static Future<void> startAlarm({Habit? habit}) async {
    if (_isRinging) {
      debugPrint('⚠️ Alarm already ringing — skipping');
      return;
    }

    _isRinging = true;
    debugPrint('🔔 AlarmService: starting alarm');

    try {
      // ✅ Sound শুরু করো — await করো না
      // unawaited কারণ loop চলতে থাকবে
      SoundService.startAlarmLoop().catchError((e) {
        debugPrint('❌ Sound loop error: $e');
        return null;
      });

      // ✅ TTS আলাদা Future এ চালাও
      // Sound কে block করবে না
      if (habit != null) {
        _speakWithDelay(habit);
      }
    } catch (e) {
      debugPrint('❌ AlarmService.startAlarm error: $e');
      _isRinging = false;
    }
  }

  // ─────────────────────────────────────────────
  // TTS — আলাদাভাবে চালাও
  // Sound interrupt করবে না
  // ─────────────────────────────────────────────

  static void _speakWithDelay(Habit habit) {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      // ✅ Alarm বন্ধ হয়ে গেলে TTS বলবে না
      if (!_isRinging) {
        debugPrint('🔇 Alarm stopped before TTS — skipping');
        return;
      }

      try {
        await TtsService.speakAlarmForced(
          'Wake up! Time for ${habit.name}. '
              '${habit.currentStreak > 0 ? "You have a ${habit.currentStreak} day streak. Don\'t break it!" : "Start your habit now!"}',
        );
      } catch (e) {
        debugPrint('❌ TTS error: $e');
      }
    });
  }

  // ─────────────────────────────────────────────
  // STOP ALARM
  // ─────────────────────────────────────────────

  static Future<void> stopAlarm() async {
    if (!_isRinging) {
      debugPrint('⚠️ Alarm not ringing — nothing to stop');
      return;
    }

    debugPrint('🔕 AlarmService: stopping alarm');

    // ✅ আগে flag reset করো
    // TTS delay check এর জন্য
    _isRinging = false;

    try {
      // ✅ Sound এবং TTS একসাথে বন্ধ করো
      await Future.wait([
        SoundService.stopAlarmLoop().catchError((e) {
          debugPrint('❌ Sound stop error: $e');
          return null;
        }),
        TtsService.stop().catchError((e) {
          debugPrint('❌ TTS stop error: $e');
          return null;
        }),
      ]);

      debugPrint('✅ Alarm fully stopped');
    } catch (e) {
      debugPrint('❌ AlarmService.stopAlarm error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // ENSURE STOPPED
  // dispose() থেকে call হয়
  // Force stop — _isRinging check নেই
  // ─────────────────────────────────────────────

  static Future<void> ensureStopped() async {
    _isRinging = false;

    try {
      await Future.wait([
        SoundService.stopAlarmLoop().catchError((e) {
          debugPrint('❌ ensureStopped sound error: $e');
          return null;
        }),
        TtsService.stop().catchError((e) {
          debugPrint('❌ ensureStopped TTS error: $e');
          return null;
        }),
      ]);
      debugPrint('✅ AlarmService.ensureStopped done');
    } catch (e) {
      debugPrint('❌ ensureStopped error: $e');
    }
  }
}