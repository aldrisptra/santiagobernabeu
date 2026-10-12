import 'package:flutter/material.dart';

import 'data/demo_data.dart';
import 'pages/splash_page.dart';

void main() {
  runApp(const SantiagoBernabeuApp());
}

class SantiagoBernabeuApp extends StatefulWidget {
  const SantiagoBernabeuApp({super.key});

  @override
  State<SantiagoBernabeuApp> createState() => _SantiagoBernabeuAppState();
}

class _SantiagoBernabeuAppState extends State<SantiagoBernabeuApp> {
  final data = DemoData();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Santiago Bernabéu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: SplashPage(data: data),
    );
  }
}
