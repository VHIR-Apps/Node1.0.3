// lib/screens/alarm_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/alarm_service.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ALARM SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
//
// ✅ No app open / no splash / no loading
// ✅ Auto-dismiss after countdown — screen off, back to previous state
// ✅ No DashboardScreen forced push — just Navigator.pop()
// ✅ Alarm sound via native channel (STREAM_ALARM)
// ✅ Premium UI — glassmorphism, animations
// ✅ Google Play policy safe
// ═══════════════════════════════════════════════════════════════════════════════

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
  // ── Animation Controllers ──
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _slideController;
  late AnimationController _glowController;
  late AnimationController _buttonController;
  late AnimationController _backgroundController;

  // ── Animations ──
  late Animation<double> _pulseAnim;
  late Animation<double> _ringAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _buttonScaleAnim;
  late Animation<double> _backgroundAnim;

  // ── State flags ──
  bool _isDismissing = false;
  bool _isSnoozed = false;
  bool _isClosing = false;

  // ── Countdown ──
  int _countdown = 30;
  Timer? _countdownTimer;

  // ── Alarm playback ──
  bool _alarmPlaybackStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    _initAnimations();
    _startAlarmPlaybackIfNeeded();
    _startCountdown();

    // Listen for AlarmService close signal (max cycles reached)
    AlarmService.onAlarmShouldClose = () {
      if (mounted && !_isClosing) {
        _closeScreen();
      }
    };
  }

  // ─────────────────────────────────────────────
  // ANIMATIONS
  // ─────────────────────────────────────────────

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.13).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringAnim = Tween<double>(begin: -0.035, end: 0.035).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _glowAnim = Tween<double>(begin: 0.25, end: 0.9).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _buttonScaleAnim = Tween<double>(begin: 0.985, end: 1.02).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _backgroundAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeInOut,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ALARM PLAYBACK
  // ─────────────────────────────────────────────

  Future<void> _startAlarmPlaybackIfNeeded() async {
    if (_alarmPlaybackStarted) return;
    _alarmPlaybackStarted = true;

    final alreadyActive =
        AlarmService.activeHabitId == widget.habit.id &&
            AlarmService.isAlarmActive;

    if (alreadyActive) {
      debugPrint('🔁 Alarm already active for this habit');
      return;
    }

    try {
      await AlarmService.startAlarm(widget.habit);
    } catch (e) {
      debugPrint('❌ AlarmScreen: failed to start alarm: $e');
    }
  }

  // ─────────────────────────────────────────────
  // COUNTDOWN
  // ─────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 30;

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_isDismissing || _isSnoozed || _isClosing) {
          timer.cancel();
          return;
        }

        setState(() => _countdown--);

        if (_countdown <= 0) {
          timer.cancel();
          _handleAutoSnooze();
        }
      },
    );
  }

  // ─────────────────────────────────────────────
  // CLOSE SCREEN — back to previous state, no app re-open
  // ─────────────────────────────────────────────

  /// Closes alarm screen cleanly.
  /// Does NOT push any new route — user returns to wherever they were.
  void _closeScreen() {
    if (_isClosing) return;
    _isClosing = true;

    _countdownTimer?.cancel();

    if (!mounted) return;

    Navigator.of(context).pop();

    // 🚀 LOCK SCREEN BYPASS FIX: Force app to background so lock screen restores securely!
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }

  // ─────────────────────────────────────────────
  // HANDLERS
  // ─────────────────────────────────────────────

  Future<void> _handleDismiss() async {
    if (_isDismissing || _isClosing) return;

    setState(() => _isDismissing = true);
    HapticFeedback.heavyImpact();

    try {
      await AlarmService.dismissAlarm();

      // Mark habit complete
      final habit = widget.habit;
      if (!habit.isCompletedToday()) {
        if (habit.dailyGoal > 1) {
          habit.forceComplete();
        } else {
          habit.toggleComplete();
        }
        await DatabaseService.updateHabit(habit);
      }

      // Play completion sound (non-alarm channel)
      await SoundService.playHabitComplete();

      // Small delay for completion sound
      await Future.delayed(const Duration(milliseconds: 180));
    } catch (e) {
      debugPrint('❌ Alarm dismiss error: $e');
    } finally {
      // Always close screen after dismiss — no dashboard push
      _closeScreen();
    }
  }

  Future<void> _handleSnooze() async {
    if (_isSnoozed || _isDismissing || _isClosing) return;

    setState(() => _isSnoozed = true);
    HapticFeedback.mediumImpact();

    try {
      await AlarmService.snoozeAlarm();
    } catch (e) {
      debugPrint('❌ Alarm snooze error: $e');
    } finally {
      _closeScreen();
    }
  }

  Future<void> _handleAutoSnooze() async {
    if (_isSnoozed || _isDismissing || _isClosing) return;

    setState(() => _isSnoozed = true);

    try {
      await AlarmService.snoozeAlarm();
    } catch (e) {
      debugPrint('❌ Auto-snooze error: $e');
    } finally {
      _closeScreen();
    }
  }

  Future<void> _handleSkip() async {
    if (_isClosing) return;

    HapticFeedback.lightImpact();

    try {
      await AlarmService.dismissAlarm();
    } catch (e) {
      debugPrint('❌ Skip error: $e');
    } finally {
      _closeScreen();
    }
  }

  // ─────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _countdownTimer?.cancel();

    _pulseController.dispose();
    _ringController.dispose();
    _slideController.dispose();
    _glowController.dispose();
    _buttonController.dispose();
    _backgroundController.dispose();

    // Clear close hook
    AlarmService.onAlarmShouldClose = null;

    // Fail-safe: if disposed unexpectedly while alarm still active
    final isSameHabit = AlarmService.activeHabitId == widget.habit.id;
    if (isSameHabit &&
        AlarmService.isAlarmActive &&
        !_isDismissing &&
        !_isSnoozed) {
      AlarmService.stopAlarm();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      if (AlarmService.activeHabitId == widget.habit.id) {
        AlarmService.stopAlarm();
      }
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  String _displayTime() {
    return widget.habit.alarmTime ?? widget.habit.time ?? '--:--';
  }

  Widget _buildFloatingOrb({
    required double size,
    required Alignment alignment,
    required Color color,
    required double opacity,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(opacity * 0.8),
              blurRadius: 50,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final color = Color(habit.colorValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSnooze();
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _glowController,
            _buttonController,
            _backgroundController,
          ]),
          builder: (context, _) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                    const Color(0xFF090E1A),
                    Color.lerp(
                      const Color(0xFF090E1A),
                      color,
                      0.14,
                    )!,
                    const Color(0xFF0B1020),
                  ]
                      : [
                    color.withOpacity(0.16),
                    Colors.white,
                    color.withOpacity(0.08),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // ── Background orbs ──
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Stack(
                        children: [
                          _buildFloatingOrb(
                            size: 220 + (_backgroundAnim.value * 40),
                            alignment: const Alignment(-1.1, -0.9),
                            color: color,
                            opacity: isDark ? 0.08 : 0.10,
                          ),
                          _buildFloatingOrb(
                            size: 180 + (_backgroundAnim.value * 24),
                            alignment: const Alignment(1.1, -0.4),
                            color: Colors.pinkAccent,
                            opacity: isDark ? 0.05 : 0.06,
                          ),
                          _buildFloatingOrb(
                            size: 200 + (_backgroundAnim.value * 30),
                            alignment: const Alignment(-0.9, 0.9),
                            color: Colors.orangeAccent,
                            opacity: isDark ? 0.05 : 0.06,
                          ),
                          _buildFloatingOrb(
                            size: 160 + (_backgroundAnim.value * 22),
                            alignment: const Alignment(1.0, 0.95),
                            color: color,
                            opacity: isDark ? 0.06 : 0.07,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Main content ──
                  SafeArea(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // ── Top bar ──
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 22),
                            child: Row(
                              children: [
                                // Alarm badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: color.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.notifications_active_rounded,
                                        color: color,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'HABIT ALARM',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: color,
                                          letterSpacing: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // Countdown badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _countdown <= 10
                                        ? Colors.red.withOpacity(0.14)
                                        : (isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.05)),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _countdown <= 10
                                          ? Colors.red.withOpacity(0.25)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_rounded,
                                        size: 16,
                                        color: _countdown <= 10
                                            ? Colors.red
                                            : (isDark
                                            ? Colors.white70
                                            : Colors.black54),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_countdown}s',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: _countdown <= 10
                                              ? Colors.red
                                              : (isDark
                                              ? Colors.white70
                                              : Colors.black54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Skip/close button
                                GestureDetector(
                                  onTap: _handleSkip,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 22,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 2),

                          // ── Animated emoji ring ──
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer glow ring
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: color.withOpacity(
                                        _glowAnim.value * 0.18,
                                      ),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(
                                          _glowAnim.value * 0.16,
                                        ),
                                        blurRadius: 50,
                                        spreadRadius: 14,
                                      ),
                                    ],
                                  ),
                                ),

                                // Mid ring
                                Container(
                                  width: 225,
                                  height: 225,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: color.withOpacity(0.14),
                                      width: 2.2,
                                    ),
                                  ),
                                ),

                                // Emoji circle — pulse + wobble
                                Transform.scale(
                                  scale: _pulseAnim.value,
                                  child: Transform.rotate(
                                    angle: _ringAnim.value,
                                    child: Container(
                                      width: 165,
                                      height: 165,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            color.withOpacity(0.34),
                                            color.withOpacity(0.18),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: color.withOpacity(0.38),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.24),
                                            blurRadius: 24,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          habit.emoji,
                                          style: const TextStyle(
                                            fontSize: 66,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Habit name ──
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 26),
                            child: Text(
                              habit.name,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color:
                                isDark ? Colors.white : Colors.black87,
                                letterSpacing: 0.4,
                                height: 1.05,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Time + category chips ──
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_filled_rounded,
                                      color: color,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _displayTime(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  habit.category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── Streak banner ──
                          if (habit.currentStreak > 0)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8A00),
                                    Color(0xFFFF5E00),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6A00)
                                        .withOpacity(0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🔥',
                                    style: TextStyle(fontSize: 17),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${habit.currentStreak} day streak — don\'t break it!',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ── Alarm description ──
                          if (habit.alarmDescription?.trim().isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 18),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 34,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  '"${habit.alarmDescription!}"',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontStyle: FontStyle.italic,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black45,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // ── Auto-snooze hint ──
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                            ),
                            child: Text(
                              'Auto-snoozes in $_countdown seconds if no action taken.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const Spacer(flex: 3),

                          // ── Action buttons ──
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: Column(
                              children: [
                                // Dismiss / complete button
                                ScaleTransition(
                                  scale: _buttonScaleAnim,
                                  child: GestureDetector(
                                    onTap: (_isDismissing || _isClosing)
                                        ? null
                                        : _handleDismiss,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 260,
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _isDismissing
                                              ? [
                                            Colors.grey,
                                            Colors.grey,
                                          ]
                                              : [
                                            AppConfig.successColor,
                                            const Color(0xFF00A843),
                                          ],
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppConfig.successColor
                                                .withOpacity(0.36),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isDismissing
                                                ? Icons.check_circle_rounded
                                                : Icons.check_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _isDismissing
                                                ? 'Completing...'
                                                : 'I\'m Doing It!',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Snooze button
                                GestureDetector(
                                  onTap: (_isSnoozed || _isClosing)
                                      ? null
                                      : _handleSnooze,
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 260,
                                    ),
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.04),
                                      borderRadius:
                                      BorderRadius.circular(22),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.14)
                                            : Colors.black.withOpacity(0.08),
                                        width: 1.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.snooze_rounded,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _isSnoozed
                                              ? 'Snoozed ✓'
                                              : 'Snooze 5 min',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Skip button
                                GestureDetector(
                                  onTap:
                                  _isClosing ? null : _handleSkip,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Skip for today',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black26,
                                        decoration:
                                        TextDecoration.underline,
                                        decorationColor: isDark
                                            ? Colors.white24
                                            : Colors.black12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height:
                            MediaQuery.of(context).padding.bottom + 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}