// lib/services/tutorial_service.dart

import 'package:flutter/material.dart';
import 'database_service.dart';

class TutorialService {
  static bool shouldShowTutorial() {
    return DatabaseService.isFirstLaunch();
  }

  static void showDashboardTutorial(BuildContext context, {
    required GlobalKey addButtonKey,
    required GlobalKey habitCardKey,
    required GlobalKey statsKey,
    required GlobalKey moreButtonKey,
    required GlobalKey notificationKey,
  }) {
    // Tutorial implementation can go here
    // For now, we just mark it as done
    DatabaseService.setFirstLaunchDone();
  }
}
