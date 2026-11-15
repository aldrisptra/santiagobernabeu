import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'edit_profile_page.dart';
import 'notifications_page.dart';
import 'help_page.dart';
import 'login_page.dart';
import '../services/booking_api.dart';
import 'privacy_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.data, required this.onChanged});
  final DemoData data;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Profil',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 24),
      const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 42)),
      const SizedBox(height: 16),
      Text(
        data.name,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      Text(data.phone, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit profil'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfilePage(data: data),
                  ),
                );
                if (context.mounted) onChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifikasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsPage(data: data),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Kebijakan privasi'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Hapus akun'),
              onTap: () async {
                final agree = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Ajukan penghapusan akun?'),
                    content: const Text(
                      'Akun, profil, booking, dan bukti transfer akan dihapus permanen. Permintaan diproses oleh pengelola. Jangan melakukan transfer baru setelah mengajukan penghapusan. Hubungi pengelola untuk menyelesaikan pembayaran atau pengembalian dana yang masih berjalan.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Ajukan penghapusan'),
                      ),
                    ],
                  ),
                );
                if (agree != true || !context.mounted) return;
                try {
                  await data.bookingApi.requestAccountDeletion();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permintaan penghapusan akun tercatat.'),
                    ),
                  );
                  await data.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => LoginPage(data: data)),
                      (_) => false,
                    );
                  }
                } on BookingApiException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Bantuan & informasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Keluar'),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Keluar dari akun?'),
              content: const Text(
                'Keluar dari akun dan kembali ke halaman login?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          try {
            await data.signOut();
          } on BookingApiException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.message)));
            }
            return;
          }
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage(data: data)),
            (_) => false,
          );
        },
      ),
    ],
  );
}
