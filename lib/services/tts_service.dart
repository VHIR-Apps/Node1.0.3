// lib/services/tts_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'database_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TTS SERVICE
// ═══════════════════════════════════════════════════════════════════════════════
//
// ✅ speakAlarmForced() — bypasses all settings, ALWAYS speaks for alarm
// ✅ speakAlarm() — respects DatabaseService.isTtsEnabled()
// ✅ speak() — routine mode TTS only
// ✅ Proper init guard + stop-before-speak
// ✅ Null-safe, production-grade
// ═══════════════════════════════════════════════════════════════════════════════

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _isInitializing = false;
  static bool _ttsEnabled = false;

  static const double _defaultSpeechRate = 0.45;
  static const double _defaultVolume = 0.90;
  static const double _defaultPitch = 1.0;
  static const double _alarmSpeechRate = 0.42;
  static const double _alarmVolume = 1.0;

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────

  static Future<bool> init() async {
    if (_initialized) return true;

    if (_isInitializing) {
      int waited = 0;
      while (_isInitializing && waited < 3000) {
        await Future.delayed(const Duration(milliseconds: 50));
        waited += 50;
      }
      return _initialized;
    }

    _isInitializing = true;

    try {
      // Check engines
      final engines = await _tts.getEngines;
      if (engines == null || (engines as List).isEmpty) {
        debugPrint('⚠️ No TTS engine on device');
        _isInitializing = false;
        return false;
      }

      // Language
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(_defaultSpeechRate);
      await _tts.setVolume(_defaultVolume);
      await _tts.setPitch(_defaultPitch);
      await _tts.setQueueMode(0);

      _tts.setCompletionHandler(() {
        debugPrint('🔊 TTS completed');
      });

      _tts.setErrorHandler((msg) {
        debugPrint('❌ TTS error: $msg');
      });

      _tts.setCancelHandler(() {
        debugPrint('🔇 TTS cancelled');
      });

      _initialized = true;
      debugPrint('✅ TTS Service initialized');
      return true;
    } catch (e) {
      debugPrint('❌ TTS init error: $e');
      _initialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  // ─────────────────────────────────────────────
  // ENABLE / DISABLE — Routine mode only
  // ─────────────────────────────────────────────

  static void setEnabled(bool enabled) {
    _ttsEnabled = enabled;
    debugPrint(
      '🔊 TTS routine mode: ${enabled ? "ENABLED" : "DISABLED"}',
    );
  }

  static bool get isEnabled => _ttsEnabled;

  // ─────────────────────────────────────────────
  // SPEAK — Routine mode only
  // ─────────────────────────────────────────────

  static Future<void> speak(String text) async {
    if (!_ttsEnabled) {
      debugPrint('🔇 TTS blocked: routine TTS disabled');
      return;
    }

    if (text.trim().isEmpty) return;

    final ready = await init();
    if (!ready) {
      debugPrint('🔇 TTS blocked: init failed');
      return;
    }

    try {
      await _tts.stop();
      await _tts.setSpeechRate(_defaultSpeechRate);
      await _tts.setVolume(_defaultVolume);
      await _tts.setPitch(_defaultPitch);
      await _tts.speak(text.trim());
      debugPrint('🔊 TTS: "${text.trim()}"');
    } catch (e) {
      debugPrint('❌ TTS speak error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // SPEAK ALARM FORCED
  // ─────────────────────────────────────────────
  //
  // ✅ ALWAYS speaks — bypasses ALL settings
  // ✅ Used by AlarmService for alarm TTS
  // ✅ Max volume, slower rate for clarity
  // ✅ No DatabaseService.isTtsEnabled() check

  static Future<void> speakAlarmForced(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      debugPrint('🔇 speakAlarmForced: empty text');
      return;
    }

    // ✅ Always init — no settings check
    final ready = await init();
    if (!ready) {
      debugPrint('⚠️ TTS engine not available — skipping alarm TTS');
      return;
    }

    try {
      // Stop anything currently speaking
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 150));

      // Max volume for alarm
      await _tts.setSpeechRate(_alarmSpeechRate);
      await _tts.setVolume(_alarmVolume);
      await _tts.setPitch(_defaultPitch);

      final result = await _tts.speak(trimmed);

      if (result == 1) {
        debugPrint('🔊 Alarm TTS forced: "$trimmed"');
      } else {
        debugPrint('⚠️ Alarm TTS result: $result for "$trimmed"');
      }
    } catch (e) {
      debugPrint('❌ speakAlarmForced error: $e');
    } finally {
      // Restore defaults
      Future.delayed(const Duration(milliseconds: 200), () async {
        try {
          await _tts.setSpeechRate(_defaultSpeechRate);
          await _tts.setVolume(_defaultVolume);
          await _tts.setPitch(_defaultPitch);
        } catch (_) {}
      });
    }
  }

  // ─────────────────────────────────────────────
  // SPEAK ALARM — Respects settings
  // ─────────────────────────────────────────────
  //
  // This version checks DatabaseService.isTtsEnabled().
  // Use speakAlarmForced() for alarm TTS instead.

  static Future<void> speakAlarm(
      String description, {
        double rate = _alarmSpeechRate,
        double volume = _alarmVolume,
      }) async {
    bool globalTtsEnabled = false;
    try {
      globalTtsEnabled = DatabaseService.isTtsEnabled();
    } catch (e) {
      debugPrint('⚠️ TTS check error: $e');
      return;
    }

    if (!globalTtsEnabled) {
      debugPrint('🔇 Alarm TTS blocked: disabled in settings');
      return;
    }

    await speakAlarmForced(description);
  }

  // ─────────────────────────────────────────────
  // SPEAK HABIT REMINDER
  // ─────────────────────────────────────────────

  static Future<void> speakHabitReminder({
    required String habitName,
    String? alarmDescription,
  }) async {
    final ready = await init();
    if (!ready) return;

    try {
      final text = (alarmDescription?.trim().isNotEmpty == true)
          ? alarmDescription!.trim()
          : 'Time for $habitName. Keep going!';

      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 150));
      await _tts.setSpeechRate(_defaultSpeechRate);
      await _tts.setVolume(_defaultVolume);
      await _tts.setPitch(_defaultPitch);
      await _tts.speak(text);
      debugPrint('🔊 Habit reminder TTS: "$text"');
    } catch (e) {
      debugPrint('❌ TTS reminder error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // STOP
  // ─────────────────────────────────────────────

  static Future<void> stop() async {
    try {
      await _tts.stop();
      debugPrint('🔇 TTS stopped');
    } catch (e) {
      debugPrint('❌ TTS stop error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────

  static void dispose() {
    try {
      _tts.stop();
      _initialized = false;
      debugPrint('🔇 TTS disposed');
    } catch (e) {
      debugPrint('❌ TTS dispose error: $e');
    }
  }
}