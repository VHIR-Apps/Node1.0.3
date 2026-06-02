// lib/services/ad_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../config/app_config.dart';
import 'database_service.dart';

/// 🚀 ADVANCED AD SERVICE
/// ✅ Supports Unity Ads + AdMob
/// ✅ VIP/PRO users are ad-free
/// ✅ Smart frequency controls
class AdService {
  static bool _isInitialized = false;
  static bool _isInterstitialShowing = false;
  static bool _isRewardedShowing = false;
  static String _lastError = '';

  // AdMob
  static BannerAd? _admobBannerAd;
  static InterstitialAd? _admobInterstitialAd;
  static RewardedAd? _admobRewardedAd;
  static bool _admobInitialized = false;
  static bool _admobBannerLoaded = false;
  static bool _admobInterstitialLoaded = false;
  static bool _admobRewardedLoaded = false;

  // Unity
  static bool _unityInitialized = false;

  static bool get isInitialized => _isInitialized;
  static bool get isInterstitialShowing => _isInterstitialShowing;
  static bool get isRewardedShowing => _isRewardedShowing;
  static String get lastError => _lastError;
  static bool get isBannerLoaded => _admobBannerLoaded;
  static bool get isInterstitialReady =>
      (_unityInitialized && AppConfig.enableUnityAds) ||
          (_admobInterstitialLoaded && AppConfig.enableAdMob);
  static bool get isRewardedReady =>
      (_unityInitialized && AppConfig.enableUnityAds) ||
          (_admobRewardedLoaded && AppConfig.enableAdMob);

  // =========================================================
  // INITIALIZE
  // =========================================================
  static Future<void> initialize() async {
    if (!AppConfig.enableAds) {
      _isInitialized = false;
      _lastError = 'Ads disabled from config';
      return;
    }

    if (DatabaseService.isProOrVipUser()) {
      _isInitialized = false;
      _lastError = 'Premium user - ads disabled';
      if (AppConfig.adDebugMode) {
        debugPrint('🌟 Premium user detected - skipping ad initialization');
      }
      return;
    }

    _lastError = '';

    final admobReady = await _initializeAdMob();
    final unityReady = await _initializeUnity();

    _isInitialized = admobReady || unityReady;

    if (!DatabaseService.isProOrVipUser()) {
      await loadBannerAd();
      await loadInterstitialAd();
      await loadRewardedAd();
    }

    if (AppConfig.adDebugMode) {
      debugPrint('✅ AdService initialized');
      debugPrint('   AdMob: $_admobInitialized');
      debugPrint('   Unity: $_unityInitialized');
    }
  }

  static Future<bool> _initializeAdMob() async {
    if (!AppConfig.enableAdMob) {
      if (AppConfig.adDebugMode) debugPrint('⚠️ AdMob disabled in config');
      return false;
    }

    try {
      await MobileAds.instance.initialize();
      // 🚀 HALAL/CLEAN ADS ONLY (Family Safe)
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      _admobInitialized = true;
      if (AppConfig.adDebugMode) debugPrint('✅ AdMob initialized');
      return true;
    } catch (e) {
      _lastError = 'AdMob init failed: $e';
      debugPrint('❌ $_lastError');
      return false;
    }
  }

  static Future<bool> _initializeUnity() async {
    if (!AppConfig.enableUnityAds) return false;

    try {
      final gameId = defaultTargetPlatform == TargetPlatform.android
          ? AppConfig.unityAndroidGameId
          : AppConfig.unityIosGameId;

      if (gameId.isEmpty) {
        _lastError = 'Unity Game ID missing';
        return false;
      }

      final completer = Completer<bool>();

      await UnityAds.init(
        gameId: gameId,
        testMode: AppConfig.unityTestMode,
        onComplete: () {
          _unityInitialized = true;
          if (!completer.isCompleted) completer.complete(true);
        },
        onFailed: (error, message) {
          _lastError = 'Unity init failed: $error / $message';
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      return completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
    } catch (e) {
      return false;
    }
  }

  // =========================================================
  // BANNER
  // =========================================================
  static Future<void> loadBannerAd() async {
    if (!AppConfig.enableAds || !AppConfig.enableBannerAd || !AppConfig.enableAdMob) return;

    if (DatabaseService.isProOrVipUser()) return;

    _admobBannerAd?.dispose();
    _admobBannerAd = null;
    _admobBannerLoaded = false;

    try {
      _admobBannerAd = BannerAd(
        adUnitId: AppConfig.admobBannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(nonPersonalizedAds: true),
        listener: BannerAdListener(
          onAdLoaded: (ad) => _admobBannerLoaded = true,
          onAdFailedToLoad: (ad, error) {
            _admobBannerLoaded = false;
            ad.dispose();
            _admobBannerAd = null;
          },
        ),
      )..load();
    } catch (e) {
      debugPrint('❌ Banner exception: $e');
    }
  }

  // =========================================================
  // INTERSTITIAL
  // =========================================================
  static Future<void> loadInterstitialAd() async {
    if (!AppConfig.enableAds || !AppConfig.enableInterstitialAd) return;
    if (DatabaseService.isProOrVipUser()) return;
    if (AppConfig.enableAdMob) _loadAdMobInterstitial();
  }

  static void _loadAdMobInterstitial() {
    _admobInterstitialLoaded = false;

    InterstitialAd.load(
      adUnitId: AppConfig.admobInterstitialAdUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _admobInterstitialAd = ad;
          _admobInterstitialLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _isInterstitialShowing = false;
              _admobInterstitialLoaded = false;
              ad.dispose();
              _admobInterstitialAd = null;
              if (!DatabaseService.isProOrVipUser()) _loadAdMobInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isInterstitialShowing = false;
              _admobInterstitialLoaded = false;
              ad.dispose();
              _admobInterstitialAd = null;
              if (!DatabaseService.isProOrVipUser()) _loadAdMobInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _admobInterstitialLoaded = false;
        },
      ),
    );
  }

