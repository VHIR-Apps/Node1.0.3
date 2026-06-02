// lib/services/advanced_pomodoro_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/app_config.dart';
import '../models/study_session_model.dart';
import '../models/study_routine_model.dart';
import 'database_service.dart';
import 'sound_service.dart';
import 'badge_service.dart';
import 'tts_service.dart';
import 'timer_persistence_service.dart';
import 'timer_notification_service.dart';
import 'background_timer_service.dart';

// ═══════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════

enum PomodoroState { idle, focus, shortBreak, longBreak }

enum PlayMode { manual, routine }

enum TimerStatus { stopped, running, paused }

// ═══════════════════════════════════════
// ADVANCED POMODORO SERVICE
// ═══════════════════════════════════════

class AdvancedPomodoroService {
  // ═══════════════════════════════════════
  // SINGLETON PATTERN
  // ═══════════════════════════════════════
  static final AdvancedPomodoroService _instance = AdvancedPomodoroService._internal();
  factory AdvancedPomodoroService() => _instance;
  AdvancedPomodoroService._internal();

  // ═══════════════════════════════════════
  // STATE NOTIFIERS - Timer
  // ═══════════════════════════════════════
  static final ValueNotifier<int> remainingSeconds = ValueNotifier(0);
  static final ValueNotifier<double> progress = ValueNotifier(1.0);
  static final ValueNotifier<TimerStatus> timerStatus = ValueNotifier(TimerStatus.stopped);
  static final ValueNotifier<PomodoroState> currentState = ValueNotifier(PomodoroState.idle);
  static final ValueNotifier<int> completedPomodoros = ValueNotifier(0);
  static final ValueNotifier<int> totalFocusMinutesToday = ValueNotifier(0);

  // ═══════════════════════════════════════
  // STATE NOTIFIERS - Routine Mode
  // ═══════════════════════════════════════
  static final ValueNotifier<PlayMode> playMode = ValueNotifier(PlayMode.manual);
  static final ValueNotifier<StudyRoutine?> activeRoutine = ValueNotifier(null);
  static final ValueNotifier<int> currentRoutineIndex = ValueNotifier(0);
  static final ValueNotifier<int> routineSessionsCompleted = ValueNotifier(0);
  static final ValueNotifier<bool> isRoutineMode = ValueNotifier(false);
  static final ValueNotifier<String> currentSubjectName = ValueNotifier('General');
  static final ValueNotifier<Color> currentSubjectColor = ValueNotifier(const Color(0xFF6C63FF));

  // ═══════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════
  static bool autoPlayEnabled = false;
  static bool ttsAnnouncementsEnabled = true;
  static bool keepScreenOn = true;
  static bool vibrateOnComplete = true;

  // ═══════════════════════════════════════
  // TIMER INTERNALS
  // ═══════════════════════════════════════
  static DateTime? _sessionStartTime;
  static int _totalDurationSeconds = 0;
  static bool _wakelockEnabled = false;
  static bool _isRestoring = false;

  // ═══════════════════════════════════════
  // CALLBACKS
  // ═══════════════════════════════════════
  static VoidCallback? onSessionComplete;
  static VoidCallback? onRoutineComplete;
  static VoidCallback? onStateChange;

  // ═══════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════
  static Future<void> init() async {
    await TimerPersistenceService.init();
    await TimerNotificationService.init();

    await BackgroundTimerService.init();
    _setupBackgroundListeners();

    _loadSettings();
    _loadTodayStats();

    await _restoreTimerState();

    if (currentState.value == PomodoroState.idle) {
      _loadDurationForState(PomodoroState.focus);
    }

    debugPrint('🍅 AdvancedPomodoroService initialized');
  }

  // ═══════════════════════════════════════
  // BACKGROUND SERVICE LISTENERS
  // ═══════════════════════════════════════
  static void _setupBackgroundListeners() {
    BackgroundTimerService.onTick((remaining) {
      if (timerStatus.value == TimerStatus.running) {
        remainingSeconds.value = remaining;
        progress.value = _totalDurationSeconds > 0
            ? remainingSeconds.value / _totalDurationSeconds
            : 0.0;

        if (remainingSeconds.value % 5 == 0) {
          TimerPersistenceService.updateRemainingSeconds(remainingSeconds.value);
        }
      }
    });

    BackgroundTimerService.onComplete(() {
      if (timerStatus.value == TimerStatus.running) {
        remainingSeconds.value = 0;
        progress.value = 0.0;
        pause();
        _handleSessionComplete(skipped: false);
      }
    });
  }

