// lib/services/alarm_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/habit_model.dart';
import 'database_service.dart';
import 'sound_service.dart';
import 'tts_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ALARM SERVICE
// ═══════════════════════════════════════════════════════════════════════════════
//
// ✅ Native alarm sound via STREAM_ALARM (SoundService → platform channel)
// ✅ TTS speaks habit name always — even without alarm description
// ✅ TTS always enabled for alarm (independent of settings)
// ✅ Auto-stop after countdown
// ✅ onAlarmShouldClose → AlarmScreen pops itself
// ✅ Race condition safe
// ✅ Google Play policy safe
// ═══════════════════════════════════════════════════════════════════════════════

class AlarmService {
  // ── Timers ──
  static Timer? _ttsTimer;
  static Timer? _autoStopTimer;
  static Timer? _autoSnoozeTimer;

  // ── State ──
  static bool _isAlarmActive = false;
  static bool _isDismissed = false;
  static bool _isSnoozedByUser = false;

  static String? _activeHabitId;
  static Habit? _activeHabit;

  static int _currentRepeatCycle = 0;
  static int _maxRepeatCycles = 1;

  static int _sessionToken = 0;
  static Future<void> _serial = Future<void>.value();

  // ── Public hooks ──
  static Function(Habit habit)? onAlarmTriggered;
  static Function()? onAlarmShouldClose;

  // ── ValueNotifiers ──
  static final ValueNotifier<bool> isAlarmActiveNotifier =
  ValueNotifier<bool>(false);
  static final ValueNotifier<String?> activeHabitIdNotifier =
  ValueNotifier<String?>(null);

  // ── Getters ──
  static bool get isAlarmActive => _isAlarmActive;
  static String? get activeHabitId => _activeHabitId;
  static Habit? get activeHabit => _activeHabit;
  static int get currentRepeatCycle => _currentRepeatCycle;
  static int get maxRepeatCycles => _maxRepeatCycles;

  // ─────────────────────────────────────────────
  // SERIAL QUEUE
  // ─────────────────────────────────────────────

  static Future<void> _runExclusive(
      Future<void> Function() action,
      ) async {
    _serial = _serial.then((_) => action()).catchError((e, st) {
      debugPrint('❌ AlarmService serial error: $e');
      if (kDebugMode) debugPrint('$st');
    });
    return _serial;
  }

  // ─────────────────────────────────────────────
  // STATE HELPER
  // ─────────────────────────────────────────────

  static void _setActiveState({
    required bool isActive,
    required Habit? habit,
  }) {
    _isAlarmActive = isActive;
    _activeHabit = habit;
    _activeHabitId = habit?.id;
    isAlarmActiveNotifier.value = _isAlarmActive;
    activeHabitIdNotifier.value = _activeHabitId;
  }

  // ─────────────────────────────────────────────
  // START ALARM
  // ─────────────────────────────────────────────

  static Future<void> startAlarm(
      Habit habit, {
        bool isAutoSnooze = false,
      }) async {
    await _runExclusive(() async {
      final int token = ++_sessionToken;

      if (!isAutoSnooze) {
        await _stopAlarmInternal(resetAll: true);
        _currentRepeatCycle = 0;
        _isDismissed = false;
        _isSnoozedByUser = false;
        _maxRepeatCycles = habit.alarmRepeatCount.clamp(1, 10);
      }

      if (_isDismissed) {
        debugPrint('⛔ Alarm start blocked: dismissed');
        return;
      }

      _setActiveState(isActive: true, habit: habit);
      _currentRepeatCycle++;

      debugPrint(
        '🔔 Alarm cycle $_currentRepeatCycle/$_maxRepeatCycles — ${habit.name}',
      );

      // 1. Native alarm sound (STREAM_ALARM — bypasses DND/silent)
      await _startSound(token);

      // 2. TTS — always enabled for alarm, no settings check
      await _startTts(habit, token);

      // 3. Auto-stop after countdown
      _startAutoStopTimer(habit, token);
    });
  }

  static Future<void> startAlarmByHabitId(
      String habitId, {
        bool isAutoSnooze = false,
      }) async {
    final habit = _findHabitById(habitId);
    if (habit == null) {
      debugPrint('❌ startAlarmByHabitId: not found — $habitId');
      return;
    }
    await startAlarm(habit, isAutoSnooze: isAutoSnooze);
  }

