import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/booking_api.dart';
import 'verify_email_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.data});
  final DemoData data;
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final validation = emailValidator(_email.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.data.bookingApi.resetPassword(_email.text);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailPage(
              data: widget.data,
              email: _email.text.trim(),
              recovery: true,
            ),
          ),
        );
      }
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pemulihan akun')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Masukkan email akun untuk menerima kode pemulihan.'),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        if (_error != null) Text(_error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? 'Mengirim...' : 'Kirim kode'),
        ),
      ],
    ),
  );
}
