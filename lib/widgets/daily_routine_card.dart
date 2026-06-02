// lib/widgets/daily_routine_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/daily_study_routine_model.dart';

class DailyRoutineCard extends StatelessWidget {
  final DailyStudyRoutine routine;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleActive;

  const DailyRoutineCard({
    super.key,
    required this.routine,
    required this.isDark,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF151C2F) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.grey.shade200.withOpacity(0.9);
    final routineColor = Color(routine.colorValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: isDark ? 10 : 0, sigmaY: isDark ? 10 : 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg.withOpacity(isDark ? 0.78 : 1.0),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: routineColor.withOpacity(isDark ? 0.16 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      routine.isActive ? Icons.event_repeat_rounded : Icons.pause_circle_outline_rounded,
                      color: routineColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (routine.description != null && routine.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            routine.description!,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${routine.blocks.length} blocks',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Actions: Switch and PopupMenu
                  if(onToggleActive != null)
                    Switch(
                      value: routine.isActive,
                      onChanged: onToggleActive,
                      activeColor: AppConfig.primaryColor,
                    ),

                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit?.call();
                      } else if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
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