// lib/services/alarm_service.dart

import 'dart:async';
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
      // ✅ STEP 1: TTS বন্ধ করো — sound block প্রতিরোধ
      try {
        await TtsService.stop();
      } catch (_) {}

      // ✅ STEP 2: Audio system settle হতে wait
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ STEP 3: Sound শুরু করো এবং wait করো
      await SoundService.startAlarmLoop();

      debugPrint('✅ Alarm sound started');

      // ✅ STEP 4: TTS sound এর পরে চালাও (delay দিয়ে)
      if (habit != null) {
        _speakWithDelay(habit);
      }
    } catch (e) {
      debugPrint('❌ AlarmService.startAlarm error: $e');
      _isRinging = false;
    }
  }

  // ─────────────────────────────────────────────
  // TTS — Sound এর পরে চালাও
  // ─────────────────────────────────────────────

  static void _speakWithDelay(Habit habit) {
    // ✅ 4 second delay — user প্রথমে sound শুনবে
    Future.delayed(const Duration(seconds: 4), () async {
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
    _isRinging = false;

    try {
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
  // ENSURE STOPPED — Force stop
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