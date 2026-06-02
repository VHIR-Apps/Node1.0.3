// lib/screens/notes_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/note_model.dart';
import '../services/notes_service.dart';
import '../services/sound_service.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';
import 'note_view_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  late AnimationController _bgAnimationController;

  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isSearching = false;
  String _searchQuery = '';

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );

    // 🚀 Ambient Background Animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _loadNotes();
    _fabController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabController.dispose();
    _bgAnimationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadNotes() {
    setState(() {
      _notes = NotesService.getAllNotes();
      _applyFilters();
    });
  }

  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredNotes = _notes;
    } else {
      _filteredNotes = NotesService.searchNotes(_searchQuery);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        _applyFilters();
      });
    });
  }

  void _openNoteView(Note note) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return NoteViewScreen(
            note: note,
            onNoteUpdated: _loadNotes,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _openNoteEditor({Note? note}) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return NoteEditorScreen(
            note: note,
            onSave: (savedNote) async {
              if (note == null) {
                await NotesService.createNote(
                  title: savedNote.title,
                  content: savedNote.content,
                  color: savedNote.color,
                  priority: savedNote.priority,
                  tags: savedNote.tags,
                );
              } else {
                await NotesService.updateNote(
                  note.id,
                  title: savedNote.title,
                  content: savedNote.content,
                  color: savedNote.color,
                  priority: savedNote.priority,
                  isPinned: savedNote.isPinned,
                  tags: savedNote.tags,
                );
              }
              _loadNotes();
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _deleteNote(String id) {
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
              Text('This action cannot be undone. Are you sure?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, height: 1.5)),
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
                        Navigator.pop(context);
                        await NotesService.deleteNote(id);
                        HapticFeedback.mediumImpact();
                        SoundService.playTap();
                        _loadNotes();

                        if (mounted) {
                          _showSnack('Note deleted successfully', isError: true);
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

  void _togglePin(String id) async {
    final note = NotesService.getNoteById(id);
    if (note != null) {
      await NotesService.updateNote(id, isPinned: !note.isPinned);
      HapticFeedback.lightImpact();
      _loadNotes();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
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
          gradientColors: isError ? [AppConfig.errorColor.withOpacity(0.9), Colors.redAccent.withOpacity(0.7)] : [AppConfig.primaryColor.withOpacity(0.9), const Color(0xFF3B82F6).withOpacity(0.8)],
          child: Row(
            children: [
              Icon(isError ? Icons.delete_sweep_rounded : Icons.check_circle_rounded, color: Colors.white, size: 20),
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
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight)
                : LinearGradient(
              colors: isDark
                  ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)]
                  : [Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder ? Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 5))
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
    final stats = NotesService.getStats();
    final bgColors = _getBackgroundColors(isDark);

    return Scaffold(
      extendBodyBehindAppBar: true,
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

          // 💎 Floating Ambient Orbs for Notes
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
                      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFB300).withOpacity(isDark ? 0.08 : 0.04), backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply),
                    ),
                  ),
                  Positioned(
                    bottom: 100 + (40 * math.cos(t * 0.8)),
                    right: -50 + (30 * math.sin(t * 1.2)),
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0EA5E9).withOpacity(isDark ? 0.06 : 0.03), backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply),
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
              // GLASSMORPHISM APP BAR
              // ═══════════════════════════════════════
              SliverAppBar(
                expandedHeight: 160,
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
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1020).withOpacity(0.5) : Colors.white.withOpacity(0.5),
                          border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFF59E0B)]),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
                                  ),
                                  child: const Icon(Icons.note_alt_rounded, color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('My Notes', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.1, letterSpacing: -0.5)),
                                      const SizedBox(height: 4),
                                      Text('${stats['total']} notes • ${stats['words']} words', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
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
              // GLASS SEARCH BAR
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: _buildGlassContainer(
                    isDark: isDark,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    borderRadius: 18,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        hintStyle: TextStyle(color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.3), fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppConfig.primaryColor, size: 24),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white60 : Colors.black45, size: 20), onPressed: () { _searchController.clear(); _onSearchChanged(''); })
                            : null,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // GLASS STATS BAR
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildStatCard(icon: Icons.description_rounded, value: '${stats['total']}', label: 'Total', color: const Color(0xFF0EA5E9), isDark: isDark),
                      const SizedBox(width: 12),
                      _buildStatCard(icon: Icons.push_pin_rounded, value: '${stats['pinned']}', label: 'Pinned', color: const Color(0xFFFFB300), isDark: isDark),
                      const SizedBox(width: 12),
                      _buildStatCard(icon: Icons.text_fields_rounded, value: '${stats['words']}', label: 'Words', color: const Color(0xFF10B981), isDark: isDark),
                    ],
                  ),
                ),
              ),

              // ═══════════════════════════════════════
              // NOTES GRID
              // ═══════════════════════════════════════
              _filteredNotes.isEmpty
                  ? SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(isDark),
              )
                  : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final note = _filteredNotes[index];
                      return NoteCard(
                        note: note,
                        onTap: () => _openNoteView(note),
                        onDelete: () => _deleteNote(note.id),
                        onPin: () => _togglePin(note.id),
                      );
                    },
                    childCount: _filteredNotes.length,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // ═══════════════════════════════════════
      // FLOATING ACTION BUTTON (PREMIUM)
      // ═══════════════════════════════════════
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppConfig.primaryColor, Color(0xFF6366F1)]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: AppConfig.primaryColor.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _openNoteEditor(),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            icon: const Icon(Icons.add_rounded, size: 24),
            label: const Text('New Note', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String value, required String label, required Color color, required bool isDark}) {
    return Expanded(
      child: _buildGlassContainer(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        borderRadius: 20,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.note_add_rounded, size: 70, color: AppConfig.primaryColor.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Text(_searchQuery.isEmpty ? 'No notes initialized' : 'No matches found', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchQuery.isEmpty ? 'Tap the button below to draft your first entry' : 'Modify your search parameters',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 15, fontWeight: FontWeight.w600, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}