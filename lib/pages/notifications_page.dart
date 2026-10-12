import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'booking_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.data});
  final DemoData data;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  DemoData get data => widget.data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifikasi')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (data.bookings.isEmpty)
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
        ...data.bookings.map(
          (booking) => Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(booking.statusLabel),
              subtitle: Text(
                '${bookingDate(booking.date)} • ${booking.hours.join(', ')}',
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailPage(data: data, booking: booking),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
      ],
    ),
  );
}