  static void _loadSettings() {
    autoPlayEnabled = DatabaseService.getAutoPlayEnabled();
    ttsAnnouncementsEnabled = DatabaseService.getPomodoroTtsEnabled();
    keepScreenOn = DatabaseService.getKeepScreenOn();
    vibrateOnComplete = DatabaseService.getVibrateOnComplete();

    TtsService.setEnabled(false);
  }

  static void _loadTodayStats() {
    totalFocusMinutesToday.value = DatabaseService.getTotalStudyMinutesToday();
  }

  // ═══════════════════════════════════════
  // RESTORE TIMER STATE
  // ═══════════════════════════════════════
  static Future<void> _restoreTimerState() async {
    _isRestoring = true;

    try {
      final savedState = TimerPersistenceService.loadTimerState();
      if (savedState == null) {
        _isRestoring = false;
        return;
      }

      currentState.value = savedState['current_state'] ?? PomodoroState.idle;
      remainingSeconds.value = savedState['remaining_seconds'] ?? 0;
      _totalDurationSeconds = savedState['total_duration_seconds'] ?? 0;
      timerStatus.value = savedState['timer_status'] ?? TimerStatus.stopped;
      completedPomodoros.value = savedState['completed_pomodoros'] ?? 0;

      currentSubjectName.value = savedState['current_subject_name'] ?? 'General';
      currentSubjectColor.value = Color(savedState['current_subject_color_value'] ?? 0xFF6C63FF);

      isRoutineMode.value = savedState['is_routine_mode'] ?? false;

      if (isRoutineMode.value) {
        final routineId = savedState['active_routine_id'];
        if (routineId != null) {
          final routine = DatabaseService.getRoutineById(routineId);
          if (routine != null) {
            activeRoutine.value = routine;
            currentRoutineIndex.value = savedState['current_routine_index'] ?? 0;
            routineSessionsCompleted.value = savedState['routine_sessions_completed'] ?? 0;
            playMode.value = PlayMode.routine;
          } else {
            isRoutineMode.value = false;
            activeRoutine.value = null;
          }
        }
      }

      _sessionStartTime = savedState['session_start_time'];

      if (_totalDurationSeconds > 0) {
        progress.value = remainingSeconds.value / _totalDurationSeconds;
      }

      debugPrint('✅ Timer state restored: ${currentState.value}, ${remainingSeconds.value}s');

      if (timerStatus.value == TimerStatus.running && remainingSeconds.value > 0) {
        debugPrint('▶️ Auto-resuming background timer...');
        _resumeAfterRestore();
      }

    } catch (e) {
      debugPrint('❌ Error restoring timer state: $e');
      await TimerPersistenceService.clearTimerState();
    }

    _isRestoring = false;
  }

  static void _resumeAfterRestore() {
    timerStatus.value = TimerStatus.running;
    _enableWakelock();

    BackgroundTimerService.startTimer(
      remainingSeconds.value,
      stateLabel,
    );

    onStateChange?.call();
  }

  // ═══════════════════════════════════════
  // SUBJECT SELECTION (Manual Mode)
  // ═══════════════════════════════════════
  static void setSubject(String subject, Color color) {
    currentSubjectName.value = subject;
    currentSubjectColor.value = color;
    debugPrint('📚 Subject set: $subject');
  }

  // ═══════════════════════════════════════
  // LOAD DURATION FOR STATE
  // ═══════════════════════════════════════
  static void _loadDurationForState(PomodoroState state) {
    int minutes = 25;

    if (isRoutineMode.value && activeRoutine.value != null) {
      final routine = activeRoutine.value!;
      if (currentRoutineIndex.value < routine.sessions.length) {
        final session = routine.sessions[currentRoutineIndex.value];

        if (state == PomodoroState.focus) {
          minutes = session.durationMinutes;
          currentSubjectName.value = session.subjectName;
          currentSubjectColor.value = Color(session.subjectColorValue);
        } else if (state == PomodoroState.shortBreak) {
          minutes = session.breakDurationMinutes;
        } else if (state == PomodoroState.longBreak) {
          minutes = DatabaseService.getPomodoroLongBreakMinutes();
        }
      }
    } else {
      switch (state) {
        case PomodoroState.focus:
          minutes = DatabaseService.getPomodoroFocusMinutes();
          break;
        case PomodoroState.shortBreak:
          minutes = DatabaseService.getPomodoroShortBreakMinutes();
          break;
        case PomodoroState.longBreak:
          minutes = DatabaseService.getPomodoroLongBreakMinutes();
          break;
        case PomodoroState.idle:
          minutes = DatabaseService.getPomodoroFocusMinutes();
          break;
      }
    }

    _totalDurationSeconds = minutes * 60;
    remainingSeconds.value = _totalDurationSeconds;
    progress.value = 1.0;
  }

