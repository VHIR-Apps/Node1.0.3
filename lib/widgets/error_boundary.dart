// lib/widgets/error_boundary.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'error_screen.dart';

/// Error Boundary Widget
/// Wraps widgets to catch and display errors gracefully.
///
/// Notes:
/// - This catches synchronous build/layout errors inside the subtree.
/// - Async errors should be wrapped using [AsyncErrorHandler.execute].
///
/// UI text must be English only (project rule).
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  /// Optional overrides. If null, the boundary will derive a friendly message
  /// from the actual error object.
  final String? errorTitle;
  final String? errorMessage;

  final VoidCallback? onRetry;

  /// If false, shows a compact inline error widget instead of full screen.
  final bool showErrorScreen;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
    this.showErrorScreen = true,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _hasError = false;
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _hasError = false;
      _error = null;
      _stackTrace = null;
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    debugPrint('🔥 ErrorBoundary caught: $error');
    debugPrint('📍 StackTrace: $stackTrace');

    if (!mounted) return;
    setState(() {
      _hasError = true;
      _error = error;
      _stackTrace = stackTrace;
    });
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _error = null;
      _stackTrace = null;
    });
    widget.onRetry?.call();
  }

  String _deriveTitle(Object? error) {
    if (widget.errorTitle != null && widget.errorTitle!.trim().isNotEmpty) {
      return widget.errorTitle!.trim();
    }

    final err = error;
    if (err == null) return 'Error';

    final s = err.toString();
    final lower = s.toLowerCase();

    if (lower.contains('firebase') || lower.contains('firestore')) {
      return 'Firebase Error';
    }
    if (lower.contains('platformexception') ||
        lower.contains('apiexception') ||
        lower.contains('developer_error') ||
        lower.contains('12500')) {
      return 'Google Sign-In Error';
    }
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('failed host lookup')) {
      return 'Network Error';
    }

    return 'Error';
  }

  String _deriveMessage(Object? error) {
    if (widget.errorMessage != null && widget.errorMessage!.trim().isNotEmpty) {
      return widget.errorMessage!.trim();
    }

    final err = error;
    if (err == null) {
      return 'An unexpected error occurred. Please try again.';
    }

    final raw = err.toString().trim();
    final lower = raw.toLowerCase();

    // Auth / sign-in related
    if (raw.contains('AuthServiceException:')) {
      return raw.replaceAll('AuthServiceException:', '').trim();
    }
    if (raw.contains('LeaderboardServiceException:')) {
      return raw.replaceAll('LeaderboardServiceException:', '').trim();
    }
    if (raw.contains('CloudBackupException:')) {
      return raw.replaceAll('CloudBackupException:', '').trim();
    }

    // Google Sign-In config failures
    if (lower.contains('apiexception: 10') ||
        lower.contains('developer_error') ||
        lower.contains('12500')) {
      return 'Unable to sign in. Google Sign-In is not configured correctly for this build.';
    }

    // Expired/invalid credential hints
    if (lower.contains('invalid-credential') ||
        lower.contains('invalid or expired') ||
        lower.contains('sign-in session')) {
      return 'Invalid or expired sign-in session. Please sign in again.';
    }

    // Use the app’s error info map for known categories
    final info = AsyncErrorHandler.detectErrorType(err);
    final msg = (info['message'] ?? '').trim();
    if (msg.isNotEmpty) return msg;

    // Last resort: show a trimmed error string (still user-friendly-ish)
    return raw.isEmpty ? 'An unexpected error occurred. Please try again.' : raw;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      final title = _deriveTitle(_error);
      final message = _deriveMessage(_error);

      final errorCode = (_error == null) ? 'UNKNOWN' : _error.runtimeType.toString();

      if (!widget.showErrorScreen) {
        return InlineErrorWidget(
          message: message,
          onRetry: widget.onRetry != null ? _retry : null,
        );
      }

      return ErrorScreen(
        title: title,
        message: message,
        errorCode: errorCode,
        customIcon: '⚠️',
        onRetry: widget.onRetry != null ? _retry : null,
        onGoBack: null,
        showBackButton: true,
        showRetryButton: widget.onRetry != null,
      );
    }

    return _ErrorCatcher(
      onError: _handleError,
      child: widget.child,
    );
  }
}

