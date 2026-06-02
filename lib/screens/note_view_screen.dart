// lib/screens/note_view_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/note_model.dart';
import '../services/notes_service.dart';
import '../services/sound_service.dart';
import 'note_editor_screen.dart';

class NoteViewScreen extends StatefulWidget {
  final Note note;
  final VoidCallback onNoteUpdated;

  const NoteViewScreen({
    Key? key,
    required this.note,
    required this.onNoteUpdated,
  }) : super(key: key);

  @override
  State<NoteViewScreen> createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen> with TickerProviderStateMixin {
  late Note _currentNote;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    // 🚀 Ambient Background Animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  Color _getNoteColor() {
    try {
      return Color(int.parse(_currentNote.color.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFFFB300);
    }
  }

  void _openEditor() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return NoteEditorScreen(
            note: _currentNote,
            onSave: (updatedNote) async {
              final saved = await NotesService.updateNote(
                _currentNote.id,
                title: updatedNote.title,
                content: updatedNote.content,
                color: updatedNote.color,
                priority: updatedNote.priority,
                isPinned: updatedNote.isPinned,
                tags: updatedNote.tags,
              );

              if (saved != null) {
                setState(() {
                  _currentNote = saved;
                });
                widget.onNoteUpdated();
              }
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result == true) {
      final refreshed = NotesService.getNoteById(_currentNote.id);
      if (refreshed != null) {
        setState(() {
          _currentNote = refreshed;
        });
      }
    }
  }

  void _togglePin() async {
    HapticFeedback.lightImpact();
    SoundService.playTap();

    final updated = await NotesService.updateNote(
      _currentNote.id,
      isPinned: !_currentNote.isPinned,
    );

    if (updated != null) {
      setState(() {
        _currentNote = updated;
      });
      widget.onNoteUpdated();

      if (mounted) {
        _showSnack(updated.isPinned ? '📌 Note pinned' : '📌 Note unpinned');
      }
    }
  }

  void _deleteNote() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: _buildGlassContainer(
          isDark: isDark,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Text('Delete Note?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 16),
              Text('This action cannot be undone. The note will be permanently deleted.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        await NotesService.deleteNote(_currentNote.id);
                        HapticFeedback.mediumImpact();
                        SoundService.playTap();
                        widget.onNoteUpdated();
                        if (mounted) {
                          Navigator.pop(context); // Close view screen
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareNote() {
    HapticFeedback.lightImpact();
    final text = '${_currentNote.title}\n\n${_currentNote.content}';
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Note copied to clipboard');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        content: _buildGlassContainer(
          isDark: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          gradientColors: [AppConfig.primaryColor.withOpacity(0.9), const Color(0xFF3B82F6).withOpacity(0.8)],
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13))),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 💎 PREMIUM GLASSMORPHISM HELPERS
  // ─────────────────────────────────────────────

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDark,
    double borderRadius = 22.0,
    EdgeInsets padding = const EdgeInsets.all(20),
    List<Color>? gradientColors,
    bool hasBorder = true,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight)
                : LinearGradient(
              colors: isDark
                  ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)]
                  : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder ? Border.all(
              color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8),
              width: 1.5,
            ) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  List<Color> _getBackgroundColors(bool isDark) {
    if (isDark) {
      return [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF020617)];
    } else {
      return [const Color(0xFFF8FAFC), const Color(0xFFE0E7FF), const Color(0xFFF3E8FF)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteColor = _getNoteColor();
    final bgColors = _getBackgroundColors(isDark);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      body: Stack(
        children: [
          // 💎 Deep Animated Mesh Background
          AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOutSine,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),

          // 💎 Floating Ambient Orbs (Matching Note Color)
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              final t = _bgAnimationController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: -50 + (30 * math.sin(t)),
                    left: -100 + (40 * math.cos(t)),
                    child: Container(
                      width: 350, height: 350,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: noteColor.withOpacity(isDark ? 0.1 : 0.05), backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply),
                    ),
                  ),
                  Positioned(
                    bottom: 100 + (40 * math.cos(t * 0.8)),
                    right: -50 + (30 * math.sin(t * 1.2)),
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.primaryColor.withOpacity(isDark ? 0.08 : 0.04), backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply),
                    ),
                  ),
                ],
              );
            },
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ═══════════════════════════════════════
              // SLIVER APP BAR (GLASSMORPHISM)
              // ═══════════════════════════════════════
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildGlassContainer(isDark: isDark, padding: EdgeInsets.zero, borderRadius: 12, child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87)),
                  ),
                ),
                actions: [
                  _buildActionButton(icon: _currentNote.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, onTap: _togglePin, isDark: isDark, activeColor: noteColor),
                  _buildActionButton(icon: Icons.copy_rounded, onTap: _shareNote, isDark: isDark),
                  _buildActionButton(icon: Icons.delete_outline_rounded, onTap: _deleteNote, isDark: isDark),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1020).withOpacity(0.6) : Colors.white.withOpacity(0.6),
                          border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_currentNote.priority > 0)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _currentNote.priority == 2 ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFFFFB300).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _currentNote.priority == 2 ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFFFFB300).withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      _currentNote.priority == 2 ? '🔴 URGENT' : '🟡 IMPORTANT',
                                      style: TextStyle(color: _currentNote.priority == 2 ? const Color(0xFFEF4444) : const Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                                    ),
                                  ),
                                Text(
                                  _currentNote.title,
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.2, letterSpacing: -0.5),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // META INFO BAR
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildGlassContainer(
                      isDark: isDark,
                      padding: const EdgeInsets.all(16),
                      borderRadius: 18,
                      child: Row(
                        children: [
                          _buildMetaItem(icon: Icons.access_time_rounded, label: _formatFullDate(_currentNote.createdAt), isDark: isDark, noteColor: noteColor),
                          _buildMetaDivider(isDark),
                          _buildMetaItem(icon: Icons.text_fields_rounded, label: '${_currentNote.wordCount} words', isDark: isDark, noteColor: noteColor),
                          _buildMetaDivider(isDark),
                          _buildMetaItem(icon: Icons.short_text_rounded, label: '${_currentNote.charCount} chars', isDark: isDark, noteColor: noteColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // NOTE CONTENT
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildGlassContainer(
                        isDark: isDark,
                        padding: const EdgeInsets.all(24),
                        borderRadius: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_stories_rounded, size: 18, color: noteColor),
                                const SizedBox(width: 8),
                                Text('Reading Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: noteColor, letterSpacing: 0.5)),
                                const Spacer(),
                                Text('Edited ${_formatRelativeDate(_currentNote.updatedAt)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black45)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), height: 1),
                            const SizedBox(height: 16),

                            _currentNote.content.isEmpty
                                ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Column(
                                  children: [
                                    Icon(Icons.note_alt_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                                    const SizedBox(height: 12),
                                    Text('No content yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black45)),
                                    const SizedBox(height: 8),
                                    Text('Tap the edit button to add content', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
                                  ],
                                ),
                              ),
                            )
                                : SelectableText(
                              _currentNote.content,
                              style: TextStyle(fontSize: 16.5, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.85), height: 1.8, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // TAGS SECTION
              // ═══════════════════════════════════════
              if (_currentNote.tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _buildGlassContainer(
                        isDark: isDark,
                        padding: const EdgeInsets.all(20),
                        borderRadius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_offer_rounded, size: 18, color: noteColor),
                                const SizedBox(width: 8),
                                Text('Tags', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: noteColor)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _currentNote.tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: noteColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: noteColor.withOpacity(0.4))),
                                  child: Text('#$tag', style: TextStyle(fontSize: 13, color: noteColor, fontWeight: FontWeight.w800)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),

      // ═══════════════════════════════════════
      // FLOATING EDIT BUTTON (PREMIUM)
      // ═══════════════════════════════════════
      floatingActionButton: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: noteColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: noteColor.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () { HapticFeedback.mediumImpact(); _openEditor(); },
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            icon: const Icon(Icons.edit_rounded, size: 22),
            label: const Text('Edit Note', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════

  Widget _buildActionButton({required IconData icon, required VoidCallback onTap, required bool isDark, Color? activeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: activeColor?.withOpacity(0.2) ?? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(12), border: Border.all(color: activeColor?.withOpacity(0.5) ?? (isDark ? Colors.white24 : Colors.black12))),
          child: Icon(icon, color: activeColor ?? (isDark ? Colors.white : Colors.black87), size: 20),
        ),
      ),
    );
  }

  Widget _buildMetaItem({required IconData icon, required String label, required bool isDark, required Color noteColor}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: noteColor.withOpacity(0.8)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaDivider(bool isDark) {
    return Container(width: 1, height: 35, margin: const EdgeInsets.symmetric(horizontal: 10), color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1));
  }

  String _formatFullDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : hour;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]}, $displayHour:$minute $amPm';
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}