import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

const String _UAPI = 'https://web-production-d2935.up.railway.app';

// ── Star Painters ─────────────────────────────────────────
class _UpgradeStar {
  final double x, y, size, opacity, twinkle, speed;
  _UpgradeStar({required this.x, required this.y, required this.size,
      required this.opacity, required this.twinkle, required this.speed});
}

class _ZenithStarPainter extends CustomPainter {
  final double progress;
  final List<_UpgradeStar> stars;
  _ZenithStarPainter(this.progress, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final t = (math.sin((progress * s.speed + s.twinkle) * 2 * math.pi) + 1) / 2;
      final op = s.opacity * (0.2 + 0.8 * t);

      // Glow effect
      final glowPaint = Paint()
        ..color = Color.fromRGBO(150, 180, 255, op * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size * 2.5,
        glowPaint,
      );

      // Star core
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        Paint()..color = Color.fromRGBO(200, 220, 255, op),
      );
    }
  }

  @override
  bool shouldRepaint(_ZenithStarPainter old) => true;
}

// ── Colors ────────────────────────────────────────────────
class _UC {
  static const bg = Color(0xFF020818);
  static const surface = Color(0xFF060F24);
  static const border = Color(0xFF1A3A8F);
  static const primary = Color(0xFF2D5BE3);
  static const primaryLight = Color(0xFF6B9FFF);
  static const text = Color(0xFFD0DCFF);
  static const textDim = Color(0xFF3A5A9A);
  static const success = Color(0xFF2D8B4E);
  static const danger = Color(0xFFFF4444);
  static const warning = Color(0xFFF59E0B);
  static const apex = Color(0xFF6B9FFF);
  static const zenith = Color(0xFFFFD700);
}

