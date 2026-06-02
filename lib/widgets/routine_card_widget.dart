// lib/widgets/routine_card_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/study_routine_model.dart';
import '../services/sound_service.dart';

class RoutineCardWidget extends StatelessWidget {
  final StudyRoutine routine;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDark;

  const RoutineCardWidget({
    super.key,
    required this.routine,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final routineColor = Color(routine.colorValue);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        SoundService.playTap();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              routineColor.withOpacity(0.15),
              routineColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: routineColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: routineColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      // Emoji Icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: routineColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: routineColor, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            routine.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Name & Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (routine.description != null && routine.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                routine.description!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Action Buttons
                      if (onEdit != null || onDelete != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: textColor),
                          color: surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (value) {
                            HapticFeedback.lightImpact();
                            if (value == 'edit' && onEdit != null) {
                              onEdit!();
                            } else if (value == 'delete' && onDelete != null) {
                              onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            if (onEdit != null)
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20, color: routineColor),
                                    const SizedBox(width: 12),
                                    Text('Edit', style: TextStyle(color: textColor)),
                                  ],
                                ),
                              ),
                            if (onDelete != null)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 20, color: Colors.red.shade400),
                                    const SizedBox(width: 12),
                                    Text('Delete', style: TextStyle(color: textColor)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Session Preview (First 3 sessions)
                  if (routine.sessions.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: routine.sessions.take(3).map((session) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(session.subjectColorValue).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(session.subjectColorValue).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(session.subjectColorValue),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                session.subjectName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    if (routine.sessions.length > 3) ...[
                      const SizedBox(height: 8),
                      Text(
                        '+${routine.sessions.length - 3} more sessions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatChip(
                        icon: Icons.timer_outlined,
                        label: routine.getFormattedDuration(),
                        color: routineColor,
                      ),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        icon: Icons.layers_outlined,
                        label: '${routine.sessions.length} sessions',
                        color: routineColor,
                      ),
                      const SizedBox(width: 12),
                      if (routine.timesCompleted > 0)
                        _buildStatChip(
                          icon: Icons.check_circle_outline,
                          label: '${routine.timesCompleted}x done',
                          color: const Color(0xFF10B981),
                        ),
                    ],
                  ),

                  // Auto-play & TTS Badges
                  if (routine.autoPlayEnabled || routine.ttsEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (routine.autoPlayEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  size: 14,
                                  color: const Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Auto-play',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (routine.autoPlayEnabled && routine.ttsEnabled)
                          const SizedBox(width: 8),
                        if (routine.ttsEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volume_up_outlined,
                                  size: 14,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Voice',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Active Indicator
            if (routine.isActive)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}