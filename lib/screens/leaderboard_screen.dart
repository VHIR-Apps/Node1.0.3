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
import '../services/database_service.dart';
import '../services/leaderboard_moderation_service.dart';
import '../services/leaderboard_service.dart';
import '../services/purchase_service.dart';
import '../services/sound_service.dart';
import 'leaderboard_profile_screen.dart';
import 'inbox_screen.dart'; // 🚀 ইনবক্স স্ক্রিন ইমপোর্ট
import 'chat_screen.dart'; // 🚀 চ্যাট স্ক্রিন ইমপোর্ট

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  LeaderboardPeriod _currentPeriod = LeaderboardPeriod.allTime;
  int _lastTabIndex = 2;

  final Map<LeaderboardPeriod, List<LeaderboardEntry>?> _topByPeriod =
  <LeaderboardPeriod, List<LeaderboardEntry>?>{
    LeaderboardPeriod.daily: null,
    LeaderboardPeriod.weekly: null,
    LeaderboardPeriod.allTime: null,
  };

  final Map<LeaderboardPeriod, int> _rankByPeriod =
  <LeaderboardPeriod, int>{
    LeaderboardPeriod.daily: -1,
    LeaderboardPeriod.weekly: -1,
    LeaderboardPeriod.allTime: -1,
  };

  final Map<LeaderboardPeriod, bool> _loadingByPeriod =
  <LeaderboardPeriod, bool>{
    LeaderboardPeriod.daily: false,
    LeaderboardPeriod.weekly: false,
    LeaderboardPeriod.allTime: false,
  };

  final Map<LeaderboardPeriod, String> _errorByPeriod =
  <LeaderboardPeriod, String>{
    LeaderboardPeriod.daily: '',
    LeaderboardPeriod.weekly: '',
    LeaderboardPeriod.allTime: '',
  };

  bool _syncing = false;

  late final AnimationController _animC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _animC,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _animC,
      curve: Curves.easeOutCubic,
    ),
  );

  String? _activeUid;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this, initialIndex: 2);
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

  bool get _isCurrentLoading => _loadingByPeriod[_currentPeriod] ?? false;
  String get _currentError => _errorByPeriod[_currentPeriod] ?? '';
  List<LeaderboardEntry> get _currentTop => _topByPeriod[_currentPeriod] ?? const <LeaderboardEntry>[];
  int get _currentRank => _rankByPeriod[_currentPeriod] ?? -1;
  bool get _isAnyBusy => _syncing || _isCurrentLoading;

  String _memberForText(int joinedAtMs) {
    if (joinedAtMs <= 0) return 'Member';
    final joined = DateTime.fromMillisecondsSinceEpoch(joinedAtMs, isUtc: true).toLocal();
    final now = DateTime.now();

    final diffDays = now.difference(joined).inDays;
    if (diffDays < 0) return 'Member';

    final years = diffDays ~/ 365;
    final months = (diffDays % 365) ~/ 30;
    final days = (diffDays % 365) % 30;

    if (years > 0) {
      if (months > 0) return 'Member for $years yr $months mo';
      return 'Member for $years yr';
    }
    if (months > 0) {
      if (days > 0) return 'Member for $months mo $days d';
      return 'Member for $months mo';
    }
    if (days > 0) return 'Member for $days d';
    return 'Just joined';
  }

  // 🚀 INBOX OPENER FUNCTION
  void _openInbox() {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
  }

  // 🚀 OPEN SEARCH SHEET FUNCTION (Free Fire Style)
  void _showSearchSheet(BuildContext context, User me) {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlayerSearchSheet(me: me),
    );
  }

  void _onTabChanged() {
    final idx = _tabController.index;
    if (idx == _lastTabIndex) return;
    _lastTabIndex = idx;

    if (idx == 3) {
      setState(() {});
      return;
    }

    final nextPeriod = switch (idx) {
      0 => LeaderboardPeriod.daily,
      1 => LeaderboardPeriod.weekly,
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
        haptic: false,
      );
    });
  }

  void _showSnack(
      String text, {
        bool isError = false,
        SnackBarAction? action,
      }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppConfig.errorColor : null,
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyError(Object e) {
    if (e is AuthServiceException) return e.message;

    final msg = e.toString();

    if (msg.contains('Sign-in cancelled') || msg.contains('Sign-in was cancelled')) {
      return 'Sign-in was cancelled.';
    }
    if (msg.contains('network-request-failed') || msg.contains('No internet') || msg.contains('SocketException')) {
      return 'No internet connection. Please try again.';
    }
    if (msg.toLowerCase().contains('permission-denied') || msg.toLowerCase().contains('missing or insufficient permissions')) {
      return 'Permission denied. Please sign in again and try later.';
    }
    if (msg.toLowerCase().contains('requires an index') || msg.toLowerCase().contains('failed-precondition')) {
      return 'Leaderboard is being configured on the server. Please try again shortly.';
    }

    return msg
        .replaceAll('AuthServiceException:', '')
        .replaceAll('LeaderboardServiceException:', '')
        .replaceAll('LeaderboardModerationException:', '')
        .trim();
  }

  Future<void> _maybeAutoLoadCurrentTab() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final local = DatabaseService.getLeaderboardProfileForUid(user.uid);
    if (local == null || !local.isOptedIn) return;

    _activeUid = user.uid;

    if (_tabController.index != 3) {
      await _ensurePeriodLoaded(
        period: _currentPeriod,
        syncBeforeFetch: true,
        haptic: false,
      );
    }
  }

  Future<void> _ensurePeriodLoaded({
    required LeaderboardPeriod period,
    required bool syncBeforeFetch,
    required bool haptic,
    bool forceRefresh = false,
  }) async {
    if (!mounted || _tabController.index == 3) return;

    final alreadyLoaded = _topByPeriod[period] != null;
    final currentlyLoading = _loadingByPeriod[period] ?? false;

    if (currentlyLoading) return;
    if (alreadyLoaded && !forceRefresh) return;

    if (haptic) HapticFeedback.lightImpact();

    setState(() {
      _loadingByPeriod[period] = true;
      _errorByPeriod[period] = '';
    });

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw const LeaderboardServiceException('Please sign in to view the leaderboard.');
      }

      if (_activeUid != null && _activeUid != user.uid) {
        _resetAllCachesForUser(user.uid);
      }
      _activeUid = user.uid;

      final profile = DatabaseService.getLeaderboardProfileForUid(user.uid);
      if (profile == null) {
        throw const LeaderboardServiceException('Please create your leaderboard profile first.');
      }
      if (!profile.isOptedIn) {
        throw const LeaderboardServiceException('Leaderboard is turned off for this profile.');
      }

      try { await user.getIdToken(true); } catch (_) {}

      if (syncBeforeFetch) {
        try {
          await LeaderboardService.instance.syncMyProfileToCloud();
        } catch (e) {
          debugPrint('⚠️ Leaderboard sync skipped/failed: $e');
        }
      }

      final List<LeaderboardEntry> top = switch (period) {
        LeaderboardPeriod.daily => await LeaderboardService.instance.fetchDailyLeaderboard(limit: 50),
        LeaderboardPeriod.weekly => await LeaderboardService.instance.fetchWeeklyLeaderboard(limit: 50),
        LeaderboardPeriod.allTime => await LeaderboardService.instance.fetchTop(limit: 50),
      };

      final double myScore = switch (period) {
        LeaderboardPeriod.daily => profile.dailyScore.toDouble(),
        LeaderboardPeriod.weekly => profile.weeklyScore.toDouble(),
        LeaderboardPeriod.allTime => _safeDouble(LeaderboardService.instance.getCurrentLocalMetrics()['score']),
      };

      int myRank = -1;
      try {
        myRank = switch (period) {
          LeaderboardPeriod.daily => await LeaderboardService.instance.fetchMyRankByPeriod(uid: user.uid, period: LeaderboardPeriod.daily, myScore: myScore, fallbackScanLimit: 500),
          LeaderboardPeriod.weekly => await LeaderboardService.instance.fetchMyRankByPeriod(uid: user.uid, period: LeaderboardPeriod.weekly, myScore: myScore, fallbackScanLimit: 500),
          LeaderboardPeriod.allTime => await LeaderboardService.instance.fetchMyRankExact(uid: user.uid, myScore: myScore, fallbackScanLimit: 500),
        };
      } catch (e) {
        debugPrint('⚠️ Rank fetch failed ($period): $e');
      }

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
          await DatabaseService.saveLeaderboardProfile(profile);
        } catch (e) {
          debugPrint('⚠️ Failed to cache leaderboard rank locally: $e');
        }
      }

      _animC.forward(from: 0);
    } catch (e) {
      if (!mounted) return;

      final friendly = _prettyError(e);
      setState(() => _errorByPeriod[period] = friendly);

      final hasCached = (_topByPeriod[period]?.isNotEmpty ?? false);
      if (hasCached) {
        _showSnack('Could not refresh. Showing the last loaded results.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingByPeriod[period] = false);
      }
    }
  }

  void _resetAllCachesForUser(String uid) {
    _activeUid = uid;
    for (final p in LeaderboardPeriod.values) {
      _topByPeriod[p] = null;
      _rankByPeriod[p] = -1;
      _loadingByPeriod[p] = false;
      _errorByPeriod[p] = '';
    }
  }

  double _safeDouble(Object? v) {
    if (v is num) return v.toDouble();
    return 0.0;
  }

  Future<void> _ensureSignedIn() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    try {
      final user = await AuthService.instance.ensureSignedInOnDemand(interactive: true);
      if (!mounted) return;

      if (user == null) {
        _showSnack('Sign-in was cancelled.', isError: true);
        return;
      }
      _showSnack('Signed in successfully.');
      await _maybeAutoLoadCurrentTab();
    } catch (e) {
      if (!mounted) return;
      _showSnack(_prettyError(e), isError: true);
    }
  }

  Future<void> _openProfileEditor() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    final me = AuthService.instance.currentUser;
    if (me == null) {
      await _ensureSignedIn();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardProfileScreen()),
    );

    if (!mounted) return;

    if (result == true) {
      await _ensurePeriodLoaded(period: _currentPeriod, syncBeforeFetch: true, haptic: false, forceRefresh: true);
    }
  }

  Future<void> _syncAndReloadCurrent() async {
    if (_syncing) return;
    HapticFeedback.lightImpact();
    SoundService.playTap();

    setState(() => _syncing = true);
    try {
      await LeaderboardService.instance.syncMyProfileToCloud();
      if (!mounted) return;

      _showSnack('Synced successfully.');
      await _ensurePeriodLoaded(period: _currentPeriod, syncBeforeFetch: false, haptic: false, forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_prettyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
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
        builder: (_) => _PublicLeaderboardProfileScreen(
          me: me,
          entry: entry,
          rank: rank,
          selfProLocal: selfProLocal,
          selfProVerified: selfProVerified,
        ),
      ),
    );
  }

  void _showAddPostSheet(LeaderboardProfileModel profile) {
    HapticFeedback.mediumImpact();
    SoundService.playTap();
    final TextEditingController postC = TextEditingController();
    bool isPosting = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF151C2F).withOpacity(0.95) : Colors.white.withOpacity(0.95)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 20),
                        Text('Share Your Progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
                          child: TextField(
                            controller: postC,
                            maxLines: 4,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(hintText: 'What did you achieve today? Inspire others!', hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), border: InputBorder.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: isPosting ? null : () async {
                              final text = postC.text.trim();
                              if (text.isEmpty || _activeUid == null) return;
                              setSheetState(() => isPosting = true);
                              try {
                                final double myXp = _safeDouble(LeaderboardService.instance.getCurrentLocalMetrics()['score']);

                                await FirebaseFirestore.instance.collection('leaderboard_v1_posts').add({
                                  'authorUid': _activeUid,
                                  'authorName': profile.displayName,
                                  'authorAvatar': profile.avatarEmoji.isEmpty ? '🙂' : profile.avatarEmoji,
                                  'authorXp': myXp,
                                  'content': text,
                                  'timestamp': FieldValue.serverTimestamp(),
                                });
                                SoundService.playSuccess();
                                if (mounted) { Navigator.pop(context); _showSnack('Post shared successfully!'); }
                              } catch (e) {
                                setSheetState(() => isPosting = false);
                                _showSnack(_prettyError(e), isError: true);
                              }
                            },
                            child: isPosting ? const CircularProgressIndicator(color: Colors.white) : const Text('Post Now 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
      ),
    );
  }

  Widget _buildSocialFeedTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leaderboard_v1_posts').orderBy('timestamp', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppConfig.primaryColor)));

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('Feed is empty! Be the first to share.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w700))));

        List<QueryDocumentSnapshot> sortedPosts = docs.toList();
        sortedPosts.sort((a, b) {
          final xpA = (a.data() as Map<String, dynamic>)['authorXp'] ?? 0;
          final xpB = (b.data() as Map<String, dynamic>)['authorXp'] ?? 0;
          return (xpB as num).compareTo(xpA as num);
        });

        return Column(
          children: sortedPosts.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['authorUid'] == _activeUid;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.12 : 0.05), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(data['authorAvatar'] ?? '😎', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['authorName'] ?? 'Player', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                            Text('${data['authorXp'] ?? 0} XP', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConfig.accentColor)),
                          ],
                        ),
                      ),
                      if (isMe)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppConfig.errorColor, size: 20),
                          onPressed: () => FirebaseFirestore.instance.collection('leaderboard_v1_posts').doc(doc.id).delete(),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(data['content'] ?? '', style: TextStyle(fontSize: 14.5, height: 1.4, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return _GlassCard(
      padding: padding,
      borderRadius: 22,
      child: child,
    );
  }

  Widget _buildHeaderCard({
    required bool isDark,
    required User user,
    required LeaderboardProfileModel profile,
    required bool selfProLocal,
    required bool selfProVerified,
  }) {
    final rank = _currentRank;
    final score = switch (_currentPeriod) {
      LeaderboardPeriod.daily => profile.dailyScore.toDouble(),
      LeaderboardPeriod.weekly => profile.weeklyScore.toDouble(),
      LeaderboardPeriod.allTime =>
          _safeDouble(LeaderboardService.instance.getCurrentLocalMetrics()['score']),
    };

    final rankText = rank > 0 ? '#$rank' : '—';
    final scoreText = score > 0 ? score.toStringAsFixed(0) : '—';

    return _glassCard(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConfig.primaryColor,
                      AppConfig.primaryColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    (profile.avatarEmoji.trim().isEmpty) ? '🙂' : profile.avatarEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              if (selfProLocal || selfProVerified)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700)
                          .withOpacity(isDark ? 0.18 : 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700)
                              .withOpacity(isDark ? 0.18 : 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text('👑', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((profile.tagline ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.tagline!.trim(),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? 'Signed in',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // 🚀 ADDED UID COPY BUTTON (Free Fire Style)
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    SoundService.playTap();
                    Clipboard.setData(ClipboardData(text: user.uid));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppConfig.successColor,
                          content: Row(
                            children: [
                              const Icon(Icons.copy_all_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text('UID Copied: ${user.uid}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                        )
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('UID: ${user.uid.substring(0, 10)}...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : Colors.black54)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                      ],
                    ),
                  ),
                ),

                if (selfProVerified) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppConfig.successColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Verified Pro',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Your Rank',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rankText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score $scoreText',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppConfig.infoColor,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _metricChip({
    required bool isDark,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(isDark ? 0.22 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

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
    final isBlocked = LeaderboardModerationService.isBlocked(entry.uid);

    HapticFeedback.lightImpact();
    SoundService.playTap();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = (isDark ? const Color(0xFF151C2F) : Colors.white)
            .withOpacity(isDark ? 0.92 : 0.96);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppConfig.primaryColor.withOpacity(0.95),
                                      AppConfig.primaryColor.withOpacity(0.55),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    entry.avatarEmoji.trim().isEmpty
                                        ? '🙂'
                                        : entry.avatarEmoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                              if (entry.isInterviewUser)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700)
                                          .withOpacity(isDark ? 0.18 : 0.14),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFFFD700)
                                            .withOpacity(0.35),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text('👑',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ),
                              if (isSelf && (selfProLocal || selfProVerified))
                                Positioned(
                                  bottom: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFF59E0B)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF151C2F)
                                            : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color:
                                    isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Rank #$rank • Score ${_getScoreForEntry(entry)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 14),
                      _actionTile(
                        isDark: isDark,
                        enabled: true,
                        icon: isSelf
                            ? Icons.edit_rounded
                            : Icons.person_search_rounded,
                        color: AppConfig.primaryColor,
                        title: isSelf ? 'Edit Profile' : 'View Profile',
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
                              rank: rank,
                              entry: entry,
                              selfProLocal: selfProLocal,
                              selfProVerified: selfProVerified,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _actionTile(
                        isDark: isDark,
                        enabled: !isSelf,
                        icon: Icons.flag_outlined,
                        color: AppConfig.warningColor,
                        title: 'Report',
                        subtitle: 'Report inappropriate content',
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _openReportFlow(
                            isDark: isDark,
                            me: me,
                            entry: entry,
                            rank: rank,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _actionTile(
                        isDark: isDark,
                        enabled: !isSelf,
                        icon: isBlocked
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: AppConfig.infoColor,
                        title: isBlocked ? 'Unblock' : 'Block',
                        subtitle: isBlocked
                            ? 'Show this user again'
                            : 'Hide this user from your leaderboard',
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _toggleBlock(entry.uid, entry.displayName);
                        },
                      ),
                      if (isSelf) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Report and block actions are disabled for your own profile.',
                          style: TextStyle(
                            fontSize: 12.2,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
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

  String _getScoreForEntry(LeaderboardEntry entry) {
    final score = switch (_currentPeriod) {
      LeaderboardPeriod.daily => entry.dailyScore.toDouble(),
      LeaderboardPeriod.weekly => entry.weeklyScore.toDouble(),
      LeaderboardPeriod.allTime => entry.score,
    };
    return score.isFinite ? score.toStringAsFixed(0) : '0';
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
            color: color.withOpacity(isDark ? 0.10 : 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(isDark ? 0.22 : 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBlock(String uid, String name) async {
    final isBlocked = LeaderboardModerationService.isBlocked(uid);

    try {
      if (isBlocked) {
        await LeaderboardModerationService.unblockUid(uid);
        _showSnack('Unblocked "$name".');
      } else {
        await LeaderboardModerationService.blockUid(uid);

        _showSnack(
          'Blocked "$name".',
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () async {
              try {
                await LeaderboardModerationService.unblockUid(uid);
              } catch (_) {}
            },
          ),
        );
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
    final can = await LeaderboardModerationService.canReportNow();
    if (!can) {
      _showSnack(
        'Please wait a moment before sending another report.',
        isError: true,
      );
      return;
    }

    final result = await showDialog<_ReportPayload>(
      context: context,
      builder: (_) => _ReportDialog(
        isDark: isDark,
        targetName: entry.displayName,
      ),
    );

    if (result == null) return;

    HapticFeedback.mediumImpact();
    SoundService.playTap();

    try {
      await LeaderboardModerationService.reportUser(
        targetUid: entry.uid,
        reasonId: result.reasonId,
        details: result.details,
        targetDisplayName: entry.displayName,
        targetScore: entry.score,
        targetRank: rank,
      );
      await LeaderboardModerationService.markReportedNow();

      _showSnack('Report sent. Thank you.');
    } catch (e) {
      _showSnack(_prettyError(e), isError: true);
    }
  }

  Widget _buildEntryTile({
    required bool isDark,
    required User me,
    required int rank,
    required LeaderboardEntry e,
    required bool selfProLocal,
    required bool selfProVerified,
  }) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    final showMedal = rank <= 3;
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '' };

    final chips = <Widget>[];

    if (e.showLevel) {
      chips.add(
        _metricChip(
          isDark: isDark,
          icon: Icons.military_tech_rounded,
          text: 'Lv. ${e.level}',
          color: const Color(0xFFFFD700),
        ),
      );
    }

    if (e.showBadges) {
      chips.add(
        _metricChip(
          isDark: isDark,
          icon: Icons.emoji_events_rounded,
          text: '${e.badgesUnlocked} badges',
          color: const Color(0xFF00C853),
        ),
      );
    }

    if (e.showStudyHours) {
      final niceHours = e.studyHours.isFinite
          ? e.studyHours.toStringAsFixed(e.studyHours < 10 ? 1 : 0)
          : '0';
      chips.add(
        _metricChip(
          isDark: isDark,
          icon: Icons.timer_rounded,
          text: '$niceHours h',
          color: const Color(0xFF3B82F6),
        ),
      );
    }

    final scoreText = _getScoreForEntry(e);
    final isSelf = e.uid == me.uid;

    final tagline = (e.tagline ?? '').trim();
    final bio = (e.bio ?? '').trim();
    final showBioPreview = bio.isNotEmpty;

    final memberText = _memberForText(e.joinedAtMs);

    final showSelfProCrown = isSelf && (selfProLocal || selfProVerified);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  showMedal ? medal : '#$rank',
                  style: TextStyle(
                    fontSize: showMedal ? 22 : 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score $scoreText',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConfig.primaryColor.withOpacity(0.95),
                      AppConfig.primaryColor.withOpacity(0.55),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    (e.avatarEmoji.trim().isEmpty) ? '🙂' : e.avatarEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              if (e.isInterviewUser)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700)
                          .withOpacity(isDark ? 0.18 : 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700)
                              .withOpacity(isDark ? 0.18 : 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text('👑', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              if (showSelfProCrown)
                Positioned(
                  bottom: -7,
                  right: -7,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF151C2F) : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () async {
                await _openPublicProfile(
                  me: me,
                  entry: e,
                  rank: rank,
                  selfProLocal: selfProLocal,
                  selfProVerified: selfProVerified,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.displayName,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppConfig.primaryColor.withOpacity(
                              isDark ? 0.18 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppConfig.primaryColor.withOpacity(
                                isDark ? 0.35 : 0.22,
                              ),
                            ),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppConfig.primaryColor,
                            ),
                          ),
                        ),
                      ],
                      if ((e.countryCode ?? '').trim().isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            e.countryCode!.trim().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                      if (e.isInterviewUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700)
                                .withOpacity(isDark ? 0.14 : 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFFFD700)
                                  .withOpacity(isDark ? 0.26 : 0.18),
                            ),
                          ),
                          child: const Text(
                            'CROWN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                              letterSpacing: 0.35,
                            ),
                          ),
                        ),
                      ],
                      if (showSelfProCrown) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppConfig.primaryColor.withOpacity(
                              isDark ? 0.18 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppConfig.primaryColor.withOpacity(
                                isDark ? 0.30 : 0.22,
                              ),
                            ),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppConfig.primaryColor,
                              letterSpacing: 0.35,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    memberText,
                    style: TextStyle(
                      fontSize: 11.8,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      tagline,
                      style: TextStyle(
                        fontSize: 12.2,
                        height: 1.3,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (showBioPreview) ...[
                    const SizedBox(height: 6),
                    Text(
                      bio,
                      style: TextStyle(
                        fontSize: 12.2,
                        height: 1.3,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Actions',
            onPressed: () async {
              await _showUserActionsSheet(
                isDark: isDark,
                me: me,
                rank: rank,
                entry: e,
                selfProLocal: selfProLocal,
                selfProVerified: selfProVerified,
              );
            },
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        _glassCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppConfig.infoColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppConfig.infoColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sign in to view the leaderboard and create your public profile.',
                  style: TextStyle(
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _ensureSignedIn,
            icon: const Icon(Icons.login_rounded),
            label: const Text(
              'Sign in with Google',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoProfileState(bool isDark, User user) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppConfig.primaryColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppConfig.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create your leaderboard profile to appear in rankings.',
                      style: TextStyle(
                        height: 1.35,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'No image upload is required. You can use a character and your name.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openProfileEditor,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text(
                    'Create Profile',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptedOutState(
      bool isDark,
      User user,
      LeaderboardProfileModel profile,
      ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leaderboard is turned off',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enable it from your profile to appear publicly and see your rank.',
                style: TextStyle(
                  fontSize: 12.8,
                  height: 1.4,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openProfileEditor,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        _glassCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppConfig.errorColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppConfig.errorColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error.isEmpty ? 'Something went wrong.' : error,
                  style: TextStyle(
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _ensurePeriodLoaded(
              period: _currentPeriod,
              syncBeforeFetch: false,
              haptic: true,
              forceRefresh: true,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
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
        forceRefresh: true,
      ),
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: LeaderboardModerationService.blockedUidsNotifier,
        builder: (context, blockedSet, _) {
          final blockedCount = blockedSet.length;

          final visibleTiles = <Widget>[];
          for (int i = 0; i < top.length; i++) {
            final e = top[i];
            if (blockedSet.contains(e.uid)) continue;

            visibleTiles.add(
              _buildEntryTile(
                isDark: isDark,
                me: user,
                rank: i + 1,
                e: e,
                selfProLocal: selfProLocal,
                selfProVerified: selfProVerified,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: [
              _buildHeaderCard(
                isDark: isDark,
                user: user,
                profile: profile,
                selfProLocal: selfProLocal,
                selfProVerified: selfProVerified,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openProfileEditor,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAnyBusy ? null : _syncAndReloadCurrent,
                      icon: Icon(
                        _syncing ? Icons.hourglass_top_rounded : Icons.sync_rounded,
                        size: 18,
                      ),
                      label: Text(_syncing ? 'Syncing...' : 'Sync'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildGlassTabBar(isDark),
              const SizedBox(height: 12),

              if (_tabController.index == 3)
                _buildSocialFeedTab(isDark)
              else ...[
                if (_isCurrentLoading)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Loading...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_currentError.isNotEmpty && top.isEmpty && !_isCurrentLoading)
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentError,
                          style: TextStyle(
                            height: 1.35,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _ensurePeriodLoaded(
                              period: _currentPeriod,
                              syncBeforeFetch: false,
                              haptic: true,
                              forceRefresh: true,
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text(
                              'Retry',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (top.isEmpty && !_isCurrentLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _glassCard(
                      child: Text(
                        'No players yet. Be the first to join!',
                        style: TextStyle(
                          height: 1.35,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else if (visibleTiles.isEmpty && top.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _glassCard(
                        child: Text(
                          'All visible entries are currently blocked.',
                          style: TextStyle(
                            height: 1.35,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Column(children: visibleTiles),
                      ),
                    ),
                const SizedBox(height: 10),
                Text(
                  'Tip: Tap a user to view their profile. Use the menu to Report or Block.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (blockedCount > 0)
                  Text(
                    'Blocked: $blockedCount users hidden',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? Colors.white.withOpacity(0.45)
                          : Colors.black38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ]
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassTabBar(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF151C2F) : Colors.white)
                .withOpacity(isDark ? 0.65 : 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.20 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConfig.primaryColor.withOpacity(0.95),
                  AppConfig.primaryColor.withOpacity(0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppConfig.primaryColor.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            tabs: const [
              Tab(text: 'TODAY'),
              Tab(text: 'WEEKLY'),
              Tab(text: 'ALL-TIME'),
              Tab(text: 'SOCIAL'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<User?>(
      valueListenable: AuthService.instance.userNotifier,
      builder: (context, user, _) {
        final hasUser = user != null;

        LeaderboardProfileModel? profile;
        if (hasUser) {
          profile = DatabaseService.getLeaderboardProfileForUid(user.uid);
        }

        final canShowLeaderboard =
            hasUser && profile != null && profile.isOptedIn;

        final selfProLocal = DatabaseService.isProOrVipUser();

        if (hasUser && _activeUid != null && _activeUid != user!.uid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _resetAllCachesForUser(user.uid));
          });
        }

        return ValueListenableBuilder<bool>(
          valueListenable: PurchaseService.proVerifiedNotifier,
          builder: (context, proVerified, __) {
            final selfProVerified = proVerified;

            return Scaffold(
              backgroundColor:
              isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
              appBar: AppBar(
                title: const Text('Leaderboard'),
                actions: [
                  // 🚀 SEARCH ICON ADDED HERE
                  if (hasUser)
                    IconButton(
                      icon: const Icon(Icons.search_rounded),
                      color: AppConfig.primaryColor,
                      onPressed: () => _showSearchSheet(context, user!),
                      tooltip: 'Search Player',
                    ),
                  // 🚀 INBOX ICON IS RIGHT HERE!
                  if (hasUser)
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_rounded),
                      color: AppConfig.primaryColor,
                      onPressed: _openInbox,
                      tooltip: 'Messages',
                    ),
                  if (hasUser)
                    IconButton(
                      tooltip: 'My Profile',
                      onPressed: _openProfileEditor,
                      icon: const Icon(Icons.person_rounded),
                      color: AppConfig.primaryColor,
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: !hasUser
                    ? _buildSignedOutState(isDark)
                    : (profile == null)
                    ? _buildNoProfileState(isDark, user!)
                    : (!profile.isOptedIn)
                    ? _buildOptedOutState(isDark, user!, profile)
                    : (_currentError.isNotEmpty &&
                    _currentTop.isEmpty &&
                    !_isCurrentLoading)
                    ? _buildErrorState(isDark, _currentError)
                    : _buildLeaderboardBody(
                  isDark: isDark,
                  user: user!,
                  profile: profile,
                  selfProLocal: selfProLocal,
                  selfProVerified: selfProVerified,
                ),
              ),
              floatingActionButton: canShowLeaderboard
                  ? FloatingActionButton.extended(
                onPressed: _tabController.index == 3
                    ? () => _showAddPostSheet(profile!)
                    : (_isAnyBusy
                    ? null
                    : () => _ensurePeriodLoaded(
                  period: _currentPeriod,
                  syncBeforeFetch: true,
                  haptic: true,
                  forceRefresh: true,
                )),
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                icon: Icon(_tabController.index == 3 ? Icons.add_comment_rounded : Icons.refresh_rounded),
                label: Text(
                  _tabController.index == 3 ? 'Add Post' : (_isAnyBusy ? 'Loading...' : 'Refresh'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.padding,
    required this.borderRadius,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF151C2F) : Colors.white)
                .withOpacity(isDark ? 0.72 : 0.82),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.24 : 0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PublicLeaderboardProfileScreen extends StatelessWidget {
  const _PublicLeaderboardProfileScreen({
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

  String _prettyError(Object e) {
    final msg = e.toString();
    if (msg.contains('network-request-failed') ||
        msg.contains('No internet') ||
        msg.contains('SocketException')) {
      return 'No internet connection. Please try again.';
    }
    return msg
        .replaceAll('AuthServiceException:', '')
        .replaceAll('LeaderboardServiceException:', '')
        .replaceAll('LeaderboardModerationException:', '')
        .trim();
  }

  String _memberForText(int joinedAtMs) {
    if (joinedAtMs <= 0) return 'Member';
    final joined = DateTime.fromMillisecondsSinceEpoch(joinedAtMs, isUtc: true).toLocal();
    final now = DateTime.now();

    final diffDays = now.difference(joined).inDays;
    if (diffDays < 0) return 'Member';

    final years = diffDays ~/ 365;
    final months = (diffDays % 365) ~/ 30;
    final days = (diffDays % 365) % 30;

    if (years > 0) {
      if (months > 0) return 'Member for $years yr $months mo';
      return 'Member for $years yr';
    }
    if (months > 0) {
      if (days > 0) return 'Member for $months mo $days d';
      return 'Member for $months mo';
    }
    if (days > 0) return 'Member for $days d';
    return 'Just joined';
  }

  void _showSnack(
      BuildContext context, {
        required String text,
        required bool isError,
        SnackBarAction? action,
      }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppConfig.errorColor : null,
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  List<Widget> _buildChips(bool isDark) {
    final chips = <Widget>[];

    if (entry.showLevel) {
      chips.add(
        _ProfileChip(
          icon: Icons.military_tech_rounded,
          text: 'Level ${entry.level}',
          color: const Color(0xFFFFD700),
          isDark: isDark,
        ),
      );
    }

    if (entry.showBadges) {
      chips.add(
        _ProfileChip(
          icon: Icons.emoji_events_rounded,
          text: '${entry.badgesUnlocked} badges',
          color: AppConfig.successColor,
          isDark: isDark,
        ),
      );
    }

    if (entry.showStudyHours) {
      final niceHours = entry.studyHours.isFinite
          ? entry.studyHours.toStringAsFixed(entry.studyHours < 10 ? 1 : 0)
          : '0';
      chips.add(
        _ProfileChip(
          icon: Icons.timer_rounded,
          text: '$niceHours hours',
          color: AppConfig.infoColor,
          isDark: isDark,
        ),
      );
    }

    if ((entry.countryCode ?? '').trim().isNotEmpty) {
      chips.add(
        _ProfileChip(
          icon: Icons.public_rounded,
          text: entry.countryCode!.trim().toUpperCase(),
          color: const Color(0xFF8B5CF6),
          isDark: isDark,
        ),
      );
    }

    if (entry.isInterviewUser) {
      chips.add(
        _ProfileChip(
          icon: Icons.workspace_premium_rounded,
          text: 'Crown User',
          color: const Color(0xFFFFD700),
          isDark: isDark,
        ),
      );
    }

    if (entry.uid == me.uid && (selfProLocal || selfProVerified)) {
      chips.add(
        _ProfileChip(
          icon: selfProVerified ? Icons.verified_rounded : Icons.star_rounded,
          text: selfProVerified ? 'Verified Pro' : 'Pro',
          color: AppConfig.primaryColor,
          isDark: isDark,
        ),
      );
    }

    return chips;
  }

  Future<void> _toggleBlock(BuildContext context) async {
    final isBlocked = LeaderboardModerationService.isBlocked(entry.uid);
    try {
      if (isBlocked) {
        await LeaderboardModerationService.unblockUid(entry.uid);
        _showSnack(
          context,
          text: 'Unblocked "${entry.displayName}".',
          isError: false,
        );
      } else {
        await LeaderboardModerationService.blockUid(entry.uid);
        _showSnack(
          context,
          text: 'Blocked "${entry.displayName}".',
          isError: false,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () async {
              try {
                await LeaderboardModerationService.unblockUid(entry.uid);
              } catch (_) {}
            },
          ),
        );
      }
    } catch (e) {
      _showSnack(context, text: _prettyError(e), isError: true);
    }
  }

  Future<void> _reportUser(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final can = await LeaderboardModerationService.canReportNow();
    if (!can) {
      _showSnack(
        context,
        text: 'Please wait a moment before sending another report.',
        isError: true,
      );
      return;
    }

    final result = await showDialog<_ReportPayload>(
      context: context,
      builder: (_) => _ReportDialog(
        isDark: isDark,
        targetName: entry.displayName,
      ),
    );

    if (result == null) return;

    HapticFeedback.mediumImpact();
    SoundService.playTap();

    try {
      await LeaderboardModerationService.reportUser(
        targetUid: entry.uid,
        reasonId: result.reasonId,
        details: result.details,
        targetDisplayName: entry.displayName,
        targetScore: entry.score,
        targetRank: rank,
      );
      await LeaderboardModerationService.markReportedNow();
      _showSnack(context, text: 'Report sent. Thank you.', isError: false);
    } catch (e) {
      _showSnack(context, text: _prettyError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelf = entry.uid == me.uid;

    final scoreText =
    entry.score.isFinite ? entry.score.toStringAsFixed(0) : '0';
    final avatar = entry.avatarEmoji.trim().isEmpty ? '🙂' : entry.avatarEmoji;

    final tagline = (entry.tagline ?? '').trim();
    final bio = (entry.bio ?? '').trim();
    final memberText = _memberForText(entry.joinedAtMs);

    final showSelfProCrown = isSelf && (selfProLocal || selfProVerified);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (isSelf)
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
              },
              icon: const Icon(Icons.edit_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            _GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 24,
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppConfig.primaryColor.withOpacity(0.95),
                                  AppConfig.primaryColor.withOpacity(0.55),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Center(
                              child: Text(avatar,
                                  style: const TextStyle(fontSize: 30)),
                            ),
                          ),
                          if (entry.isInterviewUser)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700)
                                      .withOpacity(isDark ? 0.18 : 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFD700)
                                        .withOpacity(0.35),
                                  ),
                                ),
                                child: const Center(
                                  child: Text('👑', style: TextStyle(fontSize: 13)),
                                ),
                              ),
                            ),
                          if (showSelfProCrown)
                            Positioned(
                              bottom: -7,
                              right: -7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFF59E0B)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF151C2F)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              memberText,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tagline.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                tagline,
                                style: TextStyle(
                                  fontSize: 12.8,
                                  height: 1.35,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (selfProVerified && isSelf) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: AppConfig.successColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Verified Pro',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color:
                                      isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 🚀 DIRECT MESSAGE BUTTON IS HERE!
                  if (!isSelf) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          SoundService.playTap();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                peerUid: entry.uid,
                                peerName: entry.displayName,
                                peerAvatar: avatar,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text('Direct Message', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              _GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bio,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 24,
              child: Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      label: 'Rank',
                      value: '#$rank',
                      color: const Color(0xFFFFD700),
                      isDark: isDark,
                      icon: Icons.military_tech_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBlock(
                      label: 'Score',
                      value: scoreText,
                      color: AppConfig.infoColor,
                      isDark: isDark,
                      icon: Icons.leaderboard_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Highlights',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _buildChips(isDark),
                  ),
                ],
              ),
            ),

            // 🚀 User's Own Social Posts
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('leaderboard_v1_posts')
                  .where('authorUid', isEqualTo: entry.uid)
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

                final posts = snapshot.data!.docs;
                return Column(
                  children: [
                    const SizedBox(height: 14),
                    _GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Updates',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...posts.map((postDoc) {
                            final postData = postDoc.data() as Map<String, dynamic>;
                            final text = postData['content'] as String? ?? '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.campaign_rounded, size: 18, color: AppConfig.primaryColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            if (!isSelf)
              ValueListenableBuilder<Set<String>>(
                valueListenable:
                LeaderboardModerationService.blockedUidsNotifier,
                builder: (context, blockedSet, _) {
                  final isBlocked = blockedSet.contains(entry.uid);

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            SoundService.playTap();
                            await _reportUser(context);
                          },
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text(
                            'Report',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            SoundService.playTap();
                            await _toggleBlock(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBlocked
                                ? AppConfig.successColor
                                : AppConfig.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(
                            isBlocked
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          label: Text(
                            isBlocked ? 'Unblock' : 'Block',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    SoundService.playTap();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardProfileScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.22 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.22 : 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
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

class _ReportPayload {
  final String reasonId;
  final String? details;

  const _ReportPayload({
    required this.reasonId,
    required this.details,
  });
}

class _ReportDialog extends StatefulWidget {
  final bool isDark;
  final String targetName;

  const _ReportDialog({
    required this.isDark,
    required this.targetName,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reasonId = LeaderboardReportReasons.spam;
  final TextEditingController _detailsC = TextEditingController();

  @override
  void dispose() {
    _detailsC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Report ${widget.targetName}',
        style: const TextStyle(fontWeight: FontWeight.w900),
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reasonRadio(
              isDark: isDark,
              value: LeaderboardReportReasons.spam,
              label: 'Spam',
            ),
            _reasonRadio(
              isDark: isDark,
              value: LeaderboardReportReasons.abusive,
              label: 'Abusive content',
            ),
            _reasonRadio(
              isDark: isDark,
              value: LeaderboardReportReasons.impersonation,
              label: 'Impersonation',
            ),
            _reasonRadio(
              isDark: isDark,
              value: LeaderboardReportReasons.inappropriate,
              label: 'Inappropriate content',
            ),
            _reasonRadio(
              isDark: isDark,
              value: LeaderboardReportReasons.other,
              label: 'Other',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsC,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Add more information...',
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _ReportPayload(
                reasonId: _reasonId,
                details: _detailsC.text.trim().isEmpty
                    ? null
                    : _detailsC.text.trim(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text(
            'Send Report',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _reasonRadio({
    required bool isDark,
    required String value,
    required String label,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: _reasonId,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: AppConfig.primaryColor,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _reasonId = v);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🔍 SEARCH PLAYER SHEET (FREE FIRE STYLE)
// ═══════════════════════════════════════════════════════════════════════════════

class _PlayerSearchSheet extends StatefulWidget {
  final User me;
  const _PlayerSearchSheet({required this.me});

  @override
  State<_PlayerSearchSheet> createState() => _PlayerSearchSheetState();
}

class _PlayerSearchSheetState extends State<_PlayerSearchSheet> {
  final TextEditingController _searchC = TextEditingController();
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
      // 1. Exact UID Match
      final doc = await FirebaseFirestore.instance.collection('leaderboard_v1_profiles').doc(query).get();
      if (doc.exists) {
        _results.add({'id': doc.id, ...doc.data() as Map<String, dynamic>});
      } else {
        // 2. Exact Name Match (Case Sensitive)
        final snap = await FirebaseFirestore.instance.collection('leaderboard_v1_profiles')
            .where('displayName', isEqualTo: query)
            .limit(10)
            .get();

        for (var d in snap.docs) {
          if (d.id != widget.me.uid) {
            _results.add({'id': d.id, ...d.data()});
          }
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C2F).withOpacity(0.95) : Colors.white.withOpacity(0.95),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),

                Text('Find Player', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text('Search by exact UID or Player Name.', style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                const SizedBox(height: 20),

                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppConfig.primaryColor.withOpacity(0.3)),
                        ),
                        child: TextField(
                          controller: _searchC,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter UID or Name...',
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                            border: InputBorder.none,
                            icon: const Icon(Icons.search_rounded, color: AppConfig.primaryColor),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _performSearch,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppConfig.primaryColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 24),

                // Results List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor))
                      : (!_hasSearched)
                      ? Center(child: Icon(Icons.person_search_rounded, size: 80, color: isDark ? Colors.white10 : Colors.black12))
                      : (_results.isEmpty)
                      ? Center(child: Text('No player found.', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black45)))
                      : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      final uid = r['id'];
                      final name = r['displayName'] ?? 'Player';
                      final avatar = r['avatarEmoji'] ?? '🙂';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 24, backgroundColor: AppConfig.primaryColor.withOpacity(0.2), child: Text(avatar, style: const TextStyle(fontSize: 24))),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text('UID: $uid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_rounded, color: AppConfig.primaryColor),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peerUid: uid, peerName: name, peerAvatar: avatar)));
                              },
                            )
                          ],
                        ),
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