import 'package:flutter/material.dart';

import '../app_state.dart';

class BookingListTab extends StatelessWidget {
  const BookingListTab({super.key, required this.state, this.history = false});
  final AppState state;
  final bool history;
  @override
  Widget build(BuildContext context) {
    final bookings = state.bookings
        .where((booking) => booking.isHistory == history)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          history ? 'Riwayat Booking' : 'Booking Saya',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (bookings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: Column(
              children: [
                Icon(
                  history ? Icons.history : Icons.receipt_long,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  history
                      ? 'Belum ada riwayat booking'
                      : 'Belum ada booking aktif',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pilih tanggal dan jam di Beranda untuk memulai.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ...bookings.map(
          (booking) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                'Lapangan Mini Soccer • ${bookingDate(booking.date)}',
              ),
              subtitle: Text(
                '${booking.hours.join(', ')}\n${booking.statusLabel}\n${rupiah(booking.total)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.bookingDetail,
                arguments: booking,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({
    super.key,
    required this.state,
    required this.booking,
  });
  final AppState state;
  final FieldBooking booking;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Detail Booking')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.sports_soccer, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Santiago Bernabéu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.id,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 28),
                  Text('Tanggal: ${bookingDate(booking.date)}'),
                  const SizedBox(height: 12),
                  Text('Jam mulai: ${booking.hours.join(', ')}'),
                  const SizedBox(height: 12),
                  Text('Durasi: ${booking.hours.length} jam'),
                  const SizedBox(height: 12),
                  Text('Status: ${booking.statusLabel}'),
                  const Divider(height: 28),
                  Text(
                    'Total: ${rupiah(booking.total)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (booking.status == BookingStatus.pending &&
              !booking.isHistory) ...[
            FilledButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.payment,
                arguments: booking,
              ),
              child: const Text('Lanjut ke pembayaran'),
            ),
            TextButton(
              onPressed: () async {
                final cancel = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Batalkan booking?'),
                    content: const Text(
                      'Jam yang dipilih akan tersedia kembali.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Kembali'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Batalkan booking'),
                      ),
                    ],
                  ),
                );
                if (cancel == true) state.cancel(booking);
              },
              child: const Text('Batalkan booking'),
            ),
          ],
          if (booking.status == BookingStatus.confirmed)
            const Text(
              'Booking terkonfirmasi dalam mode demo. Ini bukan bukti pembayaran atau reservasi lapangan sungguhan.',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    ),
  );
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.state, required this.booking});
  final AppState state;
  final FieldBooking booking;
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _method = 'Transfer bank';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pembayaran')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          rupiah(widget.booking.total),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        Text(
          '${bookingDate(widget.booking.date)} • ${widget.booking.hours.length} jam',
        ),
        const SizedBox(height: 24),
        const Text(
          'Metode pembayaran',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Pilih metode'),
          items: const [
            DropdownMenuItem(
              value: 'Transfer bank',
              child: Text('Transfer bank'),
            ),
            DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
          ],
          onChanged: (value) => setState(() => _method = value!),
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Simulasi pembayaran: belum ada rekening, kode QR, atau gateway pembayaran. Jangan melakukan transfer. Tombol berikut hanya mengubah status booking demo.',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            widget.state.confirmPayment(widget.booking);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Simulasi pembayaran berhasil')),
            );
          },
          child: const Text('Simulasikan pembayaran berhasil'),
        ),
      ],
    ),
  );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.bookings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada notifikasi'),
                ],
              ),
            ),
          ...state.bookings.map(
            (booking) => Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(booking.statusLabel),
                subtitle: Text(
                  '${bookingDate(booking.date)} • ${booking.hours.join(', ')}',
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.bookingDetail,
                  arguments: booking,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

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
            '1. Pilih tanggal di Beranda.\n2. Pilih satu atau beberapa jam yang tersedia.\n3. Konfirmasi booking dan buka detailnya.\n4. Pilih pembayaran untuk mencoba alur konfirmasi.',
          ),
          SizedBox(height: 24),
          Text(
            'Informasi lapangan',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Buka 08.00–23.00.\nHarga siang Rp 250.000/jam.\nHarga malam mulai pukul 17.00 Rp 350.000/jam.\nSetiap slot menunjukkan jam mulai dengan durasi satu jam.',
          ),
          SizedBox(height: 24),
          Text(
            'Tentang versi demo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Login, pendaftaran, booking, profil, dan pembayaran belum terhubung ke server. Data akan hilang ketika aplikasi ditutup atau akun keluar. Notifikasi menampilkan status booking demo. Pemulihan password dan pembayaran sungguhan memerlukan backend.',
          ),
        ],
      ),
    ),
  );
}
