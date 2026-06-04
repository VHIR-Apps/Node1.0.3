import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';

class ForceUpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _configDoc = 'admin/app_config'; // ✅ অ্যাডমিন প্যানেলের ডকুমেন্ট
  static const String _lastSkipKey = 'force_update_last_skip';
  static const int _skipDurationHours = 24; // ২৪ ঘণ্টা পর আবার দেখাবে (non-blocking ক্ষেত্রে)

  /// 🔍 অ্যাডমিন কনফিগ চেক করে আপডেট দরকার কিনা জানাবে
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // বর্তমান অ্যাপ ভার্সন (স্ট্রিং, যেমন "1.0.2")
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('📱 Current App Version: $currentVersion');

      // অ্যাডমিন ডকুমেন্ট পড়া
      final docSnap = await _firestore.doc(_configDoc).get();
      if (!docSnap.exists) {
        debugPrint('⚠️ admin/app_config not found');
        return null;
      }

      final data = docSnap.data()!;

      // ফোর্স আপডেট এনাবল কি না
      final enabled = data['force_update_enabled'] == true;
      if (!enabled) {
        debugPrint('✅ Force update is disabled in admin');
        return null;
      }

      // প্রয়োজনীয় ভার্সন
      final requiredVersion = data['force_update_version'] as String? ?? '0.0.0';
      debugPrint('🔔 Required Version: $requiredVersion');

      // ভার্সন তুলনা
      if (!_isVersionLower(currentVersion, requiredVersion)) {
        debugPrint('✅ Current version meets or exceeds required version');
        return null;
      }

      // allow_skip: true = ইউজার স্কিপ করতে পারবে
      final allowSkip = data['allow_skip'] == true; // ডিফল্ট true
      final isBlocking = !allowSkip; // false হলে স্কিপ বাটন দেখাবে না, ব্যাকও করতে পারবে না

      // যদি ব্লকিং না হয়, তাহলে আগে ২৪ ঘণ্টা স্কিপ করেছিল কি না চেক
      if (!isBlocking) {
        final canShow = await _canShowUpdateDialog();
        if (!canShow) {
          debugPrint('⏭️ User skipped recently. Will show after $_skipDurationHours hours');
          return null;
        }
      }

      // update_features (অ্যারি অফ স্ট্রিং)
      List<String> features = [];
      final rawFeatures = data['update_features'];
      if (rawFeatures is List) {
        features = rawFeatures.map((e) => e.toString()).toList();
      } else if (rawFeatures is String) {
        // যদি কোনো কারণে স্ট্রিং আসে (নিউলাইন দিয়ে)
        features = rawFeatures
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      debugPrint('🚨 Update required! Blocking: $isBlocking');
      return {
        'updateRequired': true,
        'isBlocking': isBlocking,
        'latestVersion': requiredVersion,
        'currentVersion': currentVersion,
        'title': data['force_update_title'] as String? ?? 'Update Available!',
        'message':
        data['force_update_message'] as String? ?? 'A new version is available.',
        'updateUrl':
        data['force_update_url'] as String? ?? AppConfig.playStoreAppUrl,
        'features': features,
        'allowSkip': allowSkip,
      };
    } catch (e) {
      debugPrint('❌ Force update check error: $e');
      return null;
    }
  }

  /// সহজ সিমান্টিক ভার্সন কম্পেয়ার (current < required কিনা)
  static bool _isVersionLower(String current, String required) {
    try {
      final curParts =
      current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final reqParts =
      required.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < curParts.length ? curParts[i] : 0;
        final r = i < reqParts.length ? reqParts[i] : 0;
        if (c < r) return true;
        if (c > r) return false;
      }
      return false; // সমান বা বেশি হলে আপডেট দরকার নেই
    } catch (_) {
      return false;
    }
  }

  /// ২৪ ঘণ্টার মধ্যে আগে স্কিপ করেছিল কিনা
  static Future<bool> _canShowUpdateDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSkip = prefs.getInt(_lastSkipKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursPassed = (now - lastSkip) / (1000 * 60 * 60);
      return hoursPassed >= _skipDurationHours;
    } catch (_) {
      return true; // এরর হলে দেখানোই ভালো
    }
  }

  /// স্কিপ টাইমস্ট্যাম্প সংরক্ষণ
  static Future<void> saveSkipTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastSkipKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// স্কিপ টাইমস্ট্যাম্প মুছা (উদাহরণ: সফল আপডেটের পর)
  static Future<void> clearSkipTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSkipKey);
  }
}