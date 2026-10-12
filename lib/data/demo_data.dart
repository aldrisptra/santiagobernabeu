import '../models/booking.dart';

// Data demo dibagikan ke halaman lewat constructor, belum memakai database.
class DemoData {
  String name = 'Pemain';
  String phone = '';
  bool signedIn = false;
  final List<FieldBooking> _bookings = [];
  List<FieldBooking> get bookings => List.unmodifiable(_bookings);
  void signIn(String number, {String? displayName}) {
    phone = number;
    if (displayName != null) name = displayName;
    signedIn = true;
  }

  void signOut() {
    signedIn = false;
    name = 'Pemain';
    phone = '';
    _bookings.clear();
  }

  void updateProfile(String newName, String number) {
    name = newName;
    phone = number;
  }

  bool occupied(DateTime date, String hour) {
    for (final booking in _bookings) {
      if (booking.date == date &&
          booking.status != BookingStatus.cancelled &&
          booking.hours.contains(hour)) {
        return true;
      }
    }
    return false;
  }

  FieldBooking? createBooking(DateTime date, List<String> hours) {
    if (hours.isEmpty) return null;
    for (final hour in hours) {
      if (occupied(date, hour)) return null;
    }
    final booking = FieldBooking(
      id: 'SB-${DateTime.now().microsecondsSinceEpoch}',
      date: date,
      hours: List.unmodifiable(hours),
    );
    _bookings.insert(0, booking);
    return booking;
  }

  void confirmPayment(FieldBooking booking) {
    if (booking.status != BookingStatus.pending) return;
    booking.status = BookingStatus.confirmed;
  }

  void cancel(FieldBooking booking) {
    booking.status = BookingStatus.cancelled;
  }
}

String rupiah(int value) {
  final digits = value.toString();
  String result = '';
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) result += '.';
    result += digits[i];
  }
  return 'Rp $result';
}

String bookingDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Wajib diisi' : null;
String? phoneValidator(String? value) =>
    RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Masukkan nomor telepon yang valid';
