import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'pages/account_pages.dart';
import 'pages/booking_pages.dart';
import 'pages/home_page.dart';

void main() => runApp(const SantiagoBernabeuApp());

class SantiagoBernabeuApp extends StatefulWidget {
  const SantiagoBernabeuApp({super.key});
  @override
  State<SantiagoBernabeuApp> createState() => _SantiagoBernabeuAppState();
}

class _SantiagoBernabeuAppState extends State<SantiagoBernabeuApp> {
  final _state = AppState();
  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Route<dynamic> _route(RouteSettings settings) {
    final public = {
      AppRoutes.splash,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
    };
    if (!_state.signedIn && !public.contains(settings.name)) {
      return MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.login),
        builder: (_) => AuthPage(state: _state),
      );
    }
    final booking = settings.arguments;
    final Widget page = switch (settings.name) {
      AppRoutes.splash => const SplashPage(),
      AppRoutes.login => AuthPage(state: _state),
      AppRoutes.register => AuthPage(state: _state, register: true),
      AppRoutes.forgotPassword => const ForgotPasswordPage(),
      AppRoutes.home => HomePage(state: _state),
      AppRoutes.notifications => NotificationsPage(state: _state),
      AppRoutes.editProfile => EditProfilePage(state: _state),
      AppRoutes.help => const HelpPage(),
      AppRoutes.bookingDetail
          when booking is FieldBooking && _state.bookings.contains(booking) =>
        BookingDetailPage(state: _state, booking: booking),
      AppRoutes.payment
          when booking is FieldBooking &&
              _state.bookings.contains(booking) &&
              booking.status == BookingStatus.pending &&
              !booking.isHistory =>
        PaymentPage(state: _state, booking: booking),
      _ => const _RouteErrorPage(),
    };
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Santiago Bernabéu',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      useMaterial3: true,
    ),
    initialRoute: AppRoutes.splash,
    onGenerateRoute: _route,
  );
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Image.asset('assets/images/logo.png', height: 160)),
  );
}

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Halaman tidak tersedia')),
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        ),
        child: const Text('Kembali ke Beranda'),
      ),
    ),
  );
}
