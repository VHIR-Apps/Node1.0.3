// lib/services/remote_config_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class RemoteConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _configDoc = 'admin/app_config';
  static const String _notifDoc = 'admin/push_notification';
  static const String _cachePrefix = 'rc_';
  static const int _cacheDurationHours = 12;

  // ═══════════════════════════════════════
  // 🔑 INIT — Called once on app startup
  // ═══════════════════════════════════════

  static Future<void> init() async {
    try {
      // Step 1: Load cached config immediately (fast boot)
      await _loadFromCache();

      // Step 2: Check for new push notification
      await _checkForNewNotification();

      // Step 3: Fetch from Firebase if cache expired or forced
      await _fetchConfigIfNeeded();

      debugPrint('✅ RemoteConfigService initialized.');
    } catch (e) {
      debugPrint('⚠️ RemoteConfigService init error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 📦 LOAD FROM LOCAL CACHE
  // ═══════════════════════════════════════

  static Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!prefs.containsKey('${_cachePrefix}enableAds')) return;

      // ═══ FEATURE TOGGLES ═══
      AppConfig.enableAds = prefs.getBool('${_cachePrefix}enableAds') ?? AppConfig.enableAds;
      AppConfig.enableAdMob = prefs.getBool('${_cachePrefix}enableAdMob') ?? AppConfig.enableAdMob;
      AppConfig.enableUnityAds = prefs.getBool('${_cachePrefix}enableUnityAds') ?? AppConfig.enableUnityAds;
      AppConfig.enableBannerAd = prefs.getBool('${_cachePrefix}enableBannerAd') ?? AppConfig.enableBannerAd;
      AppConfig.enableInterstitialAd = prefs.getBool('${_cachePrefix}enableInterstitialAd') ?? AppConfig.enableInterstitialAd;
      AppConfig.enableRewardedAd = prefs.getBool('${_cachePrefix}enableRewardedAd') ?? AppConfig.enableRewardedAd;
      AppConfig.adSoundEnabled = prefs.getBool('${_cachePrefix}adSoundEnabled') ?? AppConfig.adSoundEnabled;
      AppConfig.adDebugMode = prefs.getBool('${_cachePrefix}adDebugMode') ?? AppConfig.adDebugMode;

      AppConfig.enableProVersion = prefs.getBool('${_cachePrefix}enableProVersion') ?? AppConfig.enableProVersion;
      AppConfig.enableNotifications = prefs.getBool('${_cachePrefix}enableNotifications') ?? AppConfig.enableNotifications;
      AppConfig.enableBackup = prefs.getBool('${_cachePrefix}enableBackup') ?? AppConfig.enableBackup;
      AppConfig.enableStats = prefs.getBool('${_cachePrefix}enableStats') ?? AppConfig.enableStats;
      AppConfig.enableMissions = prefs.getBool('${_cachePrefix}enableMissions') ?? AppConfig.enableMissions;
      AppConfig.enableDailyTips = prefs.getBool('${_cachePrefix}enableDailyTips') ?? AppConfig.enableDailyTips;
      AppConfig.enableProfileHeader = prefs.getBool('${_cachePrefix}enableProfileHeader') ?? AppConfig.enableProfileHeader;
      AppConfig.enableSkeletonLoading = prefs.getBool('${_cachePrefix}enableSkeletonLoading') ?? AppConfig.enableSkeletonLoading;
      AppConfig.enablePullToRefresh = prefs.getBool('${_cachePrefix}enablePullToRefresh') ?? AppConfig.enablePullToRefresh;
      AppConfig.enableBadges = prefs.getBool('${_cachePrefix}enableBadges') ?? AppConfig.enableBadges;
      AppConfig.enableMissedHabitDialog = prefs.getBool('${_cachePrefix}enableMissedHabitDialog') ?? AppConfig.enableMissedHabitDialog;
      AppConfig.enableSmartReminders = prefs.getBool('${_cachePrefix}enableSmartReminders') ?? AppConfig.enableSmartReminders;

      // ═══ AD FREQUENCY ═══
      AppConfig.interstitialAdFrequency = prefs.getInt('${_cachePrefix}interstitialAdFrequency') ?? AppConfig.interstitialAdFrequency;
      AppConfig.maxInterstitialPerSession = prefs.getInt('${_cachePrefix}maxInterstitialPerSession') ?? AppConfig.maxInterstitialPerSession;
      AppConfig.minSecondsBetweenInterstitial = prefs.getInt('${_cachePrefix}minSecondsBetweenInterstitial') ?? AppConfig.minSecondsBetweenInterstitial;
      AppConfig.rewardedExtraHabits = prefs.getInt('${_cachePrefix}rewardedExtraHabits') ?? AppConfig.rewardedExtraHabits;

      // ═══ AD IDs ═══
      final admobBanner = prefs.getString('${_cachePrefix}admobBannerAdUnitId');
      if (admobBanner != null && admobBanner.isNotEmpty) AppConfig.admobBannerAdUnitId = admobBanner;

      final admobInterstitial = prefs.getString('${_cachePrefix}admobInterstitialAdUnitId');
      if (admobInterstitial != null && admobInterstitial.isNotEmpty) AppConfig.admobInterstitialAdUnitId = admobInterstitial;

      final admobRewarded = prefs.getString('${_cachePrefix}admobRewardedAdUnitId');
      if (admobRewarded != null && admobRewarded.isNotEmpty) AppConfig.admobRewardedAdUnitId = admobRewarded;

      final admobApp = prefs.getString('${_cachePrefix}admobAppId');
      if (admobApp != null && admobApp.isNotEmpty) AppConfig.admobAppId = admobApp;

      final unityAndroid = prefs.getString('${_cachePrefix}unityAndroidGameId');
      if (unityAndroid != null && unityAndroid.isNotEmpty) AppConfig.unityAndroidGameId = unityAndroid;

      final unityIos = prefs.getString('${_cachePrefix}unityIosGameId');
      if (unityIos != null && unityIos.isNotEmpty) AppConfig.unityIosGameId = unityIos;

      AppConfig.unityTestMode = prefs.getBool('${_cachePrefix}unityTestMode') ?? AppConfig.unityTestMode;

      final unityInterstitial = prefs.getString('${_cachePrefix}unityInterstitialPlacementId');
      if (unityInterstitial != null && unityInterstitial.isNotEmpty) AppConfig.unityInterstitialPlacementId = unityInterstitial;

      final unityRewarded = prefs.getString('${_cachePrefix}unityRewardedPlacementId');
      if (unityRewarded != null && unityRewarded.isNotEmpty) AppConfig.unityRewardedPlacementId = unityRewarded;

      final unityBanner = prefs.getString('${_cachePrefix}unityBannerPlacementId');
      if (unityBanner != null && unityBanner.isNotEmpty) AppConfig.unityBannerPlacementId = unityBanner;

      // ═══ PRICING ═══
      final monthlyPrice = prefs.getString('${_cachePrefix}monthlyPrice');
      if (monthlyPrice != null && monthlyPrice.isNotEmpty) AppConfig.monthlyPrice = monthlyPrice;

      final yearlyPrice = prefs.getString('${_cachePrefix}yearlyPrice');
      if (yearlyPrice != null && yearlyPrice.isNotEmpty) AppConfig.yearlyPrice = yearlyPrice;

      final proPrice = prefs.getString('${_cachePrefix}proPrice');
      if (proPrice != null && proPrice.isNotEmpty) AppConfig.proPrice = proPrice;

      final monthlyProductId = prefs.getString('${_cachePrefix}monthlyProductId');
      if (monthlyProductId != null && monthlyProductId.isNotEmpty) AppConfig.monthlyProductId = monthlyProductId;

      final yearlyProductId = prefs.getString('${_cachePrefix}yearlyProductId');
      if (yearlyProductId != null && yearlyProductId.isNotEmpty) AppConfig.yearlyProductId = yearlyProductId;

      final proProductId = prefs.getString('${_cachePrefix}proProductId');
      if (proProductId != null && proProductId.isNotEmpty) AppConfig.proProductId = proProductId;

      AppConfig.maxHabitsFree = prefs.getInt('${_cachePrefix}maxHabitsFree') ?? AppConfig.maxHabitsFree;
      AppConfig.maxHabitsPro = prefs.getInt('${_cachePrefix}maxHabitsPro') ?? AppConfig.maxHabitsPro;

      // ═══ DEVELOPER ═══
      final devName = prefs.getString('${_cachePrefix}developerName');
      if (devName != null && devName.isNotEmpty) AppConfig.developerName = devName;

      final supportEmail = prefs.getString('${_cachePrefix}supportEmail');
      if (supportEmail != null && supportEmail.isNotEmpty) AppConfig.supportEmail = supportEmail;

      // ═══ LINKS ═══
      final websiteUrl = prefs.getString('${_cachePrefix}websiteUrl');
      if (websiteUrl != null) AppConfig.websiteUrl = websiteUrl;

      final privacyUrl = prefs.getString('${_cachePrefix}privacyPolicyUrl');
      if (privacyUrl != null) AppConfig.privacyPolicyUrl = privacyUrl;

      final termsUrl = prefs.getString('${_cachePrefix}termsUrl');
      if (termsUrl != null) AppConfig.termsUrl = termsUrl;

      final playStoreUrl = prefs.getString('${_cachePrefix}playStoreAppUrl');
      if (playStoreUrl != null) AppConfig.playStoreAppUrl = playStoreUrl;

      final shareMsg = prefs.getString('${_cachePrefix}shareMessage');
      if (shareMsg != null) AppConfig.shareMessage = shareMsg;

      final telegramUrl = prefs.getString('${_cachePrefix}telegramUrl');
      if (telegramUrl != null) AppConfig.telegramUrl = telegramUrl;

      final facebookUrl = prefs.getString('${_cachePrefix}facebookUrl');
      if (facebookUrl != null) AppConfig.facebookUrl = facebookUrl;

      final youtubeUrl = prefs.getString('${_cachePrefix}youtubeUrl');
      if (youtubeUrl != null) AppConfig.youtubeUrl = youtubeUrl;

      debugPrint('📦 Config loaded from cache.');
    } catch (e) {
      debugPrint('⚠️ Cache load error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 🌐 FETCH CONFIG FROM FIREBASE
  // ═══════════════════════════════════════

  static Future<void> _fetchConfigIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetch = prefs.getInt('${_cachePrefix}last_fetch_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheMs = _cacheDurationHours * 60 * 60 * 1000;

      bool forceRefresh = false;
      try {
        final configSnap = await _firestore.doc(_configDoc).get();
        if (configSnap.exists) {
          forceRefresh = configSnap.data()?['forceRefresh'] == true;
        }
      } catch (_) {}

      if (!forceRefresh && (now - lastFetch) < cacheMs) {
        debugPrint('⏭️ Config cache still fresh. Skipping fetch.');
        return;
      }

      await _fetchFromFirebase();

      if (forceRefresh) {
        try {
          await _firestore.doc(_configDoc).update({'forceRefresh': false});
        } catch (_) {}
      }

      await prefs.setInt('${_cachePrefix}last_fetch_time', now);
      await DatabaseService.setLastConfigFetchTime(now);

      debugPrint('🌐 Config fetched from Firebase.');
    } catch (e) {
      debugPrint('⚠️ Config fetch error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 🔥 FETCH FROM FIREBASE & APPLY
  // ═══════════════════════════════════════

  static Future<void> _fetchFromFirebase() async {
    try {
      final docSnap = await _firestore.doc(_configDoc).get();
      if (!docSnap.exists) return;

      final d = docSnap.data()!;
      final prefs = await SharedPreferences.getInstance();

      await _applyAndCacheBool(prefs, d, 'enableAds', (v) => AppConfig.enableAds = v);
      await _applyAndCacheBool(prefs, d, 'enableAdMob', (v) => AppConfig.enableAdMob = v);
      await _applyAndCacheBool(prefs, d, 'enableUnityAds', (v) => AppConfig.enableUnityAds = v);
      await _applyAndCacheBool(prefs, d, 'enableBannerAd', (v) => AppConfig.enableBannerAd = v);
      await _applyAndCacheBool(prefs, d, 'enableInterstitialAd', (v) => AppConfig.enableInterstitialAd = v);
      await _applyAndCacheBool(prefs, d, 'enableRewardedAd', (v) => AppConfig.enableRewardedAd = v);
      await _applyAndCacheBool(prefs, d, 'adSoundEnabled', (v) => AppConfig.adSoundEnabled = v);
      await _applyAndCacheBool(prefs, d, 'adDebugMode', (v) => AppConfig.adDebugMode = v);
      await _applyAndCacheBool(prefs, d, 'enableProVersion', (v) => AppConfig.enableProVersion = v);
      await _applyAndCacheBool(prefs, d, 'enableNotifications', (v) => AppConfig.enableNotifications = v);
      await _applyAndCacheBool(prefs, d, 'enableBackup', (v) => AppConfig.enableBackup = v);
      await _applyAndCacheBool(prefs, d, 'enableStats', (v) => AppConfig.enableStats = v);
      await _applyAndCacheBool(prefs, d, 'enableMissions', (v) => AppConfig.enableMissions = v);
      await _applyAndCacheBool(prefs, d, 'enableDailyTips', (v) => AppConfig.enableDailyTips = v);
      await _applyAndCacheBool(prefs, d, 'enableProfileHeader', (v) => AppConfig.enableProfileHeader = v);
      await _applyAndCacheBool(prefs, d, 'enableSkeletonLoading', (v) => AppConfig.enableSkeletonLoading = v);
      await _applyAndCacheBool(prefs, d, 'enablePullToRefresh', (v) => AppConfig.enablePullToRefresh = v);
      await _applyAndCacheBool(prefs, d, 'enableBadges', (v) => AppConfig.enableBadges = v);
      await _applyAndCacheBool(prefs, d, 'enableMissedHabitDialog', (v) => AppConfig.enableMissedHabitDialog = v);
      await _applyAndCacheBool(prefs, d, 'enableSmartReminders', (v) => AppConfig.enableSmartReminders = v);
      await _applyAndCacheBool(prefs, d, 'unityTestMode', (v) => AppConfig.unityTestMode = v);

      await _applyAndCacheInt(prefs, d, 'interstitialAdFrequency', (v) => AppConfig.interstitialAdFrequency = v);
      await _applyAndCacheInt(prefs, d, 'maxInterstitialPerSession', (v) => AppConfig.maxInterstitialPerSession = v);
      await _applyAndCacheInt(prefs, d, 'minSecondsBetweenInterstitial', (v) => AppConfig.minSecondsBetweenInterstitial = v);
      await _applyAndCacheInt(prefs, d, 'rewardedExtraHabits', (v) => AppConfig.rewardedExtraHabits = v);
      await _applyAndCacheInt(prefs, d, 'maxHabitsFree', (v) => AppConfig.maxHabitsFree = v);
      await _applyAndCacheInt(prefs, d, 'maxHabitsPro', (v) => AppConfig.maxHabitsPro = v);

      await _applyAndCacheString(prefs, d, 'admobBannerAdUnitId', (v) => AppConfig.admobBannerAdUnitId = v);
      await _applyAndCacheString(prefs, d, 'admobInterstitialAdUnitId', (v) => AppConfig.admobInterstitialAdUnitId = v);
      await _applyAndCacheString(prefs, d, 'admobRewardedAdUnitId', (v) => AppConfig.admobRewardedAdUnitId = v);
      await _applyAndCacheString(prefs, d, 'admobAppId', (v) => AppConfig.admobAppId = v);
      await _applyAndCacheString(prefs, d, 'unityAndroidGameId', (v) => AppConfig.unityAndroidGameId = v);
      await _applyAndCacheString(prefs, d, 'unityIosGameId', (v) => AppConfig.unityIosGameId = v);
      await _applyAndCacheString(prefs, d, 'unityInterstitialPlacementId', (v) => AppConfig.unityInterstitialPlacementId = v);
      await _applyAndCacheString(prefs, d, 'unityRewardedPlacementId', (v) => AppConfig.unityRewardedPlacementId = v);
      await _applyAndCacheString(prefs, d, 'unityBannerPlacementId', (v) => AppConfig.unityBannerPlacementId = v);

      await _applyAndCacheString(prefs, d, 'monthlyPrice', (v) => AppConfig.monthlyPrice = v);
      await _applyAndCacheString(prefs, d, 'yearlyPrice', (v) => AppConfig.yearlyPrice = v);
      await _applyAndCacheString(prefs, d, 'proPrice', (v) => AppConfig.proPrice = v);
      await _applyAndCacheString(prefs, d, 'monthlyProductId', (v) => AppConfig.monthlyProductId = v);
      await _applyAndCacheString(prefs, d, 'yearlyProductId', (v) => AppConfig.yearlyProductId = v);
      await _applyAndCacheString(prefs, d, 'proProductId', (v) => AppConfig.proProductId = v);

      await _applyAndCacheString(prefs, d, 'developerName', (v) => AppConfig.developerName = v);
      await _applyAndCacheString(prefs, d, 'supportEmail', (v) => AppConfig.supportEmail = v);
      await _applyAndCacheString(prefs, d, 'websiteUrl', (v) => AppConfig.websiteUrl = v);
      await _applyAndCacheString(prefs, d, 'privacyPolicyUrl', (v) => AppConfig.privacyPolicyUrl = v);
      await _applyAndCacheString(prefs, d, 'termsUrl', (v) => AppConfig.termsUrl = v);
      await _applyAndCacheString(prefs, d, 'playStoreAppUrl', (v) => AppConfig.playStoreAppUrl = v);
      await _applyAndCacheString(prefs, d, 'shareMessage', (v) => AppConfig.shareMessage = v);
      await _applyAndCacheString(prefs, d, 'telegramUrl', (v) => AppConfig.telegramUrl = v);
      await _applyAndCacheString(prefs, d, 'facebookUrl', (v) => AppConfig.facebookUrl = v);
      await _applyAndCacheString(prefs, d, 'youtubeUrl', (v) => AppConfig.youtubeUrl = v);

      _applyIntList(d, 'streakBadgeThresholds', (v) => AppConfig.streakBadgeThresholds = v);
      _applyIntList(d, 'completionBadgeThresholds', (v) => AppConfig.completionBadgeThresholds = v);
      _applyIntList(d, 'perfectDayThresholds', (v) => AppConfig.perfectDayThresholds = v);
      _applyIntList(d, 'comebackThresholds', (v) => AppConfig.comebackThresholds = v);
      _applyIntList(d, 'timeBasedThresholds', (v) => AppConfig.timeBasedThresholds = v);
      _applyIntList(d, 'varietyThresholds', (v) => AppConfig.varietyThresholds = v);
      _applyIntList(d, 'appUsageThresholds', (v) => AppConfig.appUsageThresholds = v);
      _applyIntList(d, 'levelThresholds', (v) => AppConfig.levelThresholds = v);

      debugPrint('🔥 Firebase config applied & cached successfully.');
    } catch (e) {
      debugPrint('⚠️ Firebase fetch error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 🆕 CHECK FOR NEW PUSH NOTIFICATION (with save)
  // ═══════════════════════════════════════

  static Future<void> _checkForNewNotification() async {
    try {
      final docSnap = await _firestore.doc(_notifDoc).get();
      if (!docSnap.exists) return;

      final data = docSnap.data()!;
      final sentAt = data['sentAt'] as Timestamp?;
      if (sentAt == null) return;

      final sentAtMs = sentAt.millisecondsSinceEpoch;
      final lastSeen = DatabaseService.getLastSeenNotificationTime();

      if (sentAtMs > lastSeen) {
        final title = data['title'] as String? ?? 'HabitNode';
        final body = data['body'] as String? ?? '';

        if (title.isNotEmpty && body.isNotEmpty) {
          // 🆕 Show as local notification WITH auto-save
          await NotificationService.showInstantNotification(
            title: title,
            body: body,
            type: 'push',
            saveToDb: true,
          );

          debugPrint('📢 New push notification shown & saved: $title');
        }

        await DatabaseService.setLastSeenNotificationTime(sentAtMs);
      } else {
        debugPrint('📢 No new notifications.');
      }
    } catch (e) {
      debugPrint('⚠️ Notification check error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 🔄 FORCE REFRESH
  // ═══════════════════════════════════════

  static Future<void> forceRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_cachePrefix}last_fetch_time', 0);
      await _fetchFromFirebase();
      await _checkForNewNotification();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('${_cachePrefix}last_fetch_time', now);
      debugPrint('🔄 Force refresh completed.');
    } catch (e) {
      debugPrint('⚠️ Force refresh error: $e');
    }
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  static Future<void> _applyAndCacheBool(
      SharedPreferences prefs,
      Map<String, dynamic> data,
      String key,
      Function(bool) setter,
      ) async {
    if (data.containsKey(key) && data[key] is bool) {
      final value = data[key] as bool;
      setter(value);
      await prefs.setBool('$_cachePrefix$key', value);
    }
  }

  static Future<void> _applyAndCacheInt(
      SharedPreferences prefs,
      Map<String, dynamic> data,
      String key,
      Function(int) setter,
      ) async {
    if (data.containsKey(key) && data[key] is int) {
      final value = data[key] as int;
      setter(value);
      await prefs.setInt('$_cachePrefix$key', value);
    }
  }

  static Future<void> _applyAndCacheString(
      SharedPreferences prefs,
      Map<String, dynamic> data,
      String key,
      Function(String) setter,
      ) async {
    if (data.containsKey(key) && data[key] is String) {
      final value = data[key] as String;
      setter(value);
      await prefs.setString('$_cachePrefix$key', value);
    }
  }

  static void _applyIntList(
      Map<String, dynamic> data,
      String key,
      Function(List<int>) setter,
      ) {
    if (data.containsKey(key) && data[key] is List) {
      try {
        final list = (data[key] as List).map((e) => (e as num).toInt()).toList();
        if (list.isNotEmpty) setter(list);
      } catch (_) {}
    }
  }
}