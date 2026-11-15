import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'home_page.dart';
import '../services/booking_api.dart';
import 'verify_email_page.dart';
import 'privacy_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.data});
  final DemoData data;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final active = await widget.data.bookingApi.registerCustomer(
        _email.text,
        _password.text,
        _name.text,
        _phone.text,
      );
      if (!mounted) return;
      if (!active) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerifyEmailPage(data: widget.data, email: _email.text.trim()),
          ),
        );
        return;
      }
      await widget.data.loadCustomer();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(data: widget.data)),
        (_) => false,
      );
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SizedBox(
                  width: 420,
                  child: Form(
                    key: _form,
                    child: Column(
                      children: [
                        Image.asset('assets/images/logo.png', height: 110),
                        const SizedBox(height: 20),
                        const Text(
                          'SANTIAGO BERNABÉU',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Nama lengkap',
                          ),
                          validator: requiredText,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Telepon',
                          ),
                          validator: phoneValidator,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: emailValidator,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.length ?? 0) >= 6
                              ? null
                              : 'Minimal 6 karakter',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Konfirmasi password',
                          ),
                          validator: (value) => value == _password.text
                              ? null
                              : 'Password tidak sama',
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Data nama, email, telepon, booking, dan bukti transfer digunakan untuk melayani pemesanan. Kebijakan privasi tersedia di Profil.',
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPage(),
                            ),
                          ),
                          child: const Text('Baca kebijakan privasi'),
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (_busy) const LinearProgressIndicator(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _register,
                            child: const Text('DAFTAR'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Sudah punya akun? Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
