import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'beranda_page.dart';
import 'booking_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import '../services/booking_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.data});
  final DemoData data;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _loading = false;
  String? _error;

  Future<void> _reload() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.data.refreshCustomer();
    } on BookingApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Santiago Bernabéu'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  BerandaPage(data: widget.data, onChanged: _refresh),
                  BookingPage(data: widget.data, onChanged: _refresh),
                  HistoryPage(data: widget.data, onChanged: _refresh),
                  ProfilePage(data: widget.data, onChanged: _refresh),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Booking',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
