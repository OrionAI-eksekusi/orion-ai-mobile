import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';

const String _API = 'https://web-production-d2935.up.railway.app';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'profile',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/drive.readonly',
  ],
);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String _error = '';
  late AnimationController _starController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late List<_StarData> _stars;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    final rng = math.Random(42);
    _stars = List.generate(70, (_) => _StarData(
      x: rng.nextDouble(), y: rng.nextDouble(),
      size: rng.nextDouble() * 1.8 + 0.3,
      opacity: rng.nextDouble() * 0.7 + 0.2,
      twinkle: rng.nextDouble(),
    ));
  }

  @override
  void dispose() {
    _starController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final account = await _googleSignIn.signIn();
      if (account != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final userId = account.email.split('@')[0].toUpperCase();
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', account.displayName ?? '');
        await prefs.setString('user_email', account.email);

        // Ambil OAuth token Gmail user — ini yang buat multi-user bisa baca email masing-masing
        final auth = await account.authentication;
        final accessToken = auth.accessToken ?? '';
        final idToken = auth.idToken ?? '';

        debugPrint('[OAUTH] accessToken: ${accessToken.isNotEmpty ? "OK" : "EMPTY"}');
        debugPrint('[OAUTH] idToken: ${idToken.isNotEmpty ? "OK" : "EMPTY"}');

        // Kirim profil + token Gmail ke backend
        await _saveUserProfile(
          userId: userId,
          name: account.displayName ?? account.email,
          email: account.email,
          accessToken: accessToken,
          idToken: idToken,
        );

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      setState(() => _error = 'Gagal login: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserProfile({
    required String userId,
    required String name,
    required String email,
    String accessToken = '',
    String idToken = '',
  }) async {
    try {
      await http.post(
        Uri.parse('$_API/chat/save-user-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'email': email,
          'phone': '',
          'city': 'Jakarta',
          'briefing_hour': 6,
          'gmail_access_token': accessToken,
          'gmail_id_token': idToken,
        }),
      );
      debugPrint('[SAVE PROFILE] Berhasil untuk $userId');
    } catch (e) {
      debugPrint('[SAVE PROFILE ERROR] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF020818),
      body: Stack(
        children: [
          // ── Background bumi ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/bumi.jpg',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.35),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          // ── Gradient atas ──
          Positioned(
            top: 0, left: 0, right: 0,
            height: h * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF020818), Color(0x00020818)],
                ),
              ),
            ),
          ),

          // ── Gradient bawah ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: h * 0.6,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF020818), Color(0xAA020818), Color(0x00020818)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Bintang ──
          AnimatedBuilder(
            animation: _starController,
            builder: (_, __) => CustomPaint(
              painter: _StarPainter(_starController.value, _stars),
              size: Size.infinite,
            ),
          ),

          // ── Konten ──
          FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    SizedBox(height: h * 0.08),

                    // Logo
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1428).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF2D5BE3).withOpacity(0.7),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2D5BE3).withOpacity(0.4),
                            blurRadius: 30, spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CustomPaint(painter: _OrionLogoPainter()),
                    ),

                    const SizedBox(height: 20),

                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFF6B9FFF), Color(0xFFFFFFFF), Color(0xFF6B9FFF)],
                        stops: [0.0, 0.5, 1.0],
                      ).createShader(b),
                      child: const Text('ORION AI',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 8, height: 1)),
                    ),
                    const SizedBox(height: 6),
                    const Text('AI EXECUTION SYSTEM',
                        style: TextStyle(fontSize: 11, color: Color(0xFF4A6AAA),
                            letterSpacing: 5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1A3F).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xFF2D5BE3).withOpacity(0.4), width: 0.8),
                      ),
                      child: const Text(
                        'Orion handles everything. You focus on growth.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF8BB8FF),
                            fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Asisten AI yang bekerja otomatis 24/7\nuntuk komunikasi, tugas, dan eksekusi perintah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF3A5A8A),
                          height: 1.6, fontWeight: FontWeight.w400),
                    ),

                    const SizedBox(height: 32),

                    _featureCard(Icons.email_outlined, 'Balas Email Otomatis',
                        'AI baca & balas email bisnis kamu'),
                    const SizedBox(height: 10),
                    _featureCard(Icons.chat_outlined, 'WhatsApp 24/7',
                        'AI kelola pesan WA Business kamu'),
                    const SizedBox(height: 10),
                    _featureCard(Icons.task_alt_outlined, 'Task Extractor',
                        'Deteksi meeting & deadline otomatis'),
                    const SizedBox(height: 10),
                    _featureCard(Icons.auto_awesome_outlined, 'Smart Briefing',
                        'Laporan harian yang actionable'),

                    const SizedBox(height: 36),

                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error,
                            style: const TextStyle(color: Color(0xFFFF6666), fontSize: 12),
                            textAlign: TextAlign.center),
                      ),

                    // Login button
                    GestureDetector(
                      onTap: _isLoading ? null : _signInWithGoogle,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3), Color(0xFF1A3A8F)],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF2D5BE3).withOpacity(0.5),
                            blurRadius: 24, offset: const Offset(0, 8),
                          )],
                          border: Border.all(
                              color: const Color(0xFF6B9FFF).withOpacity(0.3), width: 0.5),
                        ),
                        child: _isLoading
                            ? const Center(child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.g_mobiledata, color: Colors.white, size: 26),
                                  SizedBox(width: 8),
                                  Text('Mulai Sekarang',
                                      style: TextStyle(color: Colors.white, fontSize: 16,
                                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      'Dengan masuk, kamu mengizinkan Orion AI\nmengakses Gmail untuk membaca & membalas email.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF2A3A5A), height: 1.6),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF060F24).withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF1A3A8F).withOpacity(0.5), width: 0.8),
        boxShadow: [BoxShadow(
            color: const Color(0xFF2D5BE3).withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3A8F), Color(0xFF0A1A3F)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.4)),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF2D5BE3).withOpacity(0.2), blurRadius: 8)],
            ),
            child: Icon(icon, color: const Color(0xFF6B9FFF), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: Color(0xFFE0EAFF))),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12,
                    color: Color(0xFF4A6AAA), fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF2D5BE3), size: 18),
        ],
      ),
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

class _OrionLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFF2D5BE3).withOpacity(0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final stars = [
      Offset(cx, cy),
      Offset(cx * 0.35, cy * 0.55),
      Offset(cx * 1.65, cy * 0.55),
      Offset(cx * 0.45, cy * 1.5),
      Offset(cx * 1.55, cy * 1.5),
      Offset(cx, cy * 0.28),
    ];

    for (var l in [[0,1],[0,2],[0,3],[0,4],[1,5],[0,5]]) {
      canvas.drawLine(stars[l[0]], stars[l[1]], linePaint);
    }

    final sizes = [5.0, 2.5, 2.0, 1.8, 2.8, 1.5];
    final colors = [
      const Color(0xFF6B9FFF),
      const Color(0xFF4A7FEE),
      const Color(0xFF4A7FEE),
      const Color(0xFF8BAAFF),
      const Color(0xFF5577FF),
      const Color(0xFF99AAFF),
    ];

    for (int i = 0; i < stars.length; i++) {
      starPaint.color = colors[i].withOpacity(0.3);
      canvas.drawCircle(stars[i], sizes[i] * 2, starPaint);
      starPaint.color = colors[i];
      canvas.drawCircle(stars[i], sizes[i], starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}