import 'package:flutter/material.dart';

import '../app_state.dart';

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Wajib diisi' : null;
String? phoneValidator(String? value) =>
    RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Masukkan nomor telepon yang valid';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.state, this.register = false});
  final AppState state;
  final bool register;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    widget.state.signIn(
      _phone.text.trim(),
      displayName: widget.register ? _name.text.trim() : null,
    );
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.register ? AppBar(title: const Text('Daftar akun')) : null,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', height: 110),
                  const SizedBox(height: 20),
                  const Text(
                    'SANTIAGO BERNABÉU',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                  const Text('Mini Soccer Field'),
                  const SizedBox(height: 24),
                  if (widget.register) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nama lengkap',
                      ),
                      validator: requiredText,
                    ),
                    const SizedBox(height: 16),
                  ],
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
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        (value?.length ?? 0) >= 6 ? null : 'Minimal 6 karakter',
                  ),
                  if (widget.register) ...[
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
                  ] else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.forgotPassword,
                        ),
                        child: const Text('Lupa password?'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(widget.register ? 'DAFTAR' : 'LOGIN'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.register
                        ? Navigator.pop(context)
                        : Navigator.pushNamed(context, AppRoutes.register),
                    child: Text(
                      widget.register
                          ? 'Sudah punya akun? Login'
                          : 'Belum memiliki akun? Daftar',
                    ),
                  ),
                  const Text(
                    'Mode demo: akun belum terhubung ke server. Data hanya tersimpan selama aplikasi terbuka.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lupa password')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_reset, size: 56),
          SizedBox(height: 20),
          Text(
            'Pemulihan akun',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Pemulihan password belum tersedia pada versi demo. Saat layanan akun terhubung, kode verifikasi akan dikirim ke nomor telepon terdaftar. Untuk mencoba navigasi sekarang, kembali ke login dan gunakan nomor telepon serta password minimal 6 karakter.',
          ),
        ],
      ),
    ),
  );
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Profil',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 24),
      const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 42)),
      const SizedBox(height: 16),
      Text(
        state.name,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      Text(state.phone, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit profil'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifikasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Bantuan & informasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.help),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Keluar'),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Keluar dari akun?'),
              content: const Text(
                'Data booking demo akan dihapus saat keluar.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          state.signOut();
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (_) => false,
          );
        },
      ),
    ],
  );
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.state});
  final AppState state;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.state.name);
  late final _phone = TextEditingController(text: widget.state.phone);
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profil')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
              validator: requiredText,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor Telepon'),
              validator: phoneValidator,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                widget.state.updateProfile(
                  _name.text.trim(),
                  _phone.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text('Simpan profil'),
            ),
          ],
        ),
      ),
    ),
  );
}
