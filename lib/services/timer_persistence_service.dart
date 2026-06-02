// lib/services/timer_persistence_service.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/study_routine_model.dart';
import 'advanced_pomodoro_service.dart';

// ═══════════════════════════════════════
// TIMER PERSISTENCE SERVICE
// ═══════════════════════════════════════
// Purpose: Save & restore timer state to/from Hive
// so timer survives app restart/background

class TimerPersistenceService {
  static const String _boxName = 'timer_state';
  static late Box _box;

  // ═══════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    debugPrint('✅ TimerPersistenceService initialized');
  }

  // ═══════════════════════════════════════
  // SAVE TIMER STATE
  // ═══════════════════════════════════════
  static Future<void> saveTimerState({
    required PomodoroState currentState,
    required int remainingSeconds,
    required int totalDurationSeconds,
    required TimerStatus timerStatus,
    required bool isRoutineMode,
    required int completedPomodoros,
    required String currentSubjectName,
    required int currentSubjectColorValue,
    String? activeRoutineId,
    int? currentRoutineIndex,
    int? routineSessionsCompleted,
    DateTime? sessionStartTime,
  }) async {
    try {
      await _box.put('has_active_timer', true);
      await _box.put('current_state', currentState.toString());
      await _box.put('remaining_seconds', remainingSeconds);
      await _box.put('total_duration_seconds', totalDurationSeconds);
      await _box.put('timer_status', timerStatus.toString());
      await _box.put('is_routine_mode', isRoutineMode);
      await _box.put('completed_pomodoros', completedPomodoros);
      await _box.put('current_subject_name', currentSubjectName);
      await _box.put('current_subject_color_value', currentSubjectColorValue);
      await _box.put('active_routine_id', activeRoutineId);
      await _box.put('current_routine_index', currentRoutineIndex);
      await _box.put('routine_sessions_completed', routineSessionsCompleted);
      await _box.put('session_start_time', sessionStartTime?.millisecondsSinceEpoch);
      await _box.put('last_saved_time', DateTime.now().millisecondsSinceEpoch);

      debugPrint('💾 Timer state saved: $currentState, ${remainingSeconds}s remaining');
    } catch (e) {
      debugPrint('❌ Error saving timer state: $e');
    }
  }

  // ═══════════════════════════════════════
  // LOAD TIMER STATE
  // ═══════════════════════════════════════
  static Map<String, dynamic>? loadTimerState() {
    try {
      final hasActiveTimer = _box.get('has_active_timer', defaultValue: false);
      if (!hasActiveTimer) {
        debugPrint('ℹ️ No active timer found');
        return null;
      }

      final lastSavedTime = _box.get('last_saved_time', defaultValue: 0);
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = now - lastSavedTime;

      // If more than 24 hours, clear state
      if (elapsedMs > 24 * 60 * 60 * 1000) {
        debugPrint('⏰ Timer state too old, clearing');
        clearTimerState();
        return null;
      }

      final currentStateStr = _box.get('current_state', defaultValue: '');
      final timerStatusStr = _box.get('timer_status', defaultValue: '');

      PomodoroState? currentState;
      if (currentStateStr.contains('focus')) {
        currentState = PomodoroState.focus;
      } else if (currentStateStr.contains('shortBreak')) {
        currentState = PomodoroState.shortBreak;
      } else if (currentStateStr.contains('longBreak')) {
        currentState = PomodoroState.longBreak;
      } else {
        currentState = PomodoroState.idle;
      }

      TimerStatus? timerStatus;
      if (timerStatusStr.contains('running')) {
        timerStatus = TimerStatus.running;
      } else if (timerStatusStr.contains('paused')) {
        timerStatus = TimerStatus.paused;
      } else {
        timerStatus = TimerStatus.stopped;
      }

      int remainingSeconds = _box.get('remaining_seconds', defaultValue: 0);

      // If timer was running, calculate elapsed time
      if (timerStatus == TimerStatus.running) {
        final elapsedSeconds = (elapsedMs / 1000).floor();
        remainingSeconds = (remainingSeconds - elapsedSeconds).clamp(0, 999999);
        debugPrint('⏱️ Timer was running, adjusted remaining: ${remainingSeconds}s');
      }

      final sessionStartTimeMs = _box.get('session_start_time');
      DateTime? sessionStartTime;
      if (sessionStartTimeMs != null && sessionStartTimeMs > 0) {
        sessionStartTime = DateTime.fromMillisecondsSinceEpoch(sessionStartTimeMs);
      }

      final state = {
        'current_state': currentState,
        'remaining_seconds': remainingSeconds,
        'total_duration_seconds': _box.get('total_duration_seconds', defaultValue: 0),
        'timer_status': timerStatus,
        'is_routine_mode': _box.get('is_routine_mode', defaultValue: false),
        'completed_pomodoros': _box.get('completed_pomodoros', defaultValue: 0),
        'current_subject_name': _box.get('current_subject_name', defaultValue: 'General'),
        'current_subject_color_value': _box.get('current_subject_color_value', defaultValue: 0xFF6C63FF),
        'active_routine_id': _box.get('active_routine_id'),
        'current_routine_index': _box.get('current_routine_index', defaultValue: 0),
        'routine_sessions_completed': _box.get('routine_sessions_completed', defaultValue: 0),
        'session_start_time': sessionStartTime,
      };

      debugPrint('📂 Timer state loaded successfully');
      return state;
    } catch (e) {
      debugPrint('❌ Error loading timer state: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // CLEAR TIMER STATE
  // ═══════════════════════════════════════
  static Future<void> clearTimerState() async {
    try {
      await _box.clear();
      debugPrint('🗑️ Timer state cleared');
    } catch (e) {
      debugPrint('❌ Error clearing timer state: $e');
    }
  }

  // ═══════════════════════════════════════
  // CHECK IF TIMER IS ACTIVE
  // ═══════════════════════════════════════
  static bool hasActiveTimer() {
    return _box.get('has_active_timer', defaultValue: false);
  }

  // ═══════════════════════════════════════
  // UPDATE REMAINING SECONDS (called every tick)
  // ═══════════════════════════════════════
  static Future<void> updateRemainingSeconds(int seconds) async {
    try {
      await _box.put('remaining_seconds', seconds);
      await _box.put('last_saved_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('❌ Error updating remaining seconds: $e');
    }
  }

  // ═══════════════════════════════════════
  // UPDATE TIMER STATUS
  // ═══════════════════════════════════════
  static Future<void> updateTimerStatus(TimerStatus status) async {
    try {
      await _box.put('timer_status', status.toString());
      await _box.put('last_saved_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('❌ Error updating timer status: $e');
    }
  }
}