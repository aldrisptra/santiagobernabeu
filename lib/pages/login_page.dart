import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'home_page.dart';
import 'admin_login_page.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import '../services/booking_api.dart';
import 'verify_email_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.data});
  final DemoData data;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.data.signIn(_phone.text.trim(), _password.text);
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
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
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
                              Image.asset(
                                'assets/images/logo.png',
                                height: 110,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'SANTIAGO BERNABÉU',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Mini Soccer Field'),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                ),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordPage(
                                          data: widget.data,
                                        ),
                                      ),
                                    ),
                                    child: const Text('Lupa password?'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
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
                                  onPressed: _busy ? null : _login,
                                  child: const Text('LOGIN'),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RegisterPage(data: widget.data),
                                  ),
                                ),
                                child: const Text(
                                  'Belum memiliki akun? Daftar',
                                ),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        final error = emailValidator(
                                          _phone.text,
                                        );
                                        if (error != null) {
                                          setState(() => _error = error);
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => VerifyEmailPage(
                                              data: widget.data,
                                              email: _phone.text.trim(),
                                            ),
                                          ),
                                        );
                                      },
                                child: const Text(
                                  'Verifikasi email yang sudah didaftarkan',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminLoginPage(data: widget.data),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                                label: const Text('Masuk admin'),
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
          ],
        ),
      ),
    );
  }
}