  // ═══════════════════════════════════════
  // TIMER CONTROLS
  // ═══════════════════════════════════════
  static Future<void> start() async {
    if (timerStatus.value == TimerStatus.running) return;

    if (currentState.value == PomodoroState.idle || remainingSeconds.value <= 0) {
      currentState.value = PomodoroState.focus;
      _loadDurationForState(PomodoroState.focus);
    }

    // ✅ CRITICAL FIX: Set session start time when starting a FOCUS session
    if (currentState.value == PomodoroState.focus && _sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
      debugPrint('⏱️ Focus session started at: $_sessionStartTime');
    }

    timerStatus.value = TimerStatus.running;
    _enableWakelock();

    await BackgroundTimerService.startTimer(
      remainingSeconds.value,
      stateLabel,
    );

    if (ttsAnnouncementsEnabled && isRoutineMode.value) {
      TtsService.setEnabled(true);
      await _announceSessionStart();
    }

    await _saveCurrentState();
    onStateChange?.call();
    debugPrint('▶️ Timer started: ${currentState.value}');
  }

  static Future<void> pause() async {
    timerStatus.value = TimerStatus.paused;
    _disableWakelock();

    BackgroundTimerService.pauseTimer();

    await _saveCurrentState();
    onStateChange?.call();
    debugPrint('⏸️ Timer paused');
  }

  static Future<void> resume() async {
    if (timerStatus.value != TimerStatus.paused) return;
    if (remainingSeconds.value <= 0) return;

    timerStatus.value = TimerStatus.running;
    _enableWakelock();

    BackgroundTimerService.resumeTimer(
      remainingSeconds.value,
      stateLabel,
    );

    await _saveCurrentState();
    onStateChange?.call();
    debugPrint('▶️ Timer resumed');
  }

  static Future<void> stop() async {
    timerStatus.value = TimerStatus.stopped;
    _sessionStartTime = null;
    _disableWakelock();

    BackgroundTimerService.stopTimer();

    await TimerPersistenceService.clearTimerState();
    await TimerNotificationService.cancelTimerNotification();

    onStateChange?.call();
    debugPrint('⏹️ Timer stopped');
  }

  static Future<void> reset() async {
    await stop();
    currentState.value = PomodoroState.idle;
    completedPomodoros.value = 0;
    _loadDurationForState(PomodoroState.focus);
    onStateChange?.call();
    debugPrint('🔄 Timer reset');
  }

  static Future<void> skip() async {
    await pause();
    await _handleSessionComplete(skipped: true);
    debugPrint('⏭️ Session skipped');
  }

