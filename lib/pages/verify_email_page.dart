import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/booking_api.dart';
import 'home_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    required this.data,
    required this.email,
    this.recovery = false,
  });
  final DemoData data;
  final String email;
  final bool recovery;
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _verified = false;
  String? _error;
  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = widget.data.bookingApi;
      if (!_verified) {
        await api.verifyEmail(
          widget.email,
          _token.text,
          recovery: widget.recovery,
        );
        _verified = true;
      }
      if (widget.recovery) {
        if (_password.text.length < 8) {
          throw const BookingApiException('Password baru minimal 8 karakter.');
        }
        await api.setPassword(_password.text);
        await widget.data.signOut();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password diperbarui. Silakan login.'),
            ),
          );
        }
      } else {
        await widget.data.loadCustomer();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => HomePage(data: widget.data)),
            (_) => false,
          );
        }
      }
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recovery ? 'Password baru' : 'Verifikasi email'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Masukkan kode dari email yang dikirim ke ${widget.email}. Periksa juga folder spam.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _token,
          decoration: const InputDecoration(labelText: 'Kode verifikasi'),
          keyboardType: TextInputType.number,
        ),
        if (widget.recovery) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password baru (minimal 8 karakter)',
            ),
          ),
        ],
        if (_error != null) Text(_error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Memproses...' : 'Verifikasi'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    if (widget.recovery) {
                      await widget.data.bookingApi.resetPassword(widget.email);
                    } else {
                      await widget.data.bookingApi.resendConfirmation(
                        widget.email,
                      );
                    }
                  } on BookingApiException catch (e) {
                    if (mounted) setState(() => _error = e.message);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Kirim ulang kode'),
        ),
      ],
    ),
  );
}
