import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/booking_api.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.data});
  final DemoData data;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  late final _name = TextEditingController(text: widget.data.name);
  late final _phone = TextEditingController(text: widget.data.phone);
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
              onPressed: _busy
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      setState(() => _busy = true);
                      try {
                        await widget.data.updateProfile(
                          _name.text.trim(),
                          _phone.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } on BookingApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Simpan profil'),
            ),
          ],
        ),
      ),
    ),
  );
}
