import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'beranda_page.dart';
import 'booking_page.dart';
import 'history_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.data});
  final DemoData data;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
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