  // ═══════════════════════════════════════
  // ✅ SESSION COMPLETION LOGIC (PROFESSIONAL FIX)
  // ═══════════════════════════════════════
  static Future<void> _handleSessionComplete({required bool skipped}) async {
    final now = DateTime.now();

    // ─────────────────────────────────────────────
    // ✅ FOCUS SESSION COMPLETION
    // ─────────────────────────────────────────────
    if (currentState.value == PomodoroState.focus) {
      completedPomodoros.value++;

      // ✅ CRITICAL FIX: Only count ELAPSED TIME
      int actualMinutes = 0;

      if (_sessionStartTime != null) {
        // Calculate how long the session actually ran
        final elapsedDuration = now.difference(_sessionStartTime!);
        actualMinutes = elapsedDuration.inMinutes;

        // Minimum 1 minute if session ran for any time
        if (actualMinutes < 1 && elapsedDuration.inSeconds > 0) {
          actualMinutes = 1;
        }

        debugPrint('⏱️ Session duration: ${elapsedDuration.inSeconds}s → $actualMinutes min (${skipped ? "SKIPPED" : "COMPLETED"})');
      } else {
        // Fallback: if no start time, assume 1 minute
        actualMinutes = 1;
        debugPrint('⚠️ No session start time found, defaulting to 1 minute');
      }

      // ✅ Save study session with ACTUAL elapsed time
      final session = StudySession(
        id: 'study_${now.millisecondsSinceEpoch}',
        subjectName: currentSubjectName.value,
        subjectColorValue: currentSubjectColor.value.value,
        startTime: _sessionStartTime ?? now.subtract(Duration(minutes: actualMinutes)),
        endTime: now,
        durationMinutes: actualMinutes,
        sessionType: 'focus',
        completedAt: now,
        pomodoroCount: completedPomodoros.value,
        isCompleted: !skipped,
      );

      await DatabaseService.saveStudySession(session);
      await BadgeService.onStudySessionCompleted(session);

      _loadTodayStats();

      SoundService.playPomodoroComplete();
      if (vibrateOnComplete) {
        HapticFeedback.heavyImpact();
      }

      await TimerNotificationService.showCompletionNotification(
        title: skipped ? '⏭️ Session Skipped' : '🎉 Focus Complete!',
        body: skipped
            ? 'You studied ${currentSubjectName.value} for $actualMinutes minutes.'
            : 'Great job! You completed $actualMinutes minutes of ${currentSubjectName.value}.',
        isFocusComplete: true,
      );

      if (ttsAnnouncementsEnabled && isRoutineMode.value) {
        TtsService.setEnabled(true);
        await TtsService.speak(
          skipped
              ? 'Session skipped. You studied ${currentSubjectName.value} for $actualMinutes minutes.'
              : 'Focus session completed. Great job! You studied ${currentSubjectName.value} for $actualMinutes minutes.',
        );
      }

      // ✅ Reset session start time
      _sessionStartTime = null;

      // ─────────────────────────────────────────────
      // ✅ MOVE TO NEXT STATE (ROUTINE OR MANUAL)
      // ─────────────────────────────────────────────
      if (isRoutineMode.value && activeRoutine.value != null) {
        final routine = activeRoutine.value!;
        final currentSession = routine.sessions[currentRoutineIndex.value];
        routineSessionsCompleted.value++;

        if (currentSession.includeBreak) {
          currentState.value = PomodoroState.shortBreak;
          _loadDurationForState(PomodoroState.shortBreak);
        } else {
          await _moveToNextRoutineSession();
          return;
        }
      } else {
        if (completedPomodoros.value % AppConfig.pomodorosUntilLongBreak == 0) {
          currentState.value = PomodoroState.longBreak;
        } else {
          currentState.value = PomodoroState.shortBreak;
        }
        _loadDurationForState(currentState.value);
      }

      SoundService.playBreakStart();

      if (ttsAnnouncementsEnabled && isRoutineMode.value) {
        final breakMins = remainingSeconds.value ~/ 60;
        await Future.delayed(const Duration(seconds: 2));
        await TtsService.speak('Break time started. Relax for $breakMins minutes.');
      }

    }
    // ─────────────────────────────────────────────
    // ✅ BREAK COMPLETION (No study time added)
    // ─────────────────────────────────────────────
    else {
      SoundService.playBreakEnd();
      if (vibrateOnComplete) {
        HapticFeedback.mediumImpact();
      }

      await TimerNotificationService.showCompletionNotification(
        title: '⏰ Break Over!',
        body: 'Ready to focus again?',
        isFocusComplete: false,
      );

      if (ttsAnnouncementsEnabled && isRoutineMode.value) {
        await TtsService.speak('Break time is over. Let\'s get back to work!');
      }

      if (isRoutineMode.value && activeRoutine.value != null) {
        await _moveToNextRoutineSession();
        return;
      } else {
        currentState.value = PomodoroState.focus;
        _loadDurationForState(PomodoroState.focus);
      }
    }

    await _saveCurrentState();
    onStateChange?.call();
    onSessionComplete?.call();

    if (_shouldAutoPlay()) {
      await Future.delayed(const Duration(seconds: 3));
      if (timerStatus.value == TimerStatus.stopped || timerStatus.value == TimerStatus.paused) {
        await start();
      }
    }
  }

  // ═══════════════════════════════════════
  // ROUTINE CONTROLS
  // ═══════════════════════════════════════
  static Future<void> _moveToNextRoutineSession() async {
    final routine = activeRoutine.value;
    if (routine == null) return;

    currentRoutineIndex.value++;

    if (currentRoutineIndex.value >= routine.sessions.length) {
      await _completeRoutine();
      return;
    }

    currentState.value = PomodoroState.focus;
    _loadDurationForState(PomodoroState.focus);

    if (ttsAnnouncementsEnabled && isRoutineMode.value) {
      TtsService.setEnabled(true);
      Future.delayed(const Duration(seconds: 1), () {
        _announceSessionStart();
      });
    }

    await _saveCurrentState();
    onStateChange?.call();

    if (_shouldAutoPlay()) {
      Future.delayed(const Duration(seconds: 3), () {
        if (timerStatus.value != TimerStatus.running) {
          start();
        }
      });
    }
  }