  static Future<void> handleAlarmActionFromNotification({
    required String actionId,
    required String habitId,
  }) async {
    debugPrint('🔔 Notification action: $actionId / $habitId');

    if (actionId == 'dismiss') {
      await dismissAlarm();
      return;
    }

    if (actionId == 'snooze') {
      if (_activeHabitId == null) {
        final habit = _findHabitById(habitId);
        if (habit != null) await startAlarm(habit);
      }
      await snoozeAlarm();
      return;
    }

    debugPrint('⚠️ Unknown actionId: $actionId');
  }

  // ─────────────────────────────────────────────
  // SOUND
  // ─────────────────────────────────────────────

  static Future<void> _startSound(int token) async {
    if (token != _sessionToken || _isDismissed) return;

    try {
      await SoundService.startAlarmLoop();
      debugPrint('🔊 Alarm sound started');
    } catch (e) {
      debugPrint('❌ Alarm sound error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // TTS
  // ─────────────────────────────────────────────

  static Future<void> _startTts(Habit habit, int token) async {
    _ttsTimer?.cancel();
    _ttsTimer = null;

    if (token != _sessionToken || _isDismissed) return;

    // ✅ KEY FIX: TTS is ALWAYS active for alarm
    // Does NOT depend on DatabaseService.isTtsEnabled()
    // Alarm TTS is a core alarm feature, not a general TTS setting
    //
    // Build TTS text:
    // - If alarm description exists → use it
    // - If not → speak habit name as default
    final ttsText = _buildTtsText(habit);
    final ttsRepeats = habit.ttsRepeatCount.clamp(1, 5);

    debugPrint('🔊 Alarm TTS will speak: "$ttsText" ($ttsRepeats times)');

    int spokenCount = 0;

    Future<void> speakOnce() async {
      if (token != _sessionToken) return;
      if (!_isAlarmActive || _isDismissed) return;

      try {
        // Use speakAlarmForced — bypasses isTtsEnabled() check
        await TtsService.speakAlarmForced(ttsText);
      } catch (e) {
        debugPrint('❌ Alarm TTS error: $e');
      }
    }

    // Wait for native sound to start first
    await Future.delayed(const Duration(milliseconds: 1800));
    if (token != _sessionToken) return;
    if (!_isAlarmActive || _isDismissed) return;

    await speakOnce();
    spokenCount++;

    if (ttsRepeats > 1) {
      _ttsTimer = Timer.periodic(
        const Duration(seconds: 8),
            (timer) async {
          if (token != _sessionToken) {
            timer.cancel();
            return;
          }
          if (!_isAlarmActive || _isDismissed) {
            timer.cancel();
            return;
          }
          if (spokenCount >= ttsRepeats) {
            timer.cancel();
            return;
          }
          spokenCount++;
          await speakOnce();
        },
      );
    }
  }

  /// Build TTS text with guaranteed fallback.
  static String _buildTtsText(Habit habit) {
    final description = habit.alarmDescription?.trim();

    if (description != null && description.isNotEmpty) {
      return description;
    }

    // Default: always speak habit name
    return 'Time for ${habit.name}. '
        '${habit.currentStreak > 0 ? "You have a ${habit.currentStreak} day streak. Keep it alive!" : "Start your habit now!"}';
  }

  // ─────────────────────────────────────────────
  // AUTO-STOP TIMER
  // ─────────────────────────────────────────────

  static void _startAutoStopTimer(Habit habit, int token) {
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(
      const Duration(seconds: 30),
          () async {
        await _runExclusive(() async {
          if (token != _sessionToken) return;
          await _handleAutoStop(habit);
        });
      },
    );
  }

  static Future<void> _handleAutoStop(Habit habit) async {
    if (_isDismissed || !_isAlarmActive) return;

    debugPrint(
      '⏸️ Auto-stop after 30s '
          '(cycle $_currentRepeatCycle/$_maxRepeatCycles)',
    );

    await _stopCurrentPlaybackOnly();

    if (_currentRepeatCycle < _maxRepeatCycles) {
      await _scheduleNextAutoSnooze(habit);
    } else {
      debugPrint('✅ Max cycles done — fully stopping');
      await _stopAlarmInternal(resetAll: true);

      // ✅ Signal AlarmScreen to close
      _notifyClose();
    }
  }

  static void _notifyClose() {
    try {
      onAlarmShouldClose?.call();
    } catch (e) {
      debugPrint('⚠️ onAlarmShouldClose error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // AUTO-SNOOZE
  // ─────────────────────────────────────────────

  static Future<void> _scheduleNextAutoSnooze(Habit habit) async {
    _autoSnoozeTimer?.cancel();

    debugPrint(
      '⏰ Auto-snooze in 5 min '
          '(${_currentRepeatCycle + 1}/$_maxRepeatCycles)',
    );

    _autoSnoozeTimer = Timer(
      const Duration(minutes: 5),
          () async {
        await _runExclusive(() async {
          if (_isDismissed) {
            debugPrint('⛔ Auto-snooze cancelled: dismissed');
            return;
          }

          if (_isSnoozedByUser) {
            _isSnoozedByUser = false;
          }

          Habit? habitToUse = _activeHabit ?? _findHabitById(habit.id);

          if (habitToUse == null) {
            debugPrint('❌ No habit for auto-snooze');
            return;
          }

          await startAlarm(habitToUse, isAutoSnooze: true);
          onAlarmTriggered?.call(habitToUse);
        });
      },
    );
  }

  // ─────────────────────────────────────────────
  // USER ACTIONS
  // ─────────────────────────────────────────────

  static Future<void> snoozeAlarm() async {
    await _runExclusive(() async {
      if (_activeHabit == null || _isDismissed) return;

      debugPrint('⏰ User snoozed');
      _isSnoozedByUser = true;

      await _stopCurrentPlaybackOnly();
      await _scheduleNextAutoSnooze(_activeHabit!);
    });
  }

  static Future<void> dismissAlarm() async {
    await _runExclusive(() async {
      debugPrint('✅ User dismissed alarm');
      _isDismissed = true;
      await _stopAlarmInternal(resetAll: true);
    });
  }

  static Future<void> stopAlarm() async {
    await _runExclusive(() async {
      await _stopAlarmInternal(resetAll: true);
    });
  }

  // ─────────────────────────────────────────────
  // INTERNAL STOP HELPERS
  // ─────────────────────────────────────────────

  static Future<void> _stopCurrentPlaybackOnly() async {
    _sessionToken++;
    _setActiveState(isActive: false, habit: _activeHabit);

    _ttsTimer?.cancel();
    _ttsTimer = null;

    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    try {
      await SoundService.stopAlarmLoop();
    } catch (e) {
      debugPrint('⚠️ stopAlarmLoop: $e');
    }

    try {
      await TtsService.stop();
    } catch (e) {
      debugPrint('⚠️ TTS stop: $e');
    }

    debugPrint('⏹️ Alarm playback stopped');
  }

  static Future<void> _stopAlarmInternal({
    required bool resetAll,
  }) async {
    _sessionToken++;
    _isSnoozedByUser = false;

    _ttsTimer?.cancel();
    _ttsTimer = null;

    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    _autoSnoozeTimer?.cancel();
    _autoSnoozeTimer = null;

    try {
      await SoundService.stopAlarmLoop();
    } catch (e) {
      debugPrint('⚠️ stopAlarmLoop: $e');
    }

    try {
      await TtsService.stop();
    } catch (e) {
      debugPrint('⚠️ TTS stop: $e');
    }

    if (resetAll) {
      _setActiveState(isActive: false, habit: null);
      _activeHabitId = null;
      _activeHabit = null;
      _currentRepeatCycle = 0;
      _maxRepeatCycles = 1;
    } else {
      _setActiveState(isActive: false, habit: _activeHabit);
    }

    debugPrint('🔕 Alarm fully stopped');
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  static Habit? _findHabitById(String habitId) {
    try {
      final habits = DatabaseService.getAllHabits();
      for (final h in habits) {
        if (h.id == habitId) return h;
      }
    } catch (e) {
      debugPrint('❌ _findHabitById: $e');
    }
    return null;
  }
}