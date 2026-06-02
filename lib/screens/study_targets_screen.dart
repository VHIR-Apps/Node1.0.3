// lib/screens/study_targets_screen.dart
//
// Targets & Schedule screen (single tab):
// - Set daily/weekly study targets
// - Optional subject-wise weekly targets
// - Manage weekly schedule routines (recurring study blocks)
//
// UI text: English only.
// State management: setState only.
// Premium UI: Material 3 + subtle glass effects, strong error handling.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/daily_study_routine_model.dart';
import '../models/study_target_model.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';
import '../widgets/daily_routine_card.dart' as routine_widgets;
import '../widgets/study_target_card.dart' as target_widgets;

class StudyTargetsScreen extends StatefulWidget {
  const StudyTargetsScreen({super.key});

  @override
  State<StudyTargetsScreen> createState() => _StudyTargetsScreenState();
}

class _StudyTargetsScreenState extends State<StudyTargetsScreen> {
  bool _busy = false;

  StudyTarget? _target;
  int _minutesToday = 0;
  int _minutesThisWeek = 0;
  Map<String, int> _minutesBySubjectThisWeek = <String, int>{};

  List<DailyStudyRoutine> _dailyRoutines = <DailyStudyRoutine>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _busy = true);
    }
    try {
      final t = await DatabaseService.ensureStudyTarget();
      final minutesToday = DatabaseService.getTotalStudyMinutesToday();
      final minutesThisWeek = DatabaseService.getTotalStudyMinutesThisWeek();
      final bySubjectWeek = DatabaseService.getStudyMinutesThisWeekBySubject();
      final routines = DatabaseService.getAllDailyStudyRoutines();

      if (!mounted) return;
      setState(() {
        _target = t;
        _minutesToday = minutesToday;
        _minutesThisWeek = minutesThisWeek;
        _minutesBySubjectThisWeek = bySubjectWeek;
        _dailyRoutines = routines;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to load targets and schedule.', isError: true);
    } finally {
      if (!mounted) return;
      if (!silent) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Targets & Schedule',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : () => _load(),
            icon: _busy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 4),
            _buildTargetsSection(isDark),
            const SizedBox(height: 6),
            _divider(isDark),
            _buildScheduleSection(isDark),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createDailyRoutine,
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Routine',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Targets
  // ─────────────────────────────────────────────

  Widget _buildTargetsSection(bool isDark) {
    final t = _target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Study Targets'),
        if (t == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: _infoCard(
              isDark: isDark,
              icon: Icons.flag_outlined,
              title: 'Loading targets...',
              subtitle: 'Please wait a moment.',
              color: AppConfig.infoColor,
            ),
          )
        else
          target_widgets.StudyTargetCard(
            target: t,
            minutesToday: _minutesToday,
            minutesThisWeek: _minutesThisWeek,
            minutesBySubjectThisWeek: _minutesBySubjectThisWeek,
            isDark: isDark,
            onEdit: () => _openTargetEditor(t),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          child: Text(
            'Targets are calculated from your saved focus sessions.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTargetEditor(StudyTarget current) async {
    await _tapFeedback();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    int daily = current.dailyTargetMinutes;
    int weekly = current.weeklyTargetMinutes;

    // Copy
    final subjectTargets = Map<String, int>.from(current.subjectTargets);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final sheetBg = isDark ? const Color(0xFF151C2F) : Colors.white;

            final safeDaily = daily.clamp(
              AppConfig.minTargetMinutes,
              AppConfig.maxTargetMinutes,
            );
            final safeWeekly = weekly.clamp(
              AppConfig.minTargetMinutes,
              AppConfig.maxTargetMinutes,
            );

            final subjects = _availableSubjects()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    18 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppConfig.primaryColor.withOpacity(0.95),
                                    AppConfig.infoColor.withOpacity(0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Edit Targets',
                                style: TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        _editorCard(
                          isDark: isDark,
                          title: 'Daily target',
                          subtitle: 'How much you want to study per day',
                          icon: Icons.today_rounded,
                          color: AppConfig.successColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _valuePill(
                                isDark: isDark,
                                label: _fmtMinutes(safeDaily),
                                color: AppConfig.successColor,
                              ),
                              const SizedBox(height: 10),
                              _presetRow(
                                isDark: isDark,
                                presets: AppConfig.dailyTargetPresets,
                                selectedMinutes: safeDaily,
                                onPick: (m) => setSheetState(() => daily = m),
                              ),
                              const SizedBox(height: 12),
                              Slider(
                                value: safeDaily.toDouble(),
                                min: AppConfig.minTargetMinutes.toDouble(),
                                max: 600, // 10 hours/day UI limit
                                divisions: (600 - AppConfig.minTargetMinutes) ~/ 5,
                                onChanged: (v) => setSheetState(() => daily = v.round()),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                        _editorCard(
                          isDark: isDark,
                          title: 'Weekly target',
                          subtitle: 'Your weekly study goal',
                          icon: Icons.date_range_rounded,
                          color: AppConfig.infoColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _valuePill(
                                isDark: isDark,
                                label: _fmtMinutes(safeWeekly),
                                color: AppConfig.infoColor,
                              ),
                              const SizedBox(height: 10),
                              _presetRow(
                                isDark: isDark,
                                presets: AppConfig.weeklyTargetPresets,
                                selectedMinutes: safeWeekly,
                                onPick: (m) => setSheetState(() => weekly = m),
                              ),
                              const SizedBox(height: 12),
                              Slider(
                                value: safeWeekly.toDouble(),
                                min: 120, // 2 hours/week
                                max: 3000, // 50 hours/week
                                divisions: (3000 - 120) ~/ 30,
                                onChanged: (v) => setSheetState(() => weekly = v.round()),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                        _editorCard(
                          isDark: isDark,
                          title: 'Subject targets (weekly)',
                          subtitle: 'Optional: set weekly goals per subject',
                          icon: Icons.menu_book_rounded,
                          color: AppConfig.primaryColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (subjectTargets.isEmpty)
                                Text(
                                  'No subject targets set.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                ...subjectTargets.entries.map((e) {
                                  final subject = e.key;
                                  final value = e.value;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subject,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _miniStepper(
                                          isDark: isDark,
                                          valueMinutes: value,
                                          onChanged: (newMinutes) {
                                            setSheetState(() {
                                              if (newMinutes <= 0) {
                                                subjectTargets.remove(subject);
                                              } else {
                                                subjectTargets[subject] = newMinutes;
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          tooltip: 'Remove',
                                          onPressed: () {
                                            setSheetState(() => subjectTargets.remove(subject));
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final added = await _addSubjectTargetDialog(
                                      ctx,
                                      isDark: isDark,
                                      availableSubjects: subjects,
                                    );
                                    if (added == null) return;
                                    setSheetState(() {
                                      subjectTargets[added.subject] = added.minutes;
                                    });
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text(
                                    'Add subject target',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConfig.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    setState(() => _busy = true);
    try {
      daily = daily.clamp(AppConfig.minTargetMinutes, AppConfig.maxTargetMinutes);
      weekly = weekly.clamp(AppConfig.minTargetMinutes, AppConfig.maxTargetMinutes);

      final cleaned = <String, int>{};
      for (final e in subjectTargets.entries) {
        final k = e.key.trim();
        final v = e.value;
        if (k.isEmpty) continue;
        if (v <= 0) continue;
        cleaned[k] = v;
      }

      await DatabaseService.setStudyTargets(
        dailyMinutes: daily,
        weeklyMinutes: weekly,
        subjectWeeklyTargets: cleaned,
      );

      await _load(silent: true);

      try {
        SoundService.playSuccess();
      } catch (_) {}

      if (!mounted) return;
      _showSnack('Targets saved.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to save targets. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─────────────────────────────────────────────
  // Schedule
  // ─────────────────────────────────────────────

  Widget _buildScheduleSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Weekly Schedule'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            'Create routines with recurring study blocks (subject, time, and weekdays).',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_dailyRoutines.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
            child: _infoCard(
              isDark: isDark,
              icon: Icons.event_busy_rounded,
              title: 'No schedule routines yet',
              subtitle: 'Tap "Add Routine" to create a weekly study plan.',
              color: AppConfig.warningColor,
            ),
          )
        else
          ..._dailyRoutines.map((r) {
            return routine_widgets.DailyRoutineCard(
              routine: r,
              isDark: isDark,
              onTap: () => _openRoutineDetails(r),
              onEdit: () => _openRoutineDetails(r, jumpToEdit: true),
              onDelete: () => _confirmDeleteRoutine(r),
              onToggleActive: (v) => _toggleRoutineActive(r, v),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }

  Future<void> _createDailyRoutine() async {
    await _tapFeedback();

    final created = await _routineEditorDialog(
      context,
      isDark: Theme.of(context).brightness == Brightness.dark,
      existing: null,
    );

    if (created == null) return;

    setState(() => _busy = true);
    try {
      await DatabaseService.saveDailyStudyRoutine(created);
      await _load(silent: true);

      try {
        SoundService.playSuccess();
      } catch (_) {}

      if (!mounted) return;
      _showSnack('Routine created.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to create routine.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRoutineActive(DailyStudyRoutine r, bool active) async {
    await _tapFeedback();

    setState(() => _busy = true);
    try {
      await DatabaseService.setDailyStudyRoutineActive(r.id, active);
      await _load(silent: true);
      if (!mounted) return;
      _showSnack(active ? 'Routine activated.' : 'Routine paused.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to update routine.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDeleteRoutine(DailyStudyRoutine r) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete routine?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'This will permanently delete "${r.name}".',
          style: TextStyle(
            height: 1.45,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _tapFeedback(heavy: true);

    setState(() => _busy = true);
    try {
      await DatabaseService.deleteDailyStudyRoutine(r.id);
      await _load(silent: true);

      try {
        SoundService.playSuccess();
      } catch (_) {}

      if (!mounted) return;
      _showSnack('Routine deleted.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to delete routine.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRoutineDetails(
      DailyStudyRoutine routine, {
        bool jumpToEdit = false,
      }) async {
    await _tapFeedback();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isDark ? const Color(0xFF151C2F) : Colors.white;

        DailyStudyRoutine r = routine;

        Future<void> reloadLocal(void Function(void Function()) setSheetState) async {
          final latest = DatabaseService.getDailyStudyRoutineById(r.id);
          if (latest != null) {
            setSheetState(() => r = latest);
          }
        }

        Future<void> saveLocal(
            DailyStudyRoutine updated,
            void Function(void Function()) setSheetState,
            ) async {
          await DatabaseService.saveDailyStudyRoutine(updated);
          await reloadLocal(setSheetState);
          await _load(silent: true);
        }

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                18 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: StatefulBuilder(
                builder: (ctx, setSheetState) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(r.colorValue).withOpacity(0.95),
                                    AppConfig.primaryColor.withOpacity(0.75),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.event_repeat_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                r.name,
                                style: TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Switch(
                              value: r.isActive,
                              onChanged: (v) async {
                                await _tapFeedback();
                                try {
                                  await saveLocal(r.copyWith(isActive: v), setSheetState);
                                  if (mounted) {
                                    _showSnack(v ? 'Routine activated.' : 'Routine paused.');
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    _showSnack('Unable to update routine.', isError: true);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Blocks',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (r.blocks.isEmpty)
                          _infoCard(
                            isDark: isDark,
                            icon: Icons.view_agenda_outlined,
                            title: 'No blocks yet',
                            subtitle: 'Add blocks to define your weekly schedule.',
                            color: AppConfig.infoColor,
                          )
                        else
                          ...r.blocks.map((b) {
                            final enabled = b.isEnabled;
                            final blockColor = Color(b.subjectColorValue);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: blockColor.withOpacity(isDark ? 0.12 : 0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: blockColor.withOpacity(isDark ? 0.22 : 0.16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: blockColor.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      enabled
                                          ? Icons.schedule_rounded
                                          : Icons.pause_circle_filled_rounded,
                                      color: blockColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.subjectName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${b.formattedTimeRange} • ${b.formattedWeekDays}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.25,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                        if (b.note != null && b.note!.trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            b.note!.trim(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    tooltip: 'Options',
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        final updated = await _blockEditorSheet(
                                          ctx,
                                          isDark: isDark,
                                          routineColor: Color(r.colorValue),
                                          existing: b,
                                        );
                                        if (updated == null) return;

                                        final blocks = List<DailyStudyBlock>.from(r.blocks);
                                        final idx = blocks.indexWhere((x) => x.id == b.id);
                                        if (idx >= 0) blocks[idx] = updated;

                                        try {
                                          await saveLocal(r.copyWith(blocks: blocks), setSheetState);
                                          if (mounted) _showSnack('Block updated.');
                                        } catch (_) {
                                          if (mounted) _showSnack('Unable to update block.', isError: true);
                                        }
                                      } else if (v == 'toggle') {
                                        final blocks = List<DailyStudyBlock>.from(r.blocks);
                                        final idx = blocks.indexWhere((x) => x.id == b.id);
                                        if (idx >= 0) {
                                          blocks[idx] = blocks[idx].copyWith(
                                            isEnabled: !blocks[idx].isEnabled,
                                          );
                                        }
                                        try {
                                          await saveLocal(r.copyWith(blocks: blocks), setSheetState);
                                        } catch (_) {
                                          if (mounted) _showSnack('Unable to update block.', isError: true);
                                        }
                                      } else if (v == 'delete') {
                                        final ok = await _confirm(
                                          ctx,
                                          title: 'Delete block?',
                                          message: 'This block will be removed from the routine.',
                                          isDark: isDark,
                                          destructive: true,
                                        );
                                        if (ok != true) return;

                                        final blocks = List<DailyStudyBlock>.from(r.blocks)
                                          ..removeWhere((x) => x.id == b.id);

                                        try {
                                          await saveLocal(r.copyWith(blocks: blocks), setSheetState);
                                          if (mounted) _showSnack('Block deleted.');
                                        } catch (_) {
                                          if (mounted) _showSnack('Unable to delete block.', isError: true);
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(enabled ? 'Disable' : 'Enable'),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final updated = await _routineEditorDialog(
                                      ctx,
                                      isDark: isDark,
                                      existing: r,
                                    );
                                    if (updated == null) return;

                                    await _tapFeedback();
                                    try {
                                      await saveLocal(updated, setSheetState);
                                      if (mounted) _showSnack('Routine updated.');
                                    } catch (_) {
                                      if (mounted) _showSnack('Unable to update routine.', isError: true);
                                    }
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  label: const Text(
                                    'Edit routine',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final newBlock = await _blockEditorSheet(
                                      ctx,
                                      isDark: isDark,
                                      routineColor: Color(r.colorValue),
                                      existing: null,
                                    );
                                    if (newBlock == null) return;

                                    await _tapFeedback();
                                    final blocks = List<DailyStudyBlock>.from(r.blocks)..add(newBlock);

                                    try {
                                      await saveLocal(r.copyWith(blocks: blocks), setSheetState);
                                      if (mounted) _showSnack('Block added.');
                                    } catch (_) {
                                      if (mounted) _showSnack('Unable to add block.', isError: true);
                                    }
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text(
                                    'Add block',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConfig.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Close',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ),

                        if (jumpToEdit) const SizedBox(height: 1),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Editors
  // ─────────────────────────────────────────────

  Future<DailyStudyRoutine?> _routineEditorDialog(
      BuildContext context, {
        required bool isDark,
        required DailyStudyRoutine? existing,
      }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    int colorValue = existing?.colorValue ?? AppConfig.primaryColor.value;
    bool isActive = existing?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final bg = isDark ? const Color(0xFF151C2F) : Colors.white;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                existing == null ? 'Create routine' : 'Edit routine',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Routine name',
                        hintText: 'e.g., Weekly Study Plan',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'e.g., Exam preparation schedule',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Color',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppConfig.habitColors.take(10).map((c) {
                        final selected = c.value == colorValue;
                        return InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setDialogState(() => colorValue = c.value);
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: selected ? 3 : 1,
                                color: selected
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.white24 : Colors.black12),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (v) {
                            HapticFeedback.lightImpact();
                            setDialogState(() => isActive = v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return null;

    final name = nameCtrl.text.trim();
    final desc = descCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Please enter a routine name.', isError: true);
      return null;
    }

    final now = DateTime.now();
    final id = existing?.id ?? 'dsr_${now.microsecondsSinceEpoch}';

    return DailyStudyRoutine(
      id: id,
      name: name,
      description: desc.isEmpty ? null : desc,
      colorValue: colorValue,
      blocks: existing?.blocks ?? <DailyStudyBlock>[],
      isActive: isActive,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<DailyStudyBlock?> _blockEditorSheet(
      BuildContext context, {
        required bool isDark,
        required Color routineColor,
        required DailyStudyBlock? existing,
      }) async {
    String subject = existing?.subjectName ?? 'General';
    int colorValue = existing?.subjectColorValue ?? routineColor.value;

    int startMinute = existing?.startMinuteOfDay ?? 9 * 60;
    int endMinute = existing?.endMinuteOfDay ?? 10 * 60;

    final days = <int>{...?(existing?.weekDays)}; // empty => every day
    bool enabled = existing?.isEnabled ?? true;

    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    final picked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isDark ? const Color(0xFF151C2F) : Colors.white;
        final subjects = _availableSubjects()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                18 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: StatefulBuilder(
                builder: (ctx, setSheetState) {
                  final startLabel = DailyStudyBlock.formatMinuteOfDay(startMinute);
                  final endLabel = DailyStudyBlock.formatMinuteOfDay(endMinute);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Color(colorValue).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Color(colorValue).withOpacity(isDark ? 0.25 : 0.18),
                                ),
                              ),
                              child: Icon(
                                existing == null ? Icons.add_rounded : Icons.edit_rounded,
                                color: Color(colorValue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                existing == null ? 'Add block' : 'Edit block',
                                style: TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Switch(
                              value: enabled,
                              onChanged: (v) {
                                HapticFeedback.lightImpact();
                                setSheetState(() => enabled = v);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Subject',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: subjects.contains(subject) ? subject : subjects.first,
                          items: subjects
                              .map(
                                (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ),
                          )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            HapticFeedback.lightImpact();
                            setSheetState(() {
                              subject = v;
                              final predefinedColor = AppConfig.predefinedSubjects[v];
                              if (predefinedColor != null) {
                                colorValue = predefinedColor.value;
                              }
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Select subject',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Time',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _timeButton(
                                isDark: isDark,
                                label: 'Start',
                                value: startLabel,
                                color: Color(colorValue),
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: ctx,
                                    initialTime: TimeOfDay(
                                      hour: startMinute ~/ 60,
                                      minute: startMinute % 60,
                                    ),
                                    helpText: 'Select start time',
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: isDark
                                              ? const ColorScheme.dark(primary: AppConfig.primaryColor)
                                              : const ColorScheme.light(primary: AppConfig.primaryColor),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (t == null) return;
                                  setSheetState(() => startMinute = t.hour * 60 + t.minute);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _timeButton(
                                isDark: isDark,
                                label: 'End',
                                value: endLabel,
                                color: Color(colorValue),
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: ctx,
                                    initialTime: TimeOfDay(
                                      hour: endMinute ~/ 60,
                                      minute: endMinute % 60,
                                    ),
                                    helpText: 'Select end time',
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: isDark
                                              ? const ColorScheme.dark(primary: AppConfig.primaryColor)
                                              : const ColorScheme.light(primary: AppConfig.primaryColor),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (t == null) return;
                                  setSheetState(() => endMinute = t.hour * 60 + t.minute);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Weekdays',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(7, (i) {
                            final day = i + 1; // 1..7
                            const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            final selected = days.contains(day);

                            return FilterChip(
                              selected: selected,
                              label: Text(labels[i]),
                              onSelected: (v) {
                                HapticFeedback.lightImpact();
                                setSheetState(() {
                                  if (v) {
                                    days.add(day);
                                  } else {
                                    days.remove(day);
                                  }
                                });
                              },
                              selectedColor: AppConfig.primaryColor.withOpacity(isDark ? 0.25 : 0.14),
                              checkmarkColor: AppConfig.primaryColor,
                              side: BorderSide(
                                color: selected
                                    ? AppConfig.primaryColor.withOpacity(0.6)
                                    : (isDark ? Colors.white12 : Colors.black12),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            hintText: 'e.g., Chapter 3, Mock test',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConfig.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (picked != true) return null;

    if (endMinute <= startMinute) {
      _showSnack('End time must be after start time.', isError: true);
      return null;
    }

    final now = DateTime.now();
    final id = existing?.id ?? 'dsb_${now.microsecondsSinceEpoch}';

    final note = noteCtrl.text.trim();

    return DailyStudyBlock(
      id: id,
      subjectName: subject.trim().isEmpty ? 'General' : subject.trim(),
      subjectColorValue: colorValue,
      startMinuteOfDay: startMinute,
      endMinuteOfDay: endMinute,
      weekDays: days.toList()..sort(),
      isEnabled: enabled,
      note: note.isEmpty ? null : note,
    );
  }

  // ─────────────────────────────────────────────
  // UI Helpers
  // ─────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          color: AppConfig.primaryColor,
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      indent: 20,
      endIndent: 20,
      color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
    );
  }

  Widget _infoCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final bg = isDark ? const Color(0xFF151C2F) : Colors.white;
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: isDark ? 10 : 0, sigmaY: isDark ? 10 : 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg.withOpacity(isDark ? 0.78 : 1.0),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editorCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    final bg = isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50;
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.2,
              height: 1.3,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _valuePill({
    required bool isDark,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(isDark ? 0.22 : 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _presetRow({
    required bool isDark,
    required List<Map<String, dynamic>> presets,
    required int selectedMinutes,
    required ValueChanged<int> onPick,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: presets.map((p) {
        final label = (p['label'] as String?) ?? '';
        final minutes = (p['minutes'] as num?)?.toInt() ?? 0;
        final selected = minutes == selectedMinutes;

        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            HapticFeedback.lightImpact();
            onPick(minutes);
          },
          selectedColor: AppConfig.primaryColor.withOpacity(isDark ? 0.25 : 0.14),
          side: BorderSide(
            color: selected
                ? AppConfig.primaryColor.withOpacity(0.6)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        );
      }).toList(),
    );
  }

  Widget _miniStepper({
    required bool isDark,
    required int valueMinutes,
    required ValueChanged<int> onChanged,
  }) {
    final v = valueMinutes.clamp(0, 99999);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: () => onChanged((v - 30).clamp(0, 99999)),
          icon: const Icon(Icons.remove_rounded),
          tooltip: 'Decrease',
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            _fmtMinutes(v),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => onChanged((v + 30).clamp(0, 99999)),
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Increase',
        ),
      ],
    );
  }

  Widget _timeButton({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bg = isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50;
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200;

    return InkWell(
      onTap: () async {
        await _tapFeedback();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Dialog helpers
  // ─────────────────────────────────────────────

  Future<_SubjectTargetDraft?> _addSubjectTargetDialog(
      BuildContext context, {
        required bool isDark,
        required List<String> availableSubjects,
      }) async {
    String? selected = availableSubjects.isNotEmpty ? availableSubjects.first : null;
    final customCtrl = TextEditingController();
    final minutesCtrl = TextEditingController(text: '120');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final bg = isDark ? const Color(0xFF151C2F) : Colors.white;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Add subject target',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (availableSubjects.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selected,
                      items: availableSubjects
                          .map(
                            (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setDialogState(() => selected = v),
                      decoration: const InputDecoration(
                        labelText: 'Subject (optional)',
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Or type subject name',
                      hintText: 'e.g., Math',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minutesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Weekly minutes',
                      hintText: 'e.g., 180',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return null;

    final custom = customCtrl.text.trim();
    final subject = custom.isNotEmpty ? custom : (selected ?? '').trim();

    if (subject.isEmpty) {
      _showSnack('Please enter a subject name.', isError: true);
      return null;
    }

    final mins = int.tryParse(minutesCtrl.text.trim()) ?? 0;
    if (mins <= 0) {
      _showSnack('Please enter a valid minutes value.', isError: true);
      return null;
    }

    return _SubjectTargetDraft(subject: subject, minutes: mins);
  }

  Future<bool?> _confirm(
      BuildContext context, {
        required String title,
        required String message,
        required bool isDark,
        required bool destructive,
      }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          message,
          style: TextStyle(
            height: 1.45,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? AppConfig.errorColor : AppConfig.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
                destructive ? 'Delete' : 'OK',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  List<String> _availableSubjects() {
    final set = <String>{};
    set.addAll(AppConfig.predefinedSubjects.keys);
    try {
      set.addAll(DatabaseService.getCustomStudySubjects());
    } catch (_) {}
    if (set.isEmpty) set.add('General');
    return set.toList();
  }

  static String _fmtMinutes(int minutes) {
    final m = minutes < 0 ? 0 : minutes;
    final h = m ~/ 60;
    final r = m % 60;
    if (h <= 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  Future<void> _tapFeedback({bool heavy = false}) async {
    try {
      if (heavy) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}

    try {
      SoundService.playTap();
    } catch (_) {}
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppConfig.errorColor : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

class _SubjectTargetDraft {
  final String subject;
  final int minutes;

  const _SubjectTargetDraft({
    required this.subject,
    required this.minutes,
  });
}