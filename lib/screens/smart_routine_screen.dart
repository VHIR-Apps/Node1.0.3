// lib/screens/smart_routine_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/ad_service.dart';
import '../services/badge_service.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';
import 'pro_version_screen.dart';

class SmartRoutineScreen extends StatefulWidget {
  const SmartRoutineScreen({super.key});

  @override
  State<SmartRoutineScreen> createState() => _SmartRoutineScreenState();
}

class _SmartRoutineScreenState extends State<SmartRoutineScreen> {
  String _selectedRoutine = 'productive';
  String _currentSeason = '';
  String _detectedCountry = '';
  bool _isAdLoading = false;
  bool _isPro = false;

  late Map<String, RoutineTemplate> _routines;

  @override
  void initState() {
    super.initState();
    _detectSeasonAndCountry();
    _routines = _buildAdvancedRoutines();
    _cleanupExpiredUnlocks();
    // Load Pro/VIP status
    _isPro = DatabaseService.isProOrVipUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh Pro/VIP status every time screen is visible
    final newPro = DatabaseService.isProOrVipUser();
    if (newPro != _isPro) {
      setState(() => _isPro = newPro);
    }
  }

  Future<void> _cleanupExpiredUnlocks() async {
    await DatabaseService.cleanupExpiredRoutineUnlocks(_routines.keys.toList());
    if (mounted) setState(() {});
  }

  void _detectSeasonAndCountry() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final countryCode = locale.countryCode ?? '';
    _detectedCountry = countryCode;

    if (countryCode.isNotEmpty) {
      DatabaseService.setDetectedCountryCode(countryCode);
    }

