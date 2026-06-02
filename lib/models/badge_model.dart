import 'package:flutter/material.dart';

// ═══════════════════════════════════════
// BADGE RARITY ENUM
// ═══════════════════════════════════════

enum BadgeRarity {
  common,
  rare,
  epic,
  legendary,
}

// ═══════════════════════════════════════
// BADGE CATEGORY ENUM
// ═══════════════════════════════════════

enum BadgeCategory {
  streak,
  completion,
  perfection,
  recovery,
  timeBased,
  variety,
  special,
}

// ═══════════════════════════════════════
// BADGE DEFINITION — Static config
// ═══════════════════════════════════════

class BadgeDefinition {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final int threshold;
  final String thresholdUnit;
  final int xpReward;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.category,
    required this.rarity,
    required this.threshold,
    required this.thresholdUnit,
    required this.xpReward,
  });

  Color get rarityColor {
    switch (rarity) {
      case BadgeRarity.common:
        return const Color(0xFF94A3B8);
      case BadgeRarity.rare:
        return const Color(0xFF3B82F6);
      case BadgeRarity.epic:
        return const Color(0xFF8B5CF6);
      case BadgeRarity.legendary:
        return const Color(0xFFFFD700);
    }
  }

  String get rarityLabel {
    switch (rarity) {
      case BadgeRarity.common:
        return 'Common';
      case BadgeRarity.rare:
        return 'Rare';
      case BadgeRarity.epic:
        return 'Epic';
      case BadgeRarity.legendary:
        return 'Legendary';
    }
  }

  String get categoryLabel {
    switch (category) {
      case BadgeCategory.streak:
        return '🔥 Streak';
      case BadgeCategory.completion:
        return '⭐ Completion';
      case BadgeCategory.perfection:
        return '📅 Perfection';
      case BadgeCategory.recovery:
        return '💪 Recovery';
      case BadgeCategory.timeBased:
        return '🌅 Time-Based';
      case BadgeCategory.variety:
        return '🎯 Variety';
      case BadgeCategory.special:
        return '🌟 Special';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case BadgeCategory.streak:
        return Icons.local_fire_department_rounded;
      case BadgeCategory.completion:
        return Icons.check_circle_rounded;
      case BadgeCategory.perfection:
        return Icons.calendar_month_rounded;
      case BadgeCategory.recovery:
        return Icons.replay_rounded;
      case BadgeCategory.timeBased:
        return Icons.access_time_rounded;
      case BadgeCategory.variety:
        return Icons.category_rounded;
      case BadgeCategory.special:
        return Icons.star_rounded;
    }
  }
}

// ═══════════════════════════════════════
// UNLOCKED BADGE — Runtime data
// ═══════════════════════════════════════

class UnlockedBadge {
  final String badgeId;
  final DateTime unlockedAt;