  static Future<void> showInterstitialAd() async {
    if (!AppConfig.enableAds || !AppConfig.enableInterstitialAd) return;
    if (DatabaseService.isProOrVipUser()) return;
    if (_isInterstitialShowing || _isRewardedShowing) return;

    final shownThisSession = DatabaseService.getSessionInterstitialCount();
    if (shownThisSession >= AppConfig.maxInterstitialPerSession) return;

    final lastShown = DatabaseService.getLastInterstitialTime();
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffSeconds = ((now - lastShown) / 1000).floor();

    if (lastShown != 0 && diffSeconds < AppConfig.minSecondsBetweenInterstitial) return;

    bool shown = false;

    if (AppConfig.enableUnityAds && _unityInitialized) {
      shown = await _showUnityInterstitial();
    }

    if (!shown && AppConfig.enableAdMob && _admobInterstitialAd != null) {
      try {
        _isInterstitialShowing = true;
        await _admobInterstitialAd!.show();
        shown = true;
      } catch (e) {
        _isInterstitialShowing = false;
      }
    }

    if (shown) {
      await DatabaseService.setLastInterstitialTime(now);
      await DatabaseService.setSessionInterstitialCount(shownThisSession + 1);
    }
  }

  static Future<bool> _showUnityInterstitial() async {
    try {
      final completer = Completer<bool>();
      await UnityAds.load(
        placementId: AppConfig.unityInterstitialPlacementId,
        onComplete: (placementId) async {
          await UnityAds.showVideoAd(
            placementId: placementId,
            onStart: (_) => _isInterstitialShowing = true,
            onClick: (_) {},
            onComplete: (_) {
              _isInterstitialShowing = false;
              if (!completer.isCompleted) completer.complete(true);
            },
            onFailed: (_, error, message) {
              _isInterstitialShowing = false;
              if (!completer.isCompleted) completer.complete(false);
            },
          );
        },
        onFailed: (_, error, message) {
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
        _isInterstitialShowing = false;
        return false;
      });
    } catch (e) {
      return false;
    }
  }

  static Future<void> registerMeaningfulAction() async {
    if (!AppConfig.enableAds || !AppConfig.enableInterstitialAd) return;
    if (DatabaseService.isProOrVipUser()) return;

    await DatabaseService.incrementInterstitialCounter();
    final counter = DatabaseService.getInterstitialCounter();

    if (counter >= AppConfig.interstitialAdFrequency) {
      await showInterstitialAd();
      await DatabaseService.resetInterstitialCounter();
    }
  }

  // =========================================================
  // REWARDED
  // =========================================================
  static Future<void> loadRewardedAd() async {
    if (!AppConfig.enableAds || !AppConfig.enableRewardedAd) return;
    if (DatabaseService.isProOrVipUser()) return;
    if (AppConfig.enableAdMob) _loadAdMobRewarded();
  }

