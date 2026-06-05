// lib/services/lock_screen_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LockScreenService {
  static const MethodChannel _channel =
  MethodChannel('com.habit.node/lock_screen');

  static bool _isEnabled = false;
  static bool get isEnabled => _isEnabled;

  // 🔒 Enable lock screen bypass for alarm
  static Future<void> enableForAlarm() async {
    try {
      await _channel.invokeMethod('enableLockScreenBypass');
      _isEnabled = true;
      debugPrint('🔒 Lock screen bypass ENABLED');
    } catch (e) {
      debugPrint('❌ enableForAlarm error: $e');
    }
  }

  // 🔒 Disable lock screen bypass after alarm dismissed
  static Future<void> disableAfterAlarm() async {
    try {
      await _channel.invokeMethod('disableLockScreenBypass');
      _isEnabled = false;
      debugPrint('🔓 Lock screen bypass DISABLED');
    } catch (e) {
      debugPrint('❌ disableAfterAlarm error: $e');
    }
  }

  // 🔒 Force disable (used on app startup)
  static Future<void> forceDisable() async {
    try {
      await _channel.invokeMethod('disableLockScreenBypass');
      _isEnabled = false;
    } catch (e) {
      debugPrint('❌ forceDisable error: $e');
    }
  }

  // 🔒 Check if device is currently locked
  static Future<bool> isDeviceLocked() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceLocked');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ isDeviceLocked error: $e');
      return false;
    }
  }

  // 🔒 Check if alarm mode is active on native side
  static Future<bool> isAlarmActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAlarmActive');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // 🔒 Clear pending alarm payload (after handling)
  static Future<void> clearAlarmPayload() async {
    try {
      await _channel.invokeMethod('clearAlarmPayload');
    } catch (_) {}
  }
}