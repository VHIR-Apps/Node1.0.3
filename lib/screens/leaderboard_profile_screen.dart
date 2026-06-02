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
import '../services/database_service.dart';
import '../services/leaderboard_service.dart';
import '../services/leaderboard_moderation_service.dart';
import '../services/sound_service.dart';

class LeaderboardProfileScreen extends StatefulWidget {
  const LeaderboardProfileScreen({super.key});

  @override
  State<LeaderboardProfileScreen> createState() =>
      _LeaderboardProfileScreenState();
}

class _LeaderboardProfileScreenState extends State<LeaderboardProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _taglineC = TextEditingController();
  final TextEditingController _bioC = TextEditingController();
  final TextEditingController _countryC = TextEditingController();
  final TextEditingController _postC = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // Privacy & Settings
  bool _optedIn = true;
  bool _showLevel = true;
  bool _showBadges = true;
  bool _showStudyHours = true;
  bool _allowMessages = true; // NEW: Message Privacy
  bool _showMyPosts = true; // NEW: Post Visibility

  String _emoji = '🙂';
  int _avatarIndex = 0;
  int _joinedAtMs = 0;
  bool _isInterviewUser = false;
  int _profileThemeIndex = 0;

  String? _uid;
  LeaderboardProfileModel? _existing;

  late AnimationController _bgAnimationController;

  static const List<String> _emojiOptions = <String>[
    '🙂', '😄', '😎', '🤓', '🧠', '🔥', '⭐', '🏆',
    '👑', '💎', '🚀', '🌙', '☀️', '🌿', '🌸', '🎯',
  ];

  static const List<_AvatarOption> _avatarOptions = <_AvatarOption>[
    _AvatarOption(emoji: '🧠', title: 'Mind', colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
    _AvatarOption(emoji: '🔥', title: 'Blaze', colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)]),
    _AvatarOption(emoji: '🎯', title: 'Focus', colors: [Color(0xFF00C853), Color(0xFF10B981)]),
    _AvatarOption(emoji: '🌙', title: 'Night', colors: [Color(0xFF6366F1), Color(0xFF111827)]),
    _AvatarOption(emoji: '☀️', title: 'Day', colors: [Color(0xFFFFD700), Color(0xFFFFB300)]),
    _AvatarOption(emoji: '🚀', title: 'Rocket', colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
    _AvatarOption(emoji: '🌿', title: 'Calm', colors: [Color(0xFF10B981), Color(0xFF34D399)]),
    _AvatarOption(emoji: '💎', title: 'Gem', colors: [Color(0xFF8B5CF6), Color(0xFF6C63FF)]),
    _AvatarOption(emoji: '🏆', title: 'Winner', colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]),
    _AvatarOption(emoji: '📚', title: 'Study', colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
    _AvatarOption(emoji: '⚡', title: 'Spark', colors: [Color(0xFFFFB300), Color(0xFFFF6B6B)]),
    _AvatarOption(emoji: '🛡️', title: 'Shield', colors: [Color(0xFF6B7280), Color(0xFF111827)]),
    _AvatarOption(emoji: '🎵', title: 'Rhythm', colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)]),
    _AvatarOption(emoji: '🌸', title: 'Bloom', colors: [Color(0xFFFF6B6B), Color(0xFFFB7185)]),
    _AvatarOption(emoji: '🧩', title: 'Puzzle', colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)]),
    _AvatarOption(emoji: '🧘', title: 'Zen', colors: [Color(0xFF10B981), Color(0xFF059669)]),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _taglineC.dispose();
    _bioC.dispose();
    _countryC.dispose();
    _postC.dispose();
    _bgAnimationController.dispose();
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
            title: 'Sign-in Required', message: 'Sign-in was cancelled.');
        if (mounted) Navigator.pop(context);
        return;
      }

      final uid = user.uid;
      _uid = uid;

      final local = DatabaseService.getLeaderboardProfileForUid(uid);
      _existing = local;

      if (local != null) {
        _nameC.text = local.displayName;
        _taglineC.text = local.tagline ?? '';
        _bioC.text = local.bio ?? '';
        _countryC.text = local.countryCode ?? '';
        _optedIn = local.isOptedIn;
        _showLevel = local.showLevel;
        _showBadges = local.showBadges;
        _showStudyHours = local.showStudyHours;
        _emoji = local.avatarEmoji.trim().isEmpty ? '🙂' : local.avatarEmoji;
        _avatarIndex = (local.avatarIndex < 0) ? 0 : local.avatarIndex;
        _joinedAtMs = local.joinedAtMs;
        _isInterviewUser = local.isInterviewUser;
        _profileThemeIndex = local.profileThemeIndex;

        // Mock loading extra privacy settings if added to model later
        _allowMessages = true;
        _showMyPosts = true;
      } else {
        final suggested = (user.displayName ?? '').trim();
        if (suggested.isNotEmpty) {
          _nameC.text = LeaderboardProfileModel.safeDisplayName(suggested);
        }
        _avatarIndex = 0;
        _emoji = _avatarOptions[_avatarIndex].emoji;
        _joinedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        _isInterviewUser = false;
        _profileThemeIndex = 0;
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(title: 'Error', message: _prettyError(e));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _prettyError(Object e) {
    if (e is AuthServiceException) {
      return e.message.trim().isEmpty ? 'Sign-in failed.' : e.message;
    }
    final msg = e.toString();
    if (msg.contains('cancelled')) return 'Sign-in was cancelled.';
    if (msg.contains('network-request-failed') ||
        msg.contains('SocketException')) return 'No internet connection.';
    return msg
        .replaceAll('AuthServiceException:', '')
        .replaceAll('LeaderboardServiceException:', '')
        .trim();
  }

  Future<void> _showErrorDialog(
      {required String title, required String message}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: _buildGlassContainer(
          isDark: isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppConfig.errorColor, size: 48),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      height: 1.4)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('OK',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        content: _buildGlassContainer(
          isDark: Theme.of(context).brightness == Brightness.dark,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          gradientColors: isError
              ? [
            AppConfig.errorColor.withOpacity(0.9),
            Colors.redAccent.withOpacity(0.8)
          ]
              : [
            AppConfig.primaryColor.withOpacity(0.95),
            const Color(0xFF3B82F6).withOpacity(0.85)
          ],
          child: Row(
            children: [
              Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }

  _AvatarOption _safeAvatarOption(int index) {
    if (_avatarOptions.isEmpty) {
      return const _AvatarOption(
          emoji: '🙂',
          title: 'Default',
          colors: [AppConfig.primaryColor, AppConfig.infoColor]);
    }
    final i = index.clamp(0, _avatarOptions.length - 1);
    return _avatarOptions[i];
  }

  Future<void> _pickAvatarCharacter() async {
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
                  color: (isDark ? const Color(0xFF151C2F) : Colors.white)
                      .withOpacity(0.85),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05))),
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
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Choose Avatar',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87)),
                        IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded,
                                color:
                                isDark ? Colors.white70 : Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: _avatarOptions.length,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.0),
                      itemBuilder: (_, i) {
                        final opt = _avatarOptions[i];
                        final isSelected = i == _avatarIndex;
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                                    opt.colors[0]
                                        .withOpacity(isDark ? 0.6 : 0.4),
                                    opt.colors[1]
                                        .withOpacity(isDark ? 0.3 : 0.2)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: isSelected
                                      ? AppConfig.primaryColor
                                      : Colors.transparent,
                                  width: isSelected ? 2.5 : 0),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                      color: AppConfig.primaryColor
                                          .withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5))
                              ],
                            ),
                            child: Center(
                                child: Text(opt.emoji,
                                    style: const TextStyle(fontSize: 32))),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final e = await _pickEmoji(ctx);
                          if (ctx.mounted && e != null) {
                            Navigator.pop(ctx, null);
                            if (mounted) setState(() => _emoji = e);
                          }
                        },
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        label: const Text('Pick Custom Emoji',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
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
      _emoji = _safeAvatarOption(selected).emoji;
    });
  }

  Future<String?> _pickEmoji(BuildContext context) async {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF151C2F) : Colors.white)
                      .withOpacity(0.95),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05))),
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
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('More Emojis',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87)),
                        IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded,
                                color:
                                isDark ? Colors.white70 : Colors.black54))
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: _emojiOptions.length,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12),
                      itemBuilder: (_, i) {
                        final e = _emojiOptions[i];
                        final isSelected = e == _emoji;
                        return InkWell(
                          onTap: () => Navigator.pop(ctx, e),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                              decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppConfig.primaryColor.withOpacity(0.2)
                                      : (isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.05)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.transparent)),
                              child: Center(
                                  child: Text(e,
                                      style: const TextStyle(fontSize: 22)))),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🚀 NEW: Blocklist Bottom Sheet
  Future<void> _showBlocklistSheet() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF151C2F) : Colors.white)
                      .withOpacity(0.85),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05))),
              child: Column(
                children: [
                  Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Blocked Users',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87)),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.black54))
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: LeaderboardModerationService.blockedUidsNotifier,
                      builder: (context, blockedSet, _) {
                        if (blockedSet.isEmpty) {
                          return Center(
                            child: Text(
                              'No blocked users found.',
                              style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: blockedSet.length,
                          itemBuilder: (context, index) {
                            final blockedUid = blockedSet.elementAt(index);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_off_rounded, color: AppConfig.errorColor),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'User ID: ${blockedUid.substring(0, 8)}...',
                                      style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await LeaderboardModerationService.unblockUid(blockedUid);
                                      SoundService.playTap();
                                    },
                                    style: TextButton.styleFrom(foregroundColor: AppConfig.primaryColor),
                                    child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.w800)),
                                  )
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _normalizeCountry(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final only = v.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    return only.length <= 2 ? only : only.substring(0, 2);
  }

  String _memberForText(int joinedAtMs) {
    if (joinedAtMs <= 0) return 'Member';
    final diffDays = DateTime.now()
        .difference(
        DateTime.fromMillisecondsSinceEpoch(joinedAtMs, isUtc: true)
            .toLocal())
        .inDays;
    if (diffDays < 0) return 'Member';
    final years = diffDays ~/ 365,
        months = (diffDays % 365) ~/ 30,
        days = (diffDays % 365) % 30;
    if (years > 0) {
      return months > 0 ? 'Member for $years yr $months mo' : 'Member for $years yr';
    }
    if (months > 0) {
      return days > 0 ? 'Member for $months mo $days d' : 'Member for $months mo';
    }
    return days > 0 ? 'Member for $days d' : 'Just joined';
  }

  Future<void> _sharePost() async {
    final text = _postC.text.trim();
    if (text.isEmpty || _uid == null) return;
    HapticFeedback.mediumImpact();
    SoundService.playTap();
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final double myXp = _existing?.cachedScore ?? 0.0;
      await FirebaseFirestore.instance.collection('leaderboard_v1_posts').add({
        'authorUid': _uid,
        'authorName': _nameC.text.trim(),
        'authorAvatar': _emoji.isEmpty ? '🙂' : _emoji,
        'authorXp': myXp,
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _postC.clear();
      _showSnack('Update posted successfully!');
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
    final tagline = _taglineC.text.trim(),
        bio = _bioC.text.trim(),
        country = _normalizeCountry(_countryC.text);

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final base = _existing ??
          LeaderboardProfileModel.create(
              uid: uid,
              displayName: displayName,
              joinedAtMs: _joinedAtMs > 0
                  ? _joinedAtMs
                  : now.toUtc().millisecondsSinceEpoch,
              avatarIndex: _avatarIndex,
              avatarEmoji: LeaderboardProfileModel.safeEmoji(_emoji),
              isOptedIn: _optedIn,
              showLevel: _showLevel,
              showBadges: _showBadges,
              showStudyHours: _showStudyHours,
              isInterviewUser: _isInterviewUser,
              profileThemeIndex: _profileThemeIndex);

      final finalProfile = base.copyWith(
          displayName: displayName,
          tagline: tagline.isEmpty ? null : tagline,
          bio: bio.isEmpty ? null : bio,
          countryCode: country.isEmpty ? null : country,
          isOptedIn: _optedIn,
          showLevel: _showLevel,
          showBadges: _showBadges,
          showStudyHours: _showStudyHours,
          avatarEmoji: LeaderboardProfileModel.safeEmoji(_emoji),
          avatarIndex: _avatarIndex,
          joinedAtMs: _joinedAtMs > 0 ? _joinedAtMs : base.joinedAtMs,
          isInterviewUser: _isInterviewUser,
          profileThemeIndex: _profileThemeIndex,
          cachedRank: _existing?.cachedRank ?? -1,
          cachedScore: _existing?.cachedScore ?? 0.0,
          lastCloudSyncAt: _existing?.lastCloudSyncAt);

      _joinedAtMs = finalProfile.joinedAtMs;
      await DatabaseService.saveLeaderboardProfile(finalProfile);
      _existing = finalProfile;

      if (finalProfile.isOptedIn) {
        try {
          await LeaderboardService.instance.syncMyProfileToCloud();
        } catch (_) {}
      } else {
        try {
          await LeaderboardService.instance.hideMyProfileFromLeaderboard();
        } catch (e) {
          _showSnack('Saved locally. Cloud update needs internet.',
              isError: true);
        }
      }

      SoundService.playSuccess();
      _showSnack(finalProfile.isOptedIn
          ? 'Profile saved! 🚀'
          : 'Profile saved. Leaderboard turned off.');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(title: 'Save Failed', message: _prettyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDisableLeaderboard() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: _buildGlassContainer(
          isDark: isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_rounded,
                  color: AppConfig.warningColor, size: 48),
              const SizedBox(height: 16),
              Text('Hide Profile?',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                  'You will be hidden from the public leaderboard. You can turn it back on anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      height: 1.4)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.errorColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Hide Me',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _optedIn = false;
        _showLevel = false;
        _showBadges = false;
        _showStudyHours = false;
      });
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
        content: _buildGlassContainer(
          isDark: isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever_rounded,
                  color: AppConfig.errorColor, size: 48),
              const SizedBox(height: 16),
              Text('Delete Account Data?',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                  'This permanently deletes your public profile and leaderboard rank.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      height: 1.4)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.errorColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Delete',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
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
      await LeaderboardService.instance
          .deleteMyLeaderboardProfileFromCloud(alsoClearLocalProfile: true);
      if (!mounted) return;
      SoundService.playSuccess();
      _showSnack('Cloud profile deleted.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(title: 'Delete Failed', message: _prettyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─────────────────────────────────────────────
  // 💎 ULTRA-PREMIUM GLASSMORPHISM HELPERS & CUSTOM INPUTS
  // ─────────────────────────────────────────────

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDark,
    double borderRadius = 28.0,
    EdgeInsets padding = const EdgeInsets.all(24),
    List<Color>? gradientColors,
    bool hasBorder = true,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
                : LinearGradient(
                colors: isDark
                    ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.02)
                ]
                    : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.6)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder
                ? Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.8),
                width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 12))
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _customInputDeco(String label, String hint, bool isDark) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.black54,
          fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
      filled: true,
      fillColor:
      isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppConfig.primaryColor, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppConfig.errorColor, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatar = _safeAvatarOption(_avatarIndex);
    final bgColors = isDark
        ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
        : [const Color(0xFFF1F5F9), const Color(0xFFE0E7FF)];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: bgColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight))),

          // Ultra-Premium Mesh Gradient Orbs
          AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                final t = _bgAnimationController.value * 2 * math.pi;
                return Stack(
                  children: [
                    Positioned(
                        top: -50 + (40 * math.sin(t)),
                        left: -100 + (50 * math.cos(t)),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                          child: Container(
                              width: 400,
                              height: 400,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF6C63FF)
                                      .withOpacity(isDark ? 0.15 : 0.08))),
                        )),
                    Positioned(
                        bottom: 100 + (50 * math.cos(t * 0.8)),
                        right: -50 + (40 * math.sin(t * 1.2)),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                          child: Container(
                              width: 350,
                              height: 350,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppConfig.primaryColor
                                      .withOpacity(isDark ? 0.15 : 0.08))),
                        )),
                  ],
                );
              }),

          _loading
              ? const Center(
              child: CircularProgressIndicator(color: AppConfig.primaryColor))
              : CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: _buildGlassContainer(
                            isDark: isDark,
                            padding: EdgeInsets.zero,
                            borderRadius: 16,
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87)))),
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0B1020).withOpacity(0.6)
                                : Colors.white.withOpacity(0.6),
                            border: Border(
                                bottom: BorderSide(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.05)))),
                        child: SafeArea(
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 45, 24, 16),
                                child: Text('Edit Profile',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        letterSpacing: -0.5)))),
                      ),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        // 🚀 Floating Avatar Section
                        _buildGlassContainer(
                          isDark: isDark,
                          child: Column(
                            children: [
                              AnimatedBuilder(
                                animation: _bgAnimationController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                        0,
                                        8 * math.sin(_bgAnimationController.value * 2 * math.pi)),
                                    child: child,
                                  );
                                },
                                child: GestureDetector(
                                  onTap: _saving ? null : _pickAvatarCharacter,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 400),
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                colors: [
                                                  avatar.colors[0],
                                                  avatar.colors[1]
                                                      .withOpacity(0.8)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: avatar.colors[0]
                                                      .withOpacity(isDark
                                                      ? 0.5
                                                      : 0.3),
                                                  blurRadius: 30,
                                                  offset: const Offset(
                                                      0, 12))
                                            ]),
                                        child: Center(
                                            child: Text(
                                                _emoji.trim().isEmpty
                                                    ? avatar.emoji
                                                    : _emoji,
                                                style: const TextStyle(
                                                    fontSize: 52))),
                                      ),
                                      Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                              padding:
                                              const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(
                                                      0xFF1E293B)
                                                      : Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(
                                                            0.15),
                                                        blurRadius: 15)
                                                  ]),
                                              child: const Icon(
                                                  Icons.edit_rounded,
                                                  size: 18,
                                                  color: AppConfig
                                                      .primaryColor))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text('Public Identity',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87)),
                              const SizedBox(height: 4),
                              Text(_memberForText(_joinedAtMs),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Form Details
                        _buildGlassContainer(
                          isDark: isDark,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text('Profile Details',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87)),
                                const SizedBox(height: 24),
                                TextFormField(
                                    controller: _nameC,
                                    textInputAction: TextInputAction.next,
                                    maxLength: 24,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16),
                                    decoration: _customInputDeco(
                                        'Display Name',
                                        'Superhero name...',
                                        isDark),
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return 'Name required.';
                                      if (s.length < 2) return 'Too short.';
                                      return null;
                                    }),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _taglineC,
                                    textInputAction: TextInputAction.next,
                                    maxLength: 64,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600),
                                    decoration: _customInputDeco(
                                        'Tagline (optional)',
                                        'What drives you?',
                                        isDark)),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _bioC,
                                    textInputAction: TextInputAction.newline,
                                    maxLength: 220,
                                    maxLines: 4,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        height: 1.4),
                                    decoration: _customInputDeco(
                                        'Bio (optional)',
                                        'Share your journey...',
                                        isDark)),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _countryC,
                                    textInputAction: TextInputAction.done,
                                    maxLength: 2,
                                    textCapitalization:
                                    TextCapitalization.characters,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w800),
                                    decoration: _customInputDeco(
                                        'Country Code (e.g. BD)',
                                        'BD',
                                        isDark),
                                    onChanged: (v) {
                                      final norm = _normalizeCountry(v);
                                      if (norm != v) {
                                        _countryC.value = _countryC.value
                                            .copyWith(
                                            text: norm,
                                            selection: TextSelection
                                                .collapsed(
                                                offset:
                                                norm.length));
                                      }
                                    }),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🚀 NEW: Privacy & Security Settings
                        _buildGlassContainer(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.redAccent
                                              .withOpacity(0.15),
                                          borderRadius:
                                          BorderRadius.circular(10)),
                                      child: const Icon(
                                          Icons.shield_rounded,
                                          color: Colors.redAccent,
                                          size: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text('Privacy & Security',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87))),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _privacyToggle(
                                  isDark: isDark,
                                  title: 'Allow Direct Messages',
                                  subtitle: 'Let other users message you',
                                  value: _allowMessages,
                                  onChanged: (v) =>
                                      setState(() => _allowMessages = v)),
                              _privacyToggle(
                                  isDark: isDark,
                                  title: 'Show My Posts',
                                  subtitle: 'Make your posts public',
                                  value: _showMyPosts,
                                  onChanged: (v) =>
                                      setState(() => _showMyPosts = v)),
                              const SizedBox(height: 12),
                              Divider(color: isDark ? Colors.white24 : Colors.black12),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text('Leaderboard Visibility',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87)),
                                        const SizedBox(height: 4),
                                        Text(
                                            _optedIn
                                                ? 'Your profile is publicly visible'
                                                : 'You are hidden from public',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: _optedIn
                                                    ? (isDark
                                                    ? Colors.white54
                                                    : Colors.black54)
                                                    : AppConfig.warningColor)),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                      activeColor: AppConfig.primaryColor,
                                      value: _optedIn,
                                      onChanged: (v) async {
                                        HapticFeedback.lightImpact();
                                        SoundService.playTap();
                                        if (!v) {
                                          await _confirmDisableLeaderboard();
                                          return;
                                        }
                                        setState(() {
                                          _optedIn = true;
                                          _showLevel = true;
                                          _showBadges = true;
                                          _showStudyHours = true;
                                        });
                                      }),
                                ],
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                child: _optedIn
                                    ? Column(
                                  children: [
                                    const SizedBox(height: 20),
                                    Container(
                                      padding:
                                      const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white
                                              .withOpacity(0.02)
                                              : Colors.black
                                              .withOpacity(0.02),
                                          borderRadius:
                                          BorderRadius.circular(
                                              16),
                                          border: Border.all(
                                              color: isDark
                                                  ? Colors.white
                                                  .withOpacity(
                                                  0.05)
                                                  : Colors.black
                                                  .withOpacity(
                                                  0.05))),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text('Profile Info Sharing',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                  FontWeight.w900,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors
                                                      .black87)),
                                          const SizedBox(height: 16),
                                          _privacyToggle(
                                              isDark: isDark,
                                              title: 'Show Level',
                                              subtitle:
                                              'Display level on leaderboard',
                                              value: _showLevel,
                                              onChanged: (v) =>
                                                  setState(() =>
                                                  _showLevel = v)),
                                          _privacyToggle(
                                              isDark: isDark,
                                              title: 'Show Badges',
                                              subtitle:
                                              'Display unlocked badges',
                                              value: _showBadges,
                                              onChanged: (v) =>
                                                  setState(() =>
                                                  _showBadges = v)),
                                          _privacyToggle(
                                              isDark: isDark,
                                              title: 'Study Hours',
                                              subtitle:
                                              'Display total study time',
                                              value: _showStudyHours,
                                              onChanged: (v) =>
                                                  setState(() =>
                                                  _showStudyHours =
                                                      v)),
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

                        const SizedBox(height: 24),

                        // 🚀 NEW: Blocklist Management Button
                        InkWell(
                          onTap: _showBlocklistSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.block_rounded, color: Colors.grey),
                                const SizedBox(width: 14),
                                Expanded(child: Text('Manage Blocked Users', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.black87))),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey)
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Social Update Box
                        _buildGlassContainer(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: AppConfig.primaryColor
                                            .withOpacity(0.15),
                                        borderRadius:
                                        BorderRadius.circular(10)),
                                    child: const Icon(
                                        Icons.campaign_rounded,
                                        color: AppConfig.primaryColor,
                                        size: 20)),
                                const SizedBox(width: 12),
                                Text('Share an Update',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87))
                              ]),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: _postC,
                                  maxLines: 3,
                                  maxLength: 120,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      height: 1.4),
                                  decoration: _customInputDeco(
                                      '',
                                      "What's on your mind? Inspire others!",
                                      isDark)
                                      .copyWith(
                                      contentPadding:
                                      const EdgeInsets.all(16))),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: _saving ? null : _sharePost,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 14),
                                    decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                            colors: [
                                              AppConfig.primaryColor,
                                              Color(0xFF3B82F6)
                                            ]),
                                        borderRadius:
                                        BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                              color: AppConfig.primaryColor
                                                  .withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4))
                                        ]),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Post Now',
                                              style: TextStyle(
                                                  fontWeight:
                                                  FontWeight.w900,
                                                  color: Colors.white,
                                                  fontSize: 15)),
                                          SizedBox(width: 8),
                                          Icon(Icons.send_rounded,
                                              color: Colors.white,
                                              size: 18)
                                        ]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🚀 NEW: Real-time User's Posts History with Delete Option
                        if (_uid != null)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('leaderboard_v1_posts')
                                .where('authorUid', isEqualTo: _uid)
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final posts = snapshot.data!.docs;
                              return _buildGlassContainer(
                                isDark: isDark,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.history_rounded, color: AppConfig.accentColor),
                                      const SizedBox(width: 8),
                                      Text('My Recent Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87))
                                    ]),
                                    const SizedBox(height: 16),
                                    ...posts.map((postDoc) {
                                      final postData = postDoc.data() as Map<String, dynamic>;
                                      final text = postData['content'] as String? ?? '';
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(text, style: TextStyle(fontSize: 14.5, height: 1.4, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87)),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                              onPressed: () async {
                                                HapticFeedback.mediumImpact();
                                                await postDoc.reference.delete();
                                                _showSnack('Post deleted.');
                                              },
                                            )
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 30),

                        // Main Save Button
                        InkWell(
                          onTap: _saving ? null : _save,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  AppConfig.primaryColor,
                                  AppConfig.primaryColor.withOpacity(0.8)
                                ]),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppConfig.primaryColor
                                          .withOpacity(0.4),
                                      blurRadius: 25,
                                      offset: const Offset(0, 10))
                                ]),
                            child: Center(
                                child: Text(
                                    _saving ? 'Saving...' : 'Save Profile',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white))),
                          ),
                        ),

                        if (_existing != null) ...[
                          const SizedBox(height: 16),
                          TextButton.icon(
                              onPressed:
                              _saving ? null : _deleteCloudProfile,
                              icon: const Icon(Icons.delete_forever_rounded,
                                  color: AppConfig.errorColor),
                              label: const Text('Delete Cloud Profile',
                                  style: TextStyle(
                                      color: AppConfig.errorColor,
                                      fontWeight: FontWeight.w800))),
                        ],
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _privacyToggle(
      {required bool isDark,
        required String title,
        required String subtitle,
        required bool value,
        required ValueChanged<bool>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54))
                  ])),
          Switch(
              activeColor: AppConfig.primaryColor,
              value: value,
              onChanged: onChanged != null
                  ? (v) {
                HapticFeedback.lightImpact();
                SoundService.playTap();
                onChanged(v);
              }
                  : null),
        ],
      ),
    );
  }
}

class _AvatarOption {
  final String emoji;
  final String title;
  final List<Color> colors;

  const _AvatarOption(
      {required this.emoji, required this.title, required this.colors});
}