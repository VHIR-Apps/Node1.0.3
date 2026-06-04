// lib/screens/leaderboard_screen.dart

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/leaderboard_profile_model.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';
import '../services/leaderboard_moderation_service.dart';
import '../services/leaderboard_service.dart';
import '../services/purchase_service.dart';
import '../services/sound_service.dart';
import 'leaderboard_profile_screen.dart';
import 'public_leaderboard_profile_screen.dart';
import 'leaderboard_social_tab.dart';
import 'inbox_screen.dart';
import 'chat_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() =>
      _LeaderboardScreenState();
}

class _LeaderboardScreenState
    extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  LeaderboardPeriod _currentPeriod =
      LeaderboardPeriod.weekly;
  int _lastTabIndex = 0;

  final Map<LeaderboardPeriod, List<LeaderboardEntry>?>
  _topByPeriod = {
    LeaderboardPeriod.weekly: null,
    LeaderboardPeriod.allTime: null,
  };

  final Map<LeaderboardPeriod, int> _rankByPeriod = {
    LeaderboardPeriod.weekly: -1,
    LeaderboardPeriod.allTime: -1,
  };

  final Map<LeaderboardPeriod, bool>
  _loadingByPeriod = {
    LeaderboardPeriod.weekly: false,
    LeaderboardPeriod.allTime: false,
  };

  final Map<LeaderboardPeriod, String>
  _errorByPeriod = {
    LeaderboardPeriod.weekly: '',
    LeaderboardPeriod.allTime: '',
  };

  bool _syncing = false;

  late final AnimationController _animC =
  AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final Animation<double> _fade =
  CurvedAnimation(
    parent: _animC,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide =
  Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(
      parent: _animC,
      curve: Curves.easeOutCubic));

  String? _activeUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: 0);
    _lastTabIndex = _tabController.index;
    _tabController.addListener(_onTabChanged);
    LeaderboardModerationService.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoLoadCurrentTab();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _animC.dispose();
    super.dispose();
  }

  bool get _isCurrentLoading =>
      _loadingByPeriod[_currentPeriod] ?? false;
  String get _currentError =>
      _errorByPeriod[_currentPeriod] ?? '';
  List<LeaderboardEntry> get _currentTop =>
      _topByPeriod[_currentPeriod] ?? const [];
  int get _currentRank =>
      _rankByPeriod[_currentPeriod] ?? -1;
  bool get _isAnyBusy =>
      _syncing || _isCurrentLoading;

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  String _memberForText(int joinedAtMs) {
    if (joinedAtMs <= 0) return 'Member';
    final joined =
    DateTime.fromMillisecondsSinceEpoch(
        joinedAtMs,
        isUtc: true)
        .toLocal();
    final diffDays =
        DateTime.now().difference(joined).inDays;
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

  List<String> _getExplicitBadgeNames(
      int badgeCount) {
    if (badgeCount <= 0) return [];
    final allBadges = [
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
    return allBadges
        .take(badgeCount > allBadges.length
        ? allBadges.length
        : badgeCount)
        .toList();
  }

  double _safeDouble(Object? v) =>
      v is num ? v.toDouble() : 0.0;

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppConfig.primaryColor;
  }

  String _getScoreForEntry(LeaderboardEntry entry) {
    final score = switch (_currentPeriod) {
      LeaderboardPeriod.daily =>
          entry.dailyScore.toDouble(),
      LeaderboardPeriod.weekly =>
          entry.weeklyScore.toDouble(),
      LeaderboardPeriod.allTime => entry.score,
    };
    return score.isFinite
        ? score.toStringAsFixed(0)
        : '0';
  }

  String _prettyError(Object e) {
    if (e is AuthServiceException) return e.message;
    final msg = e.toString();
    if (msg.contains('Sign-in cancelled'))
      return 'Sign-in was cancelled.';
    if (msg.contains('network-request-failed'))
      return 'No internet connection.';
    if (msg
        .toLowerCase()
        .contains('permission-denied'))
      return 'Permission denied. Please sign in again.';
    return msg
        .replaceAll('AuthServiceException:', '')
        .replaceAll(
        'LeaderboardServiceException:', '')
        .replaceAll(
        'LeaderboardModerationException:', '')
        .trim();
  }

  void _showSnack(String text,
      {bool isError = false,
        SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
        isError ? AppConfig.errorColor : null,
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
            16, 0, 16, 16),
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(14)),
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons
                .check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════

  void _openInbox() {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const InboxScreen()));
  }

  void _showSearchSheet(
      BuildContext context, User me) {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          PlayerSearchSheet(me: me),
    );
  }

  Future<void> _ensureSignedIn() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    if (!ConnectivityService.instance.isOnline) {
      _showSnack(
          'You are offline. Connect to internet to sign in.',
          isError: true);
      return;
    }

    try {
      final user = await AuthService.instance
          .ensureSignedInOnDemand(
          interactive: true);
      if (user != null) {
        _showSnack('Signed in successfully.');
        await _maybeAutoLoadCurrentTab();
      }
    } catch (e) {
      _showSnack(_prettyError(e), isError: true);
    }
  }

  Future<void> _openProfileEditor() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    final me = AuthService.instance.currentUser;
    if (me == null) {
      _showSnack('Please sign in first.',
          isError: true);
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
          const LeaderboardProfileScreen()),
    );
    if (result == true) {
      await _ensurePeriodLoaded(
        period: _currentPeriod,
        syncBeforeFetch: true,
        haptic: false,
        forceRefresh: true,
      );
    }
  }

  Future<void> _openPublicProfile({
    required User me,
    required int rank,
    required LeaderboardEntry entry,
    required bool selfProLocal,
    required bool selfProVerified,
  }) async {
    HapticFeedback.selectionClick();
    SoundService.playTap();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PublicLeaderboardProfileScreen(
              me: me,
              entry: entry,
              rank: rank,
              selfProLocal: selfProLocal,
              selfProVerified: selfProVerified,
            ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB LOGIC
  // ═══════════════════════════════════════

  void _onTabChanged() {
    final idx = _tabController.index;
    if (idx == _lastTabIndex) return;
    _lastTabIndex = idx;

    if (idx == 2) {
      setState(() {});
      return;
    }

    final nextPeriod = switch (idx) {
      0 => LeaderboardPeriod.weekly,
      _ => LeaderboardPeriod.allTime,
    };

    if (nextPeriod == _currentPeriod) return;
    setState(() => _currentPeriod = nextPeriod);
    HapticFeedback.selectionClick();
    _animC.forward(from: 0);

    Future.microtask(() async {
      await _ensurePeriodLoaded(
          period: nextPeriod,
          syncBeforeFetch: false,
          haptic: false);
    });
  }

  // ═══════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════

  Future<void> _maybeAutoLoadCurrentTab() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final local = DatabaseService
        .getLeaderboardProfileForUid(user.uid);
    if (local == null || !local.isOptedIn) return;
    _activeUid = user.uid;
    if (_tabController.index != 2) {
      await _ensurePeriodLoaded(
          period: _currentPeriod,
          syncBeforeFetch: true,
          haptic: false);
    }
  }

  Future<void> _ensurePeriodLoaded({
    required LeaderboardPeriod period,
    required bool syncBeforeFetch,
    required bool haptic,
    bool forceRefresh = false,
  }) async {
    if (!mounted || _tabController.index == 2) return;
    final alreadyLoaded =
        _topByPeriod[period] != null;
    final currentlyLoading =
        _loadingByPeriod[period] ?? false;
    if (currentlyLoading) return;
    if (alreadyLoaded && !forceRefresh) return;
    if (haptic) HapticFeedback.lightImpact();

    setState(() {
      _loadingByPeriod[period] = true;
      _errorByPeriod[period] = '';
    });

    try {
      final user =
          AuthService.instance.currentUser;
      if (user == null) {
        throw const LeaderboardServiceException(
            'Please sign in to view the leaderboard.');
      }

      if (_activeUid != null &&
          _activeUid != user.uid) {
        _resetAllCachesForUser(user.uid);
      }
      _activeUid = user.uid;

      final profile = DatabaseService
          .getLeaderboardProfileForUid(user.uid);
      if (profile == null) {
        throw const LeaderboardServiceException(
            'Please create your leaderboard profile first.');
      }
      if (!profile.isOptedIn) {
        throw const LeaderboardServiceException(
            'Leaderboard is turned off.');
      }

      try {
        await user.getIdToken(false);
      } catch (_) {}

      if (syncBeforeFetch) {
        try {
          await LeaderboardService.instance
              .syncMyProfileToCloud();
        } catch (_) {}
      }

      final List<LeaderboardEntry> top =
      switch (period) {
        LeaderboardPeriod.daily =>
        await LeaderboardService.instance
            .fetchDailyLeaderboard(limit: 50),
        LeaderboardPeriod.weekly =>
        await LeaderboardService.instance
            .fetchWeeklyLeaderboard(limit: 50),
        LeaderboardPeriod.allTime =>
        await LeaderboardService.instance
            .fetchTop(limit: 50),
      };

      final double myScore = switch (period) {
        LeaderboardPeriod.daily =>
            profile.dailyScore.toDouble(),
        LeaderboardPeriod.weekly =>
            profile.weeklyScore.toDouble(),
        LeaderboardPeriod.allTime => _safeDouble(
            LeaderboardService.instance
                .getCurrentLocalMetrics()[
            'score']),
      };

      int myRank = -1;
      try {
        myRank = switch (period) {
          LeaderboardPeriod.daily =>
          await LeaderboardService.instance
              .fetchMyRankByPeriod(
              uid: user.uid,
              period:
              LeaderboardPeriod.daily,
              myScore: myScore,
              fallbackScanLimit: 500),
          LeaderboardPeriod.weekly =>
          await LeaderboardService.instance
              .fetchMyRankByPeriod(
              uid: user.uid,
              period:
              LeaderboardPeriod.weekly,
              myScore: myScore,
              fallbackScanLimit: 500),
          LeaderboardPeriod.allTime =>
          await LeaderboardService.instance
              .fetchMyRankExact(
              uid: user.uid,
              myScore: myScore,
              fallbackScanLimit: 500),
        };
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _topByPeriod[period] = top;
        _rankByPeriod[period] = myRank;
      });

      if (period == LeaderboardPeriod.allTime) {
        try {
          profile.cachedRank = myRank;
          profile.cachedScore = myScore;
          profile.lastCloudSyncAt = DateTime.now();
          profile.touchUpdated();
          await DatabaseService
              .saveLeaderboardProfile(profile);
        } catch (_) {}
      }

      _animC.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorByPeriod[period] =
          _prettyError(e));
    } finally {
      if (mounted) {
        setState(() =>
        _loadingByPeriod[period] = false);
      }
    }
  }

  void _resetAllCachesForUser(String uid) {
    _activeUid = uid;
    for (final p in [
      LeaderboardPeriod.weekly,
      LeaderboardPeriod.allTime,
    ]) {
      _topByPeriod[p] = null;
      _rankByPeriod[p] = -1;
      _loadingByPeriod[p] = false;
      _errorByPeriod[p] = '';
    }
  }

  Future<void> _syncAndReloadCurrent() async {
    if (_syncing) return;
    HapticFeedback.lightImpact();
    SoundService.playTap();
    setState(() => _syncing = true);
    try {
      await LeaderboardService.instance
          .syncMyProfileToCloud();
      if (!mounted) return;
      _showSnack('Synced successfully.');
      await _ensurePeriodLoaded(
          period: _currentPeriod,
          syncBeforeFetch: false,
          haptic: false,
          forceRefresh: true);
    } catch (e) {
      _showSnack(_prettyError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  // ═══════════════════════════════════════
  // USER ACTIONS
  // ═══════════════════════════════════════

  Future<void> _showUserActionsSheet({
    required bool isDark,
    required User me,
    required int rank,
    required LeaderboardEntry entry,
    required bool selfProLocal,
    required bool selfProVerified,
  }) async {
    if (!mounted) return;
    final isSelf = entry.uid == me.uid;
    final isBlocked =
    LeaderboardModerationService.isBlocked(
        entry.uid);
    HapticFeedback.lightImpact();
    SoundService.playTap();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = (isDark
            ? const Color(0xFF151C2F)
            : Colors.white)
            .withOpacity(isDark ? 0.92 : 0.96);
        return ClipRRect(
          borderRadius:
          const BorderRadius.vertical(
              top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(
                      color: isDark
                          ? Colors.white
                          .withOpacity(0.08)
                          : Colors.black
                          .withOpacity(
                          0.08))),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                  const EdgeInsets.fromLTRB(
                      18, 10, 18, 18),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                              color: isDark
                                  ? Colors
                                  .white24
                                  : Colors
                                  .black12,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  3))),
                      const SizedBox(height: 14),
                      Row(children: [
                        Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: AppConfig
                                    .primaryColor
                                    .withOpacity(
                                    0.15),
                                shape: BoxShape
                                    .circle),
                            child: Center(
                                child: Text(
                                    entry.avatarEmoji
                                        .isEmpty
                                        ? '🙂'
                                        : entry
                                        .avatarEmoji,
                                    style: const TextStyle(
                                        fontSize:
                                        22)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                      entry
                                          .displayName,
                                      style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .w900,
                                          fontSize:
                                          16,
                                          color: isDark
                                              ? Colors
                                              .white
                                              : Colors
                                              .black87),
                                      maxLines: 1,
                                      overflow:
                                      TextOverflow
                                          .ellipsis),
                                  const SizedBox(
                                      height: 3),
                                  Text(
                                      'Rank #$rank • Score ${_getScoreForEntry(entry)}',
                                      style: TextStyle(
                                          fontSize:
                                          12.5,
                                          color: isDark
                                              ? Colors
                                              .white60
                                              : Colors
                                              .black54)),
                                ])),
                        IconButton(
                            onPressed: () =>
                                Navigator.pop(
                                    ctx),
                            icon: Icon(
                                Icons
                                    .close_rounded,
                                color: isDark
                                    ? Colors
                                    .white70
                                    : Colors
                                    .black54)),
                      ]),
                      const SizedBox(height: 14),
                      _actionTile(
                          isDark: isDark,
                          enabled: true,
                          icon: isSelf
                              ? Icons
                              .edit_rounded
                              : Icons
                              .person_search_rounded,
                          color: AppConfig
                              .primaryColor,
                          title: isSelf
                              ? 'Edit Profile'
                              : 'View Profile',
                          subtitle: isSelf
                              ? 'Customize your public profile'
                              : 'See highlights and stats',
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (isSelf) {
                              await _openProfileEditor();
                            } else {
                              await _openPublicProfile(
                                  me: me,
                                  entry: entry,
                                  rank: rank,
                                  selfProLocal:
                                  selfProLocal,
                                  selfProVerified:
                                  selfProVerified);
                            }
                          }),
                      const SizedBox(height: 10),
                      _actionTile(
                          isDark: isDark,
                          enabled: !isSelf,
                          icon:
                          Icons.flag_outlined,
                          color: AppConfig
                              .warningColor,
                          title: 'Report',
                          subtitle:
                          'Report inappropriate content',
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _openReportFlow(
                                isDark: isDark,
                                me: me,
                                entry: entry,
                                rank: rank);
                          }),
                      const SizedBox(height: 10),
                      _actionTile(
                          isDark: isDark,
                          enabled: !isSelf,
                          icon: isBlocked
                              ? Icons
                              .visibility_rounded
                              : Icons
                              .visibility_off_rounded,
                          color:
                          AppConfig.infoColor,
                          title: isBlocked
                              ? 'Unblock'
                              : 'Block',
                          subtitle: isBlocked
                              ? 'Show this user again'
                              : 'Hide this user',
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _toggleBlock(
                                entry.uid,
                                entry
                                    .displayName);
                          }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile({
    required bool isDark,
    required bool enabled,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled
            ? () async {
          HapticFeedback.lightImpact();
          SoundService.playTap();
          await onTap();
        }
            : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: color.withOpacity(
                  isDark ? 0.10 : 0.06),
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                  color: color.withOpacity(
                      isDark ? 0.22 : 0.14))),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color:
                    color.withOpacity(0.16),
                    borderRadius:
                    BorderRadius.circular(
                        16)),
                child:
                Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight:
                              FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87),
                          overflow:
                          TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.25,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.black54),
                          overflow:
                          TextOverflow.ellipsis),
                    ])),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded,
                color: isDark
                    ? Colors.white24
                    : Colors.black26),
          ]),
        ),
      ),
    );
  }

  Future<void> _toggleBlock(
      String uid, String name) async {
    final isBlocked =
    LeaderboardModerationService.isBlocked(
        uid);
    try {
      if (isBlocked) {
        await LeaderboardModerationService
            .unblockUid(uid);
        _showSnack('Unblocked "$name".');
      } else {
        await LeaderboardModerationService
            .blockUid(uid);
        _showSnack('Blocked "$name".',
            action: SnackBarAction(
                label: 'UNDO',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await LeaderboardModerationService
                        .unblockUid(uid);
                  } catch (_) {}
                }));
      }
    } catch (e) {
      _showSnack(_prettyError(e), isError: true);
    }
  }

  Future<void> _openReportFlow({
    required bool isDark,
    required User me,
    required LeaderboardEntry entry,
    required int rank,
  }) async {
    final can = await LeaderboardModerationService
        .canReportNow();
    if (!can) {
      _showSnack('Please wait before reporting.',
          isError: true);
      return;
    }
    final result =
    await showDialog<ReportPayload>(
        context: context,
        builder: (_) => ReportDialog(
            isDark: isDark,
            targetName:
            entry.displayName));
    if (result == null) return;
    HapticFeedback.mediumImpact();
    try {
      await LeaderboardModerationService
          .reportUser(
          targetUid: entry.uid,
          reasonId: result.reasonId,
          details: result.details,
          targetDisplayName:
          entry.displayName,
          targetScore: entry.score,
          targetRank: rank);
      await LeaderboardModerationService
          .markReportedNow();
      _showSnack('Report sent. Thank you.');
    } catch (e) {
      _showSnack(_prettyError(e), isError: true);
    }
  }

  LinearGradient _getDynamicTabGradient() {
    if (_currentPeriod ==
        LeaderboardPeriod.weekly) {
      return const LinearGradient(
          colors: [
            Color(0xFFF355DA),
            Color(0xFF7000FF)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    }
    return const LinearGradient(
        colors: [
          Color(0xFFFFD700),
          Color(0xFFFFA500)
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight);
  }

  // ═══════════════════════════════════════
  // BUILD WIDGETS
  // ═══════════════════════════════════════

  Widget _glassCard(
      {required Widget child,
        EdgeInsets padding =
        const EdgeInsets.all(16)}) =>
      LeaderboardGlassCard(
          padding: padding,
          borderRadius: 22,
          child: child);

  Widget _buildHeaderCard({
    required bool isDark,
    required User user,
    required LeaderboardProfileModel profile,
    required bool selfProLocal,
    required bool selfProVerified,
  }) {
    final rank = _currentRank;
    final score = switch (_currentPeriod) {
      LeaderboardPeriod.daily =>
          profile.dailyScore.toDouble(),
      LeaderboardPeriod.weekly =>
          profile.weeklyScore.toDouble(),
      LeaderboardPeriod.allTime => _safeDouble(
          LeaderboardService.instance
              .getCurrentLocalMetrics()[
          'score']),
    };

    final rankText = rank > 0 ? '#$rank' : '—';
    final scoreText = score > 0
        ? score.toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          gradient: _getDynamicTabGradient(),
          borderRadius:
          BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black
                    .withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ]),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white,
                      width: 2)),
              child: Center(
                  child: Text(
                      profile.avatarEmoji
                          .trim()
                          .isEmpty
                          ? '🙂'
                          : profile.avatarEmoji,
                      style: const TextStyle(
                          fontSize: 28)))),
          if (selfProLocal || selfProVerified)
            Positioned(
                top: -6,
                right: -6,
                child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: const Color(
                            0xFFFFD700)
                            .withOpacity(isDark
                            ? 0.18
                            : 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(
                                0xFFFFD700)
                                .withOpacity(
                                0.35))),
                    child: const Center(
                        child: Text('👑',
                            style: TextStyle(
                                fontSize:
                                12))))),
        ]),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w900,
                          color: Colors.white),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(
                                text: user.uid));
                        _showSnack('UID Copied!');
                      },
                      child: Container(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal: 8,
                              vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black
                                  .withOpacity(
                                  0.25),
                              borderRadius:
                              BorderRadius
                                  .circular(8),
                              border: Border.all(
                                  color: Colors
                                      .white24)),
                          child: Row(
                              mainAxisSize:
                              MainAxisSize.min,
                              children: [
                                Text(
                                    'UID: ${user.uid.length > 10 ? user.uid.substring(0, 10) : user.uid}...',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                        FontWeight
                                            .w900,
                                        color: Colors
                                            .white)),
                                const SizedBox(
                                    width: 6),
                                const Icon(
                                    Icons
                                        .copy_rounded,
                                    size: 12,
                                    color: Colors
                                        .white),
                              ]))),
                ])),
        const SizedBox(width: 10),
        Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(0.2),
                borderRadius:
                BorderRadius.circular(16)),
            child: Column(children: [
              Text(rankText,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text('$scoreText XP',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight:
                      FontWeight.w800,
                      color: Colors.white)),
            ])),
      ]),
    );
  }

  Widget _buildEntryTile({
    required bool isDark,
    required User me,
    required int rank,
    required LeaderboardEntry e,
    required bool selfProLocal,
    required bool selfProVerified,
  }) {
    final showMedal = rank <= 3;
    final medalColor = _getRankColor(rank);
    final scoreText = _getScoreForEntry(e);
    final isSelf = e.uid == me.uid;
    final memberText =
    _memberForText(e.joinedAtMs);
    final explicitBadges =
    _getExplicitBadgeNames(e.badgesUnlocked);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: isSelf
              ? AppConfig.primaryColor
              .withOpacity(0.12)
              : (isDark
              ? const Color(0xFF151C2F)
              : Colors.white),
          borderRadius:
          BorderRadius.circular(20),
          border: Border.all(
              color: showMedal
                  ? medalColor.withOpacity(0.5)
                  : (isSelf
                  ? AppConfig.primaryColor
                  .withOpacity(0.4)
                  : (isDark
                  ? Colors.white
                  .withOpacity(0.06)
                  : Colors.black
                  .withOpacity(
                  0.06)))),
          boxShadow: [
            BoxShadow(
                color: showMedal
                    ? medalColor
                    .withOpacity(0.1)
                    : Colors.black.withOpacity(
                    isDark ? 0.12 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ]),
      child: Row(children: [
        Container(
            width: 48,
            alignment: Alignment.center,
            child: Text('#$rank',
                style: TextStyle(
                    fontSize:
                    showMedal ? 20 : 16,
                    fontWeight: FontWeight.w900,
                    color: showMedal
                        ? medalColor
                        : (isDark
                        ? Colors.white
                        : Colors
                        .black87)))),
        const SizedBox(width: 8),
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: AppConfig.primaryColor
                    .withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: showMedal
                        ? medalColor
                        : Colors
                        .transparent)),
            child: Center(
                child: Text(
                    e.avatarEmoji.trim().isEmpty
                        ? '🙂'
                        : e.avatarEmoji,
                    style: const TextStyle(
                        fontSize: 24)))),
        const SizedBox(width: 12),
        Expanded(
            child: GestureDetector(
                behavior:
                HitTestBehavior.translucent,
                onTap: () => _openPublicProfile(
                    me: me,
                    entry: e,
                    rank: rank,
                    selfProLocal: selfProLocal,
                    selfProVerified:
                    selfProVerified),
                child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Row(children: [
                        Flexible(
                            child: Text(
                                e.displayName,
                                style: TextStyle(
                                    fontSize:
                                    15.5,
                                    fontWeight:
                                    FontWeight
                                        .w900,
                                    color: isDark
                                        ? Colors
                                        .white
                                        : Colors
                                        .black87),
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis)),
                        if (isSelf) ...[
                          const SizedBox(
                              width: 6),
                          Container(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 8,
                                  vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppConfig
                                      .primaryColor
                                      .withOpacity(
                                      0.15),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                      999)),
                              child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                      fontSize:
                                      10,
                                      fontWeight:
                                      FontWeight
                                          .w900,
                                      color: AppConfig
                                          .primaryColor))),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(memberText,
                          style: TextStyle(
                              fontSize: 11.8,
                              color: isDark
                                  ? Colors
                                  .white54
                                  : Colors
                                  .black45),
                          maxLines: 1,
                          overflow: TextOverflow
                              .ellipsis),
                      if (explicitBadges
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: explicitBadges
                                .take(2)
                                .map((b) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal:
                                    8,
                                    vertical:
                                    3),
                                decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors
                                        .white10
                                        : Colors.black.withOpacity(
                                        0.05),
                                    borderRadius:
                                    BorderRadius.circular(
                                        8),
                                    border: Border.all(
                                        color: AppConfig.primaryColor.withOpacity(0.3))),
                                child: Text(b, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppConfig.primaryColor))))
                                .toList()),
                      ],
                    ]))),
        const SizedBox(width: 10),
        Column(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text('$scoreText XP',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w900,
                      color: showMedal
                          ? medalColor
                          : AppConfig
                          .accentColor)),
              IconButton(
                  tooltip: 'Actions',
                  onPressed: () =>
                      _showUserActionsSheet(
                          isDark: isDark,
                          me: me,
                          rank: rank,
                          entry: e,
                          selfProLocal:
                          selfProLocal,
                          selfProVerified:
                          selfProVerified),
                  icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark
                          ? Colors.white70
                          : Colors.black54,
                      size: 20)),
            ]),
      ]),
    );
  }

  // ✅ Tab bar — YOU LIKED tab
  Widget _buildGlassTabBar(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: (isDark
                  ? const Color(0xFF151C2F)
                  : Colors.white)
                  .withOpacity(
                  isDark ? 0.65 : 0.75),
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                  color: isDark
                      ? Colors.white
                      .withOpacity(0.08)
                      : Colors.black
                      .withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black
                        .withOpacity(
                        isDark ? 0.20 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ]),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppConfig.primaryColor
                      .withOpacity(0.95),
                  AppConfig.primaryColor
                      .withOpacity(0.75),
                ]),
                borderRadius:
                BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: AppConfig.primaryColor
                          .withOpacity(0.35),
                      blurRadius: 12,
                      offset:
                      const Offset(0, 4))
                ]),
            indicatorSize:
            TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900),
            unselectedLabelStyle:
            const TextStyle(
                fontSize: 13.5,
                fontWeight:
                FontWeight.w700),
            labelColor: Colors.white,
            unselectedLabelColor: isDark
                ? Colors.white60
                : Colors.black54,
            // ✅ YOU LIKED tab
            tabs: const [
              Tab(text: 'WEEKLY'),
              Tab(text: 'ALL-TIME'),
              Tab(text: 'YOU LIKED'),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // STATE BUILDERS
  // ═══════════════════════════════════════

  Widget _buildSignedOutState(bool isDark) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(
            18, 14, 18, 18),
        children: [
          _glassCard(
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: AppConfig.infoColor
                            .withOpacity(0.14),
                        borderRadius:
                        BorderRadius.circular(
                            16)),
                    child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppConfig.infoColor)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Sign in to view the leaderboard.',
                        style: TextStyle(
                            height: 1.35,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87,
                            fontWeight:
                            FontWeight.w600))),
              ])),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: _ensureSignedIn,
                  icon: const Icon(
                      Icons.login_rounded),
                  label: const Text(
                      'Sign in with Google',
                      style: TextStyle(
                          fontWeight:
                          FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets
                          .symmetric(
                          vertical: 14),
                      shape:
                      RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                              16))))),
        ]);
  }

  Widget _buildNoProfileState(
      bool isDark, User user) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(
            18, 14, 18, 18),
        children: [
          _glassCard(
              child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: AppConfig
                                  .primaryColor
                                  .withOpacity(0.14),
                              borderRadius:
                              BorderRadius
                                  .circular(16)),
                          child: const Icon(
                              Icons
                                  .person_add_alt_1_rounded,
                              color: AppConfig
                                  .primaryColor)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              'Create your leaderboard profile.',
                              style: TextStyle(
                                  height: 1.35,
                                  color: isDark
                                      ? Colors
                                      .white70
                                      : Colors
                                      .black87,
                                  fontWeight:
                                  FontWeight
                                      .w700))),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            onPressed:
                            _openProfileEditor,
                            icon: const Icon(
                                Icons.edit_rounded),
                            label: const Text(
                                'Create Profile',
                                style: TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .w900)),
                            style: ElevatedButton
                                .styleFrom(
                                padding: const EdgeInsets
                                    .symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        16))))),
                  ])),
        ]);
  }

  Widget _buildOptedOutState(bool isDark, User user,
      LeaderboardProfileModel profile) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(
            18, 14, 18, 18),
        children: [
          _glassCard(
              child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text('Leaderboard is turned off',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : Colors.black87)),
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            onPressed:
                            _openProfileEditor,
                            icon: const Icon(
                                Icons.tune_rounded),
                            label: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .w900)),
                            style: ElevatedButton
                                .styleFrom(
                                padding: const EdgeInsets
                                    .symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        16))))),
                  ])),
        ]);
  }

  Widget _buildErrorState(
      bool isDark, String error) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(
            18, 14, 18, 18),
        children: [
          _glassCard(
              child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                        error.isEmpty
                            ? 'Something went wrong.'
                            : error,
                        style: TextStyle(
                            height: 1.35,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87,
                            fontWeight:
                            FontWeight.w700)),
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            onPressed: () =>
                                _ensurePeriodLoaded(
                                    period:
                                    _currentPeriod,
                                    syncBeforeFetch:
                                    false,
                                    haptic: true,
                                    forceRefresh:
                                    true),
                            icon: const Icon(
                                Icons
                                    .refresh_rounded),
                            label: const Text(
                                'Retry',
                                style: TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .w900)),
                            style: ElevatedButton
                                .styleFrom(
                                padding: const EdgeInsets
                                    .symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        16))))),
                  ])),
        ]);
  }

  Widget _buildLeaderboardBody({
    required bool isDark,
    required User user,
    required LeaderboardProfileModel profile,
    required bool selfProLocal,
    required bool selfProVerified,
  }) {
    final top = _currentTop;

    return RefreshIndicator(
      color: AppConfig.primaryColor,
      onRefresh: () => _ensurePeriodLoaded(
          period: _currentPeriod,
          syncBeforeFetch: true,
          haptic: false,
          forceRefresh: true),
      child:
      ValueListenableBuilder<Set<String>>(
        valueListenable:
        LeaderboardModerationService
            .blockedUidsNotifier,
        builder: (context, blockedSet, _) {
          final blockedCount =
              blockedSet.length;
          final visibleTiles = <Widget>[];
          for (int i = 0;
          i < top.length;
          i++) {
            final e = top[i];
            if (blockedSet.contains(e.uid))
              continue;
            visibleTiles.add(_buildEntryTile(
                isDark: isDark,
                me: user,
                rank: i + 1,
                e: e,
                selfProLocal: selfProLocal,
                selfProVerified:
                selfProVerified));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                18, 14, 18, 18),
            physics:
            const BouncingScrollPhysics(
                parent:
                AlwaysScrollableScrollPhysics()),
            children: [
              _buildHeaderCard(
                  isDark: isDark,
                  user: user,
                  profile: profile,
                  selfProLocal: selfProLocal,
                  selfProVerified:
                  selfProVerified),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed:
                        _openProfileEditor,
                        icon: const Icon(
                            Icons.edit_rounded,
                            size: 18),
                        label: const Text(
                            'Edit Profile'))),
                const SizedBox(width: 10),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _isAnyBusy
                            ? null
                            : _syncAndReloadCurrent,
                        icon: Icon(
                            _syncing
                                ? Icons
                                .hourglass_top_rounded
                                : Icons
                                .sync_rounded,
                            size: 18),
                        label: Text(_syncing
                            ? 'Syncing...'
                            : 'Sync'))),
              ]),
              const SizedBox(height: 14),
              _buildGlassTabBar(isDark),
              const SizedBox(height: 12),

              // ✅ Tab 2 = YOU LIKED
              if (_tabController.index == 2)
                LeaderboardSocialFeedTab(
                  activeUid: _activeUid,
                  isDark: isDark,
                  cachedUsers: top, // ✅ এই লাইনটাই মিসিং ছিল
                )
              else ...[
                if (_isCurrentLoading)
                  Container(
                    margin:
                    const EdgeInsets.only(
                        bottom: 10),
                    padding: const EdgeInsets
                        .symmetric(
                        horizontal: 12,
                        vertical: 10),
                    decoration: BoxDecoration(
                        color: (isDark
                            ? Colors.white
                            : Colors.black)
                            .withOpacity(0.04),
                        borderRadius:
                        BorderRadius
                            .circular(16),
                        border: Border.all(
                            color: (isDark
                                ? Colors
                                .white
                                : Colors
                                .black)
                                .withOpacity(
                                0.06))),
                    child: Row(children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                              strokeWidth:
                              2.4,
                              color: AppConfig
                                  .primaryColor)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Loading...',
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .w700,
                                  color: isDark
                                      ? Colors
                                      .white70
                                      : Colors
                                      .black54))),
                    ]),
                  ),
                if (_currentError.isNotEmpty &&
                    top.isEmpty &&
                    !_isCurrentLoading)
                  _glassCard(
                      child: Text(
                          _currentError,
                          style: TextStyle(
                              height: 1.35,
                              color: isDark
                                  ? Colors
                                  .white70
                                  : Colors
                                  .black87,
                              fontWeight:
                              FontWeight
                                  .w700)))
                else if (top.isEmpty &&
                    !_isCurrentLoading)
                  _glassCard(
                      child: Text(
                          'No players yet.',
                          style: TextStyle(
                              color: isDark
                                  ? Colors
                                  .white70
                                  : Colors
                                  .black87,
                              fontWeight:
                              FontWeight
                                  .w700)))
                else if (visibleTiles.isEmpty &&
                      top.isNotEmpty)
                    _glassCard(
                        child: Text(
                            'All entries blocked.',
                            style: TextStyle(
                                color: isDark
                                    ? Colors
                                    .white70
                                    : Colors
                                    .black87,
                                fontWeight:
                                FontWeight
                                    .w700)))
                  else
                    FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                            position: _slide,
                            child: Column(
                                children:
                                visibleTiles))),
                const SizedBox(height: 10),
                if (blockedCount > 0)
                  Text(
                      'Blocked: $blockedCount hidden',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.white38
                              : Colors.black38,
                          fontWeight:
                          FontWeight.w600)),
              ],
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  // MAIN BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return ValueListenableBuilder<User?>(
      valueListenable:
      AuthService.instance.userNotifier,
      builder: (context, user, _) {
        final hasUser = user != null;
        LeaderboardProfileModel? profile;
        if (hasUser) {
          profile = DatabaseService
              .getLeaderboardProfileForUid(
              user.uid);
        }
        final selfProLocal =
        DatabaseService.isProOrVipUser();

        if (hasUser &&
            _activeUid != null &&
            _activeUid != user!.uid) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() =>
                _resetAllCachesForUser(
                    user.uid));
          });
        }

        return ValueListenableBuilder<bool>(
          valueListenable: PurchaseService
              .proVerifiedNotifier,
          builder:
              (context, proVerified, __) {
            final selfProVerified =
                proVerified;
            final canShowLeaderboard =
                hasUser &&
                    profile != null &&
                    profile.isOptedIn;

            return Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF0B1020)
                  : const Color(0xFFF7F8FC),
              appBar: AppBar(
                title: const Text(
                    'Leaderboard'),
                actions: [
                  if (hasUser)
                    IconButton(
                        icon: const Icon(
                            Icons
                                .search_rounded),
                        color: AppConfig
                            .primaryColor,
                        onPressed: () =>
                            _showSearchSheet(
                                context,
                                user!),
                        tooltip:
                        'Search Player'),
                  if (hasUser)
                    IconButton(
                        icon: const Icon(Icons
                            .chat_bubble_rounded),
                        color: AppConfig
                            .primaryColor,
                        onPressed: _openInbox,
                        tooltip: 'Messages'),
                  if (hasUser)
                    IconButton(
                        tooltip: 'My Profile',
                        onPressed:
                        _openProfileEditor,
                        icon: const Icon(Icons
                            .person_rounded),
                        color: AppConfig
                            .primaryColor),
                  const SizedBox(width: 8),
                ],
              ),
              body: AnimatedSwitcher(
                duration: const Duration(
                    milliseconds: 350),
                child: !hasUser
                    ? _buildSignedOutState(
                    isDark)
                    : (profile == null)
                    ? _buildNoProfileState(
                    isDark, user!)
                    : (!profile.isOptedIn)
                    ? _buildOptedOutState(
                    isDark,
                    user!,
                    profile)
                    : (_currentError
                    .isNotEmpty &&
                    _currentTop
                        .isEmpty &&
                    !_isCurrentLoading)
                    ? _buildErrorState(
                    isDark,
                    _currentError)
                    : _buildLeaderboardBody(
                    isDark:
                    isDark,
                    user:
                    user!,
                    profile:
                    profile,
                    selfProLocal:
                    selfProLocal,
                    selfProVerified:
                    selfProVerified),
              ),
              // ✅ FAB — Refresh only (no Add Post)
              floatingActionButton:
              canShowLeaderboard
                  ? FloatingActionButton
                  .extended(
                onPressed: _isAnyBusy
                    ? null
                    : () =>
                    _ensurePeriodLoaded(
                      period:
                      _currentPeriod,
                      syncBeforeFetch:
                      true,
                      haptic:
                      true,
                      forceRefresh:
                      true,
                    ),
                backgroundColor:
                AppConfig
                    .primaryColor,
                foregroundColor:
                Colors.white,
                icon: Icon(_isAnyBusy
                    ? Icons
                    .hourglass_top_rounded
                    : Icons
                    .refresh_rounded),
                label: Text(
                  _isAnyBusy
                      ? 'Loading...'
                      : 'Refresh',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight
                        .w900,
                  ),
                ),
              )
                  : null,
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════

