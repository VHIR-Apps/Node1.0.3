// lib/services/auth_service.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthServiceException implements Exception {
  final String message;
  final Object? cause;

  const AuthServiceException(this.message, {this.cause});

  @override
  String toString() => 'AuthServiceException: $message';
}

class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient(this._headersProvider) : _inner = http.Client();

  final http.Client _inner;
  final Future<Map<String, String>> Function() _headersProvider;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _headersProvider();
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

class AuthService {
  AuthService._internal() {
    googleUserNotifier.value = _google.currentUser;
    googleDriveUserNotifier.value = _google.currentUser;
    firebaseUserNotifier.value = _auth.currentUser;

    _googleSub = _google.onCurrentUserChanged.listen((acct) {
      googleUserNotifier.value = acct;
      googleDriveUserNotifier.value = acct;
    });

    _firebaseSub = _auth.authStateChanges().listen((user) {
      firebaseUserNotifier.value = user;
    });
  }

  static final AuthService instance = AuthService._internal();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _webClientIdEnv = String.fromEnvironment(
    'HABITNODE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  String? get _webClientIdOrNull {
    final t = _webClientIdEnv.trim();
    return t.isEmpty ? null : t;
  }

  static const List<String> _baseScopes = <String>[
    'email',
    'profile',
  ];

  static const String _driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  late final GoogleSignIn _google = GoogleSignIn(
    serverClientId: _webClientIdOrNull,
    scopes: _baseScopes,
  );

  final ValueNotifier<GoogleSignInAccount?> googleUserNotifier =
  ValueNotifier<GoogleSignInAccount?>(null);

  final ValueNotifier<GoogleSignInAccount?> googleDriveUserNotifier =
  ValueNotifier<GoogleSignInAccount?>(null);

  final ValueNotifier<User?> firebaseUserNotifier =
  ValueNotifier<User?>(_auth.currentUser);

  StreamSubscription<GoogleSignInAccount?>? _googleSub;
  StreamSubscription<User?>? _firebaseSub;

  Completer<void>? _interactiveGate;
  Completer<User?>? _firebaseEnsureCompleter;
  Completer<GoogleSignInAccount?>? _googleEnsureCompleter;

  GoogleSignInAccount? get currentGoogleUser => googleUserNotifier.value;

  GoogleSignInAccount? get currentGoogleDriveUser =>
      googleDriveUserNotifier.value;

  User? get currentFirebaseUser => firebaseUserNotifier.value;

  User? get currentUser => firebaseUserNotifier.value;

  ValueNotifier<User?> get userNotifier => firebaseUserNotifier;

  bool get isFirebaseSignedIn => currentFirebaseUser != null;

  bool get isGoogleSignedIn => currentGoogleUser != null;

  bool get isSignedIn => isFirebaseSignedIn;

  String? get uid => currentFirebaseUser?.uid;

  String? get email => currentGoogleUser?.email ?? currentFirebaseUser?.email;

  String? get displayName =>
      currentGoogleUser?.displayName ?? currentFirebaseUser?.displayName;

  String? get photoURL =>
      currentGoogleUser?.photoUrl ?? currentFirebaseUser?.photoURL;

  Future<T> _runExclusiveInteractive<T>(Future<T> Function() action) async {
    final gate = _interactiveGate;
    if (gate != null) {
      try {
        await gate.future;
      } catch (_) {}
    }

    final myGate = Completer<void>();
    _interactiveGate = myGate;

    try {
      return await action();
    } finally {
      if (!myGate.isCompleted) myGate.complete();
      if (identical(_interactiveGate, myGate)) _interactiveGate = null;
    }
  }

  Future<void> signIn() async {
    await ensureSignedInOnDemand(interactive: true);
  }

  Future<User?> ensureSignedInOnDemand({required bool interactive}) async {
    if (isFirebaseSignedIn) {
      return currentUser;
    }

    if (_firebaseEnsureCompleter != null) {
      return _firebaseEnsureCompleter!.future;
    }

    final completer = Completer<User?>();
    _firebaseEnsureCompleter = completer;

    try {
      final acct = await ensureGoogleSignedInOnDemand(interactive: interactive);
      if (acct == null) {
        completer.complete(null);
        return null;
      }

      final user = await _signInFirebaseWithGoogleAccount(acct);

      completer.complete(user);
      return user;
    } catch (e) {
      final ex = _mapError(e);
      if (!completer.isCompleted) completer.completeError(ex);
      throw ex;
    } finally {
      _firebaseEnsureCompleter = null;
    }
  }

