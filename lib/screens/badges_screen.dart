import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';
import '../services/profile_service.dart';
import '../services/sound_service.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with TickerProviderStateMixin {
  BadgeCategory? _selectedCategory;
  late AnimationController _staggerController;
  late AnimationController _headerGlowController;
  late Animation<double> _headerGlow;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _headerGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _headerGlow = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _headerGlowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _headerGlowController.dispose();
    super.dispose();
  }

  List<BadgeDefinition> _getFilteredBadges() {
    if (_selectedCategory == null) return AllBadges.getAll();
    return AllBadges.getByCategory(_selectedCategory!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badges = _getFilteredBadges();
    final unlocked = BadgeService.getUnlockedCount();
    final total = BadgeService.getTotalCount();
    final stats = ProfileService.getProfileStats();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══ HEADER ═══
          SliverToBoxAdapter(
            child: _buildHeader(isDark, stats, unlocked, total),
          ),

          // ═══ CATEGORY FILTER ═══
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _categoryChip(null, 'All', Icons.grid_view_rounded, isDark),
                    ...AllBadges.getAllCategories().map((cat) {
                      final def = AllBadges.getByCategory(cat).first;
                      return _categoryChip(cat, def.categoryLabel, def.categoryIcon, isDark);
                    }),
                  ],
                ),
              ),
            ),
          ),

          // ═══ BADGE COUNT ═══
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${badges.length} badges',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$unlocked unlocked',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppConfig.successColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══ BADGE GRID ═══
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final badge = badges[index];
                  final isUnlocked = BadgeService.isBadgeUnlocked(badge.id);
                  final progress = BadgeService.getBadgeProgress(badge);

                  final slideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _staggerController,
                      curve: Interval(
                        (index * 0.05).clamp(0.0, 0.7),
                        ((index * 0.05) + 0.3).clamp(0.3, 1.0),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  );

                  return AnimatedBuilder(
                    animation: slideAnim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - slideAnim.value)),
                        child: Opacity(
                          opacity: slideAnim.value,
                          child: _buildBadgeCard(
                            badge, isUnlocked, progress, isDark,
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: badges.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════

  Widget _buildHeader(bool isDark, Map<String, dynamic> stats, int unlocked, int total) {
    final xp = stats['xp'] as int;
    final level = stats['level'] as int;
    final levelTitle = stats['levelTitle'] as String;
    final progress = stats['progress'] as double;
    final xpNext = stats['xpNext'] as int;

    return AnimatedBuilder(
      animation: _headerGlowController,
      builder: (context, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 12,
            20,
            24,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A1040), const Color(0xFF0D0A20)]
                  : [const Color(0xFF6C63FF), const Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppConfig.primaryColor.withOpacity(_headerGlow.value * 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      SoundService.playTap();
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Badge Collection',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$unlocked / $total',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // XP + Level card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    // Level badge
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(_headerGlow.value * 0.4),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Lv\n$level',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            levelTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$xp XP • $xpNext XP to next level',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFD700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Rarity summary
              Row(
                children: [
                  _rarityStat('Common', BadgeRarity.common, isDark),
                  const SizedBox(width: 8),
                  _rarityStat('Rare', BadgeRarity.rare, isDark),
                  const SizedBox(width: 8),
                  _rarityStat('Epic', BadgeRarity.epic, isDark),
                  const SizedBox(width: 8),
                  _rarityStat('Legend', BadgeRarity.legendary, isDark),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rarityStat(String label, BadgeRarity rarity, bool isDark) {
    final all = AllBadges.getAll().where((b) => b.rarity == rarity).length;
    final unlocked = AllBadges.getAll()
        .where((b) => b.rarity == rarity && BadgeService.isBadgeUnlocked(b.id))
        .length;

    final color = BadgeDefinition(
      id: '', name: '', emoji: '', description: '',
      category: BadgeCategory.streak, rarity: rarity,
      threshold: 0, thresholdUnit: '', xpReward: 0,
    ).rarityColor;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$unlocked/$all',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // CATEGORY CHIP
  // ═══════════════════════════════════════

  Widget _categoryChip(BadgeCategory? category, String label, IconData icon, bool isDark) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          SoundService.playTap();
          setState(() {
            _selectedCategory = category;
            _staggerController.reset();
            _staggerController.forward();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConfig.primaryColor
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppConfig.primaryColor
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label.replaceAll(RegExp(r'[^\w\s-]'), '').trim(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // BADGE CARD
  // ═══════════════════════════════════════

  Widget _buildBadgeCard(
      BadgeDefinition badge,
      bool isUnlocked,
      double progress,
      bool isDark,
      ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        SoundService.playTap();
        _showBadgeDetail(badge, isUnlocked, progress);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? (isUnlocked ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02))
              : (isUnlocked ? Colors.white : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUnlocked
                ? badge.rarityColor.withOpacity(0.5)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
            width: isUnlocked ? 2 : 1,
          ),
          boxShadow: isUnlocked
              ? [
            BoxShadow(
              color: badge.rarityColor.withOpacity(isDark ? 0.15 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Stack(
          children: [
            // Rarity indicator
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: badge.rarityColor.withOpacity(isUnlocked ? 1.0 : 0.3),
                  shape: BoxShape.circle,
                  boxShadow: isUnlocked
                      ? [
                    BoxShadow(
                      color: badge.rarityColor.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ]
                      : null,
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emoji
                  Text(
                    badge.emoji,
                    style: TextStyle(
                      fontSize: 36,
                      color: isUnlocked ? null : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Name
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isUnlocked
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white30 : Colors.black26),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Progress bar or checkmark
                  if (isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConfig.successColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 12,
                              color: AppConfig.successColor),
                          SizedBox(width: 3),
                          Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppConfig.successColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              badge.rarityColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Lock overlay
            if (!isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // BADGE DETAIL BOTTOM SHEET
  // ═══════════════════════════════════════

  void _showBadgeDetail(BadgeDefinition badge, bool isUnlocked, double progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressText = BadgeService.getBadgeProgressText(badge);

    // Find unlock date
    DateTime? unlockedAt;
    if (isUnlocked) {
      final unlocked = BadgeService.getUnlockedBadges();
      for (final u in unlocked) {
        if (u.badgeId == badge.id) {
          unlockedAt = u.unlockedAt;
          break;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Badge icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    badge.rarityColor.withOpacity(isUnlocked ? 0.3 : 0.1),
                    badge.rarityColor.withOpacity(0.02),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: isUnlocked
                    ? [
                  BoxShadow(
                    color: badge.rarityColor.withOpacity(0.3),
                    blurRadius: 25,
                  ),
                ]
                    : null,
              ),
              child: Center(
                child: Text(
                  badge.emoji,
                  style: TextStyle(
                    fontSize: 52,
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Name
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // Info pills
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _detailPill(badge.rarityLabel, badge.rarityColor, isDark),
                _detailPill('+${badge.xpReward} XP', const Color(0xFFFFD700), isDark),
                _detailPill(badge.categoryLabel, AppConfig.primaryColor, isDark),
                _detailPill(
                  '${badge.threshold} ${badge.thresholdUnit}',
                  AppConfig.infoColor,
                  isDark,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Progress
            if (isUnlocked)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConfig.successColor.withOpacity(isDark ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConfig.successColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppConfig.successColor, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unlocked!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (unlockedAt != null)
                            Text(
                              'on ${unlockedAt.day}/${unlockedAt.month}/${unlockedAt.year}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_rounded,
                            color: isDark ? Colors.white38 : Colors.black26, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Progress: $progressText',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: badge.rarityColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          badge.rarityColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _detailPill(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}