// lib/models/habit_node_model.dart

import 'dart:ui';
import '../models/habit_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// NODE TYPE
// ═══════════════════════════════════════════════════════════════════════════════

enum HabitNodeType {
  root,
  sub,
  leaf,
}

// ═══════════════════════════════════════════════════════════════════════════════
// NODE STATE
// ═══════════════════════════════════════════════════════════════════════════════

enum HabitNodeState {
  inactive,
  active,
  pulsing,
  locked,
}

// ═══════════════════════════════════════════════════════════════════════════════
// HABIT NODE MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class HabitNodeModel {
  final String id;
  final Habit habit;
  final HabitNodeType type;
  HabitNodeState state;
  Offset position;
  final List<String> childIds;
  final List<String> parentIds;
  final double radius;
  final int depth;
  double pulseValue;
  double flowProgress;

  HabitNodeModel({
    required this.id,
    required this.habit,
    required this.type,
    required this.state,
    required this.position,
    required this.childIds,
    required this.parentIds,
    required this.depth,
    this.radius = 44.0,
    this.pulseValue = 0.0,
    this.flowProgress = 0.0,
  });

  Color get nodeColor => Color(habit.colorValue);

  bool get isCompleted => habit.isCompletedToday();

  bool get isLocked {
    if (type == HabitNodeType.root) return false;
    return state == HabitNodeState.locked;
  }

  String get shortName {
    final name = habit.name;
    if (name.length <= 14) return name;
    return '${name.substring(0, 12)}…';
  }

  @override
  String toString() =>
      'HabitNodeModel(id=$id, type=$type, state=$state, depth=$depth)';
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDGE MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class HabitEdgeModel {
  final String fromId;
  final String toId;
  bool isFlowing;
  double litProgress;
  final Color flowColor;

  HabitEdgeModel({
    required this.fromId,
    required this.toId,
    this.isFlowing = false,
    this.litProgress = 0.0,
    required this.flowColor,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRAPH MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class HabitGraphModel {
  final Map<String, HabitNodeModel> nodes;
  final List<HabitEdgeModel> edges;
  final Size canvasSize;

  const HabitGraphModel({
    required this.nodes,
    required this.edges,
    required this.canvasSize,
  });

  HabitNodeModel? getNode(String id) => nodes[id];

  List<HabitNodeModel> get rootNodes =>
      nodes.values
          .where((n) => n.type == HabitNodeType.root)
          .toList();

  List<HabitNodeModel> get allNodes => nodes.values.toList();

  List<HabitEdgeModel> edgesFrom(String nodeId) =>
      edges.where((e) => e.fromId == nodeId).toList();

  List<HabitEdgeModel> edgesTo(String nodeId) =>
      edges.where((e) => e.toId == nodeId).toList();

  int get totalNodes => nodes.length;

  int get completedNodes =>
      nodes.values.where((n) => n.isCompleted).length;

  double get completionPercent {
    if (totalNodes == 0) return 0;
    return (completedNodes / totalNodes) * 100;
  }
}