// lib/screens/leaderboard_social_tab.dart

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/leaderboard_profile_model.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';

/// ═════════════════════════════════════════════════
/// SOCIAL TAB — আমি যাদের Like করেছি তাদের list
/// ═════════════════════════════════════════════════
class LeaderboardSocialFeedTab extends StatefulWidget {
  const LeaderboardSocialFeedTab({
    super.key,
    required this.activeUid,
    required this.isDark,
  });

  final String? activeUid;
  final bool isDark;

  @override
  State<LeaderboardSocialFeedTab> createState() =>
      _LeaderboardSocialFeedTabState();
}

class _LeaderboardSocialFeedTabState
    extends State<LeaderboardSocialFeedTab> {
  bool _isLoading = true;
  List<_LikedProfile> _likedProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadLikedProfiles();
  }

  Future<void> _loadLikedProfiles() async {
    final myUid = widget.activeUid;
    if (myUid == null || myUid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _likedProfiles = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // ✅ Step 1: সব user profile load করো
      // তারপর check করো আমি কাকে কাকে like করেছি
      final usersSnap = await FirebaseFirestore.instance
          .collection('leaderboard_v1_users')
          .get(_safeGetOptions())
          .timeout(const Duration(seconds: 10));

      final List<_LikedProfile> results = [];

      for (final userDoc in usersSnap.docs) {
        if (userDoc.id == myUid) continue;

        try {
          // Check: আমি এই user কে like করেছি কিনা
          final likeDoc = await FirebaseFirestore
              .instance
              .collection('leaderboard_v1_users')
              .doc(userDoc.id)
              .collection('likes')
              .doc(myUid)
              .get(_safeGetOptions());

          if (likeDoc.exists) {
            final userData = userDoc.data();
            final likeData = likeDoc.data();
            final likedAt =
            likeData?['likedAt'] as Timestamp?;

            results.add(_LikedProfile(
              uid: userDoc.id,
              displayName:
              (userData['displayName'] as String?) ??
                  'Player',
              avatarEmoji:
              (userData['avatarEmoji'] as String?) ??
                  '🙂',
              score: (userData['metrics']
              ?['score'] as num?)
                  ?.toDouble() ??
                  0.0,
              level:
              (userData['metrics']?['level'] as int?) ??
                  0,
              likedAtMs: likedAt?.millisecondsSinceEpoch ??
                  0,
            ));
          }
        } catch (_) {
          // Single user check fail — skip
        }
      }

      // Sort: সবচেয়ে recent like আগে
      results.sort(
              (a, b) => b.likedAtMs.compareTo(a.likedAtMs));

      if (mounted) {
        setState(() {
          _likedProfiles = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Liked profiles load error: $e');

      // ✅ Offline fallback — cache থেকে try করো
      // Error UI দেখাবে না
      try {
        await _loadFromCache(myUid);
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            // ✅ Error দেখাবে না — empty list দেখাবে
          });
        }
      }
    }
  }

  Future<void> _loadFromCache(String myUid) async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('leaderboard_v1_users')
        .get(const GetOptions(source: Source.cache));

    final List<_LikedProfile> results = [];

    for (final userDoc in usersSnap.docs) {
      if (userDoc.id == myUid) continue;

      try {
        final likeDoc = await FirebaseFirestore.instance
            .collection('leaderboard_v1_users')
            .doc(userDoc.id)
            .collection('likes')
            .doc(myUid)
            .get(const GetOptions(source: Source.cache));

        if (likeDoc.exists) {
          final userData = userDoc.data();
          final likeData = likeDoc.data();
          final likedAt =
          likeData?['likedAt'] as Timestamp?;

          results.add(_LikedProfile(
            uid: userDoc.id,
            displayName:
            (userData['displayName'] as String?) ??
                'Player',
            avatarEmoji:
            (userData['avatarEmoji'] as String?) ??
                '🙂',
            score: (userData['metrics']?['score'] as num?)
                ?.toDouble() ??
                0.0,
            level:
            (userData['metrics']?['level'] as int?) ??
                0,
            likedAtMs:
            likedAt?.millisecondsSinceEpoch ?? 0,
          ));
        }
      } catch (_) {}
    }

    results
        .sort((a, b) => b.likedAtMs.compareTo(a.likedAtMs));

    if (mounted) {
      setState(() {
        _likedProfiles = results;
        _isLoading = false;
      });
    }
  }

  GetOptions _safeGetOptions() {
    return const GetOptions(
        source: Source.serverAndCache);
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '';
    final dt =
    DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    // LOADING
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(
            color: AppConfig.primaryColor,
          ),
        ),
      );
    }

    // EMPTY
    if (_likedProfiles.isEmpty) {
      return _buildEmpty();
    }

    // LIST
    return RefreshIndicator(
      onRefresh: _loadLikedProfiles,
      color: AppConfig.primaryColor,
      child: ListView.builder(
        padding:
        const EdgeInsets.fromLTRB(18, 14, 18, 40),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: _likedProfiles.length + 1,
        itemBuilder: (context, index) {
          // Header
          if (index == 0) {
            return _buildHeader();
          }

          final profile =
          _likedProfiles[index - 1];
          return _LikedProfileCard(
            profile: profile,
            isDark: widget.isDark,
            timeText: _formatTime(profile.likedAtMs),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF4D6D)
                  .withOpacity(0.15),
              const Color(0xFFFF0040)
                  .withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFF4D6D)
                .withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF4D6D),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liked Profiles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: widget.isDark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_likedProfiles.length} ${_likedProfiles.length == 1 ? 'profile' : 'profiles'} liked',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? Colors.white54
                          : Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D6D)
                    .withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '❤️',
                  style: TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Liked Profiles Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: widget.isDark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Like someone\'s profile from the\nleaderboard and they\'ll appear here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: widget.isDark
                    ? Colors.white54
                    : Colors.black45,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadLikedProfiles,
              icon:
              const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                AppConfig.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═════════════════════════════════════════════════
