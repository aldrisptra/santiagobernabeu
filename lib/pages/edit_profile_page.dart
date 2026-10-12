import 'package:flutter/material.dart';

import '../data/demo_data.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.data});
  final DemoData data;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
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
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                widget.data.updateProfile(
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
