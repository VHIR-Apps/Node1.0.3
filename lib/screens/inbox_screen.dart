// lib/screens/inbox_screen.dart

import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/sound_service.dart';
import '../services/leaderboard_moderation_service.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  final TextEditingController _searchC = TextEditingController();
  String _searchQuery = '';

  final String? myUid = AuthService.instance.uid;

  @override
  void initState() {
    super.initState();
    // 🌟 Premium Background Animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _searchC.dispose();
    super.dispose();
  }

  void _openChat(String peerUid, String peerName, String peerAvatar) {
    HapticFeedback.lightImpact();
    SoundService.playTap();
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

  // 💎 Premium Glassmorphism Container
  Widget _buildPremiumGlass({
    required Widget child,
    required bool isDark,
    double borderRadius = 24.0,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🔍 SEARCH RESULTS (Premium List)
  // ─────────────────────────────────────────────
  Widget _buildSearchResults(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leaderboard_v1_profiles').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor));
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        final query = _searchQuery.toLowerCase();
        final blockedSet = LeaderboardModerationService.blockedUidsNotifier.value;

        final results = docs.where((doc) {
          if (doc.id == myUid) return false;
          if (blockedSet.contains(doc.id)) return false;

          final data = doc.data() as Map<String, dynamic>;
          final name = (data['username'] ?? data['displayName'] ?? '').toString().toLowerCase();
          return name.contains(query) || doc.id.toLowerCase().contains(query);
        }).toList();

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 16),
                Text('No warriors found', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 40, left: 20, right: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final data = results[index].data() as Map<String, dynamic>;
            final peerUid = results[index].id;
            final peerName = data['username'] ?? data['displayName'] ?? 'Unknown Player';
            final peerAvatar = data['avatarEmoji'] ?? data['avatar'] ?? '👤';

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildPremiumGlass(
                isDark: isDark,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppConfig.primaryColor.withOpacity(0.8), AppConfig.accentColor.withOpacity(0.8)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(child: Text(peerAvatar, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(peerName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text('ID: ${peerUid.substring(0, 6)}...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => _openChat(peerUid, peerName, peerAvatar),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
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

  // ─────────────────────────────────────────────
  // 📥 INBOX LIST (Premium Chat History)
  // ─────────────────────────────────────────────
  Widget _buildInboxList(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChatService.instance.getInboxStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor));
        }

        final allChats = snapshot.data ?? [];
        final blockedSet = LeaderboardModerationService.blockedUidsNotifier.value;
        final chats = allChats.where((chat) => !blockedSet.contains(chat['peerUid'])).toList();

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.primaryColor.withOpacity(isDark ? 0.1 : 0.05)),
                  child: Icon(Icons.forum_rounded, size: 70, color: AppConfig.primaryColor.withOpacity(isDark ? 0.8 : 0.5)),
                ),
                const SizedBox(height: 24),
                Text('No Messages Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text('Search above to challenge players!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 40, left: 20, right: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final peerUid = chat['peerUid'] ?? '';
            final lastMsg = chat['lastMessage'] ?? '';
            final isChallenge = chat['isChallenge'] ?? false;
            final senderId = chat['senderId'] ?? '';

            final prefix = senderId == myUid ? "You: " : "";
            final displayMsg = isChallenge ? "⚔️ Challenge!" : "$prefix$lastMsg";

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('leaderboard_v1_profiles').doc(peerUid).get(),
              builder: (context, userSnap) {
                String peerName = 'Player';
                String peerAvatar = '👤';

                if (userSnap.hasData && userSnap.data!.exists) {
                  final uData = userSnap.data!.data() as Map<String, dynamic>;
                  peerName = uData['displayName'] ?? uData['username'] ?? peerName;
                  peerAvatar = uData['avatarEmoji'] ?? uData['avatar'] ?? peerAvatar;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildPremiumGlass(
                    isDark: isDark,
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openChat(peerUid, peerName, peerAvatar),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: AppConfig.primaryColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(child: Text(peerAvatar, style: const TextStyle(fontSize: 28))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(peerName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Text(
                                      displayMsg,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isChallenge ? FontWeight.w800 : FontWeight.w600,
                                        color: isChallenge ? const Color(0xFFF59E0B) : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04), shape: BoxShape.circle),
                                child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black87),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: isDark ? const Color(0xFF0B1020).withOpacity(0.6) : Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 🌟 Animated Glowing Orbs Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final t = _bgController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: 150 + (60 * math.sin(t)),
                    right: -80 + (50 * math.cos(t)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Container(
                        width: 350, height: 350,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.primaryColor.withOpacity(isDark ? 0.2 : 0.1)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 100 + (70 * math.cos(t * 0.8)),
                    left: -100 + (60 * math.sin(t * 1.2)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Container(
                        width: 300, height: 300,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.accentColor.withOpacity(isDark ? 0.15 : 0.08)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                // 🔍 Ultra-Premium Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: _buildPremiumGlass(
                    isDark: isDark,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    borderRadius: 24,
                    child: TextField(
                      controller: _searchC,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, color: AppConfig.primaryColor, size: 26),
                        hintText: 'Search player by name...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        suffixIcon: isSearching
                            ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white54 : Colors.black54),
                          onPressed: () {
                            _searchC.clear();
                            setState(() => _searchQuery = '');
                            FocusScope.of(context).unfocus();
                          },
                        )
                            : null,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                ),

                // 📜 Content Area (Search Results or Inbox)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isSearching ? _buildSearchResults(isDark) : _buildInboxList(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}