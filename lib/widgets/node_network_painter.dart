// lib/widgets/node_network_painter.dart

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/habit_node_model.dart';

class NodeNetworkPainter extends CustomPainter {
  final HabitGraphModel graph;
  final double pulseValue;
  final double flowValue;
  final double glowValue;
  final String? selectedNodeId;
  final bool isDark;

  NodeNetworkPainter({
    required this.graph,
    required this.pulseValue,
    required this.flowValue,
    required this.glowValue,
    this.selectedNodeId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawAllEdges(canvas);
    _drawAllNodes(canvas);
    _drawAllLabels(canvas);
  }

  void _drawAllEdges(Canvas canvas) {
    for (final edge in graph.edges) {
      final fromNode = graph.getNode(edge.fromId);
      final toNode = graph.getNode(edge.toId);
      if (fromNode == null || toNode == null) continue;
      _drawEdge(canvas, edge, fromNode, toNode);
      if (edge.isFlowing) {
        _drawFlowParticle(canvas, edge, fromNode, toNode);
      }
    }
  }

  void _drawEdge(
      Canvas canvas,
      HabitEdgeModel edge,
      HabitNodeModel from,
      HabitNodeModel to,
      ) {
    final fromPos = from.position;
    final toPos = to.position;

    final basePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.08)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(fromPos, toPos, basePaint);

    if (edge.litProgress > 0) {
      final litEnd = Offset.lerp(fromPos, toPos, edge.litProgress)!;

      final litPaint = Paint()
        ..color = edge.flowColor.withOpacity(0.75)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawLine(fromPos, litEnd, litPaint);

      final crispPaint = Paint()
        ..color = edge.flowColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(fromPos, litEnd, crispPaint);
    }

    _drawArrow(canvas, fromPos, toPos, edge.flowColor, edge.litProgress);
  }

  void _drawArrow(
      Canvas canvas,
      Offset from,
      Offset to,
      Color color,
      double progress,
      ) {
    const arrowSize = 10.0;
    final angle = atan2(to.dy - from.dy, to.dx - from.dx);
    final tipPos = to;

    final arrowPath = Path()
      ..moveTo(tipPos.dx, tipPos.dy)
      ..lineTo(
        tipPos.dx - arrowSize * cos(angle - pi / 7),
        tipPos.dy - arrowSize * sin(angle - pi / 7),
      )
      ..lineTo(
        tipPos.dx - arrowSize * cos(angle + pi / 7),
        tipPos.dy - arrowSize * sin(angle + pi / 7),
      )
      ..close();

    final arrowPaint = Paint()
      ..color = color.withOpacity(progress > 0 ? 0.85 : 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawFlowParticle(
      Canvas canvas,
      HabitEdgeModel edge,
      HabitNodeModel from,
      HabitNodeModel to,
      ) {
    final t = (flowValue + edge.fromId.hashCode * 0.1) % 1.0;
    final particlePos = Offset.lerp(from.position, to.position, t)!;

    final glowPaint = Paint()
      ..color = edge.flowColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(particlePos, 10, glowPaint);

    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(particlePos, 4, corePaint);

    final tailStart =
    Offset.lerp(from.position, to.position, (t - 0.15).clamp(0.0, 1.0))!;

    final tailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          edge.flowColor.withOpacity(0),
          edge.flowColor.withOpacity(0.6),
        ],
      ).createShader(Rect.fromPoints(tailStart, particlePos))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(tailStart, particlePos, tailPaint);
  }

  void _drawAllNodes(Canvas canvas) {
    final inactive =
    graph.allNodes.where((n) => !n.isCompleted).toList();
    final active =
    graph.allNodes.where((n) => n.isCompleted).toList();

    for (final node in inactive) _drawNode(canvas, node);
    for (final node in active) _drawNode(canvas, node);
  }

