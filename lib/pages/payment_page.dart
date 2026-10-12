import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.data, required this.booking});
  final DemoData data;
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
            widget.data.confirmPayment(widget.booking);
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
