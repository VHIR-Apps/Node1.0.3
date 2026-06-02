import 'package:flutter/material.dart';

class MissionsService {
  /// Get all predefined habit missions
  static List<HabitMission> getAllMissions() {
    return [
      // 🏃 FITNESS (Easy to Expert)
      HabitMission(
        id: 'morning_walk',
        name: 'Morning Walk',
        emoji: '🚶',
        category: 'Fitness',
        color: 0xFF10B981,
        description: 'Start your day with a refreshing walk',
        duration: '15-30 min',
        difficulty: 'Easy',
        benefits: ['Boosts energy', 'Improves mood', 'Better sleep'],
      ),
      HabitMission(
        id: 'stretching',
        name: 'Morning Stretch',
        emoji: '🧘',
        category: 'Fitness',
        color: 0xFF8B5CF6,
        description: 'Stretch your body to start flexible',
        duration: '5-10 min',
        difficulty: 'Easy',
        benefits: ['Improve flexibility', 'Reduce tension', 'Better posture'],
      ),
      HabitMission(
        id: 'take_stairs',
        name: 'Take the Stairs',
        emoji: '🧗',
        category: 'Fitness',
        color: 0xFF3B82F6,
        description: 'Avoid elevators and take the stairs today',
        duration: '5-10 min',
        difficulty: 'Easy',
        benefits: ['Leg strength', 'Cardio boost', 'Burn calories'],
      ),
      HabitMission(
        id: 'workout',
        name: 'Daily Workout',
        emoji: '💪',
        category: 'Fitness',
        color: 0xFFEF4444,
        description: 'Exercise to stay fit and healthy',
        duration: '20-45 min',
        difficulty: 'Medium',
        benefits: ['Build strength', 'Increase stamina', 'Burn calories'],
      ),
      HabitMission(
        id: 'run',
        name: 'Go for a Run',
        emoji: '🏃',
        category: 'Fitness',
        color: 0xFFF97316,
        description: 'Cardio exercise for heart health',
        duration: '20-40 min',
        difficulty: 'Medium',
        benefits: ['Heart health', 'Weight loss', 'Mental clarity'],
      ),
      HabitMission(
        id: 'yoga',
        name: 'Yoga Flow',
        emoji: '🕉️',
        category: 'Fitness',
        color: 0xFFA855F7,
        description: 'Complete a basic yoga routine',
        duration: '15-30 min',
        difficulty: 'Medium',
        benefits: ['Mind-body connection', 'Flexibility', 'Stress relief'],
      ),
      HabitMission(
        id: '100_pushups',
        name: '100 Pushups',
        emoji: '🧎‍♂️',
        category: 'Fitness',
        color: 0xFFEAB308,
        description: 'Complete 100 pushups throughout the day',
        duration: '15-20 min',
        difficulty: 'Hard',
        benefits: ['Chest strength', 'Discipline', 'Endurance'],
      ),
      HabitMission(
        id: '10k_run',
        name: '10K Run',
        emoji: '🏃‍♂️',
        category: 'Fitness',
        color: 0xFFDC2626,
        description: 'Run 10 kilometers without stopping',
        duration: '45-90 min',
        difficulty: 'Hard',
        benefits: ['Extreme cardio', 'Mental toughness', 'Calorie burn'],
      ),
      HabitMission(
        id: 'heavy_lifting',
        name: 'Heavy Lifting Session',
        emoji: '🏋️‍♂️',
        category: 'Fitness',
        color: 0xFF000000,
        description: 'High-intensity heavy weightlifting',
        duration: '60-90 min',
        difficulty: 'Hard',
        benefits: ['Muscle mass', 'Testosterone boost', 'Bone density'],
      ),
      HabitMission(
        id: 'murph_challenge',
        name: 'The Murph Challenge',
        emoji: '🦅',
        category: 'Fitness',
        color: 0xFF450A0A,
        description: '1 mile run, 100 pullups, 200 pushups, 300 squats, 1 mile run',
        duration: '60-120 min',
        difficulty: 'Expert',
        benefits: ['Elite stamina', 'Full body mastery', 'Mental grit'],
      ),

      // 🧠 MINDFULNESS (Easy to Expert)
      HabitMission(
        id: 'deep_breathing',
        name: 'Deep Breathing',
        emoji: '🌬️',
        category: 'Mindfulness',
        color: 0xFF14B8A6,
        description: 'Practice breathing exercises',
        duration: '3-5 min',
        difficulty: 'Easy',
        benefits: ['Calm nerves', 'Lower anxiety', 'Better oxygen'],
      ),
      HabitMission(
        id: 'gratitude',
        name: 'Gratitude Journal',
        emoji: '🙏',
        category: 'Mindfulness',
        color: 0xFFEC4899,
        description: 'Write 3 things you are grateful for',
        duration: '5 min',
        difficulty: 'Easy',
        benefits: ['Positive mindset', 'Better sleep', 'More happiness'],
      ),
      HabitMission(
        id: 'meditation',
        name: 'Meditation',
        emoji: '🧘‍♂️',
        category: 'Mindfulness',
        color: 0xFF6366F1,
        description: 'Find inner peace through meditation',
        duration: '10-20 min',
        difficulty: 'Medium',
        benefits: ['Reduce stress', 'Better focus', 'Emotional balance'],
      ),
      HabitMission(
        id: 'no_phone_morning',
        name: 'Phone-Free Morning',
        emoji: '📵',
        category: 'Mindfulness',
        color: 0xFF64748B,
        description: 'First hour without checking phone',
        duration: '60 min',
        difficulty: 'Medium',
        benefits: ['Better focus', 'Less anxiety', 'More presence'],
      ),
      HabitMission(
        id: 'hour_meditation',
        name: '1-Hour Meditation',
        emoji: '🧘‍♀️',
        category: 'Mindfulness',
        color: 0xFF4F46E5,
        description: 'Sit in uninterrupted meditation for 60 minutes',
        duration: '60 min',
        difficulty: 'Hard',
        benefits: ['Deep insight', 'Ego detachment', 'Extreme calm'],
      ),
      HabitMission(
        id: 'dopamine_detox',
        name: '24h Dopamine Detox',
        emoji: '🧠',
        category: 'Mindfulness',
        color: 0xFF1E293B,
        description: 'No screens, no sugar, no music, no cheap thrills',
        duration: '24 hours',
        difficulty: 'Expert',
        benefits: ['Reset receptors', 'Cure boredom', 'Laser focus'],
      ),
      HabitMission(
        id: 'silent_day',
        name: 'Day of Silence',
        emoji: '🤐',
        category: 'Mindfulness',
        color: 0xFF701A75,
        description: 'Speak exactly zero words for a full day',
        duration: 'All day',
        difficulty: 'Expert',
        benefits: ['Internal awareness', 'Listening skills', 'Deep peace'],
      ),

      // 📚 LEARNING (Easy to Expert)
      HabitMission(
        id: 'new_word',
        name: 'Word of the Day',
        emoji: '📖',
        category: 'Learning',
        color: 0xFF0EA5E9,
        description: 'Learn and use a new vocabulary word',
        duration: '5 min',
        difficulty: 'Easy',
        benefits: ['Communication skills', 'Intelligence', 'Memory'],
      ),
      HabitMission(
        id: 'podcast',
        name: 'Listen to Podcast',
        emoji: '🎧',
        category: 'Learning',
        color: 0xFFA855F7,
        description: 'Learn while commuting or exercising',
        duration: '20-40 min',
        difficulty: 'Easy',
        benefits: ['Multi-tasking', 'Stay informed', 'New ideas'],
      ),
      HabitMission(
        id: 'reading',
        name: 'Read 20 Pages',
        emoji: '📚',
        category: 'Learning',
        color: 0xFF3B82F6,
        description: 'Read at least 20 pages of a non-fiction book',
        duration: '30 min',
        difficulty: 'Medium',
        benefits: ['More knowledge', 'Better vocabulary', 'Reduced stress'],
      ),
      HabitMission(
        id: 'learn_language',
        name: 'Learn a Language',
        emoji: '🗣️',
        category: 'Learning',
        color: 0xFF22C55E,
        description: 'Practice a new language',
        duration: '20 min',
        difficulty: 'Medium',
        benefits: ['Brain health', 'Career growth', 'Travel easier'],
      ),
      HabitMission(
        id: 'coding',
        name: 'Practice Coding',
        emoji: '💻',
        category: 'Learning',
        color: 0xFF14B8A6,
        description: 'Write code or solve an algorithm',
        duration: '60 min',
        difficulty: 'Hard',
        benefits: ['Problem solving', 'Career value', 'Logic skills'],
      ),
      HabitMission(
        id: 'read_whole_book',
        name: 'Read a Whole Book',
        emoji: '📙',
        category: 'Learning',
        color: 0xFF0F172A,
        description: 'Finish an entire book in one single day',
        duration: '3-5 hours',
        difficulty: 'Expert',
        benefits: ['Massive knowledge gain', 'Focus endurance'],
      ),
      HabitMission(
        id: 'write_research',
        name: 'Research Deep-Dive',
        emoji: '🔬',
        category: 'Learning',
        color: 0xFFBE185D,
        description: 'Spend 3 hours researching a complex new topic and write a summary',
        duration: '3 hours',
        difficulty: 'Expert',
        benefits: ['Subject mastery', 'Critical thinking', 'Synthesis'],
      ),

      // 💧 HEALTH (Easy to Expert)
      HabitMission(
        id: 'drink_water',
        name: 'Drink Water',
        emoji: '💧',
        category: 'Health',
        color: 0xFF0EA5E9,
        description: 'Stay hydrated - 8 glasses daily',
        duration: 'Throughout day',
        difficulty: 'Easy',
        benefits: ['Better skin', 'More energy', 'Clearer thinking'],
      ),
      HabitMission(
        id: 'vitamins',
        name: 'Take Vitamins',
        emoji: '💊',
        category: 'Health',
        color: 0xFFFBBF24,
        description: 'Daily vitamins and supplements',
        duration: '1 min',
        difficulty: 'Easy',
        benefits: ['Immune support', 'Fill nutrient gaps', 'Better health'],
      ),
      HabitMission(
        id: 'eat_veggies',
        name: 'Eat Greens',
        emoji: '🥦',
        category: 'Health',
        color: 0xFF22C55E,
        description: 'Eat a large serving of vegetables',
        duration: '15 min',
        difficulty: 'Easy',
        benefits: ['Fiber', 'Vitamins', 'Gut health'],
      ),
      HabitMission(
        id: 'sleep_early',
        name: 'Sleep by 10 PM',
        emoji: '😴',
        category: 'Health',
        color: 0xFF4F46E5,
        description: 'Get quality sleep early',
        duration: '7-8 hours',
        difficulty: 'Medium',
        benefits: ['More energy', 'Better focus', 'Stronger immunity'],
      ),
      HabitMission(
        id: 'cook_all_meals',
        name: '100% Home Cooked',
        emoji: '🍳',
        category: 'Health',
        color: 0xFFF97316,
        description: 'Do not eat anything you didn\'t cook yourself today',
        duration: 'All day',
        difficulty: 'Hard',
        benefits: ['Calorie control', 'Save money', 'Healthier ingredients'],
      ),
      HabitMission(
        id: 'no_sugar',
        name: 'Zero Sugar Day',
        emoji: '🚫🍬',
        category: 'Health',
        color: 0xFFDC2626,
        description: 'Consume strictly 0g of added sugar today',
        duration: 'All day',
        difficulty: 'Hard',
        benefits: ['Weight loss', 'Stable energy', 'Better teeth'],
      ),
      HabitMission(
        id: 'cold_plunge',
        name: 'Ice Bath / Cold Shower',
        emoji: '🧊',
        category: 'Health',
        color: 0xFF0284C7,
        description: 'Take a fully cold shower or ice bath for 3+ minutes',
        duration: '3-5 min',
        difficulty: 'Hard',
        benefits: ['Dopamine spike', 'Immunity', 'Willpower'],
      ),
      HabitMission(
        id: 'water_fast',
        name: '24-Hour Water Fast',
        emoji: '⏳',
        category: 'Health',
        color: 0xFF064E3B,
        description: 'Consume nothing but water for 24 straight hours',
        duration: '24 hours',
        difficulty: 'Expert',
        benefits: ['Autophagy', 'Insulin reset', 'Extreme discipline'],
      ),

      // ✨ PRODUCTIVITY (Easy to Expert)
      HabitMission(
        id: 'two_minute_rule',
        name: 'Two-Minute Rule',
        emoji: '⏱️',
        category: 'Productivity',
        color: 0xFF06B6D4,
        description: 'If it takes < 2 mins, do it immediately',
        duration: 'Instant',
        difficulty: 'Easy',
        benefits: ['Clear backlog', 'Quick wins', 'Reduced clutter'],
      ),
      HabitMission(
        id: 'plan_day',
        name: 'Plan Your Day',
        emoji: '📝',
        category: 'Productivity',
        color: 0xFF7C3AED,
        description: 'Write down tasks for the day',
        duration: '5-10 min',
        difficulty: 'Easy',
        benefits: ['Clear focus', 'Less stress', 'More achievement'],
      ),
      HabitMission(
        id: 'eat_the_frog',
        name: 'Eat the Frog',
        emoji: '🐸',
        category: 'Productivity',
        color: 0xFF16A34A,
        description: 'Do your hardest, most dreaded task first thing in the morning',
        duration: '1-2 hours',
        difficulty: 'Medium',
        benefits: ['Destroy procrastination', 'Momentum', 'Relief'],
      ),
      HabitMission(
        id: 'deep_work',
        name: '90-Min Deep Work',
        emoji: '🎯',
        category: 'Productivity',
        color: 0xFFBE185D,
        description: 'Focused work without any distractions',
        duration: '90 min',
        difficulty: 'Hard',
        benefits: ['High output', 'Better quality', 'Flow state'],
      ),
      HabitMission(
        id: '4_am_club',
        name: 'The 4 AM Club',
        emoji: '🌅',
        category: 'Productivity',
        color: 0xFFEAB308,
        description: 'Wake up at 4:00 AM and start working immediately',
        duration: 'Early Morning',
        difficulty: 'Hard',
        benefits: ['Zero distractions', 'Head start', 'Quiet time'],
      ),
      HabitMission(
        id: 'four_hour_deep_work',
        name: '4-Hour Flow State',
        emoji: '🧠',
        category: 'Productivity',
        color: 0xFF7F1D1D,
        description: 'Work for 4 straight hours with zero breaks and zero phone',
        duration: '4 hours',
        difficulty: 'Expert',
        benefits: ['Massive progress', 'Cognitive endurance', 'Mastery'],
      ),

      // 💝 SELF-CARE (Easy to Expert)
      HabitMission(
        id: 'skincare',
        name: 'Skincare Routine',
        emoji: '🧴',
        category: 'Self-Care',
        color: 0xFFF472B6,
        description: 'Morning and evening skincare',
        duration: '5-10 min',
        difficulty: 'Easy',
        benefits: ['Better skin', 'Self-love', 'Aging gracefully'],
      ),
      HabitMission(
        id: 'nature_time',
        name: 'Time in Nature',
        emoji: '🌳',
        category: 'Self-Care',
        color: 0xFF16A34A,
        description: 'Spend time outdoors',
        duration: '20-30 min',
        difficulty: 'Easy',
        benefits: ['Vitamin D', 'Fresh air', 'Mental reset'],
      ),
      HabitMission(
        id: 'journaling',
        name: 'Daily Journaling',
        emoji: '📔',
        category: 'Self-Care',
        color: 0xFF92400E,
        description: 'Write your thoughts and feelings',
        duration: '10-15 min',
        difficulty: 'Easy',
        benefits: ['Self-awareness', 'Process emotions', 'Track growth'],
      ),
      HabitMission(
        id: 'digital_sabbath',
        name: 'Digital Sabbath',
        emoji: '🔌',
        category: 'Self-Care',
        color: 0xFF475569,
        description: 'Turn off all electronics for 24 hours',
        duration: '24 hours',
        difficulty: 'Hard',
        benefits: ['Ultimate peace', 'Real-world connection', 'Eye rest'],
      ),
      HabitMission(
        id: 'solo_date',
        name: 'Solo Date',
        emoji: '🍷',
        category: 'Self-Care',
        color: 0xFF9D174D,
        description: 'Take yourself out to a nice dinner or movie alone',
        duration: '2 hours',
        difficulty: 'Hard',
        benefits: ['Self-reliance', 'Confidence', 'Enjoying own company'],
      ),

      // 🤝 SOCIAL (Easy to Expert)
      HabitMission(
        id: 'compliment',
        name: 'Give a Compliment',
        emoji: '✨',
        category: 'Social',
        color: 0xFFEAB308,
        description: 'Give a genuine compliment to someone today',
        duration: '1 min',
        difficulty: 'Easy',
        benefits: ['Make someone smile', 'Positive vibes', 'Confidence'],
      ),
      HabitMission(
        id: 'call_family',
        name: 'Call Family',
        emoji: '📞',
        category: 'Social',
        color: 0xFFF43F5E,
        description: 'Stay connected with loved ones',
        duration: '10-20 min',
        difficulty: 'Easy',
        benefits: ['Stronger bonds', 'Support network', 'Happiness'],
      ),
      HabitMission(
        id: 'act_of_kindness',
        name: 'Random Act of Kindness',
        emoji: '💝',
        category: 'Social',
        color: 0xFFD946EF,
        description: 'Do something nice for a stranger',
        duration: '5 min',
        difficulty: 'Medium',
        benefits: ['Spread joy', 'Feel good', 'Better world'],
      ),
      HabitMission(
        id: 'difficult_conversation',
        name: 'Difficult Conversation',
        emoji: '💬',
        category: 'Social',
        color: 0xFF9A3412,
        description: 'Address a lingering conflict or issue honestly',
        duration: '30 min',
        difficulty: 'Hard',
        benefits: ['Resolution', 'Growth', 'Relief'],
      ),
      HabitMission(
        id: 'public_speaking',
        name: 'Public Speaking',
        emoji: '🎤',
        category: 'Social',
        color: 0xFF4338CA,
        description: 'Speak in front of a crowd or record a raw video of yourself talking',
        duration: '10 min',
        difficulty: 'Expert',
        benefits: ['Conquer fear', 'Charisma', 'Leadership'],
      ),

      // 💰 FINANCE (Easy to Expert)
      HabitMission(
        id: 'track_expenses',
        name: 'Track Expenses',
        emoji: '💰',
        category: 'Finance',
        color: 0xFF059669,
        description: 'Log all spending daily',
        duration: '5 min',
        difficulty: 'Easy',
        benefits: ['Money awareness', 'Save more', 'Financial goals'],
      ),
      HabitMission(
        id: 'pack_lunch',
        name: 'Pack a Lunch',
        emoji: '🍱',
        category: 'Finance',
        color: 0xFF84CC16,
        description: 'Cook and pack lunch instead of buying',
        duration: '20 min',
        difficulty: 'Easy',
        benefits: ['Save money', 'Healthier food', 'Portion control'],
      ),
      HabitMission(
        id: 'no_spend_day',
        name: 'No Spend Day',
        emoji: '🛑',
        category: 'Finance',
        color: 0xFFDC2626,
        description: 'Spend exactly \$0 today (except bills)',
        duration: 'All day',
        difficulty: 'Medium',
        benefits: ['Break buying habits', 'Save cash', 'Creativity'],
      ),
      HabitMission(
        id: 'side_hustle',
        name: 'Side Hustle Grind',
        emoji: '🚀',
        category: 'Finance',
        color: 0xFF2563EB,
        description: 'Spend 2 hours building an alternate income stream',
        duration: '2 hours',
        difficulty: 'Hard',
        benefits: ['Wealth building', 'Business skills', 'Freedom'],
      ),
      HabitMission(
        id: 'no_spend_week',
        name: 'No Spend Week',
        emoji: '🥶',
        category: 'Finance',
        color: 0xFF111827,
        description: 'Go an entire 7 days buying ONLY absolute survival necessities',
        duration: '7 Days',
        difficulty: 'Expert',
        benefits: ['Massive savings', 'Value recalibration', 'Discipline'],
      ),

      // 🎨 CREATIVITY (Easy to Expert)
      HabitMission(
        id: 'sketch',
        name: 'Sketch / Draw',
        emoji: '✏️',
        category: 'Creativity',
        color: 0xFFEC4899,
        description: 'Doodle or sketch anything for fun',
        duration: '15 min',
        difficulty: 'Easy',
        benefits: ['Express emotions', 'Relaxation', 'Right-brain exercise'],
      ),
      HabitMission(
        id: 'brainstorming',
        name: 'Idea Generation',
        emoji: '🧠',
        category: 'Creativity',
        color: 0xFFF59E0B,
        description: 'Write down 10 ideas for a specific topic',
        duration: '15 min',
        difficulty: 'Medium',
        benefits: ['Idea muscle', 'Problem solving', 'Innovation'],
      ),
      HabitMission(
        id: 'write_2000_words',
        name: 'Write 2,000 Words',
        emoji: '⌨️',
        category: 'Creativity',
        color: 0xFF8B5CF6,
        description: 'Write 2,000 words for a book, blog, or script',
        duration: '1-2 hours',
        difficulty: 'Hard',
        benefits: ['Creative output', 'Typing speed', 'Flow state'],
      ),
      HabitMission(
        id: 'publish_content',
        name: 'Publish Original Work',
        emoji: '🌐',
        category: 'Creativity',
        color: 0xFF0284C7,
        description: 'Create and publicly post a piece of art, video, or writing',
        duration: '2 hours',
        difficulty: 'Hard',
        benefits: ['Overcome perfectionism', 'Build audience', 'Vulnerability'],
      ),
      HabitMission(
        id: 'masterpiece',
        name: 'Start a Masterpiece',
        emoji: '🎨',
        category: 'Creativity',
        color: 0xFF4C1D95,
        description: 'Spend 4 straight hours working on your biggest creative project',
        duration: '4 hours',
        difficulty: 'Expert',
        benefits: ['Legacy building', 'Extreme focus', 'Artistic breakthrough'],
      ),

      // 🧹 ORGANIZATION (Easy to Expert)
      HabitMission(
        id: 'make_bed',
        name: 'Make the Bed',
        emoji: '🛏️',
        category: 'Organization',
        color: 0xFF3B82F6,
        description: 'Make your bed immediately upon waking',
        duration: '2 min',
        difficulty: 'Easy',
        benefits: ['First win of the day', 'Tidy room', 'Discipline'],
      ),
      HabitMission(
        id: 'ten_min_tidy',
        name: '10-Minute Tidy',
        emoji: '🧹',
        category: 'Organization',
        color: 0xFF10B981,
        description: 'Speed-clean a messy area for 10 minutes',
        duration: '10 min',
        difficulty: 'Easy',
        benefits: ['Visual peace', 'Clean environment', 'Quick momentum'],
      ),
      HabitMission(
        id: 'inbox_zero',
        name: 'Inbox Zero',
        emoji: '📧',
        category: 'Organization',
        color: 0xFF0891B2,
        description: 'Clear your email inbox completely',
        duration: '15-30 min',
        difficulty: 'Medium',
        benefits: ['Less stress', 'Stay organized', 'Quick responses'],
      ),
      HabitMission(
        id: 'deep_clean',
        name: 'Deep Clean House',
        emoji: '🧽',
        category: 'Organization',
        color: 0xFFEA580C,
        description: 'Scrub floors, clean bathrooms, dust everywhere',
        duration: '2-3 hours',
        difficulty: 'Hard',
        benefits: ['Pristine living space', 'Physical exercise', 'Mental clarity'],
      ),
      HabitMission(
        id: 'minimalist_purge',
        name: 'Minimalist Purge',
        emoji: '📦',
        category: 'Organization',
        color: 0xFFB91C1C,
        description: 'Find 50 items in your house to throw away or donate today',
        duration: '2 hours',
        difficulty: 'Expert',
        benefits: ['Extreme declutter', 'Letting go', 'Spaciousness'],
      ),
      HabitMission(
        id: 'digital_declutter',
        name: 'Digital Purge',
        emoji: '💻',
        category: 'Organization',
        color: 0xFF334155,
        description: 'Zero files on desktop, delete 1000+ old photos, organize all folders',
        duration: '3 hours',
        difficulty: 'Expert',
        benefits: ['Faster tech', 'Zero digital anxiety', 'Efficiency'],
      ),
    ];
  }

