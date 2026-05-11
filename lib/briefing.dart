import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

const String _BAPI = 'https://web-production-d2935.up.railway.app';

class _MiniStar {
  final double x, y, size, opacity, twinkle;
  _MiniStar({required this.x, required this.y, required this.size,
      required this.opacity, required this.twinkle});
}

class _StarPainterB extends CustomPainter {
  final double progress;
  final List<_MiniStar> stars;
  _StarPainterB(this.progress, this.stars);
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
  bool shouldRepaint(_StarPainterB old) => true;
}

// ── Colors ────────────────────────────────────────────────
class _BC {
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
    final rng = math.Random(42);
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
      final res = await http.get(Uri.parse('$_BAPI/chat/briefing'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        setState(() {
          _briefing = jsonDecode(res.body)['briefing'];
          _loading = false;
        });
      } else {
        setState(() { _error = 'Server error: ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Gagal memuat: $e'; _loading = false; });
    }
  }

  int get _totalEmails {
    if (_briefing == null) return 0;
    return (_briefing!['urgent'] as List? ?? []).length +
        (_briefing!['bisa_nanti'] as List? ?? []).length +
        (_briefing!['arsip'] as List? ?? []).length;
  }

  int get _repliedCount {
    if (_briefing == null) return 0;
    return (_briefing!['urgent'] as List? ?? []).length +
        (_briefing!['arsip'] as List? ?? []).length;
  }

  String _getLabel(String from) {
    final f = from.toLowerCase();
    if (f.contains('investor') || f.contains('vc') || f.contains('fund') ||
        f.contains('capital') || f.contains('sequoia')) return 'Investor';
    if (f.contains('vendor') || f.contains('supplier') || f.contains('hosting')) return 'Vendor';
    if (f.contains('finance') || f.contains('internal') || f.contains('orion')) return 'Internal';
    if (f.contains('lead') || f.contains('prospect')) return 'Lead';
    return 'Klien';
  }

  Color _getLabelColor(String label) {
    switch (label) {
      case 'Investor': return const Color(0xFF8B5CF6);
      case 'Vendor': return const Color(0xFFF59E0B);
      case 'Internal': return const Color(0xFF3A5A9A);
      case 'Lead': return const Color(0xFF10B981);
      default: return _BC.primary;
    }
  }

