// lib/widgets/life_tree_widget.dart

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/badge_service.dart';
import '../services/database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEEDED RANDOM — প্রতি frame-এ নতুন Random() বানানো বন্ধ করে
// ─────────────────────────────────────────────────────────────────────────────

class _SeededRandom {
  final List<double> _values;

  _SeededRandom(int seed, int count)
      : _values = List.generate(count, (i) {
    return math.Random(seed + i * 997).nextDouble();
  });

  double operator [](int i) => _values[i % _values.length];
}

// Global pre-built tables (seed fixed, তাই প্রতিবার একই result)
final _canopyRng  = _SeededRandom(42, 64);
final _fruitRng   = _SeededRandom(7,  32);
final _flowerRng  = _SeededRandom(13, 32);
final _sparkleRng = _SeededRandom(99, 32);

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class LifeTreeWidget extends StatefulWidget {
  final int    xp;
  final int    level;
  final int    bestStreak;
  final int    totalStudyMinutes;
  final double todayCompletionRate;
  final double width;
  final double height;

  const LifeTreeWidget({
    super.key,
    required this.xp,
    required this.level,
    required this.bestStreak,
    required this.totalStudyMinutes,
    required this.todayCompletionRate,
    this.width  = 200,
    this.height = 220,
  });

  /// Dashboard থেকে শুধু এটা call করলেই হবে — data নিজে নেয়
  factory LifeTreeWidget.fromServices({
    Key?   key,
    double width  = 200,
    double height = 220,
  }) {
    final xp    = BadgeService.getXp();
    final level = BadgeService.getLevel();

    int    bestStreak    = 0;
    int    completedToday = 0;
    int    totalHabits   = 0;

    try {
      final habits = DatabaseService.getAllHabits();
      totalHabits  = habits.length;
      for (final h in habits) {
        if (h.bestStreak > bestStreak) bestStreak = h.bestStreak;
        if (h.isCompletedToday()) completedToday++;
      }
    } catch (_) {}

    final todayRate =
    totalHabits > 0 ? (completedToday / totalHabits) : 0.0;

    return LifeTreeWidget(
      key:                 key,
      xp:                  xp,
      level:               level,
      bestStreak:          bestStreak,
      totalStudyMinutes:   DatabaseService.getTotalStudyMinutesAllTime(),
      todayCompletionRate: todayRate.clamp(0.0, 1.0),
      width:               width,
      height:              height,
    );
  }

  @override
  State<LifeTreeWidget> createState() => _LifeTreeWidgetState();
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE — 4টা AnimationController
// ─────────────────────────────────────────────────────────────────────────────

class _LifeTreeWidgetState extends State<LifeTreeWidget>
    with TickerProviderStateMixin {

  late final AnimationController _swayCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _fruitCtrl;
  late final AnimationController _growthCtrl;

  late final Animation<double> _swayAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fruitAnim;
  late final Animation<double> _growthAnim;

  late double _health;
  double _prevHealth = -1.0;

  @override
  void initState() {
    super.initState();
    _health = _computeHealth();
    _prevHealth = _health;

    // 🌬️ Wind sway
    _swayCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _swayAnim = Tween<double>(begin: -0.030, end: 0.030).animate(
      CurvedAnimation(parent: _swayCtrl, curve: Curves.easeInOut),
    );

    // 💚 Leaf pulse
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // 🍎 Fruit bob
    _fruitCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _fruitAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fruitCtrl, curve: Curves.easeInOut),
    );

    // 🌱 Growth burst (health change এ একবার চলে)
    _growthCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _growthAnim = CurvedAnimation(
      parent: _growthCtrl,
      curve:  Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(LifeTreeWidget old) {
    super.didUpdateWidget(old);
    final newH = _computeHealth();
    if ((_prevHealth - newH).abs() > 0.02) {
      _growthCtrl.forward(from: 0.0);
      setState(() {
        _health    = newH;
        _prevHealth = newH;
      });
    }
  }

  @override
  void dispose() {
    _swayCtrl.dispose();
    _pulseCtrl.dispose();
    _fruitCtrl.dispose();
    _growthCtrl.dispose();
    super.dispose();
  }

  // ── Health formula ────────────────────────────────────────────────────────
  double _computeHealth() {
    final levelScore  = (widget.level / 20.0).clamp(0.0, 1.0);
    final streakScore = (widget.bestStreak / 100.0).clamp(0.0, 1.0);
    final studyScore  = (widget.totalStudyMinutes / 3000.0).clamp(0.0, 1.0);
    final habitScore  = widget.todayCompletionRate.clamp(0.0, 1.0);

    return ((levelScore  * 0.35) +
        (streakScore * 0.25) +
        (studyScore  * 0.20) +
        (habitScore  * 0.20))
        .clamp(0.0, 1.0);
  }

  // ── Stage labels ──────────────────────────────────────────────────────────
  static String _label(double h) {
    if (h < 0.15) return 'Seedling 🌱';
    if (h < 0.35) return 'Sapling 🌿';
    if (h < 0.55) return 'Young Tree 🌳';
    if (h < 0.75) return 'Mature Tree 🌲';
    return 'Ancient Tree 🌴';
  }

  static Color _labelColor(double h) {
    if (h < 0.15) return const Color(0xFF86EFAC);
    if (h < 0.35) return const Color(0xFF4ADE80);
    if (h < 0.55) return const Color(0xFF22C55E);
    if (h < 0.75) return const Color(0xFF16A34A);
    return const Color(0xFFFFD700);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tree canvas — RepaintBoundary দিয়ে isolate করা
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge(
                [_swayAnim, _pulseAnim, _fruitAnim, _growthAnim]),
            builder: (_, __) => CustomPaint(
              size: Size(widget.width, widget.height),
              painter: LifeTreePainter(
                health:      _health,
                swayAngle:   _swayAnim.value,
                pulseScale:  _pulseAnim.value,
                fruitPhase:  _fruitAnim.value,
                growthScale: 0.85 + (_growthAnim.value * 0.20),
              ),
            ),
          ),
        ),

        const SizedBox(height: 5),

        // Stage label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _label(_health),
            key: ValueKey(_label(_health)),
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w800,
              color:      _labelColor(_health),
              letterSpacing: 0.3,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Health bar
        SizedBox(
          width:  widget.width * 0.75,
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // Track
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: _health,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _labelColor(_health).withOpacity(0.75),
                          _labelColor(_health),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color:      _labelColor(_health).withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class LifeTreePainter extends CustomPainter {
  final double health;
  final double swayAngle;
  final double pulseScale;
  final double fruitPhase;
  final double growthScale;

  LifeTreePainter({
    required this.health,
    required this.swayAngle,
    required this.pulseScale,
    required this.fruitPhase,
    required this.growthScale,
  });

  // ── Stage ──────────────────────────────────────────────────────────────────
  bool get _isSeedling => health < 0.15;
  bool get _isSapling  => health >= 0.15 && health < 0.35;
  bool get _isYoung    => health >= 0.35 && health < 0.55;
  bool get _isMature   => health >= 0.55 && health < 0.75;
  bool get _isAncient  => health >= 0.75;

  // ── Trunk colours (fixed) ──────────────────────────────────────────────────
  static const _trunkDark  = Color(0xFF78350F);
  static const _trunkLight = Color(0xFFA16207);

  // ── Leaf colour — health দিয়ে ধীরে ধীরে বদলায় ──────────────────────────
  //   health 1.0 → গাঢ় সবুজ
  //   health 0.5 → হলুদ-সবুজ
  //   health 0.15 → ধূসর
  //   health 0.0 → ছাই রঙ
  Color get _leafColor {
    if (health > 0.5) {
      final t = ((health - 0.5) / 0.5).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFBEF264), // হলুদ-সবুজ
        const Color(0xFF15803D), // গাঢ় সবুজ
        t,
      )!;
    } else if (health > 0.15) {
      final t = ((health - 0.15) / 0.35).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFF9CA3AF), // ধূসর (অসুস্থ)
        const Color(0xFFFBBF24), // হলুদ-কমলা (মাঝামাঝি)
        t,
      )!;
    }
    return const Color(0xFF6B7280); // ছাই (মরা)
  }

  Color get _leafHighlight {
    if (health > 0.5) {
      final t = ((health - 0.5) / 0.5).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFD9F99D),
        const Color(0xFF4ADE80),
        t,
      )!;
    } else if (health > 0.15) {
      final t = ((health - 0.15) / 0.35).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFD1D5DB),
        const Color(0xFFFDE68A),
        t,
      )!;
    }
    return const Color(0xFF9CA3AF);
  }

  // অসুস্থ গাছ — ডাল নিচের দিকে ঝুলে
  double get _droop => (1.0 - health) * 0.40;

  // পাতার ঘনত্ব — মরা গাছে কম পাতা
  double get _density => health.clamp(0.15, 1.0);

  Color get _fruitColor {
    if (_isAncient) return const Color(0xFFFFD700);
    if (_isMature)  return const Color(0xFFEF4444);
    return const Color(0xFFF97316);
  }

  Color get _flowerColor =>
      _isAncient ? const Color(0xFFF0ABFC) : const Color(0xFFFBCFE8);

  // ─────────────────────────────────────────────────────────────────────────
  // PAINT
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cx      = size.width / 2;
    final groundY = size.height - 10.0;

    // Growth burst — নিচে-কেন্দ্র pivot
    canvas.save();
    canvas.translate(cx, groundY);
    canvas.scale(growthScale, growthScale);
    canvas.translate(-cx, -groundY);

    _drawGround(canvas, cx, groundY);

    if (_isSeedling)     _drawSeedling(canvas, cx, groundY);
    else if (_isSapling) _drawSapling(canvas, cx, groundY);
    else if (_isYoung)   _drawYoung(canvas, cx, groundY);
    else if (_isMature)  _drawMature(canvas, cx, groundY);
    else                 _drawAncient(canvas, cx, groundY);

    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GROUND SHADOW
  // ─────────────────────────────────────────────────────────────────────────

  void _drawGround(Canvas canvas, double cx, double groundY) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 4),
        width:  96,
        height: 20,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, groundY + 4),
          55,
          [
            const Color(0xFF166534).withOpacity(0.55),
            const Color(0xFF14532D).withOpacity(0.0),
          ],
          [0.0, 1.0],
        ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 1 — SEEDLING
  // ─────────────────────────────────────────────────────────────────────────

  void _drawSeedling(Canvas canvas, double cx, double groundY) {
    final stemH = 28.0 + health * 60;

    // সুস্থতা অনুযায়ী stem রঙ
    final stemColor = Color.lerp(
      const Color(0xFF6B7280),
      const Color(0xFF4ADE80),
      (health / 0.15).clamp(0.0, 1.0),
    )!;

    // সুস্থতা অনুযায়ী sway — মরা গাছ বেশি দুলবে না
    canvas.save();
    canvas.translate(cx, groundY - stemH / 2);
    canvas.rotate(swayAngle);
    canvas.translate(-cx, -(groundY - stemH / 2));

    // Stem
    canvas.drawLine(
      Offset(cx, groundY),
      Offset(cx, groundY - stemH),
      Paint()
        ..color       = stemColor
        ..strokeWidth = 3.0
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke,
    );

    // ২টি ছোট পাতা
    _ovalLeaf(canvas,
      center: Offset(cx - 11, groundY - stemH + 8),
      w: 13 * pulseScale, h: 20 * pulseScale,
      angle: -0.45,
    );
    _ovalLeaf(canvas,
      center: Offset(cx + 11, groundY - stemH + 12),
      w: 13 * pulseScale, h: 20 * pulseScale,
      angle: 0.45,
    );

    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 2 — SAPLING
  // ─────────────────────────────────────────────────────────────────────────

  void _drawSapling(Canvas canvas, double cx, double groundY) {
    final trunkH = 55.0 + health * 30;

    canvas.save();
    canvas.translate(cx, groundY - trunkH / 2);
    canvas.rotate(swayAngle * 0.8);
    canvas.translate(-cx, -(groundY - trunkH / 2));

    _trunk(canvas, cx, groundY, trunkH, 7.0);

    // ২টি ডাল
    _branch(canvas,
      start: Offset(cx, groundY - trunkH * 0.55),
      angle: -0.70 + _droop, len: 22, w: 3.0,
    );
    _branch(canvas,
      start: Offset(cx, groundY - trunkH * 0.65),
      angle:  0.70 - _droop, len: 22, w: 3.0,
    );

    // ছোট canopy
    final cc = Offset(cx, groundY - trunkH - 16);
    _canopy(canvas,
      center: cc,
      count:    (_density * 6).round().clamp(2, 6),
      radius:   20, leafSize: 16,
    );

    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 3 — YOUNG
  // ─────────────────────────────────────────────────────────────────────────

  void _drawYoung(Canvas canvas, double cx, double groundY) {
    const trunkH = 74.0;

    canvas.save();
    canvas.translate(cx, groundY - trunkH / 2);
    canvas.rotate(swayAngle * 0.65);
    canvas.translate(-cx, -(groundY - trunkH / 2));

    _trunk(canvas, cx, groundY, trunkH, 11.0);

    // ৩ জোড়া ডাল
    for (int i = 0; i < 3; i++) {
      final t = 0.45 + i * 0.15;
      final a = 0.52 + i * 0.15;
      _branch(canvas,
        start: Offset(cx, groundY - trunkH * t),
        angle: -(a) + _droop, len: 28.0 - i * 4, w: 4.2 - i * 0.5,
      );
      _branch(canvas,
        start: Offset(cx, groundY - trunkH * t),
        angle:   a  - _droop, len: 28.0 - i * 4, w: 4.2 - i * 0.5,
      );
    }

    final cc = Offset(cx, groundY - trunkH - 26);
    _canopy(canvas,
      center:   cc,
      count:    (_density * 9).round().clamp(3, 9),
      radius:   30, leafSize: 22,
    );

    if (health > 0.38) {
      _fruits(canvas, center: cc, count: 3, spread: 22, radius: 5);
    }

    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 4 — MATURE
  // ─────────────────────────────────────────────────────────────────────────

  void _drawMature(Canvas canvas, double cx, double groundY) {
    const trunkH = 90.0;

    canvas.save();
    canvas.translate(cx, groundY - trunkH / 2);
    canvas.rotate(swayAngle * 0.48);
    canvas.translate(-cx, -(groundY - trunkH / 2));

    _trunk(canvas, cx, groundY, trunkH, 15.0);

    // ৪ জোড়া ডাল
    for (int i = 0; i < 4; i++) {
      final t = 0.35 + i * 0.15;
      final a = 0.46 + i * 0.11;
      _branch(canvas,
        start: Offset(cx, groundY - trunkH * t),
        angle: -(a) + _droop, len: 36.0 - i * 5, w: 5.2 - i * 0.7,
      );
      _branch(canvas,
        start: Offset(cx, groundY - trunkH * t),
        angle:   a  - _droop, len: 36.0 - i * 5, w: 5.2 - i * 0.7,
      );
    }

    final cc = Offset(cx, groundY - trunkH - 34);
    _canopy(canvas,
      center:   cc,
      count:    (_density * 12).round().clamp(4, 12),
      radius:   40, leafSize: 28,
    );

    if (health > 0.56) {
      _fruits(canvas,  center: cc, count: 6, spread: 32, radius: 6);
      _flowers(canvas, center: cc, count: 5, spread: 26);
    }

    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 5 — ANCIENT
  // ─────────────────────────────────────────────────────────────────────────

  void _drawAncient(Canvas canvas, double cx, double groundY) {
    const trunkH = 112.0;

    canvas.save();
    canvas.translate(cx, groundY - trunkH / 2);
    canvas.rotate(swayAngle * 0.30);
    canvas.translate(-cx, -(groundY - trunkH / 2));

    _trunk(canvas, cx, groundY, trunkH, 19.0);
    _rootFlares(canvas, cx, groundY, 19.0);

    // ৫ জোড়া ডাল
    for (int i = 0; i < 5; i++) {
      final t = 0.28 + i * 0.13;
      final a = 0.40 + i * 0.10;
      _branch(canvas,
        start: Offset(cx, groundY - trunkH * t),
        angle: -(a) + _droop, len: 44.0 - i * 5, w: 6.0 - i * 0.8,
      );
      _branch(canvas,
        start: Offset(cx, groundY - trunkH * t),
        angle:   a  - _droop, len: 44.0 - i * 5, w: 6.0 - i * 0.8,
      );
    }

    final cc = Offset(cx, groundY - trunkH - 42);

    // পেছনের (গাঢ়) স্তর
    _canopy(canvas,
      center:          Offset(cx, cc.dy + 10),
      count:           8, radius: 48, leafSize: 32,
      colorOverride:   const Color(0xFF14532D),
      hlOverride:      const Color(0xFF166534),
    );

    // মূল স্তর
    _canopy(canvas,
      center: cc, count: (_density * 14).round().clamp(5, 14),
      radius: 44, leafSize: 30,
    );

    // উপরের উজ্জ্বল স্তর
    _canopy(canvas,
      center:        Offset(cx, cc.dy - 16),
      count:         (_density * 6).round().clamp(2, 7),
      radius:        22, leafSize: 20,
      colorOverride: _leafHighlight,
      hlOverride:    Colors.white.withOpacity(0.35),
    );

    // সোনালি ফল + ফুল + তারা
    _fruits(canvas,  center: cc, count: 9, spread: 38, radius: 7, glow: true);
    _flowers(canvas, center: cc, count: 7, spread: 32);
    _sparkles(canvas, cc);

    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMITIVES
  // ─────────────────────────────────────────────────────────────────────────

  /// Tapered trunk with 3D gradient + bark lines
  void _trunk(Canvas canvas, double cx, double groundY,
      double h, double w) {
    final hW  = w / 2;
    final tW  = hW * 0.42; // উপরের অংশ সরু
    final rect = Rect.fromLTWH(cx - hW, groundY - h, w, h);

    final path = Path()
      ..moveTo(cx - hW, groundY)
      ..cubicTo(cx - hW, groundY - h * 0.40,
          cx - tW,  groundY - h * 0.72,
          cx - tW * 0.80, groundY - h)
      ..lineTo(cx + tW * 0.80, groundY - h)
      ..cubicTo(cx + tW,  groundY - h * 0.72,
          cx + hW, groundY - h * 0.40,
          cx + hW, groundY)
      ..close();

    // Main fill
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - hW, 0), Offset(cx + hW, 0),
          [_trunkLight, _trunkDark, _trunkDark],
          [0.0, 0.55, 1.0],
        ),
    );

    // Highlight stripe (cylinder illusion)
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - hW * 0.6, 0), Offset(cx - hW * 0.1, 0),
          [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.0)],
        )
        ..blendMode = BlendMode.plus,
    );

    // Bark lines
    final barkP = Paint()
      ..color       = _trunkDark.withOpacity(0.38)
      ..strokeWidth = 1.1
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    for (int i = 1; i <= 4; i++) {
      final y = groundY - h * (0.18 * i);
      canvas.drawLine(
        Offset(cx - hW * 0.65, y),
        Offset(cx + hW * 0.40, y - 4),
        barkP,
      );
    }
  }

  /// Root flares — গাছের গোড়ায় মোটা শিকড়
  void _rootFlares(Canvas canvas, double cx, double groundY, double trunkW) {
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(cx + side * trunkW / 2, groundY - 14)
        ..quadraticBezierTo(
          cx + side * (trunkW / 2 + 20), groundY - 5,
          cx + side * (trunkW / 2 + 30), groundY,
        )
        ..lineTo(cx + side * trunkW / 2, groundY)
        ..close();
      canvas.drawPath(path, Paint()..color = _trunkDark);
    }
  }

  /// Single bezier branch
  /// angle = 0 → সোজা উপরে, positive → ডানে, negative → বামে
  void _branch(Canvas canvas, {
    required Offset start,
    required double angle,
    required double len,
    required double w,
  }) {
    final end = Offset(
      start.dx + math.sin(angle) * len,
      start.dy - math.cos(angle) * len,  // উপরে যাওয়ার জন্য বিয়োগ
    );
    final ctrl = Offset(
      (start.dx + end.dx) / 2 + math.cos(angle) * 7,
      (start.dy + end.dy) / 2,
    );

    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
      Paint()
        ..color       = _trunkDark
        ..strokeWidth = w
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke,
    );
  }

  /// Canopy — গোল পাতার cluster
  void _canopy(Canvas canvas, {
    required Offset center,
    required int count,
    required double radius,
    required double leafSize,
    Color? colorOverride,
    Color? hlOverride,
  }) {
    final base = colorOverride ?? _leafColor;
    final hl   = hlOverride   ?? _leafHighlight;

    for (int i = 0; i < count; i++) {
      final rA = _canopyRng[i * 2];
      final rB = _canopyRng[i * 2 + 1];

      final angle = (i / count) * math.pi * 2;
      final r     = radius * (0.55 + rA * 0.45);
      final lx    = center.dx + math.cos(angle) * r;
      final ly    = center.dy + math.sin(angle) * r * 0.58;
      final sz    = leafSize * (0.72 + rB * 0.55) * pulseScale;

      // Shadow
      canvas.drawCircle(
        Offset(lx, ly + 3),
        sz * 0.58,
        Paint()
          ..color      = base.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // Leaf blob
      canvas.drawCircle(
        Offset(lx, ly), sz,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(lx - sz * 0.25, ly - sz * 0.25), sz,
            [hl, base], [0.0, 1.0],
          ),
      );
    }

    // Centre cluster
    final cs = leafSize * pulseScale;
    canvas.drawCircle(
      center, cs,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.dx - cs * 0.2, center.dy - cs * 0.2), cs,
          [hl.withOpacity(0.9), base], [0.0, 1.0],
        ),
    );
  }

  /// Oval leaf — Seedling stage-এ ব্যবহার হয়
  void _ovalLeaf(Canvas canvas, {
    required Offset center,
    required double w, required double h,
    required double angle,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final rect = Rect.fromCenter(
      center: Offset.zero, width: w, height: h,
    );

    canvas.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -h / 2), Offset(0, h / 2),
          [_leafHighlight, _leafColor],
        ),
    );

    // Midrib
    canvas.drawLine(
      Offset(0, -h / 2 + 2), Offset(0, h / 2 - 2),
      Paint()
        ..color       = _leafColor.withOpacity(0.55)
        ..strokeWidth = 0.8
        ..style       = PaintingStyle.stroke,
    );

    canvas.restore();
  }

  /// Fruits — ফল আঁকে, bobbing animation সহ
  void _fruits(Canvas canvas, {
    required Offset center,
    required int    count,
    required double spread,
    required double radius,
    bool            glow = false,
  }) {
    final fc = _fruitColor;

    for (int i = 0; i < count; i++) {
      final rA  = _fruitRng[i * 2];
      final rB  = _fruitRng[i * 2 + 1];
      final ang = (i / count) * math.pi * 2 + fruitPhase * 0.25;
      final r   = spread * (0.45 + rA * 0.55);
      final fx  = center.dx + math.cos(ang) * r;
      final fy  = center.dy + math.sin(ang) * r * 0.62;
      final bob = math.sin(fruitPhase * math.pi * 2 + i * 1.1 + rB * 2) * 2.2;
      final pos = Offset(fx, fy + bob);

      if (glow) {
        canvas.drawCircle(
          pos, radius + 3,
          Paint()
            ..color      = fc.withOpacity(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      canvas.drawCircle(
        pos, radius,
        Paint()
          ..shader = ui.Gradient.radial(
            pos - Offset(radius * 0.3, radius * 0.4), radius * 1.2,
            [Color.lerp(fc, Colors.white, 0.45)!, fc],
            [0.0, 1.0],
          ),
      );

      // Stem
      canvas.drawLine(
        Offset(fx, fy + bob - radius),
        Offset(fx - 2, fy + bob - radius - 5),
        Paint()
          ..color       = const Color(0xFF4ADE80)
          ..strokeWidth = 1.3
          ..strokeCap   = StrokeCap.round
          ..style       = PaintingStyle.stroke,
      );
    }
  }

  /// Flowers — ৫ পাপড়ির ফুল
  void _flowers(Canvas canvas, {
    required Offset center,
    required int    count,
    required double spread,
  }) {
    final fc = _flowerColor;

    for (int i = 0; i < count; i++) {
      final rA  = _flowerRng[i * 2];
      final rB  = _flowerRng[i * 2 + 1];
      final ang = (i / count) * math.pi * 2 + math.pi / count;
      final r   = spread * (0.55 + rA * 0.45);
      final fx  = center.dx + math.cos(ang) * r;
      final fy  = center.dy + math.sin(ang) * r * 0.58;
      final bob = math.sin(fruitPhase * math.pi * 2 + i * 1.5 + rB * 2) * 1.8;

      // ৫টি পাপড়ি
      final petalP = Paint()
        ..color = fc.withOpacity(0.88)
        ..style = PaintingStyle.fill;

      for (int p = 0; p < 5; p++) {
        final pa = (p / 5) * math.pi * 2;
        canvas.drawCircle(
          Offset(fx + math.cos(pa) * 4.2,
              fy + bob + math.sin(pa) * 4.2),
          3.8, petalP,
        );
      }

      // ফুলের মাঝখান
      canvas.drawCircle(
        Offset(fx, fy + bob), 2.8,
        Paint()..color = const Color(0xFFFDE68A),
      );
    }
  }

  /// Sparkles — Ancient tree-এর তারাখচিত জ্যোতি
  void _sparkles(Canvas canvas, Offset center) {
    for (int i = 0; i < 8; i++) {
      final rA = _sparkleRng[i * 2];
      final rB = _sparkleRng[i * 2 + 1];

      final ang    = (i / 8) * math.pi * 2;
      final r      = 44.0 + rA * 14;
      final sx     = center.dx + math.cos(ang) * r;
      final sy     = center.dy + math.sin(ang) * r * 0.68;
      final blink  = ((math.sin(fruitPhase * math.pi * 2
          + i * 0.85 + rB * 3) + 1) / 2)
          .clamp(0.0, 1.0);

      if (blink < 0.25) continue;

      final sz = 4.5 * blink;
      final p  = Paint()
        ..color       = const Color(0xFFFFD700).withOpacity(blink * 0.9)
        ..strokeWidth = 1.6
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke;

      // ৪টি বাহু
      for (int arm = 0; arm < 4; arm++) {
        final aa = arm * math.pi / 2;
        canvas.drawLine(
          Offset(sx, sy),
          Offset(sx + math.cos(aa) * sz, sy + math.sin(aa) * sz),
          p,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REPAINT GUARD — শুধু দরকারি হলেই repaint করে
  // ─────────────────────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(LifeTreePainter old) =>
      old.health      != health      ||
          old.swayAngle   != swayAngle   ||
          old.pulseScale  != pulseScale  ||
          old.fruitPhase  != fruitPhase  ||
          old.growthScale != growthScale;
}