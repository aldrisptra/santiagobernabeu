import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'booking_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.data, required this.onChanged});
  final DemoData data;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    return BookingPage(data: data, history: true, onChanged: onChanged);
  }
}
