// lib/config/app_config.dart

import 'package:flutter/material.dart';

class AppConfig {
  const AppConfig._();

  static const String appName = 'Habit Node';
  static const String appTagline = 'Start from Zero, Grow like a Hero.';
  static const String logoPath = 'assets/images/logo.png';
  static const String version = '1.0.5';
  static const String buildNumber = '1';

  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color accentColor = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF00C853);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);

  static const bool enableFastBoot = true;
  static const bool deferredAdLoading = true;
  static const int minSplashDuration = 800;
  static const int maxSplashDuration = 1500;

  // =========================================================
  // 📢 AD SYSTEM CONTROLS (Admin Panel Ready - No Const)
  // =========================================================
  static bool enableAds = true;
  static bool enableAdMob = false;
  static bool enableUnityAds = true;

  static bool enableBannerAd = true;
  static bool enableInterstitialAd = true;
  static bool enableRewardedAd = true;

  static bool adSoundEnabled = false;
  static bool adDebugMode = true;

  static int interstitialAdFrequency = 4;
  static int maxInterstitialPerSession = 5;
  static int minSecondsBetweenInterstitial = 120;

  static int rewardedExtraHabits = 3;

  // =========================================================
  // ADMOB IDs (Admin Panel Ready)
  // =========================================================
  static String admobBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static String admobInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static String admobRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static String admobAppId = 'ca-app-pub-3940256099942544~3347511713';

  // =========================================================
  // UNITY ADS IDs (Admin Panel Ready)
  // =========================================================
  static String unityAndroidGameId = '6073314';
  static String unityIosGameId = '6073315';
  static bool unityTestMode = false;
  static String unityInterstitialPlacementId = 'Interstitial_Android';
  static String unityRewardedPlacementId = 'Rewarded_Android';
  static String unityBannerPlacementId = 'Banner_Android';

  // =========================================================
  // SUBSCRIPTION (Admin Panel Ready)
  // =========================================================
  static bool enableProVersion = true;
  static String monthlyPrice = '₹49';
  static String yearlyPrice = '₹399';
  static String monthlyProductId = 'habit_node_monthly';
  static String yearlyProductId = 'habit_node_yearly';

  static String proProductId = 'habit_node_pro';
  static String proPrice = '₹399';

  static int maxHabitsFree = 5;
  static int maxHabitsPro = 999;

  // =========================================================
  // DISABLED FEATURES
  // =========================================================
  static const bool enableFlowAI = false;
  static const bool enableOfflineMlTranslation = false;
  static const bool enableDynamicContentTranslation = false;
  static const String defaultAppLanguageCode = 'en';

  // =========================================================
  // SMART ROUTINES & QUICK ADD
  // =========================================================
  static const bool enableSmartRoutines = true;
  static const bool smartRoutinesProOnly = true;
  static const bool enableSeasonalRoutines = true;
  static const bool autoDetectCountry = true;
  static const bool enableQuickAdd = true;
  static const int maxQuickAddFree = 8;

  // =========================================================
  // DEVELOPER / LINKS (Admin Panel Ready)
  // =========================================================
  static String developerName = 'VHIR';
  static String supportEmail = 'vhirsupport@gmail.com';
  static String websiteUrl = 'https://vrapp24.blogspot.com/';
  static String privacyPolicyUrl = 'https://vhir-apps.github.io/habit-node-privacy_policy/';
  static String termsUrl = 'https://vhir-apps.github.io/habit-node-terms_and_conditions/';
  static const String packageName = 'com.habit.node';
  static String playStoreAppUrl = 'https://play.google.com/store/apps/details?id=$packageName';
  static String playStoreRateUrl = 'market://details?id=$packageName';
  static String playStoreDeveloperUrl = 'https://vrapp24.blogspot.com/';
  static String shareMessage = 'Check out $appName - $appTagline! 🚀\n\nDownload now:\n$playStoreAppUrl';

  static String telegramUrl = '';
  static String facebookUrl = '';
  static String youtubeUrl = '';

  // =========================================================
  // FEATURE TOGGLES (Admin Panel Ready)
  // =========================================================
  static bool enableNotifications = true;
  static bool enableBackup = true;
  static bool enableStats = true;
  static bool enableMissions = true;
  static bool enableDailyTips = true;
  static bool enableProfileHeader = true;
  static bool enableSkeletonLoading = true;
  static bool enablePullToRefresh = true;
  static bool enableBadges = true;
  static bool enableMissedHabitDialog = true;
  static bool enableSmartReminders = true;

  // =========================================================
  // NOTIFICATION CONFIGS
  // =========================================================
  static const String notificationChannelId = 'habit_reminders';
  static const String notificationChannelName = 'Habit Reminders';
  static const String notificationChannelDesc = 'Daily habit reminder notifications';
  static const bool enableDailySummary = true;
  static const int dailySummaryHour = 20;
  static const int dailySummaryMinute = 0;

  // =========================================================
  // BACKUP CONFIGS
  // =========================================================
  static const String backupFolderName = 'HabitNodeBackups';
  static const String backupFilePrefix = 'habitnode_backup_';
  static const String backupFileExtension = '.json';
  static const int maxCachedTips = 50;

  // =========================================================
  // 🎨 UI CONFIGS
  // =========================================================
  static const double cardBorderRadius = 20.0;
  static const double buttonBorderRadius = 16.0;
  static const double headerBorderRadius = 32.0;
  static const double chipBorderRadius = 12.0;
  static const int fadeAnimDuration = 800;
  static const int slideAnimDuration = 500;
  static const int pulseAnimDuration = 1500;
  static const int clockUpdateInterval = 30;

  // =========================================================
  // 🏆 BADGE SYSTEM CONFIG (Admin Panel Ready)
  // =========================================================
  static List<int> streakBadgeThresholds = [3, 7, 14, 30, 60, 100, 200, 365];
  static List<int> completionBadgeThresholds = [1, 10, 50, 100, 250, 500, 1000, 2500];
  static List<int> perfectDayThresholds = [1, 7, 14, 30, 90];
  static List<int> comebackThresholds = [1, 3, 5, 10];
  static List<int> timeBasedThresholds = [5, 15, 30, 50];
  static List<int> varietyThresholds = [3, 5, 8, 10];
  static List<int> appUsageThresholds = [7, 30, 100, 365];

  static const int alarmHeroThreshold = 10;
  static const int noExcuseThreshold = 10;
  static const int selfAwareThreshold = 20;
  static const int goalCrusherThreshold = 50;

  static const int xpCommon = 25;
  static const int xpRare = 50;
  static const int xpEpic = 100;
  static const int xpLegendary = 250;

  static List<int> levelThresholds = [
    0, 50, 150, 300, 500, 800, 1200, 1700, 2400, 3200, 4200, 5500, 7000, 9000, 11500, 14500, 18000, 22000, 27000, 33000,
  ];

  static List<Map<String, String>> levelTitles = [
    {'emoji': '🌱', 'title': 'Beginner'},
    {'emoji': '🌿', 'title': 'Starter'},
    {'emoji': '🌳', 'title': 'Grower'},
    {'emoji': '⭐', 'title': 'Achiever'},
    {'emoji': '🔥', 'title': 'Dedicated'},
    {'emoji': '💪', 'title': 'Warrior'},
    {'emoji': '🎯', 'title': 'Focused'},
    {'emoji': '🏅', 'title': 'Champion'},
    {'emoji': '🏆', 'title': 'Master'},
    {'emoji': '💎', 'title': 'Diamond'},
    {'emoji': '🌟', 'title': 'Star'},
    {'emoji': '⚡', 'title': 'Thunder'},
    {'emoji': '🔱', 'title': 'Titan'},
    {'emoji': '🐉', 'title': 'Dragon'},
    {'emoji': '🦅', 'title': 'Eagle'},
    {'emoji': '👑', 'title': 'Royal'},
    {'emoji': '🌌', 'title': 'Cosmic'},
    {'emoji': '🔮', 'title': 'Mystic'},
    {'emoji': '🏛️', 'title': 'Immortal'},
    {'emoji': '🌠', 'title': 'Legend'},
  ];

  // =========================================================
  // 🔔 SMART REMINDER MESSAGES
  // =========================================================
  static Map<String, String> smartReminderTemplates = {
    'tired': '😊 You were tired yesterday. Start {habit} early today! 💪',
    'no_time': '⏰ No time yesterday? Try doing {habit} right now — just start! 🚀',
    'forgot': '🔔 Don\'t forget {habit} today! You\'ve got this! ✅',
    'sick': '🤗 Hope you\'re feeling better! If you can, try {habit} today 💚',
    'lazy': '⚡ Beat the laziness! Just 2 minutes of {habit} to start! 🏆',
    'busy': '📋 Busy day? Take a quick break for {habit}! 🎯',
    'not_motivated': '🌟 Remember why you started {habit}! Every step counts! 💫',
    'weather': '🌤️ Don\'t let weather stop you! Adapt {habit} for today! 💪',
    'default': '💡 Yesterday didn\'t work out. Today is a fresh start for {habit}! ✨',
  };

  // =========================================================
  // 📋 MISSED HABIT REASONS
  // =========================================================
  static List<Map<String, String>> missedReasons = [
    {'id': 'tired', 'emoji': '😴', 'label': 'Was tired'},
    {'id': 'no_time', 'emoji': '⏰', 'label': 'No time'},
    {'id': 'forgot', 'emoji': '😑', 'label': 'Forgot'},
    {'id': 'sick', 'emoji': '🤒', 'label': 'Was sick'},
    {'id': 'lazy', 'emoji': '😮‍💨', 'label': 'Felt lazy'},
    {'id': 'busy', 'emoji': '📋', 'label': 'Too busy'},
    {'id': 'not_motivated', 'emoji': '😶', 'label': 'No motivation'},
    {'id': 'weather', 'emoji': '🌧️', 'label': 'Bad weather'},
  ];

  // =========================================================
  // DEFAULT DATA
  // =========================================================
  static const List<String> defaultCategories = ['Fitness', 'Health', 'Mindfulness', 'Learning', 'Productivity', 'Self-Care', 'Social', 'Finance', 'Spiritual', 'Other'];
  static const List<String> defaultEmojis = ['💪', '🧘', '📚', '💧', '🏃', '🧠', '🎯', '✅', '🌅', '😴', '🥗', '📝', '🎨', '🏋️', '🚶', '🧴', '📖', '🎵', '🙏', '💰', '📵', '🌳', '💊', '🚫', '⏰', '📧', '🍎', '🎧', '📞', '💝', '🧘‍♂️', '🌬️', '🏆', '⭐', '🔥', '💎', '🚀', '✨', '❤️', '🌟'];
  static const List<Color> habitColors = [Color(0xFF6C63FF), Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFEAB308), Color(0xFF22C55E), Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFEC4899), Color(0xFFF43F5E), Color(0xFF64748B), Color(0xFF92400E), Color(0xFF059669)];

  static const List<Map<String, dynamic>> starterGoalPresets = [
    {'id': 'water', 'name': 'Drink Water', 'emoji': '💧', 'category': 'Health', 'color': 0xFF0EA5E9},
    {'id': 'read', 'name': 'Read 10 Pages', 'emoji': '📚', 'category': 'Learning', 'color': 0xFF3B82F6},
    {'id': 'walk', 'name': 'Morning Walk', 'emoji': '🚶', 'category': 'Fitness', 'color': 0xFF10B981},
    {'id': 'meditate', 'name': 'Meditate', 'emoji': '🧘', 'category': 'Mindfulness', 'color': 0xFF8B5CF6},
    {'id': 'journal', 'name': 'Journal', 'emoji': '📝', 'category': 'Self-Care', 'color': 0xFF92400E},
    {'id': 'sleep', 'name': 'Sleep Early', 'emoji': '😴', 'category': 'Health', 'color': 0xFF4F46E5},
  ];

  static String getSeason(int month, {bool isSouthernHemisphere = false}) {
    if (isSouthernHemisphere) {
      if (month >= 3 && month <= 5) return 'Autumn';
      if (month >= 6 && month <= 8) return 'Winter';
      if (month >= 9 && month <= 11) return 'Spring';
      return 'Summer';
    }
    if (month >= 3 && month <= 5) return 'Spring';
    if (month >= 6 && month <= 8) return 'Summer';
    if (month >= 9 && month <= 11) return 'Autumn';
    return 'Winter';
  }

  static const List<String> southernHemisphereCountries = ['AU', 'NZ', 'AR', 'BR', 'CL', 'ZA', 'UY', 'PY'];

  // =========================================================
  // 🍅 STUDY MODE & POMODORO SETTINGS
  // =========================================================

  // Default Timer Settings (Minutes)
  static const int defaultFocusMinutes = 25;
  static const int defaultShortBreakMinutes = 5;
  static const int defaultLongBreakMinutes = 15;
  static const int pomodorosUntilLongBreak = 4;

  // Custom Timer Limits (Minutes)
  static const int minFocusMinutes = 15;
  static const int maxFocusMinutes = 60;
  static const int minBreakMinutes = 5;
  static const int maxBreakMinutes = 30;

  // Predefined Study Subjects & Colors
  static const Map<String, Color> predefinedSubjects = {
    'Math': Color(0xFFEF4444),
    'Physics': Color(0xFF3B82F6),
    'Chemistry': Color(0xFF10B981),
    'Biology': Color(0xFF22C55E),
    'English': Color(0xFFF59E0B),
    'History': Color(0xFF8B5CF6),
    'Programming': Color(0xFF06B6D4),
    'Language': Color(0xFFEC4899),
    'Other': Color(0xFF6B7280),
  };

  // Study Badges Thresholds
  static const int badgeStudyStarterHours = 1;
  static const int badgeBookwormHours = 10;
  static const int badgeScholarHours = 50;
  static const int badgeStudyStreak7 = 7;
  static const int badgeStudyStreak30 = 30;
  static const int badgeSubjectMasterHours = 20;
  static const int badgeNightOwlHour = 22;
  static const int badgeEarlyBirdHour = 7;
  static const int badgeMarathonPomodoros = 4;

  // =========================================================
  // 🆕 STUDY TARGETS CONFIG
  // =========================================================
  static const int defaultDailyTargetMinutes = 120; // 2 hours
  static const int defaultWeeklyTargetMinutes = 900; // 15 hours
  static const int minTargetMinutes = 30;
  static const int maxTargetMinutes = 1440; // 24 hours

  // Target Quick Presets (Daily in minutes)
  static const List<Map<String, dynamic>> dailyTargetPresets = [
    {'label': '30 min', 'minutes': 30},
    {'label': '1 hour', 'minutes': 60},
    {'label': '2 hours', 'minutes': 120},
    {'label': '3 hours', 'minutes': 180},
    {'label': '4 hours', 'minutes': 240},
    {'label': '5 hours', 'minutes': 300},
  ];

  // Target Quick Presets (Weekly in minutes)
  static const List<Map<String, dynamic>> weeklyTargetPresets = [
    {'label': '5 hours', 'minutes': 300},
    {'label': '10 hours', 'minutes': 600},
    {'label': '15 hours', 'minutes': 900},
    {'label': '20 hours', 'minutes': 1200},
    {'label': '25 hours', 'minutes': 1500},
    {'label': '30 hours', 'minutes': 1800},
  ];

  // =========================================================
  // 🆕 DAILY STUDY ROUTINE CONFIG
  // =========================================================
  static const List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const List<Map<String, dynamic>> routineTimePresets = [
    {'label': 'Morning (6-8 AM)', 'start': '06:00', 'end': '08:00'},
    {'label': 'Mid Morning (8-10 AM)', 'start': '08:00', 'end': '10:00'},
    {'label': 'Afternoon (2-4 PM)', 'start': '14:00', 'end': '16:00'},
    {'label': 'Evening (5-7 PM)', 'start': '17:00', 'end': '19:00'},
    {'label': 'Night (8-10 PM)', 'start': '20:00', 'end': '22:00'},
  ];

  // =========================================================
  // 🆕 ERROR MESSAGES (Professional Error Handling)
  // =========================================================
  static const Map<String, Map<String, String>> errorMessages = {
    'network': {
      'title': 'No Internet',
      'message': 'Please check your internet connection and try again.',
      'icon': '📶',
    },
    'ad_load': {
      'title': 'Ad Not Available',
      'message': 'Unable to load advertisement. Please try again later.',
      'icon': '📺',
    },
    'database': {
      'title': 'Data Error',
      'message': 'Something went wrong while accessing your data.',
      'icon': '💾',
    },
    'permission': {
      'title': 'Permission Required',
      'message': 'Please grant the required permission to continue.',
      'icon': '🔐',
    },
    'timeout': {
      'title': 'Request Timeout',
      'message': 'The request took too long. Please try again.',
      'icon': '⏱️',
    },
    'server': {
      'title': 'Server Error',
      'message': 'Our servers are having issues. Please try again later.',
      'icon': '🖥️',
    },
    'unknown': {
      'title': 'Oops!',
      'message': 'Something went wrong. Please try again.',
      'icon': '😅',
    },
    'ui_error': {
      'title': 'Display Error',
      'message': 'Unable to display this content properly.',
      'icon': '🎨',
    },
    'firebase': {
      'title': 'Connection Error',
      'message': 'Unable to connect to cloud services.',
      'icon': '☁️',
    },
    'purchase': {
      'title': 'Purchase Failed',
      'message': 'Unable to complete purchase. Please try again.',
      'icon': '💳',
    },
    'backup': {
      'title': 'Backup Error',
      'message': 'Unable to backup/restore data.',
      'icon': '📁',
    },
    'notification': {
      'title': 'Notification Error',
      'message': 'Unable to schedule notification.',
      'icon': '🔔',
    },
  };

  static Map<String, String> getErrorInfo(String errorCode) {
    final code = errorCode.toLowerCase();
    return errorMessages[code] ?? errorMessages['unknown']!;
  }

  // =========================================================
  // 🔧 ADMIN HELPER METHODS
  // =========================================================
  static String getSmartMessage(String reasonId, String habitName) {
    final template = smartReminderTemplates[reasonId] ?? smartReminderTemplates['default']!;
    return template.replaceAll('{habit}', habitName);
  }

  static int getLevelFromXp(int xp) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  static Map<String, String> getLevelInfo(int level) {
    final index = (level - 1).clamp(0, levelTitles.length - 1);
    return levelTitles[index];
  }

  static double getLevelProgress(int xp) {
    final level = getLevelFromXp(xp);
    if (level >= levelThresholds.length) return 1.0;
    final currentThreshold = levelThresholds[level - 1];
    final nextThreshold = levelThresholds[level];
    final progress = (xp - currentThreshold) / (nextThreshold - currentThreshold);
    return progress.clamp(0.0, 1.0);
  }

  static int getXpForNextLevel(int xp) {
    final level = getLevelFromXp(xp);
    if (level >= levelThresholds.length) return 0;
    return levelThresholds[level] - xp;
  }
}