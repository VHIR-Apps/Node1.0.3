// lib/screens/study_mode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/study_routine_model.dart';
import '../services/advanced_pomodoro_service.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';
import '../widgets/pomodoro_timer_widget.dart';
import '../widgets/routine_card_widget.dart';
import '../widgets/study_stats_widgets.dart';
import 'create_routine_screen.dart';
import 'study_targets_screen.dart';

class StudyModeScreen extends StatefulWidget {
  const StudyModeScreen({super.key});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _activeTabIndex = 0;

  bool isDark = false;
  List<StudyRoutine> _routines = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // ✅ Now 5 tabs (single new tab: Targets)
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);

    // ✅ Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    _initializeScreen();
  }

  void _onTabChanged() {
    if (!mounted) return;

    // Avoid excessive rebuilds during swipe animations.
    if (_tabController.indexIsChanging) return;

    final idx = _tabController.index;
    if (idx != _activeTabIndex) {
      setState(() => _activeTabIndex = idx);
    }
  }

  // ═══════════════════════════════════════
  // 🔄 INITIALIZE SCREEN
  // ═══════════════════════════════════════
  Future<void> _initializeScreen() async {
    if (_isInitialized) return;

    // Initialize pomodoro service (will auto-restore state)
    await AdvancedPomodoroService.init();

    _loadRoutines();

    // Listen to state changes
    AdvancedPomodoroService.onStateChange = () {
      if (mounted) {
        setState(() {});
      }
    };

    AdvancedPomodoroService.onRoutineComplete = () {
      if (mounted) {
        _loadRoutines();
        _showRoutineCompleteDialog();
      }
    };

    _isInitialized = true;
    debugPrint('📱 Study Mode Screen initialized');
  }

  // ═══════════════════════════════════════
  // 🔄 APP LIFECYCLE OBSERVER
  // ═══════════════════════════════════════
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
      // ✅ App resumed from background - refresh UI
        debugPrint('📱 App resumed - refreshing timer UI');
        if (mounted) {
          setState(() {
            // Force rebuild to show latest timer state
          });
        }
        break;

      case AppLifecycleState.paused:
      // ✅ App going to background
        debugPrint('📱 App paused - timer continues in background');
        break;

      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive');
        break;

      case AppLifecycleState.detached:
        debugPrint('📱 App detached');
        break;

      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  void _loadRoutines() {
    setState(() {
      _routines = DatabaseService.getAllRoutines();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();

    // ✅ Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // ✅ Don't dispose AdvancedPomodoroService here
    // It should keep running in background

    super.dispose();
  }

  void _showSubjectPicker() {
    if (AdvancedPomodoroService.isRoutineMode.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subject is locked in routine mode'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Subject',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: AppConfig.predefinedSubjects.entries.map((entry) {
                  final subject = entry.key;
                  final color = entry.value;
                  final isSelected =
                      AdvancedPomodoroService.currentSubjectName.value ==
                          subject;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      SoundService.playTap();
                      setState(() {
                        AdvancedPomodoroService.setSubject(subject, color);
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.2)
                            : (isDark ? Colors.white10 : Colors.black12),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            subject,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showRoutineCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.9),
                  const Color(0xFF3B82F6).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.celebration,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Routine Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Amazing work! You completed the entire routine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // ✅ Subject picker should only show on Timer tab (cleaner UX)
    final bool showTimerHeaderActions = _activeTabIndex == 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Study Mode',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          if (showTimerHeaderActions) ...[
            // ✅ Subject Selector (Manual Mode Only)
            if (!AdvancedPomodoroService.isRoutineMode.value)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ValueListenableBuilder<String>(
                  valueListenable: AdvancedPomodoroService.currentSubjectName,
                  builder: (context, subjectName, _) {
                    return ValueListenableBuilder<Color>(
                      valueListenable: AdvancedPomodoroService.currentSubjectColor,
                      builder: (context, subjectColor, _) {
                        return GestureDetector(
                          onTap: _showSubjectPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: subjectColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  subjectName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

            // ✅ Routine Mode Indicator
            if (AdvancedPomodoroService.isRoutineMode.value)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF8B5CF6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.playlist_play,
                        size: 16,
                        color: Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Routine Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEF4444),
          labelColor: const Color(0xFFEF4444),
          unselectedLabelColor: textColor.withOpacity(0.5),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(icon: Icon(Icons.timer), text: 'Timer'),
            Tab(icon: Icon(Icons.playlist_play), text: 'Routines'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
            // ✅ Single new tab requested by user
            Tab(icon: Icon(Icons.flag_rounded), text: 'Targets'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Timer
          PomodoroTimerWidget(isDark: isDark),

          // Tab 2: Routines
          _buildRoutinesTab(bgColor, surfaceColor, textColor),

          // Tab 3: Stats
          StudyStatsView(isDark: isDark),

          // Tab 4: Targets & Schedule
          const StudyTargetsScreen(),

          // Tab 5: Settings
          _buildSettingsTab(textColor, surfaceColor),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 2: ROUTINES
  // ═══════════════════════════════════════

  Widget _buildRoutinesTab(Color bgColor, Color surfaceColor, Color textColor) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Study Routines',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_routines.length} routine${_routines.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  SoundService.playTap();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateRoutineScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadRoutines();
                  }
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // Routines List
        Expanded(
          child: _routines.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.playlist_add,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No routines yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first study routine',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _routines.length,
            itemBuilder: (context, index) {
              final routine = _routines[index];
              return RoutineCardWidget(
                routine: routine,
                isDark: isDark,
                onTap: () {
                  _showRoutineOptions(routine);
                },
                onEdit: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateRoutineScreen(editRoutine: routine),
                    ),
                  );
                  if (result == true) {
                    _loadRoutines();
                  }
                },
                onDelete: () {
                  _deleteRoutine(routine);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRoutineOptions(StudyRoutine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                routine.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${routine.sessions.length} sessions • ${routine.getFormattedDuration()}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  SoundService.playSuccess();
                  Navigator.pop(context);
                  AdvancedPomodoroService.startRoutine(routine);
                  _tabController.animateTo(0); // Switch to Timer tab
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(routine.colorValue),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Start Routine',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _deleteRoutine(StudyRoutine routine) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delete Routine?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure you want to delete "${routine.name}"?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.heavyImpact();
                SoundService.playError();
                await DatabaseService.deleteRoutine(routine.id);
                Navigator.pop(context);
                _loadRoutines();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Routine deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════
  // TAB 5: SETTINGS
  // ═══════════════════════════════════════

  Widget _buildSettingsTab(Color textColor, Color surfaceColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timer Durations (Minutes)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingSlider(
            title: 'Focus Time',
            value: DatabaseService.getPomodoroFocusMinutes(),
            min: AppConfig.minFocusMinutes,
            max: AppConfig.maxFocusMinutes,
            color: const Color(0xFFEF4444),
            surfaceColor: surfaceColor,
            textColor: textColor,
            onChanged: (val) {
              setState(() {
                DatabaseService.setPomodoroSettings(
                  focusMins: val.round(),
                  shortBreakMins: DatabaseService.getPomodoroShortBreakMinutes(),
                  longBreakMins: DatabaseService.getPomodoroLongBreakMinutes(),
                );
              });
            },
          ),
          const SizedBox(height: 16),
          _buildSettingSlider(
            title: 'Short Break',
            value: DatabaseService.getPomodoroShortBreakMinutes(),
            min: AppConfig.minBreakMinutes,
            max: AppConfig.maxBreakMinutes,
            color: const Color(0xFF10B981),
            surfaceColor: surfaceColor,
            textColor: textColor,
            onChanged: (val) {
              setState(() {
                DatabaseService.setPomodoroSettings(
                  focusMins: DatabaseService.getPomodoroFocusMinutes(),
                  shortBreakMins: val.round(),
                  longBreakMins: DatabaseService.getPomodoroLongBreakMinutes(),
                );
              });
            },
          ),
          const SizedBox(height: 16),
          _buildSettingSlider(
            title: 'Long Break',
            value: DatabaseService.getPomodoroLongBreakMinutes(),
            min: AppConfig.minBreakMinutes,
            max: AppConfig.maxFocusMinutes,
            color: const Color(0xFF3B82F6),
            surfaceColor: surfaceColor,
            textColor: textColor,
            onChanged: (val) {
              setState(() {
                DatabaseService.setPomodoroSettings(
                  focusMins: DatabaseService.getPomodoroFocusMinutes(),
                  shortBreakMins: DatabaseService.getPomodoroShortBreakMinutes(),
                  longBreakMins: val.round(),
                );
              });
            },
          ),
          const SizedBox(height: 32),

          // Advanced Settings
          Text(
            'Advanced Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'Auto-play Sessions',
                  subtitle: 'Automatically start next session',
                  value: AdvancedPomodoroService.autoPlayEnabled,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  onChanged: (val) async {
                    await AdvancedPomodoroService.setAutoPlay(val);
                    setState(() {});
                  },
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  title: 'Voice Announcements',
                  subtitle: 'Active only in Routine Mode',
                  value: AdvancedPomodoroService.ttsAnnouncementsEnabled,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  onChanged: (val) async {
                    await AdvancedPomodoroService.setTtsAnnouncements(val);
                    setState(() {});
                  },
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  title: 'Keep Screen On',
                  subtitle: 'Prevent screen from sleeping',
                  value: AdvancedPomodoroService.keepScreenOn,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  onChanged: (val) async {
                    await AdvancedPomodoroService.toggleKeepScreenOn();
                    setState(() {});
                  },
                ),
                const Divider(height: 24),
                _buildSwitchTile(
                  title: 'Vibrate on Complete',
                  subtitle: 'Haptic feedback when sessions end',
                  value: AdvancedPomodoroService.vibrateOnComplete,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  onChanged: (val) async {
                    await AdvancedPomodoroService.toggleVibrateOnComplete();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Changes will apply on the next session',
              style: TextStyle(
                color: textColor.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSlider({
    required String title,
    required int value,
    required int min,
    required int max,
    required Color color,
    required Color surfaceColor,
    required Color textColor,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$value min',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min).clamp(1, 9999),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color surfaceColor,
    required Color textColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF10B981),
        ),
      ],
    );
  }
}