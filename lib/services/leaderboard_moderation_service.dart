// lib/services/leaderboard_moderation_service.dart
//
// UGC Safety for Leaderboard (Google Play policy friendly):
// - Report: sends a report document to Firestore
// - Block: hides a user locally (blocklist stored in Hive settings)
// - No new Hive typeId required (uses settings box keys)
//
// UI text must be handled in screens (English only). This service provides logic only.
//
// Firestore collection used for reports:
// - leaderboard_v1_reports (add-only from clients)
//
// Recommended Firestore Rules (later):
// - allow create if request.auth != null
// - deny update/delete from clients (optional)

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'auth_service.dart';
import 'database_service.dart';

class LeaderboardModerationException implements Exception {
  final String message;
  final Object? cause;

  const LeaderboardModerationException(this.message, {this.cause});

  @override
  String toString() => 'LeaderboardModerationException: $message';
}

class LeaderboardReportReasons {
  const LeaderboardReportReasons._();

  // Keep reason ids stable (used in Firestore).
  static const String spam = 'spam';
  static const String abusive = 'abusive';
  static const String impersonation = 'impersonation';
  static const String inappropriate = 'inappropriate';
  static const String other = 'other';

  static const List<String> all = <String>[
    spam,
    abusive,
    impersonation,
    inappropriate,
    other,
  ];

  static bool isValid(String id) => all.contains(id);

  static String normalize(String raw) {
    final v = raw.trim().toLowerCase();
    if (isValid(v)) return v;
    return other;
  }
}

class LeaderboardModerationService {
  LeaderboardModerationService._();

  static const String _reportsCollection = 'leaderboard_v1_reports';

  /// Stored in Hive settings box.
  static const String _kBlockedUids = 'leaderboard_blocked_uids';

  /// UI can listen to this without Provider/Bloc.
  static final ValueNotifier<Set<String>> blockedUidsNotifier =
  ValueNotifier<Set<String>>(<String>{});

  /// Call once early (optional). Safe to call multiple times.
  static Future<void> init() async {
    try {
      final current = getBlockedUids();
      blockedUidsNotifier.value = current.toSet();
    } catch (e) {
      debugPrint('⚠️ LeaderboardModerationService.init error: $e');
    }
  }

