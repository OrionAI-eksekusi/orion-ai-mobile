import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

const String _ZAPI = 'https://web-production-d2935.up.railway.app';

// ── Colors ────────────────────────────────────────────────
class _ZC {
  static const bg = Color(0xFF020818);
  static const surface = Color(0xFF060F24);
  static const border = Color(0xFF1A3A8F);
  static const text = Color(0xFFD0DCFF);
  static const textDim = Color(0xFF3A5A9A);
  static const gold = Color(0xFFFFD700);
  static const goldDim = Color(0xFF8B7A3A);
  static const danger = Color(0xFFFF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF2D8B4E);
  static const primary = Color(0xFF2D5BE3);
  static const primaryLight = Color(0xFF6B9FFF);
}

// ── Star Painter ──────────────────────────────────────────
class _ZStar {
  final double x, y, size, opacity, twinkle, speed;
  _ZStar({required this.x, required this.y, required this.size,
      required this.opacity, required this.twinkle, required this.speed});
}

class _ZStarPainter extends CustomPainter {
  final double progress;
  final List<_ZStar> stars;
  _ZStarPainter(this.progress, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final t = (math.sin((progress * s.speed + s.twinkle) * 2 * math.pi) + 1) / 2;
      final op = s.opacity * (0.2 + 0.8 * t);
      final glowPaint = Paint()
        ..color = Color.fromRGBO(255, 215, 0, op * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.size * 2, glowPaint);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        Paint()..color = Color.fromRGBO(220, 200, 255, op),
      );
    }
  }

  @override
  bool shouldRepaint(_ZStarPainter old) => true;
}

// ── Zenith Screen ─────────────────────────────────────────
class ZenithScreen extends StatefulWidget {
  const ZenithScreen({super.key});

  @override
  State<ZenithScreen> createState() => _ZenithScreenState();
}

