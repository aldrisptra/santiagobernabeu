import 'package:flutter/material.dart';

import '../data/demo_data.dart';

class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key, required this.data});
  final DemoData data;
  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final customers = <String, String>{};
    final counts = <String, int>{};
    for (final booking in widget.data.bookings) {
      customers[booking.customerPhone] = booking.customerName;
      counts[booking.customerPhone] = (counts[booking.customerPhone] ?? 0) + 1;
    }
    final numbers = customers.keys
        .where(
          (phone) => '$phone ${customers[phone]}'.toLowerCase().contains(
            _search.toLowerCase(),
          ),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Daftar Pelanggan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Cari pelanggan',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 16),
          if (numbers.isEmpty) const Text('Tidak ada pelanggan yang sesuai.'),
          for (final phone in numbers)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customers[phone]!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(phone),
                          Text('${counts[phone]} booking'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