  void _drawNode(Canvas canvas, HabitNodeModel node) {
    final pos = node.position;
    final color = node.nodeColor;
    final isSelected = node.id == selectedNodeId;
    final isCompleted = node.isCompleted;
    final isLocked = node.isLocked;

    if (isCompleted) {
      final glowRadius = node.radius + 14 + (glowValue * 8);
      final glowPaint = Paint()
        ..color = color.withOpacity(0.18 + glowValue * 0.14)
        ..maskFilter =
        MaskFilter.blur(BlurStyle.normal, glowRadius * 0.6);
      canvas.drawCircle(pos, glowRadius, glowPaint);
    }

    if (isSelected) {
      final selPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pos, node.radius + 10, selPaint);
    }

    if (isCompleted && !isLocked) {
      final pulseRadius = node.radius + 6 + (pulseValue * 16);
      final pulsePaint = Paint()
        ..color = color.withOpacity((1 - pulseValue) * 0.45)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, pulseRadius, pulsePaint);
    }

    final borderPaint = Paint()
      ..color = isCompleted
          ? color.withOpacity(0.9)
          : isLocked
          ? (isDark ? Colors.white12 : Colors.black12)
          : color.withOpacity(0.45)
      ..strokeWidth = isCompleted ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, node.radius, borderPaint);

    final fillColor = _nodeFillColor(node, color);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, node.radius - 1.5, fillPaint);

    if (node.type == HabitNodeType.root) {
      _drawRootIndicator(canvas, node, color, isCompleted);
    }

    if (isLocked) _drawLockIcon(canvas, pos);
    if (isCompleted) _drawCheckmark(canvas, pos, color);
    if (!isLocked) _drawEmoji(canvas, node, isCompleted);
  }

  Color _nodeFillColor(HabitNodeModel node, Color color) {
    if (node.isLocked) {
      return isDark
          ? const Color(0xFF1A1F2E)
          : const Color(0xFFEEEEEE);
    }
    if (node.isCompleted) {
      return Color.lerp(
        color.withOpacity(0.22),
        color.withOpacity(0.38),
        glowValue,
      )!;
    }
    return isDark
        ? Color.lerp(
      const Color(0xFF1A2235),
      color.withOpacity(0.08),
      0.5,
    )!
        : Color.lerp(Colors.white, color.withOpacity(0.06), 0.5)!;
  }

  void _drawRootIndicator(
      Canvas canvas,
      HabitNodeModel node,
      Color color,
      bool isCompleted,
      ) {
    final accentPaint = Paint()
      ..color = color.withOpacity(isCompleted ? 0.5 : 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashCount = 12;
    const angleStep = (2 * pi) / dashCount;
    final accentRadius = node.radius + 6.0;

    for (int i = 0; i < dashCount; i += 2) {
      final startAngle = i * angleStep;
      final endAngle = startAngle + angleStep * 0.6;
      final rect =
      Rect.fromCircle(center: node.position, radius: accentRadius);
      canvas.drawArc(
        rect,
        startAngle,
        endAngle - startAngle,
        false,
        accentPaint,
      );
    }
  }

  void _drawLockIcon(Canvas canvas, Offset pos) {
    final lockColor = isDark ? Colors.white30 : Colors.black26;

    final bodyPaint = Paint()
      ..color = lockColor
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pos.translate(0, 4),
        width: 18,
        height: 14,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    final shacklePaint = Paint()
      ..color = lockColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final shacklePath = Path()
      ..moveTo(pos.dx - 5, pos.dy + 2)
      ..lineTo(pos.dx - 5, pos.dy - 5)
      ..arcToPoint(
        Offset(pos.dx + 5, pos.dy - 5),
        radius: const Radius.circular(5),
        clockwise: false,
      )
      ..lineTo(pos.dx + 5, pos.dy + 2);

    canvas.drawPath(shacklePath, shacklePaint);
  }

  void _drawCheckmark(Canvas canvas, Offset pos, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final origin = pos.translate(14, 14);
    final path = Path()
      ..moveTo(origin.dx - 6, origin.dy)
      ..lineTo(origin.dx - 2, origin.dy + 4)
      ..lineTo(origin.dx + 6, origin.dy - 5);

    canvas.drawCircle(
      origin,
      10,
      Paint()
        ..color =
        (isDark ? const Color(0xFF0B1020) : Colors.white)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      origin,
      10,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawPath(path, paint);
  }

  void _drawEmoji(
      Canvas canvas,
      HabitNodeModel node,
      bool isCompleted,
      ) {
    final emoji = node.habit.emoji;
    final pos = node.position;
    final fontSize = isCompleted ? 30.0 : 26.0;

    // ── Use ui.ParagraphBuilder to avoid TextStyle conflict ──
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )..addText(emoji);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 60));

    canvas.drawParagraph(
      paragraph,
      Offset(pos.dx - 30, pos.dy - paragraph.height / 2),
    );
  }

  void _drawAllLabels(Canvas canvas) {
    for (final node in graph.allNodes) {
      _drawLabel(canvas, node);
    }
  }

  void _drawLabel(Canvas canvas, HabitNodeModel node) {
    final pos = node.position;
    final isCompleted = node.isCompleted;
    final isLocked = node.isLocked;
    final color = node.nodeColor;

    final textColor = isLocked
        ? (isDark ? Colors.white30 : Colors.black26)
        : isCompleted
        ? color
        : (isDark ? Colors.white70 : Colors.black87);

    // ── ui.ParagraphBuilder — avoids TextStyle conflict ──
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    )
      ..pushStyle(ui.TextStyle(color: textColor))
      ..addText(node.shortName);

    final paragraph = paragraphBuilder.build()
      ..layout(
        ui.ParagraphConstraints(width: node.radius * 2 + 40),
      );

    canvas.drawParagraph(
      paragraph,
      Offset(
        pos.dx - (node.radius + 20),
        pos.dy + node.radius + 8,
      ),
    );

    if (!isLocked && node.habit.currentStreak > 0) {
      _drawStreakBadge(canvas, node, isCompleted, color);
    }

    if (node.type == HabitNodeType.root) {
      _drawCategoryTag(canvas, node, color, isLocked);
    }
  }

  void _drawStreakBadge(
      Canvas canvas,
      HabitNodeModel node,
      bool isCompleted,
      Color color,
      ) {
    final streak = node.habit.currentStreak;
    final pos =
    node.position.translate(-node.radius - 4, -node.radius - 4);

    final bgPaint = Paint()
      ..color = isCompleted ? color : color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 36, height: 20),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    final badgeBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 10,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      )
      ..addText('🔥$streak');

    final badge = badgeBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 36));

    canvas.drawParagraph(
      badge,
      Offset(pos.dx - 18, pos.dy - badge.height / 2),
    );
  }

  void _drawCategoryTag(
      Canvas canvas,
      HabitNodeModel node,
      Color color,
      bool isLocked,
      ) {
    final pos = node.position.translate(0, -node.radius - 22);
    final category = node.habit.category;
    final tagColor =
    isLocked ? (isDark ? Colors.white24 : Colors.black26) : color;

    final tagPaint = Paint()
      ..color = tagColor.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    const tagW = 80.0;
    const tagH = 18.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: tagW, height: tagH),
        const Radius.circular(9),
      ),
      tagPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: tagW, height: tagH),
        const Radius.circular(9),
      ),
      Paint()
        ..color = tagColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final short = category.length > 10
        ? '${category.substring(0, 9)}…'
        : category;

    final tagBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 9.5,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: tagColor,
          fontWeight: FontWeight.w800,
        ),
      )
      ..addText(short.toUpperCase());

    final tagPara = tagBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: tagW));

    canvas.drawParagraph(
      tagPara,
      Offset(pos.dx - tagW / 2, pos.dy - tagPara.height / 2),
    );
  }

  @override
  bool shouldRepaint(NodeNetworkPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.flowValue != flowValue ||
        oldDelegate.glowValue != glowValue ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.graph != graph ||
        oldDelegate.isDark != isDark;
  }
}