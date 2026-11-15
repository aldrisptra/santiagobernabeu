import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';
import '../services/booking_api.dart';
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
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.data.loadAdminBookings();
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onChanged();
    } on BookingApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = widget.data.adminBookings.where((booking) {
      final matchesStatus =
          _filter == 'Semua' || _filter == booking.statusLabel;
      final matchesSearch =
          '${booking.customerName} ${booking.customerPhone} ${booking.id}'
              .toLowerCase()
              .contains(_search.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kelola Booking',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Muat ulang booking',
                  onPressed: _loading ? null : _loadBookings,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const Text('Memuat booking dari server...'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (widget.data.hasLoadedApiBookings)
                const Text(
                  'Menampilkan data server terakhir yang berhasil dimuat.',
                ),
              OutlinedButton.icon(
                onPressed: _loadBookings,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
            if (!_loading && _error == null)
              Text('${widget.data.apiBookingCount} booking dari server'),
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
                  [
                        'Semua',
                        'Menunggu pembayaran',
                        'Terkonfirmasi',
                        'Dibatalkan',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _filter = value!),
            ),
            const SizedBox(height: 16),
            if (bookings.isEmpty && !_loading && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Tidak ada booking yang sesuai.'),
              ),
            for (final FieldBooking booking in bookings)
              Card(
                child: ListTile(
                  title: Text(booking.customerName),
                  subtitle: Text(
                    '${booking.id}${widget.data.isApiBooking(booking) ? '' : ' (lokal)'}\n${bookingDate(booking.date)} • ${booking.hours.join(', ')}\n${booking.statusLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _loading
                      ? null
                      : () async {
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
      ),
    );
  }
}
