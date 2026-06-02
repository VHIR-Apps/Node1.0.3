// lib/screens/chat_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/sound_service.dart';
import '../services/leaderboard_moderation_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT SCREEN (ULTRA PREMIUM)
// ═══════════════════════════════════════════════════════════════════════════════

class ChatScreen extends StatefulWidget {
  final String peerUid;
  final String peerName;
  final String peerAvatar;

  const ChatScreen({
    super.key,
    required this.peerUid,
    required this.peerName,
    required this.peerAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _msgC = TextEditingController();
  late AnimationController _bgAnimationController;
  final FocusNode _focusNode = FocusNode();

  final AudioPlayer _chatAudioPlayer = AudioPlayer();

  int _previousMessageCount = 0;
  bool _isSending = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    // 🌟 Premium Animated Background
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);

    _isBlocked = LeaderboardModerationService.isBlocked(widget.peerUid);
  }

  @override
  void dispose() {
    _msgC.dispose();
    _focusNode.dispose();
    _bgAnimationController.dispose();
    _chatAudioPlayer.dispose();
    super.dispose();
  }

  // 🎵 Premium Sound Logic
  Future<void> _playChatSound(String fileName) async {
    if (!SoundService.isSoundEnabled) return;
    try {
      await _chatAudioPlayer.stop();
      await _chatAudioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint("Sound Error: $e");
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isError
                    ? AppConfig.errorColor.withOpacity(isDark ? 0.8 : 0.9)
                    : AppConfig.primaryColor.withOpacity(isDark ? 0.8 : 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage({bool isChallenge = false}) async {
    if (_isBlocked) {
      _showSnack('You have blocked this user.', isError: true);
      return;
    }

    final text = _msgC.text.trim();
    if (text.isEmpty && !isChallenge) return;

    if (_isSending) return;
    setState(() => _isSending = true);

    HapticFeedback.mediumImpact();

    final msgText = isChallenge && text.isEmpty ? "I challenge you to a duel! ⚔️" : text;
    _msgC.clear();

    try {
      await ChatService.instance.sendMessage(widget.peerUid, msgText, isChallenge: isChallenge);
      // 🎵 Play Send Sound
      _playChatSound('chat_send.mp3');
    } catch (e) {
      if (e.toString().contains('Upgrade to Pro')) {
        _showSnack('Daily free chat limit reached!', isError: true);
      } else {
        _showSnack('Failed to send message.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      _focusNode.requestFocus();
    }
  }

  // 🚀 Premium Unsend Dialog
  void _showUnsendDialog(ChatMessage msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151C2F).withOpacity(0.85) : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppConfig.errorColor.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_sweep_rounded, color: AppConfig.errorColor, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Unsend Message?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 8),
                  Text('This message will be permanently removed for everyone.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : Colors.black54)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            HapticFeedback.mediumImpact();
                            await ChatService.instance.unsendMessage(widget.peerUid, msg);
                            _showSnack('Message unsent successfully.');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppConfig.errorColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Text('Unsend', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 💎 Ultra-Premium Glass App Bar
  Widget _buildGlassAppBar(bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1020).withOpacity(0.6) : Colors.white.withOpacity(0.6),
            border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          ),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 12, left: 8, right: 16),
          child: Row(
            children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87)),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppConfig.primaryColor.withOpacity(0.9), AppConfig.accentColor.withOpacity(0.9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Center(child: Text(widget.peerAvatar.isEmpty ? '🙂' : widget.peerAvatar, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.peerName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppConfig.successColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Player', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    await ChatService.instance.clearChatHistory(widget.peerUid);
                    _showSnack('Chat cleared!');
                  },
                  icon: const Icon(Icons.cleaning_services_rounded, color: AppConfig.errorColor, size: 22)
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 💬 Premium Chat Bubbles
  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark) {
    final align = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(24), topRight: const Radius.circular(24),
      bottomLeft: Radius.circular(isMe ? 24 : 6), bottomRight: Radius.circular(isMe ? 6 : 24),
    );

    Widget bubbleContent;

    if (isMe) {
      // My Message: Premium Gradient Solid
      bubbleContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppConfig.primaryColor, AppConfig.accentColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: borderRadius,
          boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600)),
      );
    } else {
      // Peer Message: Premium Glassmorphism
      bubbleContent = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.8),
              borderRadius: borderRadius,
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)],
            ),
            child: Text(msg.text, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15.5, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () { if (isMe) _showUnsendDialog(msg); },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        child: Row(
          mainAxisAlignment: align,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              Text(widget.peerAvatar, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
            ],
            Flexible(child: bubbleContent),
          ],
        ),
      ),
    );
  }

  // ✍️ Glassmorphism Input Area
  Widget _buildGlassInputArea(bool isDark) {
    if (_isBlocked) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: 20, bottom: MediaQuery.of(context).padding.bottom + 20),
        color: AppConfig.errorColor.withOpacity(isDark ? 0.15 : 0.1),
        child: const Text("You have blocked this user.", textAlign: TextAlign.center, style: TextStyle(color: AppConfig.errorColor, fontWeight: FontWeight.w800, fontSize: 16)),
      );
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1020).withOpacity(0.7) : Colors.white.withOpacity(0.7),
            border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _sendMessage(isChallenge: true),
                        icon: const Icon(Icons.local_fire_department_rounded, color: AppConfig.accentColor),
                        tooltip: 'Send Challenge',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgC,
                          focusNode: _focusNode,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _sendMessage(),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppConfig.primaryColor, AppConfig.accentColor]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: _isSending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = AuthService.instance.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      body: Stack(
        children: [
          // 🌟 Animated Glowing Orbs Background
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              final t = _bgAnimationController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: 200 + (80 * math.sin(t)),
                    right: -50 + (60 * math.cos(t)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                      child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.primaryColor.withOpacity(isDark ? 0.15 : 0.08))),
                    ),
                  ),
                  Positioned(
                    bottom: 150 + (60 * math.cos(t * 0.8)),
                    left: -80 + (50 * math.sin(t * 1.2)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                      child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.accentColor.withOpacity(isDark ? 0.15 : 0.08))),
                    ),
                  ),
                ],
              );
            },
          ),

          // 💬 Chat Content
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 70),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: ChatService.instance.getChatStream(widget.peerUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _previousMessageCount == 0) {
                      return const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor));
                    }

                    final msgs = snapshot.data ?? [];

                    // 🎵 Play Receive Sound
                    if (msgs.length > _previousMessageCount && _previousMessageCount != 0) {
                      final latestMsg = msgs.first;
                      if (latestMsg.senderId != myUid) {
                        _playChatSound('chat_receive.mp3');
                      }
                    }
                    _previousMessageCount = msgs.length;

                    if (msgs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.waving_hand_rounded, size: 48, color: AppConfig.primaryColor)),
                            const SizedBox(height: 16),
                            Text('Say Hello!', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text('Start a conversation or send a challenge.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                      itemCount: msgs.length,
                      itemBuilder: (context, index) {
                        final msg = msgs[index];
                        final isMe = msg.senderId == myUid;
                        return _buildMessageBubble(msg, isMe, isDark);
                      },
                    );
                  },
                ),
              ),
              _buildGlassInputArea(isDark),
            ],
          ),

          // 📱 App Bar on Top
          Positioned(top: 0, left: 0, right: 0, child: _buildGlassAppBar(isDark)),
        ],
      ),
    );
  }
}