  Future<GoogleSignInAccount?> ensureGoogleSignedInOnDemand({
    required bool interactive,
    bool forceConsent = false,
    bool forceRefresh = false,
  }) async {
    // If caller explicitly wants a fresh/consent session, we sign out/disconnect
    // BEFORE attempting sign-in again. This is user-driven only (backup/restore).
    if (forceConsent || forceRefresh) {
      // If not interactive, we cannot ask for consent/account chooser.
      if (!interactive) return _google.currentUser;

      await _runExclusiveInteractive<void>(() async {
        try {
          if (forceConsent) {
            // disconnect revokes previous grants (best effort)
            await _google.disconnect();
          } else {
            await _google.signOut();
          }
        } catch (_) {}

        googleUserNotifier.value = null;
        googleDriveUserNotifier.value = null;
      });
    }

    final existing = googleUserNotifier.value ?? _google.currentUser;
    if (existing != null) {
      googleUserNotifier.value = existing;
      googleDriveUserNotifier.value = existing;
      return existing;
    }

    if (_googleEnsureCompleter != null) {
      return _googleEnsureCompleter!.future;
    }

    final completer = Completer<GoogleSignInAccount?>();
    _googleEnsureCompleter = completer;

    try {
      // Silent first (no UI)
      try {
        final silent = await _google.signInSilently();
        if (silent != null) {
          googleUserNotifier.value = silent;
          googleDriveUserNotifier.value = silent;
          completer.complete(silent);
          return silent;
        }
      } catch (e) {
        debugPrint('Auth: Google silent sign-in failed: $e');
      }

      if (!interactive) {
        completer.complete(null);
        return null;
      }

      final acct = await _runExclusiveInteractive<GoogleSignInAccount?>(() async {
        return _google.signIn();
      });

      if (acct == null) {
        completer.complete(null);
        return null;
      }

      googleUserNotifier.value = acct;
      googleDriveUserNotifier.value = acct;
      completer.complete(acct);
      return acct;
    } on PlatformException catch (e) {
      final ex = AuthServiceException(_handlePlatformError(e), cause: e);
      completer.completeError(ex);
      throw ex;
    } catch (e) {
      final ex = _mapError(e);
      completer.completeError(ex);
      throw ex;
    } finally {
      _googleEnsureCompleter = null;
    }
  }

