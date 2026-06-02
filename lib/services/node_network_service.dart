// lib/services/node_network_service.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/habit_model.dart';
import '../models/habit_node_model.dart';
import 'database_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// NODE NETWORK SERVICE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Responsibilities:
// ✅ Logic for Habit Stacking (Mapping Habits to Graph Nodes)
// ✅ Tree-based Layout Engine (Calculates coordinates)
// ✅ Dependency Resolution (Checks if parents are completed)
// ✅ No Persistence — Recomputes from Habit list in-memory
// ═══════════════════════════════════════════════════════════════════════════════

class NodeNetworkService {
  static const double nodeSpacingX = 220.0;
  static const double nodeSpacingY = 140.0;

  /// Builds the habit graph using current Database state.
  /// Categorizes habits:
  /// - High priority habits with no dependencies become Roots.
  /// - Habits in the same category naturally follow as Sub-nodes.
  static HabitGraphModel buildGraph() {
    final List<Habit> habits = DatabaseService.getAllHabits();
    if (habits.isEmpty) {
      return const HabitGraphModel(
        nodes: {},
        edges: [],
        canvasSize: Size(1000, 1000),
      );
    }

    final Map<String, HabitNodeModel> nodes = {};
    final List<HabitEdgeModel> edges = [];

    // 1. Group habits by Category for logical stacking
    final Map<String, List<Habit>> categoryGroups = {};
    for (var h in habits) {
      categoryGroups.putIfAbsent(h.category, () => []).add(h);
    }

    double maxY = 0;
    double currentX = 100.0;
    double currentY = 150.0;

    // 2. Iterate categories to build vertical stacks/trees
    categoryGroups.forEach((category, categoryHabits) {
      // Sort within category: priority first (Critical -> High -> Medium -> Low)
      categoryHabits.sort((a, b) {
        final p = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
        return (p[a.priority] ?? 2).compareTo(p[b.priority] ?? 2);
      });

      HabitNodeModel? previousNode;

      for (int i = 0; i < categoryHabits.length; i++) {
        final habit = categoryHabits[i];
        final type = (i == 0) ? HabitNodeType.root : HabitNodeType.sub;

        // Determine if locked
        // A node is locked if it's a sub-node and its parent isn't completed
        bool parentDone = true;
        if (previousNode != null) {
          parentDone = previousNode.habit.isCompletedToday();
        }

        final state = habit.isCompletedToday()
            ? HabitNodeState.active
            : (parentDone ? HabitNodeState.inactive : HabitNodeState.locked);

        final node = HabitNodeModel(
          id: habit.id,
          habit: habit,
          type: type,
          state: state,
          position: Offset(currentX, currentY + (i * nodeSpacingY)),
          childIds: [],
          parentIds: previousNode != null ? [previousNode.id] : [],
          depth: i,
        );

        nodes[node.id] = node;

        // 3. Create edges
        if (previousNode != null) {
          previousNode.childIds.add(node.id);

          edges.add(HabitEdgeModel(
            fromId: previousNode.id,
            toId: node.id,
            litProgress: previousNode.isCompleted ? 1.0 : 0.0,
            isFlowing: previousNode.isCompleted && !node.isCompleted,
            flowColor: Color(habit.colorValue),
          ));
        }

        previousNode = node;
        maxY = max(maxY, node.position.dy + 200);
      }

      currentX += nodeSpacingX;
    });

    return HabitGraphModel(
      nodes: nodes,
      edges: edges,
      canvasSize: Size(currentX + 200, maxY + 200),
    );
  }

  /// Refreshes node states based on a new completion event.
  /// Used for animations without re-building the whole layout.
  static void refreshNodeStates(HabitGraphModel graph) {
    for (var node in graph.nodes.values) {
      if (node.habit.isCompletedToday()) {
        node.state = HabitNodeState.active;
      } else {
        // Check parents
        bool allParentsDone = true;
        for (var pid in node.parentIds) {
          final parent = graph.getNode(pid);
          if (parent != null && !parent.habit.isCompletedToday()) {
            allParentsDone = false;
            break;
          }
        }
        node.state = allParentsDone ? HabitNodeState.inactive : HabitNodeState.locked;
      }
    }

    // Refresh edges
    for (var edge in graph.edges) {
      final from = graph.getNode(edge.fromId);
      final to = graph.getNode(edge.toId);
      if (from != null && to != null) {
        edge.litProgress = from.isCompleted ? 1.0 : 0.0;
        edge.isFlowing = from.isCompleted && !to.isCompleted;
      }
    }
  }

  /// Calculates the bounding box to keep graph centered
  static Rect getGraphBounds(HabitGraphModel graph) {
    if (graph.nodes.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var node in graph.nodes.values) {
      minX = min(minX, node.position.dx);
      minY = min(minY, node.position.dy);
      maxX = max(maxX, node.position.dx);
      maxY = max(maxY, node.position.dy);
    }

    return Rect.fromLTRB(minX - 100, minY - 100, maxX + 100, maxY + 100);
  }
}