  const UnlockedBadge({
    required this.badgeId,
    required this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
    'badgeId': badgeId,
    'unlockedAt': unlockedAt.toIso8601String(),
  };

  factory UnlockedBadge.fromJson(Map<String, dynamic> json) => UnlockedBadge(
    badgeId: json['badgeId'] as String,
    unlockedAt: DateTime.parse(json['unlockedAt'] as String),
  );
}

// ═══════════════════════════════════════
// ALL BADGE DEFINITIONS — Admin can modify
// ═══════════════════════════════════════

class AllBadges {
  static List<BadgeDefinition> getAll() {
    return [
      // ═══ 🔥 STREAK BADGES ═══
      const BadgeDefinition(
        id: 'streak_3', name: 'Spark', emoji: '✨',
        description: 'Achieve a 3-day streak on any habit',
        category: BadgeCategory.streak, rarity: BadgeRarity.common,
        threshold: 3, thresholdUnit: 'day streak', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'streak_7', name: 'Flame', emoji: '🔥',
        description: 'Achieve a 7-day streak on any habit',
        category: BadgeCategory.streak, rarity: BadgeRarity.common,
        threshold: 7, thresholdUnit: 'day streak', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'streak_14', name: 'Fire', emoji: '🔥',
        description: 'Achieve a 14-day streak on any habit',
        category: BadgeCategory.streak, rarity: BadgeRarity.rare,
        threshold: 14, thresholdUnit: 'day streak', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'streak_30', name: 'Inferno', emoji: '🌋',
        description: 'Achieve a 30-day streak on any habit',
        category: BadgeCategory.streak, rarity: BadgeRarity.rare,
        threshold: 30, thresholdUnit: 'day streak', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'streak_60', name: 'Volcano', emoji: '🌋',
        description: 'Achieve a 60-day streak — two full months!',
        category: BadgeCategory.streak, rarity: BadgeRarity.epic,
        threshold: 60, thresholdUnit: 'day streak', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'streak_100', name: 'Phoenix', emoji: '🐦‍🔥',
        description: 'Achieve a 100-day streak — unstoppable!',
        category: BadgeCategory.streak, rarity: BadgeRarity.epic,
        threshold: 100, thresholdUnit: 'day streak', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'streak_200', name: 'Immortal', emoji: '♾️',
        description: 'Achieve a 200-day streak — you are immortal!',
        category: BadgeCategory.streak, rarity: BadgeRarity.legendary,
        threshold: 200, thresholdUnit: 'day streak', xpReward: 250,
      ),
      const BadgeDefinition(
        id: 'streak_365', name: 'Eternal Flame', emoji: '🌠',
        description: 'A full year streak — 365 days!',
        category: BadgeCategory.streak, rarity: BadgeRarity.legendary,
        threshold: 365, thresholdUnit: 'day streak', xpReward: 250,
      ),

      // ═══ ⭐ COMPLETION BADGES ═══
      const BadgeDefinition(
        id: 'complete_1', name: 'First Step', emoji: '👣',
        description: 'Complete your very first habit',
        category: BadgeCategory.completion, rarity: BadgeRarity.common,
        threshold: 1, thresholdUnit: 'completions', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'complete_10', name: 'Getting Started', emoji: '🚀',
        description: 'Complete 10 total habit check-ins',
        category: BadgeCategory.completion, rarity: BadgeRarity.common,
        threshold: 10, thresholdUnit: 'completions', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'complete_50', name: 'Dedicated', emoji: '💎',
        description: 'Complete 50 total habit check-ins',
        category: BadgeCategory.completion, rarity: BadgeRarity.rare,
        threshold: 50, thresholdUnit: 'completions', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'complete_100', name: 'Committed', emoji: '🏅',
        description: 'Complete 100 total habit check-ins',
        category: BadgeCategory.completion, rarity: BadgeRarity.rare,
        threshold: 100, thresholdUnit: 'completions', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'complete_250', name: 'Unstoppable', emoji: '⚡',
        description: 'Complete 250 total habit check-ins',
        category: BadgeCategory.completion, rarity: BadgeRarity.epic,
        threshold: 250, thresholdUnit: 'completions', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'complete_500', name: 'Master', emoji: '🏆',
        description: 'Complete 500 total habit check-ins',
        category: BadgeCategory.completion, rarity: BadgeRarity.epic,
        threshold: 500, thresholdUnit: 'completions', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'complete_1000', name: 'Legend', emoji: '👑',
        description: 'Complete 1,000 total habit check-ins!',
        category: BadgeCategory.completion, rarity: BadgeRarity.legendary,
        threshold: 1000, thresholdUnit: 'completions', xpReward: 250,
      ),
      const BadgeDefinition(
        id: 'complete_2500', name: 'Mythic', emoji: '🐉',
        description: 'Complete 2,500 total habit check-ins — mythical!',
        category: BadgeCategory.completion, rarity: BadgeRarity.legendary,
        threshold: 2500, thresholdUnit: 'completions', xpReward: 250,
      ),

      // ═══ 📅 PERFECTION BADGES ═══
      const BadgeDefinition(
        id: 'perfect_1', name: 'Perfect Day', emoji: '🌟',
        description: 'Complete all habits in a single day',
        category: BadgeCategory.perfection, rarity: BadgeRarity.common,
        threshold: 1, thresholdUnit: 'perfect days', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'perfect_7', name: 'Perfect Week', emoji: '📅',
        description: '7 consecutive perfect days',
        category: BadgeCategory.perfection, rarity: BadgeRarity.rare,
        threshold: 7, thresholdUnit: 'consecutive perfect days', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'perfect_14', name: 'Perfect Fortnight', emoji: '🗓️',
        description: '14 consecutive perfect days',
        category: BadgeCategory.perfection, rarity: BadgeRarity.epic,
        threshold: 14, thresholdUnit: 'consecutive perfect days', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'perfect_30', name: 'Perfect Month', emoji: '📆',
        description: '30 consecutive perfect days — flawless!',
        category: BadgeCategory.perfection, rarity: BadgeRarity.epic,
        threshold: 30, thresholdUnit: 'consecutive perfect days', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'perfect_90', name: 'Perfect Quarter', emoji: '🏛️',
        description: '90 consecutive perfect days — god-tier!',
        category: BadgeCategory.perfection, rarity: BadgeRarity.legendary,
        threshold: 90, thresholdUnit: 'consecutive perfect days', xpReward: 250,
      ),

      // ═══ 💪 RECOVERY BADGES ═══
      const BadgeDefinition(
        id: 'comeback_1', name: 'Bounce Back', emoji: '🔄',
        description: 'Resume a habit after missing 1 day',
        category: BadgeCategory.recovery, rarity: BadgeRarity.common,
        threshold: 1, thresholdUnit: 'comebacks', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'comeback_3', name: 'Comeback Kid', emoji: '💪',
        description: 'Resume after missing 3+ days, 3 times',
        category: BadgeCategory.recovery, rarity: BadgeRarity.rare,
        threshold: 3, thresholdUnit: 'comebacks', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'comeback_5', name: 'Resilient', emoji: '🛡️',
        description: 'Come back from breaks 5 times total',
        category: BadgeCategory.recovery, rarity: BadgeRarity.rare,
        threshold: 5, thresholdUnit: 'comebacks', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'comeback_10', name: 'Unbreakable', emoji: '🗿',
        description: 'Come back from breaks 10 times — nothing stops you!',
        category: BadgeCategory.recovery, rarity: BadgeRarity.epic,
        threshold: 10, thresholdUnit: 'comebacks', xpReward: 100,
      ),

      // ═══ 🌅 TIME-BASED BADGES ═══
      const BadgeDefinition(
        id: 'early_5', name: 'Early Bird', emoji: '🐦',
        description: 'Complete habits before 8 AM, 5 times',
        category: BadgeCategory.timeBased, rarity: BadgeRarity.common,
        threshold: 5, thresholdUnit: 'early completions', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'early_15', name: 'Dawn Warrior', emoji: '🌅',
        description: 'Complete habits before 6 AM, 15 times',
        category: BadgeCategory.timeBased, rarity: BadgeRarity.rare,
        threshold: 15, thresholdUnit: 'dawn completions', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'night_5', name: 'Night Owl', emoji: '🦉',
        description: 'Complete habits after 10 PM, 5 times',
        category: BadgeCategory.timeBased, rarity: BadgeRarity.common,
        threshold: 5, thresholdUnit: 'night completions', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'night_15', name: 'Midnight Hero', emoji: '🌙',
        description: 'Complete habits after midnight, 15 times',
        category: BadgeCategory.timeBased, rarity: BadgeRarity.rare,
        threshold: 15, thresholdUnit: 'midnight completions', xpReward: 50,
      ),

      // ═══ 🎯 VARIETY BADGES ═══
      const BadgeDefinition(
        id: 'variety_3', name: 'Multi-Tasker', emoji: '🎪',
        description: 'Have 3 active habits at the same time',
        category: BadgeCategory.variety, rarity: BadgeRarity.common,
        threshold: 3, thresholdUnit: 'active habits', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'variety_5', name: 'Life Designer', emoji: '🎨',
        description: 'Have 5 active habits at the same time',
        category: BadgeCategory.variety, rarity: BadgeRarity.rare,
        threshold: 5, thresholdUnit: 'active habits', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'variety_8', name: 'Habit Architect', emoji: '🏗️',
        description: 'Have 8 active habits at the same time',
        category: BadgeCategory.variety, rarity: BadgeRarity.epic,
        threshold: 8, thresholdUnit: 'active habits', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'variety_10', name: 'Life Master', emoji: '🌍',
        description: 'Have 10+ active habits — you control your life!',
        category: BadgeCategory.variety, rarity: BadgeRarity.legendary,
        threshold: 10, thresholdUnit: 'active habits', xpReward: 250,
      ),

      // ═══ 🌟 SPECIAL BADGES ═══
      const BadgeDefinition(
        id: 'explorer', name: 'Explorer', emoji: '🧭',
        description: 'Try habits from all categories',
        category: BadgeCategory.special, rarity: BadgeRarity.rare,
        threshold: 8, thresholdUnit: 'categories tried', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'alarm_hero', name: 'Alarm Hero', emoji: '⏰',
        description: 'Dismiss alarm & complete habit 10 times',
        category: BadgeCategory.special, rarity: BadgeRarity.rare,
        threshold: 10, thresholdUnit: 'alarm completions', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'no_excuse', name: 'No Excuse', emoji: '🚫',
        description: 'Submit missed reasons 10 times (self-awareness!)',
        category: BadgeCategory.special, rarity: BadgeRarity.rare,
        threshold: 10, thresholdUnit: 'reasons submitted', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'app_7', name: 'Consistent', emoji: '📱',
        description: 'Use the app 7 consecutive days',
        category: BadgeCategory.special, rarity: BadgeRarity.common,
        threshold: 7, thresholdUnit: 'consecutive app days', xpReward: 25,
      ),
      const BadgeDefinition(
        id: 'app_30', name: 'Devoted', emoji: '🤝',
        description: 'Use the app 30 consecutive days',
        category: BadgeCategory.special, rarity: BadgeRarity.rare,
        threshold: 30, thresholdUnit: 'consecutive app days', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'app_100', name: 'Veteran', emoji: '🎖️',
        description: 'Use the app 100 consecutive days',
        category: BadgeCategory.special, rarity: BadgeRarity.epic,
        threshold: 100, thresholdUnit: 'consecutive app days', xpReward: 100,
      ),
      const BadgeDefinition(
        id: 'app_365', name: 'OG User', emoji: '🏅',
        description: 'Use the app for a full year — 365 days!',
        category: BadgeCategory.special, rarity: BadgeRarity.legendary,
        threshold: 365, thresholdUnit: 'consecutive app days', xpReward: 250,
      ),
      const BadgeDefinition(
        id: 'self_aware', name: 'Self-Aware', emoji: '🪞',
        description: 'Write notes on 20 different habits',
        category: BadgeCategory.special, rarity: BadgeRarity.rare,
        threshold: 20, thresholdUnit: 'habits with notes', xpReward: 50,
      ),
      const BadgeDefinition(
        id: 'goal_crusher', name: 'Goal Crusher', emoji: '🎯',
        description: 'Hit daily goal 50 times across all habits',
        category: BadgeCategory.special, rarity: BadgeRarity.epic,
        threshold: 50, thresholdUnit: 'daily goals met', xpReward: 100,
      ),
    ];
  }

  static BadgeDefinition? getById(String id) {
    try {
      return getAll().firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<BadgeDefinition> getByCategory(BadgeCategory category) {
    return getAll().where((b) => b.category == category).toList();
  }

  static List<BadgeCategory> getAllCategories() {
    return BadgeCategory.values;
  }
}