class _ZenithScreenState extends State<ZenithScreen>
    with TickerProviderStateMixin {
  late AnimationController _starController;
  late List<_ZStar> _stars;
  late TabController _tabController;

  String _userId = 'default';
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _alerts = [];
  bool _loading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this, duration: const Duration(seconds: 20),
    )..repeat();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _selectedTab = _tabController.index);
    });

    final rng = math.Random(77);
    _stars = List.generate(150, (_) => _ZStar(
      x: rng.nextDouble(), y: rng.nextDouble(),
      size: rng.nextDouble() * 2 + 0.3,
      opacity: rng.nextDouble() * 0.7 + 0.2,
      twinkle: rng.nextDouble(),
      speed: rng.nextDouble() * 0.5 + 0.3,
    ));

    _loadData();
  }

  @override
  void dispose() {
    _starController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'default';
    setState(() => _userId = userId);

    setState(() => _loading = true);
    try {
      final dashRes = await http.get(
        Uri.parse('$_ZAPI/zenith/dashboard/$userId'),
      ).timeout(const Duration(seconds: 10));

      final alertRes = await http.get(
        Uri.parse('$_ZAPI/zenith/alerts/$userId'),
      ).timeout(const Duration(seconds: 10));

      if (dashRes.statusCode == 200) {
        final data = jsonDecode(dashRes.body);
        setState(() => _dashboard = data['dashboard'] ?? {});
      }
      if (alertRes.statusCode == 200) {
        final data = jsonDecode(alertRes.body);
        setState(() => _alerts = data['alerts'] ?? []);
      }
    } catch (e) {
      debugPrint('[ZENITH] Load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ZC.bg,
      body: Stack(
        children: [
          // Bintang penuh layar
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _ZStarPainter(_starController.value, _stars),
              size: Size.infinite,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: _loading
                      ? _buildLoading()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDashboard(),
                            _buildPriceGuard(),
                            _buildAnomalies(),
                            _buildVendorIntel(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final overview = _dashboard['overview'] ?? {};
    final alerts = _dashboard['alerts'] ?? {};
    final highAlerts = alerts['high'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF050508).withOpacity(0.9),
        border: Border(bottom: BorderSide(
            color: _ZC.gold.withOpacity(0.2), width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _ZC.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _ZC.gold.withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _ZC.gold, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_ZC.gold, Color(0xFFFFF3A0), _ZC.gold],
                ).createShader(b),
                child: const Text('ZENITH',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 2)),
              ),
              const Text('Enterprise Risk Intelligence',
                  style: TextStyle(fontSize: 9, color: _ZC.goldDim, letterSpacing: 1)),
            ],
          ),
          const Spacer(),
          if (highAlerts > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _ZC.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _ZC.danger.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 5, height: 5,
                    decoration: const BoxDecoration(color: _ZC.danger, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('$highAlerts ALERT',
                    style: const TextStyle(fontSize: 9, color: _ZC.danger,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _ZC.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _ZC.success.withOpacity(0.3)),
              ),
              child: const Text('✅ AMAN',
                  style: TextStyle(fontSize: 9, color: _ZC.success,
                      fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _ZC.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _ZC.gold.withOpacity(0.3)),
              ),
              child: const Icon(Icons.refresh_rounded, color: _ZC.gold, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['📊 Dashboard', '🛡️ Price Guard', '⚠️ Anomali', '🔍 Vendor'];
    return Container(
      color: const Color(0xFF050508).withOpacity(0.8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: _ZC.gold,
        indicatorWeight: 2,
        labelColor: _ZC.gold,
        unselectedLabelColor: _ZC.textDim,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: _ZC.gold.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _ZC.gold.withOpacity(0.3)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: _ZC.gold, strokeWidth: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Zenith AI menganalisa data...',
              style: TextStyle(color: _ZC.goldDim, fontSize: 12)),
        ],
      ),
    );
  }

  // ── TAB 1: Executive Dashboard ───────────────────────────
  Widget _buildDashboard() {
    final overview = _dashboard['overview'] ?? {};
    final topVendors = List<dynamic>.from(_dashboard['top_vendors'] ?? []);
    final riskyVendors = List<dynamic>.from(_dashboard['risky_vendors'] ?? []);
    final monthly = List<dynamic>.from(_dashboard['monthly_trend'] ?? []);
    final alerts = _dashboard['alerts'] ?? {};

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _ZC.gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overview cards
          Row(children: [
            Expanded(child: _overviewCard('TOTAL SPEND',
                _formatRp(overview['total_spend'] ?? 0),
                Icons.account_balance_wallet_rounded, _ZC.gold)),
            const SizedBox(width: 8),
            Expanded(child: _overviewCard('TRANSAKSI',
                '${overview['total_transactions'] ?? 0}',
                Icons.receipt_rounded, _ZC.primaryLight)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _overviewCard('POTENSI RISIKO',
                _formatRp(overview['potential_loss'] ?? 0),
                Icons.warning_rounded, _ZC.danger)),
            const SizedBox(width: 8),
            Expanded(child: _overviewCard('ALERTS',
                '${alerts['total'] ?? 0}',
                Icons.notifications_active_rounded, _ZC.warning)),
          ]),
          const SizedBox(height: 16),

          // Alert summary
          if (_alerts.isNotEmpty) ...[
            _sectionTitle('🚨 RISK ALERTS TERBARU'),
            const SizedBox(height: 8),
            ..._alerts.take(3).map((a) => _alertCard(a)),
            const SizedBox(height: 16),
          ],

          // Top vendors
          if (topVendors.isNotEmpty) ...[
            _sectionTitle('🏢 TOP VENDOR BY SPEND'),
            const SizedBox(height: 8),
            ...topVendors.map((v) => _vendorSpendCard(v)),
            const SizedBox(height: 16),
          ],

          // Risky vendors
          if (riskyVendors.isNotEmpty) ...[
            _sectionTitle('⚠️ VENDOR BERISIKO'),
            const SizedBox(height: 8),
            ...riskyVendors.map((v) => _riskyVendorCard(v)),
            const SizedBox(height: 16),
          ],

          // Monthly trend
          if (monthly.isNotEmpty) ...[
            _sectionTitle('📈 TREND BULANAN'),
            const SizedBox(height: 8),
            ...monthly.map((m) => _monthlyCard(m)),
          ],

          if (overview.isEmpty)
            _emptyState('Belum ada data transaksi',
                'Tambah transaksi di tab Price Guard untuk mulai analisa'),
        ],
      ),
    );
  }

  // ── TAB 2: Price Guard ───────────────────────────────────
  Widget _buildPriceGuard() {
    return _PriceGuardTab(userId: _userId, onAnalyzed: _loadData);
  }

  // ── TAB 3: Anomalies ─────────────────────────────────────
  Widget _buildAnomalies() {
    return _AnomaliesTab(userId: _userId);
  }

  // ── TAB 4: Vendor Intelligence ───────────────────────────
  Widget _buildVendorIntel() {
    return _VendorIntelTab(userId: _userId);
  }

  // ── Helper Widgets ────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: _ZC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 11, color: _ZC.gold,
          letterSpacing: 1, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _overviewCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7),
                letterSpacing: 0.5, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: color, height: 1)),
        ],
      ),
    );
  }

  Widget _alertCard(dynamic alert) {
    final severity = alert['severity'] ?? 'MEDIUM';
    final color = severity == 'HIGH' ? _ZC.danger : _ZC.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(severity, style: TextStyle(fontSize: 9, color: color,
              fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['vendor'] ?? '', style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _ZC.text)),
            Text(alert['description'] ?? '', style: const TextStyle(
                fontSize: 10, color: _ZC.textDim), maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        )),
        Text(_formatRp(alert['amount'] ?? 0),
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _vendorSpendCard(dynamic vendor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _ZC.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ZC.gold.withOpacity(0.1)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _ZC.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Text('🏢', style: TextStyle(fontSize: 15))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(vendor['vendor'] ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: _ZC.text))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_formatRp(vendor['total'] ?? 0),
              style: const TextStyle(fontSize: 12, color: _ZC.gold,
                  fontWeight: FontWeight.w700)),
          Text('${vendor['count']} transaksi',
              style: const TextStyle(fontSize: 9, color: _ZC.textDim)),
        ]),
      ]),
    );
  }

  Widget _riskyVendorCard(dynamic vendor) {
    final risk = vendor['risk_level'] ?? 'SAFE';
    final color = risk == 'HIGH' ? _ZC.danger
        : risk == 'MEDIUM' ? _ZC.warning : _ZC.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Text(risk == 'HIGH' ? '🔴' : risk == 'MEDIUM' ? '🟡' : '🟢',
            style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(vendor['vendor'] ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: _ZC.text))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(risk, style: TextStyle(fontSize: 9, color: color,
                fontWeight: FontWeight.w700)),
          ),
          Text('Score: ${vendor['risk_score']?.toStringAsFixed(0) ?? 0}',
              style: const TextStyle(fontSize: 9, color: _ZC.textDim)),
        ]),
      ]),
    );
  }

  Widget _monthlyCard(dynamic month) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _ZC.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ZC.border.withOpacity(0.2)),
      ),
      child: Row(children: [
        Text(month['month'] ?? '', style: const TextStyle(
            fontSize: 12, color: _ZC.textDim, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(_formatRp(month['total'] ?? 0),
            style: const TextStyle(fontSize: 13, color: _ZC.gold,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Text('${month['count']} tx',
            style: const TextStyle(fontSize: 10, color: _ZC.textDim)),
      ]),
    );
  }

  Widget _emptyState(String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          const Text('👑', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.w600, color: _ZC.text)),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(fontSize: 12, color: _ZC.textDim),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  String _formatRp(dynamic amount) {
    final num val = (amount is num) ? amount : 0;
    if (val >= 1000000000) return 'Rp ${(val / 1000000000).toStringAsFixed(1)}M';
    if (val >= 1000000) return 'Rp ${(val / 1000000).toStringAsFixed(1)}jt';
    if (val >= 1000) return 'Rp ${(val / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${val.toStringAsFixed(0)}';
  }
}

// ── Price Guard Tab ───────────────────────────────────────
class _PriceGuardTab extends StatefulWidget {
  final String userId;
  final VoidCallback onAnalyzed;
  const _PriceGuardTab({required this.userId, required this.onAnalyzed});

  @override
  State<_PriceGuardTab> createState() => _PriceGuardTabState();
}

class _PriceGuardTabState extends State<_PriceGuardTab> {
  final _vendorCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _category = 'general';
  bool _analyzing = false;
  Map<String, dynamic>? _result;

  final _categories = [
    'general', 'electronics', 'furniture', 'consumables',
    'services', 'construction', 'food', 'transportation'
  ];

  Future<void> _analyze() async {
    if (_vendorCtrl.text.isEmpty || _itemCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi semua field dulu!'),
            backgroundColor: _ZC.danger),
      );
      return;
    }

    setState(() { _analyzing = true; _result = null; });

    try {
      final res = await http.post(
        Uri.parse('$_ZAPI/zenith/price-guard'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'vendor_name': _vendorCtrl.text,
          'item_description': _itemCtrl.text,
          'unit_price': double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
          'quantity': double.tryParse(_qtyCtrl.text) ?? 1,
          'category': _category,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _result = data['analysis']);
        widget.onAnalyzed();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _ZC.danger),
      );
    } finally {
      setState(() => _analyzing = false);
    }
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _itemCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Form input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _ZC.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _ZC.gold.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🛡️ PRICE GUARD ANALYZER',
                  style: TextStyle(fontSize: 12, color: _ZC.gold,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text('Analisa apakah harga vendor wajar atau ada markup',
                  style: TextStyle(fontSize: 10, color: _ZC.textDim)),
              const SizedBox(height: 16),
              _inputField('Nama Vendor', _vendorCtrl, 'PT Maju Jaya'),
              const SizedBox(height: 10),
              _inputField('Deskripsi Item', _itemCtrl, 'Laptop Dell Inspiron 15'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _inputField('Harga Satuan (Rp)', _priceCtrl, '15000000',
                    isNumber: true)),
                const SizedBox(width: 10),
                SizedBox(width: 80, child: _inputField('Qty', _qtyCtrl, '1',
                    isNumber: true)),
              ]),
              const SizedBox(height: 10),
              // Category dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _ZC.bg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _ZC.gold.withOpacity(0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0A0A1A),
                    style: const TextStyle(fontSize: 13, color: _ZC.text),
                    icon: const Icon(Icons.keyboard_arrow_down, color: _ZC.gold, size: 18),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 13, color: _ZC.text)),
                    )).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _analyzing ? null : _analyze,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B6914), _ZC.gold]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: _ZC.gold.withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: _analyzing
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('🛡️ Analisa Harga Sekarang',
                            style: TextStyle(color: Color(0xFF1A0F00),
                                fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Result
        if (_result != null) ...[
          const SizedBox(height: 16),
          _buildResult(_result!),
        ],
      ],
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, String hint,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _ZC.goldDim,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 13, color: _ZC.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: _ZC.textDim),
            filled: true,
            fillColor: _ZC.bg.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _ZC.gold.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _ZC.gold.withOpacity(0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(Map<String, dynamic> result) {
    final risk = result['risk_level'] ?? 'SAFE';
    final score = result['risk_score'] ?? 0;
    final color = risk == 'HIGH' ? _ZC.danger
        : risk == 'MEDIUM' ? _ZC.warning : _ZC.success;
    final emoji = risk == 'HIGH' ? '🔴' : risk == 'MEDIUM' ? '🟡' : '🟢';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('$emoji $risk RISK',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: color)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text('Score: $score',
                  style: TextStyle(fontSize: 12, color: color,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(result['summary'] ?? '',
              style: const TextStyle(fontSize: 13, color: _ZC.text, height: 1.4)),
          if (result['findings'] != null) ...[
            const SizedBox(height: 12),
            const Text('TEMUAN:',
                style: TextStyle(fontSize: 10, color: _ZC.textDim,
                    letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...(result['findings'] as List).map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ', style: TextStyle(color: color)),
                Expanded(child: Text(f.toString(),
                    style: const TextStyle(fontSize: 12, color: _ZC.text))),
              ]),
            )),
          ],
          if (result['recommendation'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _ZC.bg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.lightbulb_outline, color: color, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(result['recommendation'] ?? '',
                    style: TextStyle(fontSize: 11, color: color))),
              ]),
            ),
          ],
          if ((result['potential_savings'] ?? 0) > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _ZC.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Text('💰 Potensi Penghematan: ',
                    style: TextStyle(fontSize: 12, color: _ZC.text)),
                Text(_formatRp(result['potential_savings']),
                    style: const TextStyle(fontSize: 13, color: _ZC.danger,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRp(dynamic amount) {
    final num val = (amount is num) ? amount : 0;
    if (val >= 1000000000) return 'Rp ${(val / 1000000000).toStringAsFixed(1)}M';
    if (val >= 1000000) return 'Rp ${(val / 1000000).toStringAsFixed(1)}jt';
    if (val >= 1000) return 'Rp ${(val / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${val.toStringAsFixed(0)}';
  }
}

// ── Anomalies Tab ─────────────────────────────────────────
class _AnomaliesTab extends StatefulWidget {
  final String userId;
  const _AnomaliesTab({required this.userId});

  @override
  State<_AnomaliesTab> createState() => _AnomaliesTabState();
}

class _AnomaliesTabState extends State<_AnomaliesTab> {
  List<dynamic> _anomalies = [];
  String _summary = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$_ZAPI/zenith/anomalies/${widget.userId}'),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] ?? {};
        setState(() {
          _anomalies = data['anomalies'] ?? [];
          _summary = data['summary'] ?? '';
        });
      }
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _ZC.gold, strokeWidth: 1.5));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _ZC.gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_summary.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _ZC.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _ZC.gold.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Text('🤖', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text(_summary,
                    style: const TextStyle(fontSize: 12, color: _ZC.text, height: 1.4))),
              ]),
            ),
          if (_anomalies.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: const Column(children: [
                Text('✅', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Tidak ada anomali terdeteksi',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: _ZC.success)),
                SizedBox(height: 6),
                Text('Semua transaksi tampak normal',
                    style: TextStyle(fontSize: 12, color: _ZC.textDim)),
              ]),
            )
          else
            ..._anomalies.map((a) {
              final severity = a['severity'] ?? 'MEDIUM';
              final color = severity == 'HIGH' ? _ZC.danger : _ZC.warning;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a['type'] ?? '',
                            style: TextStyle(fontSize: 9, color: color,
                                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(severity,
                            style: TextStyle(fontSize: 9, color: color,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      Text('Score: ${a['risk_score'] ?? 0}',
                          style: TextStyle(fontSize: 10, color: color)),
                    ]),
                    const SizedBox(height: 8),
                    Text(a['description'] ?? '',
                        style: const TextStyle(fontSize: 12, color: _ZC.text, height: 1.4)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Vendor Intel Tab ──────────────────────────────────────
class _VendorIntelTab extends StatefulWidget {
  final String userId;
  const _VendorIntelTab({required this.userId});

  @override
  State<_VendorIntelTab> createState() => _VendorIntelTabState();
}

class _VendorIntelTabState extends State<_VendorIntelTab> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  Map<String, dynamic>? _result;

  Future<void> _search() async {
    if (_searchCtrl.text.isEmpty) return;
    setState(() { _searching = true; _result = null; });
    try {
      final res = await http.post(
        Uri.parse('$_ZAPI/zenith/vendor-intelligence'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'vendor_name': _searchCtrl.text,
        }),
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _result = data['intelligence']);
      }
    } catch (_) {} finally {
      setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _ZC.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _ZC.gold.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔍 VENDOR INTELLIGENCE',
                  style: TextStyle(fontSize: 12, color: _ZC.gold,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text('Deep analisa profil dan risiko vendor',
                  style: TextStyle(fontSize: 10, color: _ZC.textDim)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13, color: _ZC.text),
                    decoration: InputDecoration(
                      hintText: 'Nama vendor...',
                      hintStyle: const TextStyle(color: _ZC.textDim, fontSize: 12),
                      filled: true,
                      fillColor: _ZC.bg.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _ZC.gold.withOpacity(0.2)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _searching ? null : _search,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF8B6914), _ZC.gold]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.search_rounded,
                            color: Color(0xFF1A0F00), size: 20),
                  ),
                ),
              ]),
            ],
          ),
        ),

        if (_result != null) ...[
          const SizedBox(height: 16),
          _buildIntelResult(_result!),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: const Column(children: [
              Text('🔍', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('Cari vendor untuk analisa',
                  style: TextStyle(fontSize: 14, color: _ZC.textDim)),
              SizedBox(height: 6),
              Text('Masukkan nama vendor di atas',
                  style: TextStyle(fontSize: 11, color: _ZC.textDim)),
            ]),
          ),
      ],
    );
  }

  Widget _buildIntelResult(Map<String, dynamic> result) {
    final risk = result['risk_level'] ?? 'UNKNOWN';
    final color = risk == 'HIGH' ? _ZC.danger
        : risk == 'MEDIUM' ? _ZC.warning
        : risk == 'SAFE' ? _ZC.success : _ZC.textDim;
    final trustScore = result['trust_score'] ?? 50;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ZC.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ZC.gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(result['vendor_name'] ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: _ZC.text)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(risk,
                  style: TextStyle(fontSize: 11, color: color,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _intelStat('Transaksi', '${result['total_transactions'] ?? 0}', _ZC.primaryLight),
            const SizedBox(width: 12),
            _intelStat('Trust Score', '$trustScore/100',
                trustScore > 70 ? _ZC.success : trustScore > 40 ? _ZC.warning : _ZC.danger),
          ]),
          const SizedBox(height: 12),
          Text(result['summary'] ?? '',
              style: const TextStyle(fontSize: 12, color: _ZC.text, height: 1.4)),
          if ((result['red_flags'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            const Text('🚩 RED FLAGS:',
                style: TextStyle(fontSize: 10, color: _ZC.danger,
                    letterSpacing: 1, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...(result['red_flags'] as List).map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(color: _ZC.danger)),
                Expanded(child: Text(f.toString(),
                    style: const TextStyle(fontSize: 12, color: _ZC.text))),
              ]),
            )),
          ],
          if ((result['positive_signals'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Text('✅ POSITIF:',
                style: TextStyle(fontSize: 10, color: _ZC.success,
                    letterSpacing: 1, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...(result['positive_signals'] as List).map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(color: _ZC.success)),
                Expanded(child: Text(f.toString(),
                    style: const TextStyle(fontSize: 12, color: _ZC.text))),
              ]),
            )),
          ],
          if (result['recommendation'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _ZC.gold.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _ZC.gold.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text(result['recommendation'] ?? '',
                    style: const TextStyle(fontSize: 11, color: _ZC.gold))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _intelStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: _ZC.textDim,
          letterSpacing: 0.5)),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
          color: color)),
    ]);
  }
}