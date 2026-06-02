// lib/services/force_update_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';

class ForceUpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _updateDoc = 'admin/force_update';
  static const String _lastSkipKey = 'force_update_last_skip';
  static const int _skipDurationHours = 24;

  // ═══════════════════════════════════════
  // 🔍 CHECK IF UPDATE NEEDED
  // ═══════════════════════════════════════

  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;
      final currentVersionName = packageInfo.version;

      debugPrint('📱 Current Version: $currentVersionName ($currentVersionCode)');

      // Fetch update config from Firestore
      final docSnap = await _firestore.doc(_updateDoc).get();

      if (!docSnap.exists) {
        debugPrint('⚠️ No force_update document found');
        return null;
      }

      final data = docSnap.data()!;

      final enabled = data['enabled'] as bool? ?? false;
      if (!enabled) {
        debugPrint('✅ Force update disabled by admin');
        return null;
      }

      final latestVersionCode = data['latestVersionCode'] as int? ?? currentVersionCode;
      final minimumVersionCode = data['minimumVersionCode'] as int? ?? currentVersionCode;
      final isForceUpdate = data['isForceUpdate'] as bool? ?? false;

      debugPrint('🔔 Latest: $latestVersionCode | Minimum: $minimumVersionCode | Force: $isForceUpdate');

      // Check if update needed
      bool updateRequired = false;
      bool isBlocking = false;

      if (currentVersionCode < minimumVersionCode) {
        // Must update (blocking)
        updateRequired = true;
        isBlocking = true;
        debugPrint('🚨 BLOCKING UPDATE REQUIRED');
      } else if (currentVersionCode < latestVersionCode) {
        // Optional update (can skip)
        updateRequired = true;
        isBlocking = isForceUpdate;
        debugPrint('💡 Update available (blocking: $isBlocking)');
      }

      if (!updateRequired) {
        debugPrint('✅ App is up to date');
        return null;
      }

      // Check if user skipped recently (only for non-blocking updates)
      if (!isBlocking) {
        final canShow = await _canShowUpdateDialog();
        if (!canShow) {
          debugPrint('⏭️ Update skipped recently, will show after 24h');
          return null;
        }
      }

      // Return update info
      return {
        'updateRequired': true,
        'isBlocking': isBlocking,
        'latestVersion': data['latestVersionName'] as String? ?? '',
        'currentVersion': currentVersionName,
        'title': data['updateTitle'] as String? ?? 'Update Available',
        'message': data['updateMessage'] as String? ?? 'A new version is available.',
        'updateUrl': data['updateUrl'] as String? ?? AppConfig.playStoreAppUrl,
        'features': data['updateFeatures'] as List<dynamic>? ?? [],
      };
    } catch (e) {
      debugPrint('❌ Force update check error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // ⏭️ CAN SHOW UPDATE DIALOG? (24h check)
  // ═══════════════════════════════════════

  static Future<bool> _canShowUpdateDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSkip = prefs.getInt(_lastSkipKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - lastSkip;
      final hoursPassed = diff / (1000 * 60 * 60);

      return hoursPassed >= _skipDurationHours;
    } catch (e) {
      debugPrint('⚠️ Skip check error: $e');
      return true; // Show by default if error
    }
  }

  // ═══════════════════════════════════════
  // 💾 SAVE SKIP TIMESTAMP
  // ═══════════════════════════════════════

  static Future<void> saveSkipTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastSkipKey, now);
      debugPrint('💾 Update skipped, will show again after 24h');
    } catch (e) {
      debugPrint('⚠️ Save skip error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 🗑️ CLEAR SKIP TIMESTAMP
  // ═══════════════════════════════════════

  static Future<void> clearSkipTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSkipKey);
      debugPrint('🗑️ Skip timestamp cleared');
    } catch (e) {
      debugPrint('⚠️ Clear skip error: $e');
    }
  }
}