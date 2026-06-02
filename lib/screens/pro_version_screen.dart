import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/database_service.dart';
import '../services/purchase_service.dart';
import '../services/url_service.dart';

class ProVersionScreen extends StatefulWidget {
  const ProVersionScreen({super.key});

  @override
  State<ProVersionScreen> createState() => _ProVersionScreenState();
}

class _ProVersionScreenState extends State<ProVersionScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  String _selectedPlan = AppConfig.yearlyProductId;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _fadeController.forward();

    // Check if products are loaded
    PurchaseService.loadProducts();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: isDark ? [const Color(0xFF0D0D1A), const Color(0xFF1A1A2E), const Color(0xFF16213E)] : [const Color(0xFFF8F9FF), const Color(0xFFEEF0FF), Colors.white],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      const SizedBox(height: 10),
                      _buildHeroSection(isDark),
                      const SizedBox(height: 32),
                      _buildFeaturesGrid(isDark),
                      const SizedBox(height: 32),
                      _buildPlanCards(isDark),
                      const SizedBox(height: 28),
                      _buildTrustBadges(isDark),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
                _buildStickyBottomBar(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(26) : Colors.black.withAlpha(13), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('PREMIUM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ]),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFF6C63FF).withAlpha(77), const Color(0xFF6C63FF).withAlpha(0)]))),
        Container(width: 90, height: 90, decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6C63FF), Color(0xFF4338CA), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(28)),
            child: const Icon(Icons.diamond_rounded, size: 45, color: Colors.white)),
      ]),
      const SizedBox(height: 24),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9333EA)]).createShader(bounds),
        child: const Text('Unlock Premium', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
      ),
      const SizedBox(height: 12),
      Text('Transform your habits with powerful tools\nand a cleaner ad-free experience', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.black54, height: 1.5)),
    ]);
  }

  Widget _buildFeaturesGrid(bool isDark) {
    final features = [
      _FeatureItem(icon: Icons.all_inclusive_rounded, title: 'Unlimited Habits', color: const Color(0xFF10B981)),
      _FeatureItem(icon: Icons.block_rounded, title: 'No Ads, Ever', color: const Color(0xFFEF4444)),
      _FeatureItem(icon: Icons.insights_rounded, title: 'Pro Analytics', color: const Color(0xFF3B82F6)),
      _FeatureItem(icon: Icons.auto_awesome_rounded, title: 'Smart Routines', color: const Color(0xFFF59E0B)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(13) : Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WHAT YOU GET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final f = features[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: f.color.withAlpha(26), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: f.color.withAlpha(51), borderRadius: BorderRadius.circular(10)), child: Icon(f.icon, color: f.color, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(f.title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildPlanCards(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CHOOSE YOUR PLAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 1.5)),
      const SizedBox(height: 16),
      _buildPlanCard(productId: AppConfig.yearlyProductId, title: 'Yearly', price: AppConfig.yearlyPrice, period: '/year', subtitle: 'Save 32% • Best Value', badge: '🔥 MOST POPULAR', badgeColor: const Color(0xFFFF6B6B), isDark: isDark),
      const SizedBox(height: 12),
      _buildPlanCard(productId: AppConfig.monthlyProductId, title: 'Monthly', price: AppConfig.monthlyPrice, period: '/month', subtitle: 'Flexible plan', badge: '⚡ FLEXIBLE', badgeColor: const Color(0xFF3B82F6), isDark: isDark),
    ]);
  }

  Widget _buildPlanCard({required String productId, required String title, required String price, required String period, required String subtitle, required String badge, required Color badgeColor, required bool isDark}) {
    final isSelected = _selectedPlan == productId;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = productId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6C63FF), Color(0xFF4338CA)]) : null,
          color: isSelected ? null : (isDark ? Colors.white.withAlpha(13) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white.withAlpha(26) : Colors.grey.withAlpha(38)), width: 2),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: isSelected ? Colors.white.withAlpha(51) : badgeColor.withAlpha(26), borderRadius: BorderRadius.circular(20)),
            child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : badgeColor)),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(period, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white70 : (isDark ? Colors.white54 : Colors.black45)))),
          ]),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white70 : (isDark ? Colors.white54 : Colors.black45))),
        ]),
      ),
    );
  }

  Widget _buildTrustBadges(bool isDark) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _trustBadge(Icons.security_rounded, 'Secure Play', isDark),
      _trustBadge(Icons.restore_rounded, 'Auto Restore', isDark),
      _trustBadge(Icons.cancel_outlined, 'Cancel Anytime', isDark),
    ]);
  }

  Widget _trustBadge(IconData icon, String label, bool isDark) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(13) : Colors.grey.withAlpha(26), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 22)),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
    ]);
  }

  Widget _buildStickyBottomBar(bool isDark) {
    String displayPrice = _selectedPlan == AppConfig.monthlyProductId ? AppConfig.monthlyPrice : AppConfig.yearlyPrice;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 77 : 20), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: double.infinity, height: 60,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF4338CA)]), borderRadius: BorderRadius.circular(20)),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _buySelectedPlan,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shopping_cart_checkout_rounded, size: 22),
                const SizedBox(width: 10),
                Flexible(child: Text('Subscribe for $displayPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: _restorePurchases, child: Text('Restore Purchases', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w600, fontSize: 13))),
          Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: isDark ? Colors.white38 : Colors.black26, shape: BoxShape.circle)),
          TextButton(onPressed: () => UrlService.openUrl(AppConfig.termsUrl, context), child: Text('Terms', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      ]),
    );
  }

  Future<void> _buySelectedPlan() async {
    setState(() => _isLoading = true);

    // Real call to Google Play
    final success = await PurchaseService.buyProduct(_selectedPlan);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase could not be completed. Product might not be available in Play Console yet.'), behavior: SnackBarBehavior.floating));
    } else {
      // The _onPurchaseUpdate listener in PurchaseService will handle success dialogs.
      // But we can show a temporary one here if needed.
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final restored = await PurchaseService.restorePurchases();

    if (!mounted) return;

    // Give it a second to process
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    final isPro = DatabaseService.isProUser();

    if (restored) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPro ? 'Purchases restored ✅' : 'No previous purchases found'), behavior: SnackBarBehavior.floating));
      if (isPro) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to connect to App Store/Play Store'), behavior: SnackBarBehavior.floating));
    }
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final Color color;
  _FeatureItem({required this.icon, required this.title, required this.color});
}