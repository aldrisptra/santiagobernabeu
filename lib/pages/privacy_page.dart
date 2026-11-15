import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'riaacoria@gmail.com',
  );
  static const operatorName = String.fromEnvironment(
    'OPERATOR_NAME',
    defaultValue: 'Muhammad Aldri Saputra',
  );
  static const policyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kebijakan privasi')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        Text(
          'Santiago Bernabéu',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text('Pengelola: $operatorName'),
        SizedBox(height: 16),
        Text(
          'Data yang digunakan: nama, email, nomor telepon, tanggal dan jam pemesanan, serta gambar bukti transfer. Password ditangani oleh layanan Supabase Auth; aplikasi tidak menyimpan password dalam tabel profil.',
        ),
        SizedBox(height: 16),
        Text(
          'Data digunakan untuk autentikasi, pemesanan lapangan, pemeriksaan pembayaran, dan bantuan pelanggan. Profil dan pemesanan hanya tersedia bagi pemilik akun dan admin berwenang. Bukti transfer disimpan privat dengan akses terbatas. Penyimpanan dan autentikasi diproses melalui Supabase.',
        ),
        SizedBox(height: 16),
        Text(
          'Aplikasi meminta akses hanya ke foto yang dipilih untuk unggah bukti pembayaran. Jangan sertakan PIN, password bank, atau data lain yang tidak diperlukan pada bukti transfer.',
        ),
        SizedBox(height: 16),
        Text(
          'Data disimpan selama akun digunakan. Untuk menghapus akun dan data terkait, pilih Profil > Hapus akun. Permintaan dicatat untuk diproses pengelola. Cadangan layanan dapat mengikuti siklus retensi penyedia. Selesaikan terlebih dahulu urusan pembayaran atau pengembalian dana dengan pengelola.',
        ),
        SizedBox(height: 16),
        SelectableText(
          'Bantuan dan permintaan penghapusan dari luar aplikasi: $supportEmail',
        ),
        SizedBox(height: 16),
        SelectableText('Kebijakan privasi publik: $policyUrl'),
      ],
    ),
  );
}
