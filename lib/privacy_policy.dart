import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
        title: const Text('Kebijakan Privasi',
            style: TextStyle(color: Color(0xFFD0DCFF), fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Kebijakan Privasi Orion AI',
              'Terakhir diperbarui: 15 Mei 2026', isTitle: true),
          _section('1. Informasi yang Kami Kumpulkan',
              'Orion AI mengumpulkan informasi berikut:\n\n• Akun Google: Nama, email, dan foto profil saat login\n• Gmail: Akses baca dan kirim email untuk briefing otomatis\n• WhatsApp: Pesan yang diterima untuk fitur auto-reply bisnis\n• Google Drive: Akses file untuk firim dokumen'),
          _section('2. Cara Kami Menggunakan Informasi',
              '• Memberikan layanan AI untuk bisnis Anda\n• Menganalisa email untuk briefing harian\n• Membalas pesan customer secara otomatis\n• Mendeteksi tugas dan deadline dari komunikasi bisnis'),
          _section('3. Keamanan Data',
              '• Semua data dienkripsi menggunakan HTTPS\n• Token akses disimpan secara aman di server\n• Kami tidak menjual data Anda kepada pihak ketiga'),
          _section('4. Hak Pengguna',
              '• Cabut akses Gmail di Google Account Settings kapan saja\n• Hapus akun dan data dengan menghubungi kami\n• Minta salinan data Anda melalui email support'),
          _section('5. Kontak',
              'Email: support@orion-ai.id\nWebsite: https://orion-ai.id'),
          _section('6. Perubahan Kebijakan',
              'Kami akan memberitahu pengguna jika ada perubahan kebijakan melalui email atau notifikasi dalam aplikasi.'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String title, String content, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
            fontSize: isTitle ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: isTitle ? const Color(0xFF6B9FFF) : const Color(0xFFD0DCFF),
          )),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(
            fontSize: 13, color: Color(0xFF8899CC), height: 1.6,
          )),
        ],
      ),
    );
  }
}
