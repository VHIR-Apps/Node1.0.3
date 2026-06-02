// lib/widgets/force_update_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/force_update_service.dart';
import '../services/sound_service.dart';

class ForceUpdateDialog {
  // ═══════════════════════════════════════
  // 🚀 SHOW UPDATE DIALOG
  // ═══════════════════════════════════════

  static void show(
      BuildContext context,
      Map<String, dynamic> updateInfo,
      ) {
    final isBlocking = updateInfo['isBlocking'] as bool? ?? false;

    showDialog(
      context: context,
      barrierDismissible: !isBlocking,
      builder: (context) => WillPopScope(
        onWillPop: () async => !isBlocking, // Prevent back button if blocking
        child: _UpdateDialogContent(updateInfo: updateInfo),
      ),
    );
  }
}

// ═══════════════════════════════════════
// 📱 UPDATE DIALOG CONTENT
// ═══════════════════════════════════════

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBlocking = widget.updateInfo['isBlocking'] as bool? ?? false;
    final title = widget.updateInfo['title'] as String? ?? 'Update Available';
    final message = widget.updateInfo['message'] as String? ?? '';
    final latestVersion = widget.updateInfo['latestVersion'] as String? ?? '';
    final features = widget.updateInfo['features'] as List<dynamic>? ?? [];
    final updateUrl = widget.updateInfo['updateUrl'] as String? ?? '';

    return ScaleTransition(
      scale: _scaleAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1F1F3D),
                  Color(0xFF0F0F1E),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppConfig.primaryColor.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                _buildHeader(title, latestVersion),

                // Message
                if (message.isNotEmpty) _buildMessage(message),

                // Features list
                if (features.isNotEmpty) _buildFeatures(features),

                const SizedBox(height: 24),

                // Update button
                _buildUpdateButton(context, updateUrl),

                // Skip button (only if not blocking)
                if (!isBlocking) _buildSkipButton(context),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 🎨 HEADER
  // ═══════════════════════════════════════

  Widget _buildHeader(String title, String version) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.primaryColor,
                        AppConfig.primaryColor.withOpacity(0.6),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppConfig.primaryColor.withOpacity(0.4 * value),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Version badge
          if (version.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppConfig.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Version $version',
                style: TextStyle(
                  color: AppConfig.primaryColor.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // 💬 MESSAGE
  // ═══════════════════════════════════════

  Widget _buildMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ═══════════════════════════════════════
  // ✨ FEATURES LIST
  // ═══════════════════════════════════════

  Widget _buildFeatures(List<dynamic> features) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'What\'s New',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppConfig.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // 🔄 UPDATE BUTTON
  // ═══════════════════════════════════════

  Widget _buildUpdateButton(BuildContext context, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleUpdate(context, url),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppConfig.primaryColor,
                  Color(0xFF5A52E0),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppConfig.primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Update Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

  // ═══════════════════════════════════════
  // ⏭️ SKIP BUTTON
  // ═══════════════════════════════════════

  Widget _buildSkipButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: TextButton(
        onPressed: () => _handleSkip(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Maybe Later',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 🔄 HANDLE UPDATE
  // ═══════════════════════════════════════

  void _handleUpdate(BuildContext context, String url) async {
    HapticFeedback.mediumImpact();
    SoundService.playTap();

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await ForceUpdateService.clearSkipTimestamp();
      } else {
        _showError(context, 'Cannot open Play Store');
      }
    } catch (e) {
      _showError(context, 'Error: $e');
    }
  }

  // ═══════════════════════════════════════
  // ⏭️ HANDLE SKIP
  // ═══════════════════════════════════════

  void _handleSkip(BuildContext context) {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    ForceUpdateService.saveSkipTimestamp();
    Navigator.of(context).pop();
  }

  // ═══════════════════════════════════════
  // ⚠️ ERROR SNACKBAR
  // ═══════════════════════════════════════

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConfig.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}