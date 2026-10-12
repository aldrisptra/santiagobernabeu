import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';
import 'payment_page.dart';

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({
    super.key,
    required this.data,
    required this.booking,
  });
  final DemoData data;
  final FieldBooking booking;
  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  FieldBooking get booking => widget.booking;
  DemoData get data => widget.data;
  @override
  Widget build(BuildContext context) => Scaffold(
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
        if (booking.status == BookingStatus.pending && !booking.isHistory) ...[
          FilledButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentPage(data: data, booking: booking),
                ),
              );
              if (mounted) setState(() {});
            },
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
              if (cancel == true && mounted) {
                setState(() => data.cancel(booking));
              }
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
  );
}
