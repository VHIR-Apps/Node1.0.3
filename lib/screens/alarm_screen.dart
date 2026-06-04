// lib/screens/alarm_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/alarm_service.dart';
import '../services/lock_screen_service.dart';
import '../services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final Habit habit;

  const AlarmScreen({
    super.key,
    required this.habit,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final AnimationController _rotateController;
  late final AnimationController _shimmerController;
  late final AnimationController _entryController;

  late final Animation<double> _entryFade;
  late final Animation<double> _entryScale;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  bool _isBusy = false;

  // ✅ FIX: _alarmStarted সবসময় true ধরবো
  // ensureStopped() force stop করবে
  bool _alarmStarted = false;

  Color get _habitColor => Color(widget.habit.colorValue);

  String get _alarmText {
    final text = widget.habit.alarmDescription?.trim();
    if (text != null && text.isNotEmpty) return text;
    return 'Time to build your habit. Don\'t break the chain today.';
  }

  String get _habitTime =>
      (widget.habit.alarmTime ?? widget.habit.time ?? '--:--').trim();

  // ─────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Lock screen bypass enable
    unawaited(LockScreenService.enableForAlarm());

    // Full immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // Pulse for orb
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Ring expanding waves
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Rotating gradient
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Shimmer on title
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );

    _entryScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutBack,
      ),
    );

    _entryController.forward();

    // Live clock
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );

    // ✅ Alarm শুরু করো
    unawaited(_startAlarmSafely());
  }

  // ✅ FIX: Sound block করবে না
  Future<void> _startAlarmSafely() async {
    try {
      await AlarmService.startAlarm(habit: widget.habit);
    } catch (e) {
      debugPrint('❌ Alarm start failed: $e');
    } finally {
      // ✅ Error হলেও true — dispose এ ensureStopped চলবে
      if (mounted) setState(() => _alarmStarted = true);
    }
  }

  // ✅ FIX: সবসময় stop করবে
  Future<void> _stopAlarmSafely() async {
    try {
      await AlarmService.ensureStopped();
    } catch (e) {
      debugPrint('❌ Alarm stop failed: $e');
    } finally {
      _alarmStarted = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();

    _pulseController.dispose();
    _ringController.dispose();
    _rotateController.dispose();
    _shimmerController.dispose();
    _entryController.dispose();

    // ✅ FIX: ensureStopped — force stop
    // _isRinging check নেই, সবসময় stop করবে
    unawaited(AlarmService.ensureStopped());

    // Lock screen bypass disable
    unawaited(LockScreenService.disableAfterAlarm());

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }

  // ─────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────

  Future<void> _runAction(
      Future<void> Function() action,
      ) async {
    if (_isBusy) return;
    if (mounted) setState(() => _isBusy = true);

    try {
      // ✅ আগে alarm বন্ধ করো
      await _stopAlarmSafely();
      // তারপর action করো
      await action();
      // তারপর screen বন্ধ করো
      if (mounted) await _closeScreen();
    } catch (e) {
      debugPrint('❌ Alarm action failed: $e');
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _dismissAlarm() {
    HapticFeedback.mediumImpact();
    unawaited(
      _runAction(() async {
        await NotificationService.dismissAlarmForToday(
          widget.habit,
        );
      }),
    );
  }

  void _snoozeAlarm() {
    HapticFeedback.lightImpact();
    unawaited(
      _runAction(() async {
        await NotificationService.dismissAlarmForToday(
          widget.habit,
        );
        await NotificationService.scheduleSnoozeAlarm(
          habit: widget.habit,
          delay: const Duration(minutes: 5),
        );
      }),
    );
  }

  Future<void> _closeScreen() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    // ✅ Pop করলে আগের screen এই থাকবে
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // App kill থেকে alarm খুলেছিলে
      await SystemNavigator.pop();
    }
  }

  // ─────────────────────────────────────────────
  // FORMATTERS
  // ─────────────────────────────────────────────

  String _formatClock(DateTime time) {
    final hour =
    time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute =
    time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime time) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu',
      'Fri', 'Sat', 'Sun',
    ];
    return '${days[time.weekday - 1]}, '
        '${time.day} ${months[time.month - 1]}';
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = _habitColor;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;

    return WillPopScope(
      // ✅ Back button disable — dismiss button দিয়েই বন্ধ করতে হবে
      onWillPop: () async => false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
          Brightness.light,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF030712),
          body: Stack(
            children: [
              // ANIMATED BACKGROUND
              _buildAnimatedBackground(primary),

              // GLASSMORPHISM OVERLAY
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 40,
                    sigmaY: 40,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),

              // MAIN CONTENT
              SafeArea(
                child: FadeTransition(
                  opacity: _entryFade,
                  child: ScaleTransition(
                    scale: _entryScale,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical:
                        isSmallScreen ? 12 : 20,
                      ),
                      child: Column(
                        children: [
                          _buildTopStatus(primary),
                          SizedBox(
                              height:
                              isSmallScreen ? 16 : 24),
                          _buildLiveClock(),
                          SizedBox(
                              height:
                              isSmallScreen ? 20 : 36),
                          Expanded(
                            child: Center(
                              child: _buildPulsingOrb(
                                  primary, size),
                            ),
                          ),
                          SizedBox(
                              height:
                              isSmallScreen ? 16 : 24),
                          _buildInfoCard(primary),
                          SizedBox(
                              height:
                              isSmallScreen ? 16 : 24),
                          _buildActionButtons(primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ANIMATED BACKGROUND
  // ─────────────────────────────────────────────

  Widget _buildAnimatedBackground(Color primary) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, _) {
        final t = _rotateController.value * 2 * math.pi;
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF030712),
                    primary.withOpacity(0.18),
                    const Color(0xFF0A0E1A),
                    const Color(0xFF030712),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -100 + (math.sin(t) * 60),
              right: -100 + (math.cos(t) * 60),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withOpacity(0.3),
                      primary.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150 + (math.cos(t * 0.7) * 80),
              left: -120 + (math.sin(t * 1.3) * 70),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppConfig.primaryColor
                          .withOpacity(0.25),
                      AppConfig.primaryColor
                          .withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 250 + (math.sin(t * 1.5) * 40),
              left: 50 + (math.cos(t * 1.1) * 50),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withOpacity(0.2),
                      Colors.purple.withOpacity(0.0),
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

  // ─────────────────────────────────────────────
  // TOP STATUS
  // ─────────────────────────────────────────────

  Widget _buildTopStatus(Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, _) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [
                    primary,
                    Colors.white,
                    primary,
                  ],
                  stops: [
                    0.0,
                    _shimmerController.value,
                    1.0,
                  ],
                ).createShader(bounds);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                  Colors.white.withOpacity(0.06),
                  borderRadius:
                  BorderRadius.circular(999),
                  border: Border.all(
                    color:
                    Colors.white.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ALARM ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // LIVE CLOCK
  // ─────────────────────────────────────────────

  Widget _buildLiveClock() {
    return Column(
      children: [
        Text(
          _formatClock(_now),
          style: TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 1,
            shadows: [
              Shadow(
                color: _habitColor.withOpacity(0.5),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatDate(_now),
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // PULSING ORB
  // ─────────────────────────────────────────────

  Widget _buildPulsingOrb(Color primary, Size size) {
    final orbSize = size.width > 480 ? 240.0 : 200.0;

    return SizedBox(
      width: orbSize + 100,
      height: orbSize + 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding Wave Rings
          AnimatedBuilder(
            animation: _ringController,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(3, (i) {
                  final offset = i / 3;
                  final progress =
                      (_ringController.value + offset) %
                          1.0;
                  final scale = 0.6 + (progress * 0.8);
                  final opacity =
                      (1.0 - progress) * 0.5;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: orbSize + 60,
                      height: orbSize + 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primary
                              .withOpacity(opacity),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          // Outer Glow
          ScaleTransition(
            scale: Tween<double>(
              begin: 0.9,
              end: 1.05,
            ).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: orbSize + 40,
              height: orbSize + 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withOpacity(0.5),
                    primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.5),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // Rotating Gradient Ring
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, _) {
              return Transform.rotate(
                angle:
                _rotateController.value * 2 * math.pi,
                child: Container(
                  width: orbSize - 10,
                  height: orbSize - 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        primary.withOpacity(0.0),
                        primary.withOpacity(0.8),
                        Colors.white.withOpacity(0.9),
                        primary.withOpacity(0.8),
                        primary.withOpacity(0.0),
                      ],
                      stops: const [
                        0.0,
                        0.3,
                        0.5,
                        0.7,
                        1.0,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Inner Glass Circle
          Container(
            width: orbSize - 30,
            height: orbSize - 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10,
                  sigmaY: 10,
                ),
                child: Container(
                  color: Colors.white.withOpacity(0.05),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final scale = 1.0 +
                            (math.sin(
                                _pulseController
                                    .value *
                                    math.pi) *
                                0.08);
                        return Transform.scale(
                          scale: scale,
                          child: Text(
                            widget.habit.emoji,
                            style: TextStyle(
                              fontSize: orbSize * 0.4,
                              shadows: [
                                Shadow(
                                  color: primary
                                      .withOpacity(0.6),
                                  blurRadius: 25,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INFO CARD
  // ─────────────────────────────────────────────

  Widget _buildInfoCard(Color primary) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: primary.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [primary, Colors.white, primary],
                  ).createShader(bounds);
                },
                child: const Text(
                  'WAKE UP!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.habit.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: primary.withOpacity(0.4),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _alarmText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: _habitTime,
                    color: primary,
                  ),
                  _InfoChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '${widget.habit.currentStreak} days',
                    color: Colors.orange,
                  ),
                  if (widget.habit.bestStreak > 0)
                    _InfoChip(
                      icon: Icons.emoji_events_rounded,
                      label:
                      'Best ${widget.habit.bestStreak}',
                      color: const Color(0xFFFFD700),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────────────────

  Widget _buildActionButtons(Color primary) {
    return Column(
      children: [
        // STOP ALARM
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.6),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isBusy ? null : _dismissAlarm,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary,
                      primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: _isBusy
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'STOP ALARM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // SNOOZE
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isBusy ? null : _snoozeAlarm,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.snooze_rounded,
                      color: Colors.white.withOpacity(0.85),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'SNOOZE 5 MINUTES',
                      style: TextStyle(
                        color:
                        Colors.white.withOpacity(0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// INFO CHIP
// ─────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}