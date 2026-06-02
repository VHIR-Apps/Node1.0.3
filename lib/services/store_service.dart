import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class StoreService {
  const StoreService._();

  static Future<void> shareApp(BuildContext context) async {
    try {
      await Share.share(
        AppConfig.shareMessage,
        subject: AppConfig.appName,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Unable to share app');
    }
  }

  static Future<void> rateApp(BuildContext context) async {
    try {
      final marketUri = Uri.parse(AppConfig.playStoreRateUrl);
      final webUri = Uri.parse(AppConfig.playStoreAppUrl);

      if (await canLaunchUrl(marketUri)) {
        await launchUrl(
          marketUri,
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (!context.mounted) return;

      if (await canLaunchUrl(webUri)) {
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (!context.mounted) return;
      _showSnack(context, 'Unable to open store page');
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Unable to open store page');
    }
  }

  static Future<void> openStore(BuildContext context) async {
    try {
      final uri = Uri.parse(AppConfig.playStoreAppUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!context.mounted) return;
        _showSnack(context, 'Unable to open Play Store');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Unable to open Play Store');
    }
  }

  static Future<void> moreApps(BuildContext context) async {
    try {
      final uri = Uri.parse(AppConfig.playStoreDeveloperUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!context.mounted) return;
        _showSnack(context, 'Unable to open developer page');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Unable to open developer page');
    }
  }

  static void _showSnack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}