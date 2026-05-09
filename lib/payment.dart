import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

const String _PAPI = 'https://web-production-d2935.up.railway.app';

// ── Star Painters ─────────────────────────────────────────
class _MiniStarP {
  final double x, y, size, opacity, twinkle;
  _MiniStarP({required this.x, required this.y, required this.size,
      required this.opacity, required this.twinkle});
}

class _StarPainterP extends CustomPainter {
  final double progress;
  final List<_MiniStarP> stars;
  _StarPainterP(this.progress, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final t = (math.sin((progress + s.twinkle) * 2 * math.pi) + 1) / 2;
      final op = s.opacity * (0.3 + 0.7 * t);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        Paint()..color = Color.fromRGBO(180, 210, 255, op),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainterP old) => true;
}

// ── Colors ────────────────────────────────────────────────
class _PC {
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
}

// ── Payment Screen ────────────────────────────────────────
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _invoices = [];
  bool _loading = true;
  String _error = '';
  String _userId = 'default';
  String _filter = 'all'; // all, unpaid, paid
  late AnimationController _starController;
  late List<_MiniStarP> _stars;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    final rng = math.Random(77);
    _stars = List.generate(50, (_) => _MiniStarP(
      x: rng.nextDouble(), y: rng.nextDouble(),
      size: rng.nextDouble() * 1.5 + 0.3,
      opacity: rng.nextDouble() * 0.5 + 0.15,
      twinkle: rng.nextDouble(),
    ));
    _loadUserAndInvoices();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getString('user_id') ?? 'default');
    await _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('$_PAPI/chat/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': 'daftar invoice',
          'user_id': _userId
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Parse invoice dari response
        await _loadInvoicesDirect();
      } else {
        setState(() { _error = 'Server error'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Gagal memuat: $e'; _loading = false; });
    }
  }

  Future<void> _loadInvoicesDirect() async {
    try {
      final res = await http.get(
        Uri.parse('$_PAPI/chat/invoices/$_userId'),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _invoices = List.from(data['invoices'] ?? []);
          _loading = false;
        });
      } else {
        // Fallback: parse dari chat response
        setState(() { _invoices = []; _loading = false; });
      }
    } catch (e) {
      setState(() { _invoices = []; _loading = false; });
    }
  }

  Future<void> _markPaid(String invoiceNumber) async {
    try:
      final res = await http.post(
        Uri.parse('$_PAPI/chat/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': '$invoiceNumber sudah lunas',
          'user_id': _userId
        }),
      );
      if (res.statusCode == 200) {
        _showSnack('✅ Invoice ditandai lunas!', _PC.success);
        _loadInvoicesDirect();
      }
    } catch (e) {
      _showSnack('❌ Gagal update invoice', _PC.danger);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      duration: const Duration(seconds: 2),
    ));
  }

  String _formatAmount(dynamic amount) {
    final num val = (amount is num) ? amount : double.tryParse('$amount') ?? 0;
    return 'Rp ${val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    )}';
  }

  List<dynamic> get _filteredInvoices {
    if (_filter == 'unpaid') return _invoices.where((i) => i['status'] == 'unpaid').toList();
    if (_filter == 'paid') return _invoices.where((i) => i['status'] == 'paid').toList();
    return _invoices;
  }

  int get _unpaidCount => _invoices.where((i) => i['status'] == 'unpaid').length;
  int get _paidCount => _invoices.where((i) => i['status'] == 'paid').length;
  double get _totalUnpaid => _invoices
      .where((i) => i['status'] == 'unpaid')
      .fold(0.0, (sum, i) => sum + (double.tryParse('${i['amount']}') ?? 0));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Star background
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _StarPainterP(_starController.value, _stars),
              size: Size.infinite,
            ),
          ),
          Column(
            children: [
              _buildHeader(),
              _buildSummaryCards(),
              _buildFilterTabs(),
              Expanded(child: _buildBody()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _PC.surface.withOpacity(0.9),
        border: Border(bottom: BorderSide(
            color: _PC.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _PC.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _PC.warning.withOpacity(0.3)),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Color(0xFFF59E0B), size: 18),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFFFD700)],
            ).createShader(b),
            child: const Text('Payment',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 16, color: Colors.white)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadInvoicesDirect,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _PC.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _PC.primary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _PC.primaryLight, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _summaryCard(
            icon: Icons.pending_actions_rounded,
            label: 'Belum Lunas',
            value: '$_unpaidCount invoice',
            sub: _formatAmount(_totalUnpaid),
            color: _PC.danger,
          )),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard(
            icon: Icons.check_circle_rounded,
            label: 'Sudah Lunas',
            value: '$_paidCount invoice',
            sub: 'Total ${_invoices.length} invoice',
            color: _PC.success,
          )),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PC.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
                fontSize: 11, color: color,
                fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(
              fontSize: 16, color: _PC.text,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(
              fontSize: 10, color: _PC.textDim)),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _filterTab('all', 'Semua'),
          const SizedBox(width: 8),
          _filterTab('unpaid', '⏳ Belum Lunas'),
          const SizedBox(width: 8),
          _filterTab('paid', '✅ Lunas'),
        ],
      ),
    );
  }

  Widget _filterTab(String value, String label) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _PC.primary.withOpacity(0.2) : _PC.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _PC.primary : _PC.border.withOpacity(0.3),
            width: active ? 1 : 0.5,
          ),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 11,
            color: active ? _PC.primaryLight : _PC.textDim,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: _PC.primaryLight, strokeWidth: 1.5));
    }

    if (_error.isNotEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: _PC.danger, size: 40),
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: _PC.danger, fontSize: 13)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadInvoicesDirect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _PC.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _PC.primary.withOpacity(0.3)),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: _PC.primaryLight, fontSize: 13)),
            ),
          ),
        ],
      ));
    }

    final filtered = _filteredInvoices;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _PC.warning.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _PC.warning.withOpacity(0.3)),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Color(0xFFF59E0B), size: 28),
            ),
            const SizedBox(height: 14),
            const Text('Belum ada invoice',
                style: TextStyle(color: _PC.text, fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Ketik "tagih [nama] [nominal]" di Command',
                style: TextStyle(color: _PC.textDim, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvoicesDirect,
      color: _PC.primaryLight,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _InvoiceCard(
          invoice: filtered[i],
          onMarkPaid: () => _markPaid(filtered[i]['invoice_number'] ?? ''),
          formatAmount: _formatAmount,
        ),
      ),
    );
  }
}

