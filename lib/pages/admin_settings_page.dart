import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/booking_api.dart';

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
  bool _busy = true;
  String? _error;
  final _bank = TextEditingController(),
      _account = TextEditingController(),
      _holder = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.data.loadSettings();
      if (!mounted) return;
      _day.text = widget.data.dayPrice.toString();
      _night.text = widget.data.nightPrice.toString();
      _bank.text = widget.data.bankName;
      _account.text = widget.data.bankAccount;
      _holder.text = widget.data.bankHolder;
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    _bank.dispose();
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    final price = int.tryParse(value ?? '');
    if (price == null || price <= 0 || price > 10000000) {
      return 'Isi harga 1 sampai 10.000.000';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.data.bookingApi.saveSettings({
        'day_price': int.parse(_day.text),
        'night_price': int.parse(_night.text),
        'bank_name': _bank.text.trim(),
        'bank_account': _account.text.trim(),
        'bank_holder': _holder.text.trim(),
      });
      await widget.data.loadSettings();
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Harga berhasil disimpan')));
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
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
              TextFormField(
                controller: _bank,
                decoration: const InputDecoration(labelText: 'Nama bank'),
                validator: requiredText,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _account,
                decoration: const InputDecoration(labelText: 'Nomor rekening'),
                validator: requiredText,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _holder,
                decoration: const InputDecoration(
                  labelText: 'Nama pemilik rekening',
                ),
                validator: requiredText,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
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
