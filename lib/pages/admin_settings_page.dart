import 'package:flutter/material.dart';

import '../data/demo_data.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({
    super.key,
    required this.data,
    required this.onChanged,
  });
  final DemoData data;
  final VoidCallback onChanged;
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _form = GlobalKey<FormState>();
  late final _day = TextEditingController(
    text: widget.data.dayPrice.toString(),
  );
  late final _night = TextEditingController(
    text: widget.data.nightPrice.toString(),
  );
  @override
  void dispose() {
    _day.dispose();
    _night.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    final price = int.tryParse(value ?? '');
    if (price == null || price <= 0 || price > 10000000) {
      return 'Isi harga 1 sampai 10.000.000';
    }
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    widget.data.dayPrice = int.parse(_day.text);
    widget.data.nightPrice = int.parse(_night.text);
    widget.onChanged();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Harga berhasil disimpan')));
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pengaturan Harga',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Harga berlaku untuk booking baru. Total booking yang sudah dibuat tidak berubah.',
        ),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _day,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga siang / jam',
                  prefixText: 'Rp ',
                ),
                validator: _validatePrice,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _night,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga malam / jam',
                  prefixText: 'Rp ',
                ),
                validator: _validatePrice,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Simpan harga'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Operasional: 08.00–23.00. Tarif malam mulai 17.00. Gunakan tab Jadwal untuk membuka atau menutup slot.',
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