// ── Invoice Card ──────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final dynamic invoice;
  final VoidCallback onMarkPaid;
  final String Function(dynamic) formatAmount;

  const _InvoiceCard({
    required this.invoice,
    required this.onMarkPaid,
    required this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice['status'] == 'paid';
    final color = isPaid ? _PC.success : _PC.danger;
    final reminderCount = invoice['reminder_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _PC.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.05), blurRadius: 10)],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Status bar kiri
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice['customer_name'] ?? 'Customer',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: _PC.text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                invoice['invoice_number'] ?? '',
                                style: const TextStyle(
                                    fontSize: 10, color: _PC.textDim),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: color.withOpacity(0.3), width: 0.5),
                          ),
                          child: Text(
                            isPaid ? '✅ Lunas' : '⏳ Belum',
                            style: TextStyle(
                                fontSize: 10, color: color,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Amount & due date
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nominal',
                                  style: TextStyle(
                                      fontSize: 9, color: _PC.textDim)),
                              Text(
                                formatAmount(invoice['amount']),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _PC.primaryLight),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Jatuh Tempo',
                                style: TextStyle(
                                    fontSize: 9, color: _PC.textDim)),
                            Text(
                              invoice['due_date'] ?? '-',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isPaid ? _PC.textDim : _PC.danger),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Phone & reminder info
                    if (invoice['customer_phone'] != null &&
                        invoice['customer_phone'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.phone_rounded,
                            color: _PC.textDim, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          invoice['customer_phone'],
                          style: const TextStyle(
                              fontSize: 10, color: _PC.textDim),
                        ),
                        if (!isPaid) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _PC.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Reminder: $reminderCount/3',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFF59E0B)),
                            ),
                          ),
                        ],
                      ]),
                    ],

                    // Action button kalau belum lunas
                    if (!isPaid) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onMarkPaid,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1A5C30), _PC.success],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(
                                    color: _PC.success.withOpacity(0.3),
                                    blurRadius: 6)],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded,
                                      color: Colors.white, size: 13),
                                  SizedBox(width: 5),
                                  Text('Tandai Lunas',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}