  static void _loadAdMobRewarded() {
    _admobRewardedLoaded = false;

    RewardedAd.load(
      adUnitId: AppConfig.admobRewardedAdUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _admobRewardedAd = ad;
          _admobRewardedLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _isRewardedShowing = false;
              _admobRewardedLoaded = false;
              ad.dispose();
              _admobRewardedAd = null;
              if (!DatabaseService.isProOrVipUser()) _loadAdMobRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isRewardedShowing = false;
              _admobRewardedLoaded = false;
              ad.dispose();
              _admobRewardedAd = null;
              if (!DatabaseService.isProOrVipUser()) _loadAdMobRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _admobRewardedLoaded = false;
        },
      ),
    );
  }

  static Future<bool> showRewardedUnlockHabits() async {
    if (!AppConfig.enableAds || !AppConfig.enableRewardedAd) return false;
    if (_isRewardedShowing || _isInterstitialShowing) return false;

    if (DatabaseService.isProOrVipUser()) {
      await DatabaseService.addRewardedExtraHabits(AppConfig.rewardedExtraHabits);
      return true;
    }

    bool rewarded = false;

    if (AppConfig.enableUnityAds && _unityInitialized) {
      rewarded = await _showUnityRewarded(
        onReward: () async => await DatabaseService.addRewardedExtraHabits(AppConfig.rewardedExtraHabits),
      );
      if (rewarded) return true;
    }

    if (AppConfig.enableAdMob && _admobRewardedAd != null) {
      rewarded = await _showAdMobRewarded(
        onReward: () async => await DatabaseService.addRewardedExtraHabits(AppConfig.rewardedExtraHabits),
      );
    }

    return rewarded;
  }

  static Future<bool> showRewardedUnlockRoutine(String routineId) async {
    if (!AppConfig.enableAds || !AppConfig.enableRewardedAd) return false;
    if (_isRewardedShowing || _isInterstitialShowing) return false;

    if (DatabaseService.isProOrVipUser()) {
      await DatabaseService.unlockRoutineForOneDay(routineId);
      return true;
    }

    bool rewarded = false;

    if (AppConfig.enableUnityAds && _unityInitialized) {
      rewarded = await _showUnityRewarded(
        onReward: () async => await DatabaseService.unlockRoutineForOneDay(routineId),
      );
      if (rewarded) return true;
    }

    if (AppConfig.enableAdMob && _admobRewardedAd != null) {
      rewarded = await _showAdMobRewarded(
        onReward: () async => await DatabaseService.unlockRoutineForOneDay(routineId),
      );
    }

    return rewarded;
  }

  static Future<bool> _showAdMobRewarded({required Future<void> Function() onReward}) async {
    if (_admobRewardedAd == null) return false;

    try {
      final completer = Completer<bool>();
      _isRewardedShowing = true;

      await _admobRewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          await onReward();
          if (!completer.isCompleted) completer.complete(true);
        },
      );

      return completer.future.timeout(const Duration(seconds: 20), onTimeout: () {
        _isRewardedShowing = false;
        return false;
      });
    } catch (e) {
      _isRewardedShowing = false;
      return false;
    }
  }

  static Future<bool> _showUnityRewarded({required Future<void> Function() onReward}) async {
    try {
      final completer = Completer<bool>();

      await UnityAds.load(
        placementId: AppConfig.unityRewardedPlacementId,
        onComplete: (placementId) async {
          await UnityAds.showVideoAd(
            placementId: placementId,
            onStart: (_) => _isRewardedShowing = true,
            onClick: (_) {},
            onComplete: (_) async {
              await onReward();
              _isRewardedShowing = false;
              if (!completer.isCompleted) completer.complete(true);
            },
            onFailed: (_, error, message) {
              _isRewardedShowing = false;
              if (!completer.isCompleted) completer.complete(false);
            },
          );
        },
        onFailed: (_, error, message) {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      return completer.future.timeout(const Duration(seconds: 20), onTimeout: () {
        _isRewardedShowing = false;
        return false;
      });
    } catch (e) {
      _isRewardedShowing = false;
      return false;
    }
  }

  static void disposeAllAds() {
    _admobBannerAd?.dispose();
    _admobInterstitialAd?.dispose();
    _admobRewardedAd?.dispose();
    _admobBannerAd = null;
    _admobInterstitialAd = null;
    _admobRewardedAd = null;
    _admobBannerLoaded = false;
    _admobInterstitialLoaded = false;
    _admobRewardedLoaded = false;
  }

  static void dispose() {
    disposeAllAds();
  }
}

// ─────────────────────────────────────────────
// 📢 INLINE BANNER AD WIDGET FOR CHATS
// ─────────────────────────────────────────────
class InlineChatBannerAd extends StatefulWidget {
  final bool isDark;
  const InlineChatBannerAd({super.key, required this.isDark});

  @override
  State<InlineChatBannerAd> createState() => _InlineChatBannerAdState();
}

class _InlineChatBannerAdState extends State<InlineChatBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // প্রো ইউজার হলে অ্যাড লোডই হবে না
    if (!DatabaseService.isProOrVipUser() && AppConfig.enableAds && AppConfig.enableBannerAd && AppConfig.enableAdMob) {
      _loadAd();
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AppConfig.admobBannerAdUnitId,
      request: const AdRequest(nonPersonalizedAds: true), // 🚀 Halal / Family Safe
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}