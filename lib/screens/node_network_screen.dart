// lib/screens/node_network_screen.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../models/habit_node_model.dart';
import '../services/badge_service.dart';
import '../services/database_service.dart';
import '../services/node_network_service.dart';
import '../services/sound_service.dart';
import '../widgets/node_network_painter.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// NODE NETWORK SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
//
// ✅ Interactive canvas — pan + zoom (InteractiveViewer)
// ✅ Tap node → shows habit detail sheet
// ✅ Tap complete → toggles habit, propagates energy flow
// ✅ Pulse + glow + flow particle animations
// ✅ Premium glassmorphism header
// ✅ No overflow — FittedBox / Expanded used where needed
// ✅ setState + ValueNotifier only
// ═══════════════════════════════════════════════════════════════════════════════

class NodeNetworkScreen extends StatefulWidget {
  const NodeNetworkScreen({super.key});

  @override
  State<NodeNetworkScreen> createState() => _NodeNetworkScreenState();
}

class _NodeNetworkScreenState extends State<NodeNetworkScreen>
    with TickerProviderStateMixin {
  // ── Graph data ──
  late HabitGraphModel _graph;
  String? _selectedNodeId;
  bool _isLoading = true;

  // ── Animation controllers ──
  late AnimationController _pulseController;
  late AnimationController _flowController;
  late AnimationController _glowController;
  late AnimationController _unlockController;
  late AnimationController _headerController;

  late Animation<double> _pulseAnim;
  late Animation<double> _flowAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _unlockAnim;
  late Animation<double> _headerAnim;

  // ── Interactive viewer ──
  final TransformationController _transformController =
  TransformationController();

  // ── Legend toggle ──
  bool _showLegend = false;

  // ── Completing state ──
  final Set<String> _completingNodes = {};

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadGraph();
  }

  // ─────────────────────────────────────────────
  // ANIMATIONS
  // ─────────────────────────────────────────────

  void _initAnimations() {
    // Pulse — node ring expand/contract
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Flow — energy particle moves along edges
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _flowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flowController, curve: Curves.linear),
    );

    // Glow — node breathe
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Unlock — flash when node completes
    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _unlockAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _unlockController, curve: Curves.easeOutCubic),
    );

    // Header slide in
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _headerAnim = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );
  }

  // ─────────────────────────────────────────────
  // GRAPH LOADING
  // ─────────────────────────────────────────────

  void _loadGraph() {
    setState(() => _isLoading = true);

    try {
      final graph = NodeNetworkService.buildGraph();
      setState(() {
        _graph = graph;
        _isLoading = false;
      });

      // Auto-center the graph
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerGraph();
      });
    } catch (e) {
      debugPrint('❌ NodeNetwork load error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _centerGraph() {
    if (!mounted) return;

    try {
      final bounds = NodeNetworkService.getGraphBounds(_graph);
      final screenSize = MediaQuery.of(context).size;

      final scaleX = screenSize.width / bounds.width;
      final scaleY = (screenSize.height * 0.78) / bounds.height;
      final scale = min(min(scaleX, scaleY), 1.0).clamp(0.35, 1.0);

      final translateX = (screenSize.width - bounds.width * scale) / 2 -
          bounds.left * scale;
      final translateY = 80.0;

      final matrix = Matrix4.identity()
        ..translate(translateX, translateY)
        ..scale(scale);

      _transformController.value = matrix;
    } catch (e) {
      debugPrint('⚠️ Center graph error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // NODE TAP
  // ─────────────────────────────────────────────

  void _handleCanvasTap(TapUpDetails details) {
    if (_isLoading) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(details.globalPosition);

    // Convert screen pos → canvas pos (account for transform)
    final matrix = _transformController.value;
    final inverse = Matrix4.inverted(matrix);
    final canvasPos = MatrixUtils.transformPoint(inverse, localPos);

    // Find tapped node (check within radius)
    String? tappedId;
    double closestDist = double.infinity;

    for (final node in _graph.allNodes) {
      final dist = (node.position - canvasPos).distance;
      if (dist <= node.radius + 12 && dist < closestDist) {
        closestDist = dist;
        tappedId = node.id;
      }
    }

    if (tappedId != null) {
      HapticFeedback.lightImpact();
      SoundService.playTap();
      setState(() => _selectedNodeId = tappedId);
      _showNodeDetailSheet(tappedId);
    } else {
      setState(() => _selectedNodeId = null);
    }
  }

  // ─────────────────────────────────────────────
  // HABIT COMPLETE
  // ─────────────────────────────────────────────

  Future<void> _completeHabit(HabitNodeModel node) async {
    if (_completingNodes.contains(node.id)) return;
    if (node.isLocked) {
      _showLockedSnack();
      return;
    }

    setState(() => _completingNodes.add(node.id));
    HapticFeedback.heavyImpact();
    SoundService.playHabitComplete();

    try {
      final habit = node.habit;

      if (!habit.isCompletedToday()) {
        if (habit.dailyGoal > 1) {
          habit.forceComplete();
        } else {
          habit.toggleComplete();
        }
        await DatabaseService.updateHabit(habit);
        await BadgeService.onHabitCompleted(habit);
      }

      // Animate energy unlock
      await _unlockController.forward(from: 0);

      // Refresh graph states
      NodeNetworkService.refreshNodeStates(_graph);

      setState(() {});
    } catch (e) {
      debugPrint('❌ Complete habit error: $e');
    } finally {
      setState(() => _completingNodes.remove(node.id));
    }
  }

  void _showLockedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Text('🔒', style: TextStyle(fontSize: 16)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete the previous habit first to unlock this!',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppConfig.warningColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NODE DETAIL SHEET
  // ─────────────────────────────────────────────

  void _showNodeDetailSheet(String nodeId) {
    final node = _graph.getNode(nodeId);
    if (node == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = node.nodeColor;
    final habit = node.habit;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151C2F) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Emoji + name row
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withOpacity(0.4),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            habit.emoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    habit.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.07)
                                        : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    node.type == HabitNodeType.root
                                        ? '⭐ Root'
                                        : node.type == HabitNodeType.sub
                                        ? '🔗 Sub'
                                        : '🍃 Leaf',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Stats row
                  Row(
                    children: [
                      _statChip(
                        emoji: '🔥',
                        label: 'Streak',
                        value: '${habit.currentStreak}d',
                        color: const Color(0xFFFF6A00),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _statChip(
                        emoji: '✅',
                        label: 'Total',
                        value: '${habit.totalCompletions}',
                        color: AppConfig.successColor,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _statChip(
                        emoji: '📊',
                        label: 'Weekly',
                        value:
                        '${habit.getWeeklyCompletionRate().toInt()}%',
                        color: AppConfig.infoColor,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  if (habit.description?.isNotEmpty == true)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        habit.description!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color:
                          isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  if (habit.description?.isNotEmpty == true)
                    const SizedBox(height: 16),

                  // Locked warning
                  if (node.isLocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppConfig.warningColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppConfig.warningColor.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text('🔒', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Complete the previous habit to unlock this node.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppConfig.warningColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (node.isLocked) const SizedBox(height: 16),

                  // Complete button
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton(
                        onPressed: node.isLocked
                            ? null
                            : () async {
                          Navigator.pop(context);
                          await _completeHabit(node);
                          _loadGraph();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: habit.isCompletedToday()
                              ? AppConfig.successColor
                              : color,
                          disabledBackgroundColor:
                          Colors.grey.withOpacity(0.3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                          const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              habit.isCompletedToday()
                                  ? Icons.check_circle_rounded
                                  : Icons.bolt_rounded,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              habit.isCompletedToday()
                                  ? 'Completed Today ✓'
                                  : 'Mark as Done',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statChip({
    required String emoji,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────

  @override
  void dispose() {
    _pulseController.dispose();
    _flowController.dispose();
    _glowController.dispose();
    _unlockController.dispose();
    _headerController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF080D1A) : const Color(0xFFF0F2FA),
      body: Stack(
        children: [
          // ── Background grid pattern ──
          Positioned.fill(child: _buildGridBackground(isDark)),

          // ── Main content ──
          Column(
            children: [
              // Header
              AnimatedBuilder(
                animation: _headerController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _headerAnim.value * 100),
                    child: child,
                  );
                },
                child: _buildHeader(isDark),
              ),

              // Canvas
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(isDark)
                    : _graph.nodes.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildNetworkCanvas(isDark),
              ),
            ],
          ),

          // ── Legend overlay ──
          if (_showLegend)
            Positioned(
              bottom: 100,
              right: 16,
              child: _buildLegend(isDark),
            ),

          // ── Completion stats FAB ──
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: _buildBottomStatsBar(isDark),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final completedCount = _isLoading ? 0 : _graph.completedNodes;
    final totalCount = _isLoading ? 0 : _graph.totalNodes;
    final percent =
    _isLoading ? 0.0 : _graph.completionPercent;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF111827), const Color(0xFF0D1224)]
              : [const Color(0xFF6C63FF), const Color(0xFF5B50F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppConfig.primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Node Network',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  '$completedCount of $totalCount nodes active',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Progress ring
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '${percent.toInt()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Legend toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showLegend = !_showLegend);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _showLegend
                    ? Icons.close_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Reset view
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _centerGraph();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CANVAS
  // ─────────────────────────────────────────────

  Widget _buildNetworkCanvas(bool isDark) {
    return GestureDetector(
      onTapUp: _handleCanvasTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.25,
        maxScale: 2.5,
        boundaryMargin: const EdgeInsets.all(200),
        constrained: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _flowController,
            _glowController,
          ]),
          builder: (context, _) {
            return SizedBox(
              width: _graph.canvasSize.width,
              height: _graph.canvasSize.height,
              child: CustomPaint(
                size: _graph.canvasSize,
                painter: NodeNetworkPainter(
                  graph: _graph,
                  pulseValue: _pulseAnim.value,
                  flowValue: _flowAnim.value,
                  glowValue: _glowAnim.value,
                  selectedNodeId: _selectedNodeId,
                  isDark: isDark,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BACKGROUND GRID
  // ─────────────────────────────────────────────

  Widget _buildGridBackground(bool isDark) {
    return CustomPaint(
      painter: _GridPainter(isDark: isDark),
    );
  }

  // ─────────────────────────────────────────────
  // BOTTOM STATS BAR
  // ─────────────────────────────────────────────

  Widget _buildBottomStatsBar(bool isDark) {
    if (_isLoading || _graph.nodes.isEmpty) return const SizedBox.shrink();

    final completed = _graph.completedNodes;
    final total = _graph.totalNodes;
    final roots =
        _graph.rootNodes.where((n) => n.isCompleted).length;
    final totalRoots = _graph.rootNodes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomStat(
              label: 'Nodes Done',
              value: '$completed/$total',
              color: AppConfig.successColor,
              isDark: isDark,
            ),
            _verticalDivider(isDark),
            _bottomStat(
              label: 'Roots Active',
              value: '$roots/$totalRoots',
              color: AppConfig.primaryColor,
              isDark: isDark,
            ),
            _verticalDivider(isDark),
            _bottomStat(
              label: 'Energy Flow',
              value: _graph.edges
                  .where((e) => e.isFlowing)
                  .length >
                  0
                  ? '⚡ Active'
                  : '— Idle',
              color: const Color(0xFFFFB300),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomStat({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 32,
      color: isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.08),
    );
  }

  // ─────────────────────────────────────────────
  // LEGEND
  // ─────────────────────────────────────────────

  Widget _buildLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151C2F).withOpacity(0.96)
            : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Legend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _legendItem(
            color: AppConfig.successColor,
            label: 'Completed node',
            isDark: isDark,
          ),
          _legendItem(
            color: AppConfig.primaryColor,
            label: 'Active (unlocked)',
            isDark: isDark,
          ),
          _legendItem(
            color: Colors.grey,
            label: 'Locked node',
            isDark: isDark,
          ),
          _legendItem(
            color: AppConfig.warningColor,
            label: 'Energy flowing',
            isDark: isDark,
            isFlow: true,
          ),
          const SizedBox(height: 4),
          Text(
            '⭐ = Root  🔗 = Sub  🍃 = Leaf',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
    required bool isDark,
    bool isFlow = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isFlow
              ? Container(
            width: 24,
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color,
                ],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          )
              : Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // EMPTY / LOADING
  // ─────────────────────────────────────────────

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppConfig.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Building your Node Network...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Text(
                '🕸️',
                style: TextStyle(fontSize: 60),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Nodes Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some habits on the Dashboard to see your Node Network come to life!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : Colors.grey[500],
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Habits',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRID BACKGROUND PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  final bool isDark;
  const _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.isDark != isDark;
}