  static Future<void> _completeRoutine() async {
    final routine = activeRoutine.value;
    if (routine == null) return;

    routine.timesCompleted++;
    routine.lastPlayedAt = DateTime.now();
    await DatabaseService.updateRoutine(routine);

    SoundService.playLevelUp();
    HapticFeedback.heavyImpact();

    await TimerNotificationService.showCompletionNotification(
      title: '🎊 Routine Complete!',
      body: 'Amazing! You finished "${routine.name}" with ${routine.sessionCount} sessions!',
      isFocusComplete: true,
    );

    if (ttsAnnouncementsEnabled && isRoutineMode.value) {
      TtsService.setEnabled(true);
      await TtsService.speak(
        'Congratulations! You have completed the ${routine.name} routine. '
            'Total study time: ${routine.totalFocusMinutes} minutes. Amazing work!',
      );
    }

    onRoutineComplete?.call();
    await stopRoutine();
  }

  static Future<void> startRoutine(StudyRoutine routine) async {
    await stopRoutine();
    await stop();

    activeRoutine.value = routine;
    isRoutineMode.value = true;
    playMode.value = PlayMode.routine;
    currentRoutineIndex.value = 0;
    routineSessionsCompleted.value = 0;
    completedPomodoros.value = 0;

    currentState.value = PomodoroState.focus;
    _loadDurationForState(PomodoroState.focus);

    routine.isActive = true;

    if (ttsAnnouncementsEnabled && routine.ttsEnabled) {
      TtsService.setEnabled(true);
      await TtsService.speak(
        'Starting ${routine.name} routine. '
            '${routine.sessionCount} sessions, total ${routine.getFormattedDuration()}. '
            'First subject: ${routine.sessions[0].subjectName}.',
      );
    }

    await _saveCurrentState();
    onStateChange?.call();

    if (routine.autoPlayEnabled) {
      Future.delayed(const Duration(seconds: 3), () {
        start();
      });
    }

    debugPrint('🍅 Routine started: ${routine.name}');
  }

  static Future<void> stopRoutine() async {
    if (activeRoutine.value != null) {
      activeRoutine.value!.isActive = false;
    }

    await stop();
    activeRoutine.value = null;
    isRoutineMode.value = false;
    playMode.value = PlayMode.manual;
    currentRoutineIndex.value = 0;
    routineSessionsCompleted.value = 0;
    currentState.value = PomodoroState.idle;
    _loadDurationForState(PomodoroState.focus);

    TtsService.setEnabled(false);

    await TimerPersistenceService.clearTimerState();
    onStateChange?.call();
    debugPrint('🍅 Routine stopped');
  }

  // ═══════════════════════════════════════
  // HELPERS AND SETTINGS TOGGLES
  // ═══════════════════════════════════════
  static Future<void> _announceSessionStart() async {
    if (!ttsAnnouncementsEnabled || !isRoutineMode.value) return;

    String message = '';

    if (activeRoutine.value != null) {
      final routine = activeRoutine.value!;
      if (currentRoutineIndex.value < routine.sessions.length) {
        final session = routine.sessions[currentRoutineIndex.value];
        final sessionNum = currentRoutineIndex.value + 1;
        final totalSessions = routine.sessions.length;

        if (session.customMessage != null && session.customMessage!.isNotEmpty) {
          message = session.customMessage!;
        } else {
          message = 'Session $sessionNum of $totalSessions. '
              'Now studying ${session.subjectName}. '
              'Focus for ${session.durationMinutes} minutes.';
        }
      }
    }

    if (message.isNotEmpty) {
      await TtsService.speak(message);
    }
  }

  static bool _shouldAutoPlay() {
    if (isRoutineMode.value && activeRoutine.value != null) {
      return activeRoutine.value!.autoPlayEnabled;
    }
    return autoPlayEnabled;
  }

