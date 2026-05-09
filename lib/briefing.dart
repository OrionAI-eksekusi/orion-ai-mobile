import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

const String _API = 'https://web-production-d2935.up.railway.app';

// ── Star Field (reusable) ─────────────────────────────────
class _MiniStar {
  final double x, y, size, opacity, twinkle;
  _MiniStar({required this.x, required this.y, required this.size,
      required this.opacity, required this.twinkle});
}

class _StarPainter extends CustomPainter {
  final double progress;
  final List<_MiniStar> stars;
  _StarPainter(this.progress, this.stars);
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
  bool shouldRepaint(_StarPainter old) => true;
}

class BriefingScreen extends StatefulWidget {
  final Function(String)? onSendCommand;
  const BriefingScreen({super.key, this.onSendCommand});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _briefing;
  bool _loading = true;
  String _error = '';
  late AnimationController _starController;
  late List<_MiniStar> _stars;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    final rng = math.Random(77);
    _stars = List.generate(50, (_) => _MiniStar(
      x: rng.nextDouble(), y: rng.nextDouble(),
      size: rng.nextDouble() * 1.5 + 0.3,
      opacity: rng.nextDouble() * 0.5 + 0.1,
      twinkle: rng.nextDouble(),
    ));
    _loadBriefing();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  Future<void> _loadBriefing() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.get(Uri.parse('$_API/chat/briefing'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        setState(() { _briefing = jsonDecode(res.body)['briefing']; _loading = false; });
      } else {
        setState(() { _error = 'Server error: ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Gagal memuat: $e'; _loading = false; });
    }
  }

  void _onTapItem(dynamic item, String type) {
    final from = item['from']?.toString() ?? '';
    final subject = item['subject']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF060F24),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF0A1A3F), const Color(0xFF060F24)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 3,
                decoration: BoxDecoration(color: const Color(0xFF1A3A8F).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF020818).withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: type == 'urgent'
                          ? const Color(0xFFFF4444).withOpacity(0.1)
                          : const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: type == 'urgent'
                            ? const Color(0xFFFF4444).withOpacity(0.3)
                            : const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      type == 'urgent' ? Icons.priority_high : Icons.schedule,
                      color: type == 'urgent' ? const Color(0xFFFF6666) : const Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(from, style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFD0DCFF))),
                        const SizedBox(height: 3),
                        Text(subject, style: const TextStyle(fontSize: 11, color: Color(0xFF6B9FFF)),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onSendCommand?.call('Balas email dari $from tentang "$subject"');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFF2D5BE3).withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.reply, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Balas Sekarang',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A8F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.3)),
                ),
                child: const Center(
                    child: Text('Tutup', style: TextStyle(color: Color(0xFF6B9FFF), fontSize: 13))),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020818),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _StarPainter(_starController.value, _stars),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060F24).withOpacity(0.9),
                    border: Border(bottom: BorderSide(
                        color: const Color(0xFF1A3A8F).withOpacity(0.3), width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF1A3A8F).withOpacity(0.5),
                              const Color(0xFF2D5BE3).withOpacity(0.2)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF6B9FFF), size: 16),
                      ),
                      const SizedBox(width: 10),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFF6B9FFF), Color(0xFFE0EAFF)],
                        ).createShader(b),
                        child: const Text('Smart Briefing',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _loadBriefing,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3A8F).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.refresh, color: Color(0xFF6B9FFF), size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A3A8F).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.3)),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF6B9FFF), strokeWidth: 1.5),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Menganalisa inbox...',
                                  style: TextStyle(color: Color(0xFF3A5A9A), fontSize: 12)),
                            ],
                          ),
                        )
                      : _error.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4444).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.error_outline, color: Color(0xFFFF6666), size: 28),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(_error,
                                      style: const TextStyle(color: Color(0xFFFF6666), fontSize: 12),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: _loadBriefing,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                            colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3)]),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('Coba Lagi',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadBriefing,
                              color: const Color(0xFF6B9FFF),
                              child: ListView(
                                padding: const EdgeInsets.all(14),
                                children: [
                                  if (_briefing?['summary'] != null)
                                    _summaryCard(_briefing!['summary']),
                                  if (_briefing?['urgent'] != null &&
                                      (_briefing!['urgent'] as List).isNotEmpty) ...[
                                    _sectionHeader('🔴 URGENT', const Color(0xFFFF4444)),
                                    const SizedBox(height: 8),
                                    ...(_briefing!['urgent'] as List)
                                        .map((e) => _emailCard(e, 'urgent')),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_briefing?['bisa_nanti'] != null &&
                                      (_briefing!['bisa_nanti'] as List).isNotEmpty) ...[
                                    _sectionHeader('🟡 BISA NANTI', const Color(0xFFF59E0B)),
                                    const SizedBox(height: 8),
                                    ...(_briefing!['bisa_nanti'] as List)
                                        .map((e) => _emailCard(e, 'nanti')),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_briefing?['arsip'] != null &&
                                      (_briefing!['arsip'] as List).isNotEmpty) ...[
                                    _sectionHeader('📦 ARSIP', const Color(0xFF3A5A9A)),
                                    const SizedBox(height: 8),
                                    ...(_briefing!['arsip'] as List)
                                        .map((e) => _arsipCard(e)),
                                    const SizedBox(height: 16),
                                  ],
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

  Widget _summaryCard(String summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A3F).withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.3)),
        boxShadow: [BoxShadow(
            color: const Color(0xFF2D5BE3).withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF6B9FFF), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(summary,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B9FFF), height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
            fontSize: 11, color: color, letterSpacing: 1.5,
            fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _emailCard(dynamic item, String type) {
    final isUrgent = type == 'urgent';
    final accentColor = isUrgent ? const Color(0xFFFF4444) : const Color(0xFFF59E0B);
    return GestureDetector(
      onTap: () => _onTapItem(item, type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF060F24).withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.2), width: 0.8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item['from']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD0DCFF))),
                          ),
                          Icon(Icons.chevron_right, color: accentColor.withOpacity(0.5), size: 16),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(item['subject']?.toString() ?? '',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B9FFF)),
                          overflow: TextOverflow.ellipsis),
                      if (item['preview'] != null) ...[
                        const SizedBox(height: 3),
                        Text(item['preview']?.toString() ?? '',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF3A5A9A)),
                            overflow: TextOverflow.ellipsis),
                      ],
                      if (item['action'] != null && isUrgent) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accentColor.withOpacity(0.3)),
                          ),
                          child: Text('→ ${item['action']}',
                              style: TextStyle(fontSize: 10, color: accentColor)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arsipCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF060F24).withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.archive_outlined, color: const Color(0xFF3A5A9A).withOpacity(0.5), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['from']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF3A5A9A))),
                Text(item['subject']?.toString() ?? '',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF2A3A5A)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}