class LeaderboardGlassCard
    extends StatelessWidget {
  const LeaderboardGlassCard(
      {super.key,
        required this.child,
        required this.padding,
        required this.borderRadius});
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;
    return ClipRRect(
        borderRadius:
        BorderRadius.circular(borderRadius),
        child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: 14, sigmaY: 14),
            child: Container(
                padding: padding,
                decoration: BoxDecoration(
                    color: (isDark
                        ? const Color(
                        0xFF151C2F)
                        : Colors.white)
                        .withOpacity(
                        isDark ? 0.72 : 0.82),
                    borderRadius:
                    BorderRadius.circular(
                        borderRadius),
                    border: Border.all(
                        color: isDark
                            ? Colors.white
                            .withOpacity(
                            0.06)
                            : Colors.black
                            .withOpacity(
                            0.06)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withOpacity(isDark
                              ? 0.24
                              : 0.06),
                          blurRadius: 22,
                          offset: const Offset(
                              0, 10))
                    ]),
                child: child)));
  }
}

class ReportPayload {
  final String reasonId;
  final String? details;
  const ReportPayload(
      {required this.reasonId,
        required this.details});
}

class ReportDialog extends StatefulWidget {
  final bool isDark;
  final String targetName;
  const ReportDialog(
      {super.key,
        required this.isDark,
        required this.targetName});