  static List<String> getBlockedUids() {
    try {
      final box = Hive.box(DatabaseService.settingsBox);
      final raw = box.get(_kBlockedUids, defaultValue: <dynamic>[]);
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toSet().toList();
      }
    } catch (e) {
      debugPrint('⚠️ getBlockedUids error: $e');
    }
    return <String>[];
  }

  static bool isBlocked(String uid) {
    if (uid.trim().isEmpty) return false;
    return blockedUidsNotifier.value.contains(uid);
  }

  static Future<void> blockUid(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return;

    try {
      final list = getBlockedUids();
      if (!list.contains(id)) {
        list.add(id);
        await Hive.box(DatabaseService.settingsBox).put(_kBlockedUids, list);
      }
      blockedUidsNotifier.value = list.toSet();
    } catch (e) {
      throw LeaderboardModerationException('Failed to block user.', cause: e);
    }
  }

  static Future<void> unblockUid(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return;

    try {
      final list = getBlockedUids();
      list.removeWhere((e) => e == id);
      await Hive.box(DatabaseService.settingsBox).put(_kBlockedUids, list);
      blockedUidsNotifier.value = list.toSet();
    } catch (e) {
      throw LeaderboardModerationException('Failed to unblock user.', cause: e);
    }
  }

  static Future<void> clearAllBlocked() async {
    try {
      await Hive.box(DatabaseService.settingsBox).put(_kBlockedUids, <String>[]);
      blockedUidsNotifier.value = <String>{};
    } catch (e) {
      throw LeaderboardModerationException('Failed to clear blocked list.', cause: e);
    }
  }

  /// Report a leaderboard user to Firestore.
  ///
  /// This is "add-only" and should be rate-limited server-side if needed.
  static Future<String> reportUser({
    required String targetUid,
    required String reasonId,
    String? details,
    String? targetDisplayName,
    double? targetScore,
    int? targetRank,
  }) async {
    final reporter = AuthService.instance.currentUser;
    if (reporter == null) {
      throw const LeaderboardModerationException('Sign-in required to report.');
    }

    final tUid = targetUid.trim();
    if (tUid.isEmpty) {
      throw const LeaderboardModerationException('Invalid target user.');
    }
    if (tUid == reporter.uid) {
      throw const LeaderboardModerationException('You cannot report yourself.');
    }

    final normalizedReason = LeaderboardReportReasons.normalize(reasonId);
    final safeDetails = _sanitizeDetails(details);

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    Map<String, dynamic> app = <String, dynamic>{};
    Map<String, dynamic> device = <String, dynamic>{};

    try {
      final info = await PackageInfo.fromPlatform();
      app = <String, dynamic>{
        'appName': info.appName,
        'packageName': info.packageName,
        'version': info.version,
        'buildNumber': info.buildNumber,
      };
    } catch (e) {
      debugPrint('ℹ️ PackageInfo not available: $e');
    }

    try {
      final di = DeviceInfoPlugin();
      final android = await di.androidInfo;
      device = <String, dynamic>{
        'platform': 'android',
        'sdkInt': android.version.sdkInt,
        'brand': android.brand,
        'model': android.model,
        'device': android.device,
      };
    } catch (e) {
      debugPrint('ℹ️ DeviceInfo not available: $e');
    }

    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': nowMs,

      // Reporter (authenticated)
      'reporterUid': reporter.uid,
      'reporterEmail': reporter.email, // keep; you can null this in rules if you prefer
      'reporterName': reporter.displayName,

      // Target
      'targetUid': tUid,
      'targetDisplayName': (targetDisplayName ?? '').trim().isEmpty ? null : (targetDisplayName ?? '').trim(),
      'targetScore': (targetScore != null && targetScore.isFinite) ? double.parse(targetScore.toStringAsFixed(2)) : null,
      'targetRank': (targetRank != null && targetRank > 0) ? targetRank : null,

      // Report data
      'reasonId': normalizedReason,
      'details': safeDetails,

      // Context
      'app': app.isEmpty ? null : app,
      'device': device.isEmpty ? null : device,
    };

    // Remove null keys for cleaner docs
    payload.removeWhere((key, value) => value == null);

    try {
      final ref = await FirebaseFirestore.instance
          .collection(_reportsCollection)
          .add(payload);
      return ref.id;
    } catch (e) {
      throw LeaderboardModerationException('Failed to send report.', cause: e);
    }
  }

  static String? _sanitizeDetails(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;

    // Keep within safe limits
    final limited = v.length <= 280 ? v : v.substring(0, 280);

    // Remove repeated whitespace
    final cleaned = limited.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  /// Optional: simple client-side cooldown key.
  /// (Not a hard security measure; server-side rules/limits are recommended.)
  static Future<bool> canReportNow({Duration cooldown = const Duration(seconds: 20)}) async {
    const key = 'leaderboard_last_report_at_ms';
    try {
      final box = Hive.box(DatabaseService.settingsBox);
      final last = (box.get(key, defaultValue: 0) as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch;
      final ok = (now - last) >= cooldown.inMilliseconds;
      return ok;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markReportedNow() async {
    const key = 'leaderboard_last_report_at_ms';
    try {
      final box = Hive.box(DatabaseService.settingsBox);
      await box.put(key, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Helper: filter out blocked uids from a list.
  static List<T> filterBlocked<T>({
    required List<T> items,
    required String Function(T item) uidOf,
  }) {
    final blocked = blockedUidsNotifier.value;
    if (blocked.isEmpty) return items;

    return items.where((e) {
      final uid = uidOf(e).trim();
      return uid.isEmpty ? true : !blocked.contains(uid);
    }).toList();
  }

  /// Helper: stable random-ish anonymized id for optional client analytics (not required).
  static String makeClientNonce() {
    final r = Random();
    final now = DateTime.now().millisecondsSinceEpoch;
    final a = r.nextInt(1 << 20);
    final b = r.nextInt(1 << 20);
    return '$now-$a-$b';
  }
}