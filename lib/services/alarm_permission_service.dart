// lib/services/alarm_permission_service.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmPermissionService {
  /// Request all necessary permissions for alarms (100% Google Play Policy Safe)
  static Future<bool> requestAllPermissions(BuildContext context) async {
    bool allGranted = true;

    // 1. Exact Alarm Permission (Android 12+) - কাঁটায় কাঁটায় সময়ে অ্যালার্ম বাজার জন্য
    if (await Permission.scheduleExactAlarm.isDenied) {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted) {
        allGranted = false;
        _showPermissionDialog(
          context,
          'Exact Alarm Permission',
          'This app needs permission to schedule exact alarms so your habits trigger perfectly on time.',
        );
      }
    }

    // 2. Notification Permission (Android 13+)
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        allGranted = false;
      }
    }

    // 🚀 NOTE: SYSTEM_ALERT_WINDOW (Display over other apps) Removed!
    // আমরা এখন গুগলের লিগ্যাল "Full-Screen Intent" ব্যবহার করছি,
    // তাই রিস্কি পারমিশন সরিয়ে ফেলা হলো। এতে প্লে-স্টোরে কোনো রিজেকশন আসবে না।

    return allGranted;
  }

  static void _showPermissionDialog(
      BuildContext context,
      String title,
      String message,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}