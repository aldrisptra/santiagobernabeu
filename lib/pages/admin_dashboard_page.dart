import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({
    super.key,
    required this.data,
    required this.onOpen,
  });
  final DemoData data;
  final ValueChanged<int> onOpen;
  Widget _summary(String title, String value, IconData icon) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    int pending = 0;
    int confirmed = 0;
    int revenue = 0;
    for (final booking in data.bookings) {
      if (booking.status == BookingStatus.pending) pending++;
      if (booking.status == BookingStatus.confirmed) {
        confirmed++;
        revenue += booking.total;
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const Text('Ringkasan pengelolaan lapangan'),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summary(
                'Total booking',
                '${data.bookings.length}',
                Icons.receipt_long,
              ),
              _summary('Menunggu', '$pending', Icons.pending_actions),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summary(
                'Terkonfirmasi',
                '$confirmed',
                Icons.check_circle_outline,
              ),
              _summary('Pendapatan', rupiah(revenue), Icons.payments_outlined),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Akses cepat',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onOpen(1),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Kelola booking'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => onOpen(2),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Kelola jadwal'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Booking terbaru',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (data.bookings.isEmpty) const Text('Belum ada booking.'),
          for (final booking in data.bookings.take(3))
            Card(
              child: ListTile(
                title: Text(booking.customerName),
                subtitle: Text(
                  '${bookingDate(booking.date)} • ${booking.statusLabel}',
                ),
                onTap: () => onOpen(1),
              ),
            ),
        ],
      ),
    );
  }
}
