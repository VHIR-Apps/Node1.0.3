// lib/screens/splash_screen.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../config/app_config.dart';
import '../main.dart';
import '../services/ad_service.dart';
import '../services/badge_service.dart';
import '../services/database_service.dart';
import '../services/force_update_service.dart';
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
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _textFadeController;
  late AnimationController _progressController;
  late AnimationController _shineController;
  late AnimationController _particleController;
  late AnimationController _ringController;

  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _shineAnim;
  late Animation<double> _ringRotation;

  String _loadingText = 'Preparing...';
  double _loadingProgress = 0.0;
  bool _hasNavigated = false;
  int _initStep = 0;
  final int _totalSteps = 5;

  // ── KEY FIX: track if launched by alarm ──
  bool _isAlarmLaunch = false;

  static const List<Map<String, String>> _loadingSteps = [
    {'text': 'Loading preferences...', 'emoji': '⚙️'},
    {'text': 'Loading your habits...', 'emoji': '📋'},
    {'text': 'Preparing badges...', 'emoji': '🏆'},
    {'text': 'Connecting services...', 'emoji': '🔗'},
    {'text': 'Almost ready!', 'emoji': '✨'},
  ];

  @override
  void initState() {
    super.initState();

    FlutterNativeSplash.remove();

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

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textFadeController.forward();
    });

    _initializeApp();
  }

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();

    try {
      // ── CRITICAL: Check alarm launch FIRST before anything else ──
      // If launched from alarm notification, skip welcome sound + go directly
      _isAlarmLaunch = await _checkIsAlarmLaunch();

      if (_isAlarmLaunch) {
        debugPrint('🔔 Splash: Alarm launch detected — skipping welcome');
        // Still init services fast but skip sounds
        await _fastInitForAlarmLaunch();
        return;
      }

      // Normal launch flow
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
        SoundService.setSoundEnabled(
          DatabaseService.areSoundEffectsEnabled(),
        );
      } catch (_) {}

      _updateProgress(0.20);

      _updateStep(1);
      await Future.delayed(const Duration(milliseconds: 160));
      _updateProgress(0.40);

      _updateStep(2);
      try {
        await BadgeService.init();
      } catch (e) {
        debugPrint('⚠️ Badge init error: $e');
      }
      _updateProgress(0.62);

      _updateStep(3);
      await Future.wait([
        _initNotificationsBestEffort(),
        _initAdsBestEffort(),
        _initPurchasesBestEffort(),
      ]);
      _updateProgress(0.86);

      _updateStep(4);
      await Future.delayed(const Duration(milliseconds: 200));
      _updateProgress(1.0);

      // ── Welcome sound ONLY for normal (non-alarm) launch ──
      if (!DatabaseService.isFirstLaunch() && !_isAlarmLaunch) {
        try {
          SoundService.playWelcome();
        } catch (_) {}
      }

      final elapsed = stopwatch.elapsedMilliseconds;
      final remaining = AppConfig.minSplashDuration - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      if (!mounted || _hasNavigated) return;

      await _forceUpdateCheckBestEffort();

      if (!mounted || _hasNavigated) return;

      _goNext();
    } catch (e) {
      debugPrint('❌ Splash init error: $e');
      _updateLoading('Ready!');
      _updateProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 450));
      if (mounted && !_hasNavigated) _goNext();
    } finally {
      stopwatch.stop();
    }
  }

  // ─────────────────────────────────────────────
  // ALARM LAUNCH DETECTION
  // ─────────────────────────────────────────────

  /// Returns true if app was launched by alarm notification tap.
  /// Does NOT navigate here — lets main.dart handle alarm navigation.
  Future<bool> _checkIsAlarmLaunch() async {
    try {
      final payload = await NotificationService.getInitialPayload();
      if (payload != null && payload.startsWith('alarm:')) {
        debugPrint('🔔 Splash: alarm payload detected: $payload');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Alarm launch check error: $e');
    }
    return false;
  }

  /// Fast minimal init for alarm launch.
  /// No welcome sound, no long splash, just init services and wait.
  Future<void> _fastInitForAlarmLaunch() async {
    try {
      _updateLoading('⏰ Alarm...');
      _updateProgress(0.5);

      try {
        SoundService.setSoundEnabled(
          DatabaseService.areSoundEffectsEnabled(),
        );
      } catch (_) {}

      try {
        await BadgeService.init();
      } catch (_) {}

      _updateProgress(1.0);

      // Small delay for navigator to be ready
      // main.dart will handle opening alarm screen
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted || _hasNavigated) return;

      // Go to dashboard silently — alarm screen will overlay on top
      // via main.dart _openAlarmScreen()
      _goNextSilent();
    } catch (e) {
      debugPrint('❌ Fast alarm init error: $e');
      if (mounted && !_hasNavigated) _goNextSilent();
    }
  }

  /// Navigate to Dashboard without sound/animation — alarm screen overlays on top.
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

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  Future<void> _forceUpdateCheckBestEffort() async {
    try {
      final updateInfo = await ForceUpdateService.checkForUpdate();

      if (updateInfo != null && mounted && !_hasNavigated) {
        final isBlocking = updateInfo['isBlocking'] as bool? ?? false;

        debugPrint('🔔 Update available! Blocking: $isBlocking');

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
    final data =
    _loadingSteps[step.clamp(0, _loadingSteps.length - 1)];
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
        pageBuilder: (_, __, ___) => isFirstTime
            ? const OnboardingScreen()
            : const DashboardScreen(),
        transitionDuration: const Duration(milliseconds: 700),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity:
            CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutCubic,
                ),
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
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF7C73FF),
              Color(0xFF6C63FF),
              Color(0xFF3F37C9),
              Color(0xFF1A1055),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ..._buildFloatingCircles(screenHeight, screenWidth),
            _buildAnimatedParticles(screenHeight, screenWidth),
            _buildRotatingRing(screenHeight),

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
                            Colors.white
                                .withOpacity(0.1 * _pulseAnim.value),
                            Colors.white.withOpacity(0.02),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

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
                            _buildTagline(),
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

  Widget _buildLogoWithShine() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
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
                        color: Colors.white
                            .withOpacity(0.15 * _pulseAnim.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: AppConfig.primaryColor
                            .withOpacity(0.3 * _pulseAnim.value),
                        blurRadius: 60,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                );
              },
            ),
            Hero(
              tag: 'app_logo',
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
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
                          color: Colors.white,
                          child: const Icon(
                            Icons.track_changes_rounded,
                            size: 70,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.4),
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

  Widget _buildAppName() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.white,
                Color(0xFFFFD700),
                Colors.white,
              ],
              stops: [
                (_shineAnim.value - 0.2).clamp(0.0, 1.0),
                _shineAnim.value.clamp(0.0, 1.0),
                (_shineAnim.value + 0.2).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: const Text(
            AppConfig.appName,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            AppConfig.appTagline,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 60),
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withOpacity(0.1),
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
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00E676),
                          Color(0xFF69F0AE),
                          Color(0xFFFFD700),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676).withOpacity(0.5),
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
                    ? Colors.white
                    .withOpacity(isCurrent ? 1.0 : 0.6)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isCurrent
                    ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            _loadingText,
            key: ValueKey(_loadingText),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(_loadingProgress * 100).toInt()}%',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.04),
                    width: 2,
                  ),
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
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
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
                            color: const Color(0xFFFFD700)
                                .withOpacity(0.4),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700)
                                    .withOpacity(0.3),
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

  Widget _buildAnimatedParticles(double height, double width) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(width, height),
          painter: _SplashParticlePainter(
            progress: _particleController.value,
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!DatabaseService.isFirstLaunch()) _buildQuickStats(),
        const SizedBox(height: 16),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: Text(
            'v${AppConfig.version}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
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
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ).createShader(bounds);
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
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _quickStat('📋', '$totalHabits', 'Habits'),
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withOpacity(0.1),
          ),
          _quickStat('🔥', '$bestStreak', 'Streak'),
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withOpacity(0.1),
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
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFloatingCircles(double height, double width) {
    final rng = Random(42);
    return List.generate(15, (i) {
      final size = 20.0 + rng.nextDouble() * 160;
      final top = rng.nextDouble() * height;
      final left = rng.nextDouble() * width;
      final alpha = 0.02 + rng.nextDouble() * 0.05;
      final delay = 800 + (i * 300);

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
                        Colors.white.withOpacity(alpha),
                        Colors.white.withOpacity(alpha * 0.3),
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

class _SplashParticlePainter extends CustomPainter {
  final double progress;
  _SplashParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(99);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 25; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final radius = 1.0 + rng.nextDouble() * 2.5;
      final speed = 0.5 + rng.nextDouble() * 1.5;
      final phase = rng.nextDouble() * pi * 2;

      final x = baseX + sin(progress * pi * 2 * speed + phase) * 20;
      final y = baseY + cos(progress * pi * 2 * speed + phase) * 15;

      final opacity =
      (0.1 + sin(progress * pi * 2 + phase) * 0.1).clamp(0.0, 0.25);

      paint.color = [
        Colors.white,
        const Color(0xFFFFD700),
        const Color(0xFF00E676),
      ][i % 3]
          .withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}