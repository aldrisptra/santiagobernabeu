import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bantuan & informasi')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara booking',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            '1. Pilih tanggal di Beranda.\n2. Pilih satu atau beberapa jam yang tersedia.\n3. Konfirmasi booking dan buka detailnya.\n4. Pilih pembayaran untuk melanjutkan konfirmasi.',
          ),
          SizedBox(height: 24),
          Text(
            'Informasi lapangan',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Buka 08.00–23.00.\nHarga terbaru dapat dilihat di Beranda.\nTarif malam berlaku mulai pukul 17.00.\nSetiap slot menunjukkan jam mulai dengan durasi satu jam.',
          ),
        ],
      ),
    ),
  );
}
