// lib/widgets/missed_habit_dialog.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/badge_service.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';

/// 🎯 Premium Missed Habit Feedback Dialog
/// Shows once per day to collect user feedback on missed habits.
/// FIXED:
///   - Skip now saves today's date so dialog does NOT reappear same day.
///   - Dashboard can force-show without the shouldShowMissedDialog() gate.
///   - DraggableScrollableSheet prevents layout overflow + enables scroll.
///   - Notification icon is never blocked because sheet is dismissible.
class MissedHabitDialog {
  /// Standard show — respects the once-per-day gate.
  /// Returns true if user interacted (gave a reason), false otherwise.
  static Future<bool> show(BuildContext context) async {
    if (!AppConfig.enableMissedHabitDialog) return false;
    if (!DatabaseService.shouldShowMissedDialog()) return false;

    final missedHabits = DatabaseService.getMissedHabitsYesterday();

    // Mark shown today regardless of whether habits are empty.
    await DatabaseService.setLastMissedDialogDate(
      DateTime.now().toString().split(' ')[0],
    );

    if (missedHabits.isEmpty) return false;

    await Future.delayed(const Duration(milliseconds: 800));
    if (!context.mounted) return false;

    return _openSheet(context, missedHabits);
  }

  /// Force-show — bypasses the once-per-day gate.
  /// Used by the Dashboard Review button tap.
  /// Returns true if user interacted.
  static Future<bool> showForced(BuildContext context) async {
    if (!AppConfig.enableMissedHabitDialog) return false;

    final missedHabits = DatabaseService.getMissedHabitsYesterday();
    if (missedHabits.isEmpty) return false;

    if (!context.mounted) return false;
    return _openSheet(context, missedHabits);
  }

  static Future<bool> _openSheet(
      BuildContext context,
      List<Habit> missedHabits,
      ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (ctx) => _MissedHabitSheet(missedHabits: missedHabits),
    );

    return result ?? false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN FEEDBACK SHEET  — DraggableScrollableSheet so content never overflows
// ═══════════════════════════════════════════════════════════════════════════════

class _MissedHabitSheet extends StatefulWidget {
  final List<Habit> missedHabits;

  const _MissedHabitSheet({required this.missedHabits});

  @override
  State<_MissedHabitSheet> createState() => _MissedHabitSheetState();
}

class _MissedHabitSheetState extends State<_MissedHabitSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  int _currentIndex = 0;
  final Map<String, String> _selectedReasons = {};
  bool _isSaving = false;

  Habit get _currentHabit => widget.missedHabits[_currentIndex];
  bool get _isLast => _currentIndex >= widget.missedHabits.length - 1;

  String get _yesterdayStr =>
      DateTime.now().subtract(const Duration(days: 1)).toString().split(' ')[0];

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  String _getPriorityLabel(Habit habit) {
    try {
      switch (habit.priority.toLowerCase()) {
        case 'critical':
          return '🔴 Critical';
        case 'high':
          return '🟠 High';
        case 'medium':
          return '🟡 Medium';
        case 'low':
          return '🟢 Low';
        default:
          return habit.priority;
      }
    } catch (_) {
      return 'Normal';
    }
  }

  void _selectReason(String reasonId) {
    if (_isSaving) return;
    HapticFeedback.lightImpact();
    SoundService.playTap();
    setState(() => _selectedReasons[_currentHabit.id] = reasonId);
  }

