import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class WaSetupScreen extends StatefulWidget {
  final bool isReconnect; // ← tambah parameter ini
  const WaSetupScreen({super.key, this.isReconnect = false});

  @override
  State<WaSetupScreen> createState() => _WaSetupScreenState();
}

class _WaSetupScreenState extends State<WaSetupScreen> {
  int _step = 0;
  String _qrUrl = '';
  bool _isLoading = true;
  bool _isConnected = false;
  Timer? _timer;
  Timer? _qrRefreshTimer; // ← auto refresh QR tiap 20 detik

  final _nameController = TextEditingController();
  final _fieldController = TextEditingController();
  final _descController = TextEditingController();
  final _productNameController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productDescController = TextEditingController();
  final _howToOrderController = TextEditingController();
  final _waController = TextEditingController();
  final _emailController = TextEditingController();
  final _hoursController = TextEditingController();
  final _locationController = TextEditingController();

  final String _gatewayUrl = 'https://worker-production-67d8.up.railway.app';
  final String _backendUrl = 'https://web-production-d2935.up.railway.app';

  @override
  void initState() {
    super.initState();
    if (widget.isReconnect) {
      // Kalau reconnect, langsung ke step QR saja, skip form
      _step = 0;
    }
    _fetchQR();
    // Auto refresh QR tiap 20 detik biar ga expired
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isConnected) _fetchQR();
    });
  }

  Future<void> _fetchQR() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('$_gatewayUrl/qr'));
      final data = jsonDecode(res.body);
      setState(() {
        _qrUrl = data['qr_url'] ?? '';
        _isLoading = false;
      });
      _startPolling();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final res = await http.get(Uri.parse('$_gatewayUrl/status'));
        final data = jsonDecode(res.body);
        if (data['connected'] == true) {
          _timer?.cancel();
          _qrRefreshTimer?.cancel();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('wa_connected', true);
          setState(() {
            _isConnected = true;
            // Kalau reconnect, langsung balik ke home
            if (widget.isReconnect) {
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              _step = 1; // Kalau setup pertama, lanjut isi profil
            }
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _saveProfile() async {
    final profile = {
      'name': _nameController.text,
      'tagline': 'Asisten AI untuk bisnis ${_nameController.text}',
      'field': _fieldController.text,
      'description': _descController.text,
      'products': [
        {
          'name': _productNameController.text,
          'price': _productPriceController.text,
          'description': _productDescController.text,
        }
      ],
      'how_to_order': _howToOrderController.text,
      'contact': {
        'whatsapp': _waController.text,
        'email': _emailController.text,
      },
      'working_hours': _hoursController.text,
      'location': _locationController.text,
    };

    await http.post(
      Uri.parse('$_backendUrl/chat/save-profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(profile),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wa_connected', true);
    await prefs.setString('business_name', _nameController.text);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _qrRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080812),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4466FF), size: 20),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: Text(
          widget.isReconnect ? 'Reconnect WhatsApp' : 'Setup WhatsApp',
          style: const TextStyle(fontSize: 14, color: Color(0xFFC8D0FF)),
        ),
      ),
      body: SafeArea(
        child: _step == 0 ? _buildQRStep() : _buildFormStep(),
      ),
    );
  }

  Widget _buildQRStep() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            widget.isReconnect
                ? 'WhatsApp Terputus!'
                : 'Hubungkan WhatsApp Business',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: widget.isReconnect
                  ? const Color(0xFFFF4444)
                  : const Color(0xFFE8ECFF),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.isReconnect
                ? 'Scan QR ini untuk menghubungkan kembali'
                : 'Scan QR ini dengan WhatsApp Business kamu',
            style: const TextStyle(fontSize: 13, color: Color(0xFF5566AA)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          if (_isLoading)
            const CircularProgressIndicator(color: Color(0xFF4466FF))
          else if (_qrUrl.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.network(_qrUrl, width: 220, height: 220),
            )
          else
            const Text('Gagal load QR', style: TextStyle(color: Colors.red)),
          const SizedBox(height: 24),
          if (!_isConnected)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF4466FF),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Menunggu scan...',
                  style: TextStyle(color: Color(0xFF5566AA), fontSize: 13),
                ),
              ],
            ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchQR,
            child: const Text(
              'Refresh QR',
              style: TextStyle(color: Color(0xFF4466FF), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✅ WhatsApp Terhubung!',
            style: TextStyle(
              color: Color(0xFF44FF88),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sekarang isi profil bisnis kamu',
            style: TextStyle(color: Color(0xFF5566AA), fontSize: 13),
          ),
          const SizedBox(height: 24),
          _field('Nama Bisnis', _nameController),
          _field('Bidang Bisnis (contoh: Kuliner, Fashion)', _fieldController),
          _field('Deskripsi Bisnis', _descController, maxLines: 3),
          const SizedBox(height: 8),
          const Text(
            'Produk/Layanan',
            style: TextStyle(color: Color(0xFF8890AA), fontSize: 13),
          ),
          const SizedBox(height: 8),
          _field('Nama Produk', _productNameController),
          _field('Harga', _productPriceController),
          _field('Deskripsi Produk', _productDescController),
          _field('Cara Order', _howToOrderController),
          _field('Nomor WA Bisnis', _waController),
          _field('Email Bisnis', _emailController),
          _field('Jam Kerja (contoh: Senin-Sabtu 09.00-17.00)', _hoursController),
          _field('Lokasi', _locationController),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _saveProfile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B3D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2244AA), width: 0.8),
              ),
              child: const Text(
                'Mulai Gunakan Orion AI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF5577EE),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Color(0xFFE8ECFF), fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF5566AA), fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF0D0D18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF111120), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF111120), width: 0.5),
          ),
        ),
      ),
    );
  }
}