/// Internal widget that catches errors during build.
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final void Function(Object, StackTrace) onError;

  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (error, stackTrace) {
      debugPrint('🔥 Build error caught: $error');
      debugPrint('📍 Stack: $stackTrace');
      onError(error, stackTrace);
      return const SizedBox.shrink();
    }
  }
}

/// Async Error Handler
/// Use this to wrap async operations.
class AsyncErrorHandler {
  /// Execute async operation with error handling.
  static Future<T?> execute<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? errorTitle,
    String? errorMessage,
    bool showSnackBar = true,
    VoidCallback? onError,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      debugPrint('🔥 Async error: $error');
      debugPrint('📍 Stack: $stackTrace');

      if (context.mounted && showSnackBar) {
        _showErrorSnackBar(
          context,
          errorTitle ?? 'Error',
          errorMessage ?? error.toString(),
        );
      }

      onError?.call();
      return null;
    }
  }

  /// Show error snackbar.
  static void _showErrorSnackBar(
      BuildContext context,
      String title,
      String message,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        backgroundColor: AppConfig.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Detect error type and get appropriate message.
  static Map<String, String> detectErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('failed host lookup')) {
      return AppConfig.getErrorInfo('network');
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return AppConfig.getErrorInfo('timeout');
    }

    // Firebase errors
    if (errorString.contains('firebase') || errorString.contains('firestore')) {
      return AppConfig.getErrorInfo('firebase');
    }

    // Database errors
    if (errorString.contains('hive') ||
        errorString.contains('database') ||
        errorString.contains('box')) {
      return AppConfig.getErrorInfo('database');
    }

    // Permission errors
    if (errorString.contains('permission')) {
      return AppConfig.getErrorInfo('permission');
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('503') ||
        errorString.contains('server')) {
      return AppConfig.getErrorInfo('server');
    }

    // Ad errors
    if (errorString.contains('ad') ||
        errorString.contains('admob') ||
        errorString.contains('unity')) {
      return AppConfig.getErrorInfo('ad_load');
    }

    // Default unknown error
    return AppConfig.getErrorInfo('unknown');
  }

  /// Show smart error dialog based on error type.
  static void showSmartErrorDialog(
      BuildContext context,
      dynamic error, {
        VoidCallback? onRetry,
      }) {
    final errorInfo = detectErrorType(error);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151C2F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Text(
              errorInfo['icon'] ?? '⚠️',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                errorInfo['title'] ?? 'Error',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          errorInfo['message'] ?? 'Something went wrong.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: AppConfig.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              onRetry != null ? 'Cancel' : 'OK',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Safe Builder Widget
/// Use this instead of regular Builder to catch build errors.
class SafeBuilder extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final Widget Function(BuildContext, Object)? errorBuilder;

  const SafeBuilder({
    super.key,
    required this.builder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (error, stackTrace) {
      debugPrint('🔥 SafeBuilder error: $error');
      debugPrint('📍 Stack: $stackTrace');

      if (errorBuilder != null) {
        return errorBuilder!(context, error);
      }

      return const InlineErrorWidget(
        message: 'Unable to display content.',
        height: 100,
      );
    }
  }
}

/// Safe Future Builder
/// FutureBuilder with built-in error handling.
class SafeFutureBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final Widget? loadingWidget;
  final Widget Function(BuildContext, Object)? errorBuilder;

  const SafeFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ??
              const Center(
                child: CircularProgressIndicator(
                  color: AppConfig.primaryColor,
                ),
              );
        }

        // Error state
        if (snapshot.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(context, snapshot.error!);
          }

          final errorInfo = AsyncErrorHandler.detectErrorType(snapshot.error);
          return LoadingErrorWidget(
            errorMessage: errorInfo['message'],
            onRetry: null,
          );
        }

        // Success state
        if (snapshot.hasData) {
          try {
            return builder(context, snapshot.data as T);
          } catch (error) {
            debugPrint('🔥 SafeFutureBuilder builder error: $error');
            return const InlineErrorWidget(
              message: 'Failed to display data.',
            );
          }
        }

        // No data state
        return const InlineErrorWidget(
          message: 'No data available.',
        );
      },
    );
  }
}