// ── Upgrade Screen ────────────────────────────────────────
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen>
    with TickerProviderStateMixin {
  late AnimationController _starController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late List<_UpgradeStar> _stars;

  Map<String, dynamic> _planInfo = {};
  String _userId = 'default';
  bool _loading = true;
  bool _upgrading = false;
  int _selectedPlan = 0; // 0 = apex, 1 = zenith

  @override
  void initState() {
    super.initState();

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final rng = math.Random(42);
    _stars = List.generate(120, (_) => _UpgradeStar(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: rng.nextDouble() * 2.5 + 0.3,
      opacity: rng.nextDouble() * 0.8 + 0.2,
      twinkle: rng.nextDouble(),
      speed: rng.nextDouble() * 0.5 + 0.5,
    ));

    _loadPlanInfo();
  }

  @override
  void dispose() {
    _starController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPlanInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'default';
    setState(() => _userId = userId);

    try {
      final res = await http.get(
        Uri.parse('$_UAPI/chat/plan/$userId'),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _planInfo = data['plan'] ?? {};
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _upgrade(String plan) async {
    setState(() => _upgrading = true);
    try {
      final res = await http.post(
        Uri.parse('$_UAPI/chat/plan/upgrade'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId, 'plan': plan}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          await _loadPlanInfo();
          if (mounted) {
            _showSuccess(plan);
          }
        }
      }
    } catch (e) {
      _showError('Gagal upgrade. Coba lagi!');
    } finally {
      setState(() => _upgrading = false);
    }
  }

  void _showSuccess(String plan) {
    final label = plan == 'zenith' ? '👑 Zenith' : '⚡ Apex';
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _UC.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: plan == 'zenith' ? _UC.zenith : _UC.apex,
              width: 1,
            ),
            boxShadow: [BoxShadow(
              color: (plan == 'zenith' ? _UC.zenith : _UC.apex).withOpacity(0.3),
              blurRadius: 30,
            )],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(plan == 'zenith' ? '👑' : '⚡',
                  style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Selamat!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: plan == 'zenith' ? _UC.zenith : _UC.apex)),
              const SizedBox(height: 8),
              Text('Kamu sekarang menggunakan $label',
                  style: const TextStyle(fontSize: 14, color: _UC.text),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () { Navigator.pop(ctx); Navigator.pop(context); },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: plan == 'zenith'
                          ? [const Color(0xFF8B6914), _UC.zenith]
                          : [const Color(0xFF1A3A8F), _UC.primary],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Gas Pakai Sekarang! 🚀',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _UC.danger.withOpacity(0.9),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _UC.bg,
      body: Stack(
        children: [
          // ✅ Bintang penuh layar — Zenith vibes
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _ZenithStarPainter(_starController.value, _stars),
              size: Size.infinite,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(
                          color: _UC.primaryLight, strokeWidth: 1.5))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            children: [
                              _buildTrialBanner(),
                              const SizedBox(height: 16),
                              _buildPlanSelector(),
                              const SizedBox(height: 16),
                              _selectedPlan == 0
                                  ? _buildApexCard()
                                  : _buildZenithCard(),
                              const SizedBox(height: 16),
                              _buildCompareTable(),
                              const SizedBox(height: 24),
                              _buildCTAButton(),
                              const SizedBox(height: 12),
                              _buildFreeNote(),
                            ],
                          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _UC.surface.withOpacity(0.8),
        border: Border(bottom: BorderSide(
            color: _UC.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _UC.bg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _UC.border.withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: _UC.primaryLight, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [_UC.apex, _UC.zenith],
            ).createShader(b),
            child: const Text('Upgrade Plan',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 16, color: Colors.white)),
          ),
          const Spacer(),
          // Current plan badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _UC.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _UC.primary.withOpacity(0.3)),
            ),
            child: Text(
              _getCurrentPlanLabel(),
              style: const TextStyle(fontSize: 10, color: _UC.primaryLight,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentPlanLabel() {
    final plan = _planInfo['plan'] ?? 'free';
    final isTrialActive = _planInfo['is_trial'] == true;
    if (isTrialActive) return '✨ Trial Aktif';
    switch (plan) {
      case 'apex': return '⚡ Apex';
      case 'zenith': return '👑 Zenith';
      default: return '🆓 Free';
    }
  }

  Widget _buildTrialBanner() {
    final isTrialActive = _planInfo['is_trial'] == true;
    final trialDaysLeft = _planInfo['trial_days_left'] ?? 0;

    if (!isTrialActive) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _UC.zenith.withOpacity(0.1),
            _UC.apex.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UC.zenith.withOpacity(0.4), width: 1),
        boxShadow: [BoxShadow(
            color: _UC.zenith.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: const Text('✨', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trial Aktif!',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: _UC.zenith)),
                Text(
                  'Kamu menikmati semua fitur gratis. $trialDaysLeft hari lagi sebelum berakhir.',
                  style: const TextStyle(fontSize: 11, color: _UC.text, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _UC.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UC.border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: _planTab(0, '⚡ Apex', 'Rp 120rb/bln', _UC.apex)),
          Expanded(child: _planTab(1, '👑 Zenith', 'Rp 135rb/bln', _UC.zenith)),
        ],
      ),
    );
  }

  Widget _planTab(int index, String label, String price, Color color) {
    final active = _selectedPlan == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: color.withOpacity(0.5)) : null,
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: active ? color : _UC.textDim)),
            Text(price, style: TextStyle(
                fontSize: 10,
                color: active ? color.withOpacity(0.7) : _UC.textDim)),
          ],
        ),
      ),
    );
  }

  Widget _buildApexCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _UC.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _UC.apex.withOpacity(0.4), width: 1),
        boxShadow: [BoxShadow(
            color: _UC.apex.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _UC.apex.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _UC.apex.withOpacity(0.3)),
              ),
              child: const Text('⚡', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Apex',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: _UC.apex)),
              const Text('Untuk bisnis yang serius',
                  style: TextStyle(fontSize: 11, color: _UC.textDim)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Rp 120.000',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: _UC.text)),
              const Text('/bulan',
                  style: TextStyle(fontSize: 10, color: _UC.textDim)),
            ]),
          ]),
          const SizedBox(height: 20),
          ..._apexFeatures.map((f) => _featureItem(f, _UC.apex)),
        ],
      ),
    );
  }

  Widget _buildZenithCard() {
    return AnimatedBuilder(
      animation: _starController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0A1A),
              const Color(0xFF050510),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _UC.zenith.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(color: _UC.zenith.withOpacity(0.2), blurRadius: 30),
            BoxShadow(color: _UC.primary.withOpacity(0.1), blurRadius: 60),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Popular badge
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B6914), _UC.zenith],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('🔥 TERPOPULER',
                    style: TextStyle(fontSize: 9, color: Colors.white,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _UC.zenith.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _UC.zenith.withOpacity(0.4)),
                  boxShadow: [BoxShadow(
                      color: _UC.zenith.withOpacity(0.2), blurRadius: 10)],
                ),
                child: const Text('👑', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFF3A0), Color(0xFFFFD700)],
                  ).createShader(b),
                  child: const Text('Zenith',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const Text('Untuk perusahaan besar',
                    style: TextStyle(fontSize: 11, color: _UC.textDim)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFF3A0)],
                  ).createShader(b),
                  child: const Text('Rp 135.000',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const Text('/bulan',
                    style: TextStyle(fontSize: 10, color: _UC.textDim)),
              ]),
            ]),
            const SizedBox(height: 20),
            ..._zenithFeatures.map((f) => _featureItem(f, _UC.zenith)),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 0.5),
            ),
            child: Icon(Icons.check_rounded, color: color, size: 11),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: _UC.text, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _UC.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UC.border.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text('PERBANDINGAN PLAN',
              style: TextStyle(fontSize: 10, color: _UC.textDim,
                  letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _compareRow('Perintah/hari', '10', 'Unlimited', 'Unlimited'),
          _compareRow('Email auto-reply', '3/hari', '✅', '✅'),
          _compareRow('Invoice', '2/hari', '✅', '✅'),
          _compareRow('WA auto-reply', '20/hari', '✅', '✅'),
          _compareRow('Broadcast WA', '❌', '✅', '✅'),
          _compareRow('Quotation PDF', '❌', '✅', '✅'),
          _compareRow('Meeting transcriber', '❌', '5x/bln', 'Unlimited'),
          _compareRow('Personal Brain', '❌', '✅', '✅'),
          _compareRow('Sales AI closing', '❌', '✅', '✅'),
          _compareRow('Multi-user', '❌', '❌', '2 akun'),
          _compareRow('White label', '❌', '❌', '✅'),
          _compareRow('Priority support', '❌', '⚡', '👑 24/7'),
        ],
      ),
    );
  }

  Widget _compareRow(String feature, String free, String apex, String zenith) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
            color: _UC.border.withOpacity(0.1), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(feature,
                style: const TextStyle(fontSize: 11, color: _UC.textDim)),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(free,
                  style: TextStyle(fontSize: 10,
                      color: free == '❌' ? _UC.textDim : _UC.text),
                  textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(apex,
                  style: TextStyle(fontSize: 10,
                      color: apex == '❌' ? _UC.textDim : _UC.apex),
                  textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(zenith,
                  style: TextStyle(fontSize: 10,
                      color: zenith == '❌' ? _UC.textDim : _UC.zenith),
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    final plan = _selectedPlan == 0 ? 'apex' : 'zenith';
    final color = _selectedPlan == 0 ? _UC.apex : _UC.zenith;
    final label = _selectedPlan == 0 ? '⚡ Mulai Apex' : '👑 Mulai Zenith';
    final price = _selectedPlan == 0 ? 'Rp 120.000/bulan' : 'Rp 135.000/bulan';

    final currentPlan = _planInfo['plan'] ?? 'free';
    final isCurrentPlan = currentPlan == plan;

    return GestureDetector(
      onTap: isCurrentPlan || _upgrading ? null : () => _upgrade(plan),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Transform.scale(
          scale: isCurrentPlan ? 1.0 : _pulseAnim.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: isCurrentPlan
                  ? LinearGradient(colors: [
                      _UC.textDim.withOpacity(0.2),
                      _UC.textDim.withOpacity(0.1),
                    ])
                  : LinearGradient(
                      colors: _selectedPlan == 0
                          ? [const Color(0xFF1A3A8F), _UC.primary]
                          : [const Color(0xFF8B6914), _UC.zenith],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isCurrentPlan ? [] : [BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: _upgrading
                ? const Center(child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
                : Column(
                    children: [
                      Text(
                        isCurrentPlan ? '✅ Plan Aktif' : label,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      if (!isCurrentPlan)
                        Text(price,
                            style: TextStyle(color: Colors.white.withOpacity(0.7),
                                fontSize: 11)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreeNote() {
    return Column(
      children: [
        Text(
          '🔒 Pembayaran aman · Batalkan kapan saja',
          style: TextStyle(fontSize: 10, color: _UC.textDim.withOpacity(0.7)),
        ),
        const SizedBox(height: 4),
        Text(
          'Trial 3 hari gratis untuk semua user baru',
          style: TextStyle(fontSize: 10, color: _UC.success.withOpacity(0.8)),
        ),
      ],
    );
  }

  // ── Feature Lists ──────────────────────────────────────
  static const _apexFeatures = [
    'Unlimited perintah per hari',
    'Email auto-reply unlimited',
    'Invoice & payment unlimited',
    'WA auto-reply 24/7 unlimited',
    'Broadcast ke 500 kontak',
    'Quotation PDF otomatis',
    'Meeting transcriber 5x/bulan',
    'Personal Brain & follow up',
    'Sales AI closing otomatis',
    'Payment reminder otomatis',
  ];

  static const _zenithFeatures = [
    'Semua fitur Apex',
    'Unlimited segalanya tanpa batas',
    'Broadcast unlimited kontak',
    'Meeting transcriber unlimited',
    'Sales AI closing premium',
    'Multi-user (2 akun bisnis)',
    'White label (hapus watermark)',
    'CRM mini — pipeline sales (soon)',
    'Laporan keuangan advanced (soon)',
    'Priority support 24/7',
  ];
}