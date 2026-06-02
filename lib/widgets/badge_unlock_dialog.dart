import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../models/badge_model.dart';
import '../services/sound_service.dart';

class BadgeUnlockDialog {
  static Future<void> show(BuildContext context, BadgeDefinition badge) async {
    HapticFeedback.heavyImpact();
    SoundService.playBadgeUnlock();

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Badge Unlock',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => _BadgeUnlockContent(badge: badge),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.elasticOut),
        );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5),
          ),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }
}

class _BadgeUnlockContent extends StatefulWidget {
  final BadgeDefinition badge;
  const _BadgeUnlockContent({required this.badge});

  @override
  State<_BadgeUnlockContent> createState() => _BadgeUnlockContentState();
}

class _BadgeUnlockContentState extends State<_BadgeUnlockContent>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _confettiController;
  late AnimationController _pulseController;
  late AnimationController _shineController;

  late Animation<double> _glow;
  late Animation<double> _pulse;
  late Animation<double> _shine;

  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _glow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shine = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.linear),
    );

    // Generate confetti particles
    for (int i = 0; i < 40; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble() * -1.0,
        speed: 0.3 + _random.nextDouble() * 0.7,
        size: 4 + _random.nextDouble() * 8,
        color: [
          widget.badge.rarityColor,
          AppConfig.primaryColor,
          const Color(0xFFFFD700),
          const Color(0xFFFF6B6B),
          const Color(0xFF00E676),
          const Color(0xFF00B0FF),
          Colors.purple,
          Colors.orange,
        ][_random.nextInt(8)],
        rotation: _random.nextDouble() * 360,
        rotationSpeed: -2.0 + _random.nextDouble() * 4.0,
        shape: _random.nextInt(3), // 0=circle, 1=square, 2=star
      ));
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = widget.badge;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),

          // Main dialog
          AnimatedBuilder(
            animation: Listenable.merge([_glowController, _pulseController, _shineController]),
            builder: (context, _) {
              return Transform.scale(
                scale: _pulse.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: badge.rarityColor.withOpacity(_glow.value),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: badge.rarityColor.withOpacity(_glow.value * 0.5),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: badge.rarityColor.withOpacity(_glow.value * 0.2),
                        blurRadius: 80,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: const [
                              Color(0xFFFFD700),
                              Color(0xFFFFA500),
                              Color(0xFFFFD700),
                            ],
                            stops: [
                              (_shine.value - 0.3).clamp(0.0, 1.0),
                              _shine.value.clamp(0.0, 1.0),
                              (_shine.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          '🎉 BADGE UNLOCKED!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Badge emoji with glow
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              badge.rarityColor.withOpacity(0.3),
                              badge.rarityColor.withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: badge.rarityColor.withOpacity(_glow.value * 0.6),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            badge.emoji,
                            style: const TextStyle(fontSize: 60),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Badge name
                      Text(
                        badge.name,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      // Description
                      Text(
                        badge.description,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Rarity + XP row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _infoPill(
                            badge.rarityLabel,
                            badge.rarityColor,
                            isDark,
                          ),
                          const SizedBox(width: 12),
                          _infoPill(
                            '+${badge.xpReward} XP',
                            const Color(0xFFFFD700),
                            isDark,
                          ),
                          const SizedBox(width: 12),
                          _infoPill(
                            badge.categoryLabel,
                            AppConfig.primaryColor,
                            isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: badge.rarityColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: badge.rarityColor.withOpacity(0.5),
                          ),
                          child: const Text(
                            'Awesome! 🎉',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// CONFETTI PARTICLE
// ═══════════════════════════════════════

class _ConfettiParticle {
  double x, y, speed, size, rotation, rotationSpeed;
  Color color;
  int shape;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = p.x * size.width;
      final y = (p.y + progress * p.speed * 2.0) * size.height;

      if (y > size.height || y < -50) continue;

      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withOpacity(opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((p.rotation + progress * p.rotationSpeed * 10) * pi / 180);

      switch (p.shape) {
        case 0: // Circle
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
          break;
        case 2: // Star shape (diamond)
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 3, 0)
            ..lineTo(0, p.size / 2)
            ..lineTo(-p.size / 3, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}