  Future<User> _signInFirebaseWithGoogleAccount(GoogleSignInAccount acct) async {
    try {
      final auth = await _getGoogleAuthWithRetry(acct);

      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      final hasIdToken = (idToken?.trim().isNotEmpty ?? false);
      final hasAccessToken = (accessToken?.trim().isNotEmpty ?? false);

      if (!hasIdToken && !hasAccessToken) {
        throw AuthServiceException(
          kReleaseMode
              ? _releaseFriendlyUnavailableMessage()
              : 'Failed to get Google security tokens.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: hasIdToken ? idToken : null,
        accessToken: hasAccessToken ? accessToken : null,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user == null) {
        throw const AuthServiceException('Sign-in failed. Please try again.');
      }

      try {
        await user.getIdToken(true);
      } catch (_) {}

      firebaseUserNotifier.value = user;
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_handleFirebaseAuthError(e), cause: e);
    } on PlatformException catch (e) {
      throw AuthServiceException(_handlePlatformError(e), cause: e);
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> signInForDrive() async {
    final acct = await ensureGoogleSignedInOnDemand(interactive: true);
    if (acct == null) {
      throw AuthServiceException(
        kReleaseMode
            ? 'Sign-in was not completed. You can continue without signing in.'
            : 'Sign-in was cancelled.',
      );
    }

    await _ensureDriveScopeGrantedOnDemand(
      interactive: true,
      forceConsent: false,
    );
  }

  Future<GoogleSignInAccount?> ensureDriveSignedInOnDemand({
    required bool interactive,
  }) async {
    return ensureGoogleSignedInOnDemand(interactive: interactive);
  }

  Future<void> _ensureDriveScopeGrantedOnDemand({
    required bool interactive,
    required bool forceConsent,
  }) async {
    final ok = await _runExclusiveInteractive<bool>(() async {
      return _google.requestScopes(<String>[_driveAppDataScope]);
    });

    if (ok) return;

    // If permission was denied, we can optionally "repair" by disconnecting the
    // Google session and asking again. This is still user-driven because this
    // method is only called from backup/restore actions.
    if (forceConsent && interactive) {
      await _runExclusiveInteractive<void>(() async {
        try {
          await _google.disconnect();
        } catch (_) {}

        googleUserNotifier.value = null;
        googleDriveUserNotifier.value = null;
      });

      final acct = await ensureGoogleSignedInOnDemand(
        interactive: true,
        forceConsent: false,
        forceRefresh: true,
      );

      if (acct == null) {
        throw const AuthServiceException(
          'Sign-in was cancelled.',
        );
      }

      final ok2 = await _runExclusiveInteractive<bool>(() async {
        return _google.requestScopes(<String>[_driveAppDataScope]);
      });

      if (ok2) return;
    }

    throw const AuthServiceException(
      'Google Drive permission was not granted.\n\n'
          'Fix:\n'
          '1) Try again and tap "Allow"\n'
          '2) If it still fails: Disconnect access, then sign in again',
    );
  }

  /// Returns an authenticated HTTP client for Google Drive appDataFolder operations.
  ///
  /// Params:
  /// - interactive: if false, we do not show UI; if not already signed in, returns error.
  /// - forceConsent: best-effort revoke + re-consent (use after a 403 insufficientPermissions).
  /// - forceRefresh: best-effort new token/session (use after a 401).
  ///
  /// POLICY: this should only be called from a user action (backup/restore button).
  Future<http.BaseClient> getAuthenticatedClient({
    bool interactive = true,
    bool forceConsent = false,
    bool forceRefresh = false,
  }) async {
    // Force refresh/consent only when caller requests (e.g., after a failure).
    final acct = await ensureGoogleSignedInOnDemand(
      interactive: interactive,
      forceConsent: forceConsent,
      forceRefresh: forceRefresh,
    );

    if (acct == null) {
      throw const AuthServiceException(
        'Sign-in is required for cloud backup. Please sign in first.',
      );
    }

    await _ensureDriveScopeGrantedOnDemand(
      interactive: interactive,
      forceConsent: forceConsent,
    );

    return AuthenticatedHttpClient(() async {
      try {
        return await acct.authHeaders;
      } catch (e) {
        debugPrint('Auth: authHeaders failed, retrying with re-auth. Error: $e');

        // Best-effort repair: sign out Google, then sign in again.
        await _safeGoogleSignOut();
        googleUserNotifier.value = null;
        googleDriveUserNotifier.value = null;

        final retry = await ensureGoogleSignedInOnDemand(interactive: true);
        if (retry == null) {
          throw const AuthServiceException(
            'Sign-in is required for cloud backup. Please sign in first.',
          );
        }

        await _ensureDriveScopeGrantedOnDemand(
          interactive: true,
          forceConsent: true,
        );

        return retry.authHeaders;
      }
    });
  }

  Future<void> signOut() async {
    await Future.wait<void>(<Future<void>>[
      signOutFirebaseOnly(),
      signOutDriveOnly(),
    ]);
  }

  Future<void> signOutFirebaseOnly() async {
    try {
      await _auth.signOut();
    } catch (_) {}

    // NOTE: This also signs out Google because this app currently uses a single
    // GoogleSignIn session for both FirebaseAuth and Drive backup.
    await _safeGoogleSignOut();

    firebaseUserNotifier.value = null;
    googleUserNotifier.value = null;
    googleDriveUserNotifier.value = null;
  }

  Future<void> signOutDriveOnly() async {
    await _safeGoogleSignOut();
    googleDriveUserNotifier.value = null;
  }

  Future<void> disconnect() async {
    await Future.wait<void>(<Future<void>>[
      disconnectFirebaseOnly(),
      disconnectDriveOnly(),
    ]);
  }

  Future<void> disconnectFirebaseOnly() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await _google.disconnect();
    } catch (_) {}

    firebaseUserNotifier.value = null;
    googleUserNotifier.value = null;
    googleDriveUserNotifier.value = null;
  }

  Future<void> disconnectDriveOnly() async {
    try {
      await _google.disconnect();
    } catch (_) {}

    googleDriveUserNotifier.value = null;
    googleUserNotifier.value = null;
  }

