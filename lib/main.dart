import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'onboarding.dart';
import 'briefing.dart';
import 'tasks.dart';
import 'wa_setup.dart';
import 'meeting.dart';
import 'payment.dart';
import 'upgrade.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const OrionApp());
}

const String API = 'https://web-production-d2935.up.railway.app';
const String GATEWAY = 'https://worker-production-67d8.up.railway.app';

class OrionColors {
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

class OrionController {
  static final OrionController _instance = OrionController._internal();
  factory OrionController() => _instance;
  OrionController._internal();
  String pendingCommand = '';
  VoidCallback? onCommandReceived;
  void sendCommand(String command) {
    pendingCommand = command;
    onCommandReceived?.call();
  }
}

class OrionStats {
  static final OrionStats _instance = OrionStats._internal();
  factory OrionStats() => _instance;
  OrionStats._internal();
  int executions = 47;
  int executionsDelta = 12;
  int emails = 128;
  int emailsDelta = 24;
  int waMessages = 312;
  int waMessagesDelta = 86;
  void incrementExecution() { executions++; executionsDelta++; }
}

class OrionApp extends StatelessWidget {
  const OrionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orion AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: OrionColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: OrionColors.primary,
          surface: OrionColors.surface,
        ),
      ),
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/wa-setup': (context) => const WaSetupScreen(),
        '/wa-reconnect': (context) => const WaSetupScreen(isReconnect: true),
        '/home': (context) => const HomeScreen(),
        '/meeting': (context) => const MeetingScreen(),
        '/upgrade': (context) => const UpgradeScreen(),
      },
    );
  }
}

// ── Star Field ────────────────────────────────────────────
class StarField extends StatefulWidget {
  final int starCount;
  const StarField({super.key, this.starCount = 60});

  @override
  State<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static final List<_StarData> _stars = [];
  static bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    if (!_initialized) {
      final random = math.Random(99);
      for (int i = 0; i < 60; i++) {
        _stars.add(_StarData(
          x: random.nextDouble(), y: random.nextDouble(),
          size: random.nextDouble() * 1.8 + 0.3,
          opacity: random.nextDouble() * 0.6 + 0.2,
          twinkle: random.nextDouble(),
        ));
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _StarPainter(_controller.value, _stars),
        size: Size.infinite,
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
      final op = s.opacity * (0.4 + 0.6 * t);
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

// ── Home Screen ───────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _waConnected = true;
  bool _showDisconnectBanner = false;
  Timer? _waCheckTimer;
  String _userName = '';
  String _userInitials = '';

  @override
  void initState() {
    super.initState();
    _startWaMonitoring();
    _initFCM();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'User';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';
    if (mounted) setState(() { _userName = name; _userInitials = initials; });
  }

  Future<void> _initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? 'default';
        await prefs.setString('fcm_token', token);
        _saveFcmToken(token, userId);
      }
      messaging.onTokenRefresh.listen((token) async {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? 'default';
        _saveFcmToken(token, userId);
      });
      FirebaseMessaging.onMessage.listen((msg) {
        if (msg.notification != null && mounted) {
          _showInAppNotification(
            msg.notification!.title ?? 'Orion AI',
            msg.notification!.body ?? '',
          );
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        final type = msg.data['type'];
        if (type == 'wa') setState(() => _selectedIndex = 4);
        else if (type == 'email') setState(() => _selectedIndex = 1);
        else if (type == 'task') setState(() => _selectedIndex = 2);
        else if (type == 'payment_reminder') setState(() => _selectedIndex = 3);
      });
    } catch (e) {
      debugPrint('[FCM INIT ERROR] $e');
    }
  }

