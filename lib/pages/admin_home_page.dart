import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'admin_dashboard_page.dart';
import 'admin_booking_page.dart';
import 'admin_schedule_page.dart';
import 'admin_customers_page.dart';
import 'admin_settings_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.data});
  final DemoData data;
  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _index = 0;
  void _refresh() {
    setState(() {});
  }

  Future<void> _logout() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari admin?'),
        content: const Text('Anda akan kembali ke halaman login.'),
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
    if (exit == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Admin Santiago Bernabéu'),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          tooltip: 'Keluar admin',
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: IndexedStack(
        index: _index,
        children: [
          AdminDashboardPage(
            data: widget.data,
            onOpen: (index) => setState(() => _index = index),
          ),
          AdminBookingPage(data: widget.data, onChanged: _refresh),
          AdminSchedulePage(data: widget.data),
          AdminCustomersPage(data: widget.data),
          AdminSettingsPage(data: widget.data, onChanged: _refresh),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Booking'),
        NavigationDestination(
          icon: Icon(Icons.calendar_month),
          label: 'Jadwal',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          label: 'Pelanggan',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Pengaturan',
        ),
      ],
    ),
  );
}
