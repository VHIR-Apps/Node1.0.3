// lib/screens/leaderboard_profile_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/leaderboard_profile_model.dart';
import '../services/auth_service.dart';
import '../services/auto_backup_trigger.dart';
import '../services/database_service.dart';
import '../services/leaderboard_service.dart';
import '../services/leaderboard_moderation_service.dart';
import '../services/profile_like_service.dart';
import '../services/profile_service.dart';
import '../services/sound_service.dart';

class LeaderboardProfileScreen extends StatefulWidget {
  const LeaderboardProfileScreen({super.key});

  @override
  State<LeaderboardProfileScreen> createState() =>
      _LeaderboardProfileScreenState();
}

class _LeaderboardProfileScreenState extends State<LeaderboardProfileScreen>
    with TickerProviderStateMixin {
  bool _isEditMode = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _taglineC = TextEditingController();
  final TextEditingController _bioC = TextEditingController();
  final TextEditingController _countryC = TextEditingController();
  final TextEditingController _postC = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  bool _optedIn = true;
  bool _showLevel = true;
  bool _showBadges = true;
  bool _showStudyHours = true;

  String _emoji = '🙂';
  int _avatarIndex = 0;
  int _joinedAtMs = 0;
  bool _isInterviewUser = false;
  int _profileThemeIndex = 0;

  String? _uid;
  LeaderboardProfileModel? _existing;

  late AnimationController _bgAnimController;
  late AnimationController _modeAnimController;
  late Animation<double> _modeAnim;

  static const int _maxPostWords = 500;
  static const int _maxPostChars = 3000;
  bool _isAdjustingPostText = false;

  static const List<String> _emojiOptions = [
    '🙂',
    '😄',
    '😎',
    '🤓',
    '🧠',
    '🔥',
    '⭐',
    '🏆',
    '👑',
    '💎',
    '🚀',
    '🌙',
    '☀️',
    '🌿',
    '🌸',
    '🎯',
  ];

  static const List<_AvatarOption> _avatarOptions = [
    _AvatarOption(
      emoji: '🧠',
      title: 'Mind',
      colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
    ),
    _AvatarOption(
      emoji: '🔥',
      title: 'Blaze',
      colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
    ),
    _AvatarOption(
      emoji: '🎯',
      title: 'Focus',
      colors: [Color(0xFF00C853), Color(0xFF10B981)],
    ),
    _AvatarOption(
      emoji: '🌙',
      title: 'Night',
      colors: [Color(0xFF6366F1), Color(0xFF111827)],
    ),
    _AvatarOption(
      emoji: '☀️',
      title: 'Day',
      colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
    ),
    _AvatarOption(
      emoji: '🚀',
      title: 'Rocket',
      colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    ),
    _AvatarOption(
      emoji: '🌿',
      title: 'Calm',
      colors: [Color(0xFF10B981), Color(0xFF34D399)],
    ),
    _AvatarOption(
      emoji: '💎',
      title: 'Gem',
      colors: [Color(0xFF8B5CF6), Color(0xFF6C63FF)],
    ),
    _AvatarOption(
      emoji: '🏆',
      title: 'Winner',
      colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
    ),
    _AvatarOption(
      emoji: '📚',
      title: 'Study',
      colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    ),
    _AvatarOption(
      emoji: '⚡',
      title: 'Spark',
      colors: [Color(0xFFFFB300), Color(0xFFFF6B6B)],
    ),
    _AvatarOption(
      emoji: '🛡️',
      title: 'Shield',
      colors: [Color(0xFF6B7280), Color(0xFF111827)],
    ),
    _AvatarOption(
      emoji: '🎵',
      title: 'Rhythm',
      colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    ),
    _AvatarOption(
      emoji: '🌸',
      title: 'Bloom',
      colors: [Color(0xFFFF6B6B), Color(0xFFFB7185)],
    ),
    _AvatarOption(
      emoji: '🧩',
      title: 'Puzzle',
      colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
    ),
    _AvatarOption(
      emoji: '🧘',
      title: 'Zen',
      colors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _modeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _modeAnim = CurvedAnimation(
      parent: _modeAnimController,
      curve: Curves.easeOutCubic,
    );

    _bootstrap();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _taglineC.dispose();
    _bioC.dispose();
    _countryC.dispose();
    _postC.dispose();
    _bgAnimController.dispose();
    _modeAnimController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance
          .ensureSignedInOnDemand(interactive: true);
      if (!mounted) return;

      if (user == null) {
        await _showErrorDialog(
          title: 'Sign-in Required',
          message: 'Sign-in was cancelled.',
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      _uid = user.uid;
      final local = DatabaseService.getLeaderboardProfileForUid(user.uid);
      _existing = local;

      if (local != null) {
        _populateFromProfile(local);
      } else {
        final suggested = (user.displayName ?? '').trim();
        if (suggested.isNotEmpty) {
          _nameC.text = LeaderboardProfileModel.safeDisplayName(suggested);
        }
        _avatarIndex = 0;
        _emoji = _avatarOptions[0].emoji;
        _joinedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;

        if (suggested.isNotEmpty) {
          await DatabaseService.setUserName(
            LeaderboardProfileModel.safeDisplayName(suggested),
          );
        }
        await DatabaseService.setUserAvatar(_avatarOptions[0].emoji);

        _isEditMode = true;
        _modeAnimController.forward();
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        title: 'Error',
        message: _prettyError(e),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateFromProfile(LeaderboardProfileModel p) {
    _nameC.text = p.displayName;
    _taglineC.text = p.tagline ?? '';
    _bioC.text = p.bio ?? '';
    _countryC.text = p.countryCode ?? '';
    _optedIn = p.isOptedIn;
    _showLevel = p.showLevel;
    _showBadges = p.showBadges;
    _showStudyHours = p.showStudyHours;
    _emoji = p.avatarEmoji.trim().isEmpty ? '🙂' : p.avatarEmoji;
    _avatarIndex = p.avatarIndex < 0 ? 0 : p.avatarIndex;
    _joinedAtMs = p.joinedAtMs;
    _isInterviewUser = p.isInterviewUser;
    _profileThemeIndex = p.profileThemeIndex;
  }

  void _enterEditMode() {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    setState(() => _isEditMode = true);
    _modeAnimController.forward(from: 0);
  }

  void _exitEditMode() {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    FocusScope.of(context).unfocus();
    if (_existing != null) {
      _populateFromProfile(_existing!);
    }
    setState(() => _isEditMode = false);
    _modeAnimController.reverse();
  }

  String _prettyError(Object e) {
    if (e is AuthServiceException) {
      return e.message.trim().isEmpty ? 'Sign-in failed.' : e.message;
    }
    final msg = e.toString();
    if (msg.contains('cancelled')) return 'Sign-in was cancelled.';
    if (msg.contains('network-request-failed') ||
        msg.contains('SocketException')) {
      return 'No internet connection.';
    }
    return msg
        .replaceAll('AuthServiceException:', '')
        .replaceAll('LeaderboardServiceException:', '')
        .trim();
  }

  _AvatarOption _safeAvatar(int index) {
    if (_avatarOptions.isEmpty) {
      return const _AvatarOption(
        emoji: '🙂',
        title: 'Default',
        colors: [AppConfig.primaryColor, AppConfig.infoColor],
      );
    }
    return _avatarOptions[index.clamp(0, _avatarOptions.length - 1)];
  }

  String _memberForText(int joinedAtMs) {
    if (joinedAtMs <= 0) return 'Member';
    final joined =
    DateTime.fromMillisecondsSinceEpoch(joinedAtMs, isUtc: true).toLocal();
    final diffDays = DateTime.now().difference(joined).inDays;
    if (diffDays < 0) return 'Member';
    final years = diffDays ~/ 365;
    final months = (diffDays % 365) ~/ 30;
    final days = (diffDays % 365) % 30;
    if (years > 0) {
      return months > 0
          ? 'Member for $years yr $months mo'
          : 'Member for $years yr';
    }
    if (months > 0) {
      return days > 0 ? 'Member for $months mo $days d' : 'Member for $months mo';
    }
    return days > 0 ? 'Member for $days d' : 'Just joined';
  }

  String _normalizeCountry(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final only = v.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    return only.length <= 2 ? only : only.substring(0, 2);
  }

  String _formatStudyTime(int totalMinutes) {
    if (totalMinutes <= 0) return '0 min';
    if (totalMinutes < 60) return '$totalMinutes min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  int _wordCount(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  String _trimToMaxWords(String text, int maxWords) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final words = t.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return text;
    return words.take(maxWords).join(' ');
  }

  void _handlePostChanged(String value) {
    if (_isAdjustingPostText) return;
    final words = _wordCount(value);
    if (words > _maxPostWords) {
      final trimmed = _trimToMaxWords(value, _maxPostWords);
      _isAdjustingPostText = true;
      _postC.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
      _isAdjustingPostText = false;
      _showSnack(
        'Maximum $_maxPostWords words allowed.',
        isError: true,
      );
    }
    if (mounted) setState(() {});
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isError
                      ? [
                    AppConfig.errorColor.withOpacity(0.9),
                    Colors.redAccent.withOpacity(0.8),
                  ]
                      : [
                    AppConfig.primaryColor.withOpacity(0.95),
                    const Color(0xFF3B82F6).withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: _buildGlass(
          isDark: isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppConfig.errorColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color:
                (isDark ? const Color(0xFF151C2F) : Colors.white).withOpacity(0.9),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Choose Avatar',
                          style: TextStyle(
                            fontSize: 22,
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
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: _avatarOptions.length,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (_, i) {
                        final opt = _avatarOptions[i];
                        final isSel = i == _avatarIndex;
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  opt.colors[0].withOpacity(isDark ? 0.6 : 0.4),
                                  opt.colors[1].withOpacity(isDark ? 0.3 : 0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSel
                                    ? AppConfig.primaryColor
                                    : Colors.transparent,
                                width: isSel ? 2.5 : 0,
                              ),
                              boxShadow: [
                                if (isSel)
                                  BoxShadow(
                                    color: AppConfig.primaryColor.withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                opt.emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final e = await _pickEmoji(ctx);
                          if (ctx.mounted && e != null) {
                            Navigator.pop(ctx, null);
                            if (mounted) {
                              setState(() => _emoji = e);
                            }
                          }
                        },
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        label: const Text(
                          'Custom Emoji',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _avatarIndex = selected;
      _emoji = _safeAvatar(selected).emoji;
    });
  }

  Future<String?> _pickEmoji(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (c) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color:
              (isDark ? const Color(0xFF151C2F) : Colors.white).withOpacity(0.95),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'More Emojis',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(c),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: _emojiOptions.length,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (_, i) {
                      final e = _emojiOptions[i];
                      final isSel = e == _emoji;
                      return InkWell(
                        onTap: () => Navigator.pop(c, e),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppConfig.primaryColor.withOpacity(0.2)
                                : (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                              isSel ? AppConfig.primaryColor : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sharePost() async {
    final text = _postC.text.trim();
    if (text.isEmpty || _uid == null) return;

    final words = _wordCount(text);
    if (words > _maxPostWords) {
      _showSnack(
        'Maximum $_maxPostWords words allowed!',
        isError: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    SoundService.playTap();
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final double myXp = _existing?.cachedScore ?? 0.0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await FirebaseFirestore.instance.collection('leaderboard_v1_posts').add({
        'authorUid': _uid,
        'authorName': _nameC.text.trim(),
        'authorAvatar': _emoji.isEmpty ? '🙂' : _emoji,
        'authorXp': myXp,
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
        'clientTimestampMs': nowMs,
        'likeCount': 0,
        'dislikeCount': 0,
        'reportCount': 0,
      });

      await DatabaseService.addSocialPost(text);

      _postC.clear();
      _showSnack('Update posted! 🚀');
    } catch (e) {
      _showSnack('Failed to post: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    SoundService.playTap();
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return _showSnack('Sign-in required.', isError: true);
    }

    final displayName = LeaderboardProfileModel.safeDisplayName(_nameC.text);

    final tagline = _taglineC.text.trim();
    final bio = _bioC.text.trim();
    final country = _normalizeCountry(_countryC.text);
    final safeEmoji = LeaderboardProfileModel.safeEmoji(_emoji);

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final base = _existing ??
          LeaderboardProfileModel.create(
            uid: uid,
            displayName: displayName,
            joinedAtMs:
            _joinedAtMs > 0 ? _joinedAtMs : now.toUtc().millisecondsSinceEpoch,
            avatarIndex: _avatarIndex,
            avatarEmoji: safeEmoji,
            isOptedIn: _optedIn,
            showLevel: _showLevel,
            showBadges: _showBadges,
            showStudyHours: _showStudyHours,
            isInterviewUser: _isInterviewUser,
            profileThemeIndex: _profileThemeIndex,
          );

      final finalProfile = base.copyWith(
        displayName: displayName,
        tagline: tagline,
        bio: bio,
        countryCode: country,
        isOptedIn: _optedIn,
        showLevel: _showLevel,
        showBadges: _showBadges,
        showStudyHours: _showStudyHours,
        avatarEmoji: safeEmoji,
        avatarIndex: _avatarIndex,
        joinedAtMs: _joinedAtMs > 0 ? _joinedAtMs : base.joinedAtMs,
        isInterviewUser: _isInterviewUser,
        profileThemeIndex: _profileThemeIndex,
        cachedRank: _existing?.cachedRank ?? -1,
        cachedScore: _existing?.cachedScore ?? 0.0,
        lastCloudSyncAt: _existing?.lastCloudSyncAt,
      );

      _joinedAtMs = finalProfile.joinedAtMs;

      await DatabaseService.saveLeaderboardProfile(finalProfile);
      _existing = finalProfile;

      await DatabaseService.setUserName(displayName);
      await DatabaseService.setUserAvatar(safeEmoji);

      debugPrint(
        '✅ Profile saved: name="$displayName", '
            'tagline="${finalProfile.tagline}", '
            'bio="${finalProfile.bio}", '
            'country="${finalProfile.countryCode}", '
            'avatar="$safeEmoji"',
      );

      AutoBackupTrigger.notifyChange('profile_updated');

      if (finalProfile.isOptedIn) {
        try {
          await LeaderboardService.instance.syncMyProfileToCloud();
        } catch (_) {}
      } else {
        try {
          await LeaderboardService.instance.hideMyProfileFromLeaderboard();
        } catch (_) {
          _showSnack(
            'Saved locally. Cloud update needs internet.',
            isError: true,
          );
        }
      }

      SoundService.playSuccess();
      _showSnack(
        finalProfile.isOptedIn
            ? 'Profile saved! 🚀'
            : 'Profile saved. Leaderboard turned off.',
      );

      setState(() => _isEditMode = false);
      _modeAnimController.reverse();
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        title: 'Save Failed',
        message: _prettyError(e),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCloudProfile() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: _buildGlass(
          isDark: isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_forever_rounded,
                color: AppConfig.errorColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Cloud Profile?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This permanently deletes your public profile and leaderboard rank.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.errorColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w900),
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

    if (ok != true) return;
    HapticFeedback.heavyImpact();
    SoundService.playTap();
    setState(() => _saving = true);
    try {
      await LeaderboardService.instance.deleteMyLeaderboardProfileFromCloud(
        alsoClearLocalProfile: true,
      );
      if (!mounted) return;
      SoundService.playSuccess();
      _showSnack('Cloud profile deleted.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        title: 'Delete Failed',
        message: _prettyError(e),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showWhoLikedSheet(bool isDark) async {
    if (_uid == null) return;

    HapticFeedback.lightImpact();
    SoundService.playTap();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF151C2F) : Colors.white)
                        .withOpacity(0.96),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFFF4D6D),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Who Liked My Profile',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      Expanded(
                        child: StreamBuilder<List<LikerInfo>>(
                          stream: ProfileLikeService.instance
                              .whoLikedStream(targetUid: _uid!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppConfig.primaryColor,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Failed to load likes.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }

                            final likers = snapshot.data ?? [];
                            if (likers.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '💔',
                                      style: TextStyle(fontSize: 56),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No likes yet',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                              itemCount: likers.length,
                              itemBuilder: (context, index) {
                                return _MyProfileLikerTile(
                                  liker: likers[index],
                                  isDark: isDark,
                                  formatTime: _formatRelativeTime,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGlass({
    required Widget child,
    required bool isDark,
    double borderRadius = 24.0,
    EdgeInsets padding = const EdgeInsets.all(20),
    List<Color>? gradientColors,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
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
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.02),
              ]
                  : [
                Colors.white.withOpacity(0.92),
                Colors.white.withOpacity(0.65),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint, bool isDark) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      labelStyle: TextStyle(
        color: isDark ? Colors.white54 : Colors.black54,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.white24 : Colors.black26,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppConfig.primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppConfig.errorColor,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppConfig.errorColor,
          width: 2,
        ),
      ),
    );
  }

  Widget _privacyToggle({
    required bool isDark,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              activeColor: AppConfig.primaryColor,
              value: value,
              onChanged: onChanged != null
                  ? (v) {
                HapticFeedback.lightImpact();
                SoundService.playTap();
                onChanged(v);
              }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColors = isDark
        ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
        : [const Color(0xFFF1F5F9), const Color(0xFFE0E7FF)];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bgColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              final t = _bgAnimController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: -50 + (40 * math.sin(t)),
                    left: -100 + (50 * math.cos(t)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Container(
                        width: 380,
                        height: 380,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6C63FF)
                              .withOpacity(isDark ? 0.14 : 0.07),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80 + (50 * math.cos(t * 0.8)),
                    right: -50 + (40 * math.sin(t * 1.2)),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConfig.primaryColor
                              .withOpacity(isDark ? 0.14 : 0.07),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                color: AppConfig.primaryColor,
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isEditMode ? _buildEditView(isDark) : _buildViewMode(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildViewMode(bool isDark) {
    final profile = _existing;
    final avatar = _safeAvatar(_avatarIndex);
    final stats = ProfileService.getProfileStats();
    final level = stats['level'] as int? ?? 0;
    final xp = stats['xp'] as int? ?? 0;
    final badges = stats['badges'] as int? ?? 0;
    final totalBadges = stats['totalBadges'] as int? ?? 0;
    final progress = stats['progress'] as double? ?? 0.0;
    final levelTitle = stats['levelTitle'] as String? ?? '—';
    final bestStreak = stats['bestStreak'] as int? ?? 0;
    final totalCompleted = stats['totalCompleted'] as int? ?? 0;
    final studyMins = DatabaseService.getTotalStudyMinutesAllTime();
    final studyToday = DatabaseService.getTotalStudyMinutesToday();
    final studyWeek = DatabaseService.getTotalStudyMinutesThisWeek();
    final cachedRank = profile?.cachedRank ?? -1;
    final cachedScore = profile?.cachedScore ?? 0.0;

    return CustomScrollView(
      key: const ValueKey('view_mode'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 0,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: _buildGlass(
                isDark: isDark,
                padding: EdgeInsets.zero,
                borderRadius: 16,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 20,
                ),
              ),
            ),
          ),
          title: Text(
            'My Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
              child: GestureDetector(
                onTap: _enterEditMode,
                child: _buildGlass(
                  isDark: isDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  borderRadius: 14,
                  gradientColors: [
                    AppConfig.primaryColor.withOpacity(0.9),
                    AppConfig.primaryColor.withOpacity(0.7),
                  ],
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                color: isDark
                    ? const Color(0xFF0B1020).withOpacity(0.55)
                    : Colors.white.withOpacity(0.55),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: Column(
                children: [
                  _buildGlass(
                    isDark: isDark,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _bgAnimController,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              0,
                              6 * math.sin(_bgAnimController.value * 2 * math.pi),
                            ),
                            child: child,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      avatar.colors[0],
                                      avatar.colors[1].withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: avatar.colors[0]
                                          .withOpacity(isDark ? 0.5 : 0.3),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _emoji.trim().isEmpty ? avatar.emoji : _emoji,
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                ),
                              ),
                              if (DatabaseService.isProOrVipUser())
                                Positioned(
                                  bottom: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFF59E0B),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF0B1020)
                                            : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          profile?.displayName ?? 'HabitNode User',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if ((profile?.tagline ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            profile!.tagline!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppConfig.primaryColor.withOpacity(0.2),
                                AppConfig.accentColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppConfig.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            levelTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _memberForText(_joinedAtMs),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: profile?.isOptedIn == true
                                    ? AppConfig.successColor
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              profile?.isOptedIn == true
                                  ? 'Visible on Leaderboard'
                                  : 'Hidden from Leaderboard',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: profile?.isOptedIn == true
                                    ? AppConfig.successColor
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if ((profile?.bio ?? '').isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              profile!.bio!,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildGlass(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: AppConfig.primaryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'XP & Level',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Lv $level',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.07),
                            valueColor: const AlwaysStoppedAnimation(
                              AppConfig.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$xp XP',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                            Text(
                              'Next level: ${stats['xpNext']} XP',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildGlass(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConfig.accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.bar_chart_rounded,
                                color: AppConfig.accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'My Stats',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.7,
                          children: [
                            _ViewStatBox(
                              isDark: isDark,
                              icon: Icons.timer_rounded,
                              label: 'Today',
                              value: _formatStudyTime(studyToday),
                              color: const Color(0xFF00C853),
                            ),
                            _ViewStatBox(
                              isDark: isDark,
                              icon: Icons.date_range_rounded,
                              label: 'This Week',
                              value: _formatStudyTime(studyWeek),
                              color: const Color(0xFF3B82F6),
                            ),
                            _ViewStatBox(
                              isDark: isDark,
                              icon: Icons.school_rounded,
                              label: 'Total Study',
                              value: _formatStudyTime(studyMins),
                              color: AppConfig.primaryColor,
                            ),
                            _ViewStatBox(
                              isDark: isDark,
                              icon: Icons.local_fire_department_rounded,
                              label: 'Best Streak',
                              value: '$bestStreak days',
                              color: const Color(0xFFFF6B6B),
                            ),
                            _ViewStatBox(
                              isDark: isDark,
                              icon: Icons.check_circle_rounded,
                              label: 'Completed',
                              value: '$totalCompleted habits',
                              color: AppConfig.successColor,
                            ),
                            _ViewStatBox(
                              isDark: isDark,
                              icon: Icons.workspace_premium_rounded,
                              label: 'Badges',
                              value: '$badges / $totalBadges',
                              color: const Color(0xFFFFD700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (cachedRank > 0 || cachedScore > 0)
                    _buildGlass(
                      isDark: isDark,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFFFFD700),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Leaderboard Rank',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cachedRank > 0
                                      ? '#$cachedRank of all players'
                                      : 'Unranked',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            cachedScore > 0
                                ? '${cachedScore.toStringAsFixed(0)} XP'
                                : '—',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (cachedRank > 0 || cachedScore > 0) const SizedBox(height: 18),

                  if (_uid != null)
                    StreamBuilder<int>(
                      stream: ProfileLikeService.instance.likeCountStream(targetUid: _uid!),
                      builder: (context, snap) {
                        final likeCount = snap.data ?? 0;
                        return Column(
                          children: [
                            _buildGlass(
                              isDark: isDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color:
                                          const Color(0xFFFF4D6D).withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.favorite_rounded,
                                          color: Color(0xFFFF4D6D),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Profile Likes',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$likeCount',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFFF4D6D),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    likeCount > 0
                                        ? 'People are loving your profile. Tap below to see who liked you.'
                                        : 'No likes yet. Keep growing your profile!',
                                    style: TextStyle(
                                      fontSize: 12.8,
                                      height: 1.4,
                                      color:
                                      isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: likeCount > 0
                                          ? () => _showWhoLikedSheet(isDark)
                                          : null,
                                      icon: const Icon(
                                        Icons.people_alt_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        likeCount > 0
                                            ? 'See Who Liked'
                                            : 'No Likes Yet',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        );
                      },
                    ),

                  _buildGlass(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: AppConfig.primaryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Share Update',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _postC,
                          maxLines: 6,
                          maxLength: _maxPostChars,
                          onChanged: _handlePostChanged,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                          decoration: _inputDeco(
                            '',
                            "What's on your mind? (max 500 words)",
                            isDark,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${_wordCount(_postC.text)} / $_maxPostWords words',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _wordCount(_postC.text) > _maxPostWords
                                    ? AppConfig.errorColor
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _saving ? null : _sharePost,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppConfig.primaryColor,
                                    Color(0xFF3B82F6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppConfig.primaryColor.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Post',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_uid != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('leaderboard_v1_posts')
                          .where('authorUid', isEqualTo: _uid)
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return _buildGlass(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    color: AppConfig.accentColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'My Posts',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...snap.data!.docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final text = data['content'] as String? ?? '';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.04)
                                        : Colors.black.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.06)
                                          : Colors.black.withOpacity(0.04),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.4,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.85)
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
                                        onPressed: () async {
                                          HapticFeedback.mediumImpact();
                                          await doc.reference.delete();
                                          _showSnack('Post deleted.');
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 18),

                  if (_existing != null)
                    TextButton.icon(
                      onPressed: _saving ? null : _deleteCloudProfile,
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppConfig.errorColor,
                      ),
                      label: const Text(
                        'Delete Cloud Profile',
                        style: TextStyle(
                          color: AppConfig.errorColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildEditView(bool isDark) {
    final avatar = _safeAvatar(_avatarIndex);

    return CustomScrollView(
      key: const ValueKey('edit_mode'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 0,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: _existing != null ? _exitEditMode : () => Navigator.pop(context),
              child: _buildGlass(
                isDark: isDark,
                padding: EdgeInsets.zero,
                borderRadius: 16,
                child: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ),
          title: Text(
            _existing != null ? 'Edit Profile' : 'Create Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                      const Color(0xFF0B1020).withOpacity(0.7),
                      const Color(0xFF1E1B4B).withOpacity(0.5),
                    ]
                        : [
                      Colors.white.withOpacity(0.7),
                      const Color(0xFFF8FAFC).withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 50),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildGlass(
                      isDark: isDark,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _bgAnimController,
                                builder: (context, child) {
                                  return Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        colors: [
                                          avatar.colors[0].withOpacity(0.3),
                                          avatar.colors[1].withOpacity(0.6),
                                          avatar.colors[0].withOpacity(0.3),
                                        ],
                                        transform: GradientRotation(
                                          _bgAnimController.value * 2 * math.pi,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              GestureDetector(
                                onTap: _saving ? null : _pickAvatar,
                                child: Container(
                                  width: 116,
                                  height: 116,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        avatar.colors[0],
                                        avatar.colors[1],
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: avatar.colors[0].withOpacity(0.5),
                                        blurRadius: 32,
                                        offset: const Offset(0, 12),
                                      ),
                                      BoxShadow(
                                        color: avatar.colors[1].withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _emoji.trim().isEmpty ? avatar.emoji : _emoji,
                                      style: const TextStyle(fontSize: 52),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _saving ? null : _pickAvatar,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppConfig.primaryColor,
                                          Color(0xFF3B82F6),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF0B1020)
                                            : Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppConfig.primaryColor.withOpacity(0.5),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppConfig.primaryColor.withOpacity(0.15),
                                  AppConfig.accentColor.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppConfig.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tap avatar to customize',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGlass(
                      isDark: isDark,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppConfig.primaryColor.withOpacity(0.2),
                                      AppConfig.primaryColor.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppConfig.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Profile Details',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'How others see you',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Display Name *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameC,
                                textInputAction: TextInputAction.next,
                                maxLength: 24,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                decoration: _inputDeco(
                                  '',
                                  'Your display name',
                                  isDark,
                                ).copyWith(
                                  prefixIcon: Icon(
                                    Icons.badge_rounded,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'Name required';
                                  if (s.length < 2) return 'Too short';
                                  return null;
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tagline',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _taglineC,
                                textInputAction: TextInputAction.next,
                                maxLength: 64,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: _inputDeco(
                                  '',
                                  'What drives you?',
                                  isDark,
                                ).copyWith(
                                  prefixIcon: Icon(
                                    Icons.stars_rounded,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bio',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _bioC,
                                textInputAction: TextInputAction.newline,
                                maxLength: 220,
                                maxLines: 4,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.5,
                                ),
                                decoration: _inputDeco(
                                  '',
                                  'Share your journey...',
                                  isDark,
                                ).copyWith(
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Country Code',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _countryC,
                                textInputAction: TextInputAction.done,
                                maxLength: 2,
                                textCapitalization: TextCapitalization.characters,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                                decoration: _inputDeco(
                                  '',
                                  'BD',
                                  isDark,
                                ).copyWith(
                                  prefixIcon: Icon(
                                    Icons.flag_rounded,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    size: 20,
                                  ),
                                ),
                                onChanged: (v) {
                                  final norm = _normalizeCountry(v);
                                  if (norm != v) {
                                    _countryC.value = _countryC.value.copyWith(
                                      text: norm,
                                      selection:
                                      TextSelection.collapsed(offset: norm.length),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGlass(
                      isDark: isDark,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.withOpacity(0.2),
                                      Colors.orange.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.shield_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Privacy Settings',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'Control what\'s visible',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _optedIn
                                    ? [
                                  AppConfig.successColor.withOpacity(0.15),
                                  AppConfig.successColor.withOpacity(0.05),
                                ]
                                    : [
                                  Colors.grey.withOpacity(0.15),
                                  Colors.grey.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _optedIn
                                    ? AppConfig.successColor.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (_optedIn
                                        ? AppConfig.successColor
                                        : Colors.grey)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _optedIn
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color:
                                    _optedIn ? AppConfig.successColor : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Leaderboard Visibility',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _optedIn
                                            ? 'Visible to everyone'
                                            : 'Hidden from public',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                          _optedIn ? AppConfig.successColor : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.9,
                                  child: Switch(
                                    activeColor: AppConfig.successColor,
                                    activeTrackColor:
                                    AppConfig.successColor.withOpacity(0.5),
                                    inactiveThumbColor: Colors.grey,
                                    inactiveTrackColor: Colors.grey.withOpacity(0.3),
                                    value: _optedIn,
                                    onChanged: (v) {
                                      HapticFeedback.mediumImpact();
                                      SoundService.playTap();
                                      setState(() {
                                        _optedIn = v;
                                        if (!v) {
                                          _showLevel = false;
                                          _showBadges = false;
                                          _showStudyHours = false;
                                        } else {
                                          _showLevel = true;
                                          _showBadges = true;
                                          _showStudyHours = true;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            child: _optedIn
                                ? Column(
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.black.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      _privacyToggle(
                                        isDark: isDark,
                                        title: 'Show Level',
                                        subtitle: 'Display level on leaderboard',
                                        value: _showLevel,
                                        onChanged: (v) =>
                                            setState(() => _showLevel = v),
                                      ),
                                      Divider(
                                        height: 20,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.black.withOpacity(0.06),
                                      ),
                                      _privacyToggle(
                                        isDark: isDark,
                                        title: 'Show Badges',
                                        subtitle: 'Display unlocked badges',
                                        value: _showBadges,
                                        onChanged: (v) =>
                                            setState(() => _showBadges = v),
                                      ),
                                      Divider(
                                        height: 20,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.black.withOpacity(0.06),
                                      ),
                                      _privacyToggle(
                                        isDark: isDark,
                                        title: 'Show Study Hours',
                                        subtitle: 'Display total study time',
                                        value: _showStudyHours,
                                        onChanged: (v) =>
                                            setState(() => _showStudyHours = v),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () => _showBlocklistSheet(isDark),
                      child: _buildGlass(
                        isDark: isDark,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.block_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Manage Blocked Users',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'View and unblock users',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? Colors.white38 : Colors.black38,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppConfig.primaryColor,
                              Color(0xFF3B82F6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppConfig.primaryColor.withOpacity(0.5),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: AppConfig.primaryColor.withOpacity(0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                              : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Save Profile',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_existing != null) ...[
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _exitEditMode,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],

                    if (_existing != null) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _saving ? null : _deleteCloudProfile,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: AppConfig.errorColor,
                          size: 20,
                        ),
                        label: const Text(
                          'Delete Cloud Profile',
                          style: TextStyle(
                            color: AppConfig.errorColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _showBlocklistSheet(bool isDark) async {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  const Color(0xFF151C2F).withOpacity(0.95),
                  const Color(0xFF0B1020).withOpacity(0.98),
                ]
                    : [
                  Colors.white.withOpacity(0.95),
                  const Color(0xFFF8FAFC).withOpacity(0.98),
                ],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blocked Users',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Manage your blocklist',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ValueListenableBuilder<Set<String>>(
                    valueListenable:
                    LeaderboardModerationService.blockedUidsNotifier,
                    builder: (context, blocked, _) {
                      if (blocked.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.04)
                                      : Colors.black.withOpacity(0.03),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.verified_user_rounded,
                                  size: 64,
                                  color: isDark ? Colors.white38 : Colors.black26,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No blocked users',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You haven\'t blocked anyone yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: blocked.length,
                        itemBuilder: (context, i) {
                          final uid = blocked.elementAt(i);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                  Colors.white.withOpacity(0.06),
                                  Colors.white.withOpacity(0.03),
                                ]
                                    : [
                                  Colors.black.withOpacity(0.03),
                                  Colors.black.withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_off_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Blocked User',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        uid.length > 16
                                            ? '${uid.substring(0, 16)}...'
                                            : uid,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    await LeaderboardModerationService.unblockUid(uid);
                                    SoundService.playTap();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppConfig.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Unblock',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewStatBox extends StatelessWidget {
  const _ViewStatBox({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final bool isDark;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.18 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MyProfileLikerTile extends StatelessWidget {
  const _MyProfileLikerTile({
    required this.liker,
    required this.isDark,
    required this.formatTime,
  });

  final LikerInfo liker;
  final bool isDark;
  final String Function(DateTime) formatTime;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ProfileLikeService.instance.getLikerProfile(liker.uid),
      builder: (context, snap) {
        final data = snap.data;
        final name = (data?['displayName'] as String?) ?? 'Player';
        final avatar = (data?['avatarEmoji'] as String?) ?? '🙂';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    avatar,
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
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTime(liker.likedAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF4D6D),
                size: 18,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarOption {
  final String emoji;
  final String title;
  final List<Color> colors;

  const _AvatarOption({
    required this.emoji,
    required this.title,
    required this.colors,
  });
}