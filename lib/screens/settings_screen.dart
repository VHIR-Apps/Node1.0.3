// lib/screens/settings_screen.dart

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../main.dart';
import '../screens/leaderboard_profile_screen.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';
import '../services/leaderboard_service.dart';
import '../services/notification_service.dart';
import '../services/routine_share_service.dart';
import '../services/sound_service.dart';
import '../services/tts_service.dart';
import '../services/url_service.dart';
import 'pro_version_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // ── Support Email ─────────────────────
  static const String _supportEmail = 'vhirsupport@gmail.com';

  // ── State Variables ──────────────────
  bool _isProUser = false;
  bool _notificationsEnabled = true;
  String _themeMode = 'system';
  bool _sfxEnabled = true;
  bool _ttsEnabled = true;
  TimeOfDay _autoResetTime = const TimeOfDay(hour: 0, minute: 0);
  bool? _exactAlarmsAllowed;
  bool _checkingExactAlarms = false;

  // ── Cloud & Auto Backup ────────────────
  final GoogleDriveService _driveService = GoogleDriveService();
  final AuthService _authService = AuthService.instance;

  bool _autoBackupEnabled = true;
  String _autoBackupFrequency = 'every_change';
  bool _autoBackupWifiOnly = false;
  DateTime? _lastAutoBackupAt;
  bool _autoBackupBusy = false;

  // ── Psychology ────────────────────────
  bool _psychologyNudgesEnabled = true;

  // ── Leaderboard ───────────────────────
  late final ValueNotifier<bool> _leaderboardBusyVN;
  bool _leaderboardOptedIn = false;
  int _cachedRank = -1;

  // ── Animation ─────────────────────────
  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  // Theme mode metadata
  static const List<Map<String, dynamic>> _themeModes = [
    {
      'key': 'system',
      'label': 'Auto (System)',
      'subtitle': 'Follows your device setting',
      'icon': Icons.auto_awesome_rounded,
      'gradient': [Color(0xFF8B5CF6), Color(0xFF6C63FF)],
      'badge': 'DEFAULT',
    },
    {
      'key': 'dark',
      'label': 'Dark Mode',
      'subtitle': 'Easy on the eyes at night',
      'icon': Icons.dark_mode_rounded,
      'gradient': [Color(0xFF334155), Color(0xFF0F172A)],
      'badge': null,
    },
    {
      'key': 'light',
      'label': 'Light Mode',
      'subtitle': 'Clean and bright interface',
      'icon': Icons.light_mode_rounded,
      'gradient': [Color(0xFFF59E0B), Color(0xFFEAB308)],
      'badge': null,
    },
  ];

  // ════════════════════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _leaderboardBusyVN = ValueNotifier<bool>(false);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _bgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOut),
    );

    _authService.googleUserNotifier.addListener(_onAuthChanged);
    _authService.userNotifier.addListener(_onAuthChanged);

    _load();
    _loadExactAlarmStatusSilently();
    _loadLeaderboardLocalState();
  }

  @override
  void dispose() {
    _authService.googleUserNotifier.removeListener(_onAuthChanged);
    _authService.userNotifier.removeListener(_onAuthChanged);
    _leaderboardBusyVN.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _loadLeaderboardLocalState();
    setState(() {});
  }

  void _load() {
    setState(() {
      _isProUser = DatabaseService.isProOrVipUser();
      _notificationsEnabled = DatabaseService.areNotificationsEnabled();
      _themeMode = DatabaseService.getThemeMode();
      _sfxEnabled = DatabaseService.areSoundEffectsEnabled();
      _ttsEnabled = DatabaseService.isTtsEnabled();
      _autoResetTime = DatabaseService.getAutoResetTime();
      _autoBackupEnabled = DatabaseService.isAutoBackupEnabled();
      _autoBackupFrequency = DatabaseService.getAutoBackupFrequency();
      _autoBackupWifiOnly = DatabaseService.isAutoBackupWifiOnly();
      final lastAutoMs = DatabaseService.getLastAutoBackupTime();
      _lastAutoBackupAt = lastAutoMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastAutoMs)
          : null;
      _psychologyNudgesEnabled = DatabaseService.arePsychologyNudgesEnabled();
    });
  }

  void _loadLeaderboardLocalState() {
    try {
      final uid = _authService.uid;
      if (uid == null || uid.isEmpty) {
        _leaderboardOptedIn = false;
        _cachedRank = -1;
        return;
      }
      final p = DatabaseService.getLeaderboardProfileForUid(uid);
      _leaderboardOptedIn = p?.isOptedIn ?? false;
      _cachedRank = p?.cachedRank ?? -1;
    } catch (_) {
      _leaderboardOptedIn = false;
      _cachedRank = -1;
    }
  }

  Future<void> _loadExactAlarmStatusSilently() async {
    if (!Platform.isAndroid) return;
    setState(() => _checkingExactAlarms = true);
    try {
      final allowed = await NotificationService.canScheduleExactAlarms();
      if (mounted) setState(() => _exactAlarmsAllowed = allowed);
    } catch (_) {
      if (mounted) setState(() => _exactAlarmsAllowed = null);
    } finally {
      if (mounted) setState(() => _checkingExactAlarms = false);
    }
  }

  // ════════════════════════════════════════════════════════
  // 📧 SUPPORT EMAIL HANDLER
  // ════════════════════════════════════════════════════════

  Future<void> _openSupportEmail() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    final subject = Uri.encodeComponent(
        '${AppConfig.appName} Support — v${AppConfig.version}');
    final body = Uri.encodeComponent(
      'Hi ${AppConfig.appName} Team,\n\n'
          '[Please describe your issue or feedback here]\n\n'
          '────────────────────────────\n'
          'App Version: ${AppConfig.version}\n'
          'Platform: ${Platform.isAndroid ? "Android" : "iOS"}\n'
          '────────────────────────────',
    );

    final emailUri = Uri.parse(
      'mailto:$_supportEmail?subject=$subject&body=$body',
    );

    try {
      final canLaunch = await canLaunchUrl(emailUri);

      if (canLaunch) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) _showSupportEmailDialog();
      }
    } catch (e) {
      if (mounted) _showSupportEmailDialog();
    }
  }

  void _showSupportEmailDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.email_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Contact Support',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No email app found. Please email us at:',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.1),
                    const Color(0xFF2563EB).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email_rounded,
                      color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      _supportEmail,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                          const ClipboardData(text: _supportEmail));
                      if (mounted) {
                        Navigator.pop(context);
                        _showSnack('📋 Email copied to clipboard');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded,
                        size: 18, color: Color(0xFF3B82F6)),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.black54)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ★★★ THEME CHANGE ★★★
  // ════════════════════════════════════════════════════════

  Future<void> _changeTheme(String newThemeKey) async {
    if (newThemeKey == _themeMode) return;

    HapticFeedback.mediumImpact();
    SoundService.playSuccess();

    await DatabaseService.setThemeMode(newThemeKey);

    if (mounted) setState(() => _themeMode = newThemeKey);

    switch (newThemeKey) {
      case 'dark':
        themeNotifier.value = ThemeMode.dark;
        break;
      case 'light':
        themeNotifier.value = ThemeMode.light;
        break;
      case 'system':
      default:
        themeNotifier.value = ThemeMode.system;
        break;
    }

    _showSnack(_getThemeMessage(newThemeKey));
  }

  String _getThemeMessage(String key) {
    switch (key) {
      case 'dark':
        return '🌙 Dark Mode activated';
      case 'light':
        return '☀️ Light Mode activated';
      case 'system':
      default:
        return '✨ Auto Mode — follows your device';
    }
  }

  // ════════════════════════════════════════════════════════
  // UI HELPERS
  // ════════════════════════════════════════════════════════

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDark,
    double borderRadius = 24.0,
    EdgeInsets padding = const EdgeInsets.all(20),
    List<Color>? gradientColors,
    bool hasBorder = true,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: isDark
                  ? [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ]
                  : [
                Colors.white.withOpacity(0.85),
                Colors.white.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder
                ? Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.9),
              width: 1.5,
            )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTileGroup(List<Widget> tiles, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildGlassContainer(
        isDark: isDark,
        padding: EdgeInsets.zero,
        child: Column(
          children: tiles.asMap().entries.map((entry) {
            final idx = entry.key;
            final tile = entry.value;
            if (idx == tiles.length - 1) return tile;
            return Column(
              children: [
                tile,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    height: 1,
                    indent: 44,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _premiumTile({
    required IconData icon,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required bool isDark,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 20, 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppConfig.primaryColor),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppConfig.primaryColor.withOpacity(0.9),
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConfig.primaryColor.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // THEME SELECTOR WIDGET
  // ════════════════════════════════════════════════════════

  Widget _themeSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildGlassContainer(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6C63FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Choose your visual style',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._themeModes.map((mode) {
              final key = mode['key'] as String;
              final label = mode['label'] as String;
              final subtitle = mode['subtitle'] as String;
              final icon = mode['icon'] as IconData;
              final gradient = mode['gradient'] as List<Color>;
              final badge = mode['badge'] as String?;
              final isSelected = _themeMode == key;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _changeTheme(key),
                    borderRadius: BorderRadius.circular(18),
                    splashColor: gradient.first.withOpacity(0.1),
                    highlightColor: gradient.first.withOpacity(0.05),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? gradient.first.withOpacity(0.12)
                            : (isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.black.withOpacity(0.02)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? gradient.first.withOpacity(0.7)
                              : (isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.06)),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: gradient.first.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? gradient
                                    : [
                                  gradient.first.withOpacity(0.3),
                                  gradient.last.withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: gradient.first.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                                  : [],
                            ),
                            child: Icon(icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (badge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                          gradient.first.withOpacity(0.15),
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          border: Border.all(
                                            color:
                                            gradient.first.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          badge,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: gradient.first,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.elasticOut,
                                  ),
                                  child: child,
                                ),
                            child: isSelected
                                ? Container(
                              key: ValueKey('check_$key'),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: gradient),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                    gradient.first.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                                : Container(
                              key: ValueKey('circle_$key'),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.1),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _themeMode == 'system'
                          ? 'Auto mode follows your device\'s ${isDark ? "dark" : "light"} setting'
                          : _themeMode == 'dark'
                          ? 'Dark Mode is active — app restart not required'
                          : 'Light Mode is active — app restart not required',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // BACKUP FREQUENCY
  // ════════════════════════════════════════════════════════

  String _getFrequencyLabel(String key) {
    switch (key) {
      case 'on_exit':
        return 'On App Exit';
      case 'every_change':
        return 'After Every Change';
      case 'hourly':
        return 'Every Hour';
      case 'daily':
        return 'Once Daily';
      case 'weekly':
        return 'Once Weekly';
      default:
        return 'After Every Change';
    }
  }

  String _getFrequencyDescription(String key) {
    switch (key) {
      case 'on_exit':
        return 'Backs up when you close the app';
      case 'every_change':
        return '⭐ Recommended - Auto sync after every change';
      case 'hourly':
        return 'Automatic backup every 1 hour';
      case 'daily':
        return 'One backup per day';
      case 'weekly':
        return 'Saves data every 7 days';
      default:
        return '';
    }
  }

  IconData _getFrequencyIcon(String key) {
    switch (key) {
      case 'on_exit':
        return Icons.exit_to_app_rounded;
      case 'every_change':
        return Icons.sync_rounded;
      case 'hourly':
        return Icons.schedule_rounded;
      case 'daily':
        return Icons.today_rounded;
      case 'weekly':
        return Icons.date_range_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  Future<void> _showBackupFrequencyPickerSheet() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final frequencies = [
      'every_change',
      'on_exit',
      'hourly',
      'daily',
      'weekly',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                  const Color(0xFF151C2F).withOpacity(0.95),
                  const Color(0xFF0B1020).withOpacity(0.98),
                ]
                    : [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Backup Frequency',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'How often should we save your data?',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...frequencies.map(
                        (freq) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _frequencyOptionTile(ctx, freq, isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (selected != null && selected != _autoBackupFrequency) {
      await DatabaseService.setAutoBackupFrequency(selected);
      setState(() => _autoBackupFrequency = selected);
      SoundService.playSuccess();
      _showSnack('Backup frequency: ${_getFrequencyLabel(selected)}');
    }
  }

  Widget _frequencyOptionTile(BuildContext ctx, String value, bool isDark) {
    final isSelected = _autoBackupFrequency == value;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(ctx, value);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withOpacity(0.12)
              : (isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getFrequencyIcon(value),
              color: isSelected
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white70 : Colors.black54),
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getFrequencyLabel(value),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getFrequencyDescription(value),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // CARDS
  // ════════════════════════════════════════════════════════

  Widget _psychologyNudgesCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildGlassContainer(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6C63FF)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Motivation Engine',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'AI-driven psychological triggers',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _psychologyNudgesEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF8B5CF6),
                  onChanged: (val) async {
                    HapticFeedback.lightImpact();
                    SoundService.playTap();
                    await DatabaseService.setPsychologyNudgesEnabled(val);
                    setState(() => _psychologyNudgesEnabled = val);
                    if (!val) {
                      try {
                        await NotificationService.cancelAllReminders();
                        await NotificationService.rescheduleAllReminders();
                      } catch (_) {}
                    } else {
                      try {
                        await NotificationService
                            .scheduleEveningPsychologyNudges();
                      } catch (_) {}
                    }
                    _showSnack(val
                        ? 'Motivation nudges enabled.'
                        : 'Motivation nudges disabled.');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  _nudgeInfoRow(
                      isDark: isDark,
                      emoji: '⚡',
                      text: 'Urgency alerts when your streak is at risk'),
                  const SizedBox(height: 10),
                  _nudgeInfoRow(
                      isDark: isDark,
                      emoji: '🔥',
                      text: 'Loss aversion warnings about XP deductions'),
                  const SizedBox(height: 10),
                  _nudgeInfoRow(
                      isDark: isDark,
                      emoji: '🤷',
                      text:
                      'Reverse psychology to challenge your discipline'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nudgeInfoRow({
    required bool isDark,
    required String emoji,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _leaderboardCard(bool isDark) {
    final signedIn = _authService.currentUser != null;
    final rankText = _cachedRank > 0 ? '#$_cachedRank' : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildGlassContainer(
        isDark: isDark,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.leaderboard_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Leaderboard',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Your Global Rank',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700).withOpacity(0.2),
                        const Color(0xFFF59E0B).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.4)),
                  ),
                  child: Text(
                    rankText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: _leaderboardBusyVN,
              builder: (context, busy, _) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Public Visibility',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Opt-in to appear on rankings',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _leaderboardOptedIn,
                            activeColor: Colors.white,
                            activeTrackColor: AppConfig.primaryColor,
                            onChanged: (!signedIn || busy)
                                ? null
                                : (v) => _setLeaderboardOptIn(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (!signedIn || busy)
                                ? null
                                : _openLeaderboardProfile,
                            icon:
                            const Icon(Icons.person_rounded, size: 18),
                            label: const Text('Manage Profile'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (!signedIn || busy)
                                ? null
                                : _deleteLeaderboardCloudProfile,
                            icon: const Icon(
                                Icons.delete_forever_rounded,
                                size: 18),
                            label: const Text('Delete Cloud'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.errorColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!signedIn) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : _leaderboardSignIn,
                          icon: busy
                              ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.login_rounded),
                          label: const Text('Sign In to Manage',
                              style:
                              TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _autoBackupCard(bool isDark) {
    final isSignedIn = _authService.currentUser != null;
    final lastAutoStr = _lastAutoBackupAt != null
        ? _formatLocalTime(_lastAutoBackupAt)
        : 'Never';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildGlassContainer(
        isDark: isDark,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cloud_sync_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Auto Backup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Secure sync to Google Drive',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _autoBackupEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF10B981),
                  onChanged: (!isSignedIn || _autoBackupBusy)
                      ? null
                      : (val) async {
                    HapticFeedback.lightImpact();
                    SoundService.playTap();
                    await DatabaseService.setAutoBackupEnabled(val);
                    setState(() => _autoBackupEnabled = val);
                    _showSnack(val
                        ? 'Auto backup enabled'
                        : 'Auto backup disabled');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.black45),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Last Auto Backup: $lastAutoStr',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isSignedIn) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _autoBackupBusy ? null : _signInForAutoBackup,
                  icon: _autoBackupBusy
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.login_rounded),
                  label: const Text('Sign In to Enable Backup',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
            if (_autoBackupEnabled && isSignedIn) ...[
              const SizedBox(height: 20),
              InkWell(
                onTap: _showBackupFrequencyPickerSheet,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFrequencyIcon(_autoBackupFrequency),
                        size: 22,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup Frequency',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color:
                                isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getFrequencyLabel(_autoBackupFrequency),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.unfold_more_rounded,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wi-Fi Only',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _autoBackupWifiOnly
                              ? 'Backup only on Wi-Fi'
                              : 'Backup on Wi-Fi + Mobile Data',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _autoBackupWifiOnly,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) async {
                      HapticFeedback.lightImpact();
                      await DatabaseService.setAutoBackupWifiOnly(val);
                      setState(() => _autoBackupWifiOnly = val);
                      _showSnack(val
                          ? 'Backup restricted to Wi-Fi only'
                          : 'Backup on any connection');
                    },
                  ),
                ],
              ),
            ],
            if (isSignedIn) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _autoBackupBusy ? null : _signOutGoogle,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign Out'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppConfig.errorColor),
                  ),
                  TextButton.icon(
                    onPressed: _autoBackupBusy ? null : _disconnectGoogle,
                    icon: const Icon(Icons.link_off_rounded, size: 16),
                    label: const Text('Fix Sync'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppConfig.warningColor),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ACTION METHODS
  // ════════════════════════════════════════════════════════

  Future<void> _leaderboardSignIn() async {
    _leaderboardBusyVN.value = true;
    HapticFeedback.lightImpact();
    SoundService.playTap();
    try {
      final user =
      await _authService.ensureSignedInOnDemand(interactive: true);
      if (user == null) {
        _showSnack('Sign-in was cancelled.', isError: true);
        return;
      }
      _loadLeaderboardLocalState();
      if (mounted) setState(() {});
      _showSnack('Signed in successfully.');
    } catch (e) {
      if (mounted) _showSnack(_prettyError(e), isError: true);
    } finally {
      _leaderboardBusyVN.value = false;
    }
  }

  Future<void> _openLeaderboardProfile() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    try {
      final user =
      await _authService.ensureSignedInOnDemand(interactive: true);
      if (user == null) {
        _showSnack('Sign-in was cancelled.', isError: true);
        return;
      }
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const LeaderboardProfileScreen()),
      );
      if (mounted && result == true) {
        _loadLeaderboardLocalState();
        setState(() {});
      }
    } catch (e) {
      if (mounted) _showSnack(_prettyError(e), isError: true);
    }
  }

  Future<void> _setLeaderboardOptIn(bool optIn) async {
    _leaderboardBusyVN.value = true;
    HapticFeedback.lightImpact();
    SoundService.playTap();
    try {
      final user =
      await _authService.ensureSignedInOnDemand(interactive: true);
      if (user == null) {
        _showSnack('Sign-in was cancelled.', isError: true);
        return;
      }
      final existing =
      DatabaseService.getLeaderboardProfileForUid(user.uid);
      if (existing == null) {
        _showSnack('Create profile first.', isError: true);
        await _openLeaderboardProfile();
        return;
      }
      final updated = existing.copyWith(isOptedIn: optIn);
      await DatabaseService.saveLeaderboardProfile(updated);
      if (optIn) {
        try {
          await LeaderboardService.instance.syncMyProfileToCloud();
        } catch (_) {}
      } else {
        try {
          await LeaderboardService.instance
              .hideMyProfileFromLeaderboard();
        } catch (_) {}
      }
      _loadLeaderboardLocalState();
      if (mounted) setState(() {});
      _showSnack(
          optIn ? 'Leaderboard enabled' : 'Leaderboard disabled');
    } catch (e) {
      if (mounted) _showSnack(_prettyError(e), isError: true);
    } finally {
      _leaderboardBusyVN.value = false;
    }
  }

  Future<void> _deleteLeaderboardCloudProfile() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Cloud Profile?'),
        content: const Text('You will disappear from public ranking.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.errorColor),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _leaderboardBusyVN.value = true;
    try {
      await _authService.ensureSignedInOnDemand(interactive: true);
      await LeaderboardService.instance
          .deleteMyLeaderboardProfileFromCloud(
          alsoClearLocalProfile: true);
      _loadLeaderboardLocalState();
      if (mounted) setState(() {});
      SoundService.playSuccess();
      _showSnack('Cloud profile deleted.');
    } catch (e) {
      if (mounted) _showSnack(_prettyError(e), isError: true);
    } finally {
      _leaderboardBusyVN.value = false;
    }
  }

  Future<void> _exportRoutinePack() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    try {
      await RoutineShareService.exportRoutinePack(context,
          includeHabits: true, includeStudyRoutines: true);
    } catch (_) {
      if (mounted) _showSnack('Export failed.', isError: true);
    }
  }

  Future<void> _importRoutinePack() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Routine Pack?'),
        content: const Text('This adds habits/routines from a file.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RoutineShareService.importRoutinePack(context);
      if (DatabaseService.areNotificationsEnabled()) {
        await NotificationService.rescheduleAllReminders();
      }
    } catch (_) {
      if (mounted) _showSnack('Import failed.', isError: true);
    }
  }

  Future<void> _signInForAutoBackup() async {
    setState(() => _autoBackupBusy = true);
    try {
      final user =
      await _authService.ensureSignedInOnDemand(interactive: true);
      if (user == null) {
        _showSnack('Sign-in cancelled.', isError: true);
        return;
      }
      _showSnack('Signed in. Enable auto backup now.');
      setState(() {});
    } catch (e) {
      if (mounted) _showSnack(_prettyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _autoBackupBusy = false);
    }
  }

  Future<void> _signOutGoogle() async {
    setState(() => _autoBackupBusy = true);
    try {
      await _authService.signOut();
      if (mounted) {
        _showSnack('Signed out of Google Drive');
        setState(() => _autoBackupEnabled = false);
      }
    } catch (_) {
      if (mounted) _showSnack('Sign out failed.', isError: true);
    } finally {
      if (mounted) setState(() => _autoBackupBusy = false);
    }
  }

  Future<void> _disconnectGoogle() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect Google access?'),
        content: const Text('Use only to fix sync permission issues.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.warningColor),
            child: const Text('Disconnect',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _autoBackupBusy = true);
    try {
      await _authService.disconnect();
      if (mounted) {
        _showSnack('Disconnected.');
        setState(() => _autoBackupEnabled = false);
      }
    } catch (_) {
      if (mounted) _showSnack('Disconnect failed.', isError: true);
    } finally {
      if (mounted) setState(() => _autoBackupBusy = false);
    }
  }

  String? _formatLocalTime(DateTime? dt) {
    if (dt == null) return null;
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _prettyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Sign-in was cancelled') || msg.contains('cancelled')) {
      return 'Sign-in was cancelled.';
    }
    if (msg.contains('SocketException') || msg.contains('network')) {
      return 'No internet connection. Please try again.';
    }
    final cleaned = msg
        .replaceAll('AuthServiceException:', '')
        .replaceAll('CloudBackupException:', '')
        .replaceAll('LeaderboardServiceException:', '')
        .trim();
    return cleaned.isEmpty
        ? 'Something went wrong. Please try again.'
        : cleaned;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
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
        backgroundColor:
        isError ? AppConfig.errorColor : AppConfig.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 8,
      ),
    );
  }

  void _resetProgress() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text('Clear streaks. Habits will stay.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final habits = DatabaseService.getAllHabits();
              for (final h in habits) {
                h.completedDates.clear();
                h.currentStreak = 0;
                h.bestStreak = 0;
                h.dailyGoalProgress = 0;
                h.lastProgressDate = null;
                h.totalCompletions = 0;
                await DatabaseService.updateHabit(h);
              }
              _showSnack('Progress reset');
            },
            child: const Text('Reset',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _deleteAllHabits() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All Habits?'),
        content: const Text('This action cannot be undone!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final habits = DatabaseService.getAllHabits();
              for (final h in habits) {
                await DatabaseService.deleteHabit(h.id);
              }
              await NotificationService.cancelAllReminders();
              _showSnack('All habits deleted');
            },
            child: const Text('Delete All',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAutoResetTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: _autoResetTime);
    if (picked != null) {
      await DatabaseService.setAutoResetTime(picked);
      setState(() => _autoResetTime = picked);
      _showSnack('Daily reset time updated.');
    }
  }

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- COMMUNITY & SOCIAL LINKS ---
    final List<Widget> socialTiles = [];
    if (AppConfig.telegramUrl.isNotEmpty) {
      socialTiles.add(_premiumTile(
        icon: Icons.send_rounded,
        gradient: [const Color(0xFF0088cc), const Color(0xFF00aaff)],
        title: 'Telegram',
        subtitle: 'Join our community',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.telegramUrl, context),
      ));
    }
    if (AppConfig.youtubeUrl.isNotEmpty) {
      socialTiles.add(_premiumTile(
        icon: Icons.play_circle_fill_rounded,
        gradient: [const Color(0xFFFF0000), const Color(0xFFFF4D4D)],
        title: 'YouTube',
        subtitle: 'Watch our tutorials',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.youtubeUrl, context),
      ));
    }
    if (AppConfig.facebookUrl.isNotEmpty) {
      socialTiles.add(_premiumTile(
        icon: Icons.facebook_rounded,
        gradient: [const Color(0xFF1877F2), const Color(0xFF4267B2)],
        title: 'Facebook',
        subtitle: 'Follow our page',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.facebookUrl, context),
      ));
    }

    // --- SUPPORT US (Play Store Links) ---
    final List<Widget> playStoreTiles = [];
    if (AppConfig.playStoreRateUrl.isNotEmpty) {
      playStoreTiles.add(_premiumTile(
        icon: Icons.star_rounded,
        gradient: [const Color(0xFFFFD700), const Color(0xFFF59E0B)],
        title: 'Rate App',
        subtitle: 'Love the app? Rate us 5 stars!',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.playStoreRateUrl, context),
      ));
    }
    if (AppConfig.playStoreDeveloperUrl.isNotEmpty) {
      playStoreTiles.add(_premiumTile(
        icon: Icons.apps_rounded,
        gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
        title: 'More Apps',
        subtitle: 'Explore our other apps',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.playStoreDeveloperUrl, context),
      ));
    }

    // --- ABOUT & LEGAL LINKS ---
    final List<Widget> legalTiles = [];
    if (AppConfig.websiteUrl.isNotEmpty) {
      legalTiles.add(_premiumTile(
        icon: Icons.language_rounded,
        gradient: [Colors.teal, Colors.tealAccent],
        title: 'Website',
        subtitle: 'Visit our official website',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.websiteUrl, context),
      ));
    }
    if (AppConfig.privacyPolicyUrl.isNotEmpty) {
      legalTiles.add(_premiumTile(
        icon: Icons.privacy_tip_rounded,
        gradient: [Colors.grey.shade600, Colors.grey.shade800],
        title: 'Privacy Policy',
        subtitle: 'Read our data policy',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.privacyPolicyUrl, context),
      ));
    }
    if (AppConfig.termsUrl.isNotEmpty) {
      legalTiles.add(_premiumTile(
        icon: Icons.description_rounded,
        gradient: [Colors.grey.shade600, Colors.grey.shade800],
        title: 'Terms of Service',
        subtitle: 'App rules and guidelines',
        isDark: isDark,
        onTap: () => UrlService.openUrl(AppConfig.termsUrl, context),
      ));
    }
    // Version tile (always visible)
    legalTiles.add(_premiumTile(
      icon: Icons.code_rounded,
      gradient: [AppConfig.primaryColor, AppConfig.accentColor],
      title: 'Version ${AppConfig.version}',
      subtitle: 'Developed by ${AppConfig.developerName}',
      isDark: isDark,
    ));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
      isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.settings_rounded,
                size: 18,
                color: AppConfig.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Command Center',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 21,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
        IconThemeData(color: isDark ? Colors.white : Colors.black87),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: isDark
                  ? const Color(0xFF0B1020).withOpacity(0.6)
                  : Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (_, __) => Stack(
              children: [
                Positioned(
                  top: -60 + (25 * _bgAnimation.value),
                  right: -60 - (35 * _bgAnimation.value),
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppConfig.primaryColor
                              .withOpacity(isDark ? 0.06 : 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 120 - (20 * _bgAnimation.value),
                  left: -40 + (15 * _bgAnimation.value),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppConfig.accentColor
                              .withOpacity(isDark ? 0.04 : 0.02),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top +
                      kToolbarHeight +
                      10,
                  bottom: 60,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (!_isProUser && AppConfig.enableProVersion)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildGlassContainer(
                          isDark: isDark,
                          gradientColors: [
                            const Color(0xFFFFD700).withOpacity(0.9),
                            const Color(0xFFF59E0B).withOpacity(0.8),
                          ],
                          child: Row(
                            children: [
                              const Text('👑',
                                  style: TextStyle(fontSize: 32)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text('Unlock Pro',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900)),
                                    Text('Ad-free • Unlimited Limits',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.85),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const ProVersionScreen()),
                                ).then((_) => _load()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFF59E0B),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: const Text('Go Pro',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _sectionHeader('Appearance',
                        icon: Icons.palette_rounded),
                    _themeSelector(isDark),
                    _sectionHeader('Data & Cloud Sync',
                        icon: Icons.cloud_sync_rounded),
                    _autoBackupCard(isDark),
                    _sectionHeader('Motivation & Psychology',
                        icon: Icons.psychology_rounded),
                    _psychologyNudgesCard(isDark),
                    _sectionHeader('Ranking & Competition',
                        icon: Icons.emoji_events_rounded),
                    _leaderboardCard(isDark),
                    _sectionHeader('Preferences',
                        icon: Icons.tune_rounded),
                    _buildTileGroup([
                      _premiumTile(
                        icon: Icons.volume_up_rounded,
                        gradient: [Colors.deepOrange, Colors.orange],
                        title: 'Sound Effects',
                        subtitle: 'Haptics & UI Sounds',
                        isDark: isDark,
                        trailing: Switch.adaptive(
                          value: _sfxEnabled,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.deepOrange,
                          onChanged: (v) {
                            DatabaseService.setSoundEffectsEnabled(v);
                            SoundService.setSoundEnabled(v);
                            setState(() => _sfxEnabled = v);
                          },
                        ),
                      ),
                      _premiumTile(
                        icon: Icons.record_voice_over_rounded,
                        gradient: [Colors.blue, Colors.lightBlue],
                        title: 'Voice Alerts (TTS)',
                        subtitle: 'Spoken reminders',
                        isDark: isDark,
                        trailing: Switch.adaptive(
                          value: _ttsEnabled,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.blue,
                          onChanged: (v) {
                            DatabaseService.setTtsEnabled(v);
                            TtsService.setEnabled(v);
                            setState(() => _ttsEnabled = v);
                          },
                        ),
                      ),
                      _premiumTile(
                        icon: Icons.notifications_active_rounded,
                        gradient: [Colors.amber, Colors.orangeAccent],
                        title: 'Reminders',
                        subtitle: 'Daily habit push alerts',
                        isDark: isDark,
                        trailing: Switch.adaptive(
                          value: _notificationsEnabled,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.amber,
                          onChanged: (v) {
                            DatabaseService.setNotifications(v);
                            setState(() => _notificationsEnabled = v);
                          },
                        ),
                      ),
                      _premiumTile(
                        icon: Icons.update_rounded,
                        gradient: [Colors.teal, Colors.green],
                        title: 'Daily Reset Time',
                        subtitle: _autoResetTime.format(context),
                        isDark: isDark,
                        onTap: _pickAutoResetTime,
                      ),
                    ], isDark),
                    _sectionHeader('Routine Sharing',
                        icon: Icons.share_rounded),
                    _buildTileGroup([
                      _premiumTile(
                        icon: Icons.upload_file_rounded,
                        gradient: [
                          const Color(0xFF6C63FF),
                          const Color(0xFF4338CA),
                        ],
                        title: 'Export Routine Pack',
                        subtitle: 'Share your habits with others',
                        isDark: isDark,
                        onTap: _exportRoutinePack,
                      ),
                      _premiumTile(
                        icon: Icons.download_rounded,
                        gradient: [
                          const Color(0xFF10B981),
                          const Color(0xFF059669),
                        ],
                        title: 'Import Routine Pack',
                        subtitle: 'Load habits from a file',
                        isDark: isDark,
                        onTap: _importRoutinePack,
                      ),
                    ], isDark),

                    // ═══════════════════════════════════════
                    // COMMUNITY & SOCIAL LINKS (Conditional)
                    // ═══════════════════════════════════════
                    if (socialTiles.isNotEmpty) ...[
                      _sectionHeader('Community & Social',
                          icon: Icons.public_rounded),
                      _buildTileGroup(socialTiles, isDark),
                    ],

                    // ═══════════════════════════════════════
                    // SUPPORT US / MORE APPS (Conditional)
                    // ═══════════════════════════════════════
                    if (playStoreTiles.isNotEmpty) ...[
                      _sectionHeader('Support Us',
                          icon: Icons.favorite_rounded),
                      _buildTileGroup(playStoreTiles, isDark),
                    ],

                    // ═══════════════════════════════════════
                    // HELP & SUPPORT
                    // ═══════════════════════════════════════
                    _sectionHeader('Help & Support',
                        icon: Icons.support_agent_rounded),
                    _buildTileGroup([
                      _premiumTile(
                        icon: Icons.email_rounded,
                        gradient: [
                          const Color(0xFF3B82F6),
                          const Color(0xFF2563EB),
                        ],
                        title: 'Contact Support',
                        subtitle: _supportEmail,
                        isDark: isDark,
                        onTap: _openSupportEmail,
                      ),
                      _premiumTile(
                        icon: Icons.bug_report_rounded,
                        gradient: [
                          const Color(0xFFEF4444),
                          const Color(0xFFDC2626),
                        ],
                        title: 'Report a Bug',
                        subtitle: 'Help us improve the app',
                        isDark: isDark,
                        onTap: _openSupportEmail,
                      ),
                      _premiumTile(
                        icon: Icons.lightbulb_rounded,
                        gradient: [
                          const Color(0xFFF59E0B),
                          const Color(0xFFD97706),
                        ],
                        title: 'Feature Request',
                        subtitle: 'Suggest new features',
                        isDark: isDark,
                        onTap: _openSupportEmail,
                      ),
                    ], isDark),

                    // ═══════════════════════════════════════
                    // DANGER ZONE
                    // ═══════════════════════════════════════
                    _sectionHeader('Danger Zone',
                        icon: Icons.warning_rounded),
                    _buildTileGroup([
                      _premiumTile(
                        icon: Icons.restart_alt_rounded,
                        gradient: [Colors.orange, Colors.deepOrange],
                        title: 'Reset Progress',
                        subtitle: 'Clear streaks, keep habits',
                        isDark: isDark,
                        onTap: _resetProgress,
                      ),
                      _premiumTile(
                        icon: Icons.delete_forever_rounded,
                        gradient: [Colors.redAccent, Colors.red],
                        title: 'Delete All Habits',
                        subtitle: 'Permanent action',
                        isDark: isDark,
                        onTap: _deleteAllHabits,
                      ),
                    ], isDark),

                    // ═══════════════════════════════════════
                    // ABOUT & LEGAL (Conditional)
                    // ═══════════════════════════════════════
                    if (legalTiles.isNotEmpty) ...[
                      _sectionHeader('About & Legal',
                          icon: Icons.info_rounded),
                      _buildTileGroup(legalTiles, isDark),
                    ],

                    const SizedBox(height: 30),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}