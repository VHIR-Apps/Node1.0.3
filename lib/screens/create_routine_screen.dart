// lib/screens/create_routine_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../models/study_routine_model.dart';
import '../services/database_service.dart';
import '../services/sound_service.dart';

class CreateRoutineScreen extends StatefulWidget {
  final StudyRoutine? editRoutine;

  const CreateRoutineScreen({super.key, this.editRoutine});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<RoutineSession> _sessions = [];
  bool _autoPlayEnabled = true;
  bool _ttsEnabled = true;
  String _selectedEmoji = '📚';
  Color _selectedColor = const Color(0xFF6C63FF);

  bool isDark = false;

  final List<String> _emojiList = [
    '📚', '📖', '✏️', '🎓', '🧠', '💡', '🔬', '📝',
    '🎯', '🏆', '⭐', '🔥', '💪', '🚀', '⚡', '✨'
  ];

  final List<Color> _colorList = [
    const Color(0xFF6C63FF), // Purple
    const Color(0xFFEF4444), // Red
    const Color(0xFF10B981), // Green
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFF59E0B), // Orange
    const Color(0xFFEC4899), // Pink
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFF06B6D4), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editRoutine != null) {
      _loadExistingRoutine();
    } else {
      _addDefaultSession();
    }
  }

  void _loadExistingRoutine() {
    final routine = widget.editRoutine!;
    _nameController.text = routine.name;
    _descriptionController.text = routine.description ?? '';
    _sessions = List.from(routine.sessions);
    _autoPlayEnabled = routine.autoPlayEnabled;
    _ttsEnabled = routine.ttsEnabled;
    _selectedEmoji = routine.emoji;
    _selectedColor = Color(routine.colorValue);
  }

  void _addDefaultSession() {
    _sessions.add(RoutineSession(
      subjectName: 'Math',
      subjectColorValue: AppConfig.predefinedSubjects['Math']!.value,
      durationMinutes: 25,
      includeBreak: true,
      breakDurationMinutes: 5,
      order: _sessions.length,
      emoji: '🔢',
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isDark = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addSession() {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    setState(() {
      _sessions.add(RoutineSession(
        subjectName: 'Other',
        subjectColorValue: AppConfig.predefinedSubjects['Other']!.value,
        durationMinutes: 25,
        includeBreak: true,
        breakDurationMinutes: 5,
        order: _sessions.length,
        emoji: '📖',
      ));
    });
  }

  void _removeSession(int index) {
    if (_sessions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one session is required')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    SoundService.playTap();

    setState(() {
      _sessions.removeAt(index);
      for (int i = 0; i < _sessions.length; i++) {
        _sessions[i] = _sessions[i].copyWith(order: i);
      }
    });
  }

  void _editSession(int index) {
    HapticFeedback.lightImpact();
    _showSessionEditor(index);
  }

  void _showSessionEditor(int index) {
    final session = _sessions[index];

    String selectedSubject = session.subjectName;
    Color selectedColor = Color(session.subjectColorValue);
    int focusMins = session.durationMinutes;
    int breakMins = session.breakDurationMinutes;
    bool includeBreak = session.includeBreak;
    String emoji = session.emoji;
    String customMessage = session.customMessage ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text(
                          'Edit Session ${index + 1}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subject Selection
                          _buildSectionTitle('Subject'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: AppConfig.predefinedSubjects.entries.map((entry) {
                              final isSelected = selectedSubject == entry.key;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setModalState(() {
                                    selectedSubject = entry.key;
                                    selectedColor = entry.value;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? entry.value.withOpacity(0.2)
                                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                                    border: Border.all(
                                      color: isSelected ? entry.value : Colors.transparent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: entry.value,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          // Focus Duration
                          _buildSectionTitle('Focus Duration (minutes)'),
                          const SizedBox(height: 12),
                          _buildDurationSlider(
                            value: focusMins,
                            min: 5,
                            max: 120,
                            color: selectedColor,
                            onChanged: (val) {
                              setModalState(() {
                                focusMins = val.round();
                              });
                            },
                          ),

                          const SizedBox(height: 24),

                          // Include Break Toggle
                          _buildSwitchTile(
                            title: 'Include Break',
                            value: includeBreak,
                            onChanged: (val) {
                              setModalState(() {
                                includeBreak = val;
                              });
                            },
                          ),

                          if (includeBreak) ...[
                            const SizedBox(height: 16),
                            _buildSectionTitle('Break Duration (minutes)'),
                            const SizedBox(height: 12),
                            _buildDurationSlider(
                              value: breakMins,
                              min: 1,
                              max: 30,
                              color: const Color(0xFF10B981),
                              onChanged: (val) {
                                setModalState(() {
                                  breakMins = val.round();
                                });
                              },
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Custom TTS Message
                          _buildSectionTitle('Custom Announcement (Optional)'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: TextEditingController(text: customMessage),
                            maxLines: 2,
                            maxLength: 100,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'e.g., "Time to master calculus!"',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) {
                              customMessage = val;
                            },
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),

                  // Save Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        SoundService.playSuccess();

                        setState(() {
                          _sessions[index] = RoutineSession(
                            subjectName: selectedSubject,
                            subjectColorValue: selectedColor.value,
                            durationMinutes: focusMins,
                            includeBreak: includeBreak,
                            breakDurationMinutes: breakMins,
                            customMessage: customMessage.isEmpty ? null : customMessage,
                            order: index,
                            emoji: emoji,
                          );
                        });

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Session',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildDurationSlider({
    required int value,
    required int min,
    required int max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$min min',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$value min',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Text(
                '$max min',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  void _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one session')),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    SoundService.playSuccess();

    final routine = StudyRoutine(
      id: widget.editRoutine?.id ?? 'routine_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      sessions: _sessions,
      createdAt: widget.editRoutine?.createdAt ?? DateTime.now(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      autoPlayEnabled: _autoPlayEnabled,
      ttsEnabled: _ttsEnabled,
      emoji: _selectedEmoji,
      colorValue: _selectedColor.value,
      timesCompleted: widget.editRoutine?.timesCompleted ?? 0,
    );

    await DatabaseService.saveRoutine(routine);

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.editRoutine != null ? 'Routine updated!' : 'Routine created!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  int _calculateTotalMinutes() {
    int total = 0;
    for (var session in _sessions) {
      total += session.durationMinutes;
      if (session.includeBreak) {
        total += session.breakDurationMinutes;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final totalMins = _calculateTotalMinutes();
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.editRoutine != null ? 'Edit Routine' : 'Create Routine',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: _selectedColor, size: 28),
            onPressed: _saveRoutine,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Routine Name
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Emoji Picker
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showEmojiPicker();
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _selectedColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selectedColor, width: 2),
                          ),
                          child: Center(
                            child: Text(_selectedEmoji, style: const TextStyle(fontSize: 32)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Routine Name',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            border: InputBorder.none,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Description (optional)',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Color Picker
            Text(
              'Routine Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: _colorList.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                          : [],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Settings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Auto-play Sessions',
                    value: _autoPlayEnabled,
                    onChanged: (val) {
                      setState(() {
                        _autoPlayEnabled = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    title: 'Voice Announcements',
                    value: _ttsEnabled,
                    onChanged: (val) {
                      setState(() {
                        _ttsEnabled = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sessions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Sessions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_sessions.length} sessions • $durationStr total',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addSession,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sessions List
            ..._sessions.asMap().entries.map((entry) {
              final index = entry.key;
              final session = entry.value;
              return _buildSessionCard(index, session, surfaceColor, textColor);
            }).toList(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(int index, RoutineSession session, Color surfaceColor, Color textColor) {
    final subjectColor = Color(session.subjectColorValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: subjectColor.withOpacity(0.3), width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: subjectColor.withOpacity(0.2),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: subjectColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          session.subjectName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Text(
          session.getFormattedDuration(),
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: subjectColor, size: 20),
              onPressed: () => _editSession(index),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
              onPressed: () => _removeSession(index),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Emoji',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _emojiList.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedEmoji = emoji;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _selectedEmoji == emoji
                            ? _selectedColor.withOpacity(0.2)
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedEmoji == emoji ? _selectedColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}