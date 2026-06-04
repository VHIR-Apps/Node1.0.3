// lib/screens/smart_routine_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
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

class _SmartRoutineScreenState extends State<SmartRoutineScreen>
    with TickerProviderStateMixin {
  String _selectedRoutine = 'productive';
  String _currentSeason = '';
  String _detectedCountry = '';
  bool _isAdLoading = false;
  bool _isPro = false;
  String _selectedCategory = 'All';

  late Map<String, RoutineTemplate> _routines;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _detectSeasonAndCountry();
    _routines = _buildAdvancedRoutines();
    _cleanupExpiredUnlocks();
    _isPro = DatabaseService.isProOrVipUser();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutBack,
    );
    _headerController.forward();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  Map<String, RoutineTemplate> _buildAdvancedRoutines() {
    final month = DateTime.now().month;

    Map<String, RoutineTemplate> templates = {
      // ══════════════════════════════════════════════
      // 1. MONK MODE CEO - Deep Work & Leadership
      // ══════════════════════════════════════════════
      'productive': RoutineTemplate(
        id: 'productive',
        name: 'Monk Mode CEO',
        emoji: '🚀',
        subtitle: 'Deep Focus & Peak Output',
        description:
        'Based on Cal Newport\'s Deep Work, Andrew Huberman\'s protocols, and Tim Ferriss\'s 4-Hour framework. Engineered for 10x productivity.',
        color: const Color(0xFF6C63FF),
        gradient: const [Color(0xFF6C63FF), Color(0xFF4834DF)],
        icon: Icons.rocket_launch_rounded,
        categoryTag: 'Productivity',
        difficulty: 'Advanced',
        estimatedTime: '17 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Wake Up Immediately (Zero Snooze Protocol)', time: '04:30', category: 'Discipline', tip: 'Place alarm across room. Andrew Huberman: delay snooze = stronger cortisol awakening response.'),
          RoutineHabit(emoji: '💧', name: 'Hydrate: 500ml Water + Himalayan Salt + Lemon', time: '04:35', category: 'Health', tip: 'Rehydrate after 7-8hr fast. Salt adds electrolytes for neural function.'),
          RoutineHabit(emoji: '🧊', name: 'Cold Exposure: 2-min Cold Shower', time: '04:40', category: 'Biohacking', tip: 'Increases dopamine 2.5x for 3+ hours (Huberman Lab). Boosts alertness & willpower.'),
          RoutineHabit(emoji: '🧘', name: 'Mindfulness: 10-min Macro Goal Visualization', time: '04:50', category: 'Mindset', tip: 'Visualize your ideal day outcome. Activates reticular activating system (RAS).'),
          RoutineHabit(emoji: '☀️', name: 'Sunlight Viewing: 10-min Outdoor Light Exposure', time: '05:00', category: 'Health', tip: 'Huberman: morning sunlight sets circadian clock, boosts cortisol & suppresses melatonin.'),
          RoutineHabit(emoji: '🎯', name: 'Deep Work Block 1: "Eat the Frog" (Most Important Task)', time: '05:30', category: 'Productivity', tip: 'Brian Tracy method: hardest task first. Peak cortisol = peak cognitive performance.'),
          RoutineHabit(emoji: '🍳', name: 'Brain-Fuel Breakfast: High Protein + Healthy Fats', time: '07:30', category: 'Nutrition', tip: 'Eggs, avocado, nuts. Protein stabilizes blood sugar; fats fuel brain (no carb crash).'),
          RoutineHabit(emoji: '🧠', name: 'Deep Work Block 2: Core Project Execution', time: '08:30', category: 'Productivity', tip: 'Cal Newport: 4hrs of deep work daily = world-class output. Use Pomodoro 52/17.'),
          RoutineHabit(emoji: '🚶', name: 'Optic Flow Walk: 20-min Zone 2 + Audio Learning', time: '12:00', category: 'Health', tip: 'Walking reduces anxiety via optic flow (Huberman). Zone 2 = fat burning without fatigue.'),
          RoutineHabit(emoji: '🥗', name: 'Performance Lunch: Balanced Macros + Greens', time: '12:30', category: 'Nutrition', tip: 'Avoid heavy carbs midday. Include fiber + protein for sustained afternoon energy.'),
          RoutineHabit(emoji: '📧', name: 'Shallow Work Block: Emails, Admin, Calls', time: '13:30', category: 'Work', tip: 'Batch process communications. Never check email during deep work blocks.'),
          RoutineHabit(emoji: '⚡', name: 'NSDR Protocol: 20-min Non-Sleep Deep Rest', time: '15:00', category: 'Recovery', tip: 'Huberman: NSDR restores dopamine, enhances learning retention. Better than naps.'),
          RoutineHabit(emoji: '📝', name: 'Daily Shutdown Ritual: Plan Tomorrow + Close Loops', time: '17:00', category: 'Productivity', tip: 'Cal Newport shutdown ritual. Write tomorrow\'s priorities = reduced anxiety.'),
          RoutineHabit(emoji: '🏋️', name: 'Strength Training: Compound Movements 45-60 min', time: '17:30', category: 'Fitness', tip: 'Late afternoon = peak strength. Focus on squats, deadlifts, bench, rows.'),
          RoutineHabit(emoji: '👨‍👩‍👧', name: 'High-Quality Social Connection: Family/Friends', time: '19:00', category: 'Social', tip: 'Harvard 80-year study: relationships are #1 predictor of happiness & longevity.'),
          RoutineHabit(emoji: '📚', name: 'Read 20+ Pages: Non-Fiction / Biography', time: '20:30', category: 'Learning', tip: 'Warren Buffett reads 5hrs/day. Even 20 pages = 30+ books/year.'),
          RoutineHabit(emoji: '📵', name: 'Digital Sunset: All Screens Off', time: '21:00', category: 'Wellness', tip: 'Blue light suppresses melatonin by 50%. Use blue blockers or stop screens 1hr before bed.'),
          RoutineHabit(emoji: '😴', name: 'Sleep Optimization: Cold Room, Pitch Black, 7-8hrs', time: '21:30', category: 'Health', tip: 'Matthew Walker: 65-68°F, blackout curtains. Sleep is #1 performance enhancer.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 2. ELITE ATHLETE - Peak Physical Performance
      // ══════════════════════════════════════════════
      'fitness': RoutineTemplate(
        id: 'fitness',
        name: 'Elite Athlete',
        emoji: '💪',
        subtitle: 'Peak Physical Performance',
        description:
        'Engineered from sports science research, Jeff Nippard\'s hypertrophy protocols, and Dr. Andy Galpin\'s performance science.',
        color: const Color(0xFF10B981),
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
        icon: Icons.fitness_center_rounded,
        categoryTag: 'Fitness',
        difficulty: 'Advanced',
        estimatedTime: '16 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Rise & Circadian Reset: Natural Light Exposure', time: '05:30', category: 'Health', tip: 'Get 100,000 lux within 30 min of waking for hormonal optimization.'),
          RoutineHabit(emoji: '💧', name: 'Mega Hydration: 750ml Water + Electrolyte Complex', time: '05:40', category: 'Nutrition', tip: 'Dr. Galpin: bodyweight(lbs)/2 = daily oz water. Start strong in AM.'),
          RoutineHabit(emoji: '🍌', name: 'Pre-Workout Fuel: Banana + Coffee (30 min before)', time: '05:50', category: 'Nutrition', tip: 'Caffeine peaks 30-60 min post-ingestion. Simple carbs = quick glycogen.'),
          RoutineHabit(emoji: '🤸', name: 'Dynamic Warm-Up: Mobility + Activation Circuit', time: '06:10', category: 'Fitness', tip: '10-min: hip circles, band pull-aparts, leg swings. Reduces injury risk 50%.'),
          RoutineHabit(emoji: '🏋️', name: 'Progressive Overload Training: Compound Focus', time: '06:30', category: 'Fitness', tip: 'Jeff Nippard: 10-20 sets/muscle/week. Track weights. Progressive overload = growth.'),
          RoutineHabit(emoji: '🥩', name: 'Anabolic Breakfast: 40g+ Protein Within 1hr Post-Workout', time: '08:00', category: 'Nutrition', tip: 'Muscle protein synthesis peaks post-workout. Hit leucine threshold (2.5g+).'),
          RoutineHabit(emoji: '💼', name: 'Active Work Setup: Standing Desk + Movement Breaks', time: '09:00', category: 'Work', tip: 'Set 30-min timers. Stand, stretch, or walk. Sitting is the new smoking.'),
          RoutineHabit(emoji: '💧', name: 'Hydration Checkpoint: Goal 2L by Noon', time: '12:00', category: 'Health', tip: 'Dehydration of 2% reduces performance 20%. Track water intake religiously.'),
          RoutineHabit(emoji: '🥗', name: 'Macro-Optimized Lunch: Protein + Complex Carbs + Veggies', time: '13:00', category: 'Nutrition', tip: 'Aim 40P/40C/20F split for performance. Include colorful vegetables for micronutrients.'),
          RoutineHabit(emoji: '🚶', name: 'Post-Meal Digestion Walk: 15 min Light Movement', time: '13:30', category: 'Recovery', tip: 'Reduces blood glucose spike by 30%. Aids digestion and prevents afternoon crash.'),
          RoutineHabit(emoji: '🧘', name: 'Active Recovery: Yoga / Mobility Flow (20 min)', time: '15:00', category: 'Recovery', tip: 'Reduces DOMS, improves range of motion, and supports parasympathetic recovery.'),
          RoutineHabit(emoji: '🏃', name: 'Zone 2 Cardio: 30-45 min (120-140 BPM)', time: '17:30', category: 'Fitness', tip: 'Dr. Peter Attia: Zone 2 = mitochondrial health. Nose-breathe throughout.'),
          RoutineHabit(emoji: '🥑', name: 'Recovery Dinner: Lean Protein + Anti-inflammatory Foods', time: '19:00', category: 'Nutrition', tip: 'Salmon, sweet potato, broccoli. Omega-3s reduce inflammation from training.'),
          RoutineHabit(emoji: '🧊', name: 'Contrast Therapy: Hot Sauna + Cold Plunge', time: '20:00', category: 'Recovery', tip: 'Sauna 15 min → cold 2 min x3. Increases growth hormone 200-300% (Rhonda Patrick).'),
          RoutineHabit(emoji: '🧘', name: 'Deep Stretching: Static Hold + Foam Rolling (15 min)', time: '20:30', category: 'Recovery', tip: 'Hold stretches 60+ sec for tissue remodeling. Foam roll tight areas.'),
          RoutineHabit(emoji: '💊', name: 'Sleep Stack: Magnesium Glycinate + Zinc + Vitamin D', time: '21:30', category: 'Health', tip: 'Magnesium relaxes muscles. Zinc supports testosterone. D3 for recovery.'),
          RoutineHabit(emoji: '😴', name: 'Deep Recovery Sleep: 8-9 Hours (Growth Hormone Peak)', time: '22:00', category: 'Health', tip: 'GH secreted in deep sleep. Sleep = when muscles actually grow. Non-negotiable.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 3. HOLISTIC REBIRTH - Self-Care & Healing
      // ══════════════════════════════════════════════
      'selfcare': RoutineTemplate(
        id: 'selfcare',
        name: 'Holistic Rebirth',
        emoji: '✨',
        subtitle: 'Heal, Glow & Thrive',
        description:
        'Rooted in Ayurveda, Traditional Chinese Medicine, and modern nervous system science. Designed to heal burnout and restore radiance.',
        color: const Color(0xFFEC4899),
        gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
        icon: Icons.spa_rounded,
        categoryTag: 'Self-Care',
        difficulty: 'Beginner',
        estimatedTime: '14 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '🌅', name: 'Gentle Awakening: Natural Light (No Alarms)', time: '07:00', category: 'Wellness', tip: 'Cortisol awakening response is gentler with light vs alarm. Less stress hormones.'),
          RoutineHabit(emoji: '🧘', name: 'Morning Meditation: 15-min Loving-Kindness or Body Scan', time: '07:10', category: 'Mindfulness', tip: 'Meta-analysis: 8 weeks of meditation reduces anxiety 60% and increases grey matter.'),
          RoutineHabit(emoji: '📓', name: 'Gratitude Journaling: 3 Things + Why They Matter', time: '07:30', category: 'Mindfulness', tip: 'Dr. Emmons research: gratitude journaling increases happiness by 25% in 10 weeks.'),
          RoutineHabit(emoji: '🍵', name: 'Morning Ritual: Warm Lemon Water or Ceremonial Matcha', time: '07:45', category: 'Health', tip: 'Warm water stimulates digestion. Matcha = L-theanine for calm focus without jitters.'),
          RoutineHabit(emoji: '🧴', name: 'Glow Protocol: Gua Sha + Ice Roller + Serum Layering', time: '08:00', category: 'Self-Care', tip: 'Gua sha increases circulation 400%. Layer: toner → serum → moisturizer → SPF.'),
          RoutineHabit(emoji: '🥑', name: 'Nourishing Breakfast: Antioxidant Bowl + Collagen', time: '08:30', category: 'Nutrition', tip: 'Berries, acai, chia seeds, collagen peptides. Feed your skin from the inside out.'),
          RoutineHabit(emoji: '📝', name: 'Morning Pages: 3 Pages Free-Stream Journaling', time: '09:00', category: 'Mindfulness', tip: 'Julia Cameron method: clears mental clutter, accesses subconscious creativity.'),
          RoutineHabit(emoji: '🎨', name: 'Creative Flow Hour: Art, Music, Writing, Crafts', time: '10:00', category: 'Creative', tip: 'Csikszentmihalyi\'s Flow State: creative work releases endorphins and dopamine naturally.'),
          RoutineHabit(emoji: '🫖', name: 'Mindful Tea Ceremony: Herbal Blend + No Screens', time: '11:00', category: 'Wellness', tip: 'Chamomile reduces cortisol. The ritual itself activates parasympathetic nervous system.'),
          RoutineHabit(emoji: '🥗', name: 'Rainbow Lunch: 5+ Colors on Your Plate', time: '13:00', category: 'Nutrition', tip: 'Each color = different phytonutrients. Variety maximizes micronutrient intake.'),
          RoutineHabit(emoji: '🌳', name: 'Forest Bathing: 30-min Nature Immersion (Shinrin-yoku)', time: '15:30', category: 'Wellness', tip: 'Japanese research: forest bathing lowers cortisol 16%, blood pressure, and boosts NK cells.'),
          RoutineHabit(emoji: '📖', name: 'Gentle Reading: Fiction, Poetry, or Spiritual Text', time: '17:00', category: 'Relaxation', tip: 'Reading fiction increases empathy by 10% (York University). Escapism heals the mind.'),
          RoutineHabit(emoji: '🧘‍♀️', name: 'Yin Yoga: 30-min Deep Stretch + Breathwork', time: '18:30', category: 'Wellness', tip: 'Hold poses 3-5 min. Targets fascia and connective tissue. Activates rest-digest mode.'),
          RoutineHabit(emoji: '🛁', name: 'Luxury Bath: Epsom Salt + Essential Oils + Candles', time: '20:00', category: 'Self-Care', tip: 'Magnesium absorbs through skin. Lavender oil reduces anxiety. Water therapy = hydrotherapy.'),
          RoutineHabit(emoji: '🕯️', name: 'Ambient Wind-Down: Dim All Lights to Warm Tones', time: '20:30', category: 'Wellness', tip: 'Dim lighting signals melatonin production. Use salt lamps or candlelight only.'),
          RoutineHabit(emoji: '💆', name: 'Night Repair Protocol: Retinol + Peptide + Face Massage', time: '21:00', category: 'Self-Care', tip: 'Skin repairs overnight. Layer actives: retinol → peptides → rich moisturizer.'),
          RoutineHabit(emoji: '🌙', name: 'Yoga Nidra: 20-min Guided Sleep Meditation', time: '21:30', category: 'Relaxation', tip: '30 min of Yoga Nidra = 2 hours of sleep quality. Military uses it for trauma recovery.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 4. VIRAL VISIONARY - Content Creator Empire
      // ══════════════════════════════════════════════
      'creator': RoutineTemplate(
        id: 'creator',
        name: 'Viral Visionary',
        emoji: '🎬',
        subtitle: 'Content Empire Builder',
        description:
        'Reverse-engineered from MrBeast\'s workflow, Ali Abdaal\'s productivity, and Gary Vee\'s content machine. Build your media empire.',
        color: const Color(0xFFF97316),
        gradient: const [Color(0xFFF97316), Color(0xFFEA580C)],
        icon: Icons.videocam_rounded,
        categoryTag: 'Creator',
        difficulty: 'Intermediate',
        estimatedTime: '15 hours',
        scienceBacked: false,
        habits: [
          RoutineHabit(emoji: '⚡', name: 'Creator Morning: Walk + Black Coffee + Idea Capture', time: '06:30', category: 'Energy', tip: 'Morning walks generate 60% more creative ideas (Stanford study). Voice memo everything.'),
          RoutineHabit(emoji: '📱', name: 'Trend Radar: Scan TikTok/Reels/X for 30 min MAX', time: '07:30', category: 'Research', tip: 'Set timer. Save 10-15 trending formats/hooks. Identify patterns, don\'t consume mindlessly.'),
          RoutineHabit(emoji: '🧠', name: 'Content Brainstorm: 10 Title/Hook Ideas (No Filtering)', time: '08:00', category: 'Creative', tip: 'MrBeast: write 100 titles, pick the best 3. Quantity breeds quality.'),
          RoutineHabit(emoji: '✍️', name: 'Script Engineering: Hook → Story → CTA Framework', time: '08:30', category: 'Creative', tip: 'First 3 seconds = 80% of retention. Pattern interrupt hooks win every time.'),
          RoutineHabit(emoji: '📸', name: 'High-Energy Filming Block: Batch 3-5 Videos', time: '10:00', category: 'Creation', tip: 'Batch filming saves 60% time vs daily. Do makeup/setup once, film multiple videos.'),
          RoutineHabit(emoji: '🥗', name: 'Light Creator Lunch: Avoid Carb Coma', time: '13:00', category: 'Health', tip: 'Heavy carbs = dopamine crash = no creative energy. Salad + protein + coffee.'),
          RoutineHabit(emoji: '💻', name: 'Focused Editing Block: Sound Design + Color Grade', time: '14:00', category: 'Work', tip: 'Edit in passes: 1) rough cut 2) sound 3) color 4) text/effects 5) final review.'),
          RoutineHabit(emoji: '📝', name: 'Thumbnail A/B Design: Create 3 Options Per Video', time: '16:00', category: 'Creative', tip: 'Thumbnail = 90% of click-through rate. Test faces, contrast, curiosity gaps.'),
          RoutineHabit(emoji: '🚀', name: 'Strategic Posting: Optimal Time + SEO Description', time: '17:00', category: 'Social', tip: 'Post when your audience is online (check analytics). First 60 min engagement = algorithm boost.'),
          RoutineHabit(emoji: '💬', name: 'Community Engagement: Reply Comments for 30 min', time: '17:30', category: 'Social', tip: 'Reply with questions to boost comment threads. Algorithm rewards conversation.'),
          RoutineHabit(emoji: '📊', name: 'Analytics Deep-Dive: What Worked & Why', time: '18:00', category: 'Business', tip: 'Track: CTR, AVD (average view duration), and subscriber conversion. Double down on winners.'),
          RoutineHabit(emoji: '🕸️', name: 'Creator Networking: Collab DMs + Community Building', time: '19:00', category: 'Social', tip: 'Collaborate with creators at your level or slightly above. Cross-pollinate audiences.'),
          RoutineHabit(emoji: '📚', name: 'Skill Upgrade: Learn New Editing Technique (30 min)', time: '20:00', category: 'Learning', tip: 'YouTube editing tutorials, After Effects tricks, AI tools. Stay ahead of the curve.'),
          RoutineHabit(emoji: '📋', name: 'Content Calendar: Map Next 7 Days of Posts', time: '21:00', category: 'Planning', tip: 'Plan content in weekly batches. Include: topic, hook, format, platform, posting time.'),
          RoutineHabit(emoji: '😴', name: 'Creator Recovery: Phone Down + Quality Sleep', time: '22:00', category: 'Health', tip: 'Burnout kills creativity. Protect sleep like it\'s your most important content strategy.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 5. MINIMALIST RESET - Simple & Powerful
      // ══════════════════════════════════════════════
      'minimal': RoutineTemplate(
        id: 'minimal',
        name: 'Minimalist Reset',
        emoji: '🌿',
        subtitle: 'Less is More',
        description:
        'Inspired by James Clear\'s Atomic Habits 2-minute rule and essentialism. Perfect for beginners or burnout recovery.',
        color: const Color(0xFF14B8A6),
        gradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
        icon: Icons.eco_rounded,
        categoryTag: 'Minimalist',
        difficulty: 'Beginner',
        estimatedTime: '2 hours total',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '💧', name: 'Drink One Full Glass of Water', time: '07:00', category: 'Health', tip: 'James Clear: make the habit so easy you can\'t say no. One glass. That\'s it.'),
          RoutineHabit(emoji: '🛏️', name: 'Make Your Bed Perfectly', time: '07:05', category: 'Organization', tip: 'Admiral McRaven: making your bed = first accomplishment of the day. Momentum builds.'),
          RoutineHabit(emoji: '🧘', name: '5 Deep Breaths: Box Breathing (4-4-4-4)', time: '07:10', category: 'Mindfulness', tip: 'Navy SEALs use box breathing to stay calm. 5 cycles = reset your nervous system.'),
          RoutineHabit(emoji: '🚶', name: '15-Min Silent Walk: No Music, No Podcast', time: '07:15', category: 'Fitness', tip: 'Walking without input lets your brain default-mode network process and create.'),
          RoutineHabit(emoji: '📓', name: 'Write 3 Priorities for Today', time: '08:00', category: 'Planning', tip: 'Gary Keller (The ONE Thing): What\'s the ONE thing that makes everything else easier?'),
          RoutineHabit(emoji: '💼', name: 'Execute Priority #1 First (No Distractions)', time: '08:30', category: 'Productivity', tip: 'Single-tasking > multitasking. Phone on airplane mode. One tab open. Execute.'),
          RoutineHabit(emoji: '🧹', name: '10-Min Tidy: Reset Your Physical Environment', time: '18:00', category: 'Organization', tip: 'External order = internal calm. Clean space reduces cortisol and increases focus.'),
          RoutineHabit(emoji: '📖', name: 'Read 5 Pages of Any Book', time: '20:30', category: 'Learning', tip: '5 pages/day = 1,825 pages/year = 7+ books/year. Small habit, massive compound effect.'),
          RoutineHabit(emoji: '📵', name: 'Phone on Charger Outside Bedroom', time: '21:30', category: 'Wellness', tip: 'Removing phone from bedroom improves sleep quality 40% and reduces morning anxiety.'),
          RoutineHabit(emoji: '😴', name: 'Lights Out & Sleep', time: '22:00', category: 'Health', tip: 'Consistent sleep time is more important than sleep duration. Same time every night.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 6. TRANSFORMATIVE BELIEVER - Islamic Excellence
      // ══════════════════════════════════════════════
      'islamic': RoutineTemplate(
        id: 'islamic',
        name: 'Transformative Believer',
        emoji: '🕌',
        subtitle: 'Deen & Dunya Excellence',
        description:
        'A comprehensive daily framework combining Islamic worship, Prophetic Sunnah practices, and modern productivity for the striving Muslim.',
        color: const Color(0xFF059669),
        gradient: const [Color(0xFF059669), Color(0xFF047857)],
        icon: Icons.auto_awesome_rounded,
        categoryTag: 'Spiritual',
        difficulty: 'Intermediate',
        estimatedTime: '18 hours',
        scienceBacked: false,
        habits: [
          RoutineHabit(emoji: '🌌', name: 'Tahajjud & Heartfelt Dua (Last Third of Night)', time: '04:00', category: 'Spiritual', tip: 'Prophet ﷺ said: "The closest a servant is to his Lord is in the last third of the night."'),
          RoutineHabit(emoji: '🌅', name: 'Fajr Prayer in Congregation + Sunnah Rakaat', time: '04:45', category: 'Spiritual', tip: '"The two Sunnah of Fajr are better than the world and all it contains." — Muslim'),
          RoutineHabit(emoji: '📖', name: 'Quran Recitation: 1 Juz or Memorization Block', time: '05:15', category: 'Spiritual', tip: 'Best time for hifz. Morning brain = fresh memory. Aim for 1 page new + 5 pages review.'),
          RoutineHabit(emoji: '🤲', name: 'Morning Adhkar: Full Fortress of the Muslim Set', time: '05:45', category: 'Spiritual', tip: 'Protection for the entire day. Include: Ayatul Kursi, 3 Quls, and morning supplications.'),
          RoutineHabit(emoji: '🍯', name: 'Sunnah Breakfast: Honey + Dates + Black Seed', time: '06:00', category: 'Nutrition', tip: 'Prophet ﷺ ate dates, honey, olive oil, and black seed (cure for everything except death).'),
          RoutineHabit(emoji: '💼', name: 'Deep Work: Halal Earning / Study / Skill Building', time: '08:00', category: 'Productivity', tip: '"No one has ever eaten food better than eating from the work of his own hands." — Bukhari'),
          RoutineHabit(emoji: '🌤️', name: 'Duha Prayer: 2-4 Rakaat (Charity for Every Joint)', time: '09:30', category: 'Spiritual', tip: '"Every joint must give charity daily. Two rakaat of Duha fulfills all of that." — Muslim'),
          RoutineHabit(emoji: '☀️', name: 'Dhuhr Prayer + 4 Sunnah Before & 2 After', time: '13:00', category: 'Spiritual', tip: 'The Rawatib Sunnah prayers build a house in Jannah for the one who preserves them.'),
          RoutineHabit(emoji: '📚', name: 'Islamic Knowledge Hour: Tafsir / Hadith / Fiqh', time: '14:00', category: 'Learning', tip: '"Whoever takes a path seeking knowledge, Allah makes easy a path to Jannah." — Muslim'),
          RoutineHabit(emoji: '🌤️', name: 'Asr Prayer + Evening Adhkar', time: '16:00', category: 'Spiritual', tip: 'Prophet ﷺ warned against missing Asr. Complete evening adhkar for night protection.'),
          RoutineHabit(emoji: '🏃', name: 'Physical Training: Sunnah Sports or Exercise', time: '17:00', category: 'Fitness', tip: '"The strong believer is better than the weak believer." — Muslim. Swimming, archery, riding.'),
          RoutineHabit(emoji: '🌇', name: 'Maghrib Prayer + 2 Sunnah After', time: '18:00', category: 'Spiritual', tip: 'Don\'t delay Maghrib. Prophet ﷺ prayed immediately after sunset.'),
          RoutineHabit(emoji: '👨‍👩‍👧', name: 'Family Time: Silat-ur-Rahim & Quality Connection', time: '18:30', category: 'Social', tip: '"The one who severs family ties will not enter Jannah." — Bukhari. Invest in family daily.'),
          RoutineHabit(emoji: '🌙', name: 'Isha Prayer + Witr + Night Adhkar', time: '20:00', category: 'Spiritual', tip: 'End prayer with Witr. Make it your last act of worship before sleep.'),
          RoutineHabit(emoji: '📝', name: 'Muhasabah: Daily Self-Accountability Journaling', time: '21:30', category: 'Mindset', tip: 'Umar ibn Al-Khattab: "Take account of yourselves before you are held accountable."'),
          RoutineHabit(emoji: '😴', name: 'Sleep with Sunnah: Wudu, Right Side, Mulk, 3 Quls', time: '22:00', category: 'Health', tip: 'Sleep in wudu, recite Surah Mulk (protection from grave), blow on hands with 3 Quls.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 7. STUDENT DOMINATOR - Academic Excellence
      // ══════════════════════════════════════════════
      'student': RoutineTemplate(
        id: 'student',
        name: 'Student Dominator',
        emoji: '🎓',
        subtitle: 'Ace Every Exam',
        description:
        'Based on Anki spaced repetition, Feynman technique, active recall research, and Cal Newport\'s Straight-A Student methodology.',
        color: const Color(0xFF8B5CF6),
        gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        icon: Icons.school_rounded,
        categoryTag: 'Education',
        difficulty: 'Intermediate',
        estimatedTime: '15 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Wake Up Early: Own the Morning Before Class', time: '06:00', category: 'Discipline', tip: 'Students who wake early score 0.5 GPA higher on average (Texas University study).'),
          RoutineHabit(emoji: '💧', name: 'Hydrate + Brain-Boosting Breakfast', time: '06:10', category: 'Nutrition', tip: 'Eggs + blueberries + walnuts = choline + antioxidants + omega-3 for brain.'),
          RoutineHabit(emoji: '📝', name: 'Spaced Repetition Review: Anki Cards (30 min)', time: '06:30', category: 'Study', tip: 'Ebbinghaus forgetting curve: review at 1, 3, 7, 14, 30 days. Anki automates this.'),
          RoutineHabit(emoji: '🧠', name: 'Deep Study Block 1: Hardest Subject (Pomodoro 25/5)', time: '07:00', category: 'Study', tip: 'Tackle hardest material when prefrontal cortex is freshest. Use active recall, not re-reading.'),
          RoutineHabit(emoji: '🏫', name: 'Attend Classes: Front Row, Active Notes, Ask Questions', time: '09:00', category: 'Education', tip: 'Front-row students score 0.7 GPA higher. Ask 1 question per class minimum.'),
          RoutineHabit(emoji: '📓', name: 'Post-Class Processing: Rewrite Notes in Own Words', time: '12:00', category: 'Study', tip: 'Feynman technique: if you can\'t explain it simply, you don\'t understand it.'),
          RoutineHabit(emoji: '🥗', name: 'Brain-Fuel Lunch: Protein + Complex Carbs', time: '12:30', category: 'Nutrition', tip: 'Avoid sugary/processed food. Salmon, quinoa, leafy greens = sustained brain energy.'),
          RoutineHabit(emoji: '📚', name: 'Deep Study Block 2: Practice Problems & Past Papers', time: '14:00', category: 'Study', tip: 'Testing effect: practicing retrieval is 50% more effective than re-reading (Roediger 2006).'),
          RoutineHabit(emoji: '🏃', name: 'Exercise Break: 30 min Cardio or Sport', time: '16:00', category: 'Fitness', tip: 'Naperville study: exercise before studying improves learning by 30%. BDNF boosts neuroplasticity.'),
          RoutineHabit(emoji: '👥', name: 'Study Group: Teach Others & Discuss Concepts', time: '17:00', category: 'Social', tip: 'Teaching others = 90% retention (Learning Pyramid). Find a study partner or group.'),
          RoutineHabit(emoji: '🎯', name: 'Deep Study Block 3: Weak Areas & Gap Analysis', time: '19:00', category: 'Study', tip: 'Identify what you DON\'T know. Deliberate practice on weaknesses = fastest improvement.'),
          RoutineHabit(emoji: '📋', name: 'Plan Tomorrow: Set 3 Study Goals + Time Blocks', time: '21:00', category: 'Planning', tip: 'Students who plan study sessions score 23% higher than those who "wing it."'),
          RoutineHabit(emoji: '📖', name: 'Pre-Sleep Review: Read Tomorrow\'s Material Lightly', time: '21:30', category: 'Study', tip: 'Priming effect: pre-reading before class doubles comprehension during lecture.'),
          RoutineHabit(emoji: '😴', name: 'Sleep 8 Hours: Memory Consolidation Happens Here', time: '22:00', category: 'Health', tip: 'Walker: sleeping <6hrs before exam = 40% less memory retention. Sleep IS studying.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 8. STOIC WARRIOR - Mental Toughness
      // ══════════════════════════════════════════════
      'stoic': RoutineTemplate(
        id: 'stoic',
        name: 'Stoic Warrior',
        emoji: '⚔️',
        subtitle: 'Unshakeable Mind',
        description:
        'Built on Marcus Aurelius\' Meditations, Seneca\'s Letters, David Goggins\' discipline, and Jocko Willink\'s extreme ownership.',
        color: const Color(0xFF475569),
        gradient: const [Color(0xFF475569), Color(0xFF334155)],
        icon: Icons.shield_rounded,
        categoryTag: 'Mindset',
        difficulty: 'Advanced',
        estimatedTime: '16 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Wake at 04:30: Discipline Equals Freedom', time: '04:30', category: 'Discipline', tip: 'Jocko Willink: "Discipline equals freedom." The alarm is your first battle. Win it.'),
          RoutineHabit(emoji: '🧊', name: 'Voluntary Discomfort: 5-min Cold Shower', time: '04:35', category: 'Toughness', tip: 'Seneca: "Set aside a number of days for voluntary discomfort." Cold builds mental armor.'),
          RoutineHabit(emoji: '📓', name: 'Premeditatio Malorum: Prepare for the Worst Scenario', time: '04:45', category: 'Stoicism', tip: 'Marcus Aurelius journal practice: imagine worst case, plan response, feel peace in preparedness.'),
          RoutineHabit(emoji: '🏋️', name: 'Physical Training: Push Beyond Perceived Limits', time: '05:00', category: 'Fitness', tip: 'Goggins 40% Rule: when you think you\'re done, you\'re only at 40% capacity.'),
          RoutineHabit(emoji: '📖', name: 'Read Stoic Philosophy: 15 min (Meditations/Letters)', time: '06:15', category: 'Learning', tip: '"The impediment to action advances action. What stands in the way becomes the way." — Marcus Aurelius'),
          RoutineHabit(emoji: '💧', name: 'Fuel the Machine: Water + Whole Food Breakfast', time: '06:30', category: 'Nutrition', tip: 'Eat to perform, not to indulge. Simple, nutritious, no excess. Stoic moderation in diet.'),
          RoutineHabit(emoji: '🎯', name: 'Identify the ONE Thing: Most Impactful Task Today', time: '07:00', category: 'Productivity', tip: 'Seneca: "It is not that we have a short time to live, but that we waste much of it."'),
          RoutineHabit(emoji: '💼', name: 'Deep Work: Execute with Extreme Ownership', time: '07:30', category: 'Work', tip: 'Jocko: no excuses, no blame. Own every outcome. Take complete responsibility.'),
          RoutineHabit(emoji: '🚶', name: 'Solitary Walk: Reflect on Decisions & Actions', time: '12:00', category: 'Reflection', tip: 'Peripatetic philosophy: walking stimulates thought. Review morning actions. Course-correct.'),
          RoutineHabit(emoji: '🤐', name: 'Practice Silence: 1 Hour of No Speaking', time: '14:00', category: 'Discipline', tip: 'Epictetus: "We have two ears and one mouth for a reason." Silence builds self-mastery.'),
          RoutineHabit(emoji: '✍️', name: 'Evening Journaling: What Went Wrong? How to Improve?', time: '20:00', category: 'Reflection', tip: 'Seneca\'s nightly review: "What disease of yours did you cure today? What vice did you resist?"'),
          RoutineHabit(emoji: '🙏', name: 'Memento Mori: Reflect on Mortality (1 min)', time: '21:00', category: 'Stoicism', tip: '"Let us prepare our minds as if we\'d come to the very end of life." — Seneca'),
          RoutineHabit(emoji: '📵', name: 'Digital Detach: No Screens After This Point', time: '21:15', category: 'Discipline', tip: 'Marcus Aurelius had no phone, no Netflix, no doom-scrolling. And he ran an empire.'),
          RoutineHabit(emoji: '😴', name: 'Stoic Rest: Sleep with Clear Conscience', time: '21:30', category: 'Health', tip: '"I have lived today." If you can say that honestly, you\'ve won the day. Rest well, warrior.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 9. BIOHACKER PROTOCOL - Optimize Everything
      // ══════════════════════════════════════════════
      'biohacker': RoutineTemplate(
        id: 'biohacker',
        name: 'Biohacker Protocol',
        emoji: '🧬',
        subtitle: 'Optimize Human Performance',
        description:
        'Synthesized from Bryan Johnson\'s Blueprint, Andrew Huberman\'s toolkit, Dave Asprey\'s biohacking, and Dr. Peter Attia\'s longevity protocols.',
        color: const Color(0xFF06B6D4),
        gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
        icon: Icons.biotech_rounded,
        categoryTag: 'Biohacking',
        difficulty: 'Expert',
        estimatedTime: '18 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Chronotype-Aligned Wake: Consistent Time Daily', time: '05:00', category: 'Circadian', tip: 'Bryan Johnson wakes at 5:00 AM every day including weekends. Consistency > duration.'),
          RoutineHabit(emoji: '☀️', name: 'Photon Protocol: 10-min Direct Sunlight Exposure', time: '05:10', category: 'Circadian', tip: 'Huberman: sunlight viewing resets suprachiasmatic nucleus. 100,000 lux = optimal cortisol trigger.'),
          RoutineHabit(emoji: '💊', name: 'Morning Stack: Lions Mane + Omega-3 + Vitamin D3+K2', time: '05:20', category: 'Supplements', tip: 'Lions Mane: neurogenesis. Omega-3: anti-inflammatory. D3+K2: calcium metabolism + immunity.'),
          RoutineHabit(emoji: '🧊', name: 'Deliberate Cold: 3-min 50°F Immersion', time: '05:30', category: 'Hormesis', tip: 'Huberman: 11 min/week total cold exposure. Dopamine increase 2.5x lasting 3+ hours.'),
          RoutineHabit(emoji: '🧘', name: 'Breathwork: Wim Hof or Physiological Sigh Protocol', time: '05:45', category: 'Nervous System', tip: 'Physiological sigh (double inhale + long exhale) = fastest way to reduce stress in real-time.'),
          RoutineHabit(emoji: '🏋️', name: 'Zone 2 Cardio + Resistance Training (Alternating)', time: '06:00', category: 'Fitness', tip: 'Peter Attia: 3-4 days Zone 2, 3 days strength. VO2 max is #1 longevity predictor.'),
          RoutineHabit(emoji: '🥬', name: 'Blueprint Breakfast: Super Veggie Blend + Protein', time: '07:30', category: 'Nutrition', tip: 'Bryan Johnson\'s Super Veggie: broccoli, cauliflower, garlic, ginger, hemp seeds, lentils.'),
          RoutineHabit(emoji: '🧠', name: 'Cognitive Enhancement: 90-min Ultradian Deep Work', time: '08:30', category: 'Productivity', tip: 'Brain works in 90-min ultradian cycles. Work with biology, not against it.'),
          RoutineHabit(emoji: '💡', name: 'Red Light Therapy: 10-min Face + Body Panel', time: '10:00', category: 'Recovery', tip: 'Near-infrared (660-850nm) increases mitochondrial ATP production. Skin, joints, recovery.'),
          RoutineHabit(emoji: '🥗', name: 'Nutrient-Dense Lunch: Time-Restricted (12pm-8pm Window)', time: '12:00', category: 'Nutrition', tip: 'Intermittent fasting: autophagy, insulin sensitivity, cellular repair. 16:8 protocol.'),
          RoutineHabit(emoji: '📊', name: 'Health Metrics: HRV, Sleep Score, Glucose Check', time: '14:00', category: 'Tracking', tip: 'What gets measured gets managed. Use Oura, Whoop, or Apple Watch. Track trends weekly.'),
          RoutineHabit(emoji: '🧪', name: 'Afternoon Stack: Creatine + Electrolytes + Green Tea', time: '14:30', category: 'Supplements', tip: 'Creatine 5g/day: proven for brain AND muscle. Most researched supplement in history.'),
          RoutineHabit(emoji: '🌡️', name: 'Sauna Protocol: 20-min at 170-210°F', time: '18:00', category: 'Hormesis', tip: 'Rhonda Patrick: 4+ sauna sessions/week = 40% reduced all-cause mortality. Heat shock proteins.'),
          RoutineHabit(emoji: '🥘', name: 'Final Meal: Mediterranean + Anti-Inflammatory Focus', time: '18:30', category: 'Nutrition', tip: 'Last meal 3+ hrs before bed. High-polyphenol foods: olive oil, berries, dark chocolate, turmeric.'),
          RoutineHabit(emoji: '👓', name: 'Blue Light Block: Amber Glasses After Sunset', time: '19:30', category: 'Circadian', tip: 'Blue light after sunset suppresses melatonin 50%. Wear blue blockers for 2hrs before bed.'),
          RoutineHabit(emoji: '💊', name: 'Night Stack: Magnesium L-Threonate + Apigenin + Glycine', time: '21:00', category: 'Supplements', tip: 'Huberman sleep cocktail: Mg-Threonate (crosses BBB), Apigenin (calming), Glycine (lowers temp).'),
          RoutineHabit(emoji: '😴', name: 'Optimized Sleep: 65°F, Pitch Black, 8-Layer Protocol', time: '21:30', category: 'Health', tip: 'Bryan Johnson: consistent bedtime, cool room, blackout, no sound, weighted blanket, mouth tape.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 10. WEALTH ARCHITECT - Financial Freedom
      // ══════════════════════════════════════════════
      'wealth': RoutineTemplate(
        id: 'wealth',
        name: 'Wealth Architect',
        emoji: '💰',
        subtitle: 'Build Financial Freedom',
        description:
        'Derived from Naval Ravikant\'s Almanack, Morgan Housel\'s Psychology of Money, Grant Cardone\'s 10X Rule, and Warren Buffett\'s daily habits.',
        color: const Color(0xFFD97706),
        gradient: const [Color(0xFFD97706), Color(0xFFB45309)],
        icon: Icons.account_balance_rounded,
        categoryTag: 'Finance',
        difficulty: 'Intermediate',
        estimatedTime: '15 hours',
        scienceBacked: false,
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Wake Before the Market: Own the Pre-Dawn Hours', time: '05:00', category: 'Discipline', tip: 'Tim Cook wakes at 3:45, Buffett at 6:45. Early risers report higher proactivity scores.'),
          RoutineHabit(emoji: '📰', name: 'Market & World News Scan: 20 min MAX (Curated Sources)', time: '05:15', category: 'Business', tip: 'Read Bloomberg, Financial Times, or Morning Brew. Not social media news. Primary sources only.'),
          RoutineHabit(emoji: '📊', name: 'Portfolio Review: Check Investments & Rebalance Mental Model', time: '05:45', category: 'Finance', tip: 'Don\'t trade daily, but THINK daily. Buffett: "Risk comes from not knowing what you\'re doing."'),
          RoutineHabit(emoji: '📚', name: 'Financial Education: Read 30 min (Investing/Business Books)', time: '06:15', category: 'Learning', tip: 'Buffett reads 500 pages/day. Naval: "Read what you love until you love to read."'),
          RoutineHabit(emoji: '🏋️', name: 'Physical Training: Energy = Earning Capacity', time: '06:45', category: 'Fitness', tip: 'Richard Branson: exercise gives him 4 extra productive hours/day. Body = business asset.'),
          RoutineHabit(emoji: '🎯', name: 'Revenue-Generating Activity: Do the Highest-Leverage Task', time: '08:00', category: 'Work', tip: '80/20 Rule: 20% of activities generate 80% of income. Identify and ONLY do those first.'),
          RoutineHabit(emoji: '🤝', name: 'High-Value Networking: 1 Meaningful Connection / Day', time: '10:00', category: 'Social', tip: 'Your net worth = your network. Send 1 genuine message to someone you admire. No ask, just value.'),
          RoutineHabit(emoji: '💡', name: 'Business Ideation: Brainstorm 10 Ideas (Idea Machine)', time: '12:00', category: 'Creative', tip: 'James Altucher: write 10 ideas daily. Idea muscle atrophies in 2 weeks without exercise.'),
          RoutineHabit(emoji: '💰', name: 'Income Tracking: Log All Revenue & Expenses', time: '13:00', category: 'Finance', tip: '"What gets measured gets managed." — Drucker. Track every dollar in and out.'),
          RoutineHabit(emoji: '🧠', name: 'Skill Stacking: Learn a New Money-Making Skill (1hr)', time: '14:00', category: 'Learning', tip: 'Naval: "Specific knowledge is knowledge you cannot be trained for." Build unique skill combos.'),
          RoutineHabit(emoji: '📈', name: 'Side Business / Asset Building Block', time: '17:00', category: 'Business', tip: 'Build assets that earn while you sleep: content, courses, investments, intellectual property.'),
          RoutineHabit(emoji: '📝', name: 'Financial Journaling: Wins, Losses, Lessons', time: '20:00', category: 'Reflection', tip: 'Ray Dalio journals every trade decision. Review your money moves without emotion.'),
          RoutineHabit(emoji: '🎧', name: 'Wealth Podcast: Listen During Wind-Down', time: '21:00', category: 'Learning', tip: 'My First Million, All-In Podcast, Naval\'s interviews. Absorb wealthy thinking patterns.'),
          RoutineHabit(emoji: '😴', name: 'Rest & Recover: Wealthy People Protect Their Sleep', time: '22:00', category: 'Health', tip: 'Jeff Bezos sleeps 8 hours: "I make better decisions with better sleep." Protect your edge.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 11. DIGITAL DETOX - Reclaim Your Life
      // ══════════════════════════════════════════════
      'detox': RoutineTemplate(
        id: 'detox',
        name: 'Digital Detox',
        emoji: '📵',
        subtitle: 'Reclaim Your Attention',
        description:
        'Based on Cal Newport\'s Digital Minimalism, Johann Hari\'s Stolen Focus, and dopamine detox research. Break free from phone addiction.',
        color: const Color(0xFFDC2626),
        gradient: const [Color(0xFFDC2626), Color(0xFFB91C1C)],
        icon: Icons.phonelink_off_rounded,
        categoryTag: 'Wellness',
        difficulty: 'Intermediate',
        estimatedTime: '12 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '📵', name: 'No Phone First Hour: Alarm Clock Instead', time: '07:00', category: 'Discipline', tip: 'Checking phone within 5 min of waking puts brain in reactive mode for the entire day.'),
          RoutineHabit(emoji: '🌅', name: 'Analog Morning: Stretch, Breathe, Look Out Window', time: '07:05', category: 'Wellness', tip: 'First inputs shape your neurochemistry. Sunlight + silence > Instagram + email.'),
          RoutineHabit(emoji: '📓', name: 'Paper Journaling: Write by Hand (10 min)', time: '07:15', category: 'Mindfulness', tip: 'Handwriting activates different brain regions than typing. Deeper processing and creativity.'),
          RoutineHabit(emoji: '☕', name: 'Mindful Breakfast: No Screens, Taste Every Bite', time: '07:30', category: 'Wellness', tip: 'Mindful eating improves digestion 30% and satisfaction 40%. Be present with food.'),
          RoutineHabit(emoji: '⏰', name: 'Set 3 Intentional Phone Windows: 9am, 1pm, 6pm Only', time: '08:00', category: 'Discipline', tip: 'Cal Newport: batch phone use into scheduled windows. 3x/day vs 96x/day average.'),
          RoutineHabit(emoji: '💼', name: 'Deep Work: Computer Only (No Tabs, No Notifications)', time: '09:00', category: 'Productivity', tip: 'Use website blockers. Freedom, Cold Turkey. Single-tab browsing. Full-screen mode.'),
          RoutineHabit(emoji: '🚶', name: 'Phone-Free Walk: 30 min in Nature, No Earbuds', time: '12:00', category: 'Wellness', tip: 'Brain\'s default mode network activates without stimulation. Creativity & problem-solving peak.'),
          RoutineHabit(emoji: '🎨', name: 'Analog Hobby: Drawing, Cooking, Instrument, Gardening', time: '15:00', category: 'Creative', tip: 'Replace digital dopamine with real-world flow activities. Hands-on hobbies reduce anxiety 75%.'),
          RoutineHabit(emoji: '👥', name: 'Face-to-Face Social: Real Conversation (Phone Away)', time: '17:00', category: 'Social', tip: 'Sherry Turkle: a phone on the table reduces conversation depth 50%. Remove it completely.'),
          RoutineHabit(emoji: '📚', name: 'Physical Book Reading: 30+ min (Paper, Not Kindle)', time: '19:30', category: 'Learning', tip: 'Paper books improve comprehension 25% over screens (Stavanger study). Tactile experience matters.'),
          RoutineHabit(emoji: '🕯️', name: 'Candlelit Evening: No Electricity After 8pm', time: '20:00', category: 'Wellness', tip: 'Our ancestors lived by firelight. Candlelight produces zero blue light. Ultimate wind-down.'),
          RoutineHabit(emoji: '📵', name: 'Phone Locked in Drawer: Physical Separation', time: '20:30', category: 'Discipline', tip: 'Out of sight, out of mind. Physical distance reduces urge to check by 80%.'),
          RoutineHabit(emoji: '😴', name: 'Deep Analog Sleep: No Devices in Bedroom', time: '21:30', category: 'Health', tip: 'Bedroom = sleep & intimacy only. Devices out = 40% better sleep quality (Harvard study).'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 12. PARENT HERO - Family & Self Balance
      // ══════════════════════════════════════════════
      'parent': RoutineTemplate(
        id: 'parent',
        name: 'Parent Hero',
        emoji: '👨‍👩‍👧‍👦',
        subtitle: 'Family & Self Balance',
        description:
        'Designed for busy parents who want to be present, raise great kids, maintain health, and still pursue personal growth. No guilt framework.',
        color: const Color(0xFFE11D48),
        gradient: const [Color(0xFFE11D48), Color(0xFFBE123C)],
        icon: Icons.family_restroom_rounded,
        categoryTag: 'Family',
        difficulty: 'Beginner',
        estimatedTime: '16 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '⏰', name: 'Wake 45 Min Before Kids: Sacred Self-Time', time: '05:30', category: 'Self-Care', tip: 'This is YOUR time. No guilt. Put on your own oxygen mask first. Even 30 min transforms your day.'),
          RoutineHabit(emoji: '🧘', name: 'Quick Meditation or Prayer: 10 min Centering', time: '05:35', category: 'Mindfulness', tip: 'Calm parent = calm household. Regulate yourself first, then you can co-regulate your children.'),
          RoutineHabit(emoji: '🏋️', name: 'Quick Workout: 20-min HIIT or Yoga (No Gym Needed)', time: '05:50', category: 'Fitness', tip: 'YouTube 20-min workouts. Endorphins make you a more patient, energized parent all day.'),
          RoutineHabit(emoji: '🍳', name: 'Family Breakfast: Sit Together, No Screens', time: '06:30', category: 'Family', tip: 'Family meals reduce child anxiety 24% and increase vocabulary by 1,000+ words (Harvard).'),
          RoutineHabit(emoji: '🤗', name: 'Morning Connection Ritual: Hug + "I Love You" + Eye Contact', time: '07:00', category: 'Family', tip: 'Dr. Gottman: 6-second hug releases oxytocin. Children need 12+ positive touches daily.'),
          RoutineHabit(emoji: '🏫', name: 'School/Daycare Drop-off: Positive Send-off Phrase', time: '07:30', category: 'Family', tip: '"I can\'t wait to hear about your day!" reduces separation anxiety in children significantly.'),
          RoutineHabit(emoji: '💼', name: 'Focused Work Block: Deep Work While Kids Are Away', time: '08:30', category: 'Productivity', tip: 'Maximize kid-free hours. No shallow work during golden hours. Batched, focused execution.'),
          RoutineHabit(emoji: '📱', name: 'Mid-Day Family Check: Quick Call or Photo', time: '12:00', category: 'Family', tip: 'Stay connected. Send a funny photo. Brief connection maintains family bond during work days.'),
          RoutineHabit(emoji: '🏡', name: 'Transition Ritual: 5 min in Car Before Entering Home', time: '17:00', category: 'Mindset', tip: 'Decompress before walking in. Take 5 deep breaths. Leave work stress in the car, not the house.'),
          RoutineHabit(emoji: '🎮', name: 'Floor Time: 30 min Undivided Play with Kids', time: '17:15', category: 'Family', tip: 'Get on THEIR level. Follow THEIR lead. Phone away. 30 min focused > 3 hrs distracted.'),
          RoutineHabit(emoji: '🥘', name: 'Family Dinner: Cook Together or Eat Together', time: '18:30', category: 'Family', tip: 'Kids who eat family dinners 5x/week are 35% less likely to have eating disorders (Columbia U).'),
          RoutineHabit(emoji: '📖', name: 'Bedtime Routine: Story + Gratitude + Tuck-In Ritual', time: '19:30', category: 'Family', tip: 'Reading 20 min/night to kids = 1.8 million words by age 5. Creates lifelong readers.'),
          RoutineHabit(emoji: '💑', name: 'Partner Connection: 15 min Conversation (No Kids, No Screens)', time: '20:30', category: 'Relationship', tip: 'Gottman: couples who have 6hrs of connection/week stay happily married. Start with 15 min.'),
          RoutineHabit(emoji: '📚', name: 'Personal Growth: Read, Journal, or Learn (30 min)', time: '21:00', category: 'Self-Care', tip: 'You can\'t pour from an empty cup. Invest in yourself to be a better parent tomorrow.'),
          RoutineHabit(emoji: '😴', name: 'Parental Rest: You Deserve Quality Sleep Too', time: '22:00', category: 'Health', tip: 'Sleep-deprived parents are 4x more likely to yell. Rest is not selfish—it\'s essential.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 13. NIGHT OWL ELITE - Peak Evening Performance
      // ══════════════════════════════════════════════
      'nightowl': RoutineTemplate(
        id: 'nightowl',
        name: 'Night Owl Elite',
        emoji: '🦉',
        subtitle: 'Thrive After Dark',
        description:
        'Scientifically designed for late chronotypes. Based on Dr. Michael Breus\'s chronotype research. Not everyone is meant to wake at 5 AM.',
        color: const Color(0xFF7C3AED),
        gradient: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
        icon: Icons.nightlight_round,
        categoryTag: 'Lifestyle',
        difficulty: 'Intermediate',
        estimatedTime: '16 hours',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '🌅', name: 'Natural Wake: No Alarm, Body\'s Own Rhythm', time: '09:00', category: 'Health', tip: 'Dr. Breus: forcing an early wake on a Wolf/Dolphin chronotype increases cortisol & reduces productivity.'),
          RoutineHabit(emoji: '☀️', name: 'Sunlight Exposure: 10 min Within 30 Min of Waking', time: '09:15', category: 'Circadian', tip: 'Even late risers need light anchoring. Sunlight recalibrates even a delayed circadian rhythm.'),
          RoutineHabit(emoji: '💧', name: 'Hydration + Balanced Brunch (Protein Focus)', time: '09:30', category: 'Nutrition', tip: 'First meal should be protein-heavy to stabilize blood sugar for your entire productive window.'),
          RoutineHabit(emoji: '🧠', name: 'Creative Block: Night Owls Peak Creatively 10am-1pm', time: '10:30', category: 'Creative', tip: 'Research shows night owls have higher creative output. Leverage late-morning brain chemistry.'),
          RoutineHabit(emoji: '💼', name: 'Administrative Work: Emails, Meetings, Calls', time: '13:00', category: 'Work', tip: 'Night owls have analytical peak in early afternoon. Handle logistics and communication now.'),
          RoutineHabit(emoji: '🏋️', name: 'Exercise: Night Owls Peak Physically 2pm-7pm', time: '16:00', category: 'Fitness', tip: 'Body temperature peaks later for night owls. Strength & coordination best in late afternoon.'),
          RoutineHabit(emoji: '🥗', name: 'Early Dinner: Fuel for Your Most Productive Hours', time: '18:00', category: 'Nutrition', tip: 'Eat dinner early so digestion doesn\'t interfere with your nighttime deep work.'),
          RoutineHabit(emoji: '🎯', name: 'Deep Work Block 2: The Night Owl Golden Hours', time: '20:00', category: 'Productivity', tip: 'Night owls have a second wind 8pm-midnight. This is YOUR deep work zone. Protect it fiercely.'),
          RoutineHabit(emoji: '📚', name: 'Reading / Learning Block: The Quiet Hours', time: '22:00', category: 'Learning', tip: 'World is quiet. Distractions minimal. Deep reading and learning retention peaks in stillness.'),
          RoutineHabit(emoji: '🧘', name: 'Wind-Down Ritual: Light Stretch + Herbal Tea', time: '23:30', category: 'Wellness', tip: 'Signal your body to prepare for sleep. Chamomile + magnesium + dim lights.'),
          RoutineHabit(emoji: '📵', name: 'Screen Curfew: Blue Blockers or No Screens', time: '00:00', category: 'Health', tip: 'Even night owls need melatonin. Cut blue light 1hr before YOUR bedtime, not society\'s.'),
          RoutineHabit(emoji: '😴', name: 'Optimized Late Sleep: 8 Hours from YOUR Bedtime', time: '01:00', category: 'Health', tip: 'Quality > timing. 1am-9am is just as restorative as 10pm-6am IF it\'s consistent.'),
        ],
      ),

      // ══════════════════════════════════════════════
      // 14. LANGUAGE MASTER - Learn Any Language
      // ══════════════════════════════════════════════
      'language': RoutineTemplate(
        id: 'language',
        name: 'Language Master',
        emoji: '🌍',
        subtitle: 'Fluency in 6 Months',
        description:
        'Based on Stephen Krashen\'s Input Hypothesis, Benny Lewis\'s Fluent in 3 Months, and polyglot research. Immersion-style daily practice.',
        color: const Color(0xFF2563EB),
        gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        icon: Icons.translate_rounded,
        categoryTag: 'Education',
        difficulty: 'Intermediate',
        estimatedTime: '4 hours dedicated',
        scienceBacked: true,
        habits: [
          RoutineHabit(emoji: '📱', name: 'Change Phone Language to Target Language', time: '07:00', category: 'Immersion', tip: 'Passive immersion: every notification, every menu item becomes a mini-lesson. Adds 30+ exposures/day.'),
          RoutineHabit(emoji: '📝', name: 'Anki Flashcards: 50 New Words + Review (20 min)', time: '07:15', category: 'Vocabulary', tip: 'Spaced repetition is the most efficient memorization method. 1000 words = 85% comprehension.'),
          RoutineHabit(emoji: '🎧', name: 'Podcast in Target Language: 30 min (During Commute)', time: '08:00', category: 'Listening', tip: 'Krashen: comprehensible input is king. Listen to content slightly above your level (i+1).'),
          RoutineHabit(emoji: '📖', name: 'Graded Reader: 15 min Reading at Your Level', time: '12:00', category: 'Reading', tip: 'Start with children\'s books, progress to graded readers. Extensive reading = natural grammar acquisition.'),
          RoutineHabit(emoji: '🗣️', name: 'Speaking Practice: 15 min (iTalki / Language Exchange)', time: '17:00', category: 'Speaking', tip: 'Benny Lewis: speak from Day 1. Mistakes are data, not failures. 15 min/day > 2 hrs on weekends.'),
          RoutineHabit(emoji: '📺', name: 'Netflix in Target Language: 30 min (Target Subtitles)', time: '19:30', category: 'Immersion', tip: 'Watch with target language subtitles, NOT English. Context + visuals = natural acquisition.'),
          RoutineHabit(emoji: '✍️', name: 'Write 5 Sentences: Daily Journal in Target Language', time: '21:00', category: 'Writing', tip: 'Writing activates different memory pathways. Get corrections on HelloTalk or LangCorrect.'),
          RoutineHabit(emoji: '🛏️', name: 'Sleep Review: Listen to Vocabulary While Falling Asleep', time: '22:00', category: 'Passive', tip: 'Sleep learning is partially supported: familiar vocabulary heard during sleep consolidates faster.'),
        ],
      ),
    };

    // --- DYNAMIC SEASONAL & MONTHLY INJECTION ---
    List<RoutineHabit> dynamicHabits = [];

    if (_currentSeason == 'Winter') {
      dynamicHabits.add(RoutineHabit(emoji: '🫖', name: 'Winter Immunity Brew: Ginger + Turmeric + Honey + Black Pepper', time: '07:15', category: 'Seasonal Recipe', tip: 'Turmeric bioavailability increases 2000% with black pepper. Anti-inflammatory powerhouse.'));
      dynamicHabits.add(RoutineHabit(emoji: '💡', name: 'Light Therapy: 10,000 lux SAD Lamp (30 min)', time: '08:15', category: 'Seasonal Health', tip: 'Winter SAD affects 10% of population. Light therapy at 10,000 lux resets serotonin production.'));
      dynamicHabits.add(RoutineHabit(emoji: '🧣', name: 'Layer Up & Still Walk Outside (15 min minimum)', time: '12:30', category: 'Seasonal Fitness', tip: 'Cold air exposure + movement boosts brown fat activation. Don\'t hibernate—move!'));
    } else if (_currentSeason == 'Summer') {
      dynamicHabits.add(RoutineHabit(emoji: '🍉', name: 'Summer Hydration Mix: Watermelon + Mint + Lime + Sea Salt', time: '14:00', category: 'Seasonal Recipe', tip: 'Watermelon is 92% water + contains citrulline for blood flow. Perfect summer rehydration.'));
      dynamicHabits.add(RoutineHabit(emoji: '🧴', name: 'Apply Broad-Spectrum SPF 50 (Reapply Every 2hrs)', time: '07:45', category: 'Seasonal Health', tip: 'UV damage is cumulative. Even cloudy days = 80% UV penetration. Sunscreen is anti-aging.'));
      dynamicHabits.add(RoutineHabit(emoji: '🏊', name: 'Summer Outdoor Activity: Swimming, Cycling, Hiking', time: '17:30', category: 'Seasonal Fitness', tip: 'Exercise outdoors in summer after 5pm when UV index drops. Vitamin D + movement + nature.'));
    } else if (_currentSeason == 'Autumn') {
      dynamicHabits.add(RoutineHabit(emoji: '🍲', name: 'Autumn Immunity Soup: Bone Broth + Root Vegetables', time: '19:30', category: 'Seasonal Recipe', tip: 'Bone broth = collagen + glycine + glutamine. Gut health = immune health. Add garlic for allicin.'));
      dynamicHabits.add(RoutineHabit(emoji: '🍂', name: 'Forest Walk Among Autumn Leaves: Grounding Practice', time: '16:30', category: 'Seasonal Health', tip: 'Autumn forests release phytoncides that boost NK cells. Crunching leaves = ASMR for the soul.'));
      dynamicHabits.add(RoutineHabit(emoji: '🎃', name: 'Warm Pumpkin Spice Smoothie: Pumpkin + Cinnamon + Collagen', time: '08:30', category: 'Seasonal Recipe', tip: 'Pumpkin is loaded with beta-carotene (vitamin A). Cinnamon stabilizes blood sugar.'));
    } else if (_currentSeason == 'Spring') {
      dynamicHabits.add(RoutineHabit(emoji: '🥬', name: 'Spring Detox Smoothie: Spinach + Lemon + Ginger + Apple', time: '10:30', category: 'Seasonal Recipe', tip: 'Spring = natural detox season. Greens support liver. Lemon stimulates bile production.'));
      dynamicHabits.add(RoutineHabit(emoji: '🌬️', name: 'Open All Windows: Deep Breathing & Fresh Air Reset', time: '08:00', category: 'Seasonal Health', tip: 'Indoor air is 5x more polluted than outdoor. Spring air clears stagnant winter buildup.'));
      dynamicHabits.add(RoutineHabit(emoji: '🌷', name: 'Start a Garden or Tend to Plants: Horticultural Therapy', time: '17:00', category: 'Seasonal Wellness', tip: 'Gardening reduces cortisol more than reading (Journal of Health Psychology). Soil microbes boost serotonin.'));
    }

    // Month-Specific
    if (month == 1) {
      dynamicHabits.add(RoutineHabit(emoji: '🎯', name: 'January Reset: Write 12-Month Vision & Q1 Goals', time: '20:45', category: 'Monthly Goal', tip: 'People who write goals are 42% more likely to achieve them (Dominican University study).'));
    } else if (month == 2) {
      dynamicHabits.add(RoutineHabit(emoji: '❤️', name: 'February Self-Love: Write a Letter of Compassion to Yourself', time: '20:45', category: 'Monthly Wellness', tip: 'Self-compassion is more powerful than self-esteem for long-term psychological well-being.'));
    } else if (month == 3) {
      dynamicHabits.add(RoutineHabit(emoji: '🧹', name: 'March Declutter: Remove 5 Items You Don\'t Need', time: '18:30', category: 'Monthly Organization', tip: 'Spring cleaning reduces anxiety. Cluttered spaces increase cortisol in women by 30% (UCLA).'));
    } else if (month == 6) {
      dynamicHabits.add(RoutineHabit(emoji: '📊', name: 'June Mid-Year Review: Are You on Track?', time: '20:45', category: 'Monthly Goal', tip: 'Half the year is gone. Review Jan goals. Adjust, don\'t abandon. Recalibrate Q3-Q4 targets.'));
    } else if (month == 10) {
      dynamicHabits.add(RoutineHabit(emoji: '🎃', name: 'October Pumpkin Spice Superfood Latte', time: '09:30', category: 'Monthly Recipe', tip: 'Pumpkin puree + cinnamon + nutmeg + oat milk + collagen. Festive AND nutritious.'));
    } else if (month == 12) {
      dynamicHabits.add(RoutineHabit(emoji: '🍫', name: 'December Hot Cacao Ceremony: Dark Cacao + Reishi', time: '20:45', category: 'Monthly Recipe', tip: 'Ceremonial cacao is rich in theobromine (mood elevator) and magnesium (sleep support).'));
      dynamicHabits.add(RoutineHabit(emoji: '📝', name: 'December Annual Review: Wins, Losses, Growth, Gratitude', time: '21:00', category: 'Monthly Goal', tip: 'Reflect on the full year before setting next year\'s goals. Gratitude for growth compounds.'));
    }

    // Apply dynamic injections
    for (var key in templates.keys) {
      final template = templates[key]!;
      List<RoutineHabit> updatedHabits = List.from(template.habits);
      updatedHabits.addAll(dynamicHabits);
      updatedHabits.sort((a, b) => a.time.compareTo(b.time));

      templates[key] = RoutineTemplate(
        id: template.id,
        name: template.name,
        emoji: template.emoji,
        subtitle: template.subtitle,
        description: template.description,
        color: template.color,
        gradient: template.gradient,
        icon: template.icon,
        categoryTag: template.categoryTag,
        difficulty: template.difficulty,
        estimatedTime: template.estimatedTime,
        scienceBacked: template.scienceBacked,
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
        return 'Spring protocol active: Detox smoothies, fresh air routines, and garden therapy added to your timeline.';
      case 'Summer':
        return 'Summer protocol active: Enhanced hydration, UV protection, and outdoor activities integrated.';
      case 'Autumn':
        return 'Autumn protocol active: Immunity soups, grounding walks, and warm spice recipes added.';
      case 'Winter':
        return 'Winter protocol active: Light therapy, immunity brews, and cold-weather movement integrated.';
      default:
        return 'Build transformational habits step by step, every single day.';
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

  List<String> _getUniqueCategories(RoutineTemplate routine) {
    final cats = <String>{'All'};
    for (final h in routine.habits) {
      cats.add(h.category);
    }
    return cats.toList();
  }

  List<RoutineHabit> _getFilteredHabits(RoutineTemplate routine) {
    if (_selectedCategory == 'All') return routine.habits;
    return routine.habits.where((h) => h.category == _selectedCategory).toList();
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
        SnackBar(
          content: const Text('🎉 Routine unlocked for 24 hours!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _isPro = DatabaseService.isProOrVipUser();

    final routine = _routines[_selectedRoutine]!;
    final isRoutineUnlocked = DatabaseService.isRoutineUnlocked(routine.id);
    final expiry = DatabaseService.getRoutineUnlockExpiry(routine.id);

    final canAddHabits = _isPro || isRoutineUnlocked;
    final canAddAll = _isPro || isRoutineUnlocked;

    final filteredHabits = _getFilteredHabits(routine);
    final categories = _getUniqueCategories(routine);

    // Reset category filter if it doesn't exist in current routine
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ═══════════════════════════════════════════
          // PREMIUM SLIVER APP BAR
          // ═══════════════════════════════════════════
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF0A0E1A) : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildPremiumHeader(isDark, routine),
            ),
            title: const Text(
              'Smart Routines',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            actions: [
              if (!_isPro)
                GestureDetector(
                  onTap: _showProDialog,
                  child: Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(60),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ═══════════════════════════════════════════
          // SEASONAL INTELLIGENCE BANNER
          // ═══════════════════════════════════════════
          if (AppConfig.enableSeasonalRoutines)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildSeasonalBanner(isDark),
              ),
            ),

          // ═══════════════════════════════════════════
          // ROUTINE SELECTOR CAROUSEL
          // ═══════════════════════════════════════════
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                scrollDirection: Axis.horizontal,
                itemCount: _routines.length,
                itemBuilder: (context, index) {
                  final entry = _routines.entries.elementAt(index);
                  return _buildRoutineCard(entry, isDark);
                },
              ),
            ),
          ),

          // ═══════════════════════════════════════════
          // ROUTINE DETAIL CARD
          // ═══════════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRoutineDetailCard(routine, isDark, canAddHabits, isRoutineUnlocked, expiry),
            ),
          ),

          // ═══════════════════════════════════════════
          // CATEGORY FILTER CHIPS
          // ═══════════════════════════════════════════
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? routine.color.withAlpha(selected ? 30 : 0)
                            : (isDark ? Colors.white.withAlpha(8) : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? routine.color : Colors.transparent,
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected
                              ? routine.color
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ═══════════════════════════════════════════
          // TIMELINE HEADER
          // ═══════════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: routine.color.withAlpha(16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.timeline_rounded, size: 18, color: routine.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedCategory == 'All'
                          ? 'Daily Timeline'
                          : '$_selectedCategory Steps',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredHabits.length} steps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══════════════════════════════════════════
          // PREMIUM TIMELINE LIST
          // ═══════════════════════════════════════════
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final habit = filteredHabits[index];
                final isLast = index == filteredHabits.length - 1;
                return _buildTimelineItem(
                  habit, routine, isDark, isLast, canAddHabits, index,
                );
              },
              childCount: filteredHabits.length,
            ),
          ),

          // ═══════════════════════════════════════════
          // BOTTOM ACTION BUTTONS
          // ═══════════════════════════════════════════
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: _buildBottomActions(routine, canAddAll, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PREMIUM HEADER
  // ═══════════════════════════════════════════════════
  Widget _buildPremiumHeader(bool isDark, RoutineTemplate routine) {
    return AnimatedBuilder(
      animation: _headerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                routine.gradient[0].withAlpha(isDark ? 40 : 25),
                routine.gradient[1].withAlpha(isDark ? 25 : 15),
                isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF5F7FA),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30,
                right: -20,
                child: Opacity(
                  opacity: 0.08,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: routine.color,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: -40,
                child: Opacity(
                  opacity: 0.05,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: routine.color,
                    ),
                  ),
                ),
              ),
              // Bottom text
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: Opacity(
                  opacity: _headerAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _headerAnimation.value)),
                    child: Text(
                      'Science-backed routines for extraordinary results',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
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

  // ═══════════════════════════════════════════════════
  // SEASONAL BANNER
  // ═══════════════════════════════════════════════════
  Widget _buildSeasonalBanner(bool isDark) {
    final seasonColors = {
      'Spring': [const Color(0xFF86EFAC), const Color(0xFF22C55E)],
      'Summer': [const Color(0xFFFDE68A), const Color(0xFFF59E0B)],
      'Autumn': [const Color(0xFFFED7AA), const Color(0xFFF97316)],
      'Winter': [const Color(0xFFBAE6FD), const Color(0xFF0EA5E9)],
    };

    final colors = seasonColors[_currentSeason] ??
        [AppConfig.primaryColor, AppConfig.accentColor];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors[0].withAlpha(isDark ? 30 : 40),
            colors[1].withAlpha(isDark ? 15 : 20),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors[1].withAlpha(isDark ? 30 : 50),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colors[1].withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(_getSeasonEmoji(), style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$_currentSeason Protocol',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (_detectedCountry.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors[1].withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _detectedCountry,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors[1],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getSeasonTip(),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ROUTINE SELECTOR CARD
  // ═══════════════════════════════════════════════════
  Widget _buildRoutineCard(MapEntry<String, RoutineTemplate> entry, bool isDark) {
    final item = entry.value;
    final selected = _selectedRoutine == entry.key;
    final unlocked = DatabaseService.isRoutineUnlocked(item.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedRoutine = entry.key;
          _selectedCategory = 'All';
        });
        _headerController.reset();
        _headerController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: selected ? 130 : 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              item.gradient[0].withAlpha(isDark ? 50 : 35),
              item.gradient[1].withAlpha(isDark ? 30 : 20),
            ],
          )
              : null,
          color: selected ? null : (isDark ? Colors.white.withAlpha(8) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? item.color.withAlpha(120) : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5)),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: item.color.withAlpha(isDark ? 30 : 40),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
              : [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: selected ? 48 : 42,
                    height: selected ? 48 : 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? item.color.withAlpha(30)
                          : (isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        item.emoji,
                        style: TextStyle(fontSize: selected ? 24 : 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.name.split(' ').length > 2
                        ? item.name.split(' ').take(2).join(' ')
                        : item.name,
                    style: TextStyle(
                      fontSize: selected ? 11.5 : 10.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? item.color
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (selected) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Lock/Unlock indicator
            if (!_isPro && !unlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: Colors.amber,
                  ),
                ),
              ),
            if (!_isPro && unlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: Colors.green,
                  ),
                ),
              ),
            if (_isPro)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0x33FFD700),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('👑', style: TextStyle(fontSize: 10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ROUTINE DETAIL CARD
  // ═══════════════════════════════════════════════════
  Widget _buildRoutineDetailCard(
      RoutineTemplate routine,
      bool isDark,
      bool canAddHabits,
      bool isRoutineUnlocked,
      int expiry,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            routine.gradient[0].withAlpha(isDark ? 22 : 18),
            routine.gradient[1].withAlpha(isDark ? 12 : 8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: routine.color.withAlpha(isDark ? 25 : 30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Routine Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      routine.gradient[0].withAlpha(40),
                      routine.gradient[1].withAlpha(25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(routine.emoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
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
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (routine.scienceBacked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.science_rounded, size: 10, color: Color(0xFF3B82F6)),
                                SizedBox(width: 3),
                                Text(
                                  'Research-Based',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      routine.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: routine.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            routine.description,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          // Info Pills Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _premiumInfoPill(
                icon: Icons.track_changes_rounded,
                text: '${routine.habits.length} steps',
                color: routine.color,
                isDark: isDark,
              ),
              _premiumInfoPill(
                icon: Icons.schedule_rounded,
                text: routine.estimatedTime,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
              _premiumInfoPill(
                icon: Icons.signal_cellular_alt_rounded,
                text: routine.difficulty,
                color: routine.difficulty == 'Expert'
                    ? Colors.red
                    : routine.difficulty == 'Advanced'
                    ? Colors.orange
                    : routine.difficulty == 'Intermediate'
                    ? Colors.blue
                    : Colors.green,
                isDark: isDark,
              ),
              _premiumInfoPill(
                icon: Icons.category_rounded,
                text: routine.categoryTag,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
              if (canAddHabits && !_isPro)
                _premiumInfoPill(
                  icon: Icons.lock_open_rounded,
                  text: _formatRemainingTime(expiry),
                  color: Colors.green,
                  isDark: isDark,
                ),
              if (_isPro)
                _premiumInfoPill(
                  icon: Icons.workspace_premium_rounded,
                  text: 'Full Access',
                  color: const Color(0xFFFFD700),
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumInfoPill({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 18 : 14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PREMIUM TIMELINE ITEM
  // ═══════════════════════════════════════════════════
  Widget _buildTimelineItem(
      RoutineHabit habit,
      RoutineTemplate routine,
      bool isDark,
      bool isLast,
      bool canAddHabits,
      int index,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Timeline connector
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Dot with glow
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: routine.gradient,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: routine.color.withAlpha(40),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              routine.color.withAlpha(50),
                              routine.color.withAlpha(15),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(8) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(4),
                  ),
                  boxShadow: !isDark
                      ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showHabitDetail(habit, routine, isDark, canAddHabits),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Emoji container
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  routine.color.withAlpha(20),
                                  routine.color.withAlpha(10),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                habit.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  habit.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: routine.color.withAlpha(15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 11,
                                            color: routine.color,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            habit.time,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: routine.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        habit.category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white30 : Colors.black38,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Action button
                          canAddHabits
                              ? GestureDetector(
                            onTap: () => _addSingleHabit(habit, routine),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    routine.color.withAlpha(20),
                                    routine.color.withAlpha(12),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: routine.color.withAlpha(30),
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: routine.color,
                              ),
                            ),
                          )
                              : GestureDetector(
                            onTap: () => _unlockRoutineWithAd(routine.id),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.withAlpha(12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // HABIT DETAIL BOTTOM SHEET
  // ═══════════════════════════════════════════════════
  void _showHabitDetail(
      RoutineHabit habit,
      RoutineTemplate routine,
      bool isDark,
      bool canAdd,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C2F) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Emoji + Name
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: routine.gradient),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(habit.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 14, color: routine.color),
                              const SizedBox(width: 4),
                              Text(
                                habit.time,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: routine.color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: routine.color.withAlpha(15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  habit.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: routine.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Science Tip
                if (habit.tip.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withAlpha(isDark ? 15 : 10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withAlpha(25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 6),
                            Text(
                              'Why This Works',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          habit.tip,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Add button
                if (canAdd)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _addSingleHabit(habit, routine);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Add to My Habits',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: routine.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _unlockRoutineWithAd(routine.id);
                      },
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: const Text(
                        'Watch Ad to Unlock',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // BOTTOM ACTION BUTTONS
  // ═══════════════════════════════════════════════════
  Widget _buildBottomActions(RoutineTemplate routine, bool canAddAll, bool isDark) {
    if (canAddAll) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: routine.gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: routine.color.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _addAllHabits(routine),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_task_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Add All ${routine.habits.length} Habits ✨',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withAlpha(30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _isAdLoading ? null : () => _unlockRoutineWithAd(routine.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isAdLoading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Watch Ad to Unlock',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _showProDialog,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 17),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Go PRO',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════
  void _addSingleHabit(RoutineHabit routineHabit, RoutineTemplate routine) async {
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
          content: Row(
            children: [
              Text(routineHabit.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${routineHabit.name} added!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Text('✅', style: TextStyle(fontSize: 18)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  void _addAllHabits(RoutineTemplate routine) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
          title: Row(
            children: [
              Text(routine.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add ${routine.habits.length} Habits?',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'This will add all ${routine.habits.length} habits from "${routine.name}" to your daily tracker with reminders enabled.',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: routine.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Add All', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

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
          content: Row(
            children: [
              Text(routine.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                '$count habits added! 🎉',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showProDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C2F) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Crown
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withAlpha(40),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Unlock Full Power',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart Routines PRO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 20),
                // Features
                ...[
                  _proFeatureRow('🚀', 'All 14+ routines, fully unlocked'),
                  _proFeatureRow('⚡', 'Add ALL habits in 1 click'),
                  _proFeatureRow('🔓', 'No ads, no waiting'),
                  _proFeatureRow('🧬', 'Science-backed tips & explanations'),
                  _proFeatureRow('📅', 'Smart time scheduling'),
                  _proFeatureRow('✨', 'All future routines included forever'),
                ],
                const SizedBox(height: 24),
                // CTA
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProVersionScreen(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text(
                              'Upgrade to PRO 👑',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _proFeatureRow(String emoji, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ENHANCED DATA MODELS
// ═══════════════════════════════════════════════════════
class RoutineTemplate {
  final String id;
  final String name;
  final String emoji;
  final String subtitle;
  final String description;
  final Color color;
  final List<Color> gradient;
  final IconData icon;
  final String categoryTag;
  final String difficulty;
  final String estimatedTime;
  final bool scienceBacked;
  final List<RoutineHabit> habits;

  RoutineTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.gradient,
    required this.icon,
    required this.categoryTag,
    required this.difficulty,
    required this.estimatedTime,
    required this.scienceBacked,
    required this.habits,
  });
}

class RoutineHabit {
  final String emoji;
  final String name;
  final String time;
  final String category;
  final String tip;

  RoutineHabit({
    required this.emoji,
    required this.name,
    required this.time,
    required this.category,
    this.tip = '',
  });
}