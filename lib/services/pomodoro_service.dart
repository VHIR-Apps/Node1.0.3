// lib/services/pomodoro_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/study_session_model.dart';
import 'database_service.dart';
import 'sound_service.dart';
import 'badge_service.dart';

enum PomodoroState { focus, shortBreak, longBreak }

class PomodoroService {
  static final ValueNotifier<int> remainingSeconds = ValueNotifier(0);
  static final ValueNotifier<double> progress = ValueNotifier(1.0);
  static final ValueNotifier<bool> isRunning = ValueNotifier(false);
  static final ValueNotifier<PomodoroState> currentState = ValueNotifier(PomodoroState.focus);
  static final ValueNotifier<int> completedPomodoros = ValueNotifier(0);

  static String selectedSubject = 'Other';
  static Color subjectColor = AppConfig.predefinedSubjects['Other']!;

  static Timer? _timer;
  static DateTime? _sessionStartTime;
  static int _totalDurationSeconds = 0;

  static void init() {
    _loadSettingsForCurrentState();
  }

  static void setSubject(String subject, Color color) {
    selectedSubject = subject;
    subjectColor = color;
  }

  static void _loadSettingsForCurrentState() {
    int minutes = 25;

    switch (currentState.value) {
      case PomodoroState.focus:
        minutes = DatabaseService.getPomodoroFocusMinutes();
        break;
      case PomodoroState.shortBreak:
        minutes = DatabaseService.getPomodoroShortBreakMinutes();
        break;
      case PomodoroState.longBreak:
        minutes = DatabaseService.getPomodoroLongBreakMinutes();
        break;
    }

    _totalDurationSeconds = minutes * 60;
    remainingSeconds.value = _totalDurationSeconds;
    progress.value = 1.0;
  }

  static void start() {
    if (isRunning.value) return;

    if (remainingSeconds.value <= 0) {
      _loadSettingsForCurrentState();
    }

    if (_sessionStartTime == null && currentState.value == PomodoroState.focus) {
      _sessionStartTime = DateTime.now();
    }

    isRunning.value = true;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  static void pause() {
    _timer?.cancel();
    isRunning.value = false;
  }

  static void reset() {
    pause();
    _sessionStartTime = null;
    _loadSettingsForCurrentState();
  }

  static void skip() {
    pause();
    _handleSessionComplete();
  }

  static void _tick(Timer timer) {
    if (remainingSeconds.value > 0) {
      remainingSeconds.value--;
      progress.value = remainingSeconds.value / _totalDurationSeconds;
    } else {
      pause();
      _handleSessionComplete();
    }
  }

  static Future<void> _handleSessionComplete() async {
    final now = DateTime.now();

    if (currentState.value == PomodoroState.focus) {
      completedPomodoros.value++;

      final session = StudySession(
        id: 'study_${now.millisecondsSinceEpoch}',
        subjectName: selectedSubject,
        subjectColorValue: subjectColor.value,
        startTime: _sessionStartTime ?? now.subtract(Duration(seconds: _totalDurationSeconds)),
        endTime: now,
        durationMinutes: _totalDurationSeconds ~/ 60,
        sessionType: 'focus',
        completedAt: now,
        pomodoroCount: completedPomodoros.value,
        isCompleted: true,
      );

      await DatabaseService.saveStudySession(session);
      await BadgeService.onStudySessionCompleted(session);

      SoundService.playPomodoroComplete();

      if (completedPomodoros.value % AppConfig.pomodorosUntilLongBreak == 0) {
        currentState.value = PomodoroState.longBreak;
      } else {
        currentState.value = PomodoroState.shortBreak;
      }

    } else {
      SoundService.playBreakEnd();
      currentState.value = PomodoroState.focus;
      _sessionStartTime = null;
    }

    _loadSettingsForCurrentState();

    if (currentState.value != PomodoroState.focus) {
      SoundService.playBreakStart();
    }
  }

  static String get formattedTime {
    int min = remainingSeconds.value ~/ 60;
    int sec = remainingSeconds.value % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  static void dispose() {
    _timer?.cancel();
  }
}