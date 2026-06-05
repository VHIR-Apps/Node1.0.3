// lib/screens/public_leaderboard_profile_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/leaderboard_profile_model.dart';
import '../services/database_service.dart';
import '../services/leaderboard_moderation_service.dart';
import '../services/leaderboard_service.dart';
import '../services/profile_like_service.dart';
import '../services/sound_service.dart';
import 'chat_screen.dart';
import 'leaderboard_screen.dart';

class PublicLeaderboardProfileScreen extends StatefulWidget {
  const PublicLeaderboardProfileScreen({
    super.key,
    required this.me,
    required this.entry,
    required this.rank,
    required this.selfProLocal,
    required this.selfProVerified,
  });

  final User me;
  final LeaderboardEntry entry;
  final int rank;
  final bool selfProLocal;
  final bool selfProVerified;

  @override
  State<PublicLeaderboardProfileScreen> createState() =>
      _PublicLeaderboardProfileScreenState();
}

class _PublicLeaderboardProfileScreenState
    extends State<PublicLeaderboardProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerAnimController;
  late AnimationController _floatingBlobController;
  late Animation<double> _headerFade;

  Map<String, dynamic>? _cloudData;
  bool _loadingCloud = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    );
    _floatingBlobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _loadCloudData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimController.dispose();
    _floatingBlobController.dispose();
    super.dispose();
  }

  Future<void> _loadCloudData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('leaderboard_v1_users')
          .doc(widget.entry.uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));

      if (doc.exists && mounted) {
        setState(() {
          _cloudData = doc.data();
          _loadingCloud = false;
          _isOffline = false;
        });
      } else if (mounted) {
        setState(() => _loadingCloud = false);
      }
      _headerAnimController.forward();
    } catch (e) {
      debugPrint('⚠️ Cloud data load failed: $e');
      try {
        final cachedDoc = await FirebaseFirestore.instance
            .collection('leaderboard_v1_users')
            .doc(widget.entry.uid)
            .get(const GetOptions(source: Source.cache));

        if (cachedDoc.exists && mounted) {
          setState(() {
            _cloudData = cachedDoc.data();
            _loadingCloud = false;
            _isOffline = true;
          });
        } else if (mounted) {
          setState(() {
            _loadingCloud = false;
            _isOffline = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loadingCloud = false;
            _isOffline = true;
          });
        }
      }
      _headerAnimController.forward();
    }
  }

  bool get _isSelf => widget.entry.uid == widget.me.uid;

  T _cloudOr<T>(String key, T fallback) {
    final v = _cloudData?[key];
    if (v == null) return fallback;
    if (v is T) {
      if (v is String && v.trim().isEmpty) return fallback;
      return v;
    }
    return fallback;
  }

  String _memberForText(int joinedAtMs) {
    if (joinedAtMs <= 0) return 'Member';
    final joined =
    DateTime.fromMillisecondsSinceEpoch(joinedAtMs, isUtc: true)
        .toLocal();
    final diffDays = DateTime.now().difference(joined).inDays;
    if (diffDays < 0) return 'Member';
    final years = diffDays ~/ 365;
    final months = (diffDays % 365) ~/ 30;
    final days = (diffDays % 365) % 30;
    if (years > 0) {
      return months > 0
          ? 'Member for $years yr $months mo'
          : 'Member for $years yr';
    }
    if (months > 0) {
      return days > 0
          ? 'Member for $months mo $days d'
          : 'Member for $months mo';
    }
    if (days > 0) return 'Member for $days d';
    return 'Just joined';
  }

  String _formatStudyTime(double hours) {
    if (hours <= 0) return '0 min';
    if (hours < 1) return '${(hours * 60).round()} min';
    if (hours < 100) return '${hours.toStringAsFixed(1)} hrs';
    return '${hours.toStringAsFixed(0)} hrs';
  }

  String _formatStudyMins(int mins) {
    if (mins <= 0) return '0 min';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _formatPostTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<String> _getBadgeNames(int count, List<String> unlockedBadges) {
    if (unlockedBadges.isNotEmpty) return unlockedBadges;
    if (count <= 0) return [];
    final all = [
      '⚡ Fast Starter',
      '🚀 Rising Star',
      '🔥 Streak Warrior',
      '💎 Elite Focus',
      '👑 Grand Master',
      '🌟 Living Legend',
      '🏆 Supreme Overlord',
      '✨ Mystic Sage',
      '🌌 Reality Bender',
    ];
    return all.take(count.clamp(0, all.length)).toList();
  }

  String _safeUidDisplay(String uid) {
    if (uid.length <= 14) return 'UID: $uid';
    return 'UID: ${uid.substring(0, 14)}...';
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isError
                      ? [
                    AppConfig.errorColor.withOpacity(0.9),
                    Colors.redAccent.withOpacity(0.8),
                  ]
                      : [
                    AppConfig.primaryColor.withOpacity(0.95),
                    const Color(0xFF3B82F6).withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border:
                Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    final isBlocked =
    LeaderboardModerationService.isBlocked(widget.entry.uid);
    try {
      if (isBlocked) {
        await LeaderboardModerationService.unblockUid(widget.entry.uid);
        _showSnack('Unblocked "${widget.entry.displayName}".');
      } else {
        await LeaderboardModerationService.blockUid(widget.entry.uid);
        _showSnack('Blocked "${widget.entry.displayName}".');
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _reportUser() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final can = await LeaderboardModerationService.canReportNow();
    if (!can) {
      _showSnack('Please wait before sending another report.',
          isError: true);
      return;
    }
    final result = await showDialog<ReportPayload>(
      context: context,
      builder: (_) => ReportDialog(
        isDark: isDark,
        targetName: widget.entry.displayName,
      ),
    );
    if (result == null) return;
    HapticFeedback.mediumImpact();
    try {
      await LeaderboardModerationService.reportUser(
        targetUid: widget.entry.uid,
        reasonId: result.reasonId,
        details: result.details,
        targetDisplayName: widget.entry.displayName,
        targetScore: widget.entry.score,
        targetRank: widget.rank,
      );
      await LeaderboardModerationService.markReportedNow();
      _showSnack('Report sent. Thank you.');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  void _openChat(String avatarEmoji) {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerUid: widget.entry.uid,
          peerName: widget.entry.displayName,
          peerAvatar: avatarEmoji,
        ),
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDark,
    double borderRadius = 20.0,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ]
                  : [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName =
    _cloudOr('displayName', widget.entry.displayName);
    final rawAvatar =
    _cloudOr('avatarEmoji', widget.entry.avatarEmoji);
    final avatarEmoji =
    rawAvatar.trim().isEmpty ? '🙂' : rawAvatar;
    final tagline =
    (_cloudOr('tagline', widget.entry.tagline ?? '')).trim();
    final bio =
    (_cloudOr('bio', widget.entry.bio ?? '')).trim();
    final joinedAtMs =
    _cloudOr('joinedAtMs', widget.entry.joinedAtMs);
    final level = _cloudOr('level', widget.entry.level);
    final studyHours =
    (_cloudOr<num>('studyHours', widget.entry.studyHours))
        .toDouble();
    final score =
    (_cloudOr<num>('score', widget.entry.score)).toDouble();
    final badgesUnlocked =
    _cloudOr('badgesUnlocked', widget.entry.badgesUnlocked);
    final dailyScore =
    _cloudOr('dailyScore', widget.entry.dailyScore);
    final weeklyScore =
    _cloudOr('weeklyScore', widget.entry.weeklyScore);
    final isProUser =
    _cloudOr('isProUser', widget.entry.isProUser);
    final showLevel =
    _cloudOr('showLevel', widget.entry.showLevel);
    final showBadges =
    _cloudOr('showBadges', widget.entry.showBadges);
    final showStudyHours =
    _cloudOr('showStudyHours', widget.entry.showStudyHours);
    final countryCode =
    (_cloudOr('countryCode', widget.entry.countryCode ?? ''))
        .trim();

    final unlockedBadges = widget.entry.unlockedBadges;
    final badgeNames =
    _getBadgeNames(badgesUnlocked, unlockedBadges);
    final memberText = _memberForText(joinedAtMs);
    final scoreText =
    score.isFinite ? score.toStringAsFixed(0) : '0';
    final showSelfProCrown =
        _isSelf && (widget.selfProLocal || widget.selfProVerified);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // ✅ Animated Background
          AnimatedBuilder(
            animation: _floatingBlobController,
            builder: (context, child) {
              final t =
                  _floatingBlobController.value * 2 * math.pi;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                          const Color(0xFF0F172A),
                          const Color(0xFF1E1B4B),
                        ]
                            : [
                          const Color(0xFFF1F5F9),
                          const Color(0xFFE0E7FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -100 + (50 * math.sin(t)),
                    right: -100 + (40 * math.cos(t)),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppConfig.primaryColor.withOpacity(
                                isDark ? 0.15 : 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80 + (50 * math.cos(t * 0.7)),
                    left: -120 + (60 * math.sin(t * 0.9)),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6C63FF).withOpacity(
                                isDark ? 0.1 : 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ✅ Main Scaffold with proper AppBar
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: _buildGlassContainer(
                    isDark: isDark,
                    padding: EdgeInsets.zero,
                    borderRadius: 14,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 18,
                    ),
                  ),
                ),
              ),
              title: Text(
                displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (!_isSelf) ...[
                  // Chat button
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: () => _openChat(avatarEmoji),
                      child: _buildGlassContainer(
                        isDark: isDark,
                        padding: const EdgeInsets.all(10),
                        borderRadius: 14,
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: AppConfig.primaryColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Report button
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: _reportUser,
                      child: _buildGlassContainer(
                        isDark: isDark,
                        padding: const EdgeInsets.all(10),
                        borderRadius: 14,
                        child: const Icon(
                          Icons.flag_outlined,
                          color: AppConfig.warningColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Block button
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 8, bottom: 8, right: 8),
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: LeaderboardModerationService
                          .blockedUidsNotifier,
                      builder: (context, blocked, _) {
                        final isBlocked =
                        blocked.contains(widget.entry.uid);
                        return GestureDetector(
                          onTap: _toggleBlock,
                          child: _buildGlassContainer(
                            isDark: isDark,
                            padding: const EdgeInsets.all(10),
                            borderRadius: 14,
                            child: Icon(
                              isBlocked
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black54,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (_isSelf) const SizedBox(width: 16),
              ],
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter:
                  ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                          const Color(0xFF0B1020)
                              .withOpacity(0.6),
                          const Color(0xFF1E1B4B)
                              .withOpacity(0.4),
                        ]
                            : [
                          Colors.white.withOpacity(0.7),
                          Colors.white.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            body: Column(
              children: [
                // ✅ Offline Banner
                if (_isOffline)
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.orange.withOpacity(0.15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 14,
                            color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Showing cached data • Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ✅ Scrollable body — কিছুই ঢাকে না
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ─── Profile Header ───
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(
                          isDark: isDark,
                          displayName: displayName,
                          avatarEmoji: avatarEmoji,
                          tagline: tagline,
                          memberText: memberText,
                          countryCode: countryCode,
                          isProUser: isProUser,
                          showSelfProCrown: showSelfProCrown,
                          level: level,
                          showLevel: showLevel,
                          studyHours: studyHours,
                          showStudyHours: showStudyHours,
                          score: scoreText,
                          rank: widget.rank,
                        ),
                      ),

                      // ─── Tab Bar (sticky) ───
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyTabBarDelegate(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 10, 16, 10),
                            child: _buildProfileTabBar(isDark),
                          ),
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                        ),
                      ),

                      // ─── Tab Content ───
                      SliverFillRemaining(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildStatsTab(
                              isDark: isDark,
                              level: level,
                              showLevel: showLevel,
                              studyHours: studyHours,
                              showStudyHours: showStudyHours,
                              score: score,
                              dailyScore: dailyScore,
                              weeklyScore: weeklyScore,
                              badgesUnlocked: badgesUnlocked,
                              rank: widget.rank,
                              bio: bio,
                            ),
                            _buildBadgesTab(
                              isDark: isDark,
                              showBadges: showBadges,
                              badgeNames: badgeNames,
                              badgesUnlocked: badgesUnlocked,
                            ),
                            _buildPostsTab(isDark: isDark),
                            _buildActivityTab(
                              isDark: isDark,
                              level: level,
                              showLevel: showLevel,
                              studyHours: studyHours,
                              dailyScore: dailyScore,
                              weeklyScore: weeklyScore,
                              score: score,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Profile Header — সব content এখানে
  Widget _buildProfileHeader({
    required bool isDark,
    required String displayName,
    required String avatarEmoji,
    required String tagline,
    required String memberText,
    required String countryCode,
    required bool isProUser,
    required bool showSelfProCrown,
    required int level,
    required bool showLevel,
    required double studyHours,
    required bool showStudyHours,
    required String score,
    required int rank,
  }) {
    final profileUid = widget.entry.uid;

    // ✅ Self হলে local study data দেখাও
    final todayMins = _isSelf
        ? DatabaseService.getTotalStudyMinutesToday()
        : 0;
    final yesterdayMins = _isSelf
        ? DatabaseService.getTotalStudyMinutesYesterday()
        : 0;

    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          children: [
            // ── Avatar ──
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 700),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, val, child) =>
                  Transform.scale(scale: val, child: child),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Glow
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppConfig.primaryColor
                              .withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  // Avatar circle
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppConfig.primaryColor,
                          AppConfig.primaryColor.withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        avatarEmoji,
                        style: const TextStyle(fontSize: 46),
                      ),
                    ),
                  ),
                  // Loading overlay
                  if (_loadingCloud)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black12,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // PRO badge
                  if (showSelfProCrown || isProUser)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFF59E0B),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF0B1020)
                                : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700)
                                  .withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  // Rank badge top-left
                  if (rank >= 1 && rank <= 3)
                    Positioned(
                      top: -8,
                      left: -8,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: rank == 1
                                ? [
                              const Color(0xFFFFD700),
                              const Color(0xFFFFA500),
                            ]
                                : rank == 2
                                ? [
                              const Color(0xFFC0C0C0),
                              const Color(0xFF9E9E9E),
                            ]
                                : [
                              const Color(0xFFCD7F32),
                              const Color(0xFF8B4513),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF0B1020)
                                : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (rank == 1
                                  ? const Color(0xFFFFD700)
                                  : rank == 2
                                  ? const Color(0xFFC0C0C0)
                                  : const Color(0xFFCD7F32))
                                  .withOpacity(0.6),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Name + Country ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color:
                      isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (countryCode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(countryCode,
                      style: const TextStyle(fontSize: 18)),
                ],
                if (_isSelf) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                      AppConfig.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppConfig.primaryColor
                            .withOpacity(0.35),
                      ),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppConfig.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // ── UID copy ──
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(
                    ClipboardData(text: profileUid));
                _showSnack('UID copied!');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.white54
                            : Colors.black45),
                    const SizedBox(width: 6),
                    Text(
                      _safeUidDisplay(profileUid),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white60
                            : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded,
                        size: 12,
                        color: isDark
                            ? Colors.white38
                            : Colors.black38),
                  ],
                ),
              ),
            ),

            // ── Tagline ──
            if (tagline.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tagline,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 10),

            // ── Member + Rank ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 13,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45),
                const SizedBox(width: 4),
                Text(
                  memberText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.leaderboard_rounded,
                    size: 13,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45),
                const SizedBox(width: 4),
                Text(
                  rank > 0 ? 'Rank #$rank' : 'Unranked',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Stat Chips ──
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                PublicStatChip(
                  label: 'Score',
                  value: score,
                  icon: Icons.stars_rounded,
                  color: AppConfig.accentColor,
                  isDark: isDark,
                ),
                if (showLevel)
                  PublicStatChip(
                    label: 'Level',
                    value: level.toString(),
                    icon: Icons.trending_up_rounded,
                    color: AppConfig.primaryColor,
                    isDark: isDark,
                  ),
                if (showStudyHours && studyHours > 0)
                  PublicStatChip(
                    label: 'Study',
                    value: _formatStudyTime(studyHours),
                    icon: Icons.timer_rounded,
                    color: AppConfig.successColor,
                    isDark: isDark,
                  ),
              ],
            ),

            // ✅ Self হলে Today + Yesterday Focus Time দেখাও
            if (_isSelf && (todayMins > 0 || yesterdayMins > 0)) ...[
              const SizedBox(height: 14),
              _buildGlassContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Row(
                  children: [
                    // Today
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.today_rounded,
                                  size: 14,
                                  color: Color(0xFF00C853)),
                              const SizedBox(width: 5),
                              Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatStudyMins(todayMins),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00C853),
                            ),
                          ),
                          Text(
                            'Focus',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: 44,
                      color: isDark
                          ? Colors.white12
                          : Colors.black12,
                    ),
                    // Yesterday
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.history_rounded,
                                  size: 14,
                                  color: AppConfig.primaryColor),
                              const SizedBox(width: 5),
                              Text(
                                'Yesterday',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatStudyMins(yesterdayMins),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppConfig.primaryColor,
                            ),
                          ),
                          Text(
                            'Focus',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ✅ Like Button (not self)
            if (!_isSelf) ...[
              const SizedBox(height: 16),
              _LikeButton(
                targetUid: widget.entry.uid,
                myUid: widget.me.uid,
                isDark: isDark,
              ),
            ],

            // ✅ Liked By count (not self)
            if (!_isSelf) ...[
              const SizedBox(height: 10),
              _LikedByButton(
                targetUid: widget.entry.uid,
                isDark: isDark,
              ),
            ],

            // ✅ Chat Button (not self) — সবার শেষে, কিছুই ঢাকে না
            if (!_isSelf) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _openChat(avatarEmoji),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppConfig.primaryColor,
                          Color(0xFF3B82F6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppConfig.primaryColor
                              .withOpacity(0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_rounded,
                            color: Colors.white, size: 19),
                        SizedBox(width: 9),
                        Text(
                          'Send Message',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ Sticky Tab Bar
  Widget _buildProfileTabBar(bool isDark) {
    return _buildGlassContainer(
      isDark: isDark,
      padding: const EdgeInsets.all(5),
      borderRadius: 18,
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppConfig.primaryColor, Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppConfig.primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor:
        isDark ? Colors.white60 : Colors.black54,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'STATS'),
          Tab(text: 'BADGES'),
          Tab(text: 'POSTS'),
          Tab(text: 'ACTIVITY'),
        ],
      ),
    );
  }

  Widget _buildStatsTab({
    required bool isDark,
    required int level,
    required bool showLevel,
    required double studyHours,
    required bool showStudyHours,
    required double score,
    required int dailyScore,
    required int weeklyScore,
    required int badgesUnlocked,
    required int rank,
    required String bio,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bio.isNotEmpty) ...[
            _sectionCard(
              isDark: isDark,
              icon: Icons.person_rounded,
              title: 'About',
              color: AppConfig.primaryColor,
              child: Text(
                bio,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color:
                  isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          _sectionCard(
            isDark: isDark,
            icon: Icons.leaderboard_rounded,
            title: 'Score Overview',
            color: const Color(0xFFFFD700),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PublicStatBox(
                        label: 'All-Time',
                        value: score.toStringAsFixed(0),
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFFFFD700),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PublicStatBox(
                        label: 'Rank',
                        value: rank > 0 ? '#$rank' : '—',
                        icon: Icons.military_tech_rounded,
                        color: AppConfig.primaryColor,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PublicStatBox(
                        label: 'This Week',
                        value: '$weeklyScore',
                        icon: Icons.date_range_rounded,
                        color: const Color(0xFFF355DA),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PublicStatBox(
                        label: 'Badges',
                        value: '$badgesUnlocked',
                        icon: Icons.workspace_premium_rounded,
                        color: AppConfig.accentColor,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (showStudyHours || showLevel)
            Row(
              children: [
                if (showStudyHours)
                  Expanded(
                    child: _sectionCard(
                      isDark: isDark,
                      icon: Icons.timer_rounded,
                      title: 'Study Time',
                      color: AppConfig.successColor,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatStudyTime(studyHours),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppConfig.successColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total study',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (showStudyHours && showLevel)
                  const SizedBox(width: 12),
                if (showLevel)
                  Expanded(
                    child: _sectionCard(
                      isDark: isDark,
                      icon: Icons.trending_up_rounded,
                      title: 'Level',
                      color: AppConfig.primaryColor,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lv $level',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppConfig.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current level',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBadgesTab({
    required bool isDark,
    required bool showBadges,
    required List<String> badgeNames,
    required int badgesUnlocked,
  }) {
    if (!showBadges) {
      return _buildCenterMessage(
        isDark,
        Icons.lock_rounded,
        'Badges Hidden',
        'This user has hidden their badges.',
      );
    }
    if (badgeNames.isEmpty) {
      return _buildCenterMessage(
        isDark,
        null,
        'No Badges Yet',
        'Keep studying to unlock badges!',
        emoji: '🏆',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildGlassContainer(
            isDark: isDark,
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFD700),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$badgesUnlocked Badge${badgesUnlocked != 1 ? 's' : ''} Unlocked',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color:
                    isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badgeNames.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (_, i) {
              final badge = badgeNames[i];
              final parts = badge.split(' ');
              final emoji =
              parts.isNotEmpty ? parts.first : '🏆';
              final name = parts.length > 1
                  ? parts.sublist(1).join(' ')
                  : badge;
              return TweenAnimationBuilder(
                duration:
                Duration(milliseconds: 350 + (i * 80)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, val, child) => Transform.scale(
                  scale: val,
                  child: Opacity(opacity: val, child: child),
                ),
                child: _buildGlassContainer(
                  isDark: isDark,
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab({required bool isDark}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leaderboard_v1_posts')
          .where('authorUid', isEqualTo: widget.entry.uid)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCenterMessage(
            isDark,
            Icons.cloud_off_rounded,
            'Unable to Load Posts',
            'Check your internet connection.',
            showRetry: true,
          );
        }
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppConfig.primaryColor),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildCenterMessage(
            isDark,
            null,
            'No Posts Yet',
            'Posts will appear here.',
            emoji: '📝',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data =
            docs[index].data() as Map<String, dynamic>;
            final content =
                data['content'] as String? ?? '';
            final ts = data['timestamp'] as Timestamp?;
            final timeStr = ts != null
                ? _formatPostTime(ts.toDate())
                : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: _buildGlassContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppConfig.primaryColor,
                                Color(0xFF3B82F6),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              data['authorAvatar'] ?? '🙂',
                              style: const TextStyle(
                                  fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['authorName'] ?? '',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: isDark
                            ? Colors.white.withOpacity(0.85)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivityTab({
    required bool isDark,
    required int level,
    required bool showLevel,
    required double studyHours,
    required int dailyScore,
    required int weeklyScore,
    required double score,
  }) {
    final sessionsEstimate = studyHours > 0
        ? ((studyHours * 60) / 25).ceil()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _sectionCard(
            isDark: isDark,
            icon: Icons.bolt_rounded,
            title: 'Activity Overview',
            color: AppConfig.accentColor,
            child: Column(
              children: [
                PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.date_range_rounded,
                  label: 'Weekly Score',
                  value: '$weeklyScore XP',
                  color: const Color(0xFFF355DA),
                ),
                const SizedBox(height: 14),
                PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.emoji_events_rounded,
                  label: 'All-Time XP',
                  value: '${score.toStringAsFixed(0)} XP',
                  color: const Color(0xFFFFD700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            isDark: isDark,
            icon: Icons.school_rounded,
            title: 'Study Activity',
            color: AppConfig.successColor,
            child: Column(
              children: [
                PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.timer_rounded,
                  label: 'Total Study Time',
                  value: _formatStudyTime(studyHours),
                  color: AppConfig.successColor,
                ),
                const SizedBox(height: 14),
                PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.self_improvement_rounded,
                  label: 'Est. Sessions',
                  value: '$sessionsEstimate sessions',
                  color: AppConfig.primaryColor,
                ),
                if (showLevel) ...[
                  const SizedBox(height: 14),
                  PublicActivityRow(
                    isDark: isDark,
                    icon: Icons.trending_up_rounded,
                    label: 'Current Level',
                    value: 'Level $level',
                    color: AppConfig.primaryColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return _buildGlassContainer(
      isDark: isDark,
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color:
                  isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCenterMessage(
      bool isDark,
      IconData? icon,
      String title,
      String subtitle, {
        String? emoji,
        bool showRetry = false,
      }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 64))
            else if (icon != null)
              Icon(icon,
                  size: 64,
                  color: isDark
                      ? Colors.white24
                      : Colors.black12),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color:
                isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color:
                isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
            if (showRetry) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded,
                    size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: AppConfig.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ✅ Sticky Tab Bar Delegate
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color color;

  const _StickyTabBarDelegate({
    required this.child,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return Container(color: color, child: child);
  }

  @override
  double get maxExtent => 66;

  @override
  double get minExtent => 66;

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════
// ❤️ LIKE BUTTON
// ═══════════════════════════════════════════════════

class _LikeButton extends StatefulWidget {
  const _LikeButton({
    required this.targetUid,
    required this.myUid,
    required this.isDark,
  });

  final String targetUid;
  final String myUid;
  final bool isDark;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _isLoading = false;
  bool _localIsLiked = false;
  int _localLikeCount = 0;
  bool _hasStreamError = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.4, end: 0.85), weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_isLoading) return;
    HapticFeedback.mediumImpact();
    _animController.forward(from: 0);
    setState(() => _isLoading = true);
    try {
      await ProfileLikeService.instance.toggleLike(
        targetUid: widget.targetUid,
        myUid: widget.myUid,
      );
      if (mounted) {
        setState(() {
          _localIsLiked = !_localIsLiked;
          _localLikeCount += _localIsLiked ? 1 : -1;
          if (_localLikeCount < 0) _localLikeCount = 0;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ProfileLikeService.instance.hasLikedStream(
        targetUid: widget.targetUid,
        myUid: widget.myUid,
      ),
      builder: (context, likedSnap) {
        if (likedSnap.hasError) _hasStreamError = true;
        final isLiked = likedSnap.data ?? _localIsLiked;

        return StreamBuilder<int>(
          stream: ProfileLikeService.instance
              .likeCountStream(targetUid: widget.targetUid),
          builder: (context, countSnap) {
            if (countSnap.hasError) _hasStreamError = true;
            final likeCount =
                countSnap.data ?? _localLikeCount;
            if (!_hasStreamError) {
              _localIsLiked = isLiked;
              _localLikeCount = likeCount;
            }

            return GestureDetector(
              onTap: _isLoading ? null : _onTap,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: isLiked
                        ? const LinearGradient(
                      colors: [
                        Color(0xFFFF4D6D),
                        Color(0xFFFF0040),
                      ],
                    )
                        : LinearGradient(
                      colors: [
                        (widget.isDark
                            ? Colors.white
                            : Colors.black)
                            .withOpacity(0.1),
                        (widget.isDark
                            ? Colors.white
                            : Colors.black)
                            .withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isLiked
                          ? const Color(0xFFFF4D6D)
                          .withOpacity(0.6)
                          : (widget.isDark
                          ? Colors.white
                          : Colors.black)
                          .withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: isLiked
                        ? [
                      BoxShadow(
                        color: const Color(0xFFFF4D6D)
                            .withOpacity(0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: isLiked
                              ? Colors.white
                              : AppConfig.primaryColor,
                        ),
                      )
                          : Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isLiked
                            ? Colors.white
                            : (widget.isDark
                            ? Colors.white70
                            : Colors.black54),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        likeCount > 0
                            ? '$likeCount Like${likeCount != 1 ? 's' : ''}'
                            : isLiked
                            ? 'Liked'
                            : 'Like',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isLiked
                              ? Colors.white
                              : (widget.isDark
                              ? Colors.white70
                              : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// 👥 LIKED BY BUTTON
// ═══════════════════════════════════════════════════

class _LikedByButton extends StatelessWidget {
  const _LikedByButton(
      {required this.targetUid, required this.isDark});
  final String targetUid;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ProfileLikeService.instance
          .likeCountStream(targetUid: targetUid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _LikedBySheet(
                  targetUid: targetUid, isDark: isDark),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded,
                    color: Color(0xFFFF4D6D), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Liked by $count ${count == 1 ? 'person' : 'people'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark
                      ? Colors.white38
                      : Colors.black38,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LikedBySheet extends StatelessWidget {
  const _LikedBySheet(
      {required this.targetUid, required this.isDark});
  final String targetUid;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, sc) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  const Color(0xFF151C2F)
                      .withOpacity(0.96),
                  const Color(0xFF0B1020)
                      .withOpacity(0.98),
                ]
                    : [
                  Colors.white.withOpacity(0.96),
                  const Color(0xFFF8FAFC)
                      .withOpacity(0.98),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white30
                        : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      24, 20, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded,
                          color: Color(0xFFFF4D6D), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Liked By',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? Colors.white54
                              : Colors.black45,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<LikerInfo>>(
                    stream: ProfileLikeService.instance
                        .whoLikedStream(targetUid: targetUid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppConfig.primaryColor,
                            strokeWidth: 3,
                          ),
                        );
                      }
                      final likers = snapshot.data ?? [];
                      if (likers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💔',
                                  style:
                                  TextStyle(fontSize: 60)),
                              const SizedBox(height: 16),
                              Text(
                                'No likes yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.fromLTRB(
                            20, 8, 20, 32),
                        itemCount: likers.length,
                        itemBuilder: (_, i) {
                          return TweenAnimationBuilder(
                            duration: Duration(
                                milliseconds:
                                300 + (i * 50)),
                            tween:
                            Tween<double>(begin: 0, end: 1),
                            builder: (context, val, child) =>
                                Transform.translate(
                                  offset:
                                  Offset(0, (1 - val) * 20),
                                  child: Opacity(
                                      opacity: val, child: child),
                                ),
                            child: _LikerTile(
                              liker: likers[i],
                              isDark: isDark,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  const _LikerTile(
      {required this.liker, required this.isDark});
  final LikerInfo liker;
  final bool isDark;

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ProfileLikeService.instance
          .getLikerProfile(liker.uid),
      builder: (context, snap) {
        final data = snap.data;
        final name =
            (data?['displayName'] as String?) ?? 'Player';
        final avatar =
            (data?['avatarEmoji'] as String?) ?? '🙂';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConfig.primaryColor,
                      Color(0xFF3B82F6),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(avatar,
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF4D6D),
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _fmt(liker.likedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════

class PublicStatChip extends StatelessWidget {
  const PublicStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white54
                      : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PublicStatBox extends StatelessWidget {
  const PublicStatBox({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: color.withOpacity(isDark ? 0.25 : 0.15),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PublicActivityRow extends StatelessWidget {
  const PublicActivityRow({
    super.key,
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final bool isDark;
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}