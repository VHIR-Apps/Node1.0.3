// lib/services/profile_like_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LikerInfo {
  final String uid;
  final DateTime likedAt;

  const LikerInfo({
    required this.uid,
    required this.likedAt,
  });
}

class ProfileLikeService {
  ProfileLikeService._();
  static final ProfileLikeService instance =
  ProfileLikeService._();

  static const String _usersCollection =
      'leaderboard_v1_users';
  static const String _likesSubcollection = 'likes';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<bool> hasLikedStream({
    required String targetUid,
    required String myUid,
  }) {
    return _db
        .collection(_usersCollection)
        .doc(targetUid)
        .collection(_likesSubcollection)
        .doc(myUid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Stream<int> likeCountStream({
    required String targetUid,
  }) {
    return _db
        .collection(_usersCollection)
        .doc(targetUid)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return 0;
      final data = snap.data();
      if (data == null) return 0;
      return (data['likeCount'] as int?) ?? 0;
    });
  }

  Stream<List<LikerInfo>> whoLikedStream({
    required String targetUid,
    int limit = 50,
  }) {
    return _db
        .collection(_usersCollection)
        .doc(targetUid)
        .collection(_likesSubcollection)
        .orderBy('likedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['likedAt'] as Timestamp?;
        return LikerInfo(
          uid: doc.id,
          likedAt: ts?.toDate() ?? DateTime.now(),
        );
      }).toList();
    });
  }

  Future<Map<String, dynamic>?> getLikerProfile(
      String uid) async {
    try {
      final doc = await _db
          .collection(_usersCollection)
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('⚠️ getLikerProfile error: $e');
      return null;
    }
  }

  Future<void> like({
    required String targetUid,
    required String myUid,
  }) async {
    if (targetUid == myUid) return;

    final likeRef = _db
        .collection(_usersCollection)
        .doc(targetUid)
        .collection(_likesSubcollection)
        .doc(myUid);

    final profileRef =
    _db.collection(_usersCollection).doc(targetUid);

    final existing = await likeRef.get();
    if (existing.exists) return;

    final batch = _db.batch();

    batch.set(likeRef, {
      'likedAt': FieldValue.serverTimestamp(),
      'likerUid': myUid,
    });

    batch.set(
      profileRef,
      {'likeCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    await batch.commit();
    debugPrint('❤️ Liked: $targetUid by $myUid');
  }

  Future<void> unlike({
    required String targetUid,
    required String myUid,
  }) async {
    final likeRef = _db
        .collection(_usersCollection)
        .doc(targetUid)
        .collection(_likesSubcollection)
        .doc(myUid);

    final profileRef =
    _db.collection(_usersCollection).doc(targetUid);

    final existing = await likeRef.get();
    if (!existing.exists) return;

    final batch = _db.batch();
    batch.delete(likeRef);
    batch.set(
      profileRef,
      {'likeCount': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );

    await batch.commit();
    debugPrint('💔 Unliked: $targetUid by $myUid');
  }

  Future<bool> toggleLike({
    required String targetUid,
    required String myUid,
  }) async {
    if (targetUid == myUid) return false;

    final likeRef = _db
        .collection(_usersCollection)
        .doc(targetUid)
        .collection(_likesSubcollection)
        .doc(myUid);

    final existing = await likeRef.get();
    final isCurrentlyLiked = existing.exists;

    if (isCurrentlyLiked) {
      await unlike(targetUid: targetUid, myUid: myUid);
      return false;
    } else {
      await like(targetUid: targetUid, myUid: myUid);
      return true;
    }
  }

  Future<List<String>> getWhoLiked({
    required String targetUid,
    int limit = 20,
  }) async {
    try {
      final snap = await _db
          .collection(_usersCollection)
          .doc(targetUid)
          .collection(_likesSubcollection)
          .orderBy('likedAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('⚠️ getWhoLiked error: $e');
      return [];
    }
  }
}