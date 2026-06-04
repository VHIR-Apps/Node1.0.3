// lib/screens/add_habit_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import '../services/tts_service.dart';

class AddHabitScreen extends StatefulWidget {
  final Habit? habitToEdit;
  const AddHabitScreen({super.key, this.habitToEdit});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _dailyGoalController = TextEditingController(text: '1');
  final _goalUnitController = TextEditingController();
  final _alarmDescController = TextEditingController();
  final _notesController = TextEditingController();
  final _extraGoalController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _emojiSearchController = TextEditingController();

  late AnimationController _animController;
  late AnimationController _bgAnimController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _selectedEmoji = '✅';
  Color _selectedColor = AppConfig.primaryColor;
  String _selectedCategory = 'Health';
  String _selectedFrequency = 'daily';
  String _selectedPriority = 'medium';
  TimeOfDay? _selectedTime;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _reminderEnabled = false;

  bool _alarmEnabled = false;
  int _alarmRepeatCount = 3;
  int _ttsRepeatCount = 2;

  List<String> _extraGoals = [];
  List<int> _customDays = [];
  bool _isSaving = false;
  bool _isCustomCategoryMode = false;
  List<String> _customCategories = [];

  int _expandedSection = 0;

  final Map<String, List<String>> _emojiCategories = {
    '⭐ Popular': ['✅', '💪', '📚', '🏃', '💧', '🧘', '🎯', '⭐', '🔥', '💼', '🎨', '🎵'],
    '💪 Fitness': ['🏋️', '🚶', '🏊', '⚽', '🏀', '🎾', '🚴', '🧗', '🤸', '🏄', '⛹️', '🤾'],
    '🍎 Health': ['💧', '🍎', '🥗', '💊', '🩺', '🧴', '😴', '🛌', '🫀', '🦷', '👁️', '🧬'],
    '📚 Study': ['📚', '📖', '📝', '✏️', '🖊️', '📐', '🔬', '🧪', '💻', '🎓', '🧮', '📊'],
    '🧘 Mind': ['🧘', '🧠', '🙏', '🌿', '🕯️', '🫧', '☮️', '🌈', '🦋', '🌸', '🍃', '💆'],
    '💰 Finance': ['💰', '💳', '🏦', '📈', '💎', '🪙', '💵', '📉', '🧾', '💲', '🏧', '📋'],
    '🎨 Creative': ['🎨', '🎵', '🎸', '🎹', '📷', '🎬', '✍️', '🎭', '🖌️', '🎺', '🥁', '🎻'],
    '🏠 Home': ['🧹', '🍳', '🧺', '🪴', '🛋️', '🔧', '🏠', '🧽', '🪣', '🧊', '🛁', '🚿'],
    '❤️ Social': ['❤️', '👨‍👩‍👧', '📞', '💝', '🤝', '👋', '💌', '🎁', '👨‍👩‍👧‍👦', '🫂', '💑', '👫'],
    '🌟 Special': ['🌟', '🏆', '🚀', '✨', '🌙', '☀️', '🌅', '🌄', '⚡', '💫', '🎯', '🏅'],
    '🚫 Quit': ['🚫', '📵', '🚭', '🍺', '🎰', '📺', '🍬', '☕', '🛑', '⛔', '❌', '🙅'],
  };

  final List<Color> _colors = [
    AppConfig.primaryColor, AppConfig.accentColor, AppConfig.successColor,
    const Color(0xFF2196F3), const Color(0xFF9C27B0), const Color(0xFFFF9800),
    const Color(0xFF00BCD4), const Color(0xFF4CAF50), const Color(0xFFE91E63),
    const Color(0xFF795548), const Color(0xFF14B8A6), const Color(0xFFEF4444),
    const Color(0xFF0EA5E9), const Color(0xFFD946EF), const Color(0xFF84CC16),
    const Color(0xFFF43F5E),
  ];

  final List<String> _defaultCategories = [
    'Health', 'Fitness', 'Study', 'Work', 'Mindfulness',
    'Finance', 'Social', 'Spiritual', 'Self-Care', 'Creative',
    'Home', 'Quit Bad Habit', 'Other',
  ];