  Future<void> _safeGoogleSignOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
  }

  Future<GoogleSignInAuthentication> _getGoogleAuthWithRetry(
      GoogleSignInAccount account,
      ) async {
    const int maxRetries = 3;
    Object? lastError;

    for (int i = 0; i < maxRetries; i++) {
      try {
        final auth = await account.authentication;

        final hasAnyToken = (auth.idToken?.trim().isNotEmpty ?? false) ||
            (auth.accessToken?.trim().isNotEmpty ?? false);

        if (hasAnyToken) return auth;

        await Future.delayed(Duration(milliseconds: 250 * (i + 1)));
      } catch (e) {
        lastError = e;
        await Future.delayed(Duration(milliseconds: 250 * (i + 1)));
      }
    }

    throw AuthServiceException(
      kReleaseMode
          ? _releaseFriendlyUnavailableMessage()
          : 'Failed to get Google authentication tokens.',
      cause: lastError,
    );
  }

  String _releaseFriendlyUnavailableMessage() {
    return 'Google sign-in is temporarily unavailable right now.\n\n'
        'You can continue using HabitNode without signing in.\n\n'
        'Please try again later or install the latest update when available.';
  }

  bool _looksLikeDeveloperConfigError(String rawLower) {
    return rawLower.contains('apiexception: 10') ||
        rawLower.contains('developer configuration error') ||
        rawLower.contains('developer_error') ||
        rawLower.contains('statuscode=10') ||
        rawLower.contains('12500');
  }

  String _handlePlatformError(PlatformException e) {
    final code = e.code.toLowerCase().trim();
    final raw = e.toString().toLowerCase();

    if (code == 'sign_in_canceled' || code == 'sign_in_cancelled') {
      return kReleaseMode
          ? 'Sign-in was not completed. You can continue without signing in.'
          : 'Sign-in was cancelled.';
    }

    if (code == 'network_error' || raw.contains('network')) {
      return 'No internet connection. Please try again.';
    }

    if (code == 'sign_in_failed') {
      if (_looksLikeDeveloperConfigError(raw)) {
        if (kReleaseMode) return _releaseFriendlyUnavailableMessage();

        return 'Google Sign-In configuration error.\n\n'
            'This usually indicates:\n'
            '• SHA-1/SHA-256 mismatch\n'
            '• Wrong Firebase/Google Cloud project\n'
            '• google-services.json from a different Firebase app\n\n'
            'Fix checklist:\n'
            '1) Add the correct SHA-1 and SHA-256 in Firebase Project Settings\n'
            '2) Download a new google-services.json\n'
            '3) Rebuild and reinstall the app';
      }

      return 'Sign-in failed. Please try again.';
    }

    return kReleaseMode
        ? 'Something went wrong. Please try again.'
        : 'Google error: ${e.message ?? 'Unknown error'}';
  }

  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'invalid-idp-response':
        return kReleaseMode
            ? _releaseFriendlyUnavailableMessage()
            : 'Invalid sign-in credentials.\n\n'
            'Please verify:\n'
            '• Google provider is enabled in Firebase Authentication\n'
            '• Correct SHA-1/SHA-256 are added in Firebase Project Settings\n'
            '• google-services.json matches your package name';
      case 'account-exists-with-different-credential':
        return 'This email is already used with a different sign-in method.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled for this app. Please contact support.';
      default:
        return kReleaseMode
            ? _releaseFriendlyUnavailableMessage()
            : 'Authentication failed. Please try again.';
    }
  }

  AuthServiceException _mapError(Object e) {
    if (e is AuthServiceException) return e;

    if (e is PlatformException) {
      return AuthServiceException(_handlePlatformError(e), cause: e);
    }

    if (e is FirebaseAuthException) {
      return AuthServiceException(_handleFirebaseAuthError(e), cause: e);
    }

    final raw = e.toString();
    final rawLower = raw.toLowerCase();

    if (_looksLikeDeveloperConfigError(rawLower)) {
      return AuthServiceException(
        kReleaseMode
            ? _releaseFriendlyUnavailableMessage()
            : 'Google Sign-In is not configured correctly for this build.\n\n'
            'Please verify SHA-1/SHA-256 in Firebase and rebuild the app.',
        cause: e,
      );
    }

    if (rawLower.contains('socketexception') ||
        rawLower.contains('failed host lookup') ||
        rawLower.contains('timed out')) {
      return AuthServiceException(
        'No internet connection. Please try again.',
        cause: e,
      );
    }

    return AuthServiceException('Login failed. Please try again.', cause: e);
  }

  Future<void> dispose() async {
    try {
      await _googleSub?.cancel();
    } catch (_) {}
    try {
      await _firebaseSub?.cancel();
    } catch (_) {}
  }
}