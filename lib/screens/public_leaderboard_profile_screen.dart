// lib/screens/public_leaderboard_profile_screen.dart

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/leaderboard_profile_model.dart';
import '../services/leaderboard_moderation_service.dart';
import '../services/leaderboard_service.dart';
import '../services/profile_like_service.dart';
import '../services/sound_service.dart';
import 'chat_screen.dart';
import 'leaderboard_profile_screen.dart';
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
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    );
    _loadCloudData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // DATA LOADING — offline safe
  // ═══════════════════════════════════════

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

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? AppConfig.errorColor : null,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content:
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    ));
  }

  // ═══════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════

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
      _showSnack('Please wait before sending another report.', isError: true);
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

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = _cloudOr('displayName', widget.entry.displayName);
    final rawAvatar = _cloudOr('avatarEmoji', widget.entry.avatarEmoji);
    final avatarEmoji = rawAvatar.trim().isEmpty ? '🙂' : rawAvatar;
    final tagline =
    (_cloudOr('tagline', widget.entry.tagline ?? '')).trim();
    final bio = (_cloudOr('bio', widget.entry.bio ?? '')).trim();
    final joinedAtMs = _cloudOr('joinedAtMs', widget.entry.joinedAtMs);
    final level = _cloudOr('level', widget.entry.level);
    final studyHours =
    (_cloudOr<num>('studyHours', widget.entry.studyHours)).toDouble();
    final score =
    (_cloudOr<num>('score', widget.entry.score)).toDouble();
    final badgesUnlocked =
    _cloudOr('badgesUnlocked', widget.entry.badgesUnlocked);
    final dailyScore = _cloudOr('dailyScore', widget.entry.dailyScore);
    final weeklyScore = _cloudOr('weeklyScore', widget.entry.weeklyScore);
    final isProUser = _cloudOr('isProUser', widget.entry.isProUser);
    final showLevel = _cloudOr('showLevel', widget.entry.showLevel);
    final showBadges = _cloudOr('showBadges', widget.entry.showBadges);
    final showStudyHours =
    _cloudOr('showStudyHours', widget.entry.showStudyHours);
    final countryCode =
    (_cloudOr('countryCode', widget.entry.countryCode ?? '')).trim();

    final unlockedBadges = widget.entry.unlockedBadges;
    final badgeNames = _getBadgeNames(badgesUnlocked, unlockedBadges);
    final memberText = _memberForText(joinedAtMs);
    final scoreText = score.isFinite ? score.toStringAsFixed(0) : '0';
    final showSelfProCrown =
        _isSelf && (widget.selfProLocal || widget.selfProVerified);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(
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
            dailyScore: dailyScore,
            weeklyScore: weeklyScore,
            badgesUnlocked: badgesUnlocked,
            rank: widget.rank,
          ),
        ],
        body: Column(
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: isDark
                    ? Colors.orange.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Showing cached data • Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              color: isDark
                  ? const Color(0xFF0B1020)
                  : const Color(0xFFF7F8FC),
              child: _buildProfileTabBar(isDark),
            ),
            Expanded(
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
    );
  }

  // ═══════════════════════════════════════
  // SLIVER APP BAR — dynamic height
  // ═══════════════════════════════════════

  Widget _buildSliverAppBar({
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
    required int dailyScore,
    required int weeklyScore,
    required int badgesUnlocked,
    required int rank,
  }) {
    // ✅ FIX: Dynamic height — content অনুযায়ী
    double headerHeight = _isSelf ? 340 : 500;
    if (tagline.isEmpty) headerHeight -= 28;

    return SliverAppBar(
      expandedHeight: headerHeight.clamp(320, 560),
      pinned: true,
      backgroundColor: isDark
          ? const Color(0xFF0B1020)
          : const Color(0xFFF7F8FC),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isSelf)
          IconButton(
            tooltip: 'Edit Profile',
            onPressed: () async {
              HapticFeedback.lightImpact();
              SoundService.playTap();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaderboardProfileScreen(),
                ),
              );
              _loadCloudData();
            },
            icon: Icon(Icons.edit_rounded,
                color: isDark ? Colors.white : Colors.black87),
          ),
        if (!_isSelf) ...[
          IconButton(
            tooltip: 'Send Message',
            onPressed: () => _openChat(avatarEmoji),
            icon: const Icon(Icons.chat_bubble_rounded,
                color: AppConfig.primaryColor),
          ),
          IconButton(
            tooltip: 'Report',
            onPressed: _reportUser,
            icon: const Icon(Icons.flag_outlined,
                color: AppConfig.warningColor),
          ),
          ValueListenableBuilder<Set<String>>(
            valueListenable:
            LeaderboardModerationService.blockedUidsNotifier,
            builder: (context, blocked, _) {
              final isBlocked = blocked.contains(widget.entry.uid);
              return IconButton(
                tooltip: isBlocked ? 'Unblock' : 'Block',
                onPressed: _toggleBlock,
                icon: Icon(
                  isBlocked
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              );
            },
          ),
        ],
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildProfileHeader(
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
          score: score,
          rank: rank,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // PROFILE HEADER — scrollable
  // ═══════════════════════════════════════

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

    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E1B4B), const Color(0xFF0B1020)]
                : [const Color(0xFFE0E7FF), const Color(0xFFF7F8FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppConfig.primaryColor,
                          AppConfig.primaryColor.withOpacity(0.6),
                        ]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                            AppConfig.primaryColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                          child: Text(avatarEmoji,
                              style: const TextStyle(fontSize: 42))),
                    ),
                    if (_loadingCloud)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black26,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    if (showSelfProCrown || isProUser)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF0B1020)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Text('PRO',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                    if (rank >= 1 && rank <= 3)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? const Color(0xFFFFD700)
                                : rank == 2
                                ? const Color(0xFFC0C0C0)
                                : const Color(0xFFCD7F32),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF0B1020)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Center(
                              child: Text('#$rank',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white))),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name + Country
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (countryCode.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(countryCode,
                          style: const TextStyle(fontSize: 14)),
                    ],
                    if (_isSelf) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('YOU',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppConfig.primaryColor)),
                      ),
                    ],
                  ],
                ),

                // UID Row
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    SoundService.playTap();
                    Clipboard.setData(ClipboardData(text: profileUid));
                    _showSnack('UID copied to clipboard!');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.1)),
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
                                  : Colors.black54),
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

                // Tagline
                if (tagline.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(tagline,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ],

                const SizedBox(height: 8),

                // Member + Rank
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13,
                        color:
                        isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 5),
                    Text(memberText,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : Colors.black45,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Icon(Icons.leaderboard_rounded,
                        size: 13,
                        color:
                        isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 5),
                    Text(rank > 0 ? 'Rank #$rank' : 'Unranked',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : Colors.black45,
                            fontWeight: FontWeight.w700)),
                  ],
                ),

                const SizedBox(height: 10),

                // Stat Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    PublicStatChip(
                        label: 'Score',
                        value: score,
                        icon: Icons.stars_rounded,
                        color: AppConfig.accentColor,
                        isDark: isDark),
                    if (showLevel)
                      PublicStatChip(
                          label: 'Level',
                          value: '$level',
                          icon: Icons.trending_up_rounded,
                          color: AppConfig.primaryColor,
                          isDark: isDark),
                    if (showStudyHours && studyHours > 0)
                      PublicStatChip(
                          label: 'Study',
                          value: _formatStudyTime(studyHours),
                          icon: Icons.timer_rounded,
                          color: AppConfig.successColor,
                          isDark: isDark),
                  ],
                ),

                // Like Button (not self)
                if (!_isSelf) ...[
                  const SizedBox(height: 14),
                  _LikeButton(
                    targetUid: widget.entry.uid,
                    myUid: widget.me.uid,
                    isDark: isDark,
                  ),
                ],

                // Liked By count
                if (!_isSelf) ...[
                  const SizedBox(height: 8),
                  _LikedByButton(
                    targetUid: widget.entry.uid,
                    isDark: isDark,
                  ),
                ],

                // Chat Button (not self)
                if (!_isSelf) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openChat(avatarEmoji),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded,
                          size: 18),
                      label: const Text('Send Message',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB BAR
  // ═══════════════════════════════════════

  Widget _buildProfileTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151C2F).withOpacity(0.9)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppConfig.primaryColor,
            AppConfig.primaryColor.withOpacity(0.75),
          ]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppConfig.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle:
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        unselectedLabelStyle:
        const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'STATS'),
          Tab(text: 'BADGES'),
          Tab(text: 'POSTS'),
          Tab(text: 'ACTIVITY'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // STATS TAB
  // ═══════════════════════════════════════

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
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
              child: Text(bio,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black87)),
            ),
            const SizedBox(height: 14),
          ],
          _sectionCard(
            isDark: isDark,
            icon: Icons.leaderboard_rounded,
            title: 'Score Overview',
            color: const Color(0xFFFFD700),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: PublicStatBox(
                        label: 'All-Time',
                        value: score.toStringAsFixed(0),
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFFFFD700),
                        isDark: isDark)),
                const SizedBox(width: 12),
                Expanded(
                    child: PublicStatBox(
                        label: 'Rank',
                        value: rank > 0 ? '#$rank' : '—',
                        icon: Icons.military_tech_rounded,
                        color: AppConfig.primaryColor,
                        isDark: isDark)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: PublicStatBox(
                        label: 'This Week',
                        value: '$weeklyScore',
                        icon: Icons.date_range_rounded,
                        color: const Color(0xFFF355DA),
                        isDark: isDark)),
                const SizedBox(width: 12),
                Expanded(
                    child: PublicStatBox(
                        label: 'Badges',
                        value: '$badgesUnlocked',
                        icon: Icons.workspace_premium_rounded,
                        color: AppConfig.accentColor,
                        isDark: isDark)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            if (showStudyHours)
              Expanded(
                child: _sectionCard(
                  isDark: isDark,
                  icon: Icons.timer_rounded,
                  title: 'Study Time',
                  color: AppConfig.successColor,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatStudyTime(studyHours),
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppConfig.successColor)),
                        const SizedBox(height: 4),
                        Text('Total study time',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black45)),
                      ]),
                ),
              ),
            if (showStudyHours && showLevel) const SizedBox(width: 12),
            if (showLevel)
              Expanded(
                child: _sectionCard(
                  isDark: isDark,
                  icon: Icons.trending_up_rounded,
                  title: 'Level',
                  color: AppConfig.primaryColor,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lv $level',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppConfig.primaryColor)),
                        const SizedBox(height: 4),
                        Text('Current level',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black45)),
                      ]),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // BADGES TAB
  // ═══════════════════════════════════════

  Widget _buildBadgesTab({
    required bool isDark,
    required bool showBadges,
    required List<String> badgeNames,
    required int badgesUnlocked,
  }) {
    if (!showBadges) {
      return _buildCenterMessage(isDark, Icons.lock_rounded, 'Badges Hidden',
          'This user has hidden their badges.');
    }

    if (badgeNames.isEmpty) {
      return _buildCenterMessage(isDark, null, 'No Badges Yet',
          'Keep studying to unlock badges!',
          emoji: '🏆');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFFD700).withOpacity(0.15),
                const Color(0xFFFFA500).withOpacity(0.05),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700)),
              const SizedBox(width: 10),
              Text(
                  '$badgesUnlocked Badge${badgesUnlocked != 1 ? 's' : ''} Unlocked',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87)),
            ]),
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
              childAspectRatio: 1.6,
            ),
            itemBuilder: (_, i) {
              final badge = badgeNames[i];
              final parts = badge.split(' ');
              final emoji = parts.isNotEmpty ? parts.first : '🏆';
              final name =
              parts.length > 1 ? parts.sublist(1).join(' ') : badge;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFFFFD700).withOpacity(0.12),
                    const Color(0xFFFFA500).withOpacity(0.04),
                  ]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.3)),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(name,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black87),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ]),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // POSTS TAB — offline safe
  // ═══════════════════════════════════════

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
          return _buildCenterMessage(isDark, Icons.cloud_off_rounded,
              'Unable to Load Posts', 'Check your internet connection.',
              showRetry: true);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppConfig.primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildCenterMessage(isDark, null, 'No Posts Yet',
              'Posts will appear here.',
              emoji: '📝');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final content = data['content'] as String? ?? '';
            final ts = data['timestamp'] as Timestamp?;
            final timeStr =
            ts != null ? _formatPostTime(ts.toDate()) : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black
                          .withOpacity(isDark ? 0.1 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color:
                          AppConfig.primaryColor.withOpacity(0.15),
                          shape: BoxShape.circle),
                      child: Center(
                          child: Text(data['authorAvatar'] ?? '🙂',
                              style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['authorName'] ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                            if (timeStr.isNotEmpty)
                              Text(timeStr,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38)),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(content,
                      style: TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: isDark
                              ? Colors.white.withOpacity(0.88)
                              : Colors.black87)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════
  // ACTIVITY TAB
  // ═══════════════════════════════════════

  Widget _buildActivityTab({
    required bool isDark,
    required int level,
    required bool showLevel,
    required double studyHours,
    required int dailyScore,
    required int weeklyScore,
    required double score,
  }) {
    final sessionsEstimate =
    studyHours > 0 ? ((studyHours * 60) / 25).ceil() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            isDark: isDark,
            icon: Icons.bolt_rounded,
            title: 'Activity Overview',
            color: AppConfig.accentColor,
            child: Column(children: [
              PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.date_range_rounded,
                  label: 'Weekly Score',
                  value: '$weeklyScore XP',
                  color: const Color(0xFFF355DA)),
              const SizedBox(height: 12),
              PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.emoji_events_rounded,
                  label: 'All-Time XP',
                  value: '${score.toStringAsFixed(0)} XP',
                  color: const Color(0xFFFFD700)),
            ]),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            isDark: isDark,
            icon: Icons.school_rounded,
            title: 'Study Activity',
            color: AppConfig.successColor,
            child: Column(children: [
              PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.timer_rounded,
                  label: 'Total Study Time',
                  value: _formatStudyTime(studyHours),
                  color: AppConfig.successColor),
              const SizedBox(height: 12),
              PublicActivityRow(
                  isDark: isDark,
                  icon: Icons.self_improvement_rounded,
                  label: 'Est. Sessions',
                  value: '$sessionsEstimate sessions',
                  color: AppConfig.primaryColor),
              if (showLevel) ...[
                const SizedBox(height: 12),
                PublicActivityRow(
                    isDark: isDark,
                    icon: Icons.trending_up_rounded,
                    label: 'Current Level',
                    value: 'Level $level',
                    color: AppConfig.primaryColor),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // REUSABLE HELPERS
  // ═══════════════════════════════════════

  Widget _sectionCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color:
                      isDark ? Colors.white : Colors.black87)),
            ]),
            const SizedBox(height: 16),
            child,
          ]),
    );
  }

  Widget _buildCenterMessage(
      bool isDark, IconData? icon, String title, String subtitle,
      {String? emoji, bool showRetry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (emoji != null)
            Text(emoji, style: const TextStyle(fontSize: 56))
          else if (icon != null)
            Icon(icon,
                size: 56, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38),
              textAlign: TextAlign.center),
          if (showRetry) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                  foregroundColor: AppConfig.primaryColor),
            ),
          ],
        ]),
      ),
    );
  }
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
        vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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
          targetUid: widget.targetUid, myUid: widget.myUid);
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
      stream: ProfileLikeService.instance
          .hasLikedStream(targetUid: widget.targetUid, myUid: widget.myUid),
      builder: (context, likedSnap) {
        if (likedSnap.hasError) _hasStreamError = true;
        final isLiked = likedSnap.data ?? _localIsLiked;

        return StreamBuilder<int>(
          stream: ProfileLikeService.instance
              .likeCountStream(targetUid: widget.targetUid),
          builder: (context, countSnap) {
            if (countSnap.hasError) _hasStreamError = true;
            final likeCount = countSnap.data ?? _localLikeCount;
            if (!_hasStreamError) {
              _localIsLiked = isLiked;
              _localLikeCount = likeCount;
            }

            return GestureDetector(
              onTap: _isLoading ? null : _onTap,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isLiked
                        ? const LinearGradient(
                        colors: [Color(0xFFFF4D6D), Color(0xFFFF0040)])
                        : LinearGradient(colors: [
                      (widget.isDark ? Colors.white : Colors.black)
                          .withOpacity(0.06),
                      (widget.isDark ? Colors.white : Colors.black)
                          .withOpacity(0.03),
                    ]),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isLiked
                          ? const Color(0xFFFF4D6D).withOpacity(0.5)
                          : (widget.isDark ? Colors.white : Colors.black)
                          .withOpacity(0.12),
                      width: 1.5,
                    ),
                    boxShadow: isLiked
                        ? [
                      BoxShadow(
                          color: const Color(0xFFFF4D6D)
                              .withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoading
                          ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isLiked
                                  ? Colors.white
                                  : AppConfig.primaryColor))
                          : Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked
                              ? Colors.white
                              : (widget.isDark
                              ? Colors.white70
                              : Colors.black54),
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        likeCount > 0
                            ? '$likeCount Like${likeCount != 1 ? 's' : ''}'
                            : isLiked
                            ? 'Liked'
                            : 'Like',
                        style: TextStyle(
                          fontSize: 14,
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
  const _LikedByButton({required this.targetUid, required this.isDark});
  final String targetUid;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream:
      ProfileLikeService.instance.likeCountStream(targetUid: targetUid),
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
              builder: (_) =>
                  _LikedBySheet(targetUid: targetUid, isDark: isDark),
            );
          },
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite_rounded,
                  color: Color(0xFFFF4D6D), size: 15),
              const SizedBox(width: 6),
              Text(
                  'Liked by $count ${count == 1 ? 'person' : 'people'}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                      isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black38),
            ]),
          ),
        );
      },
    );
  }
}

