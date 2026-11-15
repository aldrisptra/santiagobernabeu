import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';
import '../services/booking_api.dart';

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
  bool _saving = false;
  String? _error;
  final _note = TextEditingController();
  bool _loadingProof = false;
  String? _proofUrl;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _showProof() async {
    setState(() => _loadingProof = true);
    try {
      final url = await widget.data.bookingApi.paymentUrl(
        widget.booking.paymentPath!,
      );
      if (mounted) setState(() => _proofUrl = url);
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingProof = false);
    }
  }

  Future<void> _review(bool approve) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.data.bookingApi.reviewPayment(
        widget.booking.id,
        approve,
        _note.text.trim(),
      );
      widget.data.applyBooking(widget.booking, updated);
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeStatus(bool confirm) async {
    final agree = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirm ? 'Konfirmasi booking?' : 'Batalkan booking?'),
        content: Text(
          confirm
              ? 'Ubah status booking menjadi terkonfirmasi?'
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
      _saving = true;
      _error = null;
    });
    try {
      await widget.data.changeAdminBookingStatus(
        widget.booking,
        confirm ? BookingStatus.confirmed : BookingStatus.cancelled,
      );
      if (mounted) setState(() => _saving = false);
    } on BookingApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Detail Booking Admin')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                booking.id,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
              Text(booking.paymentLabel),
              if (booking.paymentPath != null) ...[
                TextButton(
                  onPressed: _loadingProof ? null : _showProof,
                  child: const Text('Lihat bukti transfer'),
                ),
                if (_proofUrl != null)
                  Image.network(
                    _proofUrl!,
                    height: 300,
                    errorBuilder: (_, e, s) => const Text(
                      'Bukti gagal dimuat. Tekan Lihat bukti transfer untuk mencoba lagi.',
                    ),
                  ),
              ],
              if (booking.paymentStatus == 'submitted' &&
                  booking.status == BookingStatus.pending) ...[
                TextField(
                  controller: _note,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / alasan penolakan',
                  ),
                ),
                FilledButton(
                  onPressed: _saving ? null : () => _review(true),
                  child: const Text('Setujui pembayaran'),
                ),
                OutlinedButton(
                  onPressed: _saving ? null : () => _review(false),
                  child: const Text('Tolak bukti pembayaran'),
                ),
              ],
              if (_saving) ...[
                const LinearProgressIndicator(),
                const Text('Menyimpan perubahan booking...'),
                const SizedBox(height: 16),
              ],
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              if (!booking.isHistory &&
                  booking.status == BookingStatus.pending &&
                  booking.paymentPath == null &&
                  booking.customerId == null)
                FilledButton(
                  onPressed: _saving ? null : () => _changeStatus(true),
                  child: const Text('Konfirmasi booking'),
                ),
              if (!booking.isHistory &&
                  booking.status != BookingStatus.cancelled)
                OutlinedButton(
                  onPressed: _saving ? null : () => _changeStatus(false),
                  child: const Text('Batalkan booking'),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
