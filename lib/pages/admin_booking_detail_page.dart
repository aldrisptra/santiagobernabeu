import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';

class AdminBookingDetailPage extends StatefulWidget {
  const AdminBookingDetailPage({
    super.key,
    required this.data,
    required this.booking,
  });
  final DemoData data;
  final FieldBooking booking;
  @override
  State<AdminBookingDetailPage> createState() => _AdminBookingDetailPageState();
}

class _AdminBookingDetailPageState extends State<AdminBookingDetailPage> {
  Future<void> _changeStatus(bool confirm) async {
    final agree = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirm ? 'Konfirmasi booking demo?' : 'Batalkan booking?'),
        content: Text(
          confirm
              ? 'Status diubah tanpa memeriksa pembayaran sungguhan.'
              : 'Slot booking akan tersedia kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, lanjutkan'),
          ),
        ],
      ),
    );
    if (agree != true || !mounted) return;
    setState(() {
      if (confirm) {
        widget.data.confirmPayment(widget.booking);
      } else {
        widget.data.cancel(widget.booking);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Booking Admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              booking.id,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pelanggan: ${booking.customerName}'),
                    const SizedBox(height: 12),
                    Text('Telepon: ${booking.customerPhone}'),
                    const SizedBox(height: 12),
                    Text('Tanggal: ${bookingDate(booking.date)}'),
                    const SizedBox(height: 12),
                    Text('Jam: ${booking.hours.join(', ')}'),
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
            if (!booking.isHistory && booking.status == BookingStatus.pending)
              FilledButton(
                onPressed: () => _changeStatus(true),
                child: const Text('Konfirmasi booking demo'),
              ),
            if (!booking.isHistory && booking.status != BookingStatus.cancelled)
              OutlinedButton(
                onPressed: () => _changeStatus(false),
                child: const Text('Batalkan booking'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Perubahan hanya berlaku pada data demo selama aplikasi terbuka.',
            ),
          ],
        ),
      ),
    );
  }
}
