import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/booking_api.dart';

class AdminSchedulePage extends StatefulWidget {
  const AdminSchedulePage({super.key, required this.data});
  final DemoData data;
  @override
  State<AdminSchedulePage> createState() => _AdminSchedulePageState();
}

class _AdminSchedulePageState extends State<AdminSchedulePage> {
  late DateTime _date;
  bool _busy = true;
  String? _error;
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.data.loadAvailability(_date);
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(String hour) async {
    setState(() => _busy = true);
    try {
      await widget.data.toggleSlot(_date, hour);
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
      await _load();
    }
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
          onPressed: _busy ? null : _pickDate,
          icon: const Icon(Icons.calendar_month),
          label: Text('Tanggal: ${bookingDate(_date)}'),
        ),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Coba lagi')),
        ],
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
                    onChanged:
                        _busy ||
                            _error != null ||
                            widget.data.occupied(_date, hour)
                        ? null
                        : (_) => _toggle(hour),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text('Sakelar aktif = slot dibuka.'),
      ],
    ),
  );
}
