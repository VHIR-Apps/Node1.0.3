// lib/screens/force_update_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/force_update_service.dart';

// যদি SoundService থাকে তবে আনকমেন্ট করে নিন
// import '../services/sound_service.dart';

class ForceUpdateDialog {
  static void show(BuildContext context, Map<String, dynamic> updateInfo) {
    final isBlocking = updateInfo['isBlocking'] as bool? ?? false;

    showDialog(
      context: context,
      barrierDismissible: !isBlocking,
      barrierColor: Colors.black.withOpacity(0.75), // Background একটু ডার্ক
      builder: (context) => PopScope(
        canPop: !isBlocking,
        child: _UpdateDialogContent(updateInfo: updateInfo),
      ),
    );
  }
}

class _UpdateDialogContent extends StatefulWidget {
  final Map<String, dynamic> updateInfo;
  const _UpdateDialogContent({required this.updateInfo});

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final isBlocking = info['isBlocking'] as bool? ?? false;
    final title = info['title'] as String? ?? 'Update Available';
    final message = info['message'] as String? ?? 'A new version is ready to install.';
    final latestVersion = info['latestVersion'] as String? ?? '';
    final features = (info['features'] as List<dynamic>?) ?? [];
    final updateUrl = info['updateUrl'] as String? ?? '';

    return SlideTransition(
      position: _slideAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151C2F).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(title, latestVersion),
                      if (message.isNotEmpty) _buildMessage(message),
                      if (features.isNotEmpty) _buildFeatures(features),
                      const SizedBox(height: 28),
                      _buildUpdateButton(context, updateUrl),
                      if (!isBlocking) _buildSkipButton(context),
                      if (isBlocking) const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── UI Helper Widgets ────────────────────────────

  Widget _buildHeader(String title, String version) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Ring
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConfig.primaryColor.withOpacity(0.15),
                ),
              ),
              // Inner Icon Container
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.5 + (value * 0.5),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4338CA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppConfig.primaryColor.withOpacity(0.5 * value),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (version.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConfig.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                'v$version',
                style: const TextStyle(
                  color: AppConfig.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 14,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFeatures(List<dynamic> features) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppConfig.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppConfig.accentColor,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "What's New",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: AppConfig.successColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppConfig.successColor.withOpacity(0.5),
                          blurRadius: 4,
                        )
                      ]
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature.toString(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildUpdateButton(BuildContext context, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleUpdate(context, url),
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Update Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: TextButton(
        onPressed: () => _handleSkip(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          overlayColor: Colors.white.withOpacity(0.1),
        ),
        child: Text(
          'Not Now',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────

  void _handleUpdate(BuildContext context, String url) async {
    HapticFeedback.mediumImpact();
    // SoundService.playTap(); // আনকমেন্ট করতে পারেন

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await ForceUpdateService.clearSkipTimestamp();
      } else {
        _showError(context, 'Cannot open update link');
      }
    } catch (e) {
      _showError(context, 'Error: $e');
    }
  }

  void _handleSkip(BuildContext context) {
    HapticFeedback.lightImpact();
    // SoundService.playTap();

    // একবার স্কিপ করলে এটা লোকাল স্টোরেজে সময় সেভ করে রাখবে
    // যাতে আগামী ২৪/৪৮ ঘণ্টা আর ডিস্টার্ব না করে।
    ForceUpdateService.saveSkipTimestamp();
    Navigator.of(context).pop();
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppConfig.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}