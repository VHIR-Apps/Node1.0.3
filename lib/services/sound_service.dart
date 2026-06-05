// lib/services/sound_service.dart

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SoundService {
  // ─────────────────────────────────────────────
  // PLAYERS
  // ─────────────────────────────────────────────

  // Short sound effects (tap, swipe, etc.)
  static final AudioPlayer _effectPlayer = AudioPlayer();

  // Long sound effects (welcome, achievements, etc.)
  static final AudioPlayer _longEffectPlayer = AudioPlayer();

  // 🚀 Dedicated alarm player — alarm stream এ চলে
  static final AudioPlayer _alarmPlayer = AudioPlayer();

  // ─────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────

  static bool _soundEnabled = true;
  static bool _isAlarmLooping = false;
  static bool _isInitialized = false;

  static Timer? _effectTimeoutTimer;
  static Timer? _longEffectTimeoutTimer;

  static const double _effectVolume = 0.7;

  // ─────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Effect player setup (low latency for instant feedback)
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _effectPlayer.setPlayerMode(PlayerMode.lowLatency);

      // Long effect player setup
      await _longEffectPlayer.setReleaseMode(ReleaseMode.stop);
      await _longEffectPlayer.setPlayerMode(PlayerMode.mediaPlayer);

      // 🚀 Alarm player setup — alarm stream + max priority
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _alarmPlayer.setAudioContext(_buildAlarmAudioContext());

      _isInitialized = true;
      debugPrint('✅ SoundService initialized');
    } catch (e) {
      debugPrint('❌ SoundService init error: $e');
    }
  }

  // 🚀 Professional alarm audio context
  // Silent mode override করে, alarm stream এ বাজে
  static AudioContext _buildAlarmAudioContext() {
    return AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true, // CPU active রাখে
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.alarm, // 🚀 Alarm stream
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.duckOthers,
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SETTINGS
  // ─────────────────────────────────────────────

  static void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  static bool get isSoundEnabled => _soundEnabled;
  static bool get isAlarmPlaying => _isAlarmLooping;
  static bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────
  // ANTI-OVERLAP HELPER
  // Normal sounds বন্ধ করে — কিন্তু alarm এ touch করে না
  // ─────────────────────────────────────────────

  static Future<void> _stopAllNormalSounds() async {
    try {
      _effectTimeoutTimer?.cancel();
      _longEffectTimeoutTimer?.cancel();
      await _effectPlayer.stop();
      await _longEffectPlayer.stop();
    } catch (_) {}
  }

  // ═════════════════════════════════════════════
  // 🔔 ALARM SOUND SYSTEM
  // ═════════════════════════════════════════════

  /// Start alarm sound loop
  /// [customSoundPath] - Optional custom sound file path
  static Future<void> startAlarmLoop({String? customSoundPath}) async {
    // নিশ্চিত করো initialized
    if (!_isInitialized) await init();

    // অন্য সব normal sound বন্ধ করো
    await stopEffects();

    // Already looping হলে skip
    if (_isAlarmLooping) {
      debugPrint('⚠️ Alarm already looping — skipping');
      return;
    }

    try {
      // আগে stop করো (clean state)
      await _alarmPlayer.stop();

      // Flag set করো
      _isAlarmLooping = true;

      // Loop mode + max volume
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.setVolume(1.0);

      // 🚀 প্রতিবার audio context re-apply করো
      // (Android কখনো reset করে দেয়)
      await _alarmPlayer.setAudioContext(_buildAlarmAudioContext());

      // Custom sound থাকলে সেটা চালাও
      if (customSoundPath != null && customSoundPath.isNotEmpty) {
        await _alarmPlayer.play(
          DeviceFileSource(customSoundPath),
          volume: 1.0,
        );
        debugPrint('🔊 Alarm: custom file started');
        return;
      }

      // Default alarm sound
      try {
        await _alarmPlayer.play(
          AssetSource('sounds/alarm.mp3'),
          volume: 1.0,
        );
        debugPrint('🔊 Alarm: alarm.mp3 started');
      } catch (assetError) {
        // Fallback to notification.mp3
        debugPrint('⚠️ alarm.mp3 not found, fallback to notification.mp3');
        await _alarmPlayer.play(
          AssetSource('sounds/notification.mp3'),
          volume: 1.0,
        );
        debugPrint('🔊 Alarm: fallback notification.mp3 started');
      }
    } catch (e) {
      debugPrint('❌ Alarm sound error: $e');
      _isAlarmLooping = false;
    }
  }

  /// Stop alarm sound loop
  static Future<void> stopAlarmLoop() async {
    final wasLooping = _isAlarmLooping;
    _isAlarmLooping = false;

    try {
      await _alarmPlayer.stop();
      await _alarmPlayer.setReleaseMode(ReleaseMode.stop);

      if (wasLooping) {
        debugPrint('🔕 Alarm sound stopped');
      }
    } catch (e) {
      debugPrint('❌ stopAlarmLoop error: $e');
    }
  }

  /// Pause alarm (same as stop)
  static Future<void> pauseAlarmLoop() async => await stopAlarmLoop();

  /// Resume alarm if it was stopped
  static Future<void> resumeAlarmLoop() async {
    if (_isAlarmLooping) return;
    await startAlarmLoop();
  }

  // ═════════════════════════════════════════════
  // 🎵 SHORT SOUND EFFECTS (Low Latency)
  // ═════════════════════════════════════════════

  static Future<void> playTap() async => _playEffect('sounds/tap.mp3');

  static Future<void> playSwipe() async => _playEffect('sounds/swipe.mp3');

  static Future<void> playHabitComplete() async =>
      _playEffect('sounds/habit_complete.mp3');

  static Future<void> playHabitUndo() async =>
      _playEffect('sounds/habit_undo.mp3');

  static Future<void> playHabitCreated() async =>
      _playEffect('sounds/habit_created.mp3');

  static Future<void> playHabitDeleted() async =>
      _playEffect('sounds/habit_deleted.mp3');

  static Future<void> playSuccess() async => _playEffect('sounds/success.mp3');

  static Future<void> playError() async => _playEffect('sounds/error.mp3');

  static Future<void> playNotification() async =>
      _playEffect('sounds/notification.mp3');

  static Future<void> playBadgeUnlock() async =>
      _playEffect('sounds/level_up.mp3');

  static Future<void> playLevelUp() async => _playEffect('sounds/level_up.mp3');

  static Future<void> playBreakStart() async =>
      _playEffect('sounds/break_start.mp3');

  static Future<void> playBreakEnd() async =>
      _playEffect('sounds/break_end.mp3');

  // ═════════════════════════════════════════════
  // 🎶 LONG SOUNDS
  // ═════════════════════════════════════════════

  static Future<void> playAllComplete() async =>
      _playLong('sounds/all_complete.mp3');

  static Future<void> playWelcome() async => _playLong('sounds/welcome.mp3');

  static Future<void> playOnboardingStep() async =>
      _playLong('sounds/onboarding_step.mp3');

  static Future<void> playDailyGoalMet() async =>
      _playLong('sounds/daily_goal_met.mp3');

  static Future<void> playStreakMilestone() async =>
      _playLong('sounds/streak_milestone.mp3');

  static Future<void> playPomodoroComplete() async =>
      _playLong('sounds/focus_complete.mp3');

  // ═════════════════════════════════════════════
  // 🎵 CUSTOM SOUNDS (Device Files)
  // ═════════════════════════════════════════════

  /// Play custom sound from device file path
  /// Default volume: 0.75
  static Future<void> playCustomSound(
      String filePath, {
        double volume = 0.75,
      }) async =>
      await playCustomLongSound(filePath, volume: volume);

  /// Play long custom sound from device
  static Future<void> playCustomLongSound(
      String filePath, {
        double volume = _effectVolume,
      }) async {
    if (!_soundEnabled || _isAlarmLooping) return;
    try {
      await _stopAllNormalSounds();
      await _longEffectPlayer.play(
        DeviceFileSource(filePath),
        volume: volume,
      );
    } catch (e) {
      debugPrint('🔇 Custom long sound error: $e');
    }
  }

  /// Play short custom sound from device
  static Future<void> playCustomShortSound(
      String filePath, {
        double volume = _effectVolume,
      }) async {
    if (!_soundEnabled) return;
    try {
      await _stopAllNormalSounds();
      await _effectPlayer.play(
        DeviceFileSource(filePath),
        volume: volume,
      );
    } catch (e) {
      debugPrint('🔇 Custom short sound error: $e');
    }
  }

  // ═════════════════════════════════════════════
  // 🔧 INTERNAL HELPERS
  // ═════════════════════════════════════════════

  /// Play short effect from assets
  static Future<void> _playEffect(String assetPath) async {
    if (!_soundEnabled) return;
    try {
      await _stopAllNormalSounds();
      await _effectPlayer.play(
        AssetSource(assetPath),
        volume: _effectVolume,
      );
    } catch (e) {
      debugPrint('🔇 Effect error ($assetPath): $e');
    }
  }

  /// Play long sound from assets
  static Future<void> _playLong(String assetPath) async {
    if (!_soundEnabled || _isAlarmLooping) return;
    try {
      await _stopAllNormalSounds();
      await _longEffectPlayer.play(
        AssetSource(assetPath),
        volume: _effectVolume,
      );
    } catch (e) {
      debugPrint('🔇 Long sound error ($assetPath): $e');
    }
  }

  // ═════════════════════════════════════════════
  // 🛑 STOP / DISPOSE
  // ═════════════════════════════════════════════

  /// Stop all normal sound effects
  static Future<void> stopEffects() async {
    await _stopAllNormalSounds();
  }

  /// Stop everything (including alarm)
  static Future<void> stop() async {
    try {
      await stopEffects();
      await stopAlarmLoop();
    } catch (e) {
      debugPrint('❌ SoundService stop error: $e');
    }
  }

  /// Dispose all players (call on app exit only)
  static void dispose() {
    _effectTimeoutTimer?.cancel();
    _longEffectTimeoutTimer?.cancel();
    _effectPlayer.dispose();
    _longEffectPlayer.dispose();
    _alarmPlayer.dispose();
    _isInitialized = false;
  }
}