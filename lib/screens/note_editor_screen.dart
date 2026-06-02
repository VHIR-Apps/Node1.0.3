// lib/screens/note_editor_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/note_model.dart';
import '../services/sound_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final Function(Note) onSave;

  const NoteEditorScreen({
    Key? key,
    this.note,
    required this.onSave,
  }) : super(key: key);

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with TickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late FocusNode _titleFocus;
  late FocusNode _contentFocus;
  late FocusNode _tagFocus;

  late String _selectedColor;
  late int _selectedPriority;
  late bool _isPinned;
  late List<String> _tags;

  late AnimationController _toolbarController;
  late Animation<double> _toolbarAnimation;
  late AnimationController _bgAnimationController;
  late AnimationController _saveGlowController;
  late AnimationController _tagPanelController;
  late Animation<double> _tagPanelAnimation;
  late AnimationController _headerSlideController;

  bool _hasChanges = false;
  bool _showColorPicker = false;
  bool _showTagPanel = false;
  int _wordCount = 0;
  int _charCount = 0;
  bool _isContentFocused = false;

  final List<Map<String, dynamic>> _noteColors = [
    {'color': '#FFB300', 'name': 'Amber', 'icon': Icons.wb_sunny_rounded},
    {'color': '#FF6B6B', 'name': 'Rose', 'icon': Icons.favorite_rounded},
    {'color': '#00C853', 'name': 'Emerald', 'icon': Icons.eco_rounded},
    {'color': '#0EA5E9', 'name': 'Ocean', 'icon': Icons.water_drop_rounded},
    {'color': '#A855F7', 'name': 'Violet', 'icon': Icons.auto_awesome_rounded},
    {'color': '#EC4899', 'name': 'Pink', 'icon': Icons.local_florist_rounded},
    {'color': '#64748B', 'name': 'Slate', 'icon': Icons.dark_mode_rounded},
    {
      'color': '#F97316',
      'name': 'Flame',
      'icon': Icons.local_fire_department_rounded
    },
    {'color': '#14B8A6', 'name': 'Teal', 'icon': Icons.spa_rounded},
    {'color': '#6366F1', 'name': 'Indigo', 'icon': Icons.nights_stay_rounded},
  ];

  final List<Map<String, dynamic>> _priorities = [
    {
      'value': 0,
      'label': 'Normal',
      'icon': Icons.remove_rounded,
      'color': Colors.grey
    },
    {
      'value': 1,
      'label': 'Important',
      'icon': Icons.bookmark_rounded,
      'color': const Color(0xFFFFB300)
    },
    {
      'value': 2,
      'label': 'Urgent',
      'icon': Icons.priority_high_rounded,
      'color': const Color(0xFFEF4444)
    },
  ];

  @override
  void initState() {
    super.initState();

    _titleController =
        TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _tagController = TextEditingController();
    _titleFocus = FocusNode();
    _contentFocus = FocusNode();
    _tagFocus = FocusNode();

    _selectedColor = widget.note?.color ?? '#FFB300';
    _selectedPriority = widget.note?.priority ?? 0;
    _isPinned = widget.note?.isPinned ?? false;
    _tags = List.from(widget.note?.tags ?? []);

    _toolbarController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _toolbarAnimation = CurvedAnimation(
        parent: _toolbarController, curve: Curves.easeOutCubic);

    _bgAnimationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat(reverse: true);

    _saveGlowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    _tagPanelController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _tagPanelAnimation = CurvedAnimation(
        parent: _tagPanelController, curve: Curves.easeOutCubic);

    _headerSlideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();

    _titleController.addListener(_markChanged);
    _contentController.addListener(() {
      _markChanged();
      _updateCounts();
    });

    _contentFocus.addListener(() {
      setState(() => _isContentFocused = _contentFocus.hasFocus);
    });

    _updateCounts();

    if (widget.note == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    _tagFocus.dispose();
    _toolbarController.dispose();
    _bgAnimationController.dispose();
    _saveGlowController.dispose();
    _tagPanelController.dispose();
    _headerSlideController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges && mounted) setState(() => _hasChanges = true);
  }

  void _updateCounts() {
    final text = _contentController.text;
    final words =
    text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    if (mounted) {
      setState(() {
        _wordCount = words;
        _charCount = text.length;
      });
    }
  }

  Color _getNoteColor() {
    try {
      return Color(
          int.parse(_selectedColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFFFB300);
    }
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      _showSnackBar('Note cannot be empty', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    SoundService.playSuccess();

    final note = Note(
      id: widget.note?.id ?? '',
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      color: _selectedColor,
      priority: _selectedPriority,
      isPinned: _isPinned,
      tags: _tags,
    );

    widget.onSave(note);
    Navigator.pop(context, true);
  }

  void _confirmDiscard() {
    if (!_hasChanges) {
      Navigator.pop(context, false);
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: _glassBox(
          isDark: isDark,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppConfig.warningColor.withOpacity(0.2),
                    AppConfig.warningColor.withOpacity(0.05),
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppConfig.warningColor.withOpacity(0.4),
                      width: 2),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppConfig.warningColor, size: 28),
              ),
              const SizedBox(height: 20),
              Text('Discard Changes?',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('You have unsaved changes. Discard them?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color:
                      isDark ? Colors.white60 : Colors.black54,
                      fontSize: 14,
                      height: 1.5)),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : Colors.black54,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.errorColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Discard',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        content: _glassBox(
          isDark: true,
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          gradientColors: isError
              ? [
            AppConfig.errorColor.withOpacity(0.95),
            Colors.redAccent.withOpacity(0.85)
          ]
              : [
            AppConfig.successColor.withOpacity(0.95),
            const Color(0xFF10B981).withOpacity(0.85)
          ],
          child: Row(children: [
            Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13))),
          ]),
        ),
      ),
    );
  }

  void _toggleColorPicker() {
    HapticFeedback.lightImpact();
    setState(() {
      _showColorPicker = !_showColorPicker;
      if (_showTagPanel) {
        _showTagPanel = false;
        _tagPanelController.reverse();
      }
    });
    _showColorPicker
        ? _toolbarController.forward()
        : _toolbarController.reverse();
  }

  void _toggleTagPanel() {
    HapticFeedback.lightImpact();
    setState(() {
      _showTagPanel = !_showTagPanel;
      if (_showColorPicker) {
        _showColorPicker = false;
        _toolbarController.reverse();
      }
    });
    _showTagPanel
        ? _tagPanelController.forward()
        : _tagPanelController.reverse();
  }

  void _addTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty || _tags.contains(t) || _tags.length >= 8) return;
    HapticFeedback.lightImpact();
    setState(() => _tags.add(t));
    _tagController.clear();
    _markChanged();
  }

  void _removeTag(String tag) {
    HapticFeedback.lightImpact();
    setState(() => _tags.remove(tag));
    _markChanged();
  }

  // ─────────────────────────────────────────────
  // 💎 GLASS BOX HELPER
  // ─────────────────────────────────────────────

  Widget _glassBox({
    required Widget child,
    required bool isDark,
    double borderRadius = 24.0,
    EdgeInsets padding = const EdgeInsets.all(20),
    List<Color>? gradientColors,
    bool hasBorder = true,
    double blur = 25,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
                : LinearGradient(
                colors: isDark
                    ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03)
                ]
                    : [
                  Colors.white.withOpacity(0.88),
                  Colors.white.withOpacity(0.6)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder
                ? Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.85),
                width: 1.2)
                : null,
            boxShadow: [
              BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🏗️ BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteColor = _getNoteColor();
    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
        isDark ? Brightness.dark : Brightness.light,
      ),
      child: WillPopScope(
        onWillPop: () async {
          _confirmDiscard();
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // ── 1. Animated gradient background ──
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF1E1B4B),
                        const Color(0xFF020617),
                      ]
                          : [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFE0E7FF),
                        const Color(0xFFF3E8FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // ── 2. Floating ambient orbs ──
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgAnimationController,
                  builder: (context, _) {
                    final t =
                        _bgAnimationController.value * 2 * math.pi;
                    return Stack(children: [
                      Positioned(
                        top: -60 + (40 * math.sin(t)),
                        right: -100 + (30 * math.cos(t)),
                        child: Container(
                          width: 380,
                          height: 380,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              noteColor.withOpacity(
                                  isDark ? 0.12 : 0.08),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 60 + (30 * math.cos(t * 0.8)),
                        left: -50 + (35 * math.sin(t * 1.2)),
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              AppConfig.primaryColor.withOpacity(
                                  isDark ? 0.08 : 0.05),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),

              // ── 3. Status bar dark banner ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topSafe + 4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF0F172A)
                            .withOpacity(0.7),
                        Colors.transparent,
                      ]
                          : [
                        const Color(0xFF1E293B)
                            .withOpacity(0.85),
                        const Color(0xFF334155)
                            .withOpacity(0.5),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // ── 4. Main content ──
              Column(
                children: [
                  SizedBox(height: topSafe),

                  // ═══ APP BAR ═══
                  _buildPremiumAppBar(isDark, noteColor),

                  // ═══ TOOLBAR ═══
                  _buildToolbar(isDark, noteColor),

                  // ═══ COLOR PICKER PANEL ═══
                  SizeTransition(
                    sizeFactor: _toolbarAnimation,
                    axisAlignment: -1,
                    child:
                    _buildColorPickerPanel(isDark, noteColor),
                  ),

                  // ═══ TAG PANEL ═══
                  SizeTransition(
                    sizeFactor: _tagPanelAnimation,
                    axisAlignment: -1,
                    child: _buildTagPanel(isDark, noteColor),
                  ),

                  // ═══ EDITOR ═══
                  Expanded(child: _buildEditor(isDark, noteColor)),

                  // ═══ BOTTOM STATUS BAR ═══
                  _buildBottomBar(isDark, noteColor, bottomSafe),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏆 PREMIUM APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPremiumAppBar(bool isDark, Color noteColor) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0B1020).withOpacity(0.5)
                : Colors.white.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04)),
            ),
          ),
          child: Row(
            children: [
              // Close button
              _buildIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _confirmDiscard,
                isDark: isDark,
                noteColor: noteColor,
                size: 20,
              ),
              const SizedBox(width: 12),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: noteColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  noteColor.withOpacity(0.5),
                                  blurRadius: 6)
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.note == null
                              ? 'New Note'
                              : 'Edit Note',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    if (widget.note != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Last edited ${_formatDate(widget.note!.updatedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white38
                              : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Pin button
              _buildIconBtn(
                icon: _isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isPinned = !_isPinned);
                  _markChanged();
                },
                isDark: isDark,
                noteColor: noteColor,
                color: _isPinned ? noteColor : null,
                isActive: _isPinned,
              ),
              const SizedBox(width: 8),

              // Save button
              AnimatedBuilder(
                animation: _saveGlowController,
                builder: (context, child) {
                  final glow = _hasChanges
                      ? 0.3 +
                      (_saveGlowController.value * 0.3)
                      : 0.0;
                  return Container(
                    decoration: _hasChanges
                        ? BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: noteColor
                                .withOpacity(glow),
                            blurRadius: 16,
                            spreadRadius: 2),
                      ],
                    )
                        : null,
                    child: child,
                  );
                },
                child: ElevatedButton.icon(
                  onPressed: _saveNote,
                  icon:
                  const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: noteColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color noteColor,
    Color? color,
    bool isActive = false,
    double size = 22,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isActive
              ? (color ?? noteColor).withOpacity(0.15)
              : isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? (color ?? noteColor).withOpacity(0.4)
                : isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Icon(icon,
            size: size,
            color: color ??
                (isDark ? Colors.white70 : Colors.black54)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildToolbar(bool isDark, Color noteColor) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.white.withOpacity(0.35),
            border: Border(
              bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.04)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Color picker toggle
                _toolbarChip(
                  icon: Icons.palette_rounded,
                  label: 'Color',
                  isActive: _showColorPicker,
                  activeColor: noteColor,
                  isDark: isDark,
                  onTap: _toggleColorPicker,
                ),
                const SizedBox(width: 8),

                // Tag toggle
                _toolbarChip(
                  icon: Icons.label_rounded,
                  label: 'Tags (${_tags.length})',
                  isActive: _showTagPanel,
                  activeColor: AppConfig.infoColor,
                  isDark: isDark,
                  onTap: _toggleTagPanel,
                ),
                const SizedBox(width: 8),

                // Divider
                Container(
                  width: 1.5,
                  height: 28,
                  margin:
                  const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),

                // Priority chips
                ..._priorities.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _toolbarChip(
                    icon: p['icon'] as IconData,
                    label: p['label'] as String,
                    isActive: _selectedPriority ==
                        (p['value'] as int),
                    activeColor: p['color'] as Color,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPriority =
                      p['value'] as int);
                      _markChanged();
                    },
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: [
            activeColor.withOpacity(0.2),
            activeColor.withOpacity(0.08),
          ])
              : null,
          color: isActive
              ? null
              : isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? activeColor.withOpacity(0.5)
                : isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
                color: activeColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive
                    ? activeColor
                    : isDark
                    ? Colors.white54
                    : Colors.black45),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? activeColor
                        : isDark
                        ? Colors.white54
                        : Colors.black45)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 COLOR PICKER PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildColorPickerPanel(bool isDark, Color noteColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151C2F).withOpacity(0.85)
            : Colors.white.withOpacity(0.75),
        border: Border(
          bottom: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Text('Choose Color',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45,
                    letterSpacing: 0.5)),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _noteColors.map((cd) {
              final color = cd['color'] as String;
              final name = cd['name'] as String;
              final icon = cd['icon'] as IconData;
              final isSelected = _selectedColor == color;
              final parsed = Color(
                  int.parse(color.replaceFirst('#', '0xFF')));

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  SoundService.playTap();
                  setState(() {
                    _selectedColor = color;
                    _showColorPicker = false;
                  });
                  _toolbarController.reverse();
                  _markChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 68,
                  padding:
                  const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      parsed.withOpacity(
                          isSelected ? 0.3 : 0.1),
                      parsed.withOpacity(
                          isSelected ? 0.12 : 0.03),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isSelected
                            ? parsed
                            : Colors.transparent,
                        width: 2.5),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                          color:
                          parsed.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1)
                    ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: parsed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                parsed.withOpacity(0.4),
                                blurRadius: 6)
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16)
                            : Icon(icon,
                            color: Colors.white
                                .withOpacity(0.9),
                            size: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(name,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? parsed
                                  : isDark
                                  ? Colors.white60
                                  : Colors.black45)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏷️ TAG PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTagPanel(bool isDark, Color noteColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151C2F).withOpacity(0.85)
            : Colors.white.withOpacity(0.75),
        border: Border(
          bottom: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06)),
                  ),
                  child: TextField(
                    controller: _tagController,
                    focusNode: _tagFocus,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Add a tag...',
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white30
                              : Colors.black26,
                          fontWeight: FontWeight.w600),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                      const EdgeInsets.symmetric(
                          vertical: 12),
                    ),
                    textCapitalization:
                    TextCapitalization.words,
                    onSubmitted: _addTag,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _addTag(_tagController.text),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppConfig.infoColor,
                      AppConfig.infoColor.withOpacity(0.8)
                    ]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),

          // Tags display
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      noteColor.withOpacity(0.15),
                      noteColor.withOpacity(0.06),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: noteColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tag_rounded,
                          size: 14, color: noteColor),
                      const SizedBox(width: 4),
                      Text(tag,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeTag(tag),
                        child: Icon(Icons.close_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.white54
                                : Colors.black38),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          if (_tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('No tags added yet',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white30
                          : Colors.black26)),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📝 EDITOR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEditor(bool isDark, Color noteColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _glassBox(
        isDark: isDark,
        padding: const EdgeInsets.all(0),
        borderRadius: 28,
        child: Column(
          children: [
            // Title area
            Container(
              padding:
              const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Priority & pin indicators
                  if (_selectedPriority > 0 || _isPinned)
                    Padding(
                      padding:
                      const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          if (_selectedPriority > 0)
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5),
                              decoration: BoxDecoration(
                                color: (_selectedPriority ==
                                    2
                                    ? AppConfig
                                    .errorColor
                                    : AppConfig
                                    .warningColor)
                                    .withOpacity(0.12),
                                borderRadius:
                                BorderRadius.circular(
                                    10),
                                border: Border.all(
                                    color: (_selectedPriority ==
                                        2
                                        ? AppConfig
                                        .errorColor
                                        : AppConfig
                                        .warningColor)
                                        .withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize:
                                MainAxisSize.min,
                                children: [
                                  Icon(
                                      _selectedPriority ==
                                          2
                                          ? Icons
                                          .priority_high_rounded
                                          : Icons
                                          .bookmark_rounded,
                                      size: 12,
                                      color: _selectedPriority ==
                                          2
                                          ? AppConfig
                                          .errorColor
                                          : AppConfig
                                          .warningColor),
                                  const SizedBox(width: 4),
                                  Text(
                                      _selectedPriority ==
                                          2
                                          ? 'Urgent'
                                          : 'Important',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight:
                                          FontWeight
                                              .w900,
                                          color: _selectedPriority ==
                                              2
                                              ? AppConfig
                                              .errorColor
                                              : AppConfig
                                              .warningColor)),
                                ],
                              ),
                            ),
                          if (_selectedPriority > 0 &&
                              _isPinned)
                            const SizedBox(width: 8),
                          if (_isPinned)
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5),
                              decoration: BoxDecoration(
                                color: noteColor
                                    .withOpacity(0.12),
                                borderRadius:
                                BorderRadius.circular(
                                    10),
                                border: Border.all(
                                    color: noteColor
                                        .withOpacity(
                                        0.35)),
                              ),
                              child: Row(
                                mainAxisSize:
                                MainAxisSize.min,
                                children: [
                                  Icon(
                                      Icons
                                          .push_pin_rounded,
                                      size: 12,
                                      color: noteColor),
                                  const SizedBox(width: 4),
                                  Text('Pinned',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight:
                                          FontWeight
                                              .w900,
                                          color:
                                          noteColor)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Title field
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white
                          : Colors.black87,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Note Title...',
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white
                              .withOpacity(0.2)
                              : Colors.black
                              .withOpacity(0.15),
                          fontWeight: FontWeight.w800),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textCapitalization:
                    TextCapitalization.sentences,
                    maxLines: 2,
                    onSubmitted: (_) =>
                        _contentFocus.requestFocus(),
                  ),

                  // Colored divider
                  Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(
                        vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        noteColor,
                        noteColor.withOpacity(0.15),
                        Colors.transparent,
                      ]),
                      borderRadius:
                      BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocus,
                  style: TextStyle(
                    fontSize: 16.5,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black.withOpacity(0.85),
                    height: 1.85,
                    letterSpacing: 0.2,
                  ),
                  decoration: InputDecoration(
                    hintText:
                    'Start writing your thoughts...',
                    hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black
                            .withOpacity(0.18),
                        fontWeight: FontWeight.w600),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textCapitalization:
                  TextCapitalization.sentences,
                  maxLines: null,
                  expands: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 BOTTOM STATUS BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(
      bool isDark, Color noteColor, double bottomSafe) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, bottomSafe > 0 ? bottomSafe : 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.white.withOpacity(0.4),
            border: Border(
              top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
            ),
          ),
          child: Row(
            children: [
              // Word & char count
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.text_fields_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black
                            .withOpacity(0.35)),
                    const SizedBox(width: 6),
                    Text(
                      '$_wordCount words  ·  $_charCount chars',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black
                            .withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Tags count
              if (_tags.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppConfig.infoColor
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.label_rounded,
                          size: 12,
                          color: AppConfig.infoColor),
                      const SizedBox(width: 4),
                      Text('${_tags.length}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppConfig.infoColor)),
                    ],
                  ),
                ),

              // Unsaved indicator
              if (_hasChanges)
                AnimatedBuilder(
                  animation: _saveGlowController,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient:
                        LinearGradient(colors: [
                          noteColor.withOpacity(0.15),
                          noteColor.withOpacity(0.06),
                        ]),
                        borderRadius:
                        BorderRadius.circular(12),
                        border: Border.all(
                            color: noteColor.withOpacity(
                                0.2 +
                                    _saveGlowController
                                        .value *
                                        0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: noteColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: noteColor
                                        .withOpacity(
                                        0.5),
                                    blurRadius: 4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Unsaved',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                  FontWeight.w800,
                                  color: noteColor)),
                        ],
                      ),
                    );
                  },
                ),

              if (!_hasChanges && widget.note != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppConfig.successColor
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 14,
                          color: AppConfig.successColor),
                      SizedBox(width: 4),
                      Text('Saved',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color:
                              AppConfig.successColor)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILS
  // ═══════════════════════════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}