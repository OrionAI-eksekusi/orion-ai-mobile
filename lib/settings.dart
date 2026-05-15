cat > ~/Documents/orion_ai_mobile/lib/settings.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const String _API = 'https://web-production-d2935.up.railway.app';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  int _briefingHour = 6;
  bool _loading = false;
  bool _saved = false;
  String _userId = 'default';
  String _plan = 'trial';
  int _trialDaysLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'default';
    setState(() {
      _nameCtrl.text = prefs.getString('user_name') ?? '';
      _emailCtrl.text = prefs.getString('user_email') ?? '';
    });

    try {
      final res = await http.get(
        Uri.parse('$_API/chat/user-profile/$_userId'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final profile = data['profile'] ?? {};
        final plan = data['plan'] ?? {};
        setState(() {
          _nameCtrl.text = profile['name'] ?? _nameCtrl.text;
          _emailCtrl.text = profile['email'] ?? _emailCtrl.text;
          _phoneCtrl.text = profile['phone'] ?? '';
          _cityCtrl.text = profile['city'] ?? '';
          _briefingHour = profile['briefing_hour'] ?? 6;
          _plan = plan['plan'] ?? 'trial';
          _trialDaysLeft = plan['trial_days_left'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    setState(() { _loading = true; _saved = false; });
    try {
      await http.post(
        Uri.parse('$_API/chat/save-user-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'name': _nameCtrl.text,
          'email': _emailCtrl.text,
          'phone': _phoneCtrl.text,
          'city': _cityCtrl.text,
          'briefing_hour': _briefingHour,
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameCtrl.text);
      setState(() { _saved = true; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }

  String _getPlanLabel() {
    if (_plan == 'trial') return '✨ Trial · $_trialDaysLeft hari lagi';
    if (_plan == 'apex') return '⚡ Apex · 100 perintah/hari';
    if (_plan == 'zenith') return '👑 Zenith · 200 perintah/hari';
    return '🆓 Free · 10 perintah/hari';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020818),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060F24),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B9FFF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pengaturan',
            style: TextStyle(color: Color(0xFFD0DCFF), fontSize: 16,
                fontWeight: FontWeight.w600)),
        actions: [
          if (_saved)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.check_circle, color: Color(0xFF2D8B4E), size: 20),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Plan info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF060F24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.5)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A8F).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Color(0xFF6B9FFF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'User',
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: Color(0xFFD0DCFF))),
                  Text(_getPlanLabel(),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF3A5A9A))),
                ],
              )),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/upgrade'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Upgrade',
                      style: TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Profile form
          _sectionTitle('👤 Profil Saya'),
          const SizedBox(height: 10),
          _inputField('Nama', _nameCtrl, Icons.person_outline),
          const SizedBox(height: 10),
          _inputField('Email', _emailCtrl, Icons.email_outlined),
          const SizedBox(height: 10),
          _inputField('No. HP', _phoneCtrl, Icons.phone_outlined),
          const SizedBox(height: 10),
          _inputField('Kota', _cityCtrl, Icons.location_on_outlined),
          const SizedBox(height: 20),

          // Briefing hour
          _sectionTitle('⏰ Jam Briefing Harian'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF060F24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.3)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Jam briefing:',
                    style: TextStyle(fontSize: 13, color: Color(0xFFD0DCFF))),
                Text('$_briefingHour:00 WIB',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: Color(0xFF6B9FFF))),
              ]),
              const SizedBox(height: 8),
              Slider(
                value: _briefingHour.toDouble(),
                min: 0, max: 23, divisions: 23,
                activeColor: const Color(0xFF2D5BE3),
                inactiveColor: const Color(0xFF1A3A8F).withOpacity(0.3),
                onChanged: (v) => setState(() => _briefingHour = v.round()),
              ),
              const Text('Orion akan kirim briefing email setiap hari pada jam ini',
                  style: TextStyle(fontSize: 10, color: Color(0xFF3A5A9A))),
            ]),
          ),
          const SizedBox(height: 20),

          // Info
          _sectionTitle('ℹ️ Informasi Akun'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF060F24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1A3A8F).withOpacity(0.3)),
            ),
            child: Column(children: [
              _infoRow('User ID', _userId),
              const Divider(color: Color(0xFF1A3A8F), height: 20),
              _infoRow('Plan', _getPlanLabel()),
              const Divider(color: Color(0xFF1A3A8F), height: 20),
              _infoRow('Email', _emailCtrl.text.isNotEmpty ? _emailCtrl.text : '-'),
            ]),
          ),
          const SizedBox(height: 24),

          // Save button
          GestureDetector(
            onTap: _loading ? null : _saveProfile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A8F), Color(0xFF2D5BE3)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF2D5BE3).withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Perubahan',
                        style: TextStyle(color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Logout / disconnect WA
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('wa_connected', false);
              if (mounted) Navigator.pushNamed(context, '/wa-reconnect');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF060F24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF2D5BE3).withOpacity(0.3)),
              ),
              child: const Center(
                child: Text('🔄 Reconnect WhatsApp',
                    style: TextStyle(color: Color(0xFF6B9FFF), fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: const Color(0xFF2D5BE3),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 12,
          color: Color(0xFF6B9FFF), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ]);
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, color: Color(0xFFD0DCFF)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF3A5A9A)),
        prefixIcon: Icon(icon, color: const Color(0xFF3A5A9A), size: 18),
        filled: true,
        fillColor: const Color(0xFF060F24),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF1A3A8F).withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2D5BE3))),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF3A5A9A))),
      Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFFD0DCFF),
          fontWeight: FontWeight.w500)),
    ]);
  }
}
EOF