// lib/widgets/banner_ad_widget.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
import '../services/database_service.dart';

/// 🎯 BANNER AD WIDGET
/// ✅ Shows ad for free users only
/// ✅ VIP/PRO users see nothing (or optional premium badge)
/// ✅ Handles loading states gracefully
class BannerAdWidget extends StatefulWidget {
  /// If true, shows a small "Ad-Free ✨" badge for premium users
  /// If false, shows nothing for premium users
  final bool showPremiumBadge;

  const BannerAdWidget({
    super.key,
    this.showPremiumBadge = false,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isPremiumUser = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  /// 🌟 প্রিমিয়াম স্ট্যাটাস চেক করা
  void _checkPremiumStatus() {
    _isPremiumUser = DatabaseService.isProOrVipUser();

    if (!_isPremiumUser &&
        AppConfig.enableAds &&
        AppConfig.enableBannerAd &&
        AppConfig.enableAdMob) {
      _loadAd();
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AppConfig.admobBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // 🌟 Ad লোড হওয়ার পরও আবার চেক করুন (যদি এর মধ্যে Pro কিনে থাকে)
          if (DatabaseService.isProOrVipUser()) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _isPremiumUser = true;
                _isLoaded = false;
              });
            }
            return;
          }

          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          if (mounted) {
            setState(() => _isLoaded = false);
          }
          debugPrint('❌ Banner ad failed to load: ${error.message}');
        },
        onAdOpened: (ad) {
          debugPrint('📢 Banner ad opened');
        },
        onAdClosed: (ad) {
          debugPrint('📢 Banner ad closed');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌟 VIP/PRO ইউজার - Ad দেখাবে না
    if (_isPremiumUser || DatabaseService.isProOrVipUser()) {
      // Optional: Premium badge দেখান
      if (widget.showPremiumBadge) {
        return _buildPremiumBadge(isDark);
      }
      return const SizedBox.shrink();
    }

    // Ads disabled globally
    if (!AppConfig.enableAds || !AppConfig.enableBannerAd) {
      return const SizedBox.shrink();
    }

    // Ad not loaded yet
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // Show the banner ad
    return Container(
      color: isDark ? const Color(0xFF0B1020) : Colors.grey[100],
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }

  /// 🌟 Premium badge widget (optional)
  Widget _buildPremiumBadge(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF1E1E2E),
            const Color(0xFF2D2D3F),
          ]
              : [
            const Color(0xFFF8F9FA),
            const Color(0xFFE9ECEF),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 16,
            color: AppConfig.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Ad-Free Experience ✨',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🆕 Alternative: Adaptive Banner Ad Widget
/// Uses adaptive banner size for better fit
class AdaptiveBannerAdWidget extends StatefulWidget {
  final bool showPremiumBadge;

  const AdaptiveBannerAdWidget({
    super.key,
    this.showPremiumBadge = false,
  });

  @override
  State<AdaptiveBannerAdWidget> createState() => _AdaptiveBannerAdWidgetState();
}

class _AdaptiveBannerAdWidgetState extends State<AdaptiveBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isPremiumUser = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  void _checkPremiumStatus() {
    _isPremiumUser = DatabaseService.isProOrVipUser();

    if (!_isPremiumUser &&
        AppConfig.enableAds &&
        AppConfig.enableBannerAd &&
        AppConfig.enableAdMob) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    // Get adaptive banner size
    final AnchoredAdaptiveBannerAdSize? size =
    await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) {
      debugPrint('Unable to get adaptive banner size');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AppConfig.admobBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (DatabaseService.isProOrVipUser()) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _isPremiumUser = true;
                _isLoaded = false;
              });
            }
            return;
          }

          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          if (mounted) {
            setState(() => _isLoaded = false);
          }
          debugPrint('❌ Adaptive banner failed: ${error.message}');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌟 Premium user check
    if (_isPremiumUser || DatabaseService.isProOrVipUser()) {
      if (widget.showPremiumBadge) {
        return _buildPremiumBadge(isDark);
      }
      return const SizedBox.shrink();
    }

    if (!AppConfig.enableAds || !AppConfig.enableBannerAd) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: isDark ? const Color(0xFF0B1020) : Colors.grey[100],
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }

  Widget _buildPremiumBadge(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF1E1E2E),
            const Color(0xFF2D2D3F),
          ]
              : [
            const Color(0xFFF8F9FA),
            const Color(0xFFE9ECEF),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 16,
            color: AppConfig.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Ad-Free Experience ✨',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🆕 Helper: Check if ads should be shown
/// Use this before showing any ad-related UI
class AdHelper {
  /// Returns true if ads should be displayed
  static bool shouldShowAds() {
    if (!AppConfig.enableAds) return false;
    if (DatabaseService.isProOrVipUser()) return false;
    return true;
  }

  /// Returns true if user is premium (Pro or VIP)
  static bool isPremiumUser() {
    return DatabaseService.isProOrVipUser();
  }

  /// Returns true if user is VIP (time-limited premium)
  static bool isVipUser() {
    return DatabaseService.isVipUser() && !DatabaseService.isVipExpired();
  }

  /// Returns true if user is Pro (purchased permanently)
  static bool isProUser() {
    return DatabaseService.isProUser();
  }
}