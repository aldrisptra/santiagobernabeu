import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lupa password')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_reset, size: 56),
          SizedBox(height: 20),
          Text(
            'Pemulihan akun',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Pemulihan password belum tersedia pada versi demo. Saat layanan akun terhubung, kode verifikasi akan dikirim ke nomor telepon terdaftar. Untuk mencoba navigasi sekarang, kembali ke login dan gunakan nomor telepon serta password minimal 6 karakter.',
          ),
        ],
      ),
    ),
  );
}