  /// Get missions by category
  static List<HabitMission> getMissionsByCategory(String category) {
    return getAllMissions()
        .where((m) => m.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Get categories
  static List<String> getCategories() {
    return [
      'Fitness',
      'Mindfulness',
      'Learning',
      'Health',
      'Productivity',
      'Self-Care',
      'Social',
      'Finance',
      'Creativity',
      'Organization',
    ];
  }

  /// Get category icon
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'mindfulness':
        return Icons.self_improvement_rounded;
      case 'learning':
        return Icons.school_rounded;
      case 'health':
        return Icons.favorite_rounded;
      case 'productivity':
        return Icons.rocket_launch_rounded;
      case 'self-care':
        return Icons.spa_rounded;
      case 'social':
        return Icons.people_rounded;
      case 'finance':
        return Icons.savings_rounded;
      case 'creativity':
        return Icons.color_lens_rounded;
      case 'organization':
        return Icons.inventory_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  /// Get category color
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return const Color(0xFF10B981);
      case 'mindfulness':
        return const Color(0xFF8B5CF6);
      case 'learning':
        return const Color(0xFF3B82F6);
      case 'health':
        return const Color(0xFFEF4444);
      case 'productivity':
        return const Color(0xFFF97316);
      case 'self-care':
        return const Color(0xFFEC4899);
      case 'social':
        return const Color(0xFFF43F5E);
      case 'finance':
        return const Color(0xFF059669);
      case 'creativity':
        return const Color(0xFFD946EF);
      case 'organization':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF6366F1);
    }
  }
}

class HabitMission {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final int color;
  final String description;
  final String duration;
  final String difficulty;
  final List<String> benefits;

  HabitMission({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.color,
    required this.description,
    required this.duration,
    required this.difficulty,
    required this.benefits,
  });

  Color get colorValue => Color(color);
}
