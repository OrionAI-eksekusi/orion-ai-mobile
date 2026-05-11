import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

const String _TAPI = 'https://web-production-d2935.up.railway.app';

class _MiniStar2 {
  final double x, y, size, opacity, twinkle;
  _MiniStar2({required this.x, required this.y, required this.size,
      required this.opacity, required this.twinkle});
}

class _StarPainter2 extends CustomPainter {
  final double progress;
  final List<_MiniStar2> stars;
  _StarPainter2(this.progress, this.stars);
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
  bool shouldRepaint(_StarPainter2 old) => true;
}

// ── Colors ────────────────────────────────────────────────
class _TC {
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

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _tasks = [];
  List<dynamic> _calendarEvents = [];
  bool _loading = true;
  String _error = '';
  String _summary = '';
  String _filter = 'all'; // all, active, done
  late AnimationController _starController;
  late List<_MiniStar2> _stars;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    final rng = math.Random(55);
    _stars = List.generate(50, (_) => _MiniStar2(
      x: rng.nextDouble(), y: rng.nextDouble(),
      size: rng.nextDouble() * 1.5 + 0.3,
      opacity: rng.nextDouble() * 0.5 + 0.1,
      twinkle: rng.nextDouble(),
    ));
    _loadTasks();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.get(Uri.parse('$_TAPI/chat/tasks'))
          .timeout(const Duration(seconds: 30));
      final calRes = await http.get(Uri.parse('$_TAPI/chat/calendar-events'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['tasks'];
        setState(() {
          _tasks = List.from(data['tasks'] ?? []);
          _summary = data['summary'] ?? '';
          _loading = false;
        });
      } else {
        setState(() { _error = 'Server error: ${res.statusCode}'; _loading = false; });
      }
      if (calRes.statusCode == 200) {
        setState(() {
          _calendarEvents = List.from(jsonDecode(calRes.body)['events'] ?? []);
        });
      }
    } catch (e) {
      setState(() { _error = 'Gagal memuat: $e'; _loading = false; });
    }
  }

  void _toggleDone(int index) => setState(() {
    _tasks[index]['done'] = !(_tasks[index]['done'] ?? false);
  });

  List<dynamic> get _activeTasks => _tasks.where((t) => !(t['done'] ?? false)).toList();
  List<dynamic> get _doneTasks => _tasks.where((t) => t['done'] ?? false).toList();
  List<dynamic> get _filteredTasks {
    if (_filter == 'active') return _activeTasks;
    if (_filter == 'done') return _doneTasks;
    return _tasks;
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'high': return _TC.danger;
      case 'medium': return _TC.warning;
      default: return _TC.success;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'meeting': return Icons.groups_rounded;
      case 'deadline': return Icons.timer_rounded;
      case 'file': return Icons.insert_drive_file_rounded;
      case 'payment': return Icons.payments_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }

  String _formatTime(String? dt) {
    if (dt == null || dt.isEmpty) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      final day = days[d.weekday - 1];
      final hour = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month) return 'Hari ini, $hour:$min';
      if (d.day == now.day + 1 && d.month == now.month) return 'Besok, $hour:$min';
      return '$day, $hour:$min';
    } catch (_) { return dt; }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeTasks.length;
    final doneCount = _doneTasks.length;
    final totalCount = _tasks.length;
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;

    return SafeArea(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _StarPainter2(_starController.value, _stars),
              size: Size.infinite,
            ),
          ),
          Column(
            children: [
              _buildHeader(activeCount),
              if (!_loading && _error.isEmpty) _buildStatsBar(activeCount, doneCount, totalCount, progress),
              if (!_loading && _error.isEmpty) _buildFilterTabs(),
              Expanded(child: _buildBody()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int activeCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _TC.surface.withOpacity(0.9),
        border: Border(bottom: BorderSide(
            color: _TC.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _TC.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _TC.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.task_alt_rounded, color: _TC.primaryLight, size: 18),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [_TC.primaryLight, Color(0xFFE0EAFF)],
            ).createShader(b),
            child: const Text('Tasks',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 16, color: Colors.white)),
          ),
          const Spacer(),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _TC.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _TC.danger.withOpacity(0.3)),
              ),
              child: Text('$activeCount aktif',
                  style: const TextStyle(fontSize: 9, color: _TC.danger,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadTasks,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _TC.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _TC.primary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _TC.primaryLight, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int active, int done, int total, double progress) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _TC.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _TC.border.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HARI INI',
                        style: TextStyle(fontSize: 9, color: _TC.textDim,
                            letterSpacing: 1, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$active',
                            style: const TextStyle(fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _TC.text, height: 1)),
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('tugas aktif',
                              style: TextStyle(fontSize: 12, color: _TC.textDim)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('SELESAI MINGGU INI',
                      style: TextStyle(fontSize: 9, color: _TC.textDim,
                          letterSpacing: 0.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$done',
                          style: const TextStyle(fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _TC.primaryLight),
                        ),
                        TextSpan(
                          text: ' / $total',
                          style: const TextStyle(fontSize: 14,
                              color: _TC.textDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _TC.border.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(
                progress >= 0.8 ? _TC.success : _TC.primary,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          _filterTab('all', 'Semua'),
          const SizedBox(width: 8),
          _filterTab('active', 'Aktif'),
          const SizedBox(width: 8),
          _filterTab('done', 'Selesai'),
        ],
      ),
    );
  }

  Widget _filterTab(String value, String label) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _TC.primary.withOpacity(0.2) : _TC.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _TC.primary : _TC.border.withOpacity(0.3),
            width: active ? 1 : 0.5,
          ),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12,
            color: active ? _TC.primaryLight : _TC.textDim,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _TC.primaryLight, strokeWidth: 1.5),
          SizedBox(height: 12),
          Text('Orion AI mencari task...',
              style: TextStyle(color: _TC.textDim, fontSize: 12)),
        ],
      ));
    }

    if (_error.isNotEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: _TC.danger, size: 40),
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: _TC.danger, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadTasks,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _TC.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _TC.primary.withOpacity(0.3)),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: _TC.primaryLight, fontSize: 13)),
            ),
          ),
        ],
      ));
    }

    final filtered = _filteredTasks;

    if (filtered.isEmpty && _calendarEvents.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _TC.success.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _TC.success.withOpacity(0.3)),
            ),
            child: const Icon(Icons.task_alt_rounded, color: _TC.success, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Tidak ada task ditemukan',
              style: TextStyle(color: _TC.text, fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Inbox kamu bersih! 🎉',
              style: TextStyle(color: _TC.textDim, fontSize: 12)),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: _TC.primaryLight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        children: [
          // Calendar events (hanya tampil di filter 'all')
          if (_filter == 'all' && _calendarEvents.isNotEmpty) ...[
            _sectionLabel('📅 JADWAL KALENDER', _TC.success),
            const SizedBox(height: 8),
            ..._calendarEvents.map((e) => _calendarCard(e)),
            const SizedBox(height: 12),
          ],

          // Tasks
          if (filtered.isNotEmpty) ...[
            if (_filter == 'all') ...[
              // Split active dan done
              if (_activeTasks.isNotEmpty) ...[
                _sectionLabel('📋 PERLU DIKERJAKAN', _TC.primaryLight),
                const SizedBox(height: 8),
                ..._activeTasks.map((t) => _taskCard(t, _tasks.indexOf(t))),
                const SizedBox(height: 12),
              ],
              if (_doneTasks.isNotEmpty) ...[
                _sectionLabel('✅ SELESAI', _TC.success),
                const SizedBox(height: 8),
                ..._doneTasks.map((t) => _taskCard(t, _tasks.indexOf(t))),
              ],
            ] else
              ...filtered.map((t) => _taskCard(t, _tasks.indexOf(t))),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            fontSize: 10, color: color,
            letterSpacing: 1.2, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _calendarCard(dynamic event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _TC.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _TC.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _TC.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _TC.success.withOpacity(0.3)),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: _TC.success, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event['title']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: _TC.text)),
                if (event['start'] != null)
                  Row(children: [
                    const Icon(Icons.schedule_rounded,
                        color: _TC.success, size: 11),
                    const SizedBox(width: 4),
                    Text(_formatTime(event['start']),
                        style: const TextStyle(fontSize: 11, color: _TC.success)),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(dynamic task, int index) {
    final isDone = task['done'] ?? false;
    final priority = task['priority'] ?? 'low';
    final type = task['type'] ?? 'followup';
    final color = isDone ? _TC.success : _priorityColor(priority);
    final timeStr = _formatTime(task['due']);
    final source = task['from']?.toString() ?? '';

    // Deteksi source type
    String sourceType = 'Email';
    if (source.toLowerCase().contains('wa') ||
        source.toLowerCase().contains('whatsapp') ||
        source.startsWith('+62') || source.startsWith('62')) {
      sourceType = 'WhatsApp';
    }

    return GestureDetector(
      onTap: () => _toggleDone(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _TC.surface.withOpacity(isDone ? 0.4 : 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(isDone ? 0.1 : 0.25), width: 0.8),
        ),
        child: Row(
          children: [
            // Priority bar kiri
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: isDone ? _TC.success.withOpacity(0.3) : color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // Checkbox
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: isDone ? _TC.success.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? _TC.success : color.withOpacity(0.5),
                    width: isDone ? 0 : 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, color: _TC.success, size: 14)
                    : null,
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: _TC.textDim,
                        color: isDone ? _TC.textDim : _TC.text,
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.schedule_rounded,
                            color: isDone ? _TC.textDim : color, size: 11),
                        const SizedBox(width: 4),
                        Text(timeStr,
                            style: TextStyle(fontSize: 11,
                                color: isDone ? _TC.textDim : color)),
                      ]),
                    ],
                    if (source.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(
                          sourceType == 'WhatsApp'
                              ? Icons.chat_rounded
                              : Icons.email_rounded,
                          color: _TC.textDim, size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text('$sourceType · $source',
                            style: const TextStyle(fontSize: 10, color: _TC.textDim),
                            overflow: TextOverflow.ellipsis),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            // Priority indicator
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone ? Colors.transparent : color.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}