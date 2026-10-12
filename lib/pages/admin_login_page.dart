import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'admin_home_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, required this.data});
  final DemoData data;
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (!_form.currentState!.validate()) return;
    if (_username.text.trim() != 'admin' || _password.text != 'admin123') {
      setState(() => _error = 'Username atau password demo tidak sesuai');
      return;
    }
    widget.data.prepareAdminDemo();
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 72,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Pengelola lapangan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'UI demo admin. Gunakan username admin dan password admin123. Belum ada autentikasi atau database.',
          ),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Username admin',
                  ),
                  validator: requiredText,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
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
                    onPressed: _login,
                    child: const Text('Masuk dashboard'),
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