/// LIKED PROFILE DATA MODEL
/// ═════════════════════════════════════════════════
class _LikedProfile {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final double score;
  final int level;
  final int likedAtMs;

  const _LikedProfile({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.score,
    required this.level,
    required this.likedAtMs,
  });
}

/// ═════════════════════════════════════════════════
/// LIKED PROFILE CARD
/// ═════════════════════════════════════════════════
class _LikedProfileCard extends StatelessWidget {
  const _LikedProfileCard({
    required this.profile,
    required this.isDark,
    required this.timeText,
  });

  final _LikedProfile profile;
  final bool isDark;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(isDark ? 0.12 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConfig.primaryColor,
                  AppConfig.primaryColor
                      .withOpacity(0.6),
                ],
              ),
              borderRadius:
              BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppConfig.primaryColor
                      .withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                profile.avatarEmoji,
                style:
                const TextStyle(fontSize: 26),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (profile.level > 0) ...[
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                            horizontal: 8,
                            vertical: 3),
                        decoration: BoxDecoration(
                          color: AppConfig
                              .primaryColor
                              .withOpacity(0.12),
                          borderRadius:
                          BorderRadius
                              .circular(8),
                        ),
                        child: Text(
                          'Lv.${profile.level}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight:
                            FontWeight.w900,
                            color: AppConfig
                                .primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (profile.score > 0)
                      Text(
                        '${profile.score.toStringAsFixed(0)} XP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                          FontWeight.w700,
                          color: isDark
                              ? Colors.white54
                              : Colors.black45,
                        ),
                      ),
                  ],
                ),
                if (timeText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF4D6D),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Liked $timeText',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white38
                              : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Heart icon
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF4D6D),
            size: 22,
          ),
        ],
      ),
    );
  }
}

/// ═════════════════════════════════════════════════
/// ADD POST SHEET — এটা leaderboard_screen.dart থেকে
/// call হয়, তাই এখানেই রাখতে হবে
/// ═════════════════════════════════════════════════