    final isSouthern =
    AppConfig.southernHemisphereCountries.contains(countryCode);
    final month = DateTime.now().month;
    _currentSeason = AppConfig.getSeason(
      month,
      isSouthernHemisphere: isSouthern,
    );
  }

  /// Dynamically builds transformational routines and injects seasonal/monthly habits.
  Map<String, RoutineTemplate> _buildAdvancedRoutines() {
    final month = DateTime.now().month;

    // Advanced, life-changing base routines
    Map<String, RoutineTemplate> templates = {
      'productive': RoutineTemplate(
        id: 'productive',
        name: 'Monk Mode CEO',
        emoji: '🚀',
        description:
        'A transformational step-by-step framework for deep focus, exponential growth, and massive output.',
        color: const Color(0xFF6C63FF),
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Wake up immediately (No Snooze)', time: '04:30', category: 'Discipline'),
          RoutineHabit(emoji: '💧', name: 'Hydrate (500ml Water + Sea Salt)', time: '04:35', category: 'Health'),
          RoutineHabit(emoji: '🧘', name: 'Mindfulness & Macro Goal Visualization', time: '04:45', category: 'Mindset'),
          RoutineHabit(emoji: '☀️', name: 'Sunlight Viewing & Light Cardio', time: '05:00', category: 'Health'),
          RoutineHabit(emoji: '🎯', name: 'Deep Work Session 1 (Eat the Frog)', time: '05:30', category: 'Productivity'),
          RoutineHabit(emoji: '🍳', name: 'Brain-Fuel Breakfast (High Protein/Fat)', time: '07:30', category: 'Nutrition'),
          RoutineHabit(emoji: '🧠', name: 'Deep Work Session 2 (Core Projects)', time: '08:30', category: 'Productivity'),
          RoutineHabit(emoji: '🚶', name: 'Zone 2 Walking & Audio Learning', time: '12:00', category: 'Health'),
          RoutineHabit(emoji: '📧', name: 'Shallow Work (Emails/Admin/Calls)', time: '13:30', category: 'Work'),
          RoutineHabit(emoji: '⚡', name: 'NSDR (Non-Sleep Deep Rest) Protocol', time: '15:00', category: 'Recovery'),
          RoutineHabit(emoji: '📝', name: 'Plan Tomorrow & Daily Shutdown', time: '17:00', category: 'Productivity'),
          RoutineHabit(emoji: '🏋️', name: 'Strength Training / Hypertrophy', time: '17:30', category: 'Fitness'),
          RoutineHabit(emoji: '👨‍👩‍👧', name: 'Family & High-Quality Social Time', time: '19:00', category: 'Social'),
          RoutineHabit(emoji: '📚', name: 'Read 20+ pages (Non-fiction)', time: '20:30', category: 'Learning'),
          RoutineHabit(emoji: '📵', name: 'Digital Sunset (No Screens)', time: '21:00', category: 'Wellness'),
          RoutineHabit(emoji: '😴', name: 'In Bed (Cold Room, Pitch Black)', time: '21:30', category: 'Health'),
        ],
      ),
      'fitness': RoutineTemplate(
        id: 'fitness',
        name: 'Elite Athlete',
        emoji: '💪',
        description:
        'Engineered by sports science for peak muscle growth, fat loss, and limitless daily energy.',
        color: const Color(0xFF10B981),
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Wake up & Circadian Alignment', time: '05:30', category: 'Health'),
          RoutineHabit(emoji: '💧', name: '1L Water + Lemon + Electrolytes', time: '05:40', category: 'Nutrition'),
          RoutineHabit(emoji: '🤸', name: 'Dynamic Mobility & Primer Routine', time: '06:00', category: 'Fitness'),
          RoutineHabit(emoji: '🏋️', name: 'Intense Hypertrophy / Strength Block', time: '06:30', category: 'Fitness'),
          RoutineHabit(emoji: '🥩', name: 'Anabolic Breakfast (40g+ Protein)', time: '08:00', category: 'Nutrition'),
          RoutineHabit(emoji: '💼', name: 'Active Work / Standing Desk', time: '09:00', category: 'Work'),
          RoutineHabit(emoji: '💧', name: 'Hydration Check (Goal: 2L hit)', time: '12:00', category: 'Health'),
          RoutineHabit(emoji: '🥗', name: 'Macro-Tracked Balanced Lunch', time: '13:00', category: 'Nutrition'),
          RoutineHabit(emoji: '🚶', name: 'Post-Meal Digestion Walk (15m)', time: '13:30', category: 'Recovery'),
          RoutineHabit(emoji: '🏃', name: 'Zone 2 Cardio / 10k Steps Completion', time: '17:30', category: 'Fitness'),
          RoutineHabit(emoji: '🥑', name: 'Lean Protein & Veggies Dinner', time: '19:00', category: 'Nutrition'),
          RoutineHabit(emoji: '🧘', name: 'Static Stretching & Foam Rolling', time: '20:30', category: 'Recovery'),
          RoutineHabit(emoji: '💊', name: 'Magnesium & Sleep Supplements', time: '21:30', category: 'Health'),
          RoutineHabit(emoji: '😴', name: 'Deep Recovery Sleep (8+ Hours)', time: '22:00', category: 'Health'),
        ],
      ),
      'selfcare': RoutineTemplate(
        id: 'selfcare',
        name: 'Holistic Rebirth',
        emoji: '✨',
        description:
        'A transformational slow-living routine designed to heal the nervous system and elevate your aura.',
        color: const Color(0xFFEC4899),
        habits: [
          RoutineHabit(emoji: '🌅', name: 'Gentle Waking (Natural Light)', time: '07:00', category: 'Wellness'),
          RoutineHabit(emoji: '🧘', name: 'Morning Meditation & Gratitude', time: '07:10', category: 'Mindfulness'),
          RoutineHabit(emoji: '🍵', name: 'Warm Lemon Water / Matcha Ritual', time: '07:30', category: 'Health'),
          RoutineHabit(emoji: '🧴', name: 'Gua Sha & Advanced Skincare', time: '07:45', category: 'Self-Care'),
          RoutineHabit(emoji: '🥑', name: 'Nourishing Antioxidant Breakfast', time: '08:30', category: 'Nutrition'),
          RoutineHabit(emoji: '📓', name: 'Morning Pages / Brain-dump Journal', time: '09:00', category: 'Mindfulness'),
          RoutineHabit(emoji: '🎨', name: 'Creative Deep Work or Flow Hobby', time: '10:00', category: 'Creative'),
          RoutineHabit(emoji: '🌳', name: 'Earthing / Barefoot Nature Walk', time: '15:30', category: 'Wellness'),
          RoutineHabit(emoji: '📖', name: 'Read Fiction or Poetry', time: '17:00', category: 'Relaxation'),
          RoutineHabit(emoji: '🛁', name: 'Epsom Salt Bath / Spa Shower', time: '20:00', category: 'Self-Care'),
          RoutineHabit(emoji: '🕯️', name: 'Dim all lights to ambient', time: '20:30', category: 'Wellness'),
          RoutineHabit(emoji: '💆', name: 'Nighttime Repair Skincare', time: '21:00', category: 'Self-Care'),
          RoutineHabit(emoji: '🌙', name: 'Yoga Nidra & Drift to Sleep', time: '21:30', category: 'Relaxation'),
        ],
      ),
      'creator': RoutineTemplate(
        id: 'creator',
        name: 'Viral Visionary',
        emoji: '🎬',
        description:
        'The ultimate content machine framework for brainstorming, recording, editing, and growing an empire.',
        color: const Color(0xFFF97316),
        habits: [
          RoutineHabit(emoji: '⚡', name: 'Morning Momentum (Walk + Coffee)', time: '06:30', category: 'Energy'),
          RoutineHabit(emoji: '🧠', name: 'Trend Spotting & Market Research', time: '07:30', category: 'Business'),
          RoutineHabit(emoji: '✍️', name: 'Scripting & Hook Engineering', time: '08:30', category: 'Creative'),
          RoutineHabit(emoji: '📸', name: 'High-Energy Filming Block', time: '10:00', category: 'Creation'),
          RoutineHabit(emoji: '🥗', name: 'Light Lunch (Avoid Carb Coma)', time: '13:00', category: 'Health'),
          RoutineHabit(emoji: '💻', name: 'Focused Editing & Sound Design', time: '14:00', category: 'Work'),
          RoutineHabit(emoji: '🚀', name: 'Strategic Posting & Engagement', time: '17:00', category: 'Social'),
          RoutineHabit(emoji: '📊', name: 'Analytics Review & Adjustments', time: '18:00', category: 'Business'),
          RoutineHabit(emoji: '🕸️', name: 'Networking & DM Outreach', time: '19:00', category: 'Social'),
          RoutineHabit(emoji: '📚', name: 'Upskill (Learn New Editing Trick)', time: '20:00', category: 'Learning'),
          RoutineHabit(emoji: '📝', name: 'Set Tomorrow\'s Content Goals', time: '21:30', category: 'Planning'),
        ],
      ),
      'minimal': RoutineTemplate(
        id: 'minimal',
        name: 'Minimalist Reset',
        emoji: '🌿',
        description:
        'A low-friction, high-impact routine ensuring consistency, clarity, and zero overwhelm.',
        color: const Color(0xFF14B8A6),
        habits: [
          RoutineHabit(emoji: '💧', name: 'Drink a glass of water immediately', time: '07:00', category: 'Health'),
          RoutineHabit(emoji: '🛏️', name: 'Make the bed perfectly', time: '07:05', category: 'Organization'),
          RoutineHabit(emoji: '🚶', name: '15 Min outside walk (No Music)', time: '07:15', category: 'Fitness'),
          RoutineHabit(emoji: '📓', name: 'Write down 3 daily priorities', time: '08:00', category: 'Planning'),
          RoutineHabit(emoji: '💼', name: 'Execute Priority #1', time: '08:30', category: 'Productivity'),
          RoutineHabit(emoji: '🧹', name: '10 Min Tidy (Reset Environment)', time: '18:00', category: 'Organization'),
          RoutineHabit(emoji: '📖', name: 'Read 5 pages of a book', time: '20:30', category: 'Learning'),
          RoutineHabit(emoji: '😴', name: 'Phone away & Sleep', time: '22:00', category: 'Health'),
        ],
      ),
      'islamic': RoutineTemplate(
        id: 'islamic',
        name: 'Transformative Believer',
        emoji: '🕌',
        description:
        'An advanced synthesis of Deen and Dunya for profound spiritual and worldly success.',
        color: const Color(0xFF059669),
        habits: [
          RoutineHabit(emoji: '🌌', name: 'Tahajjud & Deep Dua', time: '04:00', category: 'Spiritual'),
          RoutineHabit(emoji: '🌅', name: 'Fajr Prayer (In Congregation if possible)', time: '04:45', category: 'Spiritual'),
          RoutineHabit(emoji: '📖', name: 'Quran Memorization / Tafsir Block', time: '05:15', category: 'Spiritual'),
          RoutineHabit(emoji: '🤲', name: 'Morning Adhkar & Affirmations', time: '05:45', category: 'Spiritual'),
          RoutineHabit(emoji: '💼', name: 'Deep Work / Halal Earning Pursuit', time: '08:00', category: 'Productivity'),
          RoutineHabit(emoji: '☀️', name: 'Dhuhr Prayer + Rawatib Sunnah', time: '13:00', category: 'Spiritual'),
          RoutineHabit(emoji: '📚', name: 'Seek Knowledge (Islamic Podcast/Book)', time: '14:00', category: 'Learning'),
          RoutineHabit(emoji: '🌤️', name: 'Asr Prayer + Evening Adhkar', time: '16:00', category: 'Spiritual'),
          RoutineHabit(emoji: '🌇', name: 'Maghrib Prayer', time: '18:00', category: 'Spiritual'),
          RoutineHabit(emoji: '👨‍👩‍👧', name: 'Family Bonding (Silat-ur-Rahim)', time: '18:30', category: 'Social'),
          RoutineHabit(emoji: '🌙', name: 'Isha Prayer + Witr', time: '20:00', category: 'Spiritual'),
          RoutineHabit(emoji: '📝', name: 'Muhasabah (Self-Accountability Journal)', time: '21:30', category: 'Mindset'),
          RoutineHabit(emoji: '😴', name: 'Sleep on right side with Sunnah', time: '22:00', category: 'Health'),
        ],
      ),
    };

    // --- DYNAMIC SEASONAL & MONTHLY INJECTION ---
    List<RoutineHabit> dynamicHabits = [];

    // Seasonal Recipes/Habits
    if (_currentSeason == 'Winter') {
      dynamicHabits.add(RoutineHabit(emoji: '🫖', name: 'Winter Immunity Brew (Ginger/Turmeric)', time: '07:15', category: 'Seasonal Recipe'));
      dynamicHabits.add(RoutineHabit(emoji: '💡', name: 'Light Therapy / Vitamin D Intake', time: '08:15', category: 'Seasonal Health'));
    } else if (_currentSeason == 'Summer') {
      dynamicHabits.add(RoutineHabit(emoji: '🍉', name: 'Summer Hydration Mix (Mint, Lime, Salt)', time: '14:00', category: 'Seasonal Recipe'));
      dynamicHabits.add(RoutineHabit(emoji: '🧴', name: 'Apply Sunscreen & UV Protect', time: '07:45', category: 'Seasonal Health'));
    } else if (_currentSeason == 'Autumn') {
      dynamicHabits.add(RoutineHabit(emoji: '🍲', name: 'Warm Autumn Spiced Soup / Broth', time: '19:30', category: 'Seasonal Recipe'));
      dynamicHabits.add(RoutineHabit(emoji: '🍂', name: 'Grounding Walk in Nature', time: '16:30', category: 'Seasonal Health'));
    } else if (_currentSeason == 'Spring') {
      dynamicHabits.add(RoutineHabit(emoji: '🥬', name: 'Spring Detox Smoothie (Greens & Lemon)', time: '10:30', category: 'Seasonal Recipe'));
      dynamicHabits.add(RoutineHabit(emoji: '🌬️', name: 'Open Windows & Deep Breathing', time: '08:00', category: 'Seasonal Health'));
    }

    // Month-Specific Micro Adjustments
    if (month == 1) {
      dynamicHabits.add(RoutineHabit(emoji: '🎯', name: 'Review Annual Trajectory', time: '20:45', category: 'Monthly Goal'));
    } else if (month == 10) {
      dynamicHabits.add(RoutineHabit(emoji: '🎃', name: 'Pumpkin Spice Superfood Meal', time: '09:30', category: 'Monthly Recipe'));
    } else if (month == 12) {
      dynamicHabits.add(RoutineHabit(emoji: '🍫', name: 'Hot Cacao (Magnesium for Sleep)', time: '20:45', category: 'Monthly Recipe'));
    }

    // Apply dynamic injections to all routines and sort chronologically
    for (var key in templates.keys) {
      final template = templates[key]!;
      List<RoutineHabit> updatedHabits = List.from(template.habits);
      updatedHabits.addAll(dynamicHabits);

      // Sort habits by string time ("HH:MM")
      updatedHabits.sort((a, b) => a.time.compareTo(b.time));

      templates[key] = RoutineTemplate(
        id: template.id,
        name: template.name,
        emoji: template.emoji,
        description: template.description,
        color: template.color,
        habits: updatedHabits,
      );
    }

    return templates;
  }

  String _getSeasonEmoji() {
    switch (_currentSeason) {
      case 'Spring':
        return '🌸';
      case 'Summer':
        return '☀️';
      case 'Autumn':
        return '🍂';
      case 'Winter':
        return '❄️';
      default:
        return '🌍';
    }
  }

  String _getSeasonTip() {
    switch (_currentSeason) {
      case 'Spring':
        return 'Spring protocol active: Routine includes detox & fresh air habits.';
      case 'Summer':
        return 'Summer protocol active: Hydration & UV protection added to timeline.';
      case 'Autumn':
        return 'Autumn protocol active: Grounding & warm meals added for immunity.';
      case 'Winter':
        return 'Winter protocol active: Light therapy & immunity brews integrated.';
      default:
        return 'Build step-by-step transformational habits every day!';
    }
  }

  String _formatRemainingTime(int expiryMillis) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = expiryMillis - now;
    if (diff <= 0) return 'Expired';

    final duration = Duration(milliseconds: diff);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '${hours}h ${minutes}m left';
  }

  Future<void> _unlockRoutineWithAd(String routineId) async {
    if (_isAdLoading) return;

    setState(() => _isAdLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppConfig.primaryColor),
              SizedBox(height: 16),
              Text(
                'Preparing rewarded ad...',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );

    bool success = false;
    try {
      success = await AdService.showRewardedUnlockRoutine(routineId);
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    setState(() => _isAdLoading = false);

    if (success) {
      SoundService.playSuccess();
      setState(() {});
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Transformational Routine unlocked for 1 day!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final error = AdService.lastError.isNotEmpty
          ? AdService.lastError
          : 'Rewarded ad not ready. Please try again in a few seconds.';
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Always refresh Pro/VIP status on each build
    _isPro = DatabaseService.isProOrVipUser();

    final routine = _routines[_selectedRoutine]!;
    final isRoutineUnlocked = DatabaseService.isRoutineUnlocked(routine.id);
    final expiry = DatabaseService.getRoutineUnlockExpiry(routine.id);

    // Determine if user can add habits (Pro/VIP OR ad-unlocked)
    final canAddHabits = _isPro || isRoutineUnlocked;
    // Determine if user can "Add All" (Pro/VIP OR ad-unlocked)
    final canAddAll = _isPro || isRoutineUnlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Routines'),
        centerTitle: true,
        actions: [
          if (!_isPro)
            GestureDetector(
              onTap: _showProDialog,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ═══ SEASONAL BANNER ═══
            if (AppConfig.enableSeasonalRoutines)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.primaryColor.withAlpha(20),
                        AppConfig.accentColor.withAlpha(14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppConfig.primaryColor.withAlpha(36),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_getSeasonEmoji(),
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_currentSeason${_detectedCountry.isNotEmpty ? ' ($_detectedCountry)' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _getSeasonTip(),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ═══ ROUTINE SELECTOR ═══
            SizedBox(
              height: 116,
              child: ListView(
                padding: const EdgeInsets.all(16),
                scrollDirection: Axis.horizontal,
                children: _routines.entries.map((entry) {
                  final item = entry.value;
                  final selected = _selectedRoutine == entry.key;
                  final unlocked =
                  DatabaseService.isRoutineUnlocked(item.id);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedRoutine = entry.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: 112,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? item.color.withAlpha(22)
                            : (isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? item.color : Colors.transparent,
                          width: 1.6,
                        ),
                        boxShadow: selected
                            ? [
                          BoxShadow(
                            color: item.color.withAlpha(35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item.emoji,
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 8),
                                Text(
                                  item.name.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? item.color
                                        : (isDark
                                        ? Colors.white70
                                        : Colors.black54),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Show lock only if NOT pro AND NOT unlocked via ad
                          if (!_isPro && !unlocked)
                            const Positioned(
                              top: 0,
                              right: 0,
                              child: Icon(
                                Icons.lock_rounded,
                                size: 16,
                                color: Colors.amber,
                              ),
                            ),
                          // Show checkmark if unlocked via ad (not pro)
                          if (!_isPro && unlocked)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ═══ ROUTINE INFO CARD ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      routine.color.withAlpha(22),
                      routine.color.withAlpha(10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Text(routine.emoji,
                        style: const TextStyle(fontSize: 38)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  routine.name,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isPro) ...[
                                const SizedBox(width: 8),
                                const Text('👑',
                                    style: TextStyle(fontSize: 16)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            routine.description,
                            style: TextStyle(
                              fontSize: 12.8,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.black54,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _infoPill(
                                icon: Icons.track_changes_rounded,
                                text: '${routine.habits.length} steps',
                                color: routine.color,
                              ),
                              _infoPill(
                                icon: Icons.schedule_rounded,
                                text: 'Full day framework',
                                color: const Color(0xFF3B82F6),
                              ),
                              if (canAddHabits && !_isPro)
                                _infoPill(
                                  icon: Icons.lock_open_rounded,
                                  text: 'Unlocked',
                                  color: Colors.green,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ═══ DAILY TIMELINE HEADER ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daily Timeline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (!canAddHabits)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Preview Only',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  else if (!_isPro && isRoutineUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatRemainingTime(expiry),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    )
                  else if (_isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '👑 Full Access',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ═══ HABIT TIMELINE LIST ═══
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                itemCount: routine.habits.length,
                itemBuilder: (context, index) {
                  final habit = routine.habits[index];
                  final isLast = index == routine.habits.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: routine.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: routine.color.withAlpha(45),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withAlpha(10)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: !isDark
                                  ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(8),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: routine.color.withAlpha(20),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      habit.emoji,
                                      style:
                                      const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        habit.name,
                                        style: TextStyle(
                                          fontSize: 14.2,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 13,
                                            color: routine.color,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            habit.time,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: routine.color,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              habit.category,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                              ),
                                              overflow:
                                              TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Add button: show if user can add habits
                                if (canAddHabits)
                                  GestureDetector(
                                    onTap: () => _addSingleHabit(
                                        habit, routine),
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color:
                                        routine.color.withAlpha(18),
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: routine.color,
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () =>
                                        _unlockRoutineWithAd(routine.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withAlpha(16),
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
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

            // ═══ BOTTOM ACTION BUTTONS ═══
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: canAddAll
                      ? ElevatedButton.icon(
                    onPressed: () => _addAllHabits(routine),
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(
                      'Add All ${routine.habits.length} Habits ✨',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: routine.color,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  )
                      : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: _isAdLoading
                              ? null
                              : () => _unlockRoutineWithAd(
                              routine.id),
                          icon: _isAdLoading
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons
                              .play_circle_fill_rounded),
                          label: const Text(
                            'Watch Ad to Unlock',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 17),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _showProDialog,
                          icon: const Icon(Icons.star_rounded,
                              size: 18),
                          label: const Text(
                            'Go PRO',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFFFFD700),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                                vertical: 17),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                        ),
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
  }

  Widget _infoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _addSingleHabit(
      RoutineHabit routineHabit, RoutineTemplate routine) async {
    SoundService.playHabitCreated();
    HapticFeedback.lightImpact();

    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: routineHabit.name,
      emoji: routineHabit.emoji,
      colorValue: routine.color.toARGB32(),
      category: routineHabit.category,
      frequency: 'daily',
      time: routineHabit.time,
      reminderEnabled: true,
      createdAt: DateTime.now(),
    );

    await DatabaseService.addHabit(habit);
    await BadgeService.checkAllBadges();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text('${routineHabit.emoji} ${routineHabit.name} added! ✅'),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _addAllHabits(RoutineTemplate routine) async {
    SoundService.playSuccess();
    HapticFeedback.mediumImpact();

    int count = 0;
    for (final h in routine.habits) {
      final habit = Habit(
        id: '${DateTime.now().millisecondsSinceEpoch}_$count',
        name: h.name,
        emoji: h.emoji,
        colorValue: routine.color.toARGB32(),
        category: h.category,
        frequency: 'daily',
        time: h.time,
        reminderEnabled: true,
        createdAt: DateTime.now(),
      );
      await DatabaseService.addHabit(habit);
      count++;
    }

    await BadgeService.checkAllBadges();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${routine.emoji} $count habits added! 🎉'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showProDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        title: Row(
          children: [
            const Text('👑 ', style: TextStyle(fontSize: 24)),
            const Expanded(
              child: Text(
                'Unlock Full Power',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
          ],
        ),
        content: const Text(
          'Smart Routines PRO Features:\n\n'
              '• Add ALL habits in 1 click\n'
              '• Unlimited routines access\n'
              '• No need to watch ads\n'
              '• Smart time scheduling\n'
              '• All future routines included\n\n'
              'Upgrade now to transform your life!',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProVersionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Upgrade',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class RoutineTemplate {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color color;
  final List<RoutineHabit> habits;

  RoutineTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    required this.habits,
  });
}

class RoutineHabit {
  final String emoji;
  final String name;
  final String time;
  final String category;

  RoutineHabit({
    required this.emoji,
    required this.name,
    required this.time,
    required this.category,
  });
}