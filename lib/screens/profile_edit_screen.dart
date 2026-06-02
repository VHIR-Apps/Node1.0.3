// lib/screens/profile_edit_screen.dart

import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  final TextEditingController _nameC = TextEditingController();

  final String? myUid = AuthService.instance.uid;
  String _selectedAvatar = '😎';
  bool _isLoading = false;

  // ফ্লাটারের বিল্ট-ইন ইমোজি অবতার অপশন
  final List<String> _avatars = ['😎', '🚀', '🔥', '🧠', '👑', '🐱', '🦉', '⚡', '💎', '🎯', '🎸', '🎨'];

  int _myLevel = 1;
  int _myTotalXp = 0;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _loadProfileData();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (myUid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('leaderboard_v1_profiles').doc(myUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameC.text = data['username'] ?? '';
          _selectedAvatar = data['avatar'] ?? '😎';
          _myLevel = data['level'] ?? 1;
          _myTotalXp = data['score'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _saveProfile() async {
    if (myUid == null) return;
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty!'), backgroundColor: AppConfig.errorColor),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    SoundService.playTap(); // আপনার সাউন্ড সার্ভিস

    try {
      await FirebaseFirestore.instance.collection('leaderboard_v1_profiles').doc(myUid).set({
        'username': name,
        'avatar': _selectedAvatar,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Updated Successfully! 🚀'), backgroundColor: AppConfig.successColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppConfig.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  // 🎨 UI COMPONENTS
  // ─────────────────────────────────────────────

  Widget _buildGlassCard({required Widget child, required bool isDark, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
      body: Stack(
        children: [
          // 🌌 Animated Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final t = _bgController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: -50 + (40 * math.sin(t)),
                    left: -50 + (30 * math.cos(t)),
                    child: Container(
                      width: 300, height: 300,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.primaryColor.withOpacity(isDark ? 0.08 : 0.04)),
                    ),
                  ),
                  Positioned(
                    bottom: -100 + (30 * math.cos(t * 0.8)),
                    right: -50 + (40 * math.sin(t * 1.2)),
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppConfig.accentColor.withOpacity(isDark ? 0.08 : 0.04)),
                    ),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 👤 Avatar Selector
                  _buildGlassCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        Text('Choose Your Avatar', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.white54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _avatars.length,
                            itemBuilder: (context, index) {
                              final avatar = _avatars[index];
                              final isSelected = _selectedAvatar == avatar;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedAvatar = avatar);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppConfig.primaryColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? AppConfig.primaryColor : Colors.transparent, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(avatar, style: const TextStyle(fontSize: 28)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 📝 Name Input & Stats
                  _buildGlassCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Display Name', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.white54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _nameC,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w800, fontSize: 18),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter your superhero name...',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppConfig.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  children: [
                                    const Icon(Icons.star_rounded, color: AppConfig.primaryColor, size: 28),
                                    const SizedBox(height: 4),
                                    Text('Level $_myLevel', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppConfig.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, color: AppConfig.accentColor, size: 28),
                                    const SizedBox(height: 4),
                                    Text('$_myTotalXp XP', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 💾 Save Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 8,
                        shadowColor: AppConfig.primaryColor.withOpacity(0.5),
                      ),
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 📝 My Posts Section (Placeholder for Phase 3)
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        // TODO: Navigate to My Posts History Screen
                      },
                      icon: const Icon(Icons.history_rounded, color: AppConfig.accentColor),
                      label: const Text('Manage My Posts', style: TextStyle(color: AppConfig.accentColor, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}