  Future<void> _saveFcmToken(String token, String userId) async {
    try {
      await http.post(
        Uri.parse('$API/chat/save-fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'user_id': userId}),
      );
    } catch (_) {}
  }

  void _showInAppNotification(String title, String body) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: OrionColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: OrionColors.primary.withOpacity(0.5)),
        ),
        content: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  OrionColors.primary.withOpacity(0.3),
                  OrionColors.border.withOpacity(0.3),
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_rounded,
                  color: OrionColors.primaryLight, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: OrionColors.text)),
                  Text(body, style: const TextStyle(
                      fontSize: 11, color: OrionColors.textDim)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _startWaMonitoring() {
    _waCheckTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _checkWaStatus());
    _checkWaStatus();
  }

  Future<void> _checkWaStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('wa_connected') ?? false)) return;
      final res = await http.get(Uri.parse('$GATEWAY/status'))
          .timeout(const Duration(seconds: 10));
      final connected = jsonDecode(res.body)['connected'] == true;
      if (!connected && _waConnected) {
        await prefs.setBool('wa_connected', false);
        if (mounted) setState(() {
          _waConnected = false;
          _showDisconnectBanner = true;
        });
      } else if (connected && !_waConnected) {
        await prefs.setBool('wa_connected', true);
        if (mounted) setState(() {
          _waConnected = true;
          _showDisconnectBanner = false;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _waCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrionColors.bg,
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          const StarField(),
          Column(
            children: [
              if (_showDisconnectBanner)
                GestureDetector(
                  onTap: () {
                    setState(() => _showDisconnectBanner = false);
                    Navigator.pushNamed(context, '/wa-reconnect');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: OrionColors.danger.withOpacity(0.1),
                      border: Border(bottom: BorderSide(
                          color: OrionColors.danger.withOpacity(0.3))),
                    ),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6,
                            decoration: const BoxDecoration(
                                color: OrionColors.danger,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text(
                                'WhatsApp terputus — Tap untuk reconnect',
                                style: TextStyle(
                                    color: Color(0xFFFF6666), fontSize: 12))),
                        const Icon(Icons.chevron_right,
                            color: OrionColors.danger, size: 16),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    CommandScreen(
                      onReady: () => setState(() => _selectedIndex = 0),
                      onStatsUpdate: () => setState(() {}),
                    ),
                    BriefingScreen(onSendCommand: (cmd) {
                      setState(() => _selectedIndex = 0);
                      OrionController().sendCommand(cmd);
                    }),
                    const TasksScreen(),
                    const PaymentScreen(),
                    const InboxScreen(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: OrionColors.surface.withOpacity(0.95),
          border: Border(top: BorderSide(
              color: OrionColors.border.withOpacity(0.3), width: 0.5)),
          boxShadow: [BoxShadow(
              color: OrionColors.primary.withOpacity(0.05), blurRadius: 20)],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: OrionColors.primaryLight,
          unselectedItemColor: OrionColors.textDim,
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
              fontSize: 9, letterSpacing: 0.3, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 9),
          onTap: (i) => setState(() => _selectedIndex = i),
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.bolt, size: 20), label: 'Command'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.email_rounded, size: 20), label: 'Email'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.task_alt, size: 20), label: 'Tasks'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_rounded, size: 20),
                label: 'Payment'),
            BottomNavigationBarItem(
              icon: Stack(children: [
                const Icon(Icons.chat_rounded, size: 20),
                if (!_waConnected)
                  Positioned(right: 0, top: 0,
                      child: Container(width: 6, height: 6,
                          decoration: const BoxDecoration(
                              color: OrionColors.danger,
                              shape: BoxShape.circle))),
              ]),
              label: 'WhatsApp',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: OrionColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(
                    color: OrionColors.border.withOpacity(0.2), width: 0.5)),
              ),
              child: Row(
                children: [
                  const OrionLogo(size: 40),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [OrionColors.primaryLight, Color(0xFFE0EAFF)],
                        ).createShader(b),
                        child: const Text('Orion AI',
                            style: TextStyle(fontWeight: FontWeight.w700,
                                fontSize: 18, color: Colors.white)),
                      ),
                      const Text('AI Execution System',
                          style: TextStyle(fontSize: 11,
                              color: OrionColors.textDim)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: OrionColors.border.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close,
                          color: OrionColors.textDim, size: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(children: [
                Text('FITUR', style: TextStyle(fontSize: 9,
                    color: OrionColors.textDim,
                    letterSpacing: 2, fontWeight: FontWeight.w600)),
              ]),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(context, Icons.email_outlined,
                      'Email Otomatis', 'Baca & balas email bisnis',
                      () { Navigator.pop(context); setState(() => _selectedIndex = 1); }),
                  _drawerItem(context, Icons.chat_rounded,
                      'WhatsApp 24/7', 'Auto reply pesan WA',
                      () { Navigator.pop(context); setState(() => _selectedIndex = 4); }),
                  _drawerItem(context, Icons.task_alt_outlined,
                      'Task Extractor', 'Deteksi tugas & deadline',
                      () { Navigator.pop(context); setState(() => _selectedIndex = 2); }),
                  _drawerItem(context, Icons.auto_awesome,
                      'Smart Briefing', 'Laporan harian otomatis',
                      () { Navigator.pop(context); setState(() => _selectedIndex = 1); }),
                  _drawerItem(context, Icons.campaign_outlined,
                      'Broadcast WA', 'Kirim ke semua customer',
                      () {
                        Navigator.pop(context);
                        setState(() => _selectedIndex = 0);
                        Future.delayed(const Duration(milliseconds: 400), () {
                          OrionController().sendCommand('broadcast pesan ke semua customer');
                        });
                      }),
                  _drawerItem(context, Icons.folder_outlined,
                      'Kirim File Drive', 'Forward file via email',
                      () {
                        Navigator.pop(context);
                        setState(() => _selectedIndex = 0);
                        Future.delayed(const Duration(milliseconds: 400), () {
                          OrionController().sendCommand('kirimkan file dari Google Drive');
                        });
                      }),
                  _drawerItem(context, Icons.picture_as_pdf_outlined,
                      'Auto Quotation', 'Generate PDF penawaran',
                      () {
                        Navigator.pop(context);
                        setState(() => _selectedIndex = 0);
                        Future.delayed(const Duration(milliseconds: 400), () {
                          OrionController().sendCommand('buatkan quotation untuk customer');
                        });
                      }),
                  _drawerItem(context, Icons.mic_rounded,
                      'Meeting Transcriber', 'Notulen otomatis dari audio',
                      () { Navigator.pop(context); Navigator.pushNamed(context, '/meeting'); },
                      color: const Color(0xFFFF6666)),
                  _drawerItem(context, Icons.receipt_long_outlined,
                      'Payment Reminder', 'Nagih customer otomatis',
                      () { Navigator.pop(context); setState(() => _selectedIndex = 3); },
                      color: const Color(0xFF2D8B4E)),
                ],
              ),
            ),

            // User profile + upgrade footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(
                    color: OrionColors.border.withOpacity(0.2), width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A3A8F), OrionColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _userInitials.isNotEmpty ? _userInitials : 'U',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty ? _userName : 'User',
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: OrionColors.text),
                        ),
                        const Text('Premium · 12 hari lagi',
                            style: TextStyle(
                                fontSize: 10, color: OrionColors.textDim)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/upgrade');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A3A8F), OrionColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: OrionColors.primary.withOpacity(0.3),
                            blurRadius: 8)],
                      ),
                      child: const Text('Upgrade',
                          style: TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title,
      String sub, VoidCallback onTap, {Color? color}) {
    final c = color ?? OrionColors.primaryLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.withOpacity(0.2)),
              ),
              child: Icon(icon, color: c, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: OrionColors.text)),
                  Text(sub, style: const TextStyle(
                      fontSize: 10, color: OrionColors.textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: OrionColors.textDim.withOpacity(0.3), size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Orion Logo ────────────────────────────────────────────
class OrionLogo extends StatelessWidget {
  final double size;
  const OrionLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1428),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
            color: OrionColors.primary.withOpacity(0.5), width: 0.8),
        boxShadow: [BoxShadow(
            color: OrionColors.primary.withOpacity(0.2), blurRadius: 10)],
      ),
      child: CustomPaint(painter: OrionConstellationPainter()),
    );
  }
}

class OrionConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = OrionColors.primary.withOpacity(0.5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final stars = [
      Offset(cx, cy), Offset(cx * 0.35, cy * 0.6),
      Offset(cx * 1.65, cy * 0.6), Offset(cx * 0.5, cy * 1.5),
      Offset(cx * 1.5, cy * 1.5), Offset(cx, cy * 0.35),
    ];
    for (var l in [[0,1],[0,2],[0,3],[0,4],[1,5]]) {
      canvas.drawLine(stars[l[0]], stars[l[1]], linePaint);
    }
    final sizes = [3.5, 1.8, 1.5, 1.2, 2.0, 1.0];
    final colors = [
      OrionColors.primaryLight, const Color(0xFF4A7FEE),
      const Color(0xFF4A7FEE), const Color(0xFF8899FF),
      const Color(0xFF5577FF), const Color(0xFF99AAFF),
    ];
    for (int i = 0; i < stars.length; i++) {
      starPaint.color = colors[i].withOpacity(0.3);
      canvas.drawCircle(stars[i], sizes[i] * 1.8, starPaint);
      starPaint.color = colors[i];
      canvas.drawCircle(stars[i], sizes[i], starPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Command Screen ────────────────────────────────────────
class CommandScreen extends StatefulWidget {
  final VoidCallback? onReady;
  final VoidCallback? onStatsUpdate;
  const CommandScreen({super.key, this.onReady, this.onStatsUpdate});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _lastInputWasVoice = false;
  String _userId = 'default';

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _initSpeech();
    _initTts();
    OrionController().onCommandReceived = () {
      final cmd = OrionController().pendingCommand;
      if (cmd.isNotEmpty) {
        OrionController().pendingCommand = '';
        Future.delayed(const Duration(milliseconds: 300),
            () => _sendMessage(cmd));
      }
    };
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getString('user_id') ?? 'default');
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted)
          setState(() => _isListening = false);
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (r) {
        setState(() => _controller.text = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.isNotEmpty) {
          _lastInputWasVoice = true;
          _sendMessage(r.recognizedWords);
          setState(() => _isListening = false);
        }
      },
      localeId: 'id_ID',
      listenMode: stt.ListenMode.confirmation,
    );
  }

  Future<void> _speakReply(String text) async {
    final clean = text
        .replaceAll(RegExp(r'\{.*?\}', dotAll: true), '')
        .replaceAll(RegExp(r'[{}\[\]":]'), '')
        .trim();
    if (clean.isNotEmpty) await _tts.speak(clean);
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    OrionController().onCommandReceived = null;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _needsConfirmation(Map<String, dynamic>? parsed) {
    if (parsed == null) return false;
    final intent = (parsed['intent'] ?? '').toString().toLowerCase();
    final actionIntents = [
      'email', 'gmail', 'balas_email', 'send_email',
      'broadcast', 'send_file', 'quotation', 'kirim'
    ];
    return actionIntents.any((a) => intent.contains(a)) &&
        parsed['draft'] != null &&
        parsed['draft'].toString().isNotEmpty;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'type': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();
    OrionStats().incrementExecution();
    widget.onStatsUpdate?.call();

    try {
      final response = await http.post(
        Uri.parse('$API/chat/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text, 'user_id': _userId}),
      );
      final data = jsonDecode(response.body);
      final parsed = data['parsed'] as Map<String, dynamic>?;

      // Cek limit reached
      if (data['status'] == 'limit_reached') {
        setState(() {
          _messages.add({'type': 'ai', 'text': data['response'] ?? 'Limit harian tercapai.'});
          _isLoading = false;
        });
        return;
      }

      if (_needsConfirmation(parsed)) {
        setState(() {
          _messages.add({'type': 'action', 'data': data});
          _isLoading = false;
        });
      } else {
        String replyText = '';
        if (parsed != null) {
          replyText = parsed['reply'] ?? parsed['draft'] ??
              parsed['summary'] ?? parsed['action'] ?? '';
        }
        if (replyText.isEmpty) {
          replyText = data['response'] ?? 'Maaf, saya tidak mengerti.';
        }
        if (replyText.startsWith('{')) {
          try {
            final parsed2 = jsonDecode(replyText);
            replyText = parsed2['reply'] ?? parsed2['draft'] ??
                parsed2['summary'] ?? parsed2['action'] ?? replyText;
          } catch (_) {}
        }
        setState(() {
          _messages.add({'type': 'ai', 'text': replyText});
          _isLoading = false;
        });
        if (_lastInputWasVoice && replyText.isNotEmpty) {
          _speakReply(replyText);
        }
      }
      _lastInputWasVoice = false;
    } catch (e) {
      setState(() {
        _messages.add({'type': 'ai',
          'text': 'Gagal terhubung ke server. Coba lagi ya!'});
        _isLoading = false;
      });
      _lastInputWasVoice = false;
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length)
                        return const _TypingIndicator();
                      final msg = _messages[i];
                      if (msg['type'] == 'user')
                        return _UserBubble(text: msg['text']);
                      if (msg['type'] == 'action')
                        return _ActionCard(
                            data: msg['data'], onSend: _sendMessage);
                      return _AiBubble(text: msg['text'] ?? '');
                    },
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: OrionColors.surface.withOpacity(0.9),
        border: Border(bottom: BorderSide(
            color: OrionColors.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: OrionColors.bg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: OrionColors.border.withOpacity(0.3), width: 0.8),
                ),
                child: const Icon(Icons.menu_rounded,
                    color: OrionColors.primaryLight, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const OrionLogo(size: 34),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [OrionColors.primaryLight, Color(0xFFE0EAFF)],
                ).createShader(b),
                child: const Text('Orion AI',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 15, color: Colors.white,
                        letterSpacing: 0.5)),
              ),
              const Text('AI EXECUTION SYSTEM',
                  style: TextStyle(fontSize: 8,
                      color: OrionColors.textDim, letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          _isListening
              ? _statusBadge('Mendengarkan...', OrionColors.danger)
              : _statusBadge('Online', OrionColors.success),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: OrionColors.surface.withOpacity(0.9),
        border: Border(top: BorderSide(
            color: OrionColors.border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _isListening
                    ? OrionColors.danger.withOpacity(0.15)
                    : OrionColors.bg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isListening
                      ? OrionColors.danger
                      : OrionColors.border.withOpacity(0.4),
                  width: _isListening ? 1.5 : 0.8,
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening
                    ? OrionColors.danger : OrionColors.primaryLight,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 13, color: OrionColors.text),
              decoration: InputDecoration(
                hintText: _isListening
                    ? 'Mendengarkan...'
                    : 'Ketik perintah untuk Orion...',
                hintStyle: TextStyle(
                  color: _isListening
                      ? OrionColors.danger.withOpacity(0.7)
                      : OrionColors.textDim,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: OrionColors.bg.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _isListening
                        ? OrionColors.danger.withOpacity(0.5)
                        : OrionColors.border.withOpacity(0.3),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: OrionColors.primary, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A8F), OrionColors.primary]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: OrionColors.primary.withOpacity(0.3),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10, color: color,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    final stats = OrionStats();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 28),
          const OrionLogo(size: 68),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF6B9FFF), Color(0xFFE0EAFF), Color(0xFF6B9FFF)],
              stops: [0.0, 0.5, 1.0],
            ).createShader(b),
            child: const Text('ORION AI',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 6)),
          ),
          const SizedBox(height: 4),
          const Text('AI EXECUTION SYSTEM',
              style: TextStyle(fontSize: 9, color: OrionColors.textDim,
                  letterSpacing: 4, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text(
            'Asisten AI yang benar-benar mengeksekusi\nbukan hanya menjawab',
            textAlign: TextAlign.center,
            style: TextStyle(color: OrionColors.textDim,
                fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _statCard('EKSEKUSI\nHARI INI',
                  '${stats.executions}', '+${stats.executionsDelta}',
                  OrionColors.primaryLight)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('EMAIL\nDIPROSES',
                  '${stats.emails}', '+${stats.emailsDelta}',
                  const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(child: _statCard('PESAN WA',
                  '${stats.waMessages}', '+${stats.waMessagesDelta}',
                  const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: OrionColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 8),
              const Text('COBA KATAKAN ATAU KETIK...',
                  style: TextStyle(fontSize: 10,
                      color: OrionColors.textDim, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 10),
          _chip('Balas email terbaru dari klien'),
          const SizedBox(height: 8),
          _chip('Broadcast promo ke semua customer'),
          const SizedBox(height: 8),
          _chip('Kirimkan pitch deck ke investor@email.com'),
          const SizedBox(height: 8),
          _chip('Buatkan quotation untuk customer baru'),
          const SizedBox(height: 8),
          _chip('Buat notulen dari rekaman meeting ini'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 20, height: 0.5,
                  color: OrionColors.border.withOpacity(0.3)),
              const SizedBox(width: 10),
              const Icon(Icons.menu_rounded,
                  color: OrionColors.textDim, size: 12),
              const SizedBox(width: 6),
              const Text('Tap ☰ untuk lihat semua fitur',
                  style: TextStyle(fontSize: 10, color: OrionColors.textDim)),
              const SizedBox(width: 10),
              Container(width: 20, height: 0.5,
                  color: OrionColors.border.withOpacity(0.3)),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String delta, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: OrionColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 0.8),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 8,
                  color: color.withOpacity(0.7),
                  letterSpacing: 0.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color, height: 1)),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(delta,
                    style: TextStyle(fontSize: 10,
                        color: color.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OrionColors.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: OrionColors.border.withOpacity(0.25), width: 0.8),
        ),
        child: Row(
          children: [
            Container(width: 5, height: 5,
                decoration: BoxDecoration(
                  color: OrionColors.primaryLight.withOpacity(0.5),
                  shape: BoxShape.circle,
                )),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13,
                      color: OrionColors.text,
                      fontWeight: FontWeight.w400)),
            ),
            const Icon(Icons.north_west_rounded,
                color: OrionColors.textDim, size: 13),
          ],
        ),
      ),
    );
  }
}