  static Future<void> _saveCurrentState() async {
    if (_isRestoring) return;

    await TimerPersistenceService.saveTimerState(
      currentState: currentState.value,
      remainingSeconds: remainingSeconds.value,
      totalDurationSeconds: _totalDurationSeconds,
      timerStatus: timerStatus.value,
      isRoutineMode: isRoutineMode.value,
      completedPomodoros: completedPomodoros.value,
      currentSubjectName: currentSubjectName.value,
      currentSubjectColorValue: currentSubjectColor.value.value,
      activeRoutineId: activeRoutine.value?.id,
      currentRoutineIndex: currentRoutineIndex.value,
      routineSessionsCompleted: routineSessionsCompleted.value,
      sessionStartTime: _sessionStartTime,
    );
  }

  static Future<void> _enableWakelock() async {
    if (_wakelockEnabled || !keepScreenOn) return;
    try {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
      debugPrint('🔒 Wakelock enabled');
    } catch (e) {
      debugPrint('⚠️ Wakelock enable error: $e');
    }
  }

  static Future<void> _disableWakelock() async {
    if (!_wakelockEnabled) return;
    try {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
      debugPrint('🔓 Wakelock disabled');
    } catch (e) {
      debugPrint('⚠️ Wakelock disable error: $e');
    }
  }

  static Future<void> toggleAutoPlay() async {
    autoPlayEnabled = !autoPlayEnabled;
    await DatabaseService.setAutoPlayEnabled(autoPlayEnabled);
    debugPrint('🔄 Auto-play: $autoPlayEnabled');
  }

  static Future<void> setAutoPlay(bool enabled) async {
    autoPlayEnabled = enabled;
    await DatabaseService.setAutoPlayEnabled(enabled);
  }

  static Future<void> toggleTtsAnnouncements() async {
    ttsAnnouncementsEnabled = !ttsAnnouncementsEnabled;
    await DatabaseService.setPomodoroTtsEnabled(ttsAnnouncementsEnabled);

    if (isRoutineMode.value) {
      TtsService.setEnabled(ttsAnnouncementsEnabled);
    } else {
      TtsService.setEnabled(false);
    }
  }

  static Future<void> setTtsAnnouncements(bool enabled) async {
    ttsAnnouncementsEnabled = enabled;
    await DatabaseService.setPomodoroTtsEnabled(enabled);

    if (isRoutineMode.value) {
      TtsService.setEnabled(enabled);
    } else {
      TtsService.setEnabled(false);
    }
  }

  static Future<void> toggleKeepScreenOn() async {
    keepScreenOn = !keepScreenOn;
    await DatabaseService.setKeepScreenOn(keepScreenOn);
    if (!keepScreenOn) {
      _disableWakelock();
    }
  }

  static Future<void> toggleVibrateOnComplete() async {
    vibrateOnComplete = !vibrateOnComplete;
    await DatabaseService.setVibrateOnComplete(vibrateOnComplete);
  }

  // ═══════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════
  static String get formattedTime {
    final min = remainingSeconds.value ~/ 60;
    final sec = remainingSeconds.value % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  static bool get isRunning => timerStatus.value == TimerStatus.running;
  static bool get isPaused => timerStatus.value == TimerStatus.paused;
  static bool get isStopped => timerStatus.value == TimerStatus.stopped;

  static String get stateLabel {
    switch (currentState.value) {
      case PomodoroState.focus:
        return 'Focus Time';
      case PomodoroState.shortBreak:
        return 'Short Break';
      case PomodoroState.longBreak:
        return 'Long Break';
      case PomodoroState.idle:
        return 'Ready';
    }
  }

  static Color get stateColor {
    switch (currentState.value) {
      case PomodoroState.focus:
        return const Color(0xFFEF4444);
      case PomodoroState.shortBreak:
        return const Color(0xFF10B981);
      case PomodoroState.longBreak:
        return const Color(0xFF3B82F6);
      case PomodoroState.idle:
        return const Color(0xFF6B7280);
    }
  }

  static String get routineProgress {
    if (!isRoutineMode.value || activeRoutine.value == null) {
      return '';
    }
    final current = currentRoutineIndex.value + 1;
    final total = activeRoutine.value!.sessions.length;
    return '$current / $total';
  }

  static RoutineSession? get currentRoutineSession {
    if (!isRoutineMode.value || activeRoutine.value == null) {
      return null;
    }
    if (currentRoutineIndex.value >= activeRoutine.value!.sessions.length) {
      return null;
    }
    return activeRoutine.value!.sessions[currentRoutineIndex.value];
  }

  // ═══════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════
  static Future<void> dispose() async {
    await stop();
    await _disableWakelock();
    debugPrint('🍅 AdvancedPomodoroService disposed');
  }
}