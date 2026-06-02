// lib/widgets/habit_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/habit_model.dart';
import '../services/sound_service.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.habit.isCompletedToday()) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.habit.isCompletedToday()) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final habit = widget.habit;

    HapticFeedback.lightImpact();

    if (habit.dailyGoal > 1) {
      // Multi-goal habit: increment progress
      final result = habit.incrementProgress();

      if (result == 1) {
        // Goal just completed!
        _controller.forward();
        SoundService.playHabitComplete();
        _showCompletionFeedback();
      } else if (result == 2) {
        // Already completed
        _showAlreadyCompletedMessage();
      } else {
        // Progress incremented but not complete yet
        SoundService.playTap();
        _showProgressFeedback();
      }
    } else {
      // Single goal habit: toggle
      if (habit.isCompletedToday()) {
        _controller.reverse();
        SoundService.playHabitUndo();
      } else {
        _controller.forward();
        SoundService.playHabitComplete();
      }
      habit.toggleComplete();
    }

    widget.onToggle();
  }

  void _handleLongPress() {
    final habit = widget.habit;

    HapticFeedback.mediumImpact();

    if (habit.dailyGoal > 1 && habit.getTodayProgress() > 0) {
      _showUndoDialog();
    } else {
      widget.onEdit();
    }
  }

  void _showUndoDialog() {
    final habit = widget.habit;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(habit.colorValue);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Habit info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(habit.emoji,
                          style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Progress: ${habit.getTodayProgress()}/${habit.dailyGoal} ${habit.dailyGoalUnit ?? ''}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'Undo 1',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _undoOneProgress();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Reset All',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _resetAllProgress();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Complete All',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _completeAll();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit Habit',
                    color: const Color(0xFF6C63FF),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onEdit();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _undoOneProgress() {
    final habit = widget.habit;
    final wasCompleted = habit.isCompletedToday();
    habit.decrementProgress();

    if (wasCompleted && !habit.isCompletedToday()) {
      _controller.reverse();
    }

    SoundService.playHabitUndo();
    widget.onToggle();

    _showSnackBar('Undone 1 ${habit.dailyGoalUnit ?? 'progress'}');
  }

  void _resetAllProgress() {
    final habit = widget.habit;
    habit.forceUncomplete();
    _controller.reverse();
    SoundService.playHabitUndo();
    widget.onToggle();

    _showSnackBar('Progress reset');
  }

  void _completeAll() {
    final habit = widget.habit;
    habit.forceComplete();
    _controller.forward();
    SoundService.playHabitComplete();
    widget.onToggle();

    _showCompletionFeedback();
  }

  void _showProgressFeedback() {
    final habit = widget.habit;
    _showSnackBar(
      '${habit.emoji} ${habit.getTodayProgress()}/${habit.dailyGoal} ${habit.dailyGoalUnit ?? ''} done!',
      icon: Icons.trending_up_rounded,
      color: Color(habit.colorValue),
    );
  }

  void _showCompletionFeedback() {
    final habit = widget.habit;
    _showSnackBar(
      '${habit.emoji} ${habit.name} completed! 🎉',
      icon: Icons.celebration_rounded,
      color: Colors.green,
    );
  }

  void _showAlreadyCompletedMessage() {
    final habit = widget.habit;
    _showSnackBar(
      '${habit.emoji} Already completed today!',
      icon: Icons.check_circle_rounded,
      color: Colors.blue,
    );
  }

  void _showSnackBar(String message, {IconData? icon, Color? color}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? const Color(0xFF6C63FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRemoving) return const SizedBox.shrink();

    final habit = widget.habit;
    final isDone = habit.isCompletedToday();
    final color = Color(habit.colorValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = Color(habit.priorityColorValue);
    final progress = habit.getTodayProgress();
    final goal = habit.dailyGoal;
    final hasMultiGoal = goal > 1;

    return Dismissible(
      key: ValueKey(habit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade300, Colors.red.shade500],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        // 🔴 CHANGED: Play error sound when user tries to delete (warning feel)
        SoundService.playError();
        HapticFeedback.mediumImpact();

        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete Habit'),
            content:
            Text('Are you sure you want to delete "${habit.name}"?'),
            actions: [
              TextButton(
                onPressed: () {
                  SoundService.playTap();
                  Navigator.pop(context, false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ) ??
            false;
      },
      onDismissed: (_) {
        setState(() => _isRemoving = true);
        // 🔴 This sound is GOOD — keep it
        SoundService.playHabitDeleted();
        HapticFeedback.heavyImpact();
        widget.onDelete();
      },
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - (_controller.value * 0.02),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDone
                      ? color.withOpacity(isDark ? 0.15 : 0.08)
                      : (isDark ? const Color(0xFF151C2F) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDone
                        ? color.withOpacity(0.4)
                        : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.transparent),
                    width: isDone ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDone
                          ? color.withOpacity(0.15)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isDone ? 20 : 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Main Row
                    Row(
                      children: [
                        // Progress Circle / Check Circle
                        _buildProgressCircle(
                          isDone: isDone,
                          color: color,
                          progress: progress,
                          goal: goal,
                          hasMultiGoal: hasMultiGoal,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 14),

                        // Emoji
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withOpacity(isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              habit.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Name & Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      habit.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: color,
                                        color: isDone
                                            ? (isDark
                                            ? Colors.white54
                                            : Colors.black45)
                                            : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: priorityColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: priorityColor.withOpacity(0.4),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (habit.time != null) ...[
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      habit.time!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      habit.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Streak Badge
                        if (habit.currentStreak > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8A00), Color(0xFFFF5E00)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  const Color(0xFFFF6A00).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🔥',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  '${habit.currentStreak}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Daily Goal Progress Bar (if goal > 1)
                    if (hasMultiGoal) ...[
                      const SizedBox(height: 14),
                      _buildGoalProgressBar(
                        progress: progress,
                        goal: goal,
                        unit: habit.dailyGoalUnit,
                        color: color,
                        isDone: isDone,
                        isDark: isDark,
                      ),
                    ],

                    // Description
                    if (habit.description != null &&
                        habit.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(width: 58),
                          Expanded(
                            child: Text(
                              habit.description!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white30 : Colors.black26,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressCircle({
    required bool isDone,
    required Color color,
    required int progress,
    required int goal,
    required bool hasMultiGoal,
    required bool isDark,
  }) {
    if (hasMultiGoal) {
      final percent = goal > 0 ? (progress / goal).clamp(0.0, 1.0) : 0.0;

      return SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 4,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade200,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? Colors.green : color,
                ),
              ),
            ),
            if (isDone)
              const Icon(Icons.check_rounded, color: Colors.green, size: 20)
            else
              Text(
                '$progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
          ],
        ),
      );
    } else {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone ? color : Colors.transparent,
          border: Border.all(
            color: color,
            width: 3,
          ),
          boxShadow: isDone
              ? [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
            ),
          ]
              : null,
        ),
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
            : null,
      );
    }
  }

  Widget _buildGoalProgressBar({
    required int progress,
    required int goal,
    required String? unit,
    required Color color,
    required bool isDone,
    required bool isDark,
  }) {
    final percent = goal > 0 ? (progress / goal * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(goal > 10 ? 10 : goal, (index) {
                    final segmentIndex =
                    goal > 10 ? (index * goal / 10).floor() : index;
                    final isCompleted = segmentIndex < progress;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: index < (goal > 10 ? 9 : goal - 1) ? 3 : 0),
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isCompleted
                              ? (isDone ? Colors.green : color)
                              : (isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.shade300),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone
                      ? Colors.green.withOpacity(0.2)
                      : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$progress/$goal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDone ? Colors.green : color,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? Colors.green.withOpacity(0.7)
                              : color.withOpacity(0.7),
                        ),
                      ),
                    ],
                    if (isDone) ...[
                      const SizedBox(width: 4),
                      const Text('✅', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.green : color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percent.toInt()}% complete',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              if (!isDone)
                Text(
                  'Tap to add +1',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.7),
                  ),
                )
              else
                const Text(
                  '🎉 Goal achieved!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}