// lib/services/lock_screen_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lock Screen Bypass Controller
///
/// Default state: DISABLED — app সাধারণভাবে lock screen bypass করে না
/// Alarm সময়: ENABLED — শুধু alarm screen lock screen-এ দেখায়
/// Alarm শেষ: DISABLED — আবার normal secure state-এ ফিরে আসে
class LockScreenService {
  static const MethodChannel _channel =
  MethodChannel('com.habit.node/lock_screen');

  // Internal state tracker
  static bool _bypassEnabled = false;

  // ─────────────────────────────────────────────
  // Alarm screen খোলার সময় call করো
  // Lock screen bypass enable করবে
  // ─────────────────────────────────────────────
  static Future<void> enableForAlarm() async {
    if (_bypassEnabled) return;
    try {
      await _channel.invokeMethod('enableLockScreenBypass');
      _bypassEnabled = true;
      debugPrint('🔓 Lock screen bypass ENABLED (alarm only)');
    } catch (e) {
      debugPrint('❌ enableForAlarm error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Alarm screen বন্ধ হলে call করো
  // Normal secure state-এ ফিরে আসবে
  // ─────────────────────────────────────────────
  static Future<void> disableAfterAlarm() async {
    if (!_bypassEnabled) return;
    try {
      await _channel.invokeMethod('disableLockScreenBypass');
      _bypassEnabled = false;
      debugPrint('🔒 Lock screen bypass DISABLED (back to normal)');
    } catch (e) {
      debugPrint('❌ disableAfterAlarm error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // App start-এ force disable
  // Ensures always starts in secure state
  // ─────────────────────────────────────────────
  static Future<void> forceDisable() async {
    try {
      await _channel.invokeMethod('disableLockScreenBypass');
      _bypassEnabled = false;
      debugPrint('🔒 Lock screen bypass FORCE DISABLED (app start)');
    } catch (e) {
      debugPrint('❌ forceDisable error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Device locked কিনা check করো
  // ─────────────────────────────────────────────
  static Future<bool> isDeviceLocked() async {
    try {
      final result =
      await _channel.invokeMethod<bool>('isDeviceLocked');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ isDeviceLocked error: $e');
      return false;
    }
  }

  static bool get isBypassEnabled => _bypassEnabled;
}