// ── Inbox Screen ──────────────────────────────────────────
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<dynamic> _waMessages = [];
  bool _loading = true;
  bool _waConnected = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkWaStatus();
  }

  Future<void> _checkWaStatus() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$GATEWAY/status'));
      final connected = jsonDecode(res.body)['connected'] == true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wa_connected', connected);
      setState(() => _waConnected = connected);
      if (connected) _loadInbox();
      else setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Gagal cek status WA';
      });
    }
  }

  Future<void> _loadInbox() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await http.get(Uri.parse('$API/chat/whatsapp-messages'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        setState(() {
          _waMessages = List.from(jsonDecode(res.body)['messages'] ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Server error: ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Gagal memuat: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: OrionColors.surface.withOpacity(0.9),
              border: Border(bottom: BorderSide(
                  color: OrionColors.border.withOpacity(0.3), width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: OrionColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: OrionColors.success.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: Color(0xFF4CAF50), size: 18),
                ),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  ).createShader(b),
                  child: const Text('WhatsApp Business',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 15, color: Colors.white)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (_waConnected
                        ? OrionColors.success
                        : OrionColors.danger).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: (_waConnected
                            ? OrionColors.success
                            : OrionColors.danger).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5,
                          decoration: BoxDecoration(
                              color: _waConnected
                                  ? OrionColors.success
                                  : OrionColors.danger,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(_waConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(fontSize: 10,
                              color: _waConnected
                                  ? OrionColors.success
                                  : OrionColors.danger,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _checkWaStatus,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: OrionColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: OrionColors.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: OrionColors.primaryLight, size: 15),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: OrionColors.primaryLight, strokeWidth: 1.5))
                : !_waConnected
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: OrionColors.danger.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: OrionColors.danger.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.wifi_off_rounded,
                                  color: OrionColors.danger, size: 34),
                            ),
                            const SizedBox(height: 16),
                            const Text('WhatsApp Business terputus',
                                style: TextStyle(color: OrionColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            const Text(
                                'Scan QR untuk menghubungkan kembali',
                                style: TextStyle(
                                    color: OrionColors.textDim,
                                    fontSize: 12)),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/wa-reconnect'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: OrionColors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: OrionColors.danger.withOpacity(0.5),
                                      width: 0.8),
                                ),
                                child: const Text('Reconnect WhatsApp',
                                    style: TextStyle(
                                        color: OrionColors.danger,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _error.isNotEmpty
                        ? Center(child: Text(_error,
                            style: const TextStyle(
                                color: OrionColors.danger, fontSize: 12)))
                        : RefreshIndicator(
                            onRefresh: _loadInbox,
                            color: OrionColors.primaryLight,
                            child: _waMessages.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chat_rounded,
                                            color: OrionColors.textDim,
                                            size: 48),
                                        SizedBox(height: 12),
                                        Text('Belum ada pesan masuk',
                                            style: TextStyle(
                                                color: OrionColors.textDim,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _waMessages.length,
                                    itemBuilder: (context, i) =>
                                        _WaItem(message: _waMessages[i]),
                                  ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Chat Bubbles ──────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A3A8F), OrionColors.primary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [BoxShadow(
                    color: OrionColors.primary.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Text(text, style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final String text;
  const _AiBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: OrionLogo(size: 28),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Orion AI',
                    style: TextStyle(fontSize: 10,
                        color: OrionColors.primaryLight,
                        fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: OrionColors.surface.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                        color: OrionColors.border.withOpacity(0.3),
                        width: 0.5),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8)],
                  ),
                  child: Text(text, style: const TextStyle(
                      fontSize: 14, color: OrionColors.text, height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Card ───────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String) onSend;
  const _ActionCard({required this.data, required this.onSend});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  String _status = 'menunggu';
  late TextEditingController _draftController;
  late Map<String, dynamic> _parsed;

  @override
  void initState() {
    super.initState();
    _parsed = widget.data['parsed'] ?? {};
    _draftController =
        TextEditingController(text: _parsed['draft'] ?? '');
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _status = 'memproses');
    try {
      final replyTo = _parsed['reply_to'] ?? '';
      final subject = _parsed['subject'] ?? 'Re: ';
      final body = _draftController.text;
      if (replyTo.isNotEmpty && replyTo.contains('@')) {
        await http.post(
          Uri.parse('$API/chat/send-email'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
              {'to': replyTo, 'subject': subject, 'body': body}),
        );
      }
      setState(() => _status = 'terkirim');
    } catch (e) {
      setState(() => _status = 'gagal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final intent = _parsed['intent'] ?? 'aksi';
    final summary = _parsed['summary'] ?? _parsed['action'] ?? '';
    final replyTo = _parsed['reply_to'] ?? '';
    final subject = _parsed['subject'] ?? '';
    final isEmail =
        intent.contains('email') || intent.contains('gmail');
    final accentColor =
        isEmail ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: OrionLogo(size: 28),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Orion AI',
                    style: TextStyle(fontSize: 10,
                        color: OrionColors.primaryLight,
                        fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: OrionColors.surface.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                        color: OrionColors.border.withOpacity(0.3),
                        width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.05),
                          border: Border(bottom: BorderSide(
                              color: OrionColors.border.withOpacity(0.2),
                              width: 0.5)),
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(18)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: accentColor.withOpacity(0.3)),
                              ),
                              child: Icon(
                                  isEmail
                                      ? Icons.email_outlined
                                      : Icons.chat_outlined,
                                  color: accentColor, size: 15),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Konfirmasi ${isEmail ? "Email" : "Pesan"}',
                                      style: const TextStyle(fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: OrionColors.text)),
                                  Text(intent.toUpperCase(),
                                      style: const TextStyle(fontSize: 9,
                                          color: OrionColors.textDim,
                                          letterSpacing: 1)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: OrionColors.bg.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_status,
                                  style: TextStyle(fontSize: 9,
                                      color: _status == 'terkirim'
                                          ? OrionColors.success
                                          : _status == 'gagal'
                                              ? OrionColors.danger
                                              : OrionColors.textDim)),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (summary.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(summary,
                                    style: const TextStyle(fontSize: 12,
                                        color: OrionColors.textDim,
                                        height: 1.4)),
                              ),
                            if (_parsed['draft'] != null) ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: OrionColors.bg.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: OrionColors.border
                                          .withOpacity(0.2)),
                                ),
                                child: Column(
                                  children: [
                                    if (replyTo.isNotEmpty)
                                      _emailRow('Kepada', replyTo),
                                    if (subject.isNotEmpty)
                                      _emailRow('Subjek', subject),
                                    TextField(
                                      controller: _draftController,
                                      maxLines: 4,
                                      style: const TextStyle(fontSize: 13,
                                          color: OrionColors.text,
                                          height: 1.5),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (_status == 'menunggu')
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _confirm,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 11),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                              colors: [Color(0xFF1A3A8F),
                                                OrionColors.primary]),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [BoxShadow(
                                              color: OrionColors.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3))],
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.send_rounded,
                                                color: Colors.white,
                                                size: 13),
                                            SizedBox(width: 6),
                                            Text('Kirim Sekarang',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _status = 'dibatalkan'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color:
                                            OrionColors.bg.withOpacity(0.5),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: OrionColors.border
                                                .withOpacity(0.3)),
                                      ),
                                      child: const Text('Batal',
                                          style: TextStyle(fontSize: 13,
                                              color: OrionColors.textDim)),
                                    ),
                                  ),
                                ],
                              ),
                            if (_status == 'terkirim')
                              Row(children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: OrionColors.success, size: 16),
                                const SizedBox(width: 6),
                                const Text('Berhasil dikirim! ✅',
                                    style: TextStyle(
                                        color: OrionColors.success,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            if (_status == 'gagal')
                              Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: OrionColors.danger, size: 16),
                                const SizedBox(width: 6),
                                const Text('Gagal mengirim',
                                    style: TextStyle(
                                        color: OrionColors.danger,
                                        fontSize: 13)),
                              ]),
                            if (_status == 'dibatalkan')
                              const Text('Aksi dibatalkan',
                                  style: TextStyle(
                                      color: OrionColors.textDim,
                                      fontSize: 13)),
                          ],
                        ),
                      ),
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

  Widget _emailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: OrionColors.border.withOpacity(0.2), width: 0.5))),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11,
              color: OrionColors.textDim, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(
              fontSize: 11, color: OrionColors.text))),
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: OrionLogo(size: 28),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Orion AI',
                  style: TextStyle(fontSize: 10,
                      color: OrionColors.primaryLight,
                      fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: OrionColors.surface.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                      color: OrionColors.border.withOpacity(0.3),
                      width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: OrionColors.primaryLight.withOpacity(0.7)),
                    ),
                    const SizedBox(width: 10),
                    const Text('Orion sedang berpikir...',
                        style: TextStyle(fontSize: 12,
                            color: OrionColors.textDim)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── WA Item ───────────────────────────────────────────────
class _WaItem extends StatelessWidget {
  final dynamic message;
  const _WaItem({required this.message});

  @override
  Widget build(BuildContext context) {
    final phone = message['phone']?.toString() ?? '';
    final initials = phone.isNotEmpty ? phone[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OrionColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: OrionColors.border.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF2D8B4E).withOpacity(0.3),
                const Color(0xFF4CAF50).withOpacity(0.1),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(color: Color(0xFF4CAF50),
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
                    child: Text(phone,
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: OrionColors.text)),
                  ),
                  Text(message['time']?.toString() ?? '',
                      style: TextStyle(fontSize: 9,
                          color: OrionColors.textDim.withOpacity(0.5))),
                ]),
                const SizedBox(height: 3),
                Text(message['message']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11,
                        color: OrionColors.textDim),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: OrionColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('AI Dibalas Orion',
                      style: TextStyle(fontSize: 9,
                          color: OrionColors.success,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}