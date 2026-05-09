import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const String _API = 'https://web-production-d2935.up.railway.app';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _titleController =
      TextEditingController(text: 'Meeting');
  final TextEditingController _emailsController = TextEditingController();

  bool _isProcessing = false;
  bool _hasFile = false;
  String _filePath = '';
  String _fileName = '';
  String _status = '';
  String _result = '';
  String _userId = 'default';

  late AnimationController _starController;
  late List<_StarData> _stars;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    final rng = math.Random(55);
    _stars = List.generate(40, (_) => _StarData(
      x: rng.nextDouble(), y: rng.nextDouble(),
      size: rng.nextDouble() * 1.5 + 0.3,
      opacity: rng.nextDouble() * 0.5 + 0.1,
      twinkle: rng.nextDouble(),
    ));
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getString('user_id') ?? 'default');
  }

  @override
  void dispose() {
    _starController.dispose();
    _titleController.dispose();
    _emailsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'mp4', 'm4a', 'wav', 'ogg', 'flac', 'aac'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _filePath = result.files.single.path!;
          _fileName = result.files.single.name;
          _hasFile = true;
          _status = '✅ File dipilih: $_fileName';
          _result = '';
        });
      }
    } catch (e) {
      setState(() => _status = '❌ Gagal pilih file: $e');
    }
  }

  Future<void> _uploadAndProcess() async {
    if (!_hasFile || _filePath.isEmpty) return;

    final file = File(_filePath);
    if (!await file.exists()) {
      setState(() => _status = '❌ File tidak ditemukan');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = '⏳ Mengunggah audio ke Orion AI...';
      _result = '';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_API/chat/transcribe-meeting'),
      );

      request.fields['meeting_title'] = _titleController.text;
      request.fields['participant_emails'] = _emailsController.text;
      request.fields['language'] = 'id';
      request.fields['user_id'] = _userId;

      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        _filePath,
        filename: _fileName,
      ));

      final response = await request.send()
          .timeout(const Duration(seconds: 120));
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);

      if (data['status'] == 'success') {
        setState(() {
          _isProcessing = false;
          _status = '✅ Audio berhasil diupload!';
          _result = '🎙️ Orion AI sedang mentranskrip meeting...\n\n'
              '📋 Notulen akan dikirim via notifikasi!\n\n'
              '📧 Dikirim ke:\n${_emailsController.text.isEmpty ? "Tidak ada email" : _emailsController.text}';
        });
      } else {
        setState(() {
          _isProcessing = false;
          _status = '❌ Gagal: ${data['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = '❌ Error: $e';
      });
    }
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
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3A8F).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              color: Color(0xFF6B9FFF), size: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B1A1A).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.mic_rounded, color: Color(0xFFFF6666), size: 18),
                      ),
                      const SizedBox(width: 10),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFFFF6666), Color(0xFFFFAAAA)],
                        ).createShader(b),
                        child: const Text('Meeting Transcriber',
                            style: TextStyle(fontWeight: FontWeight.w700,
                                fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Icon
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF8B1A1A).withOpacity(0.15),
                            border: Border.all(
                                color: const Color(0xFFFF4444).withOpacity(0.4), width: 2),
                            boxShadow: [BoxShadow(
                                color: const Color(0xFFFF4444).withOpacity(0.2),
                                blurRadius: 30, spreadRadius: 5)],
                          ),
                          child: const Icon(Icons.mic_rounded,
                              color: Color(0xFFFF6666), size: 52),
                        ),

                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Color(0xFFFF6666), Color(0xFFFFAAAA)],
                          ).createShader(b),
                          child: const Text('Meeting Transcriber',
                              style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload audio meeting → Orion AI buat notulen otomatis\ndan kirim ke semua peserta via email!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF3A5A9A), height: 1.5),
                        ),

                        const SizedBox(height: 28),

                        // Form
                        _inputField(
                          controller: _titleController,
                          label: 'Judul Meeting',
                          hint: 'Contoh: Rapat Bulanan Tim',
                          icon: Icons.title_rounded,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: _emailsController,
                          label: 'Email Peserta (pisah koma)',
                          hint: 'budi@email.com, rina@email.com',
                          icon: Icons.email_outlined,
                        ),

                        const SizedBox(height: 20),

                        // Pick File Button
                        GestureDetector(
                          onTap: _isProcessing ? null : _pickFile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF060F24).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _hasFile
                                    ? const Color(0xFF2D8B4E)
                                    : const Color(0xFF1A3A8F).withOpacity(0.5),
                                width: _hasFile ? 1.5 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _hasFile ? Icons.check_circle_rounded : Icons.audio_file_rounded,
                                  color: _hasFile ? const Color(0xFF2D8B4E) : const Color(0xFF6B9FFF),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _hasFile ? _fileName : 'Pilih File Audio',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _hasFile
                                          ? const Color(0xFF2D8B4E)
                                          : const Color(0xFF6B9FFF),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Upload Button
                        GestureDetector(
                          onTap: (_isProcessing || !_hasFile) ? null : _uploadAndProcess,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: _hasFile
                                  ? const LinearGradient(
                                      colors: [Color(0xFF6B1A1A), Color(0xFFCC3333)],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        const Color(0xFF1A1A2A).withOpacity(0.5),
                                        const Color(0xFF1A1A2A).withOpacity(0.5),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _hasFile ? [BoxShadow(
                                  color: const Color(0xFFFF4444).withOpacity(0.3),
                                  blurRadius: 20, offset: const Offset(0, 6))] : [],
                            ),
                            child: _isProcessing
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 18, height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2)),
                                      SizedBox(width: 10),
                                      Text('Memproses...',
                                          style: TextStyle(color: Colors.white,
                                              fontSize: 15, fontWeight: FontWeight.w600)),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded,
                                          color: _hasFile ? Colors.white : const Color(0xFF3A5A9A),
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text('Proses dengan Orion AI',
                                          style: TextStyle(
                                              color: _hasFile ? Colors.white : const Color(0xFF3A5A9A),
                                              fontSize: 15, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                          ),
                        ),

                        // Status
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF060F24).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF1A3A8F).withOpacity(0.3)),
                            ),
                            child: Text(_status,
                                style: const TextStyle(fontSize: 12,
                                    color: Color(0xFF6B9FFF), height: 1.5)),
                          ),
                        ],

                        // Result
                        if (_result.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1A0A).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF2D8B4E).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF2D8B4E), size: 16),
                                  SizedBox(width: 6),
                                  Text('Sedang Diproses!',
                                      style: TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2D8B4E))),
                                ]),
                                const SizedBox(height: 8),
                                Text(_result,
                                    style: const TextStyle(fontSize: 12,
                                        color: Color(0xFF6B9FFF), height: 1.6)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Tips
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1428).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF1A3A8F).withOpacity(0.2)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💡 Cara Pakai',
                                  style: TextStyle(fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B9FFF))),
                              SizedBox(height: 8),
                              Text(
                                '1. Record meeting pakai Voice Memo HP\n'
                                '2. Isi judul meeting & email peserta\n'
                                '3. Tap "Pilih File Audio"\n'
                                '4. Tap "Proses dengan Orion AI"\n'
                                '5. Notulen otomatis dikirim via email! 🎉',
                                style: TextStyle(fontSize: 11,
                                    color: Color(0xFF3A5A9A), height: 1.6),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
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

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B9FFF),
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: Color(0xFFD0DCFF)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF3A5A9A)),
            prefixIcon: Icon(icon, color: const Color(0xFF3A5A9A), size: 18),
            filled: true,
            fillColor: const Color(0xFF060F24).withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: const Color(0xFF1A3A8F).withOpacity(0.3), width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2D5BE3), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _StarData {
  final double x, y, size, opacity, twinkle;
  _StarData({required this.x, required this.y, required this.size,
      required this.opacity, required this.twinkle});
}

class _StarPainter extends CustomPainter {
  final double progress;
  final List<_StarData> stars;
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