  Future<void> _saveAndNext() async {
    if (_isSaving) return;

    final habit = _currentHabit;
    final reason = _selectedReasons[habit.id];

    if (reason == null || reason.isEmpty) {
      _showError('Please select a reason');
      return;
    }

    setState(() => _isSaving = true);

    try {
      habit.addMissedReason(_yesterdayStr, reason);
      await DatabaseService.updateHabit(habit);
      await BadgeService.onMissedReasonSubmitted();

      if (_isLast) {
        SoundService.playSuccess();
        HapticFeedback.mediumImpact();
        if (mounted) Navigator.pop(context, true);
      } else {
        SoundService.playSwipe();
        HapticFeedback.lightImpact();

        await _fadeController.reverse();
        if (!mounted) return;

        setState(() {
          _currentIndex++;
          _isSaving = false;
        });

        _fadeController.forward();
        _scaleController.forward(from: 0.85);
      }
    } catch (e) {
      debugPrint('❌ Error saving feedback: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Failed to save. Please try again.');
      }
    }
  }

  /// FIXED: Skip now marks today's date so the dialog does NOT reappear
  /// again in the same session. The next day it will show fresh.
  Future<void> _skipAll() async {
    if (_isSaving) return;

    HapticFeedback.lightImpact();
    SoundService.playTap();

    // Save today's date so shouldShowMissedDialog() returns false
    // for the rest of today.
    await DatabaseService.setLastMissedDialogDate(
      DateTime.now().toString().split(' ')[0],
    );

    if (mounted) Navigator.pop(context, false);
  }

  void _showCustomReasonInput() {
    if (_isSaving) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    SoundService.playTap();
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (ctx) => _CustomReasonDialog(
        habitName: _currentHabit.name,
        isDark: isDark,
        onSave: (text) {
          setState(() => _selectedReasons[_currentHabit.id] = text);
          SoundService.playSuccess();
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    SoundService.playError();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaHeight = MediaQuery.of(context).size.height;

    /// DraggableScrollableSheet:
    ///   - minChildSize: collapsed to 45% (visible handle + peek)
    ///   - initialChildSize: 0.70 (comfortable first view)
    ///   - maxChildSize: 0.92 (nearly full screen when dragged up)
    /// This ensures content is always scrollable and the notification bar
    /// is never permanently blocked.
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      snap: true,
      snapSizes: const [0.55, 0.70, 0.92],
      builder: (ctx, scrollController) {
        final habit = _currentHabit;
        final color = Color(habit.colorValue);
        final selectedReason = _selectedReasons[habit.id];
        final total = widget.missedHabits.length;
        final reasons = AppConfig.missedReasons;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C2F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ── Scrollable content ──
              CustomScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Header
                          _buildHeader(isDark),
                          const SizedBox(height: 20),

                          // Progress
                          _buildProgressBar(isDark, total),
                          const SizedBox(height: 24),

                          // Habit card (animated)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: _buildHabitCard(isDark, habit, color),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Reason label
                          _buildReasonLabel(isDark),
                          const SizedBox(height: 14),

                          // Reason chips
                          _buildReasonChips(isDark, reasons, selectedReason),
                          const SizedBox(height: 28),

                          // Action buttons
                          _buildActionButtons(isDark, selectedReason),

                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Loading overlay ──
              if (_isSaving)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.48),
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppConfig.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF1E1B4B).withOpacity(0.6),
            const Color(0xFF252250).withOpacity(0.4),
          ]
              : [
            AppConfig.accentColor.withOpacity(0.10),
            AppConfig.primaryColor.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : AppConfig.accentColor.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('🤔', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Yesterday's Review",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Tell us why — we'll help you improve!",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PROGRESS BAR
  // ─────────────────────────────────────────────

  Widget _buildProgressBar(bool isDark, int total) {
    return Column(
      children: [
        Row(
          children: List.generate(total, (i) {
            final isCompleted = i < _currentIndex;
            final isCurrent = i == _currentIndex;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                height: 6,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF00C853)
                      : isCurrent
                      ? AppConfig.primaryColor
                      : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isCurrent
                      ? [
                    BoxShadow(
                      color: AppConfig.primaryColor.withOpacity(0.3),
                      blurRadius: 6,
                    ),
                  ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Habit ${_currentIndex + 1} of $total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppConfig.primaryColor,
              ),
            ),
            if (_currentIndex > 0)
              Text(
                '$_currentIndex reviewed ✓',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00C853),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HABIT CARD
  // ─────────────────────────────────────────────

  Widget _buildHabitCard(bool isDark, Habit habit, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.08) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.06 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(habit.emoji, style: const TextStyle(fontSize: 28)),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _infoPill(text: habit.category, color: color, isDark: isDark),
                    const SizedBox(width: 8),
                    _infoPill(
                      text: _getPriorityLabel(habit),
                      color: Colors.grey,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.15),
                  Colors.red.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close_rounded, size: 14, color: Colors.red),
                SizedBox(width: 4),
                Text(
                  'Missed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill({
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // REASON LABEL
  // ─────────────────────────────────────────────

  Widget _buildReasonLabel(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppConfig.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.psychology_rounded,
            size: 16,
            color: AppConfig.primaryColor,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'WHY DID YOU MISS IT?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          'Select one',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // REASON CHIPS
  // ─────────────────────────────────────────────

  Widget _buildReasonChips(
      bool isDark,
      List<Map<String, String>> reasons,
      String? selectedReason,
      ) {
    final isCustomSelected =
        selectedReason != null && !reasons.any((r) => r['id'] == selectedReason);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...reasons.map((r) {
          final reasonId = r['id']!;
          final isSelected = selectedReason == reasonId;
          return GestureDetector(
            onTap: () => _selectReason(reasonId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppConfig.primaryColor.withOpacity(0.15)
                    : (isDark
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppConfig.primaryColor
                      : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.grey.withOpacity(0.12)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: AppConfig.primaryColor.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r['emoji']!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    r['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? AppConfig.primaryColor
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppConfig.primaryColor,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        // Custom reason chip
        GestureDetector(
          onTap: _showCustomReasonInput,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCustomSelected
                  ? AppConfig.primaryColor.withOpacity(0.15)
                  : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCustomSelected
                    ? AppConfig.primaryColor
                    : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.withOpacity(0.12)),
                width: isCustomSelected ? 2 : 1,
              ),
              boxShadow: isCustomSelected
                  ? [
                BoxShadow(
                  color: AppConfig.primaryColor.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✍️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isCustomSelected
                        ? selectedReason!
                        : 'Write own reason',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCustomSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isCustomSelected
                          ? AppConfig.primaryColor
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCustomSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppConfig.primaryColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────────────────

  Widget _buildActionButtons(bool isDark, String? selectedReason) {
    final canProceed = selectedReason != null && selectedReason.isNotEmpty;

    return Row(
      children: [
        // Skip button
        Expanded(
          child: GestureDetector(
            onTap: _isSaving ? null : _skipAll,
            child: AnimatedOpacity(
              opacity: _isSaving ? 0.5 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.grey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.15),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Skip All',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Next / Done button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: (_isSaving || !canProceed) ? null : _saveAndNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: canProceed && !_isSaving
                    ? LinearGradient(
                  colors: _isLast
                      ? [
                    const Color(0xFF00C853),
                    const Color(0xFF00E676),
                  ]
                      : [
                    AppConfig.primaryColor,
                    AppConfig.primaryColor.withOpacity(0.8),
                  ],
                )
                    : null,
                color: (!canProceed || _isSaving)
                    ? (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.shade200)
                    : null,
                borderRadius: BorderRadius.circular(18),
                boxShadow: canProceed && !_isSaving
                    ? [
                  BoxShadow(
                    color: (_isLast
                        ? const Color(0xFF00C853)
                        : AppConfig.primaryColor)
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  _isLast ? 'Done ✅' : 'Next →',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: canProceed
                        ? Colors.white
                        : (isDark ? Colors.white24 : Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOM REASON INPUT DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomReasonDialog extends StatefulWidget {
  final String habitName;
  final bool isDark;
  final Function(String) onSave;

  const _CustomReasonDialog({
    required this.habitName,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_CustomReasonDialog> createState() => _CustomReasonDialogState();
}

class _CustomReasonDialogState extends State<_CustomReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _charCount = 0;
  static const int _maxChars = 200;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _charCount = _controller.text.length);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      HapticFeedback.heavyImpact();
      SoundService.playError();
      return;
    }
    widget.onSave(text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _charCount > 0 && _charCount <= _maxChars;
    final progressPercent = (_charCount / _maxChars * 100).clamp(0.0, 100.0);
    final progressColor = progressPercent < 80
        ? AppConfig.primaryColor
        : progressPercent < 95
        ? Colors.orange
        : Colors.red;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor:
      widget.isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConfig.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('✍️', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Write Your Reason',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Tell us why you missed "${widget.habitName}"',
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // Text field
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              maxLength: _maxChars,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                hintText: 'e.g., Had an emergency meeting...',
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                filled: true,
                fillColor: widget.isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppConfig.primaryColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),

            // Character counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_charCount / $_maxChars',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
                if (_charCount > _maxChars)
                  const Text(
                    'Too long!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 4,
                backgroundColor: widget.isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      SoundService.playTap();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: canSave ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: widget.isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.shade200,
                      disabledForegroundColor:
                      widget.isDark ? Colors.white24 : Colors.grey,
                      elevation: canSave ? 2 : 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}