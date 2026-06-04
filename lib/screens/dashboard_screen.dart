// lib/screens/dashboard_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/backup_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';
import '../services/leaderboard_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/sound_service.dart';
import '../services/store_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/glassmorphism_nav_bar.dart';
import '../widgets/habit_card.dart';
import '../widgets/life_tree_widget.dart';
import '../widgets/missed_habit_dialog.dart';
import '../widgets/profile_header.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/weekly_calendar_widget.dart';
import 'add_habit_screen.dart';
import 'badges_screen.dart';
import 'leaderboard_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'missions_screen.dart';
import 'node_network_screen.dart';
import 'notes_screen.dart';
import 'notifications_screen.dart';
import 'pro_version_screen.dart';
import 'settings_screen.dart' hide StatisticsScreen;
import 'smart_routine_screen.dart';
import 'statistics_screen.dart';
import 'study_mode_screen.dart';
import 'weekly_review_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Habit> _habits = [];
  bool _isProUser = false;
  bool _isLoading = true;
  late Timer _clockTimer;
  String _currentTime = '';
  int _unreadNotificationCount = 0;
  bool _isRestoring = false;

  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _habitCardKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _moreButtonKey = GlobalKey();
  final GlobalKey _notificationKey = GlobalKey();

  late AnimationController _headerShimmerController;
  late AnimationController _progressPulseController;
  late AnimationController _staggerController;
  late AnimationController _celebrationController;
  late AnimationController _quoteFloatController;
  late AnimationController _statsPopController;
  late AnimationController _bellShakeController;
  late AnimationController _bgAnimationController;
  late AnimationController _progressRingController;
  late AnimationController _levelDownController;
  late AnimationController _habitCelebrationController;

  late Animation<double> _levelDownShake;
  late Animation<double> _headerShimmer;
  late Animation<double> _progressPulse;
  late Animation<double> _quoteFloat;
  late Animation<double> _bellShake;
  late Animation<double> _progressRingAnim;
  late Animation<double> _habitCelebrationScale;
  late Animation<double> _habitCelebrationOpacity;

  bool _treeExpanded = false;
  bool _showWeeklyCalendar = false;
  bool _showCelebration = false;
  double _previousProgress = 0.0;
  bool _missedDialogShown = false;
  int _selectedBottomTab = 0;

  bool _showLevelDownBanner = false;
  int _levelDownFrom = 0;
  int _levelDownTo = 0;
  Timer? _levelDownBannerTimer;

  int _leaderboardRankCache = -1;
  double _leaderboardScoreCache = 0.0;
  bool _leaderboardOptedIn = false;
  bool _leaderboardRefreshing = false;

  String? _celebratingHabitId;

  final List<String> _quotes = [
    '"Small daily improvements lead to staggering results."',
    '"We are what we repeatedly do."',
    '"Success is the sum of small efforts repeated."',
    '"The secret of getting ahead is getting started."',
    '"Motivation gets you going, habit keeps you growing."',
    '"Your future is created by what you do today."',
    '"Discipline is choosing between what you want now and what you want most."',
    '"The only way to do great work is to love what you do."',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _headerShimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _headerShimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _headerShimmerController, curve: Curves.easeInOut));

    _progressPulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _progressPulse = Tween<double>(begin: 0.97, end: 1.03).animate(
        CurvedAnimation(parent: _progressPulseController, curve: Curves.easeInOutSine));

    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward();

    _celebrationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800));

    _quoteFloatController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat(reverse: true);
    _quoteFloat = Tween<double>(begin: -4.0, end: 4.0).animate(
        CurvedAnimation(parent: _quoteFloatController, curve: Curves.easeInOutSine));

    _statsPopController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _bellShakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bellShake = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _bellShakeController, curve: Curves.elasticOut));

    _levelDownController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _levelDownShake = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _levelDownController, curve: Curves.elasticOut));

    _bgAnimationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat(reverse: true);

    _progressRingController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _progressRingAnim = CurvedAnimation(
        parent: _progressRingController, curve: Curves.easeOutCubic);

    _habitCelebrationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _habitCelebrationScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _habitCelebrationController, curve: Curves.easeOutCubic));
    _habitCelebrationOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _habitCelebrationController, curve: Curves.easeOut));

    BadgeService.onLevelDown = _handleLevelDown;

    _loadData();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
    _showMissedHabitDialogIfNeeded();
    _checkAndShowTutorial();

    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      try { await BadgeService.processMissedHabitsXpDeduction(); } catch (_) {}
    });

    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      try { await NotificationService.scheduleEveningPsychologyNudges(); } catch (_) {}
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _statsPopController.forward();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _progressRingController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _unreadNotificationCount > 0) _bellShakeController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer.cancel();
    _levelDownBannerTimer?.cancel();
    _headerShimmerController.dispose();
    _progressPulseController.dispose();
    _staggerController.dispose();
    _celebrationController.dispose();
    _quoteFloatController.dispose();
    _statsPopController.dispose();
    _bellShakeController.dispose();
    _levelDownController.dispose();
    _bgAnimationController.dispose();
    _progressRingController.dispose();
    _habitCelebrationController.dispose();
    BadgeService.onLevelDown = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // ConnectivityService handles backup
    }
  }

  // ═══════════════════════════════════════
  // GLASS CONTAINER
  // ═══════════════════════════════════════

  Widget _buildGlassContainer({
    required Widget child, required bool isDark,
    double borderRadius = 24.0, EdgeInsets padding = const EdgeInsets.all(20),
    List<Color>? gradientColors, bool hasBorder = true, double blurSigma = 25,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight)
                : LinearGradient(
                colors: isDark
                    ? [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)]
                    : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.55)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder ? Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.85), width: 1.2) : null,
            boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.45) : AppConfig.primaryColor.withOpacity(0.06), blurRadius: 28, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // LEVEL DOWN
  // ═══════════════════════════════════════

  void _handleLevelDown(int oldLevel, int newLevel) {
    if (!mounted) return;
    setState(() { _showLevelDownBanner = true; _levelDownFrom = oldLevel; _levelDownTo = newLevel; });
    HapticFeedback.heavyImpact();
    SoundService.playError();
    _levelDownController.forward(from: 0);
    NotificationService.sendLevelDownNotification(oldLevel: oldLevel, newLevel: newLevel).catchError((_) {});
    _levelDownBannerTimer?.cancel();
    _levelDownBannerTimer = Timer(const Duration(seconds: 5), () { if (mounted) setState(() => _showLevelDownBanner = false); });
  }

  // ═══════════════════════════════════════
  // TUTORIAL & MISSED
  // ═══════════════════════════════════════

  Future<void> _checkAndShowTutorial() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    if (TutorialService.shouldShowTutorial()) {
      TutorialService.showDashboardTutorial(context,
          addButtonKey: _addButtonKey, habitCardKey: _habitCardKey,
          statsKey: _statsKey, moreButtonKey: _moreButtonKey, notificationKey: _notificationKey);
    }
  }

  Future<void> _showMissedHabitDialogIfNeeded() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted || _missedDialogShown) return;
    _missedDialogShown = true;
    final interacted = await MissedHabitDialog.show(context);
    if (interacted == true && mounted) {
      if (AppConfig.enableSmartReminders) {
        await NotificationService.scheduleSmartRemindersForMissedHabits();
        await NotificationService.rescheduleAllWithSmartMessages();
      }
      _loadData();
    }
  }

  // ═══════════════════════════════════════
  // DATA
  // ═══════════════════════════════════════

  void _loadData() {
    if (!mounted) return;
    setState(() {
      _habits = DatabaseService.getAllHabits();
      _isProUser = DatabaseService.isProOrVipUser();
      _isLoading = false;
      _unreadNotificationCount = DatabaseService.getUnreadNotificationCount();
      BadgeService.checkAllBadges();

      final currentLevel = BadgeService.getLevel();
      final lastLevel = DatabaseService.getLastKnownLevel();
      if (currentLevel > lastLevel) {
        SoundService.playLevelUp();
        DatabaseService.setLastKnownLevel(currentLevel);
        _showLevelUpSnack(currentLevel);
      }

      for (final h in _habits) {
        if ([7, 14, 21, 30, 50, 100].contains(h.currentStreak)) { SoundService.playStreakMilestone(); break; }
      }

      final newProgress = _progressPercent();
      if (_previousProgress < 100 && newProgress == 100 && _habits.isNotEmpty) _trigger100PercentCelebration();
      _previousProgress = newProgress;
      _updateLeaderboardLocalCacheOnly();
    });
    _progressRingController.forward(from: 0);
    if (_unreadNotificationCount > 0 && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _bellShakeController.forward(from: 0); });
    }
  }

  void _updateLeaderboardLocalCacheOnly() {
    final user = AuthService.instance.currentUser;
    if (user == null) { _leaderboardRankCache = -1; _leaderboardScoreCache = 0.0; _leaderboardOptedIn = false; return; }
    final p = DatabaseService.getLeaderboardProfileForUid(user.uid);
    _leaderboardOptedIn = p?.isOptedIn ?? false;
    _leaderboardRankCache = p?.cachedRank ?? -1;
    _leaderboardScoreCache = p?.cachedScore ?? 0.0;
  }

  Future<void> _refreshLeaderboardCacheIfNeeded({required bool force}) async {
    if (_leaderboardRefreshing) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final p = DatabaseService.getLeaderboardProfileForUid(user.uid);
    if (p == null || !p.isOptedIn) return;
    final last = p.lastCloudSyncAt;
    final isFresh = last != null && DateTime.now().difference(last).inMinutes < 120;
    if (!force && isFresh) return;

    setState(() => _leaderboardRefreshing = true);
    try {
      await LeaderboardService.instance.getLeaderboardSnapshot(topLimit: 20, syncBeforeFetch: true);
      if (!mounted) return;
      setState(() => _updateLeaderboardLocalCacheOnly());
    } catch (_) {} finally {
      if (mounted) setState(() => _leaderboardRefreshing = false);
    }
  }

  // ═══════════════════════════════════════
  // ✅ SIGN-IN — NEVER AUTO POPUP
  // Only when user explicitly taps a button
  // ═══════════════════════════════════════

  Future<bool> _safeSignInIfNeeded() async {
    if (AuthService.instance.currentUser != null) return true;

    // ✅ Offline check — no popup
    if (!ConnectivityService.instance.isOnline) {
      _showSnack('You are offline. Please connect to the internet first.', isError: true);
      return false;
    }

    // ✅ Permission dialog FIRST — Google Play Policy compliant
    final userWantsToSignIn = await _showSignInPermissionDialog();
    if (userWantsToSignIn != true) return false;

    // ✅ User explicitly agreed — now show Google Sign-In
    try {
      final user = await AuthService.instance.ensureSignedInOnDemand(interactive: true);
      if (user == null) return false;

      // ✅ Sign-in successful — restore from cloud
      await _restoreFromCloudAfterSignIn(user.uid);
      return true;
    } catch (e) {
      _showSnack('Sign-in failed: ${_prettyError(e)}', isError: true);
      return false;
    }
  }

  // ✅ Permission dialog — appears BEFORE Google Sign-In
  // This is Google Play Policy compliant
  Future<bool?> _showSignInPermissionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sign In',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151C2F) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppConfig.primaryColor.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : AppConfig.primaryColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppConfig.primaryColor.withOpacity(0.2),
                          AppConfig.accentColor.withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('🔐', style: TextStyle(fontSize: 36))),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Sign in with Google',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  Text(
                    'Sign in to sync your habits across devices, '
                        'access the global leaderboard, chat with other users, '
                        'and automatically backup your data to Google Drive.\n\n'
                        'You can continue using the app without signing in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // What we access
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('We will access:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white60 : Colors.black45)),
                        const SizedBox(height: 8),
                        _permissionRow('📧', 'Email address', 'For account identification', isDark),
                        const SizedBox(height: 6),
                        _permissionRow('👤', 'Display name', 'For your profile', isDark),
                        const SizedBox(height: 6),
                        _permissionRow('☁️', 'Google Drive', 'For automatic backup (optional)', isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'Not now',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            SoundService.playTap();
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConfig.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🔑', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Text('Sign in', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _permissionRow(String emoji, String title, String desc, bool isDark) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$title ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                TextSpan(text: '— $desc', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // ✅ RESTORE FROM CLOUD
  // ═══════════════════════════════════════

  Future<void> _restoreFromCloudAfterSignIn(String uid) async {
    if (_isRestoring) return;
    try {
      setState(() => _isRestoring = true);

      final isOnline = await _hasNetworkConnection();
      if (!isOnline) { _loadData(); return; }

      try {
        final driveService = GoogleDriveService();
        final backupInfo = await driveService.getExistingBackupInfoOnDemand().timeout(const Duration(seconds: 10));
        if (backupInfo == null) { _loadData(); return; }

        final result = await driveService.restoreAllDataFromCloudOnDemand(source: RestoreSource.dashboard).timeout(const Duration(seconds: 30));

        _loadData();
        try { await BadgeService.checkAllBadges(); } catch (_) {}

        if (mounted) {
          final total = result.habitsImported + result.notesImported;
          if (total > 0) {
            _showSnack('✅ ${result.habitsImported} habits${result.notesImported > 0 ? " & ${result.notesImported} notes" : ""} restored!', isError: false);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Dashboard restore failed: $e');
        _loadData();
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) { return false; }
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  void _showLevelUpSnack(int level) {
    if (!mounted) return;
    final levelInfo = AppConfig.getLevelInfo(level);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showSnack("Level Up! Level $level — ${levelInfo['title']}! 🎉", isError: false);
    });
  }

  void _updateTime() { if (!mounted) return; setState(() => _currentTime = DateFormat('hh:mm a').format(DateTime.now())); }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = DatabaseService.getUserName();
    final d = name.isNotEmpty && name != 'Habit Hero' ? ', $name' : '';
    if (hour < 5) return 'Good Night$d';
    if (hour < 12) return 'Good Morning$d';
    if (hour < 17) return 'Good Afternoon$d';
    if (hour < 21) return 'Good Evening$d';
    return 'Good Night$d';
  }

  String _getGreetingEmoji() { final h = DateTime.now().hour; if (h < 5) return '🌙'; if (h < 12) return '☀️'; if (h < 17) return '🌤️'; if (h < 21) return '🌆'; return '🌙'; }

  int _completedToday() => _habits.where((e) => e.isCompletedToday()).length;

  double _progressPercent() { if (_habits.isEmpty) return 0; return (_completedToday() / _habits.length) * 100; }

  String _getQuote() { final d = DateTime.now().difference(DateTime(DateTime.now().year)).inDays; return _quotes[d % _quotes.length]; }

  int _bestCurrentStreak() { int best = 0; for (final h in _habits) { if (h.currentStreak > best) best = h.currentStreak; } return best; }

  void _trigger100PercentCelebration() {
    SoundService.playAllComplete();
    setState(() => _showCelebration = true);
    _celebrationController.forward(from: 0).then((_) { if (mounted) setState(() => _showCelebration = false); });
  }

  void _triggerHabitCelebration(String habitId) {
    setState(() => _celebratingHabitId = habitId);
    _habitCelebrationController.forward(from: 0).then((_) { if (mounted) setState(() => _celebratingHabitId = null); });
  }

  Color _progressColor(double percent, {required bool isDark}) {
    final p = (percent / 100.0).clamp(0.0, 1.0);
    Color out;
    if (p <= 0.5) { out = Color.lerp(AppConfig.errorColor, AppConfig.warningColor, p / 0.5)!; }
    else { out = Color.lerp(AppConfig.warningColor, AppConfig.successColor, (p - 0.5) / 0.5)!; }
    if (isDark) return Color.lerp(out, Colors.white, 0.12)!;
    return out;
  }

  // ═══════════════════════════════════════
  // NAVIGATION — NO AUTO LOGIN
  // ═══════════════════════════════════════

  Future<void> _handleBottomNavTap(int index) async {
    if (_selectedBottomTab == index && index == 0) return;
    HapticFeedback.lightImpact(); SoundService.playTap();
    setState(() => _selectedBottomTab = index);
    switch (index) {
      case 0: break;
      case 1: await Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())); _loadData(); break;
      case 2: await Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())); _loadData(); break;
    }
    if (mounted) setState(() => _selectedBottomTab = 0);
  }

  Future<void> _openNotificationsScreen() async {
    HapticFeedback.lightImpact(); SoundService.playTap();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _loadData();
  }

  Future<void> _openMissedHabitFeedback() async {
    HapticFeedback.lightImpact(); SoundService.playTap();
    final m = DatabaseService.getMissedHabitsYesterday();
    if (m.isEmpty) { _showSnack('No missed habits from yesterday. Keep it up! 🎉', isError: false); return; }
    final interacted = await MissedHabitDialog.showForced(context);
    if (interacted == true && mounted) {
      if (AppConfig.enableSmartReminders) { await NotificationService.scheduleSmartRemindersForMissedHabits(); await NotificationService.rescheduleAllWithSmartMessages(); }
      _loadData();
    }
  }

  Future<void> _openStudyMode() async {
    HapticFeedback.mediumImpact(); SoundService.playTap();
    await Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => const StudyModeScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
      transitionDuration: const Duration(milliseconds: 400),
    ));
    _loadData();
  }

  Future<void> _openNodeNetwork() async {
    HapticFeedback.mediumImpact(); SoundService.playTap();
    await Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => const NodeNetworkScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
      transitionDuration: const Duration(milliseconds: 400),
    ));
    _loadData();
  }

  // ✅ Profile — uses _safeSignInIfNeeded (permission dialog first)
  Future<void> _openMyProfileFromDashboard() async {
    HapticFeedback.lightImpact(); SoundService.playTap();

    if (AuthService.instance.currentUser == null) {
      final ok = await _safeSignInIfNeeded();
      if (!ok) return;
    }

    if (!mounted || AuthService.instance.currentUser == null) return;

    final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardProfileScreen()));
    if (changed == true) { _loadData(); await _refreshLeaderboardCacheIfNeeded(force: true); }
    else { _loadData(); }
  }

  // ✅ Leaderboard — uses _safeSignInIfNeeded (permission dialog first)
  Future<void> _openLeaderboardFromDashboard() async {
    HapticFeedback.lightImpact(); SoundService.playTap();

    if (AuthService.instance.currentUser == null) {
      final ok = await _safeSignInIfNeeded();
      if (!ok) return;
    }

    if (!mounted) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final p = DatabaseService.getLeaderboardProfileForUid(user.uid);
    if (p == null || !p.isOptedIn) {
      final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardProfileScreen()));
      if (r == true) { _loadData(); await _refreshLeaderboardCacheIfNeeded(force: true); }
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
    _loadData();
  }

  String _prettyError(Object e) {
    final m = e.toString();
    if (m.contains('Sign-in cancelled')) return 'Sign-in cancelled.';
    if (m.contains('No internet') || m.contains('network')) return 'No network.';
    return m.replaceAll('AuthServiceException:', '').replaceAll('ProfileServiceException:', '').replaceAll('LeaderboardServiceException:', '').trim();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.transparent, elevation: 0, behavior: SnackBarBehavior.floating, padding: EdgeInsets.zero,
      content: _buildGlassContainer(isDark: true, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        gradientColors: isError
            ? [AppConfig.errorColor.withOpacity(0.95), Colors.redAccent.withOpacity(0.85)]
            : [const Color(0xFF1E293B).withOpacity(0.98), const Color(0xFF0F172A).withOpacity(0.98)],
        child: Row(children: [
          Icon(isError ? Icons.warning_rounded : Icons.check_circle_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14, height: 1.3))),
        ]),
      ),
    ));
  }

  // ═══════════════════════════════════════
  // HABIT ACTIONS
  // ═══════════════════════════════════════

  void _addNewHabitDirect() async {
    HapticFeedback.lightImpact(); SoundService.playTap();
    final extra = DatabaseService.getRewardedExtraHabits();
    if (!_isProUser && _habits.length >= AppConfig.maxHabitsFree + extra) { _showLimitDialog(); return; }
    final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHabitScreen()));
    if (r == true) { await AdService.registerMeaningfulAction(); await BadgeService.checkAllBadges(); _loadData(); }
  }

  void _editHabit(Habit h) async {
    SoundService.playTap();
    final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddHabitScreen(habitToEdit: h)));
    if (r == true) { await AdService.registerMeaningfulAction(); _loadData(); }
  }

  void _deleteHabit(Habit habit) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: Colors.transparent, elevation: 0, contentPadding: EdgeInsets.zero,
      content: _buildGlassContainer(isDark: isDark, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: AppConfig.errorColor.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.delete_forever_rounded, color: AppConfig.errorColor, size: 28)),
        const SizedBox(height: 20),
        Text('Delete Habit', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        Text('Delete "${habit.name}"?\nThis cannot be undone.', textAlign: TextAlign.center, style: TextStyle(height: 1.5, fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w700, fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppConfig.errorColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)))),
        ]),
      ])),
    ));
    if (ok == true) { SoundService.playHabitDeleted(); HapticFeedback.heavyImpact(); await DatabaseService.deleteHabit(habit.id); await AdService.registerMeaningfulAction(); _loadData(); }
  }

  void _showLimitDialog() {
    final extra = DatabaseService.getRewardedExtraHabits();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: Colors.transparent, elevation: 0, contentPadding: EdgeInsets.zero,
      content: _buildGlassContainer(isDark: isDark, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: AppConfig.warningColor.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.lock_rounded, color: AppConfig.warningColor, size: 28)),
        const SizedBox(height: 20),
        Text('Habit Limit Reached', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 14),
        Text('Free: ${AppConfig.maxHabitsFree + extra} habits.\nWatch ad for ${AppConfig.rewardedExtraHabits} more or go Pro.', textAlign: TextAlign.center, style: TextStyle(height: 1.5, fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 28),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProVersionScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: AppConfig.primaryColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: const Text('Upgrade to Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () async { Navigator.pop(context); if (!mounted) return; bool s = false; try { s = await AdService.showRewardedUnlockHabits(); } catch (_) {} if (!mounted) return; _showSnack(s ? 'Unlocked ${AppConfig.rewardedExtraHabits} extra! 🎉' : 'Ad not available.', isError: !s); if (s) { SoundService.playSuccess(); _loadData(); } }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: AppConfig.primaryColor.withOpacity(0.5), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Watch Ad', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w800, fontSize: 16))),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Maybe Later', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w700, fontSize: 15))),
        ]),
      ])),
    ));
  }

  // ═══════════════════════════════════════
  // MORE MENU
  // ═══════════════════════════════════════

  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (sc) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic,
        builder: (context, value, child) => Transform.translate(offset: Offset(0, 60 * (1 - value)), child: Opacity(opacity: value, child: child)),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isDark ? [const Color(0xFF0D1422).withOpacity(0.95), const Color(0xFF020408).withOpacity(0.98)] : [Colors.white.withOpacity(0.97), const Color(0xFFEEF2FF).withOpacity(0.92)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.12) : AppConfig.primaryColor.withOpacity(0.15), width: 1.5)),
              ),
              child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 52, height: 5, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppConfig.primaryColor.withOpacity(0.5), AppConfig.accentColor.withOpacity(0.3)]), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 28),
                Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppConfig.primaryColor.withOpacity(0.25), AppConfig.accentColor.withOpacity(0.12)]), borderRadius: BorderRadius.circular(16)), child: const Text('🍅', style: TextStyle(fontSize: 22))),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Control Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                    Text('Quick access to all features', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w600)),
                  ]),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(sc), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white60 : Colors.black45))),
                ]),
                const SizedBox(height: 28),
                GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.88, mainAxisSpacing: 14, crossAxisSpacing: 14, children: [
                  _mi('🍅', 'Focus Mode', const Color(0xFFEF4444), isDark, onTap: () { Navigator.pop(sc); _openStudyMode(); }),
                  _mi('🌍', 'Leaderboard', const Color(0xFF0EA5E9), isDark, onTap: () { Navigator.pop(sc); _openLeaderboardFromDashboard(); }),
                  _mi('🧠', 'Routines', const Color(0xFF10B981), isDark, isPro: !_isProUser, onTap: () { Navigator.pop(sc); Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartRoutineScreen())).then((r) { if (r == true) _loadData(); }); }),
                  _mi('🚀', 'Missions', const Color(0xFFF97316), isDark, onTap: () { Navigator.pop(sc); Navigator.push(context, MaterialPageRoute(builder: (_) => const MissionsScreen())).then((r) { if (r == true) _loadData(); }); }),
                  _mi('📋', 'Review', const Color(0xFF3B82F6), isDark, onTap: () { Navigator.pop(sc); Future.microtask(() { if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => WeeklyReviewScreen(habits: _habits))).then((_) => _loadData()); }); }),
                  _mi('📊', 'Statistics', const Color(0xFF8B5CF6), isDark, onTap: () { Navigator.pop(sc); Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())).then((_) => _loadData()); }),
                  _mi('📝', 'Notes', const Color(0xFFFFB300), isDark, onTap: () { Navigator.pop(sc); Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen())).then((_) => _loadData()); }),
                  _mi('🕸️', 'Network', AppConfig.primaryColor, isDark, onTap: () { Navigator.pop(sc); _openNodeNetwork(); }),
                  _mi('⚙️', 'Settings', const Color(0xFF64748B), isDark, onTap: () { Navigator.pop(sc); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadData()); }),
                ]),
                const SizedBox(height: 28),
                Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06), Colors.transparent]))),
                const SizedBox(height: 20),
                Row(children: [
                  if (!_isProUser) Expanded(child: _cmi(Icons.star_rounded, 'Go Pro', const Color(0xFFFFD700), isDark, () { Navigator.pop(sc); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProVersionScreen())).then((_) => _loadData()); })),
                  if (!_isProUser) const SizedBox(width: 12),
                  Expanded(child: _cmi(Icons.share_rounded, 'Share', const Color(0xFF06B6D4), isDark, () { Navigator.pop(sc); try { StoreService.shareApp(context); } catch (_) {} })),
                ]),
              ])),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mi(String emoji, String label, Color color, bool isDark, {bool isPro = false, required VoidCallback onTap}) {
    return GestureDetector(onTap: () { SoundService.playTap(); HapticFeedback.lightImpact(); onTap(); },
      child: TweenAnimationBuilder<double>(tween: Tween(begin: 0.8, end: 1.0), duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(isDark ? 0.16 : 0.12), color.withOpacity(isDark ? 0.07 : 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.22), width: 1.2), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 5))]),
          child: Stack(children: [
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)), child: Text(emoji, style: const TextStyle(fontSize: 28))), const SizedBox(height: 10), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 1)])),
            if (isPro) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]), borderRadius: BorderRadius.circular(8)), child: const Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)))),
          ]),
        ),
      ),
    );
  }

  Widget _cmi(IconData icon, String label, Color color, bool isDark, VoidCallback onTap) {
    return GestureDetector(onTap: () { SoundService.playTap(); HapticFeedback.lightImpact(); onTap(); },
      child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(isDark ? 0.14 : 0.1), color.withOpacity(isDark ? 0.06 : 0.04)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25), width: 1.2), boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 24), const SizedBox(height: 8), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 1)]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _progressPercent();
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final topSafe = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 1500), curve: Curves.easeInOutSine, decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? const [Color(0xFF070B14), Color(0xFF101828), Color(0xFF020408)] : const [Color(0xFFF4F7FC), Color(0xFFE2E8F0), Color(0xFFEEF2FF)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
          AnimatedBuilder(animation: _bgAnimationController, builder: (context, _) { final t = _bgAnimationController.value * 2 * pi; return Stack(children: [Positioned(top: -60 + (35 * sin(t)), left: -110 + (35 * cos(t)), child: Container(width: 420, height: 420, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppConfig.primaryColor.withOpacity(isDark ? 0.08 : 0.06), Colors.transparent])))), Positioned(bottom: -120 + (45 * cos(t * 0.8)), right: -60 + (25 * sin(t * 1.2)), child: Container(width: 340, height: 340, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppConfig.accentColor.withOpacity(isDark ? 0.06 : 0.04), Colors.transparent]))))]); }),
          Positioned(top: 0, left: 0, right: 0, height: topSafe + 8, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [const Color(0xFF070B14), const Color(0xFF070B14).withOpacity(0.85), Colors.transparent] : [const Color(0xFF1E293B).withOpacity(0.88), const Color(0xFF334155).withOpacity(0.6), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
          Column(children: [
            Expanded(child: RefreshIndicator(
              onRefresh: () async { SoundService.playTap(); _loadData(); await _refreshLeaderboardCacheIfNeeded(force: false); },
              color: AppConfig.primaryColor, backgroundColor: isDark ? const Color(0xFF101828) : Colors.white,
              child: CustomScrollView(physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), slivers: [
                SliverToBoxAdapter(child: _buildPremiumHeader(isDark, progress)),
                if (_showLevelDownBanner) SliverToBoxAdapter(child: _buildLevelDownBanner(isDark)),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0), child: _isLoading ? const SkeletonLoader(height: 120, borderRadius: 24) : const ProfileHeader())),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: _isLoading ? const SkeletonLoader(height: 70, borderRadius: 20) : _buildWeeklyCalendar(isDark))),
                SliverToBoxAdapter(key: _statsKey, child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: _isLoading ? const SkeletonLoader(height: 140, borderRadius: 24) : _buildQuickStats(isDark))),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: _buildQuoteCard(isDark))),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 36, 20, 20), child: _buildHabitsHeader(isDark))),
                _isLoading
                    ? SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const Padding(padding: EdgeInsets.only(bottom: 16), child: SkeletonLoader(height: 100, borderRadius: 20)), childCount: 4)))
                    : _habits.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyState(isDark))
                    : SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _buildHabitItem(i, isDark), childCount: _habits.length, findChildIndexCallback: (key) { if (key is ValueKey<String>) { final idx = _habits.indexWhere((h) => h.id == key.value); return idx >= 0 ? idx : null; } return null; }))),
                SliverToBoxAdapter(child: SizedBox(height: 160 + bottomSafe + ((AppConfig.enableAds && !_isProUser) ? 60 : 0))),
              ]),
            )),
            _buildBottomSection(isDark, bottomSafe),
          ]),
          if (_isRestoring) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4), child: Center(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? const Color(0xFF151C2F) : Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: AppConfig.primaryColor), const SizedBox(height: 16), Text('Restoring your data...', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))]))))),
          if (_showCelebration) Positioned.fill(child: _buildCelebrationOverlay()),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // HABIT ITEM — ValueKey fix
  // ═══════════════════════════════════════

  Widget _buildHabitItem(int index, bool isDark) {
    final habit = _habits[index];
    final delay = (0.1 + (index * 0.1)).clamp(0.0, 0.8);
    final slideAnim = Tween<Offset>(begin: const Offset(0.4, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _staggerController, curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic)));
    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _staggerController, curve: Interval(delay, (delay + 0.3).clamp(0.0, 1.0), curve: Curves.easeOut)));

    final isCelebrating = _celebratingHabitId == habit.id;

    Widget card = HabitCard(key: ValueKey<String>(habit.id), habit: habit,
      onToggle: () async {
        final wasCompleted = habit.isCompletedToday();
        await DatabaseService.updateHabit(habit);
        await AdService.registerMeaningfulAction();
        if (habit.isCompletedToday()) { await BadgeService.onHabitCompleted(habit); if (!wasCompleted) { _triggerHabitCelebration(habit.id); HapticFeedback.mediumImpact(); } }
        _loadData();
      },
      onEdit: () => _editHabit(habit), onDelete: () => _deleteHabit(habit),
    );

    if (isCelebrating) {
      card = AnimatedBuilder(animation: _habitCelebrationController, builder: (ctx, child) => Transform.scale(scale: _habitCelebrationScale.value, child: Stack(clipBehavior: Clip.none, children: [child!, Positioned.fill(child: IgnorePointer(child: Opacity(opacity: _habitCelebrationOpacity.value, child: _buildParticles())))])), child: card);
    }

    return FadeTransition(key: ValueKey<String>(habit.id), opacity: fadeAnim, child: SlideTransition(position: slideAnim, child: Padding(padding: const EdgeInsets.only(bottom: 16), child: card)));
  }

  Widget _buildParticles() {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(children: List.generate(12, (i) {
        final rng = Random(i * 42); final angle = (i / 12) * 2 * pi; final radius = 30.0 + rng.nextDouble() * 50; final size = 6.0 + rng.nextDouble() * 10;
        final colors = [const Color(0xFFFFD700), const Color(0xFF00E676), const Color(0xFF42A5F5), const Color(0xFFFF7043), const Color(0xFFAB47BC), const Color(0xFF26C6DA)];
        final c = colors[i % colors.length]; final emojis = ['✨', '⭐', '🌟', '💫', '🎉', '🔥'];
        return AnimatedBuilder(animation: _habitCelebrationController, builder: (context, _) {
          final p = _habitCelebrationController.value; final dx = cos(angle) * radius * p; final dy = sin(angle) * radius * p - (20 * p); final opacity = (1.0 - p).clamp(0.0, 1.0);
          return Positioned(left: constraints.maxWidth / 2 + dx - size / 2, top: constraints.maxHeight / 2 + dy - size / 2, child: Opacity(opacity: opacity, child: Transform.rotate(angle: p * pi * 2, child: i % 3 == 0 ? Text(emojis[i % emojis.length], style: TextStyle(fontSize: size)) : Container(width: size, height: size, decoration: BoxDecoration(color: c, shape: i % 2 == 0 ? BoxShape.circle : BoxShape.rectangle, borderRadius: i % 2 != 0 ? BorderRadius.circular(2) : null, boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)])))));
        });
      }));
    });
  }

  // ═══════════════════════════════════════
  // HEADER + ALL UI WIDGETS
  // (Same as before — no changes needed)
  // ═══════════════════════════════════════

  Widget _buildPremiumHeader(bool isDark, double progress) {
    return AnimatedBuilder(animation: Listenable.merge([_headerShimmerController, _progressPulseController]), builder: (context, _) {
      return Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
        decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.4), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(isDark ? 0.08 : 0.4), width: 1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTopRow(isDark),
          const SizedBox(height: 28),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Flexible(child: Text('${_getGreeting()} ${_getGreetingEmoji()}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.8, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis)), if (_isProUser) const Padding(padding: EdgeInsets.only(left: 10), child: Text('👑', style: TextStyle(fontSize: 24)))]),
              const SizedBox(height: 10),
              Text(DateFormat('EEEE, MMMM d').format(DateTime.now()), style: TextStyle(color: isDark ? Colors.white60 : Colors.black45, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              if (_leaderboardOptedIn) ...[const SizedBox(height: 16), _buildLeaderboardRank()],
            ])),
            const SizedBox(width: 16),
            GestureDetector(onTap: () { HapticFeedback.lightImpact(); SoundService.playTap(); setState(() => _treeExpanded = !_treeExpanded); }, child: AnimatedContainer(duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack, width: _treeExpanded ? 140 : 110, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 8)]), child: LifeTreeWidget.fromServices(width: _treeExpanded ? 140 : 110, height: _treeExpanded ? 150 : 120))),
          ]),
          const SizedBox(height: 24),
          SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), clipBehavior: Clip.none, child: Row(children: [
            _pill(Icons.military_tech_rounded, '${ProfileService.getLevelInfo()['emoji']} Lv.${ProfileService.getLevel()}', const Color(0xFFFFD700), isDark),
            const SizedBox(width: 10), _pill(Icons.local_fire_department_rounded, '${_bestCurrentStreak()} Streak', const Color(0xFFFF7A00), isDark),
            const SizedBox(width: 10), _pill(Icons.emoji_events_rounded, '${ProfileService.getBadgesUnlocked()} Badges', const Color(0xFF00E676), isDark),
            const SizedBox(width: 10), _buildTreeHealthPill(isDark),
            if (DatabaseService.isVipUser()) ...[const SizedBox(width: 10), _pill(Icons.diamond_rounded, 'VIP', const Color(0xFFE0B0FF), isDark)],
          ])),
          const SizedBox(height: 28),
          Transform.scale(scale: _progressPulse.value, child: _buildProgressCard(progress, isDark)),
        ]),
      );
    });
  }

  Widget _pill(IconData icon, String text, Color color, bool isDark) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)] : [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.7)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.white, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Text(text, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)]));

  Widget _buildTreeHealthPill(bool isDark) { final level = BadgeService.getLevel(); int bestStreak = 0, ct = 0; for (final h in _habits) { if (h.bestStreak > bestStreak) bestStreak = h.bestStreak; if (h.isCompletedToday()) ct++; } final tr = _habits.isNotEmpty ? (ct / _habits.length) : 0.0; final sm = DatabaseService.getTotalStudyMinutesAllTime(); final health = (((level / 20.0).clamp(0.0, 1.0) * 0.35) + ((bestStreak / 100.0).clamp(0.0, 1.0) * 0.25) + ((sm / 3000.0).clamp(0.0, 1.0) * 0.20) + (tr.clamp(0.0, 1.0) * 0.20)).clamp(0.0, 1.0); String e = '🌱'; Color c = const Color(0xFF86EFAC); if (health >= 0.75) { e = '🌴'; c = const Color(0xFFFFD700); } else if (health >= 0.55) { e = '🌲'; c = const Color(0xFF16A34A); } else if (health >= 0.35) { e = '🌳'; c = const Color(0xFF22C55E); } else if (health >= 0.15) { e = '🌿'; c = const Color(0xFF4ADE80); } return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.4), width: 1.5)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(e, style: const TextStyle(fontSize: 16)), const SizedBox(width: 8), Text('${(health * 100).toInt()}%', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900))])); }

  Widget _buildLeaderboardRank() { final r = _leaderboardRankCache; final has = r > 0; final c = has ? (r <= 3 ? const Color(0xFFFFD700) : const Color(0xFF93C5FD)) : AppConfig.primaryColor; return InkWell(onTap: _leaderboardRefreshing ? null : _openLeaderboardFromDashboard, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: c.withOpacity(0.35), width: 1.5)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.public_rounded, size: 18, color: c), const SizedBox(width: 10), Flexible(child: Text(has ? 'Global Rank: #$r' : 'Global Rank: —', style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)), if (_leaderboardRefreshing) ...[const SizedBox(width: 12), SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2.5, color: c))]]))); }

  Widget _buildProgressCard(double progress, bool isDark) {
    final safe = progress.clamp(0.0, 100.0); final pc = _progressColor(safe, isDark: isDark); final done = _completedToday(); final total = _habits.length;
    return _buildGlassContainer(isDark: isDark, padding: const EdgeInsets.all(24), borderRadius: 28, child: Row(children: [
      AnimatedBuilder(animation: _progressRingController, builder: (context, _) { final av = (safe / 100.0) * _progressRingAnim.value; return SizedBox(width: 110, height: 110, child: CustomPaint(painter: _PremiumProgressPainter(progress: av, progressColor: pc, backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06), strokeWidth: 10, glowColor: pc.withOpacity(0.4)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('${safe.toInt()}', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 32, height: 1)), Text('%', style: TextStyle(color: pc, fontWeight: FontWeight.w800, fontSize: 16))])))); }),
      const SizedBox(width: 24),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Daily Progress', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)), const SizedBox(height: 8),
        RichText(text: TextSpan(children: [TextSpan(text: '$done', style: TextStyle(color: pc, fontWeight: FontWeight.w900, fontSize: 28)), TextSpan(text: ' / $total', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w700, fontSize: 20))])),
        const SizedBox(height: 6), Text('habits completed', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: AnimatedBuilder(animation: _progressRingController, builder: (context, _) => LinearProgressIndicator(value: (safe / 100.0) * _progressRingAnim.value, minHeight: 8, backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05), valueColor: AlwaysStoppedAnimation<Color>(pc)))),
        const SizedBox(height: 12), Text(safe >= 100 ? '🔥 All habits completed! Amazing!' : safe >= 50 ? '💪 Great momentum! Keep going!' : total == 0 ? '✨ Add your first habit to begin' : '🚀 Start completing your habits!', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]));
  }

  Widget _buildTopRow(bool isDark) {
    final missed = DatabaseService.getMissedHabitsYesterday();
    return Row(children: [
      _buildGlassContainer(isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), borderRadius: 20, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.access_time_filled_rounded, color: isDark ? Colors.white : AppConfig.primaryColor, size: 16), const SizedBox(width: 8), Text(_currentTime, style: TextStyle(color: isDark ? Colors.white : AppConfig.primaryColor, fontWeight: FontWeight.w900, fontSize: 14))])),
      const Spacer(),
      if (missed.isNotEmpty) GestureDetector(onTap: _openMissedHabitFeedback, child: Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Text('${missed.length}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 12))), const SizedBox(width: 8), const Icon(Icons.feedback_rounded, color: Colors.white, size: 18)]))),
      if (!_isProUser) GestureDetector(onTap: () { SoundService.playTap(); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProVersionScreen())).then((_) => _loadData()); }, child: Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, color: Colors.white, size: 18), SizedBox(width: 6), Text('PRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5))]))),
      Tooltip(message: 'Profile', child: InkWell(onTap: _openMyProfileFromDashboard, borderRadius: BorderRadius.circular(20), child: Stack(clipBehavior: Clip.none, children: [_buildGlassContainer(isDark: isDark, padding: const EdgeInsets.all(12), borderRadius: 20, child: Icon(Icons.person_rounded, color: isDark ? Colors.white : AppConfig.primaryColor, size: 24)), if (AuthService.instance.currentUser != null) Positioned(top: -2, right: -2, child: Container(width: 14, height: 14, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF3B82F6)]), shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF070B14) : Colors.white, width: 2.5))))]))),
      const SizedBox(width: 10),
      GestureDetector(key: _notificationKey, onTap: _openNotificationsScreen, child: AnimatedBuilder(animation: _bellShakeController, builder: (context, _) { final sv = sin(_bellShake.value * pi * 5) * 0.2; return Transform.rotate(angle: _unreadNotificationCount > 0 ? sv : 0, child: Stack(clipBehavior: Clip.none, children: [_buildGlassContainer(isDark: isDark, padding: const EdgeInsets.all(12), borderRadius: 20, child: Icon(Icons.notifications_rounded, color: isDark ? Colors.white : AppConfig.primaryColor, size: 24)), if (_unreadNotificationCount > 0) Positioned(top: -6, right: -6, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)]), shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF070B14) : Colors.white, width: 2.5), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]), constraints: const BoxConstraints(minWidth: 22, minHeight: 22), child: Center(child: Text(_unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))))])); })),
    ]);
  }

  Widget _buildLevelDownBanner(bool isDark) => AnimatedBuilder(animation: _levelDownController, builder: (ctx, _) { final sv = Tween<double>(begin: -100.0, end: 0.0).animate(CurvedAnimation(parent: _levelDownController, curve: Curves.elasticOut)).value; return Transform.translate(offset: Offset(0, sv), child: Container(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppConfig.errorColor.withOpacity(0.95), Colors.red.shade800.withOpacity(0.85)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppConfig.errorColor.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.trending_down_rounded, color: Colors.white, size: 20)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Level Downgrade!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)), const SizedBox(height: 4), Text('Lv.$_levelDownFrom → Lv.$_levelDownTo', style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600, fontSize: 12))])), GestureDetector(onTap: () => setState(() => _showLevelDownBanner = false), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20))]))); });

  Widget _buildWeeklyCalendar(bool isDark) => Column(children: [GestureDetector(onTap: () { HapticFeedback.lightImpact(); setState(() => _showWeeklyCalendar = !_showWeeklyCalendar); }, child: _buildGlassContainer(isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), borderRadius: 20, child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calendar_month_rounded, color: AppConfig.primaryColor, size: 20)), const SizedBox(width: 14), Text('Weekly Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)), const Spacer(), AnimatedRotation(turns: _showWeeklyCalendar ? 0.5 : 0, duration: const Duration(milliseconds: 300), child: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 24))]))), AnimatedSize(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic, child: _showWeeklyCalendar ? Padding(padding: const EdgeInsets.only(top: 10), child: WeeklyCalendarWidget(habits: _habits, onDateTap: () => HapticFeedback.lightImpact())) : const SizedBox.shrink())]);

  Widget _buildQuickStats(bool isDark) { final ct = _completedToday(); final at = DatabaseService.getTotalHabitsCompleted(); final bs = _bestCurrentStreak(); final sm = DatabaseService.getTotalStudyMinutesAllTime(); return AnimatedBuilder(animation: _statsPopController, builder: (ctx, _) { final s = Curves.elasticOut.transform(_statsPopController.value.clamp(0.0, 1.0)); return Transform.scale(scale: 0.85 + (0.15 * s), child: Opacity(opacity: _statsPopController.value.clamp(0.0, 1.0), child: _buildGlassContainer(isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), borderRadius: 24, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_stat(Icons.check_circle_rounded, 'Today', '$ct', AppConfig.successColor, isDark), _div(isDark), _stat(Icons.all_inclusive_rounded, 'All Time', '$at', AppConfig.primaryColor, isDark), _div(isDark), _stat(Icons.local_fire_department_rounded, 'Best', '$bs', AppConfig.warningColor, isDark), _div(isDark), _stat(Icons.timer_rounded, 'Focus', '${(sm / 60).toStringAsFixed(1)}h', AppConfig.infoColor, isDark)])))); }); }

  Widget _div(bool isDark) => Container(width: 1, height: 40, color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06));

  Widget _stat(IconData icon, String label, String value, Color color, bool isDark) => Column(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.08)]), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), const SizedBox(height: 10), Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black54))]);

  Widget _buildQuoteCard(bool isDark) => AnimatedBuilder(animation: _quoteFloatController, builder: (ctx, _) => Transform.translate(offset: Offset(0, _quoteFloat.value), child: _buildGlassContainer(isDark: isDark, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), borderRadius: 20, child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppConfig.primaryColor.withOpacity(0.3), AppConfig.accentColor.withOpacity(0.15)]), borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('💡', style: TextStyle(fontSize: 24)))), const SizedBox(width: 16), Expanded(child: Text(_getQuote(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)))]))));

  Widget _buildHabitsHeader(bool isDark) => Row(children: [TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 800), curve: Curves.easeOutBack, builder: (_, v, child) => Transform.scale(scale: v, child: child), child: Text('My Habits', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5))), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppConfig.primaryColor.withOpacity(0.25))), child: Text('${_habits.length} Total  ·  ${_completedToday()} Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white.withOpacity(0.85) : Colors.black54)))]);

  Widget _buildEmptyState(bool isDark) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60), child: Column(children: [TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1500), curve: Curves.elasticOut, builder: (_, v, child) => Transform.scale(scale: v, child: child), child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppConfig.primaryColor.withOpacity(0.25), AppConfig.accentColor.withOpacity(0.15)]), boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.2), blurRadius: 50, spreadRadius: 15)]), child: const Center(child: Text('🔮', style: TextStyle(fontSize: 56))))), const SizedBox(height: 32), Text('No Habits Yet', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 12), Text('Tap the + button to create your first habit\nand start building consistency!', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.5, color: isDark ? Colors.white54 : Colors.black45)), const SizedBox(height: 36), GestureDetector(onTap: _addNewHabitDirect, child: Container(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppConfig.primaryColor, Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, color: Colors.white, size: 22), SizedBox(width: 10), Text('Create First Habit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))])))]));

  Widget _buildCelebrationOverlay() => AnimatedBuilder(animation: _celebrationController, builder: (ctx, _) { final o = (1 - _celebrationController.value).clamp(0.0, 1.0); return IgnorePointer(child: Container(color: Colors.black.withOpacity(0.65 * o), child: Center(child: Transform.scale(scale: Curves.elasticOut.transform(_celebrationController.value.clamp(0.0, 1.0)), child: Opacity(opacity: _celebrationController.value.clamp(0.0, 1.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('🎉', style: TextStyle(fontSize: 80)), const SizedBox(height: 20), ShaderMask(shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF59E0B), Colors.white]).createShader(b), child: const Text('All Complete!', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white))), const SizedBox(height: 10), Text('Amazing work today! 🔥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85)))])))))); });

  Widget _buildBottomSection(bool isDark, double bottomSafe) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.7)] : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.95)], begin: Alignment.topCenter, end: Alignment.bottomCenter), border: Border(top: BorderSide(color: Colors.white.withOpacity(isDark ? 0.06 : 0.6), width: 1))),
    child: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: GlassmorphismNavBar(selectedIndex: _selectedBottomTab, onTap: _handleBottomNavTap, onAddHabitTap: _addNewHabitDirect, onMenuTap: _showMoreMenu, addButtonKey: _addButtonKey, moreButtonKey: _moreButtonKey)),
      if (AppConfig.enableAds && !_isProUser) const BannerAdWidget(),
      SizedBox(height: bottomSafe > 0 ? bottomSafe : 12),
    ]))),
  );
}

