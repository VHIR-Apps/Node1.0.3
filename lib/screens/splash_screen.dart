// lib/screens/splash_screen.dart
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../config/app_config.dart';
import '../main.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/database_service.dart';
import '../services/force_update_service.dart';
import '../services/google_drive_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/sound_service.dart';
import '../widgets/force_update_dialog.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ───
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _textFadeController;
  late AnimationController _progressController;
  late AnimationController _shineController;
  late AnimationController _particleController;
  late AnimationController _ringController;
  late AnimationController _typingController;

  // ─── Animations ───
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _shineAnim;
  late Animation<double> _ringRotation;

  // ─── State ───
  String _loadingText = 'Preparing...';
  double _loadingProgress = 0.0;
  bool _hasNavigated = false;
  int _initStep = 0;
  final int _totalSteps = 6;
  bool _isAlarmLaunch = false;

  // Typing animation state
  String _displayedTagline = '';
  bool _showCursor = true;

  static bool _welcomeSoundPlayed = false;

  static const List<Map<String, String>> _loadingSteps = [
    {'text': 'Loading preferences...', 'emoji': '⚙️'},
    {'text': 'Loading your habits...', 'emoji': '📋'},
    {'text': 'Preparing badges...', 'emoji': '🏆'},
    {'text': 'Connecting services...', 'emoji': '🔗'},
    {'text': 'Syncing your data...', 'emoji': '☁️'},
    {'text': 'Almost ready!', 'emoji': '🚀'},
  ];

  // ─── Theme Colors ───
  bool get _isDarkMode {
    final brightness = MediaQuery.of(context).platformBrightness;
    final currentTheme = themeNotifier.value;
    if (currentTheme == ThemeMode.dark) return true;
    if (currentTheme == ThemeMode.light) return false;
    return brightness == Brightness.dark;
  }

  // Light mode gradient (unchanged)
  List<Color> get _lightGradient => const [
    Color(0xFF7C73FF),
    Color(0xFF6C63FF),
    Color(0xFF3F37C9),
    Color(0xFF1A1055),
  ];

  // Dark mode gradient – refined deep indigo/space
  List<Color> get _darkGradient => const [
    Color(0xFF0B0B1A),
    Color(0xFF15132B),
    Color(0xFF1E1040),
    Color(0xFF0A0A14),
  ];

  List<Color> get _gradient => _isDarkMode ? _darkGradient : _lightGradient;

  Color get _accentColor =>
      _isDarkMode ? const Color(0xFF8B80FF) : const Color(0xFF00E676);

  Color get _secondaryAccent =>
      _isDarkMode ? const Color(0xFFFFB347) : const Color(0xFFFFD700);

  Color get _textPrimary => Colors.white;

  Color get _textSecondary =>
      _isDarkMode ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.8);

  Color get _surfaceColor => _isDarkMode
      ? const Color(0x0AFFFFFF) // ultra subtle
      : Colors.white.withOpacity(0.08);

  Color get _borderColor => _isDarkMode
      ? Colors.white.withOpacity(0.08)
      : Colors.white.withOpacity(0.15);

  Color get _glowColor =>
      _isDarkMode ? const Color(0xFF8B80FF) : Colors.white;

  Color get _particleColor1 =>
      _isDarkMode ? const Color(0xFF8B80FF) : Colors.white;
  Color get _particleColor2 =>
      _isDarkMode ? const Color(0xFFFFB347) : const Color(0xFFFFD700);
  Color get _particleColor3 =>
      _isDarkMode ? const Color(0xFFC084FC) : const Color(0xFF00E676);

  List<Color> get _progressGradient => _isDarkMode
      ? const [Color(0xFF8B80FF), Color(0xFFFFB347), Color(0xFFC084FC)]
      : const [Color(0xFF00E676), Color(0xFF69F0AE), Color(0xFFFFD700)];

  Color get _progressGlow =>
      _isDarkMode ? const Color(0xFF8B80FF) : const Color(0xFF00E676);

  Color get _logoShadowColor => _isDarkMode
      ? const Color(0xFF8B80FF).withOpacity(0.25)
      : Colors.black.withOpacity(0.25);

  Color get _logoContainerColor =>
      _isDarkMode ? const Color(0xFF1C1B3B) : Colors.white;

  Color get _ringColor => _isDarkMode
      ? Colors.white.withOpacity(0.05)
      : Colors.white.withOpacity(0.04);

  Color get _ringDot1Color => _isDarkMode
      ? const Color(0xFF8B80FF).withOpacity(0.6)
      : Colors.white.withOpacity(0.3);
  Color get _ringDot2Color => _isDarkMode
      ? const Color(0xFFFFB347).withOpacity(0.6)
      : const Color(0xFFFFD700).withOpacity(0.4);

  @override
  void initState() {
    super.initState();

    FlutterNativeSplash.remove();

    _initAnimationControllers();
    _initAnimations();
    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textFadeController.forward();
        _startTypingAnimation();
      }
    });

    _initializeApp();
  }

  void _initAnimationControllers() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  void _initAnimations() {
    _fadeAnim = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0, 0.4, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _slideAnim = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _textFadeAnim = CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeIn,
    );

    _shineAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.linear),
    );

    _ringRotation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.linear),
    );
  }

  // ─── Typing Animation ───
  void _startTypingAnimation() async {
    final fullText = AppConfig.appTagline;
    // দ্রুত টাইপিং – প্রতি ক্যারেক্টার ১৫ মিলিসেকেন্ড
    const typingSpeed = Duration(milliseconds: 15);

    for (int i = 0; i <= fullText.length; i++) {
      if (!mounted || _hasNavigated) return;
      await Future.delayed(typingSpeed);
      if (mounted) {
        setState(() {
          _displayedTagline = fullText.substring(0, i);
        });
      }
    }
    // টাইপ শেষে সামান্য বিরতি দিয়ে কার্সর সরিয়ে দিন
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() => _showCursor = false);
    }
  }

  // ─── INIT ───
  Future<void> _initializeApp() async {
    try {
      _isAlarmLaunch = await _checkIsAlarmLaunch();

      if (_isAlarmLaunch) {
        debugPrint('🔔 Splash: Alarm launch — skipping welcome');
        await _fastInitForAlarmLaunch();
        return;
      }

      // Step 0: Preferences
      _updateStep(0);
      try {
        final savedTheme = DatabaseService.getThemeMode();
        switch (savedTheme) {
          case 'light':
            themeNotifier.value = ThemeMode.light;
            break;
          case 'dark':
            themeNotifier.value = ThemeMode.dark;
            break;
          default:
            themeNotifier.value = ThemeMode.system;
        }
      } catch (_) {}

      try {
        SoundService.setSoundEnabled(DatabaseService.areSoundEffectsEnabled());
      } catch (_) {}
      _updateProgress(0.16);

      // Step 1: Habits
      _updateStep(1);
      _updateProgress(0.32);

      // Step 2: Badges
      _updateStep(2);
      try {
        await BadgeService.init();
      } catch (e) {
        debugPrint('⚠️ Badge init error: $e');
      }
      _updateProgress(0.48);

      // Step 3: Services
      _updateStep(3);
      await Future.wait([
        _initNotificationsBestEffort(),
        _initAdsBestEffort(),
        _initPurchasesBestEffort(),
      ]);
      _updateProgress(0.64);

      // Step 4: Cloud Restore
      _updateStep(4);
      await _silentCloudRestoreIfNeeded();
      _updateProgress(0.82);

      // Step 5: Almost ready
      _updateStep(5);
      _updateProgress(1.0);

      // Welcome sound (once only, not on alarm/first launch)
      if (!DatabaseService.isFirstLaunch() &&
          !_isAlarmLaunch &&
          !_welcomeSoundPlayed) {
        try {
          SoundService.playWelcome();
          _welcomeSoundPlayed = true;
        } catch (_) {}
      }

      if (!mounted || _hasNavigated) return;

      await _forceUpdateCheckBestEffort();

      if (!mounted || _hasNavigated) return;

      _goNext();
    } catch (e) {
      debugPrint('❌ Splash init error: $e');
      _updateLoading('Ready!');
      _updateProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && !_hasNavigated) _goNext();
    }
  }

  // ─── CLOUD RESTORE ───
  Future<void> _silentCloudRestoreIfNeeded() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        debugPrint('☁️ Splash restore: No user signed in — skipping');
        return;
      }

      final isOnline = await _hasNetworkConnection();
      if (!isOnline) {
        debugPrint('📵 Splash restore: Offline — skipping');
        return;
      }

      final localProfile =
      DatabaseService.getLeaderboardProfileForUid(user.uid);
      final localHabits = DatabaseService.getAllHabits();

      if (localHabits.isNotEmpty && localProfile != null) {
        debugPrint(
            '✅ Splash restore: Local data exists — skipping full restore');
        return;
      }

      debugPrint('☁️ Splash restore: No local data — checking cloud...');
      _updateLoading('☁️ Checking your backup...');

      try {
        final driveService = GoogleDriveService();

        final backupInfo = await driveService
            .getExistingBackupInfoOnDemand()
            .timeout(const Duration(seconds: 8));

        if (backupInfo == null) {
          debugPrint('☁️ Splash restore: No cloud backup found');
          return;
        }

        _updateLoading('☁️ Restoring your data...');
        debugPrint('☁️ Splash restore: Backup found — restoring...');

        final result = await driveService
            .restoreAllDataFromCloudOnDemand()
            .timeout(const Duration(seconds: 30));

        debugPrint(
            '✅ Splash restore: ${result.habitsImported} habits, ${result.notesImported} notes');

        try {
          await BadgeService.checkAllBadges();
        } catch (_) {}

        _updateLoading('✅ Data restored!');
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('⚠️ Splash cloud restore failed (non-critical): $e');
      }
    } catch (e) {
      debugPrint('⚠️ Splash restore check error: $e');
    }
  }

  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── ALARM LAUNCH ───
  Future<bool> _checkIsAlarmLaunch() async {
    try {
      final payload = await NotificationService.getInitialPayload();
      if (payload != null && payload.startsWith('alarm:')) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Alarm launch check error: $e');
    }
    return false;
  }

  Future<void> _fastInitForAlarmLaunch() async {
    try {
      _updateLoading('⏰ Alarm...');
      _updateProgress(0.5);

      try {
        SoundService.setSoundEnabled(DatabaseService.areSoundEffectsEnabled());
      } catch (_) {}

      try {
        await BadgeService.init();
      } catch (_) {}

      _updateProgress(1.0);

      if (!mounted || _hasNavigated) return;
      _goNextSilent();
    } catch (e) {
      debugPrint('❌ Fast alarm init error: $e');
      if (mounted && !_hasNavigated) _goNextSilent();
    }
  }

  void _goNextSilent() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionDuration: const Duration(milliseconds: 100),
        transitionsBuilder: (_, anim, __, child) => child,
      ),
    );
  }

  // ─── HELPERS ───
  Future<void> _forceUpdateCheckBestEffort() async {
    try {
      final updateInfo = await ForceUpdateService.checkForUpdate();

      if (updateInfo != null && mounted && !_hasNavigated) {
        final isBlocking = updateInfo['isBlocking'] as bool? ?? false;

        await Future.delayed(const Duration(milliseconds: 280));
        if (!mounted || _hasNavigated) return;

        ForceUpdateDialog.show(context, updateInfo);

        if (isBlocking) {
          _hasNavigated = true;
          return;
        }

        await Future.delayed(const Duration(milliseconds: 480));
      }
    } catch (e) {
      debugPrint('⚠️ Force update check failed: $e');
    }
  }

  Future<void> _initNotificationsBestEffort() async {
    try {
      if (DatabaseService.areNotificationsEnabled()) {
        await NotificationService.rescheduleAllReminders();
        if (AppConfig.enableDailySummary) {
          await NotificationService.scheduleDailySummary();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Notification scheduling error: $e');
    }
  }

  Future<void> _initAdsBestEffort() async {
    try {
      await DatabaseService.resetSessionAdState();
    } catch (_) {}

    try {
      await AdService.initialize();
      if (AppConfig.enableAds && !DatabaseService.isProUser()) {
        AdService.loadInterstitialAd();
        AdService.loadRewardedAd();
      }
    } catch (e) {
      debugPrint('⚠️ Ads init error: $e');
    }
  }

  Future<void> _initPurchasesBestEffort() async {
    try {
      await PurchaseService.initialize();
    } catch (e) {
      debugPrint('⚠️ Purchase init error: $e');
    }
  }

  void _updateStep(int step) {
    if (!mounted || _hasNavigated) return;
    _initStep = step;
    final data = _loadingSteps[step.clamp(0, _loadingSteps.length - 1)];
    setState(() {
      _loadingText = '${data['emoji']} ${data['text']}';
    });
  }

  void _updateLoading(String text) {
    if (!mounted || _hasNavigated) return;
    setState(() => _loadingText = text);
  }

  void _updateProgress(double value) {
    if (!mounted || _hasNavigated) return;
    final v = value.clamp(0.0, 1.0);
    setState(() => _loadingProgress = v);
    _progressController.animateTo(v, curve: Curves.easeOut);
  }

  void _goNext() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    HapticFeedback.lightImpact();

    final isFirstTime = DatabaseService.isFirstLaunch();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
        isFirstTime ? const OnboardingScreen() : const DashboardScreen(),
        transitionDuration: const Duration(milliseconds: 700),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _textFadeController.dispose();
    _progressController.dispose();
    _shineController.dispose();
    _particleController.dispose();
    _ringController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating circles
            ..._buildFloatingCircles(screenHeight, screenWidth),

            // Animated particles
            _buildAnimatedParticles(screenHeight, screenWidth),

            // Rotating ring
            _buildRotatingRing(screenHeight),

            // Pulse glow behind logo
            Positioned(
              top: screenHeight * 0.26,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 260 + (_pulseAnim.value * 50),
                      height: 260 + (_pulseAnim.value * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _glowColor
                                .withOpacity(0.1 * _pulseAnim.value),
                            _glowColor.withOpacity(0.02),
                            _glowColor.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLogoWithShine(),
                            const SizedBox(height: 36),
                            _buildAppName(),
                            const SizedBox(height: 10),
                            _buildTaglineWithTyping(),
                            const SizedBox(height: 50),
                            FadeTransition(
                              opacity: _textFadeAnim,
                              child: _buildProgressSection(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom section
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _textFadeAnim,
                child: _buildBottomSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // LOGO WITH SHINE
  // ═══════════════════════════════════════════

  Widget _buildLogoWithShine() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow behind logo
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(42),
                    boxShadow: [
                      BoxShadow(
                        color: _glowColor
                            .withOpacity(0.15 * _pulseAnim.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: _accentColor
                            .withOpacity(0.3 * _pulseAnim.value),
                        blurRadius: 60,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                );
              },
            ),
            // Logo
            Hero(
              tag: 'app_logo',
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: _logoContainerColor,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: _logoShadowColor,
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                    if (_isDarkMode)
                      BoxShadow(
                        color: const Color(0xFF7C73FF).withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                  ],
                  border: _isDarkMode
                      ? Border.all(
                    color: const Color(0xFF7C73FF).withOpacity(0.3),
                    width: 1.5,
                  )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Stack(
                    children: [
                      Image.asset(
                        AppConfig.logoPath,
                        fit: BoxFit.cover,
                        width: 140,
                        height: 140,
                        errorBuilder: (_, __, ___) => Container(
                          color: _logoContainerColor,
                          child: Icon(
                            Icons.track_changes_rounded,
                            size: 70,
                            color: _isDarkMode
                                ? const Color(0xFF7C73FF)
                                : AppConfig.primaryColor,
                          ),
                        ),
                      ),
                      // Shine overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.transparent,
                                (_isDarkMode
                                    ? const Color(0xFF7C73FF)
                                    : Colors.white)
                                    .withOpacity(_isDarkMode ? 0.2 : 0.4),
                                Colors.transparent,
                              ],
                              stops: [
                                (_shineAnim.value - 0.3).clamp(0.0, 1.0),
                                _shineAnim.value.clamp(0.0, 1.0),
                                (_shineAnim.value + 0.3).clamp(0.0, 1.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // APP NAME
  // ═══════════════════════════════════════════

  Widget _buildAppName() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        final shineColors = _isDarkMode
            ? const [Color(0xFFB8B0FF), Color(0xFF00E676), Color(0xFFB8B0FF)]
            : const [Colors.white, Color(0xFFFFD700), Colors.white];

        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: shineColors,
              stops: [
                (_shineAnim.value - 0.2).clamp(0.0, 1.0),
                _shineAnim.value.clamp(0.0, 1.0),
                (_shineAnim.value + 0.2).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            AppConfig.appName,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: _isDarkMode
                      ? const Color(0xFF7C73FF).withOpacity(0.5)
                      : Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // TAGLINE WITH TYPING ANIMATION
  // ═══════════════════════════════════════════

  Widget _buildTaglineWithTyping() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: _isDarkMode
            ? [
          BoxShadow(
            color: const Color(0xFF7C73FF).withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Transform.scale(
                scale: 0.9 + (_pulseAnim.value * 0.15),
                child: Text(
                  _isDarkMode ? '🌙' : '☀️',
                  style: const TextStyle(fontSize: 16),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Typing text
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _displayedTagline,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              // Blinking cursor
              if (_showCursor)
                AnimatedBuilder(
                  animation: _typingController,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _typingController.value > 0.5 ? 1.0 : 0.0,
                      child: Text(
                        '|',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isDarkMode
                              ? const Color(0xFF7C73FF)
                              : Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PROGRESS SECTION
  // ═══════════════════════════════════════════

  Widget _buildProgressSection() {
    return Column(
      children: [
        // Progress bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 60),
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.1),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    width: constraints.maxWidth * _loadingProgress,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: _progressGradient),
                      boxShadow: [
                        BoxShadow(
                          color: _progressGlow.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Step dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalSteps, (i) {
            final isActive = i <= _initStep;
            final isCurrent = i == _initStep;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? (_isDarkMode
                    ? (isCurrent
                    ? const Color(0xFF7C73FF)
                    : const Color(0xFF7C73FF).withOpacity(0.4))
                    : Colors.white.withOpacity(isCurrent ? 1.0 : 0.6))
                    : Colors.white.withOpacity(_isDarkMode ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isCurrent
                    ? [
                  BoxShadow(
                    color: _isDarkMode
                        ? const Color(0xFF7C73FF).withOpacity(0.5)
                        : Colors.white.withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Loading text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            _loadingText,
            key: ValueKey(_loadingText),
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Percentage
        Text(
          '${(_loadingProgress * 100).toInt()}%',
          style: TextStyle(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.25)
                : Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ROTATING RING
  // ═══════════════════════════════════════════

  Widget _buildRotatingRing(double screenHeight) {
    return Positioned(
      top: screenHeight * 0.24,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _ringController,
          builder: (context, _) {
            return Transform.rotate(
              angle: _ringRotation.value,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _ringColor, width: 2),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _ringDot1Color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _ringDot1Color,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _ringDot2Color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _ringDot2Color,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ANIMATED PARTICLES
  // ═══════════════════════════════════════════

  Widget _buildAnimatedParticles(double height, double width) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(width, height),
          painter: _SplashParticlePainter(
            progress: _particleController.value,
            color1: _particleColor1,
            color2: _particleColor2,
            color3: _particleColor3,
            isDark: _isDarkMode,
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // BOTTOM SECTION
  // ═══════════════════════════════════════════

  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!DatabaseService.isFirstLaunch()) _buildQuickStats(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Text(
            'v${AppConfig.version}',
            style: TextStyle(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.5)
                  : Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CRAFTED WITH ❤️ BY ',
              style: TextStyle(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) {
                final colors = _isDarkMode
                    ? const [Color(0xFF7C73FF), Color(0xFF00E676)]
                    : const [Color(0xFFFFD700), Color(0xFFFFA500)];
                return LinearGradient(colors: colors).createShader(bounds);
              },
              child: Text(
                AppConfig.developerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // QUICK STATS
  // ═══════════════════════════════════════════

  Widget _buildQuickStats() {
    int totalHabits = 0;
    int bestStreak = 0;
    int badgeCount = 0;

    try {
      totalHabits = DatabaseService.getAllHabits().length;
      bestStreak = DatabaseService.getBestStreakTotal();
      badgeCount = BadgeService.getUnlockedCount();
    } catch (_) {}

    if (totalHabits == 0 && bestStreak == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: _isDarkMode
            ? [
          BoxShadow(
            color: const Color(0xFF7C73FF).withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _quickStat('📋', '$totalHabits', 'Habits'),
          Container(
            width: 1,
            height: 24,
            color: _isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.1),
          ),
          _quickStat('🔥', '$bestStreak', 'Streak'),
          Container(
            width: 1,
            height: 24,
            color: _isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.1),
          ),
          _quickStat('🏆', '$badgeCount', 'Badges'),
        ],
      ),
    );
  }

  Widget _quickStat(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // FLOATING CIRCLES
  // ═══════════════════════════════════════════

  List<Widget> _buildFloatingCircles(double height, double width) {
    final rng = Random(42);
    return List.generate(15, (i) {
      final size = 20.0 + rng.nextDouble() * 160;
      final top = rng.nextDouble() * height;
      final left = rng.nextDouble() * width;
      final baseAlpha = _isDarkMode ? 0.01 : 0.02;
      final alphaRange = _isDarkMode ? 0.03 : 0.05;
      final alpha = baseAlpha + rng.nextDouble() * alphaRange;
      final delay = 800 + (i * 300);

      final circleColor =
      _isDarkMode ? const Color(0xFF7C73FF) : Colors.white;

      return Positioned(
        top: top,
        left: left,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: delay + 1000),
          curve: Curves.easeOutCirc,
          builder: (context, value, child) {
            return Opacity(
              opacity: (value * alpha).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(
                  sin(value * pi * 2 + i) * 5,
                  20 * (1 - value) + cos(value * pi * 2 + i) * 3,
                ),
                child: Container(
                  width: size * value,
                  height: size * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        circleColor.withOpacity(alpha),
                        circleColor.withOpacity(alpha * 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════
// PARTICLE PAINTER
// ═══════════════════════════════════════════

class _SplashParticlePainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;
  final Color color3;
  final bool isDark;

  _SplashParticlePainter({
    required this.progress,
    required this.color1,
    required this.color2,
    required this.color3,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(99);
    final paint = Paint()..style = PaintingStyle.fill;

    final maxOpacity = isDark ? 0.15 : 0.25;

    for (int i = 0; i < 25; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final radius = 1.0 + rng.nextDouble() * 2.5;
      final speed = 0.5 + rng.nextDouble() * 1.5;
      final phase = rng.nextDouble() * pi * 2;

      final x = baseX + sin(progress * pi * 2 * speed + phase) * 20;
      final y = baseY + cos(progress * pi * 2 * speed + phase) * 15;

      final opacity =
      (0.1 + sin(progress * pi * 2 + phase) * 0.1).clamp(0.0, maxOpacity);

      paint.color = [color1, color2, color3][i % 3].withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}