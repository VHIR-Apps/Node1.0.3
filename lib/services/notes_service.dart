// lib/services/notes_service.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';

class NotesService {
  static late Box<Note> _notesBox;

  static const String _boxName = 'notes';

  // ═══════════════════════════════════════
  // 🔧 INIT
  // ═══════════════════════════════════════

  static Future<void> init() async {
    try {
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(NoteAdapter());
      }
      _notesBox = await Hive.openBox<Note>(_boxName);
      debugPrint('✅ NotesService initialized.');
    } catch (e) {
      debugPrint('❌ NotesService init error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // 📝 CREATE NOTE
  // ═══════════════════════════════════════

  static Future<Note> createNote({
    required String title,
    required String content,
    String color = '#FFB300',
    int priority = 0,
    List<String> tags = const [],
  }) async {
    try {
      final note = Note(
        id: const Uuid().v4(),
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        color: color,
        priority: priority,
        tags: tags,
      );

      await _notesBox.put(note.id, note);
      debugPrint('✅ Note created: ${note.id}');
      return note;
    } catch (e) {
      debugPrint('❌ Create note error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // 📖 GET ALL NOTES
  // ═══════════════════════════════════════

  static List<Note> getAllNotes() {
    try {
      final notes = _notesBox.values.toList();
      // Sort: pinned first, then by updatedAt (newest first)
      notes.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return notes;
    } catch (e) {
      debugPrint('❌ Get all notes error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // 🔍 GET NOTE BY ID
  // ═══════════════════════════════════════

  static Note? getNoteById(String id) {
    try {
      return _notesBox.get(id);
    } catch (e) {
      debugPrint('❌ Get note error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // ✏️ UPDATE NOTE
  // ═══════════════════════════════════════

  static Future<Note?> updateNote(
      String id, {
        String? title,
        String? content,
        String? color,
        int? priority,
        bool? isPinned,
        List<String>? tags,
      }) async {
    try {
      final note = _notesBox.get(id);
      if (note == null) return null;

      if (title != null) note.title = title;
      if (content != null) note.content = content;
      if (color != null) note.color = color;
      if (priority != null) note.priority = priority;
      if (isPinned != null) note.isPinned = isPinned;
      if (tags != null) note.tags = tags;

      note.updatedAt = DateTime.now();
      await note.save();

      debugPrint('✅ Note updated: $id');
      return note;
    } catch (e) {
      debugPrint('❌ Update note error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // 🗑️ DELETE NOTE
  // ═══════════════════════════════════════

  static Future<bool> deleteNote(String id) async {
    try {
      await _notesBox.delete(id);
      debugPrint('✅ Note deleted: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Delete note error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════
  // 📊 GET STATS
  // ═══════════════════════════════════════

  static Map<String, int> getStats() {
    try {
      final notes = _notesBox.values.toList();
      int totalNotes = notes.length;
      int pinnedNotes = notes.where((n) => n.isPinned).length;
      int totalWords = 0;

      for (var note in notes) {
        totalWords += note.content.split(' ').where((w) => w.isNotEmpty).length;
      }

      return {
        'total': totalNotes,
        'pinned': pinnedNotes,
        'words': totalWords,
      };
    } catch (e) {
      return {'total': 0, 'pinned': 0, 'words': 0};
    }
  }

  // ═══════════════════════════════════════
  // 🔍 SEARCH NOTES
  // ═══════════════════════════════════════

  static List<Note> searchNotes(String query) {
    try {
      final notes = _notesBox.values.toList();
      final filtered = notes
          .where((note) =>
      note.title.toLowerCase().contains(query.toLowerCase()) ||
          note.content.toLowerCase().contains(query.toLowerCase()))
          .toList();

      filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return filtered;
    } catch (e) {
      debugPrint('❌ Search error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // 💾 BACKUP (in app's backup system)
  // ═══════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getNotesForBackup() async {
    try {
      final notes = _notesBox.values.toList();
      return notes.map((note) => note.toJson()).toList();
    } catch (e) {
      debugPrint('❌ Backup notes error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // 📥 RESTORE (from app's backup system)
  // ═══════════════════════════════════════

  static Future<int> restoreNotesFromBackup(
      List<Map<String, dynamic>> backupData) async {
    try {
      int count = 0;
      for (var data in backupData) {
        try {
          final note = Note.fromJson(data);
          await _notesBox.put(note.id, note);
          count++;
        } catch (e) {
          debugPrint('⚠️ Restore note error: $e');
        }
      }
      debugPrint('✅ Restored $count notes from backup');
      return count;
    } catch (e) {
      debugPrint('❌ Restore notes error: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════
  // 🧹 CLEAR ALL NOTES
  // ═══════════════════════════════════════

  static Future<void> clearAllNotes() async {
    try {
      await _notesBox.clear();
      debugPrint('✅ All notes cleared');
    } catch (e) {
      debugPrint('❌ Clear notes error: $e');
    }
  }

  // ═══════════════════════════════════════
  // 📈 GET TOTAL NOTES COUNT
  // ═══════════════════════════════════════

  static int getTotalNotesCount() {
    return _notesBox.length;
  }
}