class _LikedBySheet extends StatelessWidget {
  const _LikedBySheet({required this.targetUid, required this.isDark});
  final String targetUid;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, sc) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2F) : Colors.white,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(Icons.favorite_rounded,
                  color: Color(0xFFFF4D6D), size: 22),
              const SizedBox(width: 10),
              Text('Liked By',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color:
                      isDark ? Colors.white54 : Colors.black45)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<LikerInfo>>(
              stream: ProfileLikeService.instance
                  .whoLikedStream(targetUid: targetUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppConfig.primaryColor));
                }
                final likers = snapshot.data ?? [];
                if (likers.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💔', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text('No likes yet',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45)),
                          ]));
                }
                return ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: likers.length,
                  itemBuilder: (_, i) => _LikerTile(
                      liker: likers[i], isDark: isDark),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  const _LikerTile({required this.liker, required this.isDark});
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
      future: ProfileLikeService.instance.getLikerProfile(liker.uid),
      builder: (context, snap) {
        final data = snap.data;
        final name = (data?['displayName'] as String?) ?? 'Player';
        final avatar = (data?['avatarEmoji'] as String?) ?? '🙂';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04)),
          ),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppConfig.primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle),
                child:
                Center(child: Text(avatar, style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.favorite_rounded,
                            color: Color(0xFFFF4D6D), size: 11),
                        const SizedBox(width: 4),
                        Text(_fmt(liker.likedAt),
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38)),
                      ]),
                    ])),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════

class PublicStatChip extends StatelessWidget {
  const PublicStatChip(
      {super.key,
        required this.label,
        required this.value,
        required this.icon,
        required this.color,
        required this.isDark});
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45)),
        ]),
      ]),
    );
  }
}

class PublicStatBox extends StatelessWidget {
  const PublicStatBox(
      {super.key,
        required this.label,
        required this.value,
        required this.icon,
        required this.color,
        required this.isDark});
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: color.withOpacity(isDark ? 0.2 : 0.15)),
      ),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87),
                  overflow: TextOverflow.ellipsis),
            ])),
      ]),
    );
  }
}

class PublicActivityRow extends StatelessWidget {
  const PublicActivityRow(
      {super.key,
        required this.isDark,
        required this.icon,
        required this.label,
        required this.value,
        required this.color});
  final bool isDark;
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87))),
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900, color: color)),
    ]);
  }
}