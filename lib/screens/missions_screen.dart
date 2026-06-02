import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/habit_model.dart';
import '../services/database_service.dart';
import '../services/missions_service.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  String _selectedCategory = 'All';
  List<HabitMission> _filteredMissions = [];

  @override
  void initState() {
    super.initState();
    _filteredMissions = MissionsService.getAllMissions();
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filteredMissions = category == 'All'
          ? MissionsService.getAllMissions()
          : MissionsService.getMissionsByCategory(category);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ['All', ...MissionsService.getCategories()];

    return Scaffold(
      appBar: AppBar(title: const Text('Habit Missions'), centerTitle: true),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(category),
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    backgroundColor: isDark ? Colors.white.withAlpha(26) : Colors.grey.shade100,
                    selectedColor: AppConfig.primaryColor,
                    checkmarkColor: Colors.white,
                    onSelected: (_) => _filterByCategory(category),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('${_filteredMissions.length} missions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredMissions.length,
              itemBuilder: (context, index) => _buildMissionCard(_filteredMissions[index], isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(HabitMission mission, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMissionDetails(mission),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: mission.colorValue.withAlpha(38), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(mission.emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mission.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(mission.description, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _tag(mission.category, mission.colorValue),
                  _tag(mission.duration, Colors.grey),
                  _difficultyBadge(mission.difficulty),
                ]),
              ])),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black26),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _difficultyBadge(String difficulty) {
    final color = switch (difficulty.toLowerCase()) { 'easy' => Colors.green, 'medium' => Colors.orange, 'hard' => Colors.red, _ => Colors.grey };
    return _tag(difficulty, color);
  }

  void _showMissionDetails(HabitMission mission) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(width: 80, height: 80, decoration: BoxDecoration(color: mission.colorValue.withAlpha(38), borderRadius: BorderRadius.circular(24)), child: Center(child: Text(mission.emoji, style: const TextStyle(fontSize: 40)))),
          const SizedBox(height: 16),
          Text(mission.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text(mission.description, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _detailChip(Icons.timer_outlined, mission.duration, Colors.blue),
            _detailChip(Icons.category_outlined, mission.category, mission.colorValue),
            _detailChip(Icons.speed_outlined, mission.difficulty, _getDifficultyColor(mission.difficulty)),
          ]),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Text('Benefits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))),
          const SizedBox(height: 12),
          ...mission.benefits.map((benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: mission.colorValue, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(benefit, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54))),
            ]),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _addMissionAsHabit(mission),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add This Habit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: mission.colorValue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Color _getDifficultyColor(String d) => switch (d.toLowerCase()) { 'easy' => Colors.green, 'medium' => Colors.orange, 'hard' => Colors.red, _ => Colors.grey };

  Future<void> _addMissionAsHabit(HabitMission mission) async {
    final habit = Habit(id: DateTime.now().millisecondsSinceEpoch.toString(), name: mission.name, emoji: mission.emoji, colorValue: mission.color, category: mission.category, frequency: 'daily', createdAt: DateTime.now());
    await DatabaseService.addHabit(habit);
    if (mounted) {
      Navigator.pop(context);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${mission.emoji} ${mission.name} added! 🎉'), behavior: SnackBarBehavior.floating));
    }
  }
}