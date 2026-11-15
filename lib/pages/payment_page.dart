import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/demo_data.dart';
import '../models/booking.dart';
import '../services/booking_api.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.data, required this.booking});
  final DemoData data;
  final FieldBooking booking;
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _busy = false;
  String? _error;
  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // Use the file signature instead of trusting the filename or picker MIME.
      final png =
          bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
      final jpg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      if (!png && !jpg) {
        throw const BookingApiException('Pilih gambar JPG atau PNG.');
      }
      final updated = await widget.data.bookingApi.uploadPayment(
        widget.booking.id,
        bytes,
        png ? 'png' : 'jpg',
      );
      widget.data.applyBooking(widget.booking, updated);
      if (mounted) Navigator.pop(context);
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Gambar tidak dapat diunggah. Periksa izin foto dan koneksi, lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Pembayaran transfer')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            rupiah(widget.booking.total),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('Transfer sesuai total booking ke rekening berikut:'),
          const SizedBox(height: 12),
          SelectableText(
            '${widget.data.bankName}\n${widget.data.bankAccount}\na.n. ${widget.data.bankHolder}',
          ),
          const SizedBox(height: 24),
          Text(widget.booking.paymentLabel),
          const Text(
            'Unggah bukti JPG/PNG maksimal 5 MB. Booking dikonfirmasi setelah admin memverifikasi transfer. Jangan mengirim ulang transfer saat bukti sedang diperiksa.',
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const LinearProgressIndicator(),
          FilledButton.icon(
            onPressed:
                _busy ||
                    widget.booking.paymentStatus == 'submitted' ||
                    widget.booking.status != BookingStatus.pending
                ? null
                : _upload,
            icon: const Icon(Icons.upload_file),
            label: const Text('Unggah bukti transfer'),
          ),
        ],
      ),
    ),
  );
}
