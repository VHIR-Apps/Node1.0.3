// lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'database_service.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final int timestamp;
  final bool isChallenge;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isChallenge = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderId': senderId,
    'text': text,
    'timestamp': timestamp,
    'isChallenge': isChallenge,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as String? ?? '',
    senderId: map['senderId'] as String? ?? '',
    text: map['text'] as String? ?? '',
    timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    isChallenge: map['isChallenge'] as bool? ?? false,
  );
}

class ChatService {
  static final ChatService instance = ChatService._internal();
  ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ফ্রি ইউজারদের জন্য ডেইলি মেসেজ লিমিট
  static const int _freeDailyMessageLimit = 20;

  // ইউনিক চ্যাট আইডি জেনারেটর (অ্যাডমিন প্যানেলেও এটি ব্যবহার করবেন)
  String getChatId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  // ─────────────────────────────────────────────
  // 🚀 DAILY LIMIT LOGIC (অটো রিফ্রেশ সিস্টেম)
  // ─────────────────────────────────────────────
  Future<void> _checkAndIncrementDailyLimit(String myUid) async {
    // প্রো বা ভিআইপি ইউজার হলে কোনো লিমিট নেই!
    if (DatabaseService.isProOrVipUser()) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final limitDocRef = _db.collection('leaderboard_v1_chat_limits').doc(myUid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(limitDocRef);

      if (snap.exists) {
        final data = snap.data()!;
        final lastDate = data['date'] as String? ?? '';
        int currentCount = (data['count'] as num?)?.toInt() ?? 0;

        // যদি আজকের দিন না হয়, তবে লিমিট রিফ্রেশ করে জিরো করে দাও
        if (lastDate != todayStr) {
          currentCount = 0;
        }

        if (currentCount >= _freeDailyMessageLimit) {
          throw Exception('Daily_Limit_Reached');
        }

        tx.set(
          limitDocRef,
          {'date': todayStr, 'count': currentCount + 1},
          SetOptions(merge: true),
        );
      } else {
        // নতুন ইউজারের প্রথম মেসেজ
        tx.set(limitDocRef, {'date': todayStr, 'count': 1});
      }
    });
  }

  // ─────────────────────────────────────────────
  // 💬 CHAT STREAM (রিয়েলটাইম মেসেজ)
  // ─────────────────────────────────────────────
  Stream<List<ChatMessage>> getChatStream(String peerUid) {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return Stream.value([]);

    final chatId = getChatId(myUid, peerUid);

    return _db
        .collection('leaderboard_v1_chats')
        .doc(chatId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];
      final data = doc.data()!;
      final msgsRaw = data['messages'] as List<dynamic>? ?? [];

      final messages = msgsRaw
          .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      return messages.reversed.toList();
    });
  }

  // ─────────────────────────────────────────────
  // 📥 INBOX STREAM (ইনবক্সের লিস্ট)
  // ─────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getInboxStream() {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return Stream.value([]);

    return _db
        .collection('leaderboard_v1_chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final peerUid = participants.firstWhere((id) => id != myUid, orElse: () => '');

        final msgs = data['messages'] as List<dynamic>? ?? [];
        final lastMsg = msgs.isNotEmpty ? msgs.last : null;

        return {
          'chatId': doc.id,
          'peerUid': peerUid,
          'lastMessage': lastMsg != null ? lastMsg['text'] : '',
          'lastUpdatedMs': lastMsg != null ? lastMsg['timestamp'] : 0,
          'isChallenge': lastMsg != null ? (lastMsg['isChallenge'] ?? false) : false,
          'senderId': lastMsg != null ? lastMsg['senderId'] : '',
        };
      }).toList();
    });
  }

  // ─────────────────────────────────────────────
  // 🚀 SEND MESSAGE (লিমিট ও নোটিফিকেশন পে-লোড সহ)
  // ─────────────────────────────────────────────
  Future<void> sendMessage(String peerUid, String text, {bool isChallenge = false}) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) throw Exception('User not signed in');

    // 1. লিমিট চেক করা (Limit check)
    try {
      await _checkAndIncrementDailyLimit(myUid);
    } catch (e) {
      if (e.toString().contains('Daily_Limit_Reached')) {
        throw Exception('You have reached your daily free chat limit. Upgrade to Pro for unlimited chats!');
      }
      rethrow;
    }

    final chatId = getChatId(myUid, peerUid);
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: myUid,
      text: text.trim(),
      timestamp: nowMs,
      isChallenge: isChallenge,
    );

    final docRef = _db.collection('leaderboard_v1_chats').doc(chatId);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        List<dynamic> messages = [];

        if (snap.exists) {
          messages = snap.data()?['messages'] as List<dynamic>? ?? [];
        }

        messages.add(msg.toMap());

        // ম্যাক্সিমাম ৫০টি মেসেজ রাখার লজিক
        if (messages.length > 50) {
          messages = messages.sublist(messages.length - 50);
        }

        tx.set(
          docRef,
          {
            'messages': messages,
            'lastUpdated': FieldValue.serverTimestamp(),
            'participants': [myUid, peerUid],
            // ক্লায়েন্ট সাইডে নোটিফিকেশন ট্রিগার করার জন্য ফ্ল্যাগ
            'latestActivity': {
              'senderId': myUid,
              'isChallenge': isChallenge,
              'timestamp': nowMs,
            }
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('⚠️ Chat send error: $e');
      throw Exception('Failed to send message');
    }
  }

  // ─────────────────────────────────────────────
  // 🗑️ UNSEND MESSAGE (মেসেজ আনসেন্ড করার লজিক)
  // ─────────────────────────────────────────────
  Future<void> unsendMessage(String peerUid, ChatMessage msg) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return;

    final chatId = getChatId(myUid, peerUid);
    final docRef = _db.collection('leaderboard_v1_chats').doc(chatId);

    try {
      await docRef.update({
        'messages': FieldValue.arrayRemove([msg.toMap()])
      });
    } catch (e) {
      debugPrint('⚠️ Unsend error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 🧹 CLEAR CHAT (পুরো চ্যাট হিস্ট্রি মুছে ফেলার লজিক)
  // ─────────────────────────────────────────────
  Future<void> clearChatHistory(String peerUid) async {
    final myUid = AuthService.instance.uid;
    if (myUid == null) return;

    final chatId = getChatId(myUid, peerUid);
    try {
      await _db.collection('leaderboard_v1_chats').doc(chatId).delete();
    } catch (e) {
      debugPrint('⚠️ Clear chat error: $e');
    }
  }
}