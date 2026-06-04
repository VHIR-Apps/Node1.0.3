// lib/services/sound_service.dart

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SoundService {
  static final AudioPlayer _effectPlayer = AudioPlayer();
  static final AudioPlayer _longEffectPlayer = AudioPlayer();

  // 🚀 NEW: অ্যালার্মের জন্য সম্পূর্ণ আলাদা একটি প্লেয়ার
  static final AudioPlayer _alarmPlayer = AudioPlayer();

  static bool _soundEnabled = true;
  static bool _isAlarmLooping = false;

  static Timer? _effectTimeoutTimer;
  static Timer? _longEffectTimeoutTimer;

  static const double _effectVolume = 0.7;

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────

  static Future<void> init() async {
    try {
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _effectPlayer.setPlayerMode(PlayerMode.lowLatency);

      await _longEffectPlayer.setReleaseMode(ReleaseMode.stop);
      await _longEffectPlayer.setPlayerMode(PlayerMode.mediaPlayer);

      // 🚀 ALARM STREAM SETUP: মিডিয়া ভলিউমের বদলে রিংটোন/অ্যালার্ম ভলিউমে বাজবে
      await _alarmPlayer.setReleaseMode(ReleaseMode.stop);
      await _alarmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _alarmPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm, // 🚀 এটিই রিংটোন/অ্যালার্ম ভলিউম কন্ট্রোল করবে
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          // 🚀 FIX: List [] এর বদলে Set {} ব্যবহার করা হয়েছে
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));

      debugPrint('✅ SoundService initialized');
    } catch (e) {
      debugPrint('❌ SoundService init error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // SETTINGS
  // ─────────────────────────────────────────────

  static void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  static bool get isSoundEnabled => _soundEnabled;
  static bool get isAlarmPlaying => _isAlarmLooping;

  // ─────────────────────────────────────────────
  // ANTI-OVERLAP
  // ─────────────────────────────────────────────

  static Future<void> _stopAllNormalSounds() async {
    try {
      _effectTimeoutTimer?.cancel();
      _longEffectTimeoutTimer?.cancel();
      await _effectPlayer.stop();
      await _longEffectPlayer.stop();
      // ⚠️ Note: অ্যালার্ম প্লেয়ার এখানে স্টপ হবে না, কারণ অ্যালার্ম স্বাধীনভাবে বাজবে
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // 🔔 ALARM SOUND — FIXED (RINGTONE VOLUME)
  // ─────────────────────────────────────────────

  static Future<void> startAlarmLoop({
    String? customSoundPath,
  }) async {
    // অন্য সব normal sound বন্ধ করো
    await stopEffects();

    // Already looping হলে skip করো
    if (_isAlarmLooping) {
      debugPrint('⚠️ Alarm already looping — skipping');
      return;
    }

    try {
      // ✅ আগে alarm player stop করো
      await _alarmPlayer.stop();

      // ✅ Flag আগে set করো
      _isAlarmLooping = true;

      // ✅ Loop mode BEFORE play
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.setVolume(1.0);

      if (customSoundPath != null && customSoundPath.isNotEmpty) {
        // Custom device file
        await _alarmPlayer.play(
          DeviceFileSource(customSoundPath),
          volume: 1.0,
        );
        debugPrint('🔊 Alarm: custom file started on Alarm Stream');
      } else {
        // ✅ alarm.mp3 — assets/sounds/ এ রাখতে হবে
        try {
          await _alarmPlayer.play(
            AssetSource('sounds/alarm.mp3'),
            volume: 1.0,
          );
          debugPrint('🔊 Alarm: alarm.mp3 started on Alarm Stream');
        } catch (assetError) {
          // ✅ Fallback: notification.mp3
          debugPrint('⚠️ alarm.mp3 not found, fallback to notification.mp3');
          await _alarmPlayer.play(
            AssetSource('sounds/notification.mp3'),
            volume: 1.0,
          );
          debugPrint('🔊 Alarm: fallback notification.mp3 started');
        }
      }
    } catch (e) {
      debugPrint('❌ Alarm sound error: $e');
      _isAlarmLooping = false;
    }
  }

  static Future<void> stopAlarmLoop() async {
    final wasLooping = _isAlarmLooping;

    // ✅ আগে flag reset করো
    _isAlarmLooping = false;

    try {
      await _alarmPlayer.stop();

      // ✅ Release mode reset করো
      await _alarmPlayer.setReleaseMode(ReleaseMode.stop);

      if (wasLooping) {
        debugPrint('🔕 Alarm sound stopped');
      }
    } catch (e) {
      debugPrint('❌ stopAlarmLoop error: $e');
    }
  }

  static Future<void> pauseAlarmLoop() async =>
      await stopAlarmLoop();

  static Future<void> resumeAlarmLoop() async {
    if (_isAlarmLooping) return;
    await startAlarmLoop();
  }

  // ─────────────────────────────────────────────
  // SOUND EFFECTS
  // ─────────────────────────────────────────────

  static Future<void> playTap() async =>
      _playEffect('sounds/tap.mp3');

  static Future<void> playSwipe() async =>
      _playEffect('sounds/swipe.mp3');

  static Future<void> playHabitComplete() async =>
      _playEffect('sounds/habit_complete.mp3');

  static Future<void> playHabitUndo() async =>
      _playEffect('sounds/habit_undo.mp3');

  static Future<void> playHabitCreated() async =>
      _playEffect('sounds/habit_created.mp3');

  static Future<void> playHabitDeleted() async =>
      _playEffect('sounds/habit_deleted.mp3');

  static Future<void> playSuccess() async =>
      _playEffect('sounds/success.mp3');

  static Future<void> playError() async =>
      _playEffect('sounds/error.mp3');

  static Future<void> playNotification() async =>
      _playEffect('sounds/notification.mp3');

  static Future<void> playBadgeUnlock() async =>
      _playEffect('sounds/level_up.mp3');

  static Future<void> playLevelUp() async =>
      _playEffect('sounds/level_up.mp3');

  static Future<void> playBreakStart() async =>
      _playEffect('sounds/break_start.mp3');

  static Future<void> playBreakEnd() async =>
      _playEffect('sounds/break_end.mp3');

  static Future<void> playAllComplete() async =>
      _playLong('sounds/all_complete.mp3');

  static Future<void> playWelcome() async =>
      _playLong('sounds/welcome.mp3');

  static Future<void> playOnboardingStep() async =>
      _playLong('sounds/onboarding_step.mp3');

  static Future<void> playDailyGoalMet() async =>
      _playLong('sounds/daily_goal_met.mp3');

  static Future<void> playStreakMilestone() async =>
      _playLong('sounds/streak_milestone.mp3');

  static Future<void> playPomodoroComplete() async =>
      _playLong('sounds/focus_complete.mp3');

  static Future<void> playCustomSound(
      String filePath, {
        double volume = 0.75,
      }) async =>
      await playCustomLongSound(filePath, volume: volume);

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

  // ─────────────────────────────────────────────
  // INTERNAL HELPERS
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  // STOP / DISPOSE
  // ─────────────────────────────────────────────

  static Future<void> stopEffects() async {
    await _stopAllNormalSounds();
  }

  static Future<void> stop() async {
    try {
      await stopEffects();
      await stopAlarmLoop();
    } catch (e) {
      debugPrint('❌ SoundService stop error: $e');
    }
  }

  static void dispose() {
    _effectTimeoutTimer?.cancel();
    _longEffectTimeoutTimer?.cancel();
    _effectPlayer.dispose();
    _longEffectPlayer.dispose();
    _alarmPlayer.dispose(); // 🚀 Clean up alarm player
  }
}