// lib/services/admin_message_service.dart

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'sound_service.dart';

class AdminMessageService {
  static void listenForAdminMessages(BuildContext context) {
    final uid = AuthService.instance.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('admin_direct_messages')
        .where('targetUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final message = data['message'] ?? 'You have a new message from Admin.';

        // ডায়ালগ শো করানো
        _showWarningDialog(context, message, doc.id);
      }
    });
  }

  static void _showWarningDialog(BuildContext context, String message, String docId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.heavyImpact();
    SoundService.playTap(); // আপনি চাইলে এখানে ওয়ার্নিং সাউন্ড দিতে পারেন

    showDialog(
      context: context,
      barrierDismissible: false, // মেসেজ না পড়ে কাটা যাবে না
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF151C2F) : Colors.white).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppConfig.errorColor.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: AppConfig.errorColor.withOpacity(0.2), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppConfig.errorColor.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded, color: AppConfig.errorColor, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('Message from Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConfig.errorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () {
                        // মেসেজটি Read হিসেবে মার্ক করে দেওয়া
                        FirebaseFirestore.instance.collection('admin_direct_messages').doc(docId).update({'read': true});
                        Navigator.pop(context);
                      },
                      child: const Text('I Understand', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}