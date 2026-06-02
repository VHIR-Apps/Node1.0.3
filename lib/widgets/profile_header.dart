// lib/widgets/profile_header.dart

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/leaderboard_profile_model.dart';
import '../screens/badges_screen.dart';
import '../screens/leaderboard_profile_screen.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/profile_service.dart';
import '../services/sound_service.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: AuthService.instance.userNotifier,
      builder: (context, user, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        // Local data
        final dayStreak = DatabaseService.getBestStreakTotal();
        final rawName = DatabaseService.getUserName();
        final name = rawName.trim().isEmpty ? 'Habit Hero' : rawName.trim();
        final avatarEmoji = DatabaseService.getUserAvatar();

        // XP-based level from ProfileService
        final level = ProfileService.getLevel();
        final levelTitle = ProfileService.getLevelTitle();
        final levelProgress = ProfileService.getLevelProgress().clamp(0.0, 1.0);
        final xp = ProfileService.getTotalXp();

        final badgesUnlocked = ProfileService.getBadgesUnlocked();
        final totalBadges = ProfileService.getTotalBadges();
        final levelInfo = ProfileService.getLevelInfo();

        // 🏆 Leaderboard rank (cached locally)
        LeaderboardProfileModel? lbProfile;
        if (user != null) {
          lbProfile = DatabaseService.getLeaderboardProfileForUid(user.uid);
        }
        final bool showRankPill = (lbProfile?.isOptedIn ?? false);
        final int cachedRank = lbProfile?.cachedRank ?? -1;

        final String rankText = cachedRank > 0 ? '#$cachedRank' : '—';
        final Color rankColor = cachedRank > 0 && cachedRank <= 3
            ? const Color(0xFFFFD700)
            : AppConfig.infoColor;

        final bool isPro = DatabaseService.isProOrVipUser();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOut,
          child: _GlassCard(
            key: ValueKey<String>('profile_header_${user?.uid ?? "signed_out"}'),
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            isDark: isDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ═══ TOP ROW: Avatar + Identity + Stats ═══
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with level badge + optional crown
                    _AvatarTile(
                      isDark: isDark,
                      avatarEmoji: avatarEmoji,
                      level: level,
                      isPro: isPro,
                    ),
                    const SizedBox(width: 14),

                    // Name + Title + Progress (flex to prevent overflow)
                    Expanded(
                      child: _IdentityBlock(
                        isDark: isDark,
                        name: name,
                        isPro: isPro,
                        levelEmoji: (levelInfo['emoji'] ?? '⭐').toString(),
                        levelTitle: levelTitle,
                        levelProgress: levelProgress,
                        xp: xp,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Compact stats (constrained width to prevent overflow)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: _CompactStatsColumn(
                        isDark: isDark,
                        dayStreak: dayStreak,
                        badgesUnlocked: badgesUnlocked,
                        showRankPill: showRankPill,
                        rankText: rankText,
                        rankColor: rankColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Badge collection progress (tap → badges)
                _BadgeCollectionProgress(
                  isDark: isDark,
                  badgesUnlocked: badgesUnlocked,
                  totalBadges: totalBadges,
                  onTap: () => _openBadges(context),
                ),

                const SizedBox(height: 14),

                // Action row: Badges + Edit Profile
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        isDark: isDark,
                        style: _ActionButtonStyle.outlined,
                        icon: Icons.emoji_events_rounded,
                        label: 'Badges',
                        onTap: () => _openBadges(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        isDark: isDark,
                        style: _ActionButtonStyle.filled,
                        icon: Icons.tune_rounded,
                        label: 'Edit Profile',
                        onTap: () => _openEditProfile(context, user),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBadges(BuildContext context) async {
    try {
      SoundService.playTap();
      HapticFeedback.lightImpact();
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BadgesScreen()),
      );
    } catch (_) {
      _showSnack(
        context,
        message: 'Unable to open badges. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _openEditProfile(BuildContext context, User? user) async {
    SoundService.playTap();
    HapticFeedback.lightImpact();

    try {
      // User-driven sign-in only (Play policy safe).
      if (user == null) {
        final go = await _showProfileSignInDialog(context);
        if (go != true) return;

        await AuthService.instance.ensureSignedInOnDemand(interactive: true);
      }

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeaderboardProfileScreen()),
      );
    } catch (e) {
      _showSnack(
        context,
        message: _prettyError(e),
        isError: true,
      );
    }
  }

  Future<bool?> _showProfileSignInDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151C2F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppConfig.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Profile',
                style: TextStyle(fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'To customize your public profile and restore it after reinstall, please sign in with Google. You can continue without signing in.',
          style: TextStyle(
            height: 1.45,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Not now',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign in',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  String _prettyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Sign-in cancelled')) return 'Sign-in was cancelled.';
    if (msg.contains('No internet') || msg.contains('network')) {
      return 'No internet connection. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showSnack(
      BuildContext context, {
        required String message,
        required bool isError,
      }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppConfig.errorColor : null,
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════
// PRIVATE WIDGETS — Glass Card, Avatar, Identity, Stats, etc.
// ═══════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.isDark,
    required this.borderRadius,
    required this.padding,
    super.key,
  });

  final Widget child;
  final bool isDark;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);

    final base = isDark ? const Color(0xFF151C2F) : Colors.white;
    final overlayA = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.75);
    final overlayB = isDark
        ? Colors.white.withOpacity(0.02)
        : Colors.white.withOpacity(0.55);

    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: base.withOpacity(isDark ? 0.72 : 0.82),
            borderRadius: r,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.22)
                    : Colors.black.withOpacity(0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              colors: [overlayA, overlayB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.isDark,
    required this.avatarEmoji,
    required this.level,
    required this.isPro,
  });

  final bool isDark;
  final String avatarEmoji;
  final int level;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final tileRadius = BorderRadius.circular(18);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConfig.primaryColor,
                AppConfig.primaryColor.withOpacity(0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: tileRadius,
            boxShadow: [
              BoxShadow(
                color:
                AppConfig.primaryColor.withOpacity(isDark ? 0.22 : 0.28),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                avatarEmoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        ),

        // Level badge
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF151C2F) : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.32),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              'Lv.$level',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Pro crown
        if (isPro)
          Positioned(
            top: -8,
            left: -8,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.35),
                ),
              ),
              child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
      ],
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.isDark,
    required this.name,
    required this.isPro,
    required this.levelEmoji,
    required this.levelTitle,
    required this.levelProgress,
    required this.xp,
  });

  final bool isDark;
  final String name;
  final bool isPro;
  final String levelEmoji;
  final String levelTitle;
  final double levelProgress;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name row with PRO badge
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isPro) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700)
                      .withOpacity(isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFD700)
                        .withOpacity(isDark ? 0.20 : 0.16),
                  ),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD700),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),

        // Level title row
        Row(
          children: [
            Text(levelEmoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                levelTitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppConfig.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // XP Progress bar
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: levelProgress,
                      minHeight: 7,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD700),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FractionallySizedBox(
                        widthFactor: levelProgress,
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white
                                    .withOpacity(isDark ? 0.18 : 0.22),
                                Colors.transparent,
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
            const SizedBox(width: 8),
            Text(
              '$xp XP',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactStatsColumn extends StatelessWidget {
  const _CompactStatsColumn({
    required this.isDark,
    required this.dayStreak,
    required this.badgesUnlocked,
    required this.showRankPill,
    required this.rankText,
    required this.rankColor,
  });

  final bool isDark;
  final int dayStreak;
  final int badgesUnlocked;
  final bool showRankPill;
  final String rankText;
  final Color rankColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniStatPill(
          icon: Icons.local_fire_department_rounded,
          value: '$dayStreak',
          color: const Color(0xFFFF6A00),
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        _MiniStatPill(
          icon: Icons.emoji_events_rounded,
          value: '$badgesUnlocked',
          color: const Color(0xFFFFD700),
          isDark: isDark,
        ),
        if (showRankPill) ...[
          const SizedBox(height: 6),
          _MiniStatPill(
            icon: Icons.leaderboard_rounded,
            value: rankText,
            color: rankColor,
            isDark: isDark,
          ),
        ],
      ],
    );
  }
}

class _BadgeCollectionProgress extends StatelessWidget {
  const _BadgeCollectionProgress({
    required this.isDark,
    required this.badgesUnlocked,
    required this.totalBadges,
    required this.onTap,
  });

  final bool isDark;
  final int badgesUnlocked;
  final int totalBadges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress =
    totalBadges > 0 ? (badgesUnlocked / totalBadges).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          SoundService.playTap();
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                Colors.white.withOpacity(0.04),
                Colors.white.withOpacity(0.02),
              ]
                  : [
                AppConfig.primaryColor.withOpacity(0.05),
                AppConfig.primaryColor.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : AppConfig.primaryColor.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 14,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppConfig.primaryColor.withOpacity(0.78),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$badgesUnlocked/$totalBadges',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ActionButtonStyle { filled, outlined }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isDark,
    required this.style,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool isDark;
  final _ActionButtonStyle style;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    final filledBg =
    AppConfig.primaryColor.withOpacity(isDark ? 0.88 : 1.0);
    const filledFg = Colors.white;

    final outlinedFg = isDark ? Colors.white : Colors.black87;
    final outlinedBorder = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final outlinedBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          SoundService.playTap();
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color:
            style == _ActionButtonStyle.filled ? filledBg : outlinedBg,
            borderRadius: radius,
            border: Border.all(
              color: style == _ActionButtonStyle.filled
                  ? Colors.white.withOpacity(isDark ? 0.10 : 0.12)
                  : outlinedBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: style == _ActionButtonStyle.filled
                    ? filledFg
                    : AppConfig.primaryColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: style == _ActionButtonStyle.filled
                        ? filledFg
                        : outlinedFg,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  const _MiniStatPill({
    required this.icon,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.18 : 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}