  @override
  State<ReportDialog> createState() =>
      _ReportDialogState();
}

class _ReportDialogState
    extends State<ReportDialog> {
  String _reasonId =
      LeaderboardReportReasons.spam;
  final _detailsC = TextEditingController();

  @override
  void dispose() {
    _detailsC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark
          ? const Color(0xFF151C2F)
          : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(24)),
      title: Text(
          'Report ${widget.targetName}',
          style: const TextStyle(
              fontWeight: FontWeight.w900),
          overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _rr(LeaderboardReportReasons.spam,
                    'Spam'),
                _rr(LeaderboardReportReasons.abusive,
                    'Abusive'),
                _rr(
                    LeaderboardReportReasons
                        .impersonation,
                    'Impersonation'),
                _rr(
                    LeaderboardReportReasons
                        .inappropriate,
                    'Inappropriate'),
                _rr(LeaderboardReportReasons.other,
                    'Other'),
                const SizedBox(height: 10),
                TextField(
                    controller: _detailsC,
                    maxLines: 3,
                    maxLength: 280,
                    decoration:
                    const InputDecoration(
                        labelText:
                        'Details (optional)',
                        counterText: '')),
              ])),
      actions: [
        TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(
                    fontWeight:
                    FontWeight.w800))),
        ElevatedButton(
            onPressed: () => Navigator.pop(
                context,
                ReportPayload(
                    reasonId: _reasonId,
                    details: _detailsC.text
                        .trim()
                        .isEmpty
                        ? null
                        : _detailsC.text
                        .trim())),
            style: ElevatedButton.styleFrom(
                backgroundColor:
                AppConfig.primaryColor,
                foregroundColor: Colors.white),
            child: const Text('Send Report',
                style: TextStyle(
                    fontWeight:
                    FontWeight.w900))),
      ],
    );
  }

  Widget _rr(String value, String label) =>
      RadioListTile<String>(
          value: value,
          groupValue: _reasonId,
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: AppConfig.primaryColor,
          title: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.isDark
                      ? Colors.white
                      : Colors.black87)),
          onChanged: (v) {
            if (v != null) {
              setState(() => _reasonId = v);
            }
          });
}

