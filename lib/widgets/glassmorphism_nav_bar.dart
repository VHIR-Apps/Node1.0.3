// lib/widgets/glassmorphism_nav_bar.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../services/sound_service.dart';

class GlassmorphismNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddHabitTap;
  final VoidCallback onMenuTap;

  // 🆕 Tutorial Keys
  final GlobalKey? addButtonKey;
  final GlobalKey? moreButtonKey;

  const GlassmorphismNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.onAddHabitTap,
    required this.onMenuTap,
    this.addButtonKey, // 🆕
    this.moreButtonKey, // 🆕
  });

  @override
  State<GlassmorphismNavBar> createState() => _GlassmorphismNavBarState();
}

class _GlassmorphismNavBarState extends State<GlassmorphismNavBar>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _fabPulseController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _fabPulse;

  int _pressedIndex = -1;
  bool _fabPressed = false;
  bool _menuPressed = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fabPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabPulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _fabPulseController.dispose();
    super.dispose();
  }

  void _onItemTap(int index) {
    HapticFeedback.lightImpact();
    SoundService.playTap();
    widget.onTap(index);
  }

  void _onTapDown(int index) {
    setState(() => _pressedIndex = index);
  }

  void _onTapUp(int index) {
    setState(() => _pressedIndex = -1);
    _onItemTap(index);
  }

  void _onTapCancel() {
    setState(() => _pressedIndex = -1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SizedBox(
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      height: 68,
                      // 🛠️ FIXED: Reduced vertical padding to give items more room
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF151C2F).withOpacity(0.90)
                            : Colors.white.withOpacity(0.90),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.black.withOpacity(0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(isDark ? 0.35 : 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildNavItem(
                            index: 0,
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Home',
                            isDark: isDark,
                          ),
                          _buildNavItem(
                            index: 1,
                            icon: Icons.bar_chart_rounded,
                            activeIcon: Icons.bar_chart_rounded,
                            label: 'Stats',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 64),
                          _buildNavItem(
                            index: 2,
                            icon: Icons.emoji_events_outlined,
                            activeIcon: Icons.emoji_events_rounded,
                            label: 'Badges',
                            isDark: isDark,
                          ),
                          _buildMenuButton(isDark: isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: _buildCenterFab(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = widget.selectedIndex == index;
    final isPressed = _pressedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _onTapDown(index),
        onTapUp: (_) => _onTapUp(index),
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isPressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            // 🛠️ FIXED: Reduced vertical padding inside items
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppConfig.primaryColor.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            // 🛠️ FIXED: Added FittedBox to auto-scale items instead of overflowing
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      key: ValueKey('nav_icon_${index}_$isSelected'),
                      size: isSelected ? 24 : 22,
                      color: isSelected
                          ? AppConfig.primaryColor
                          : (isDark
                          ? Colors.white.withOpacity(0.50)
                          : Colors.black.withOpacity(0.40)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isSelected ? 10 : 9.5,
                      fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? AppConfig.primaryColor
                          : (isDark
                          ? Colors.white.withOpacity(0.42)
                          : Colors.black.withOpacity(0.35)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(top: 3),
                    width: isSelected ? 5 : 0,
                    height: isSelected ? 5 : 0,
                    decoration: BoxDecoration(
                      color: AppConfig.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: AppConfig.primaryColor.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ]
                          : [],
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

  Widget _buildCenterFab(bool isDark) {
    return AnimatedBuilder(
      animation: _fabPulseController,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_fabPulse.value * 0.15);

        return GestureDetector(
          key: widget.addButtonKey, // 🆕 Tutorial Key
          onTapDown: (_) => setState(() => _fabPressed = true),
          onTapUp: (_) {
            setState(() => _fabPressed = false);
            HapticFeedback.mediumImpact();
            SoundService.playTap();
            widget.onAddHabitTap();
          },
          onTapCancel: () => setState(() => _fabPressed = false),
          child: AnimatedScale(
            scale: _fabPressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A82FF), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppConfig.primaryColor.withOpacity(glowOpacity),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppConfig.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.6),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton({required bool isDark}) {
    return Expanded(
      child: GestureDetector(
        key: widget.moreButtonKey, // 🆕 Tutorial Key
        onTapDown: (_) => setState(() => _menuPressed = true),
        onTapUp: (_) {
          setState(() => _menuPressed = false);
          HapticFeedback.lightImpact();
          SoundService.playTap();
          widget.onMenuTap();
        },
        onTapCancel: () => setState(() => _menuPressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _menuPressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            // 🛠️ FIXED: Reduced padding here too
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            // 🛠️ FIXED: FittedBox added
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 20,
                      color: isDark
                          ? Colors.white.withOpacity(0.50)
                          : Colors.black.withOpacity(0.40),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withOpacity(0.42)
                          : Colors.black.withOpacity(0.35),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}