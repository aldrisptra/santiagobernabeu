import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'booking_detail_page.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({
    super.key,
    required this.data,
    required this.onChanged,
    this.history = false,
  });
  final DemoData data;
  final bool history;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final bookings = data.bookings
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
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailPage(data: data, booking: booking),
                  ),
                );
                if (context.mounted) onChanged();
              },
            ),
          ),
        ),
      ],
    );
  }
}