int _wordCount(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

String _trimToMaxWords(String text, int maxWords) {
  final t = text.trim();
  if (t.isEmpty) return '';
  final words = t.split(RegExp(r'\s+'));
  if (words.length <= maxWords) return text;
  return words.take(maxWords).join(' ');
}

Future<void> showAddPostSheet({
  required BuildContext context,
  required LeaderboardProfileModel profile,
  required String? activeUid,
  required Function() onSuccess,
  required Function(Object error) onError,
}) async {
  if (activeUid == null) return;

  HapticFeedback.mediumImpact();
  SoundService.playTap();

  final TextEditingController postC =
  TextEditingController();
  bool isPosting = false;
  bool isAdjusting = false;

  const int maxPostWords = 500;
  const int maxPostChars = 3000;

  final isDark =
      Theme.of(context).brightness == Brightness.dark;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
            MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF151C2F)
                      .withOpacity(0.95)
                      : Colors.white
                      .withOpacity(0.95),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey
                            .withOpacity(0.3),
                        borderRadius:
                        BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Share Your Progress',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black26
                            : Colors.black
                            .withOpacity(0.04),
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: postC,
                        maxLines: 6,
                        maxLength: maxPostChars,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : Colors.black87,
                          fontWeight:
                          FontWeight.w600,
                        ),
                        onChanged: (value) {
                          if (isAdjusting) return;
                          final words =
                          _wordCount(value);
                          if (words >
                              maxPostWords) {
                            final trimmed =
                            _trimToMaxWords(
                                value,
                                maxPostWords);
                            isAdjusting = true;
                            postC.value =
                                TextEditingValue(
                                  text: trimmed,
                                  selection:
                                  TextSelection
                                      .collapsed(
                                    offset:
                                    trimmed.length,
                                  ),
                                );
                            isAdjusting = false;
                          }
                          setSheetState(() {});
                        },
                        decoration: InputDecoration(
                          hintText:
                          'What did you achieve today?',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                          ),
                          border: InputBorder.none,
                          counterText:
                          '${_wordCount(postC.text)} / $maxPostWords words',
                          counterStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w600,
                            color: _wordCount(
                                postC.text) >
                                maxPostWords
                                ? AppConfig
                                .errorColor
                                : (isDark
                                ? Colors
                                .white38
                                : Colors
                                .black38),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          AppConfig
                              .primaryColor,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(16),
                          ),
                        ),
                        onPressed: isPosting
                            ? null
                            : () async {
                          final text = postC
                              .text
                              .trim();
                          if (text.isEmpty) {
                            return;
                          }

                          final words =
                          _wordCount(
                              text);
                          if (words >
                              maxPostWords) {
                            onError(Exception(
                                'Maximum $maxPostWords words allowed.'));
                            return;
                          }

                          setSheetState(() =>
                          isPosting =
                          true);

                          try {
                            final nowMs =
                                DateTime.now()
                                    .millisecondsSinceEpoch;

                            await FirebaseFirestore
                                .instance
                                .collection(
                                'leaderboard_v1_posts')
                                .add({
                              'authorUid':
                              activeUid,
                              'authorName':
                              profile
                                  .displayName,
                              'authorAvatar': profile
                                  .avatarEmoji
                                  .isEmpty
                                  ? '🙂'
                                  : profile
                                  .avatarEmoji,
                              'authorXp':
                              profile
                                  .cachedScore,
                              'content':
                              text,
                              'timestamp':
                              FieldValue
                                  .serverTimestamp(),
                              'clientTimestampMs':
                              nowMs,
                              'likeCount':
                              0,
                              'dislikeCount':
                              0,
                              'reportCount':
                              0,
                            });

                            postC.clear();
                            onSuccess();

                            if (context
                                .mounted) {
                              Navigator.pop(
                                  context);
                            }
                          } catch (e) {
                            setSheetState(
                                    () =>
                                isPosting =
                                false);
                            onError(e);
                          }
                        },
                        child: isPosting
                            ? const CircularProgressIndicator(
                          color:
                          Colors.white,
                        )
                            : const Text(
                          'Post Now 🚀',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight
                                .w900,
                            color:
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}