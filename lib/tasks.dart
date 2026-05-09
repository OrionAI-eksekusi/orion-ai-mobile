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

  Color _priorityColor(String p) {
    switch (p) {
      case 'high': return const Color(0xFFFF4444);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF2D8B4E);
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'meeting': return Icons.groups;
      case 'deadline': return Icons.timer;
      case 'file': return Icons.insert_drive_file;
      case 'payment': return Icons.payments;
      default: return Icons.check_circle_outline;
    }
  }

  String _formatTime(String? dt) {
    if (dt == null || dt.isEmpty) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return dt; }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => !(t['done'] ?? false)).toList();
    final done = _tasks.where((t) => t['done'] ?? false).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF020818),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _StarPainter2(_starController.value, _stars),
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
                          gradient: LinearGradient(colors: [
                            const Color(0xFF1A3A8F).withOpacity(0.5),
                            const Color(0xFF2D5BE3).withOpacity(0.2),
                          ]),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.task_alt, color: Color(0xFF6B9FFF), size: 16),
                      ),
                      const SizedBox(width: 10),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFF6B9FFF), Color(0xFFE0EAFF)],
                        ).createShader(b),
                        child: const Text('Task Extractor',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                      ),
                      const Spacer(),
                      // Stats badge
                      if (!_loading && _tasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D5BE3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.3)),
                          ),
                          child: Text('${pending.length} pending',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF6B9FFF))),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _loadTasks,
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
                              const Text('Orion AI mencari task...',
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
                                      border: Border.all(
                                          color: const Color(0xFFFF4444).withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.error_outline,
                                        color: Color(0xFFFF6666), size: 28),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(_error,
                                      style: const TextStyle(color: Color(0xFFFF6666), fontSize: 12),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: _loadTasks,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                            colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3)]),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('Coba Lagi',
                                          style: TextStyle(color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTasks,
                              color: const Color(0xFF6B9FFF),
                              child: ListView(
                                padding: const EdgeInsets.all(14),
                                children: [
                                  if (_summary.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A1A3F).withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: const Color(0xFF2D5BE3).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome,
                                              color: Color(0xFF6B9FFF), size: 14),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(_summary,
                                                style: const TextStyle(
                                                    fontSize: 12, color: Color(0xFF6B9FFF),
                                                    height: 1.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_calendarEvents.isNotEmpty) ...[
                                    _sectionHeader('📅 JADWAL KALENDER', const Color(0xFF2D8B4E)),
                                    const SizedBox(height: 8),
                                    ..._calendarEvents.map((e) => _calendarCard(e)),
                                    const SizedBox(height: 16),
                                  ],
                                  if (pending.isNotEmpty) ...[
                                    _sectionHeader('📋 PERLU DIKERJAKAN', const Color(0xFF6B9FFF)),
                                    const SizedBox(height: 8),
                                    ...pending.map((t) => _taskCard(t, _tasks.indexOf(t))),
                                    const SizedBox(height: 16),
                                  ],
                                  if (done.isNotEmpty) ...[
                                    _sectionHeader('✅ SELESAI', const Color(0xFF2D8B4E)),
                                    const SizedBox(height: 8),
                                    ...done.map((t) => _taskCard(t, _tasks.indexOf(t))),
                                  ],
                                  if (_tasks.isEmpty && _calendarEvents.isEmpty)
                                    Center(
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 40),
                                          Container(
                                            width: 70, height: 70,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2D8B4E).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: const Color(0xFF2D8B4E).withOpacity(0.3)),
                                            ),
                                            child: const Icon(Icons.task_alt,
                                                color: Color(0xFF2D8B4E), size: 32),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text('Tidak ada task ditemukan',
                                              style: TextStyle(color: Color(0xFF6B9FFF), fontSize: 13)),
                                          const SizedBox(height: 4),
                                          const Text('Inbox kamu bersih! 🎉',
                                              style: TextStyle(color: Color(0xFF3A5A9A), fontSize: 12)),
                                        ],
                                      ),
                                    ),
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

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
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
              fontSize: 11, color: color, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _calendarCard(dynamic event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF060F24).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D8B4E).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2D8B4E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2D8B4E).withOpacity(0.3)),
            ),
            child: const Icon(Icons.calendar_today, color: Color(0xFF2D8B4E), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event['title']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFFD0DCFF))),
                if (event['start'] != null)
                  Text(_formatTime(event['start']),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2D8B4E))),
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
    final color = isDone ? const Color(0xFF2D8B4E) : _priorityColor(priority);

    return GestureDetector(
      onTap: () => _toggleDone(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF060F24).withOpacity(isDone ? 0.4 : 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 0.8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(
                    isDone ? Icons.check_circle : _typeIcon(type),
                    color: color, size: 14,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? const Color(0xFF3A5A9A) : const Color(0xFFD0DCFF),
                        ),
                      ),
                      if (task['detail'] != null) ...[
                        const SizedBox(height: 3),
                        Text(task['detail']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B9FFF)),
                            overflow: TextOverflow.ellipsis, maxLines: 2),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (task['from'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3A8F).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.3)),
                              ),
                              child: Text(task['from']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B9FFF))),
                            ),
                          const SizedBox(width: 6),
                          if (task['due'] != null && task['due'].toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFFFF4444).withOpacity(0.3)),
                              ),
                              child: Text('⏰ ${task['due']}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFFFF6666))),
                            ),
                        ],
                      ),
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
}