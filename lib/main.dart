import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/load_supabase_config.dart';
import 'data/demo_data.dart';
import 'pages/splash_page.dart';
import 'services/booking_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? configurationError;
  BookingApi? bookingApi;
  try {
    final config = await loadSupabaseConfig();
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      postgrestOptions: const PostgrestClientOptions(
        requestTimeout: Duration(seconds: 10),
        retryEnabled: false,
      ),
    );
    bookingApi = BookingApi(client: Supabase.instance.client);
  } on SupabaseConfigurationException catch (error) {
    configurationError = error.message;
  } on Exception {
    configurationError = 'Koneksi Supabase belum dapat disiapkan. Periksa konfigurasi lalu jalankan ulang aplikasi.';
  }
  runApp(
    SantiagoBernabeuApp(
      bookingApi:
          bookingApi ?? BookingApi(configurationError: configurationError),
    ),
  );
}

class SantiagoBernabeuApp extends StatefulWidget {
  const SantiagoBernabeuApp({super.key, this.bookingApi});
  final BookingApi? bookingApi;

  @override
  State<SantiagoBernabeuApp> createState() => _SantiagoBernabeuAppState();
}

class _SantiagoBernabeuAppState extends State<SantiagoBernabeuApp> {
  late final data = DemoData(bookingApi: widget.bookingApi);

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

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
