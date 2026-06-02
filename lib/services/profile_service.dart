import '../config/app_config.dart';
import 'badge_service.dart';
import 'database_service.dart';

class ProfileService {
  /// Get current level (XP-based from badges)
  static int getLevel() => BadgeService.getLevel();

  /// Get level info (emoji + title)
  static Map<String, String> getLevelInfo() => BadgeService.getLevelInfo();

  /// Get level progress (0.0 - 1.0)
  static double getLevelProgress() => BadgeService.getLevelProgress();

  /// Get total XP
  static int getTotalXp() => BadgeService.getXp();

  /// Get XP needed for next level
  static int getXpForNextLevel() => BadgeService.getXpForNextLevel();

  /// Get user title string
  static String getLevelTitle() {
    final info = getLevelInfo();
    return '${info['emoji']} ${info['title']}';
  }

  /// Get badges unlocked count
  static int getBadgesUnlocked() => BadgeService.getUnlockedCount();

  /// Get total badges
  static int getTotalBadges() => BadgeService.getTotalCount();

  /// Get consecutive app usage days
  static int getAppUsageDays() => BadgeService.getConsecutiveAppDays();

  /// Get profile stats map (for display)
  static Map<String, dynamic> getProfileStats() {
    return {
      'level': getLevel(),
      'levelTitle': getLevelTitle(),
      'xp': getTotalXp(),
      'xpNext': getXpForNextLevel(),
      'progress': getLevelProgress(),
      'badges': getBadgesUnlocked(),
      'totalBadges': getTotalBadges(),
      'appDays': getAppUsageDays(),
      'totalCompleted': DatabaseService.getTotalHabitsCompleted(),
      'bestStreak': DatabaseService.getBestStreakTotal(),
      'habits': DatabaseService.getAllHabits().length,
    };
  }
}