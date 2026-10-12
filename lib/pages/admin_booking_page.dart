import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';
import 'admin_booking_detail_page.dart';

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({
    super.key,
    required this.data,
    required this.onChanged,
  });
  final DemoData data;
  final VoidCallback onChanged;
  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  String _filter = 'Semua';
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final bookings = widget.data.bookings.where((booking) {
      final matchesStatus =
          _filter == 'Semua' || _filter == booking.statusLabel;
      final matchesSearch =
          '${booking.customerName} ${booking.customerPhone} ${booking.id}'
              .toLowerCase()
              .contains(_search.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kelola Booking',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Cari nama, nomor, atau kode booking',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _filter,
            decoration: const InputDecoration(labelText: 'Status booking'),
            items:
                ['Semua', 'Menunggu pembayaran', 'Terkonfirmasi', 'Dibatalkan']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _filter = value!),
          ),
          const SizedBox(height: 16),
          if (bookings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Tidak ada booking yang sesuai.'),
            ),
          for (final FieldBooking booking in bookings)
            Card(
              child: ListTile(
                title: Text(booking.customerName),
                subtitle: Text(
                  '${booking.id}\n${bookingDate(booking.date)} • ${booking.hours.join(', ')}\n${booking.statusLabel}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminBookingDetailPage(
                        data: widget.data,
                        booking: booking,
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() {});
                    widget.onChanged();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
