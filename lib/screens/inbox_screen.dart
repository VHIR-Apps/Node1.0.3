// lib/screens/inbox_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/chat_notification_service.dart';
import '../services/sound_service.dart';
import '../services/leaderboard_moderation_service.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  final TextEditingController _searchC =
  TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;

  final String? myUid = AuthService.instance.uid;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    // Inbox খোলা থাকলে notification মুট করো না
    // কিন্তু inbox listener শুরু করো
    ChatNotificationService.instance.setActiveChatPeer(null);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _searchC.dispose();
    super.dispose();
  }

  void _openChat(
      String peerUid, String peerName, String peerAvatar) {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    // Chat এ যাওয়ার আগে pending notification cancel করো
    ChatNotificationService.instance
        .cancelChatNotification(peerUid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerUid: peerUid,
          peerName: peerName,
          peerAvatar: peerAvatar,
        ),
      ),
    );
  }

  String _formatTime(int timestampMs) {
    if (timestampMs <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(
        timestampMs, isUtc: true)
        .toLocal();
    final now = DateTime.now();
    final h = d.hour > 12
        ? d.hour - 12
        : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final p = d.hour >= 12 ? 'PM' : 'AM';

    if (d.year == now.year &&
        d.month == now.month &&
        d.day == now.day) {
      return '$h:$m $p';
    }
    if (d.year == now.year &&
        d.month == now.month &&
        d.day == now.day - 1) {
      return 'Yesterday';
    }
    return '${d.day}/${d.month}';
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }

    setState(() => _searchLoading = true);

    try {
      final results = <Map<String, dynamic>>[];

      final uidDoc = await FirebaseFirestore.instance
          .collection('leaderboard_v1_users')
          .doc(query.trim())
          .get();
      if (uidDoc.exists && uidDoc.id != myUid) {
        results.add({
          'uid': uidDoc.id,
          ...uidDoc.data() as Map<String, dynamic>
        });
      }

      final nameSnap = await FirebaseFirestore.instance
          .collection('leaderboard_v1_users')
          .where('displayName',
          isGreaterThanOrEqualTo: query.trim())
          .where('displayName',
          isLessThanOrEqualTo: '${query.trim()}\uf8ff')
          .limit(10)
          .get();

      for (final d in nameSnap.docs) {
        if (d.id != myUid &&
            !results.any((r) => r['uid'] == d.id)) {
          results.add({'uid': d.id, ...d.data()});
        }
      }

      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      debugPrint('Inbox search error: $e');
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Widget _buildGlass({
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
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black
                      .withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6))
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildConversationTile({
    required bool isDark,
    required String peerUid,
    required String peerName,
    required String peerAvatar,
    required String lastMessage,
    required int lastUpdatedMs,
    required bool isMine,
  }) {
    final blocked =
    LeaderboardModerationService.isBlocked(peerUid);
    if (blocked) return const SizedBox.shrink();

    final timeStr = _formatTime(lastUpdatedMs);
    final prefix = isMine ? 'You: ' : '';
    final displayMsg = '$prefix$lastMessage';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _buildGlass(
        isDark: isDark,
        padding: EdgeInsets.zero,
        borderRadius: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _openChat(peerUid, peerName, peerAvatar),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppConfig.primaryColor
                              .withOpacity(0.8),
                          AppConfig.accentColor
                              .withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppConfig.primaryColor
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Center(
                        child: Text(
                            peerAvatar.isEmpty
                                ? '🙂'
                                : peerAvatar,
                            style: const TextStyle(
                                fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                peerName,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87),
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            ),
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                    FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        .withOpacity(0.45)
                                        : Colors.black38),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          displayMsg.isEmpty
                              ? 'Start a conversation...'
                              : displayMsg,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: isDark
                          ? Colors.white.withOpacity(0.24)
                          : Colors.black26,
                      size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInboxStream(bool isDark) {
    if (myUid == null) {
      return Center(
        child: Text(
          'Please sign in to view messages.',
          style: TextStyle(
              color:
              isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leaderboard_v1_chats')
          .where('participants', arrayContains: myUid)
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppConfig.primaryColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppConfig.errorColor, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load messages.',
                    style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : Colors.black54,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState(isDark);

        return ListView.builder(
          padding:
          const EdgeInsets.fromLTRB(16, 8, 16, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final chatDoc = docs[index];
            final data =
            chatDoc.data() as Map<String, dynamic>;
            final participants = List<String>.from(
                data['participants'] ?? []);
            final peerUid = participants.firstWhere(
                    (id) => id != myUid,
                orElse: () => '');

            if (peerUid.isEmpty) {
              return const SizedBox.shrink();
            }

            final msgs =
                data['messages'] as List<dynamic>? ?? [];
            String lastMsg = '';
            int lastMs = 0;
            String senderId = '';

            if (msgs.isNotEmpty) {
              final last =
              msgs.last as Map<dynamic, dynamic>;
              lastMsg = (last['text'] as String?) ?? '';
              lastMs =
                  (last['timestamp'] as num?)?.toInt() ??
                      0;
              senderId =
                  (last['senderId'] as String?) ?? '';
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('leaderboard_v1_users')
                  .doc(peerUid)
                  .get(),
              builder: (context, userSnap) {
                String peerName = 'Unknown Player';
                String peerAvatar = '🙂';

                if (userSnap.hasData &&
                    userSnap.data!.exists) {
                  final uData = userSnap.data!.data()
                  as Map<String, dynamic>;
                  peerName =
                      (uData['displayName'] as String?) ??
                          peerName;
                  peerAvatar =
                      (uData['avatarEmoji'] as String?) ??
                          peerAvatar;
                }

                return _buildConversationTile(
                  isDark: isDark,
                  peerUid: peerUid,
                  peerName: peerName,
                  peerAvatar: peerAvatar,
                  lastMessage: lastMsg,
                  lastUpdatedMs: lastMs,
                  isMine: senderId == myUid,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConfig.primaryColor
                      .withOpacity(isDark ? 0.1 : 0.06)),
              child: Icon(Icons.forum_rounded,
                  size: 64,
                  color: AppConfig.primaryColor
                      .withOpacity(isDark ? 0.7 : 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No Messages Yet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color:
                  isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              'Go to Leaderboard and tap on a player\nto start a conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white54
                      : Colors.black54),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.leaderboard_rounded),
              label: const Text(
                'Go to Leaderboard',
                style:
                TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(16))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppConfig.primaryColor));
    }

    if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_rounded,
                  size: 64,
                  color: isDark
                      ? Colors.white.withOpacity(0.24)
                      : Colors.black12),
              const SizedBox(height: 16),
              Text(
                'No players found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching by exact UID or name.',
                style: TextStyle(
                    color: isDark
                        ? Colors.white38
                        : Colors.black38,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      physics: const BouncingScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final r = _searchResults[index];
        final uid = (r['uid'] as String?) ?? '';
        final name =
            (r['displayName'] as String?) ?? 'Player';
        final avatar =
            (r['avatarEmoji'] as String?) ?? '🙂';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildGlass(
            isDark: isDark,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppConfig.primaryColor
                            .withOpacity(0.8),
                        AppConfig.accentColor
                            .withOpacity(0.6),
                      ]),
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text(
                          avatar.isEmpty ? '🙂' : avatar,
                          style: const TextStyle(
                              fontSize: 24))),
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
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDark
                                ? Colors.white
                                : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UID: ${uid.length > 12 ? uid.substring(0, 12) : uid}...',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white54
                                : Colors.black54),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      _openChat(uid, name, avatar),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [
                            AppConfig.primaryColor,
                            AppConfig.accentColor,
                          ]),
                      borderRadius:
                      BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppConfig.primaryColor
                                .withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Chat',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark
          ? const Color(0xFF0B1020)
          : const Color(0xFFF7F8FC),
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final t =
                  _bgController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: 150 + (60 * math.sin(t)),
                    right: -80 + (50 * math.cos(t)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                          sigmaX: 80, sigmaY: 80),
                      child: Container(
                          width: 350,
                          height: 350,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                              AppConfig.primaryColor
                                  .withOpacity(isDark
                                  ? 0.18
                                  : 0.08))),
                    ),
                  ),
                  Positioned(
                    bottom:
                    100 + (70 * math.cos(t * 0.8)),
                    left:
                    -100 + (60 * math.sin(t * 1.2)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                          sigmaX: 80, sigmaY: 80),
                      child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppConfig.accentColor
                                  .withOpacity(isDark
                                  ? 0.12
                                  : 0.06))),
                    ),
                  ),
                ],
              );
            },
          ),

          // Main content
          Column(
            children: [
              // App bar with search
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: 25, sigmaY: 25),
                  child: Container(
                    color: isDark
                        ? const Color(0xFF0B1020)
                        .withOpacity(0.6)
                        : Colors.white.withOpacity(0.6),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding:
                        const EdgeInsets.fromLTRB(
                            16, 12, 16, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                      Icons
                                          .arrow_back_ios_new_rounded,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  onPressed: () =>
                                      Navigator.pop(context),
                                ),
                                Expanded(
                                  child: Text(
                                    'Messages',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight:
                                        FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: isDark
                                            ? Colors.white
                                            : Colors
                                            .black87),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Search bar
                            ClipRRect(
                              borderRadius:
                              BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                      horizontal: 16,
                                      vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white
                                        .withOpacity(
                                        0.06)
                                        : Colors.black
                                        .withOpacity(
                                        0.04),
                                    borderRadius:
                                    BorderRadius
                                        .circular(16),
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.white
                                            .withOpacity(
                                            0.1)
                                            : Colors.black
                                            .withOpacity(
                                            0.06)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                          Icons
                                              .search_rounded,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors
                                              .black45,
                                          size: 20),
                                      const SizedBox(
                                          width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller:
                                          _searchC,
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors
                                                  .white
                                                  : Colors
                                                  .black87,
                                              fontWeight:
                                              FontWeight
                                                  .w600),
                                          decoration:
                                          InputDecoration(
                                            hintText:
                                            'Search by name or UID...',
                                            hintStyle:
                                            TextStyle(
                                              color: isDark
                                                  ? Colors
                                                  .white38
                                                  : Colors
                                                  .black38,
                                              fontWeight:
                                              FontWeight
                                                  .w500,
                                            ),
                                            border:
                                            InputBorder
                                                .none,
                                            isDense: true,
                                          ),
                                          onChanged: (v) {
                                            setState(() {
                                              _searchQuery =
                                                  v;
                                              _isSearching =
                                                  v.isNotEmpty;
                                            });
                                            if (v.length >=
                                                2) {
                                              _performSearch(
                                                  v);
                                            } else if (v
                                                .isEmpty) {
                                              setState(() =>
                                              _searchResults =
                                              []);
                                            }
                                          },
                                        ),
                                      ),
                                      if (_searchQuery
                                          .isNotEmpty)
                                        IconButton(
                                          padding:
                                          EdgeInsets.zero,
                                          constraints:
                                          const BoxConstraints(),
                                          icon: Icon(
                                              Icons
                                                  .close_rounded,
                                              size: 18,
                                              color: isDark
                                                  ? Colors
                                                  .white54
                                                  : Colors
                                                  .black45),
                                          onPressed: () {
                                            _searchC.clear();
                                            setState(() {
                                              _searchQuery =
                                              '';
                                              _isSearching =
                                              false;
                                              _searchResults =
                                              [];
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _isSearching
                    ? _buildSearchResults(isDark)
                    : _buildInboxStream(isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}