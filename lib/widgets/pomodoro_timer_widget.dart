// lib/widgets/pomodoro_timer_widget.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/study_routine_model.dart';
import '../services/advanced_pomodoro_service.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';

class PomodoroTimerWidget extends StatefulWidget {
  final bool isDark;

  const PomodoroTimerWidget({super.key, required this.isDark});

  @override
  State<PomodoroTimerWidget> createState() => _PomodoroTimerWidgetState();
}

class _PomodoroTimerWidgetState extends State<PomodoroTimerWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    AdvancedPomodoroService.timerStatus.addListener(_onTimerStatusChange);
  }

  void _onTimerStatusChange() {
    if (mounted) {
      setState(() {});
      if (AdvancedPomodoroService.isRunning) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    AdvancedPomodoroService.timerStatus.removeListener(_onTimerStatusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Routine Mode Indicator
          ValueListenableBuilder<bool>(
            valueListenable: AdvancedPomodoroService.isRoutineMode,
            builder: (context, isRoutineMode, _) {
              if (!isRoutineMode) return const SizedBox.shrink();

              return ValueListenableBuilder<StudyRoutine?>(
                valueListenable: AdvancedPomodoroService.activeRoutine,
                builder: (context, routine, _) {
                  if (routine == null) return const SizedBox.shrink();

                  final routineColor = Color(routine.colorValue);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          routineColor.withOpacity(0.2),
                          routineColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: routineColor.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              routine.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    routine.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ValueListenableBuilder<int>(
                                    valueListenable: AdvancedPomodoroService.currentRoutineIndex,
                                    builder: (context, index, _) {
                                      return Text(
                                        'Session ${index + 1} of ${routine.sessions.length}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red.shade400),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                SoundService.playTap();
                                AdvancedPomodoroService.stopRoutine();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int>(
                          valueListenable: AdvancedPomodoroService.currentRoutineIndex,
                          builder: (context, currentIndex, _) {
                            return LinearProgressIndicator(
                              value: (currentIndex + 1) / routine.sessions.length,
                              backgroundColor: routineColor.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation(routineColor),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 20),

          // Timer Circle
          ValueListenableBuilder<PomodoroState>(
            valueListenable: AdvancedPomodoroService.currentState,
            builder: (context, state, _) {
              return AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: AdvancedPomodoroService.isRunning ? _pulseAnimation.value : 1.0,
                    child: _buildTimerCircle(state),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 40),

          // Control Buttons
          _buildControlButtons(),

          const SizedBox(height: 32),

          // Stats Cards
          _buildStatsCards(),
        ],
      ),
    );
  }

  Widget _buildTimerCircle(PomodoroState state) {
    final stateColor = AdvancedPomodoroService.stateColor;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: stateColor.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Circle
          ValueListenableBuilder<double>(
            valueListenable: AdvancedPomodoroService.progress,
            builder: (context, progress, _) {
              return CustomPaint(
                size: const Size(300, 300),
                painter: _CircularProgressPainter(
                  progress: progress,
                  color: stateColor,
                  backgroundColor: stateColor.withOpacity(0.1),
                ),
              );
            },
          ),

          // Center Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Subject Name or State Label
              ValueListenableBuilder<String>(
                valueListenable: AdvancedPomodoroService.currentSubjectName,
                builder: (context, subjectName, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      state == PomodoroState.focus ? subjectName : AdvancedPomodoroService.stateLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: stateColor,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Time Display
              ValueListenableBuilder<int>(
                valueListenable: AdvancedPomodoroService.remainingSeconds,
                builder: (context, seconds, _) {
                  return Text(
                    AdvancedPomodoroService.formattedTime,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -2,
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Pomodoro Count
              if (state == PomodoroState.focus)
                ValueListenableBuilder<int>(
                  valueListenable: AdvancedPomodoroService.completedPomodoros,
                  builder: (context, count, _) {
                    return Text(
                      '🍅 $count Pomodoro${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
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

  Widget _buildControlButtons() {
    return ValueListenableBuilder<TimerStatus>(
      valueListenable: AdvancedPomodoroService.timerStatus,
      builder: (context, status, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Reset Button
            if (status != TimerStatus.stopped)
              _buildIconButton(
                icon: Icons.refresh,
                color: Colors.red.shade400,
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  SoundService.playTap();
                  AdvancedPomodoroService.reset();
                },
              ),

            if (status != TimerStatus.stopped) const SizedBox(width: 20),

            // Main Button (Play/Pause)
            _buildMainButton(status),

            if (status == TimerStatus.running) const SizedBox(width: 20),

            // Skip Button
            if (status == TimerStatus.running)
              _buildIconButton(
                icon: Icons.skip_next,
                color: const Color(0xFF3B82F6),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  SoundService.playTap();
                  AdvancedPomodoroService.skip();
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildMainButton(TimerStatus status) {
    IconData icon;
    Color color;
    VoidCallback onPressed;

    if (status == TimerStatus.running) {
      icon = Icons.pause;
      color = const Color(0xFFF59E0B);
      onPressed = () {
        HapticFeedback.mediumImpact();
        SoundService.playTap();
        AdvancedPomodoroService.pause();
      };
    } else if (status == TimerStatus.paused) {
      icon = Icons.play_arrow;
      color = const Color(0xFF10B981);
      onPressed = () {
        HapticFeedback.mediumImpact();
        SoundService.playTap();
        AdvancedPomodoroService.resume();
      };
    } else {
      icon = Icons.play_arrow;
      color = const Color(0xFF10B981);
      onPressed = () {
        HapticFeedback.mediumImpact();
        SoundService.playSuccess();
        AdvancedPomodoroService.start();
      };
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildStatsCards() {
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Today',
            valueWidget: ValueListenableBuilder<int>(
              valueListenable: AdvancedPomodoroService.totalFocusMinutesToday,
              builder: (context, mins, _) => Text(
                '${mins}m',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            icon: Icons.today,
            color: const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Streak',
            valueWidget: Text(
              '${DatabaseService.getStudyStreak()} days',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            icon: Icons.local_fire_department,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required Widget valueWidget,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          valueWidget,
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// CIRCULAR PROGRESS PAINTER
// ═══════════════════════════════════════

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background Circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 6, bgPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}