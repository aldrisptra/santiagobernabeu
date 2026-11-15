import 'dart:async';

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'admin_home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.data});
  final DemoData data;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      Widget destination = LoginPage(data: widget.data);
      if (widget.data.bookingApi.userId != null) {
        try {
          if (await widget.data.bookingApi.isAdmin()) {
            destination = AdminHomePage(data: widget.data);
          } else {
            await widget.data.loadCustomer();
            destination = HomePage(data: widget.data);
          }
        } catch (_) {
          /* Login remains available when session restoration fails. */
        }
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Image.asset('assets/images/logo.png', height: 160)],
          ),
        ],
      ),
    );
  }
}