// ═══════════════════════════════════════
// PROGRESS RING PAINTER
// ═══════════════════════════════════════

class _PremiumProgressPainter extends CustomPainter {
  final double progress; final Color progressColor; final Color backgroundColor; final double strokeWidth; final Color glowColor;
  _PremiumProgressPainter({required this.progress, required this.progressColor, required this.backgroundColor, required this.strokeWidth, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); final radius = (min(size.width, size.height) / 2) - strokeWidth; const startAngle = -pi / 2; final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawCircle(center, radius, Paint()..color = backgroundColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
    if (progress <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, Paint()..color = glowColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth + 10..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..shader = SweepGradient(startAngle: startAngle, endAngle: startAngle + sweepAngle, colors: [progressColor.withOpacity(0.5), progressColor, progressColor, Color.lerp(progressColor, Colors.white, 0.35)!], stops: const [0.0, 0.3, 0.7, 1.0]).createShader(rect));
    if (progress > 0.02) { final ea = startAngle + sweepAngle; final dx = center.dx + radius * cos(ea); final dy = center.dy + radius * sin(ea); canvas.drawCircle(Offset(dx, dy), strokeWidth * 1.0, Paint()..color = progressColor.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)); canvas.drawCircle(Offset(dx, dy), strokeWidth * 0.5, Paint()..color = Colors.white); }
  }

  @override
  bool shouldRepaint(_PremiumProgressPainter old) => old.progress != progress || old.progressColor != progressColor;
}