class PlayerSearchSheet extends StatefulWidget {
  final User me;
  const PlayerSearchSheet(
      {super.key, required this.me});
  @override
  State<PlayerSearchSheet> createState() =>
      _PlayerSearchSheetState();
}

class _PlayerSearchSheetState
    extends State<PlayerSearchSheet> {
  final _searchC = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchC.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _results = [];
      _hasSearched = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('leaderboard_v1_users')
          .doc(query)
          .get();
      if (doc.exists &&
          doc.id != widget.me.uid) {
        _results.add({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        });
      }
      final snap = await FirebaseFirestore
          .instance
          .collection('leaderboard_v1_users')
          .where('displayName',
          isGreaterThanOrEqualTo: query)
          .where('displayName',
          isLessThanOrEqualTo:
          '$query\uf8ff')
          .limit(10)
          .get();
      for (var d in snap.docs) {
        if (d.id != widget.me.uid &&
            !_results
                .any((r) => r['id'] == d.id)) {
          _results
              .add({'id': d.id, ...d.data()});
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context)
              .viewInsets
              .bottom),
      child: ClipRRect(
        borderRadius:
        const BorderRadius.vertical(
            top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 25, sigmaY: 25),
          child: Container(
            height: MediaQuery.of(context)
                .size
                .height *
                0.75,
            padding:
            const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151C2F)
                    .withOpacity(0.95)
                    : Colors.white
                    .withOpacity(0.95)),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey
                                .withOpacity(
                                0.3),
                            borderRadius:
                            BorderRadius
                                .circular(
                                2)))),
                const SizedBox(height: 24),
                Text('Find Player',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                        FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : Colors
                            .black87)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              horizontal:
                              16),
                          decoration: BoxDecoration(
                              color: isDark
                                  ? Colors
                                  .black26
                                  : Colors.black
                                  .withOpacity(
                                  0.04),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  16),
                              border: Border.all(
                                  color: AppConfig
                                      .primaryColor
                                      .withOpacity(
                                      0.3))),
                          child: TextField(
                              controller:
                              _searchC,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors
                                      .white
                                      : Colors
                                      .black87),
                              decoration:
                              InputDecoration(
                                  hintText:
                                  'UID or Name...',
                                  hintStyle: TextStyle(
                                      color: isDark
                                          ? Colors
                                          .white38
                                          : Colors
                                          .black38),
                                  border:
                                  InputBorder
                                      .none,
                                  icon: const Icon(
                                      Icons
                                          .search_rounded,
                                      color: AppConfig
                                          .primaryColor)),
                              onSubmitted: (_) =>
                                  _performSearch()))),
                  const SizedBox(width: 12),
                  GestureDetector(
                      onTap: _performSearch,
                      child: Container(
                          padding:
                          const EdgeInsets
                              .all(14),
                          decoration: BoxDecoration(
                              color: AppConfig
                                  .primaryColor,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  16)),
                          child: _isLoading
                              ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors
                                      .white,
                                  strokeWidth:
                                  2))
                              : const Icon(
                              Icons
                                  .arrow_forward_rounded,
                              color: Colors
                                  .white))),
                ]),
                const SizedBox(height: 24),
                Expanded(
                    child: _isLoading
                        ? const Center(
                        child: CircularProgressIndicator(
                            color: AppConfig
                                .primaryColor))
                        : !_hasSearched
                        ? Center(
                        child: Icon(
                            Icons
                                .person_search_rounded,
                            size: 80,
                            color: isDark
                                ? Colors
                                .white10
                                : Colors
                                .black12))
                        : _results.isEmpty
                        ? Center(
                        child: Text(
                            'No player found.',
                            style: TextStyle(
                                fontWeight: FontWeight
                                    .w700,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black45)))
                        : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final r =
                          _results[i];
                          final uid =
                          r['id']
                          as String;
                          final name =
                              (r['displayName']
                              as String?) ??
                                  'Player';
                          final avatar =
                              (r['avatarEmoji']
                              as String?) ??
                                  '🙂';
                          return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                              child: Row(children: [
                                CircleAvatar(radius: 24, backgroundColor: AppConfig.primaryColor.withOpacity(0.2), child: Text(avatar, style: const TextStyle(fontSize: 24))),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                                      GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: uid));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UID copied!'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)));
                                          },
                                          child: Text('UID: ${uid.length > 10 ? uid.substring(0, 10) : uid}...', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54))),
                                    ])),
                                IconButton(
                                    icon: const Icon(Icons.chat_bubble_rounded, color: AppConfig.primaryColor),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peerUid: uid, peerName: name, peerAvatar: avatar)));
                                    }),
                              ]));
                        })),
              ],
            ),
          ),
        ),
      ),
    );
  }
}