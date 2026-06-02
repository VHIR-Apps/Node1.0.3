// lib/screens/onboarding_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/leaderboard_profile_model.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';
import '../services/leaderboard_service.dart';
import '../services/sound_service.dart';
import '../services/url_service.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _page = 0;

  String _userName = '';
  String _selectedAvatar = '🦸';
  String? _selectedGoalType;
  final Set<String> _selectedHabitIds = {};
  bool _commitmentChecked = false;

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  late final TapGestureRecognizer _privacyTapRecognizer;
  late final TapGestureRecognizer _termsTapRecognizer;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late AnimationController _bgAnimController;
  late AnimationController _shakeController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _bounceAnim;
  late Animation<double> _shakeAnim;

  bool _authBusy = false;
  bool _isLeavingOnboarding = false;
  bool _magicLoginInProgress = false;

  // 🚀 Updated to 7 pages because Login is moved to Page 1
  final int _totalPages = 7;

  // Ambient Background Orbs Colors
  final List<Color> _orbColorsDark = const [
    Color(0xFF3B82F6), // Tech Blue
    Color(0xFF8B5CF6), // Deep Purple
    Color(0xFF0EA5E9), // Cyan
  ];

  final List<Color> _orbColorsLight = const [
    Color(0xFF93C5FD), // Soft Blue
    Color(0xFFC4B5FD), // Soft Purple
    Color(0xFF6EE7B7), // Mint
  ];

  final List<String> _avatars = const [
    '🦸', '🧑‍💻', '🧑‍🎓', '🧑‍🏫', '🧑‍⚕️', '🏋️',
    '🧘', '🎯', '🚀', '👨‍💼', '👩‍💼', '🦁',
    '🐯', '🦊', '🐺', '🦅', '💎', '⭐',
    '🌟', '🔥', '👑', '🏆', '💪', '🧠',
    '🎨', '🎵', '📚', '🌈', '🌸', '🐬',
    '🦋', '🌺',
  ];

  final List<Map<String, dynamic>> _goalTypes = const [
    {
      'id': 'quit_bad',
      'emoji': '🚫',
      'title': 'Eradicate Bad Habits',
      'subtitle': 'Delete smoking, screen time, procrastination',
      'color': 0xFFEF4444,
      'gradient': [Color(0xFFEF4444), Color(0xFFB91C1C)],
    },
    {
      'id': 'health_fitness',
      'emoji': '💪',
      'title': 'Optimize Health & Fitness',
      'subtitle': 'Exercise, diet, hydration, sleep cycles',
      'color': 0xFF10B981,
      'gradient': [Color(0xFF10B981), Color(0xFF047857)],
    },
    {
      'id': 'learn_grow',
      'emoji': '🧠',
      'title': 'Expand Knowledge Base',
      'subtitle': 'Reading, learning skills, studying',
      'color': 0xFF3B82F6,
      'gradient': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    },
    {
      'id': 'productivity',
      'emoji': '⚡',
      'title': 'Maximize Productivity',
      'subtitle': 'Focus, routines, time management',
      'color': 0xFF8B5CF6,
      'gradient': [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    },
    {
      'id': 'mindfulness',
      'emoji': '🧘',
      'title': 'Mental Clarity & Peace',
      'subtitle': 'Meditation, journaling, stress reduction',
      'color': 0xFF0EA5E9,
      'gradient': [Color(0xFF0EA5E9), Color(0xFF0369A1)],
    },
    {
      'id': 'finance',
      'emoji': '📈',
      'title': 'Financial Growth',
      'subtitle': 'Budgeting, saving, reducing expenses',
      'color': 0xFFF59E0B,
      'gradient': [Color(0xFFF59E0B), Color(0xFFB45309)],
    },
    {
      'id': 'custom',
      'emoji': '✨',
      'title': 'Custom Node Setup',
      'subtitle': 'I have my own parameters to track',
      'color': 0xFFEC4899,
      'gradient': [Color(0xFFEC4899), Color(0xFFBE185D)],
    },
  ];

  Map<String, List<Map<String, dynamic>>> get _habitSuggestions => {
    'quit_bad': [
      {'id': 'no_smoke', 'name': 'No Smoking Today', 'emoji': '🚭', 'category': 'Health', 'color': 0xFFEF4444},
      {'id': 'no_junk', 'name': 'No Junk Food', 'emoji': '🚫', 'category': 'Health', 'color': 0xFFF97316},
      {'id': 'screen_limit', 'name': 'Screen Time < 2hrs', 'emoji': '📵', 'category': 'Productivity', 'color': 0xFF8B5CF6},
      {'id': 'no_procrastinate', 'name': 'Do #1 Task First', 'emoji': '⚡', 'category': 'Productivity', 'color': 0xFFEAB308},
      {'id': 'no_gossip', 'name': 'No Gossip/Negativity', 'emoji': '🤐', 'category': 'Mindfulness', 'color': 0xFF14B8A6},
    ],
    'health_fitness': [
      {'id': 'water', 'name': 'Drink 8 Glasses Water', 'emoji': '💧', 'category': 'Health', 'color': 0xFF0EA5E9},
      {'id': 'exercise', 'name': '30 Min Exercise', 'emoji': '💪', 'category': 'Fitness', 'color': 0xFFEF4444},
      {'id': 'walk', 'name': '10,000 Steps Walk', 'emoji': '🚶', 'category': 'Fitness', 'color': 0xFF10B981},
      {'id': 'sleep', 'name': 'Sleep Before 11 PM', 'emoji': '😴', 'category': 'Health', 'color': 0xFF4F46E5},
      {'id': 'healthy_eat', 'name': 'Eat Fruits & Veggies', 'emoji': '🥗', 'category': 'Health', 'color': 0xFF22C55E},
    ],
    'learn_grow': [
      {'id': 'read', 'name': 'Read 20 Pages', 'emoji': '📚', 'category': 'Learning', 'color': 0xFF3B82F6},
      {'id': 'study', 'name': 'Study 2 Hours', 'emoji': '📖', 'category': 'Learning', 'color': 0xFF6366F1},
      {'id': 'new_word', 'name': 'Learn 5 New Words', 'emoji': '📝', 'category': 'Learning', 'color': 0xFF8B5CF6},
      {'id': 'podcast', 'name': 'Listen to Podcast', 'emoji': '🎧', 'category': 'Learning', 'color': 0xFFEC4899},
      {'id': 'practice', 'name': 'Practice a Skill', 'emoji': '🎯', 'category': 'Learning', 'color': 0xFFEF4444},
    ],
    'productivity': [
      {'id': 'morning_routine', 'name': 'Morning Routine', 'emoji': '🌅', 'category': 'Productivity', 'color': 0xFFF97316},
      {'id': 'plan_day', 'name': 'Plan My Day', 'emoji': '📋', 'category': 'Productivity', 'color': 0xFF3B82F6},
      {'id': 'deep_work', 'name': '2hr Deep Work Block', 'emoji': '🧠', 'category': 'Productivity', 'color': 0xFF8B5CF6},
      {'id': 'inbox_zero', 'name': 'Inbox Zero', 'emoji': '📧', 'category': 'Productivity', 'color': 0xFF0EA5E9},
      {'id': 'no_social', 'name': 'No Social Media till 12', 'emoji': '📵', 'category': 'Productivity', 'color': 0xFFEF4444},
    ],
    'mindfulness': [
      {'id': 'meditate', 'name': 'Meditate 10 Min', 'emoji': '🧘', 'category': 'Mindfulness', 'color': 0xFF8B5CF6},
      {'id': 'journal', 'name': 'Write Journal', 'emoji': '📝', 'category': 'Self-Care', 'color': 0xFF92400E},
      {'id': 'gratitude', 'name': '3 Things Grateful For', 'emoji': '🙏', 'category': 'Mindfulness', 'color': 0xFFEC4899},
      {'id': 'breathe', 'name': 'Deep Breathing 5 Min', 'emoji': '🌬️', 'category': 'Mindfulness', 'color': 0xFF0EA5E9},
      {'id': 'digital_detox', 'name': '1hr Digital Detox', 'emoji': '🔇', 'category': 'Mindfulness', 'color': 0xFF64748B},
    ],
    'finance': [
      {'id': 'track_expense', 'name': 'Track Expenses', 'emoji': '📊', 'category': 'Finance', 'color': 0xFFEAB308},
      {'id': 'save_money', 'name': 'Save Money Today', 'emoji': '💰', 'category': 'Finance', 'color': 0xFF22C55E},
      {'id': 'no_impulse', 'name': 'No Impulse Buying', 'emoji': '🛒', 'category': 'Finance', 'color': 0xFFEF4444},
      {'id': 'budget_check', 'name': 'Check Budget', 'emoji': '📋', 'category': 'Finance', 'color': 0xFF3B82F6},
      {'id': 'learn_finance', 'name': 'Learn About Finance', 'emoji': '📚', 'category': 'Finance', 'color': 0xFF8B5CF6},
    ],
    'custom': [
      {'id': 'water', 'name': 'Drink Water', 'emoji': '💧', 'category': 'Health', 'color': 0xFF0EA5E9},
      {'id': 'read', 'name': 'Read 10 Pages', 'emoji': '📚', 'category': 'Learning', 'color': 0xFF3B82F6},
      {'id': 'walk', 'name': 'Morning Walk', 'emoji': '🚶', 'category': 'Fitness', 'color': 0xFF10B981},
      {'id': 'meditate', 'name': 'Meditate', 'emoji': '🧘', 'category': 'Mindfulness', 'color': 0xFF8B5CF6},
      {'id': 'sleep', 'name': 'Sleep Early', 'emoji': '😴', 'category': 'Health', 'color': 0xFF4F46E5},
    ],
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // INIT & DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _bgAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine));
    _bounceAnim = Tween<double>(begin: 0.0, end: 15.0).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOutSine));

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _privacyTapRecognizer = TapGestureRecognizer()..onTap = _openPrivacyPolicy;
    _termsTapRecognizer = TapGestureRecognizer()..onTap = _openTerms;

    _fadeController.forward();
    _slideController.forward();

    _nameFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _privacyTapRecognizer.dispose();
    _termsTapRecognizer.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _bgAnimController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _goToPage(int page) {
    if (_isLeavingOnboarding) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutExpo,
    );
    try { SoundService.playOnboardingStep(); } catch (_) {}
    HapticFeedback.lightImpact();

    // Reset and trigger animations for the new page
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  bool get _isSignedIn => AuthService.instance.currentUser != null;
  String? get _signedInEmail => AuthService.instance.email ?? AuthService.instance.currentUser?.email;

  // ═══════════════════════════════════════════════════════════════════════════
  // MAGIC LOGIN (Page 1)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleMagicLogin() async {
    if (_authBusy || _magicLoginInProgress || _isLeavingOnboarding) return;

    setState(() => _authBusy = true);
    HapticFeedback.lightImpact();
    SoundService.playTap();

    try {
      final user = await AuthService.instance.ensureSignedInOnDemand(interactive: true);

      if (!mounted) return;
      if (user == null) {
        _showSnack('Connection aborted.', isError: true);
        return;
      }

      setState(() => _magicLoginInProgress = true);
      _showSnack('Scanning network for backups...');

      final backupInfo = await BackupService.getExistingGoogleDriveBackupInfo();
      if (!mounted) return;

      if (backupInfo == null) {
        _showSnack('New Node detected. Proceed to initialization.');
        _goToPage(2);
        return;
      }

      _showSnack('Data located! Synchronizing nodes...');
      HapticFeedback.mediumImpact();

      final result = await BackupService.restoreFromGoogleDriveSilently();
      if (!mounted) return;

      _hydrateLocalStateFromDatabase();
      await DatabaseService.setFirstLaunchDone();

      if (!mounted) return;

      try { await _ensureLeaderboardProfileAndSync(); } catch (e) { debugPrint('⚠️ Sync failed: $e'); }

      if (!mounted) return;
      SoundService.playSuccess();
      HapticFeedback.heavyImpact();
      _showSnack('Synchronized ${result.habitsImported} active nodes. Welcome back!');

      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      _openDashboardDirectly();

    } catch (e) {
      if (!mounted) return;
      _showSnack(_prettyError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _authBusy = false;
          _magicLoginInProgress = false;
        });
      }
    }
  }

  int _avatarIndexFromEmoji(String emoji) {
    final idx = _avatars.indexOf(emoji);
    return (idx < 0 ? 0 : idx) % 16;
  }

  Future<void> _ensureLeaderboardProfileAndSync() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final uid = user.uid.trim();
    if (uid.isEmpty) return;

    try {
      final dbName = DatabaseService.getUserName().trim();
      final authName = AuthService.instance.displayName?.trim() ?? '';
      final localName = _userName.trim();

      final displayName = (dbName.isNotEmpty && dbName != 'Habit Hero')
          ? dbName
          : (localName.isNotEmpty ? localName : (authName.isNotEmpty ? authName : 'HabitNode User'));

      final dbAvatar = DatabaseService.getUserAvatar().trim();
      final avatarEmoji = dbAvatar.isNotEmpty ? dbAvatar : (_selectedAvatar.trim().isNotEmpty ? _selectedAvatar : '🙂');

      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final existing = DatabaseService.getLeaderboardProfileForUid(uid);
      final joinedAtMs = (existing?.joinedAtMs ?? 0) > 0 ? existing!.joinedAtMs : nowMs;

      final profile = (existing ??
          LeaderboardProfileModel.create(
            uid: uid, displayName: displayName, isOptedIn: true, showLevel: true, showBadges: true, showStudyHours: true, avatarEmoji: avatarEmoji, avatarIndex: _avatarIndexFromEmoji(avatarEmoji), joinedAtMs: joinedAtMs,
          )).copyWith(
        displayName: displayName, avatarEmoji: avatarEmoji, avatarIndex: _avatarIndexFromEmoji(avatarEmoji), isOptedIn: true, showLevel: true, showBadges: true, showStudyHours: true, joinedAtMs: joinedAtMs,
      );

      await DatabaseService.saveLeaderboardProfile(profile);
      await DatabaseService.setLeaderboardLastUid(uid);

      try { await LeaderboardService.instance.syncMyProfileToCloud(); } catch (_) {}
    } catch (_) {}
  }

  void _hydrateLocalStateFromDatabase() {
    try {
      final restoredName = DatabaseService.getUserName().trim();
      final restoredAvatar = DatabaseService.getUserAvatar().trim();
      final restoredGoalType = DatabaseService.getUserGoalType().trim();

      if (!mounted) return;
      setState(() {
        if (restoredName.isNotEmpty && restoredName != 'Habit Hero') {
          _nameController.text = restoredName;
          _userName = restoredName;
        }
        if (restoredAvatar.isNotEmpty) _selectedAvatar = restoredAvatar;
        if (restoredGoalType.isNotEmpty) _selectedGoalType = restoredGoalType;
      });
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NEXT PAGE LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  void _next() {
    if (_authBusy || _magicLoginInProgress || _isLeavingOnboarding) return;

    switch (_page) {
      case 0:
        _goToPage(1); // Go to Sync Page
        break;
      case 1:
        _goToPage(2); // Go to Name Page
        break;
      case 2:
        if (_nameController.text.trim().isEmpty) {
          HapticFeedback.heavyImpact(); SoundService.playError();
          _nameFocusNode.requestFocus();
          _shakeController.reset(); _shakeController.forward();
          _showSnack('Node identity required. Enter your name.', isError: true);
          return;
        }
        _userName = _nameController.text.trim();
        FocusScope.of(context).unfocus();
        _goToPage(3);
        break;
      case 3:
        _goToPage(4);
        break;
      case 4:
        if (_selectedGoalType == null) {
          HapticFeedback.heavyImpact(); SoundService.playError();
          _shakeController.reset(); _shakeController.forward();
          _showSnack('Please select a primary directive.', isError: true);
          return;
        }
        _goToPage(5);
        break;
      case 5:
        _goToPage(6);
        break;
      case 6:
        _finish();
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINISH ONBOARDING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _finish() async {
    if (_isLeavingOnboarding) return;

    SoundService.playWelcome();
    HapticFeedback.mediumImpact();

    final finalName = _userName.trim().isNotEmpty ? _userName.trim() : 'Habit Hero';

    await DatabaseService.setUserName(finalName);
    await DatabaseService.setUserAvatar(_selectedAvatar);

    if (_selectedGoalType != null) {
      await DatabaseService.setUserGoalType(_selectedGoalType!);
    }

    if (_selectedHabitIds.isNotEmpty && !DatabaseService.areStarterGoalsApplied()) {
      final suggestions = _habitSuggestions[_selectedGoalType ?? 'custom'] ?? [];
      final selected = suggestions.where((item) => _selectedHabitIds.contains(item['id'])).toList();
      if (selected.isNotEmpty) await DatabaseService.addStarterHabits(selected);
    }

    await DatabaseService.setFirstLaunchDone();

    if (_isSignedIn) {
      try { await _ensureLeaderboardProfileAndSync(); } catch (_) {}
    }

    if (!mounted) return;
    _openDashboardDirectly();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  void _openPrivacyPolicy() { HapticFeedback.lightImpact(); SoundService.playTap(); UrlService.openUrl(AppConfig.privacyPolicyUrl, context); }
  void _openTerms() { HapticFeedback.lightImpact(); SoundService.playTap(); UrlService.openUrl(AppConfig.termsUrl, context); }

  String _prettyError(Object e) {
    if (e is AuthServiceException) return e.message;
    if (e is CloudBackupException) return e.message;
    if (e is LeaderboardServiceException) return e.message;

    final msg = e.toString();
    if (msg.contains('cancelled')) return 'Connection aborted.';
    if (msg.contains('No cloud backup')) return 'No neural backup found in cloud.';
    if (msg.contains('SocketException') || msg.contains('network')) return 'Network offline. Please verify connection.';
    final cleaned = msg.replaceAll('AuthServiceException:', '').replaceAll('CloudBackupException:', '').replaceAll('LeaderboardServiceException:', '').trim();
    return cleaned.isEmpty ? 'System error. Please try again.' : cleaned;
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: isError ? AppConfig.errorColor.withOpacity(0.95) : const Color(0xFF1E293B).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
          ),
          child: Row(
            children: [
              Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13))),
            ],
          ),
        ),
      ),
    );
  }

  void _openDashboardDirectly() {
    if (!mounted || _isLeavingOnboarding) return;
    _isLeavingOnboarding = true;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.05, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
          (route) => false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD & ANIMATED UI SHELL
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orbColors = isDark ? _orbColorsDark : _orbColorsLight;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Dynamic Mesh Background
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              final t = _bgAnimController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.1 + (math.sin(t) * 50),
                    left: MediaQuery.of(context).size.width * 0.1 + (math.cos(t) * 50),
                    child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: orbColors[0].withOpacity(isDark ? 0.3 : 0.4))),
                  ),
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.1 + (math.cos(t * 0.8) * 60),
                    right: MediaQuery.of(context).size.width * 0.1 + (math.sin(t * 1.2) * 40),
                    child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: orbColors[1].withOpacity(isDark ? 0.25 : 0.35))),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.4 + (math.sin(t * 1.5) * 40),
                    left: MediaQuery.of(context).size.width * 0.4 + (math.cos(t * 0.9) * 60),
                    child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: orbColors[2].withOpacity(isDark ? 0.2 : 0.3))),
                  ),
                ],
              );
            },
          ),

          // Intense Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.5)),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isDark),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _buildWelcomePage(isDark),       // Page 0
                      _buildSyncPage(isDark),          // Page 1 (Moved here)
                      _buildNamePage(isDark),          // Page 2
                      _buildAvatarPage(isDark),        // Page 3
                      _buildGoalTypePage(isDark),      // Page 4
                      _buildHabitSelectionPage(isDark),// Page 5
                      _buildCommitmentPage(isDark),    // Page 6
                    ],
                  ),
                ),
                _buildBottomButton(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REUSABLE GLASS WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _glassContainer({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double borderRadius = 24,
    Color? borderColor,
    bool isDark = true,
  }) {
    final borderCol = borderColor ?? (isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6));
    final bgCol = isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4);

    return Container(
      key: key,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderCol, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((borderRadius - 2).clamp(0.0, borderRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: child,
        ),
      ),
    );
  }

  Widget _glassButton({
    required String text,
    required VoidCallback onTap,
    required List<Color> gradientColors,
    IconData? icon,
    bool isLoading = false,
    bool isDark = true,
  }) {
    final textColor = isDark || gradientColors[0] != Colors.white.withOpacity(0.3) ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.1 : 0.4),
              width: 1.5,
            )
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({required IconData icon, required String label, required String value, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(isDark ? 0.15 : 0.6), width: 1.5),
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: AppConfig.primaryColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : Colors.black54)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String iconData, String label, bool isDark) {
    return _glassContainer(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 18,
      child: Row(
        children: [
          Text(iconData, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar(bool isDark) {
    final bool busy = _authBusy || _magicLoginInProgress;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (_page > 0)
                GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); _goToPage(_page - 1); },
                  child: _glassContainer(isDark: isDark, padding: const EdgeInsets.all(12), borderRadius: 16, child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor)),
                )
              else
                const SizedBox(width: 44),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_totalPages, (i) {
                  final isActive = i == _page;
                  final isPast = i < _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppConfig.primaryColor : isPast ? AppConfig.primaryColor.withOpacity(0.5) : textColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isActive ? [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.5), blurRadius: 10)] : null,
                    ),
                  );
                }),
              ),
              const Spacer(),
              if (_page < _totalPages - 1)
                GestureDetector(
                  onTap: busy ? null : _finish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('Skip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor.withOpacity(0.6))),
                  ),
                )
              else
                const SizedBox(width: 50),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 0: WELCOME
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWelcomePage(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 🚀 Real App Logo with Bounce Animation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Transform.translate(
                    offset: Offset(0, -_bounceAnim.value),
                    child: Transform.scale(scale: _pulseAnim.value, child: child)
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: AppConfig.primaryColor.withOpacity(0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppConfig.primaryColor,
                        child: const Icon(Icons.hub_rounded, size: 70, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Habit Node',
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5, height: 1.1),
              ),

              const SizedBox(height: 16),

              Text(
                'Assalamu Alaikum. Initialize your personal network.\nBuild habits, track growth, level up.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7), height: 1.5),
              ),

              const SizedBox(height: 40),

              _buildFeatureRow('🕸️', 'Connect daily habits flawlessly', isDark),
              const SizedBox(height: 12),
              _buildFeatureRow('💎', 'Earn badges and system ranks', isDark),
              const SizedBox(height: 12),
              _buildFeatureRow('📊', 'Visualize your data growth', isDark),
              const SizedBox(height: 12),
              _buildFeatureRow('🧠', 'Smart algorithmic nudges', isDark),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 1: SYNC / MAGIC LOGIN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSyncPage(bool isDark) {
    final signedIn = _isSignedIn;
    final email = _signedInEmail;
    final textColor = isDark ? Colors.white : Colors.black87;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.cloud_sync_rounded, size: 70, color: AppConfig.primaryColor),
              ),
              const SizedBox(height: 32),
              Text(
                'Secure Connection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Sync your data to Google Drive to ensure you never lose your progress.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 40),

              // Magic Login Card
              _glassContainer(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.security_rounded, color: AppConfig.primaryColor, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Neural Link Sync', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                              const SizedBox(height: 4),
                              Text('Auto-restore your previous nodes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      signedIn
                          ? (email?.trim().isNotEmpty == true ? email!.trim() : 'Connection established. Your data is safe.')
                          : 'Connect via Google to detect your cloud backup. If found, we\'ll restore your network instantly.',
                      style: TextStyle(fontSize: 14, height: 1.5, color: textColor.withOpacity(0.85), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    _glassButton(
                      isDark: isDark,
                      text: signedIn ? 'Connection Active' : 'Establish Connection',
                      onTap: signedIn ? () {} : _handleMagicLogin,
                      gradientColors: signedIn
                          ? [const Color(0xFF10B981), const Color(0xFF047857)] // Success Green
                          : [const Color(0xFF3B82F6), const Color(0xFF06B6D4)], // Tech Blue
                      icon: signedIn ? Icons.check_circle_rounded : Icons.login_rounded,
                      isLoading: _authBusy || _magicLoginInProgress,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 2: NAME
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNamePage(bool isDark) {
    final bool hasText = _nameController.text.trim().isNotEmpty;
    final bool isFocused = _nameFocusNode.hasFocus;
    final textColor = isDark ? Colors.white : Colors.black87;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.fingerprint_rounded, size: 60, color: AppConfig.primaryColor),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Identify your Node',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your designation to personalize the network',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7)),
                ),
                const SizedBox(height: 48),

                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
                  child: _glassContainer(
                    isDark: isDark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    borderColor: isFocused || hasText ? AppConfig.primaryColor.withOpacity(0.8) : (isDark ? Colors.white.withOpacity(0.15) : Colors.black12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: (hasText || isFocused)
                              ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('DESIGNATION (NAME)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppConfig.primaryColor, letterSpacing: 1.5)),
                          )
                              : const SizedBox.shrink(),
                        ),
                        TextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          textCapitalization: TextCapitalization.words,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Enter name',
                            hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontWeight: FontWeight.w600, fontSize: 24),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            suffixIcon: hasText ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28) : null,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _next(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 3: AVATAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAvatarPage(bool isDark) {
    final displayName = _userName.isEmpty ? _nameController.text.trim() : _userName;
    final textColor = isDark ? Colors.white : Colors.black87;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            children: [
              Text(
                'Identity: $displayName',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppConfig.primaryColor, letterSpacing: 1),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Select Avatar',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a visual representation for the network',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: LinearGradient(colors: [AppConfig.primaryColor.withOpacity(0.2), AppConfig.accentColor.withOpacity(0.2)]),
                    border: Border.all(color: AppConfig.primaryColor.withOpacity(0.5), width: 2),
                    boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut), child: child),
                      child: Text(_selectedAvatar, key: ValueKey(_selectedAvatar), style: const TextStyle(fontSize: 60)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 16, crossAxisSpacing: 16),
                  itemCount: _avatars.length,
                  itemBuilder: (_, index) {
                    final avatar = _avatars[index];
                    final isSelected = _selectedAvatar == avatar;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        SoundService.playTap();
                        setState(() => _selectedAvatar = avatar);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: isSelected ? AppConfig.primaryColor.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppConfig.primaryColor : Colors.transparent, width: 2),
                          boxShadow: isSelected ? [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))] : null,
                        ),
                        child: Center(
                          child: AnimatedScale(
                            scale: isSelected ? 1.3 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            child: Text(avatar, style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 4: GOAL TYPE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGoalTypePage(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Primary Directive',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Define the main objective for your node network.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _goalTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, index) {
                    final goal = _goalTypes[index];
                    final isSelected = _selectedGoalType == goal['id'];

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact(); SoundService.playTap();
                        setState(() {
                          _selectedGoalType = goal['id'] as String;
                          _selectedHabitIds.clear();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          // 🚀 Rich Gradient when selected
                          gradient: isSelected
                              ? LinearGradient(colors: goal['gradient'], begin: Alignment.topLeft, end: Alignment.bottomRight)
                              : null,
                          color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6)),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.1) : Colors.black12),
                            width: isSelected ? 0 : 1.5,
                          ),
                          boxShadow: isSelected ? [BoxShadow(color: Color(goal['color']).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))] : null,
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withOpacity(0.2) : Color(goal['color']).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(child: Text(goal['emoji'] as String, style: const TextStyle(fontSize: 26))),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal['title'] as String,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : textColor),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    goal['subtitle'] as String,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white.withOpacity(0.8) : textColor.withOpacity(0.6)),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // 🚀 Target Icon for Selection
                            AnimatedScale(
                              scale: isSelected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(Icons.my_location_rounded, size: 20, color: Color(goal['color'])), // 🎯 Premium Target Icon
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 5: HABIT SELECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHabitSelectionPage(bool isDark) {
    final suggestions = _habitSuggestions[_selectedGoalType ?? 'custom'] ?? [];
    final textColor = isDark ? Colors.white : Colors.black87;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Initialize Nodes',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Select 2–4 base habits to launch your network.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedHabitIds.isNotEmpty ? AppConfig.primaryColor.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _selectedHabitIds.isNotEmpty ? AppConfig.primaryColor : Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedHabitIds.isNotEmpty) ...[
                          const Icon(Icons.hub_rounded, size: 18, color: AppConfig.primaryColor),
                          const SizedBox(width: 8),
                        ],
                        Text('${_selectedHabitIds.length} active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _selectedHabitIds.isNotEmpty ? AppConfig.primaryColor : textColor.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact(); SoundService.playTap();
                      setState(() {
                        if (_selectedHabitIds.length == suggestions.length) { _selectedHabitIds.clear(); } else { _selectedHabitIds..clear()..addAll(suggestions.map((e) => e['id'] as String)); }
                      });
                    },
                    child: Text(_selectedHabitIds.length == suggestions.length ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppConfig.primaryColor)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final habit = suggestions[index];
                    final id = habit['id'] as String;
                    final color = Color(habit['color'] as int);
                    final isSelected = _selectedHabitIds.contains(id);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick(); SoundService.playTap();
                        setState(() { if (isSelected) { _selectedHabitIds.remove(id); } else { _selectedHabitIds.add(id); } });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          // 🚀 Glowing gradient when selected
                          gradient: isSelected
                              ? LinearGradient(colors: [color.withOpacity(0.8), color.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                              : null,
                          color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6)),
                          border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.1) : Colors.black12), width: 1.5),
                          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))] : null,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                              child: Center(child: Text(habit['emoji'] as String, style: const TextStyle(fontSize: 24))),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(habit['name'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : textColor)),
                                  const SizedBox(height: 4),
                                  Text(habit['category'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white.withOpacity(0.8) : color)),
                                ],
                              ),
                            ),
                            // 🚀 Premium Target Checkmark
                            AnimatedScale(
                              scale: isSelected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(Icons.my_location_rounded, size: 20, color: color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 6: COMMITMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommitmentPage(bool isDark) {
    final goalType = _goalTypes.firstWhere((g) => g['id'] == _selectedGoalType, orElse: () => _goalTypes.last);
    final displayName = _userName.isEmpty ? _nameController.text.trim() : _userName;
    final textColor = isDark ? Colors.white : Colors.black87;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 200 * _pulseAnim.value, height: 200 * _pulseAnim.value,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.primaryColor.withOpacity(0.15)),
                    ),
                  ),
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: const LinearGradient(colors: [AppConfig.primaryColor, AppConfig.accentColor]),
                      boxShadow: [BoxShadow(color: AppConfig.primaryColor.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    child: Center(child: Text(_selectedAvatar, style: const TextStyle(fontSize: 60))),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Text('Network Ready', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Text('Identity $displayName confirmed.\nParameters mapped successfully.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7), height: 1.5)),
              const SizedBox(height: 36),

              _buildSummaryCard(isDark: isDark, icon: Icons.radar_rounded, label: 'Node Identity', value: displayName.isEmpty ? 'Habit Hero' : displayName),
              const SizedBox(height: 12),
              _buildSummaryCard(isDark: isDark, icon: Icons.flag_rounded, label: 'Primary Directive', value: goalType['title'] as String),
              const SizedBox(height: 12),
              _buildSummaryCard(isDark: isDark, icon: Icons.hub_rounded, label: 'Initial Nodes', value: _selectedHabitIds.isEmpty ? 'Awaiting manual entry' : '${_selectedHabitIds.length} nodes scheduled'),

              const SizedBox(height: 40),

              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _commitmentChecked = !_commitmentChecked);
                  if (_commitmentChecked) { SoundService.playSuccess(); HapticFeedback.heavyImpact(); }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _commitmentChecked ? AppConfig.primaryColor.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _commitmentChecked ? AppConfig.primaryColor : (isDark ? Colors.white.withOpacity(0.15) : Colors.black12), width: _commitmentChecked ? 2 : 1.5),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _commitmentChecked ? AppConfig.primaryColor : Colors.transparent,
                          border: Border.all(color: _commitmentChecked ? Colors.transparent : textColor.withOpacity(0.3), width: 2),
                        ),
                        child: _commitmentChecked ? const Icon(Icons.check_rounded, color: Colors.white, size: 24) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Establish Connection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _commitmentChecked ? AppConfig.primaryColor : textColor)),
                            const SizedBox(height: 4),
                            Text('I commit to daily network updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM BUTTON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomButton(bool isDark) {
    String buttonText;
    List<Color> buttonColors;
    final textColor = isDark ? Colors.white : Colors.black87;

    switch (_page) {
      case 0: // Welcome Page
        buttonText = 'Initialize Sequence';
        buttonColors = [AppConfig.primaryColor, AppConfig.accentColor];
        break;
      case 1: // Sync Page
        if (_authBusy || _magicLoginInProgress) {
          buttonText = 'Synchronizing...';
          buttonColors = [Colors.grey.shade600, Colors.grey.shade700];
        } else if (_isSignedIn) {
          buttonText = 'Proceed to Network';
          buttonColors = [AppConfig.primaryColor, AppConfig.accentColor];
        } else {
          buttonText = 'Offline Mode (Local Only)';
          buttonColors = isDark ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)] : [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.02)];
        }
        break;
      case 2: // Name Page
        final hasName = _nameController.text.trim().isNotEmpty;
        buttonText = hasName ? 'Continue' : 'Awaiting Input';
        buttonColors = hasName ? [AppConfig.primaryColor, AppConfig.accentColor] : (isDark ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)] : [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.02)]);
        break;
      case 3: // Avatar Page
        buttonText = 'Identity Confirmed';
        buttonColors = [AppConfig.primaryColor, AppConfig.accentColor];
        break;
      case 4: // Goal Page
        buttonText = _selectedGoalType != null ? 'Proceed' : 'Select Directive';
        buttonColors = _selectedGoalType != null ? [AppConfig.primaryColor, AppConfig.accentColor] : (isDark ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)] : [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.02)]);
        break;
      case 5: // Habit Page
        buttonText = _selectedHabitIds.isEmpty ? 'Skip Initialization' : 'Initialize ${_selectedHabitIds.length} Nodes';
        buttonColors = _selectedHabitIds.isEmpty ? (isDark ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)] : [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.02)]) : [AppConfig.primaryColor, AppConfig.accentColor];
        break;
      case 6: // Commitment Page
        buttonText = _commitmentChecked ? 'Launch System' : 'Awaiting Confirmation';
        buttonColors = _commitmentChecked ? [AppConfig.primaryColor, AppConfig.accentColor] : (isDark ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)] : [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.02)]);
        break;
      default:
        buttonText = 'Next';
        buttonColors = [AppConfig.primaryColor, AppConfig.accentColor];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _glassButton(
            isDark: isDark,
            text: buttonText,
            onTap: _next,
            gradientColors: buttonColors,
            isLoading: _authBusy || _magicLoginInProgress,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _page == 0
                ? Padding(
              padding: const EdgeInsets.only(top: 20),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.6), height: 1.5),
                  children: [
                    const TextSpan(text: 'By initializing, you accept the '),
                    TextSpan(text: 'Privacy Policy', recognizer: _privacyTapRecognizer, style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
                    const TextSpan(text: ' and '),
                    TextSpan(text: 'Terms of Service', recognizer: _termsTapRecognizer, style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}