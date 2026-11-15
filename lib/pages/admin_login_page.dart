import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/booking_api.dart';
import 'admin_home_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, required this.data});
  final DemoData data;
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting || !_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.data.signInAdmin(_email.text.trim(), _password.text);
    } on BookingApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AdminHomePage(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Login Admin')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 110,
                fit: BoxFit.contain,
                semanticLabel: 'Logo Santiago Bernabéu',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Pengelola lapangan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Masukkan email dan password akun admin.'),
          if (!widget.data.bookingApi.isConfigured) ...[
            const SizedBox(height: 12),
            Text(
              widget.data.bookingApi.configurationError ?? 'Koneksi Supabase belum diatur. Ikuti panduan konfigurasi di README.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !_submitting,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email admin'),
                  validator: (value) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Masukkan email yang valid',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_submitting,
                  autofillHints: const [AutofillHints.password],
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password admin',
                  ),
                  validator: requiredText,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _submitting || !widget.data.bookingApi.isConfigured
                        ? null
                        : _login,
                    child: Text(
                      _submitting ? 'Memeriksa akun...' : 'Masuk dashboard',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
