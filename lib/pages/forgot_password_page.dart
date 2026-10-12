import 'package:flutter/material.dart';

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
          Text('Hubungi pengelola lapangan untuk bantuan pemulihan akun.'),
        ],
      ),
    ),
  );
}
