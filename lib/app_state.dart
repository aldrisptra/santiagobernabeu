import 'package:flutter/material.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const bookingDetail = '/booking/detail';
  static const payment = '/booking/payment';
  static const notifications = '/notifications';
  static const editProfile = '/profile/edit';
  static const help = '/help';
}

String rupiah(int value) =>
    'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
String bookingDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

enum BookingStatus { pending, confirmed, cancelled }

class FieldBooking {
  FieldBooking({required this.id, required this.date, required this.hours});
  final String id;
  final DateTime date;
  final List<String> hours;
  BookingStatus status = BookingStatus.pending;
  int get total => hours.fold(
    0,
    (sum, hour) =>
        sum + (int.parse(hour.substring(0, 2)) >= 17 ? 350000 : 250000),
  );
  String get statusLabel => switch (status) {
    BookingStatus.pending => 'Menunggu pembayaran',
    BookingStatus.confirmed => 'Terkonfirmasi',
    BookingStatus.cancelled => 'Dibatalkan',
  };
  bool get isHistory =>
      status == BookingStatus.cancelled ||
      date.isBefore(
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      );
}

/// Prototype state only: no backend, real authentication, or real payment.
class AppState extends ChangeNotifier {
  String name = 'Pemain';
  String phone = '';
  bool signedIn = false;
  final List<FieldBooking> _bookings = [];
  List<FieldBooking> get bookings => List.unmodifiable(_bookings);
  void signIn(String number, {String? displayName}) {
    phone = number;
    if (displayName != null) name = displayName;
    signedIn = true;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    name = 'Pemain';
    phone = '';
    _bookings.clear();
    notifyListeners();
  }

  void updateProfile(String newName, String number) {
    name = newName;
    phone = number;
    notifyListeners();
  }

  bool occupied(DateTime date, String hour) => _bookings.any(
    (b) =>
        b.date == date &&
        b.status != BookingStatus.cancelled &&
        b.hours.contains(hour),
  );
  FieldBooking? createBooking(DateTime date, List<String> hours) {
    if (hours.isEmpty || hours.any((hour) => occupied(date, hour))) return null;
    final booking = FieldBooking(
      id: 'SB-${DateTime.now().microsecondsSinceEpoch}',
      date: date,
      hours: List.unmodifiable(hours),
    );
    _bookings.insert(0, booking);
    notifyListeners();
    return booking;
  }

  void confirmPayment(FieldBooking booking) {
    if (booking.status != BookingStatus.pending) return;
    booking.status = BookingStatus.confirmed;
    notifyListeners();
  }

  void cancel(FieldBooking booking) {
    booking.status = BookingStatus.cancelled;
    notifyListeners();
  }
}
