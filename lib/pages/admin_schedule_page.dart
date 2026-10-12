import 'package:flutter/material.dart';

import '../data/demo_data.dart';

class AdminSchedulePage extends StatefulWidget {
  const AdminSchedulePage({super.key, required this.data});
  final DemoData data;
  @override
  State<AdminSchedulePage> createState() => _AdminSchedulePageState();
}

class _AdminSchedulePageState extends State<AdminSchedulePage> {
  late DateTime _date;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Jadwal Lapangan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tutup slot untuk perawatan atau acara. Slot yang sudah dipesan harus dibatalkan melalui halaman booking terlebih dahulu.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month),
          label: Text('Tanggal: ${bookingDate(_date)}'),
        ),
        const SizedBox(height: 16),
        for (final hour in DemoData.hours)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hour,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.data.occupied(_date, hour)
                              ? 'Sudah dipesan'
                              : widget.data.blocked(_date, hour)
                              ? 'Ditutup admin'
                              : 'Tersedia',
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: !widget.data.blocked(_date, hour),
                    onChanged: widget.data.occupied(_date, hour)
                        ? null
                        : (_) => setState(
                            () => widget.data.toggleSlot(_date, hour),
                          ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Sakelar aktif = slot dibuka. Jadwal ini menggunakan data demo.',
        ),
      ],
    ),
  );
}