  void _onTapItem(dynamic item, String type) {
    final from = item['from']?.toString() ?? '';
    final subject = item['subject']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: _BC.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _BC.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _BC.border.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 3,
                decoration: BoxDecoration(color: _BC.border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Avatar + info
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    from.isNotEmpty ? from[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(from, style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: _BC.text)),
                  const SizedBox(height: 3),
                  Text(subject, style: const TextStyle(
                      fontSize: 11, color: _BC.primaryLight),
                      overflow: TextOverflow.ellipsis),
                ],
              )),
            ]),
            const SizedBox(height: 16),
            if (item['preview'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _BC.bg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _BC.border.withOpacity(0.2)),
                ),
                child: Text(item['preview']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: _BC.textDim, height: 1.5)),
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
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: _BC.primary.withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.reply, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Balas dengan Orion AI',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _BC.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _BC.border.withOpacity(0.3)),
                ),
                child: const Center(child: Text('Tutup',
                    style: TextStyle(color: _BC.primaryLight, fontSize: 13))),
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
    return SafeArea(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _StarPainterB(_starController.value, _stars),
              size: Size.infinite,
            ),
          ),
          Column(
            children: [
              _buildHeader(),
              if (!_loading && _error.isEmpty) _buildAutoReplyBanner(),
              if (!_loading && _error.isEmpty) _buildSearchBar(),
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
        color: _BC.surface.withOpacity(0.9),
        border: Border(bottom: BorderSide(
            color: _BC.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _BC.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _BC.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.email_rounded, color: _BC.primaryLight, size: 18),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [_BC.primaryLight, Color(0xFFE0EAFF)],
            ).createShader(b),
            child: const Text('Email',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 16, color: Colors.white)),
          ),
          if (!_loading && _briefing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _BC.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _BC.danger.withOpacity(0.3)),
              ),
              child: Text(
                '${(_briefing!['urgent'] as List? ?? []).length} BARU',
                style: const TextStyle(fontSize: 9, color: _BC.danger,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: _loadBriefing,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _BC.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _BC.primary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _BC.primaryLight, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoReplyBanner() {
    final total = _totalEmails;
    final replied = _repliedCount;
    final pct = total > 0 ? (replied / total * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _BC.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BC.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _BC.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _BC.success.withOpacity(0.3)),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Color(0xFF4CAF50), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Auto-reply aktif',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600, color: _BC.text)),
                Text('Orion menjawab $replied dari $total email hari ini',
                    style: const TextStyle(fontSize: 10, color: _BC.textDim)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? replied / total : 0,
                    backgroundColor: _BC.border.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(_BC.success),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('$pct%',
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w800, color: Color(0xFF4CAF50))),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _BC.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _BC.border.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, color: _BC.textDim, size: 16),
        const SizedBox(width: 8),
        const Text('Cari email atau pengirim...',
            style: TextStyle(fontSize: 13, color: _BC.textDim)),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _BC.primaryLight, strokeWidth: 1.5),
          SizedBox(height: 12),
          Text('Menganalisa inbox...',
              style: TextStyle(color: _BC.textDim, fontSize: 12)),
        ],
      ));
    }

    if (_error.isNotEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: _BC.danger, size: 40),
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: _BC.danger, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadBriefing,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _BC.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _BC.primary.withOpacity(0.3)),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: _BC.primaryLight, fontSize: 13)),
            ),
          ),
        ],
      ));
    }

    final urgent = _briefing?['urgent'] as List? ?? [];
    final nanti = _briefing?['bisa_nanti'] as List? ?? [];
    final arsip = _briefing?['arsip'] as List? ?? [];
    final totalNew = urgent.length;

    return RefreshIndicator(
      onRefresh: _loadBriefing,
      color: _BC.primaryLight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          if (totalNew > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('INBOX · $totalNew BARU',
                  style: const TextStyle(fontSize: 10, color: _BC.textDim,
                      letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ),
          ...urgent.map((e) => _emailCard(e, 'urgent')),
          if (nanti.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('BISA NANTI',
                  style: TextStyle(fontSize: 10, color: _BC.textDim,
                      letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ),
            ...nanti.map((e) => _emailCard(e, 'nanti')),
          ],
          if (arsip.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('ARSIP',
                  style: TextStyle(fontSize: 10, color: _BC.textDim,
                      letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ),
            ...arsip.map((e) => _arsipCard(e)),
          ],
        ],
      ),
    );
  }

  Widget _emailCard(dynamic item, String type) {
    final isUrgent = type == 'urgent';
    final from = item['from']?.toString() ?? '';
    final subject = item['subject']?.toString() ?? '';
    final preview = item['preview']?.toString() ?? '';
    final label = _getLabel(from);
    final labelColor = _getLabelColor(label);
    final accentColor = isUrgent ? _BC.danger : _BC.warning;
    final initials = from.isNotEmpty ? from[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _onTapItem(item, type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _BC.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.15), width: 0.8),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.3), accentColor.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(initials,
                    style: TextStyle(color: accentColor,
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(from,
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: _BC.text),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(isUrgent ? '12 mnt lalu' : '1 jam lalu',
                        style: const TextStyle(fontSize: 10, color: _BC.textDim)),
                  ]),
                  const SizedBox(height: 2),
                  Text(subject,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w500, color: _BC.text),
                      overflow: TextOverflow.ellipsis),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(preview,
                        style: const TextStyle(fontSize: 11, color: _BC.textDim),
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    _labelBadge(label, labelColor),
                    const SizedBox(width: 6),
                    if (type != 'nanti')
                      _labelBadge('✓ Dibalas Orion', _BC.success),
                    if (isUrgent) ...[
                      const SizedBox(width: 6),
                      _labelBadge('Urgent', _BC.danger),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: isUrgent ? _BC.danger : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _arsipCard(dynamic item) {
    final from = item['from']?.toString() ?? '';
    final subject = item['subject']?.toString() ?? '';
    final initials = from.isNotEmpty ? from[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _BC.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BC.border.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _BC.textDim.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(color: _BC.textDim,
                      fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(from,
                        style: const TextStyle(fontSize: 12,
                            color: _BC.textDim, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Text('6 jam lalu',
                      style: TextStyle(fontSize: 10, color: _BC.textDim)),
                ]),
                const SizedBox(height: 2),
                Text(subject,
                    style: const TextStyle(fontSize: 11, color: _BC.textDim),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _labelBadge('✓ Dibalas Orion', _BC.success),
              ],
            ),
          ),
        ],
      ),
    );
  }
}