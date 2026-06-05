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
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController.forward();
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0D0D1A), const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                  : [const Color(0xFFF8F9FF), const Color(0xFFEEF0FF), Colors.white],
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
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(26) : Colors.black.withAlpha(13),
                borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFFD700).withAlpha(77), blurRadius: 10, offset: const Offset(0, 4))
              ]
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('PRO MEMBER', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFFFFD700).withAlpha(77), Colors.transparent])
              )
          ),
        ),
        Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD700), Color(0xFFF59E0B), Color(0xFFD97706)]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withAlpha(102), blurRadius: 20, spreadRadius: 2)]
            ),
            child: const Icon(Icons.workspace_premium_rounded, size: 50, color: Colors.white)
        ),
      ]),
      const SizedBox(height: 24),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]).createShader(bounds),
        child: const Text('Unlock Your Full Potential', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5, height: 1.2)),
      ),
      const SizedBox(height: 12),
      Text('Join the elite 1% who crush their goals daily.\nStand out, stay focused, and achieve more.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black54, height: 1.5, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildFeaturesGrid(bool isDark) {
    final features = [
      _FeatureItem(icon: Icons.workspace_premium_rounded, title: 'Exclusive Pro Badge', subtitle: 'Show off your crown everywhere', color: const Color(0xFFFFD700)),
      _FeatureItem(icon: Icons.all_inclusive_rounded, title: 'Unlimited Habits', subtitle: 'No restrictions on your growth', color: const Color(0xFF10B981)),
      _FeatureItem(icon: Icons.auto_awesome_rounded, title: 'Smart Routines', subtitle: 'AI-powered productivity', color: const Color(0xFF6C63FF)),
      _FeatureItem(icon: Icons.insights_rounded, title: 'Pro Analytics', subtitle: 'Deep dive into your progress', color: const Color(0xFF3B82F6)),
      _FeatureItem(icon: Icons.block_rounded, title: 'Ad-Free Focus', subtitle: 'Zero distractions, 100% execution', color: const Color(0xFFEF4444)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(15) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withAlpha(26) : Colors.black.withAlpha(13))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PREMIUM BENEFITS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black45, letterSpacing: 1.5)),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final f = features[index];
            return Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: f.color.withAlpha(40), borderRadius: BorderRadius.circular(14)),
                    child: Icon(f.icon, color: f.color, size: 22)
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 2),
                        Text(f.subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
                      ],
                    )
                ),
              ],
            );
          },
        ),
      ]),
    );
  }

  Widget _buildPlanCards(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SELECT YOUR PLAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black45, letterSpacing: 1.5)),
      const SizedBox(height: 16),
      _buildPlanCard(
          productId: AppConfig.yearlyProductId,
          title: 'Yearly Subscription',
          price: AppConfig.yearlyPrice,
          period: '/year',
          subtitle: 'Save 32% instantly. Smartest choice.',
          badge: '👑 BEST VALUE',
          badgeColor: const Color(0xFFFFD700),
          isDark: isDark
      ),
      const SizedBox(height: 14),
      _buildPlanCard(
          productId: AppConfig.monthlyProductId,
          title: 'Monthly Subscription',
          price: AppConfig.monthlyPrice,
          period: '/month',
          subtitle: 'Flexible, cancel anytime.',
          badge: '⚡ STANDARD',
          badgeColor: const Color(0xFF6C63FF),
          isDark: isDark
      ),
    ]);
  }

  Widget _buildPlanCard({required String productId, required String title, required String price, required String period, required String subtitle, required String badge, required Color badgeColor, required bool isDark}) {
    final isSelected = _selectedPlan == productId;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = productId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withAlpha(20) : (isDark ? Colors.white.withAlpha(10) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? badgeColor : (isDark ? Colors.white.withAlpha(26) : Colors.grey.withAlpha(38)), width: isSelected ? 2.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: badgeColor.withAlpha(40), blurRadius: 15, spreadRadius: 1)] : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: badgeColor.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: badgeColor, letterSpacing: 0.5)),
              ),
              if (isSelected) Icon(Icons.check_circle_rounded, color: badgeColor, size: 24)
            ],
          ),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text(period, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45))),
          ]),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
        ]),
      ),
    );
  }

  Widget _buildTrustBadges(bool isDark) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _trustBadge(Icons.security_rounded, 'Secure\nPayment', isDark),
      _trustBadge(Icons.restore_rounded, 'Auto\nRestore', isDark),
      _trustBadge(Icons.cancel_outlined, 'Cancel\nAnytime', isDark),
    ]);
  }

  Widget _trustBadge(IconData icon, String label, bool isDark) {
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(26), shape: BoxShape.circle),
          child: Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 24)
      ),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black45, height: 1.3)),
    ]);
  }

  Widget _buildStickyBottomBar(bool isDark) {
    String displayPrice = _selectedPlan == AppConfig.monthlyProductId ? AppConfig.monthlyPrice : AppConfig.yearlyPrice;
    Color btnColor = _selectedPlan == AppConfig.yearlyProductId ? const Color(0xFFFFD700) : const Color(0xFF6C63FF);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16213E) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 77 : 20), blurRadius: 25, offset: const Offset(0, -10))]
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: double.infinity, height: 60,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: _selectedPlan == AppConfig.yearlyProductId ? [const Color(0xFFFFD700), const Color(0xFFF59E0B)] : [const Color(0xFF6C63FF), const Color(0xFF4338CA)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: btnColor.withAlpha(77), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _buySelectedPlan,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_open_rounded, size: 22, color: Colors.white),
                const SizedBox(width: 10),
                Flexible(child: Text('Unlock Pro for $displayPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: _restorePurchases, child: Text('Restore Purchases', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w700, fontSize: 13))),
          Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: isDark ? Colors.white38 : Colors.black26, shape: BoxShape.circle)),
          TextButton(onPressed: () => UrlService.openUrl(AppConfig.termsUrl, context), child: Text('Terms & Policy', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      ]),
    );
  }

  Future<void> _buySelectedPlan() async {
    setState(() => _isLoading = true);
    final success = await PurchaseService.buyProduct(_selectedPlan);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase could not be completed at this time.'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final restored = await PurchaseService.restorePurchases();
    if (!mounted) return;

    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    final isPro = DatabaseService.isProUser();
    if (restored) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPro ? 'Pro Status Restored! 👑' : 'No previous purchases found'), behavior: SnackBarBehavior.floating));
      if (isPro) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to connect to Store'), behavior: SnackBarBehavior.floating));
    }
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  _FeatureItem({required this.icon, required this.title, required this.subtitle, required this.color});
}