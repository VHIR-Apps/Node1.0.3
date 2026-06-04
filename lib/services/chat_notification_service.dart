// lib/services/chat_notification_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auth_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Chat Notification Service
// App foreground-এ থাকলে chat message এলে local notification দেখাবে
// ═══════════════════════════════════════════════════════════════════════════════

class ChatNotificationService {
  ChatNotificationService._();

  static final ChatNotificationService instance =
  ChatNotificationService._();

  static const String _channelId = 'chat_messages_v1';
  static const String _channelName = 'Chat Messages';

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Currently open chat peer UID
  // এই UID-এর জন্য notification দেখাবে না
  String? _activeChatPeerUid;

  // Notification tap callback
  // main.dart থেকে set করা হবে
  Function(String peerUid)? onNotificationTap;

  // Firestore inbox listener
  StreamSubscription<QuerySnapshot>? _inboxListener;

  // Track last known message counts per chatId
  final Map<String, int> _lastMsgCounts = {};

  // Peer info cache (name + avatar)
  final Map<String, Map<String, String>> _peerInfoCache =
  {};

  // ─────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings =
    InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create notification channel
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description:
        'Notifications for new chat messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    _initialized = true;
    debugPrint('✅ ChatNotificationService initialized');
  }

  // ─────────────────────────────────────────────
  // Notification tap handler
  // ─────────────────────────────────────────────

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    debugPrint('💬 Chat notification tapped: $payload');
    onNotificationTap?.call(payload);
  }

  // ─────────────────────────────────────────────
  // Set active chat peer
  // Chat screen খোলা থাকলে ওই peer-এর notification mute
  // ─────────────────────────────────────────────

  void setActiveChatPeer(String? peerUid) {
    _activeChatPeerUid = peerUid;
    debugPrint('💬 Active chat peer set: $peerUid');
  }

  // ─────────────────────────────────────────────
  // Start inbox-wide Firestore listener
  // ─────────────────────────────────────────────

  Future<void> startInboxListener() async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return;

    await init();

    // পুরনো listener বন্ধ করো আগে
    await _inboxListener?.cancel();
    _inboxListener = null;

    debugPrint('👂 Starting chat inbox listener...');

    _inboxListener = FirebaseFirestore.instance
        .collection('leaderboard_v1_chats')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .listen(
          (snapshot) async {
        for (final docChange in snapshot.docChanges) {
          // Removed documents skip করো
          if (docChange.type ==
              DocumentChangeType.removed) {
            continue;
          }

          final data = docChange.doc.data()
          as Map<String, dynamic>?;
          if (data == null) continue;

          final chatId = docChange.doc.id;
          final participants = List<String>.from(
              data['participants'] ?? []);
          final peerUid = participants.firstWhere(
                (id) => id != myUid,
            orElse: () => '',
          );

          if (peerUid.isEmpty) continue;

          // Active chat peer-এর notification skip
          if (peerUid == _activeChatPeerUid) continue;

          final msgs =
              data['messages'] as List<dynamic>? ?? [];
          final currentCount = msgs.length;
          final lastCount =
              _lastMsgCounts[chatId] ?? currentCount;

          // নতুন document add হলে শুধু count track করো,
          // notification দেখাবে না (initial load)
          if (docChange.type ==
              DocumentChangeType.added) {
            _lastMsgCounts[chatId] = currentCount;
            continue;
          }

          // Modified document — নতুন message check
          if (currentCount > lastCount) {
            final newMsgStartIndex = lastCount;

            for (int i = newMsgStartIndex;
            i < currentCount;
            i++) {
              if (i >= msgs.length) break;

              final msgRaw = msgs[i];
              final msg =
              msgRaw as Map<dynamic, dynamic>;
              final senderId =
                  (msg['senderId'] as String?) ?? '';

              // নিজের message-এ notification skip
              if (senderId == myUid) continue;

              final msgText =
                  (msg['text'] as String?) ?? '';
              final isChallenge =
                  (msg['isChallenge'] as bool?) ?? false;

              if (msgText.isNotEmpty) {
                // Peer name/avatar fetch করো
                final peerInfo =
                await _fetchPeerInfo(peerUid);

                await _showChatNotification(
                  peerUid: peerUid,
                  senderName:
                  peerInfo['name'] ?? 'Player',
                  senderAvatar:
                  peerInfo['avatar'] ?? '💬',
                  message: isChallenge
                      ? '⚔️ Challenge: $msgText'
                      : msgText,
                );
              }
            }
          }

          // Count update করো
          _lastMsgCounts[chatId] = currentCount;
        }
      },
      onError: (e) {
        debugPrint('❌ Chat inbox listener error: $e');
      },
    );
  }

  // ─────────────────────────────────────────────
  // Fetch peer info from leaderboard_v1_users
  // ─────────────────────────────────────────────

  Future<Map<String, String>> _fetchPeerInfo(
      String peerUid) async {
    // Cache hit
    if (_peerInfoCache.containsKey(peerUid)) {
      return _peerInfoCache[peerUid]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('leaderboard_v1_users')
          .doc(peerUid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final info = {
          'name': (data['displayName'] as String?)
              ?.trim()
              .isNotEmpty ==
              true
              ? (data['displayName'] as String).trim()
              : 'Player',
          'avatar':
          (data['avatarEmoji'] as String?)
              ?.trim()
              .isNotEmpty ==
              true
              ? (data['avatarEmoji'] as String)
              .trim()
              : '💬',
        };
        // Cache-এ রাখো
        _peerInfoCache[peerUid] = info;
        return info;
      }
    } catch (e) {
      debugPrint('❌ Fetch peer info error: $e');
    }

    return {'name': 'Player', 'avatar': '💬'};
  }

  // ─────────────────────────────────────────────
  // Show local notification
  // ─────────────────────────────────────────────

  Future<void> _showChatNotification({
    required String peerUid,
    required String senderName,
    required String senderAvatar,
    required String message,
  }) async {
    if (!_initialized) await init();

    // Same peer = same notification ID (update হবে)
    final notifId = peerUid.hashCode.abs() % 50000;
    final title = '$senderAvatar $senderName';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF6C63FF),
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      groupKey: 'chat_messages',
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        contentTitle: title,
        summaryText: 'New Message',
      ),
    );

    try {
      await _plugin.show(
        notifId,
        title,
        message,
        NotificationDetails(android: androidDetails),
        payload: peerUid,
      );
      debugPrint(
          '🔔 Chat notification shown: $senderName');
    } catch (e) {
      debugPrint(
          '❌ Chat notification show error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Manual show (external call)
  // ─────────────────────────────────────────────

  Future<void> showManualNotification({
    required String peerUid,
    required String senderName,
    required String senderAvatar,
    required String message,
  }) async {
    // Active chat-এ দেখাবে না
    if (peerUid == _activeChatPeerUid) return;

    await _showChatNotification(
      peerUid: peerUid,
      senderName: senderName,
      senderAvatar: senderAvatar,
      message: message,
    );
  }

  // ─────────────────────────────────────────────
  // Cancel specific notification
  // ─────────────────────────────────────────────

  Future<void> cancelChatNotification(
      String peerUid) async {
    final notifId = peerUid.hashCode.abs() % 50000;
    await _plugin.cancel(notifId);
  }

  // ─────────────────────────────────────────────
  // Cancel all chat notifications
  // ─────────────────────────────────────────────

  Future<void> cancelAllChatNotifications() async {
    await _plugin.cancelAll();
  }

  // ─────────────────────────────────────────────
  // Stop inbox listener
  // ─────────────────────────────────────────────

  Future<void> stopInboxListener() async {
    await _inboxListener?.cancel();
    _inboxListener = null;
    _lastMsgCounts.clear();
    debugPrint('🛑 Chat inbox listener stopped');
  }

  // ─────────────────────────────────────────────
  // Stop all listeners
  // ─────────────────────────────────────────────

  Future<void> stopAllListeners() async {
    await stopInboxListener();
  }

  // ─────────────────────────────────────────────
  // Reset state (logout হলে)
  // ─────────────────────────────────────────────

  void resetState() {
    _lastMsgCounts.clear();
    _activeChatPeerUid = null;
    _peerInfoCache.clear();
    debugPrint('🔄 ChatNotificationService reset');
  }
}