  final Map<String, IconData> _categoryIcons = {
    'Health': Icons.favorite_rounded,
    'Fitness': Icons.fitness_center_rounded,
    'Study': Icons.menu_book_rounded,
    'Work': Icons.work_rounded,
    'Mindfulness': Icons.self_improvement_rounded,
    'Finance': Icons.savings_rounded,
    'Social': Icons.people_rounded,
    'Spiritual': Icons.mosque_rounded,
    'Self-Care': Icons.spa_rounded,
    'Creative': Icons.palette_rounded,
    'Home': Icons.home_rounded,
    'Quit Bad Habit': Icons.block_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  final List<Map<String, dynamic>> _priorities = [
    {'id': 'low', 'label': 'Low', 'emoji': '🟢', 'color': const Color(0xFF22C55E)},
    {'id': 'medium', 'label': 'Medium', 'emoji': '🟡', 'color': const Color(0xFFEAB308)},
    {'id': 'high', 'label': 'High', 'emoji': '🟠', 'color': const Color(0xFFF97316)},
    {'id': 'critical', 'label': 'Critical', 'emoji': '🔴', 'color': const Color(0xFFEF4444)},
  ];

  final List<String> _goalUnits = [
    'times', 'minutes', 'hours', 'glasses', 'pages',
    'steps', 'reps', 'sets', 'km', 'ml', 'calories',
  ];

  final Map<int, String> _weekDays = {
    1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu',
    5: 'Fri', 6: 'Sat', 7: 'Sun',
  };

  bool get _isEditing => widget.habitToEdit != null;

  List<String> get _allCategories {
    final all = [..._defaultCategories];
    for (final c in _customCategories) {
      if (!all.contains(c)) all.add(c);
    }
    return all;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _bgAnimController = AnimationController(
        vsync: this, duration: const Duration(seconds: 15))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();

    _loadCustomCategories();
    if (_isEditing) _loadHabitData();

    _nameController.addListener(() => setState(() {}));
    _descController.addListener(() => setState(() {}));
    _dailyGoalController.addListener(() => setState(() {}));
  }

  void _loadCustomCategories() {
    _customCategories = DatabaseService.getCustomCategories();
  }

  void _loadHabitData() {
    final h = widget.habitToEdit!;
    _nameController.text = h.name;
    _descController.text = h.description ?? '';
    _selectedEmoji = h.emoji;
    _selectedColor = Color(h.colorValue);
    _selectedCategory = h.category;
    _selectedFrequency = h.frequency;
    _selectedPriority = h.priority;
    _reminderEnabled = h.reminderEnabled;
    _alarmEnabled = h.alarmEnabled;
    _alarmDescController.text = h.alarmDescription ?? '';
    _startDate = h.startDate;
    _endDate = h.endDate;
    _dailyGoalController.text = h.dailyGoal.toString();
    _goalUnitController.text = h.dailyGoalUnit ?? '';
    _extraGoals = List.from(h.extraGoals ?? []);
    _customDays = List.from(h.customDays ?? []);
    _notesController.text = h.notes ?? '';
    _isCustomCategoryMode = h.isCustomCategory;

    _alarmRepeatCount = h.alarmRepeatCount;
    _ttsRepeatCount = h.ttsRepeatCount;

    if (h.time != null) {
      final parts = h.time!.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dailyGoalController.dispose();
    _goalUnitController.dispose();
    _alarmDescController.dispose();
    _notesController.dispose();
    _extraGoalController.dispose();
    _customCategoryController.dispose();
    _emojiSearchController.dispose();
    _animController.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // GLASS CONTAINER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDark,
    double borderRadius = 24.0,
    EdgeInsets padding = const EdgeInsets.all(20),
    bool isExpanded = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isExpanded
              ? _selectedColor.withOpacity(0.5)
              : (isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.8)),
          width: isExpanded ? 2 : 1.5,
        ),
        boxShadow: [
          if (isExpanded)
            BoxShadow(
              color: _selectedColor.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTION METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedColor,
              onSurface: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  void _previewTts() {
    final text = _alarmDescController.text.trim();
    if (text.isNotEmpty) {
      TtsService.speakAlarm(text, volume: 0.8);
    } else {
      TtsService.speak(
          'Time for ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "your habit"}!');
    }
  }

  void _addExtraGoal() {
    final goal = _extraGoalController.text.trim();
    if (goal.isNotEmpty && !_extraGoals.contains(goal)) {
      setState(() {
        _extraGoals.add(goal);
        _extraGoalController.clear();
      });
      SoundService.playTap();
    }
  }

  void _addCustomCategory() {
    final cat = _customCategoryController.text.trim();
    if (cat.isNotEmpty && !_allCategories.contains(cat)) {
      setState(() {
        _customCategories.add(cat);
        _selectedCategory = cat;
        _isCustomCategoryMode = true;
        _customCategoryController.clear();
      });
      DatabaseService.saveCustomCategory(cat);
      SoundService.playTap();
    } else if (_allCategories.contains(cat)) {
      setState(() {
        _selectedCategory = cat;
        _customCategoryController.clear();
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EMOJI PICKER
  // ═══════════════════════════════════════════════════════════════

  void _showFullEmojiPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Map<String, List<String>> filteredEmojis = {};
            if (searchQuery.isEmpty) {
              filteredEmojis = _emojiCategories;
            } else {
              for (final entry in _emojiCategories.entries) {
                final filtered =
                entry.value.where((e) => e.contains(searchQuery)).toList();
                if (filtered.isNotEmpty) {
                  filteredEmojis[entry.key] = filtered;
                }
              }
            }

            return ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF101828) : Colors.white)
                        .withOpacity(0.95),
                    border: Border.all(
                        color: Colors.white.withOpacity(isDark ? 0.1 : 0.8)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Text('Choose Icon',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _showKeyboardEmojiInput();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                    color: _selectedColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.keyboard_rounded,
                                        size: 18, color: _selectedColor),
                                    const SizedBox(width: 6),
                                    Text('Type Emoji',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: _selectedColor)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          onChanged: (val) =>
                              setModalState(() => searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search icon...',
                            hintStyle: TextStyle(
                                color: Colors.grey.withOpacity(0.5)),
                            prefixIcon:
                            const Icon(Icons.search_rounded, size: 22),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: filteredEmojis.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                  const EdgeInsets.only(top: 12, bottom: 12),
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                        letterSpacing: 1),
                                  ),
                                ),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: entry.value.map((emoji) {
                                    final isSelected = _selectedEmoji == emoji;
                                    return GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(
                                                () => _selectedEmoji = emoji);
                                        setModalState(() {});
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                        const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _selectedColor.withOpacity(0.2)
                                              : (isDark
                                              ? Colors.white
                                              .withOpacity(0.03)
                                              : const Color(0xFFF1F5F9)),
                                          borderRadius:
                                          BorderRadius.circular(16),
                                          border: Border.all(
                                              color: isSelected
                                                  ? _selectedColor
                                                  : Colors.transparent,
                                              width: 2),
                                          boxShadow: isSelected
                                              ? [
                                            BoxShadow(
                                                color: _selectedColor
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                offset:
                                                const Offset(0, 4))
                                          ]
                                              : null,
                                        ),
                                        child: Center(
                                            child: Text(emoji,
                                                style: TextStyle(
                                                    fontSize:
                                                    isSelected ? 30 : 26))),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            24,
                            16,
                            24,
                            MediaQuery.of(context).padding.bottom + 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedColor,
                                foregroundColor: Colors.white,
                                padding:
                                const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            child: const Text('Done',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showKeyboardEmojiInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: Icon(Icons.keyboard_rounded,
                    color: _selectedColor, size: 20)),
            const SizedBox(width: 12),
            const Text('Type Emoji',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Use your keyboard emoji picker to type any specific icon.',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44),
              maxLength: 2,
              decoration: InputDecoration(
                hintText: '🎯',
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.3)),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black54))),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _selectedEmoji = text);
                SoundService.playTap();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Apply',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showCustomCategoryDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _customCategoryController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.category_rounded,
                    color: _selectedColor, size: 20)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('New Category',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create a custom category',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            TextField(
              controller: _customCategoryController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g., Deep Work, Routine',
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _selectedColor, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black54))),
          ElevatedButton(
            onPressed: () {
              _addCustomCategory();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Create',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _deleteCustomCategory(String cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: const Text('Delete Category?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Remove "$cat" from your custom list?',
            style:
            TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _customCategories.remove(cat);
                if (_selectedCategory == cat) {
                  _selectedCategory = 'Other';
                  _isCustomCategoryMode = false;
                }
              });
              DatabaseService.removeCustomCategory(cat);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PERMISSIONS
  // ═══════════════════════════════════════════════════════════════

  Future<bool> _checkAndRequestAlarmPermissions() async {
    if (!_alarmEnabled) return true;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (await Permission.scheduleExactAlarm.isDenied) {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted) {
        if (mounted) await _showExactAlarmDialog();
        return false;
      }
    }

    if (mounted) {
      final understood = await _showFullScreenAlarmDialog();
      if (!understood) return false;
    }

    return true;
  }

  Future<bool> _showFullScreenAlarmDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.alarm_rounded,
                  color: _selectedColor, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Full Screen Alarm',
                  style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This alarm will show a full-screen notification even when your device is locked.',
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selectedColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: _selectedColor, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Shows on lock screen',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: _selectedColor, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Bypasses DND mode',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: _selectedColor, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Wakes up screen automatically',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700))),
                  ]),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Enable Alarm',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showExactAlarmDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: const Row(children: [
          Icon(Icons.settings_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
              child: Text('Permission Required',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900))),
        ]),
        content: const Text(
          'Exact alarm permission is needed for precise habit reminders. Please enable it in settings.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Open Settings',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SAVE METHOD
  // ═══════════════════════════════════════════════════════════════

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      SoundService.playError();
      return;
    }
    if (_isSaving) return;

    if (_alarmEnabled && _selectedTime != null) {
      final hasPermission = await _checkAndRequestAlarmPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
                '⚠️ Alarm requires permissions to work properly'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ));
        }
        setState(() => _alarmEnabled = false);
      }
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final habitId = widget.habitToEdit?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final timeString = _selectedTime == null
          ? null
          : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      final habit = Habit(
        id: habitId,
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        colorValue: _selectedColor.value,
        category: _selectedCategory,
        frequency: _selectedFrequency,
        time: timeString,
        reminderEnabled: _reminderEnabled,
        createdAt: widget.habitToEdit?.createdAt ?? DateTime.now(),
        completedDates: widget.habitToEdit?.completedDates ?? [],
        currentStreak: widget.habitToEdit?.currentStreak ?? 0,
        bestStreak: widget.habitToEdit?.bestStreak ?? 0,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        priority: _selectedPriority,
        startDate: _startDate,
        endDate: _endDate,
        dailyGoal: int.tryParse(_dailyGoalController.text) ?? 1,
        dailyGoalUnit: _goalUnitController.text.trim().isNotEmpty
            ? _goalUnitController.text.trim()
            : null,
        dailyGoalProgress: widget.habitToEdit?.dailyGoalProgress ?? 0,
        extraGoals: _extraGoals.isNotEmpty ? _extraGoals : null,
        alarmSoundPath: null, // ❌ Removed custom audio
        alarmDescription: _alarmDescController.text.trim().isNotEmpty
            ? _alarmDescController.text.trim()
            : null,
        alarmEnabled: _alarmEnabled,
        alarmTime: timeString,
        customDays: _customDays.isNotEmpty ? _customDays : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        totalCompletions: widget.habitToEdit?.totalCompletions ?? 0,
        lastProgressDate: widget.habitToEdit?.lastProgressDate,
        missedReasons: widget.habitToEdit?.missedReasons,
        isCustomCategory: _isCustomCategoryMode ||
            !_defaultCategories.contains(_selectedCategory),
        dailyProgressMap: widget.habitToEdit?.dailyProgressMap,
        alarmRepeatCount: _alarmRepeatCount,
        ttsRepeatCount: _ttsRepeatCount,
      );

      if (_isEditing) {
        await DatabaseService.updateHabit(habit);
      } else {
        await DatabaseService.addHabit(habit);
      }

      if (habit.reminderEnabled || habit.alarmEnabled) {
        await NotificationService.scheduleHabitReminder(habit);
        debugPrint('✅ Notifications scheduled for: ${habit.name}');
      } else {
        await NotificationService.cancelHabitReminder(habit);
        debugPrint('🗑️ Notifications cancelled for: ${habit.name}');
      }

      SoundService.playHabitCreated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? '${habit.emoji} Habit updated successfully!'
              : '${habit.emoji} Habit created! Let\'s grow. 🔥'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          backgroundColor: _selectedColor,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      SoundService.playError();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppConfig.errorColor,
        ));
        setState(() => _isSaving = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD METHOD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF020617) : const Color(0xFFF4F7FC),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              final t = _bgAnimController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: -50 + (math.sin(t) * 40),
                    left: -50 + (math.cos(t) * 40),
                    child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedColor
                                .withOpacity(isDark ? 0.15 : 0.1))),
                  ),
                  Positioned(
                    bottom: -100 + (math.cos(t * 0.8) * 60),
                    right: -50 + (math.sin(t * 1.2) * 50),
                    child: Container(
                        width: 350,
                        height: 350,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppConfig.accentColor
                                .withOpacity(isDark ? 0.1 : 0.05))),
                  ),
                ],
              );
            },
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.white.withOpacity(0.5)),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 80,
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: FlexibleSpaceBar(
                      title: Text(
                        _isEditing ? 'Edit Habit' : 'New Habit',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5),
                      ),
                      centerTitle: true,
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            _buildLivePreview(isDark),
                            const SizedBox(height: 24),
                            _buildSection(
                              index: 0,
                              icon: Icons.tune_rounded,
                              title: 'BASIC INFO',
                              subtitle: 'Name, icon & color',
                              isDark: isDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel('Habit Name *'),
                                  _buildNameField(isDark),
                                  const SizedBox(height: 20),
                                  _buildSectionLabel('Description (Optional)'),
                                  _buildDescField(isDark),
                                  const SizedBox(height: 20),
                                  _buildSectionLabel('Icon'),
                                  _buildEmojiSection(isDark),
                                  const SizedBox(height: 20),
                                  _buildSectionLabel('Color'),
                                  _buildColorCarousel(),
                                ],
                              ),
                            ),
                            _buildSection(
                              index: 1,
                              icon: Icons.category_rounded,
                              title: 'CATEGORY & PRIORITY',
                              subtitle: 'Organize your habit',
                              isDark: isDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel('Category'),
                                  _buildCategorySection(isDark),
                                  const SizedBox(height: 20),
                                  _buildSectionLabel('Priority'),
                                  _buildPrioritySelector(isDark),
                                ],
                              ),
                            ),
                            _buildSection(
                              index: 2,
                              icon: Icons.schedule_rounded,
                              title: 'SCHEDULE',
                              subtitle: 'Frequency & timeline',
                              isDark: isDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel('Frequency'),
                                  _buildFrequencySelector(isDark),
                                  if (_selectedFrequency == 'custom') ...[
                                    const SizedBox(height: 20),
                                    _buildSectionLabel('Active Days'),
                                    _buildCustomDaysSelector(isDark),
                                  ],
                                  const SizedBox(height: 20),
                                  _buildSectionLabel('Date Range'),
                                  _buildDateRangePicker(isDark),
                                ],
                              ),
                            ),
                            _buildSection(
                              index: 3,
                              icon: Icons.track_changes_rounded,
                              title: 'GOALS',
                              subtitle: 'Daily targets',
                              isDark: isDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDailyGoalFields(isDark),
                                  const SizedBox(height: 20),
                                  _buildSectionLabel('Sub-goals (Optional)'),
                                  _buildExtraGoals(isDark),
                                ],
                              ),
                            ),
                            _buildSection(
                              index: 4,
                              icon: Icons.notifications_active_rounded,
                              title: 'REMINDERS & ALARMS',
                              subtitle: 'Stay on track',
                              isDark: isDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildReminderCard(isDark),
                                  const SizedBox(height: 16),
                                  _buildAlarmSection(isDark),
                                ],
                              ),
                            ),
                            _buildSection(
                              index: 5,
                              icon: Icons.text_snippet_rounded,
                              title: 'NOTES',
                              subtitle: 'Personal thoughts',
                              isDark: isDark,
                              child: _buildNotesField(isDark),
                            ),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, 16, 24,
                      MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.5)
                        : Colors.white.withOpacity(0.7),
                    border: Border(
                        top: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05))),
                  ),
                  child: _buildSaveButton(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UI COMPONENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSection({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Widget child,
  }) {
    final isExpanded = _expandedSection == index;

    return _buildGlassContainer(
      isDark: isDark,
      isExpanded: isExpanded,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _expandedSection = isExpanded ? -1 : index);
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _selectedColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: _selectedColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color:
                                isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black54)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 28),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: child,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 400),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(bool isDark) {
    final nameText = _nameController.text.trim();
    final priorityData =
    _priorities.firstWhere((p) => p['id'] == _selectedPriority);
    final goalVal = int.tryParse(_dailyGoalController.text) ?? 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [_selectedColor.withOpacity(0.9), _selectedColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: _selectedColor.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 2)),
                child: Center(
                    child: Text(_selectedEmoji,
                        style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameText.isEmpty ? 'Habit Name' : nameText,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Icon(
                              _categoryIcons[_selectedCategory] ??
                                  Icons.hub_rounded,
                              size: 14,
                              color: Colors.white.withOpacity(0.9)),
                          const SizedBox(width: 4),
                          Text(_selectedCategory,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9))),
                          const SizedBox(width: 12),
                          Text(priorityData['emoji'] as String,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(priorityData['label'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9))),
                          if (_selectedTime != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.access_time_filled_rounded,
                                size: 14,
                                color: Colors.white.withOpacity(0.9)),
                            const SizedBox(width: 4),
                            Text(_selectedTime!.format(context),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9))),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (goalVal > 1 || _goalUnitController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.track_changes_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                      'Target: $goalVal ${_goalUnitController.text.trim().isNotEmpty ? _goalUnitController.text.trim() : "times"}',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.grey.shade500)),
    );
  }

  Widget _buildNameField(bool isDark) {
    return TextFormField(
      controller: _nameController,
      autofocus: !_isEditing,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: 'e.g., Drink Water',
        hintStyle: TextStyle(
            color: Colors.grey.withOpacity(0.5),
            fontWeight: FontWeight.w600),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _selectedColor, width: 2)),
      ),
      validator: (v) =>
      (v == null || v.trim().isEmpty) ? 'Habit name is required' : null,
    );
  }

  Widget _buildDescField(bool isDark) {
    return TextFormField(
      controller: _descController,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: 'Why is this habit important to you?',
        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _selectedColor, width: 2)),
      ),
    );
  }

  Widget _buildEmojiSection(bool isDark) {
    final quickEmojis = [
      '✅', '💪', '📚', '🏃', '💧', '🧘', '🎯', '🚀', '🔥', '💼', '🎨', '🧠'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 60,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: quickEmojis.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              if (index == quickEmojis.length) {
                return GestureDetector(
                  onTap: _showFullEmojiPicker,
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: _selectedColor.withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded,
                            color: _selectedColor, size: 20),
                        const SizedBox(height: 2),
                        Text('More',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: _selectedColor)),
                      ],
                    ),
                  ),
                );
              }

              final emoji = quickEmojis[index];
              final isSelected = _selectedEmoji == emoji;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedEmoji = emoji);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _selectedColor.withOpacity(0.2)
                        : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color:
                        isSelected ? _selectedColor : Colors.transparent,
                        width: 2),
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: isSelected ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorCarousel() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: _colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          final color = _colors[index];
          final isSelected = _selectedColor == color;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedColor = color);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isSelected ? 50 : 40,
              height: isSelected ? 50 : 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: isSelected ? 3 : 0),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 2)
                ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 24)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: _allCategories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          if (index == _allCategories.length) {
            return GestureDetector(
              onTap: () => _showCustomCategoryDialog(),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: _selectedColor.withOpacity(0.4), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: _selectedColor),
                    const SizedBox(width: 6),
                    Text('Custom',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _selectedColor)),
                  ],
                ),
              ),
            );
          }

          final cat = _allCategories[index];
          final isSelected = _selectedCategory == cat;
          final isCustom = !_defaultCategories.contains(cat);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedCategory = cat;
                _isCustomCategoryMode = isCustom;
              });
            },
            onLongPress: isCustom ? () => _deleteCustomCategory(cat) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _selectedColor
                    : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
                borderRadius: BorderRadius.circular(24),
                border: isCustom && !isSelected
                    ? Border.all(color: _selectedColor.withOpacity(0.3))
                    : null,
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                      color: _selectedColor.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _categoryIcons[cat] ??
                        (isCustom ? Icons.hub_rounded : Icons.circle),
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrioritySelector(bool isDark) {
    return Row(
      children: _priorities.map((p) {
        final isSelected = _selectedPriority == p['id'];
        final color = p['color'] as Color;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: p != _priorities.last ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedPriority = p['id'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isSelected ? color : Colors.transparent, width: 2),
                ),
                child: Column(
                  children: [
                    Text(p['emoji'] as String,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(p['label'] as String,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? color
                                : (isDark
                                ? Colors.white54
                                : Colors.black54))),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFrequencySelector(bool isDark) {
    return Row(
      children: [
        _buildFreqCard(
            'daily', 'Daily', Icons.all_inclusive_rounded, isDark),
        const SizedBox(width: 12),
        _buildFreqCard(
            'weekly', 'Weekly', Icons.calendar_view_week_rounded, isDark),
        const SizedBox(width: 12),
        _buildFreqCard('custom', 'Custom', Icons.tune_rounded, isDark),
      ],
    );
  }

  Widget _buildFreqCard(
      String value, String label, IconData icon, bool isDark) {
    final isSelected = _selectedFrequency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedFrequency = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? _selectedColor.withOpacity(0.15)
                : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isSelected ? _selectedColor : Colors.transparent,
                width: 2),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 26,
                  color: isSelected
                      ? _selectedColor
                      : (isDark ? Colors.white54 : Colors.black54)),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? _selectedColor
                          : (isDark ? Colors.white70 : Colors.black87))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDaysSelector(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _weekDays.entries.map((entry) {
        final isSelected = _customDays.contains(entry.key);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _customDays.remove(entry.key);
              } else {
                _customDays.add(entry.key);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isSelected
                  ? _selectedColor
                  : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isSelected ? _selectedColor : Colors.transparent),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                    color: _selectedColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]
                  : null,
            ),
            child: Center(
              child: Text(entry.value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.black54))),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangePicker(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildDateCard('Start Date', _startDate, true, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildDateCard('End Date', _endDate, false, isDark)),
      ],
    );
  }

  Widget _buildDateCard(
      String label, DateTime? date, bool isStart, bool isDark) {
    return GestureDetector(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: date != null
                  ? _selectedColor.withOpacity(0.5)
                  : Colors.transparent,
              width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18,
                    color: date != null
                        ? _selectedColor
                        : (isDark ? Colors.white54 : Colors.black45)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('MMM d, yyyy').format(date)
                        : 'Optional',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: date != null
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white54 : Colors.black45)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoalFields(bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('Target Number'),
              TextFormField(
                controller: _dailyGoalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _selectedColor, width: 2)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('Unit'),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _goalUnits.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final unit = _goalUnits[i];
                    final isSelected = _goalUnitController.text == unit;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _goalUnitController.text = unit);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withOpacity(0.15)
                              : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.03)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isSelected
                                  ? _selectedColor
                                  : Colors.transparent,
                              width: 1.5),
                        ),
                        child: Center(
                            child: Text(unit.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? _selectedColor
                                        : (isDark
                                        ? Colors.white54
                                        : Colors.black54)))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtraGoals(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _extraGoalController,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'e.g., Read 10 pages',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                      BorderSide(color: _selectedColor, width: 2)),
                ),
                onFieldSubmitted: (_) => _addExtraGoal(),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _addExtraGoal,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: _selectedColor.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        if (_extraGoals.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._extraGoals.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trip_origin_rounded,
                        color: _selectedColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(entry.value,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color:
                                isDark ? Colors.white : Colors.black87))),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _extraGoals.removeAt(entry.key));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: AppConfig.errorColor.withOpacity(0.15),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppConfig.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildReminderCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _reminderEnabled
                ? _selectedColor.withOpacity(0.4)
                : Colors.transparent),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text('Reminder Notification',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(
                _reminderEnabled
                    ? 'You\'ll get a notification'
                    : 'No notifications',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54)),
            value: _reminderEnabled,
            activeColor: Colors.white,
            activeTrackColor: _selectedColor,
            onChanged: (val) {
              if (val && _selectedTime == null) {
                _pickTime().then((_) {
                  if (_selectedTime != null) {
                    setState(() => _reminderEnabled = true);
                  }
                });
              } else {
                setState(() => _reminderEnabled = val);
              }
            },
          ),
          if (_reminderEnabled || _selectedTime != null) ...[
            Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: isDark ? Colors.white10 : Colors.black12),
            ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.access_time_filled_rounded,
                    color: _selectedColor, size: 20),
              ),
              title: Text('Reminder Time',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87)),
              trailing: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Select',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _selectedColor),
                ),
              ),
              onTap: _pickTime,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlarmSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _alarmEnabled
                ? AppConfig.errorColor.withOpacity(0.4)
                : Colors.transparent),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text('Full-Screen Alarm',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(
                _alarmEnabled
                    ? 'Wakes up screen with sound'
                    : 'Standard reminder only',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54)),
            value: _alarmEnabled,
            activeColor: Colors.white,
            activeTrackColor: AppConfig.errorColor,
            onChanged: (val) {
              setState(() => _alarmEnabled = val);
              if (val) NotificationService.promptAlarmPermissionsIfNeeded();
            },
          ),
          if (_alarmEnabled) ...[
            Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: isDark ? Colors.white10 : Colors.black12),
            // ❌ Audio picker removed - default sound only
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.notifications_active_rounded,
                          color: Colors.green, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Default Alarm Sound',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87)),
                          const SizedBox(height: 2),
                          Text('System will use built-in alarm sound',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text('Repeats: $_alarmRepeatCount',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87)),
                  Expanded(
                    child: Slider(
                      value: _alarmRepeatCount.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: AppConfig.errorColor,
                      onChanged: (val) => setState(
                              () => _alarmRepeatCount = val.toInt()),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: isDark ? Colors.white10 : Colors.black12),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded,
                          size: 20, color: Colors.blue),
                      const SizedBox(width: 10),
                      Text('Voice Message (TTS)',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color:
                              isDark ? Colors.white : Colors.black87)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _previewTts,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 6),
                              const Text('Test',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _alarmDescController,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'e.g., Time to drink water!',
                      hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.5), fontSize: 14),
                      filled: true,
                      fillColor: isDark
                          ? Colors.black.withOpacity(0.2)
                          : Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesField(bool isDark) {
    return TextFormField(
      controller: _notesController,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 5,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: 'Write your thoughts, motivation, or reflections...',
        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _selectedColor, width: 2)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _save,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: _selectedColor,
        foregroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        shadowColor: _selectedColor.withOpacity(0.6),
      ),
      child: _isSaving
          ? const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 3, color: Colors.white))
          : Text(
        _isEditing ? 'Update Habit' : 'Create Habit',
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5),
      ),
    );
  }
}