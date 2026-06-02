// lib/widgets/dashboard_action_buttons.dart
// NOTE: This widget is no longer used in dashboard.
// The Add Habit FAB is now part of GlassmorphismNavBar.
// Kept for backward compatibility.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sound_service.dart';

class DashboardActionButtons extends StatelessWidget {
  final VoidCallback onMissionsTap;
  final VoidCallback onAddHabitTap;

  const DashboardActionButtons({
    super.key,
    required this.onMissionsTap,
    required this.onAddHabitTap,
  });

  @override
  Widget build(BuildContext context) {
    // This widget is deprecated — functionality moved to nav bar + menu
    return const SizedBox.shrink();
  }
}