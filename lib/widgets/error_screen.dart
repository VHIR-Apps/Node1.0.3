// lib/widgets/error_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';

/// Professional error screen widget
/// Shows user-friendly error messages instead of raw stack traces
class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? errorCode;
  final VoidCallback? onRetry;
  final VoidCallback? onGoBack;
  final bool showBackButton;
  final bool showRetryButton;
  final String? customIcon;

  const ErrorScreen({
    Key? key,
    required this.title,
    required this.message,
    this.errorCode,
    this.onRetry,
    this.onGoBack,
    this.showBackButton = true,
    this.showRetryButton = true,
    this.customIcon,
  }) : super(key: key);

  /// Factory constructor for common error types
  factory ErrorScreen.network({VoidCallback? onRetry}) {
    final info = AppConfig.getErrorInfo('network');
    return ErrorScreen(
      title: info['title']!,
      message: info['message']!,
      errorCode: 'NETWORK_ERROR',
      customIcon: info['icon'],
      onRetry: onRetry,
    );
  }

  factory ErrorScreen.database({VoidCallback? onRetry}) {
    final info = AppConfig.getErrorInfo('database');
    return ErrorScreen(
      title: info['title']!,
      message: info['message']!,
      errorCode: 'DATABASE_ERROR',
      customIcon: info['icon'],
      onRetry: onRetry,
    );
  }

  factory ErrorScreen.server({VoidCallback? onRetry}) {
    final info = AppConfig.getErrorInfo('server');
    return ErrorScreen(
      title: info['title']!,
      message: info['message']!,
      errorCode: 'SERVER_ERROR',
      customIcon: info['icon'],
      onRetry: onRetry,
    );
  }

  factory ErrorScreen.unknown({VoidCallback? onRetry}) {
    final info = AppConfig.getErrorInfo('unknown');
    return ErrorScreen(
      title: info['title']!,
      message: info['message']!,
      errorCode: 'UNKNOWN_ERROR',
      customIcon: info['icon'],
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon/Emoji
                _buildErrorIcon(),
                const SizedBox(height: 32),

                // Error Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Error Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Error Code (if provided)
                if (errorCode != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      'Error Code: $errorCode',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),

                // Action Buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    if (customIcon != null && customIcon!.isNotEmpty) {
      // Show emoji icon
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppConfig.primaryColor.withOpacity(0.1),
              AppConfig.primaryColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: AppConfig.primaryColor.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            customIcon!,
            style: const TextStyle(fontSize: 56),
          ),
        ),
      );
    }

    // Default error icon
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppConfig.errorColor.withOpacity(0.2),
            AppConfig.errorColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppConfig.errorColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.error_outline_rounded,
        size: 64,
        color: AppConfig.errorColor.withOpacity(0.8),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Retry Button
        if (showRetryButton && onRetry != null)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onRetry!();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Back Button
        if (showBackButton) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                if (onGoBack != null) {
                  onGoBack!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Go Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Inline error widget for smaller error displays
class InlineErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final double height;

  const InlineErrorWidget({
    Key? key,
    required this.message,
    this.onRetry,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppConfig.errorColor.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: AppConfig.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading error fallback widget
class LoadingErrorWidget extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const LoadingErrorWidget({
    Key? key,
    this.errorMessage,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppConfig.errorColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppConfig.errorColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            errorMessage ?? 'Failed to load',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}