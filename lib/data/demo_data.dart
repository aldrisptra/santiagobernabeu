import '../models/booking.dart';

// Data demo dibagikan ke halaman lewat constructor, belum memakai database.
class DemoData {
  String name = 'Pemain';
  String phone = '';
  bool signedIn = false;
  int dayPrice = 250000;
  int nightPrice = 350000;
  static const hours = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
  ];
  final Map<String, Set<String>> blockedSlots = {};

  int pricePerHour(String hour) {
    return int.parse(hour.substring(0, 2)) >= 17 ? nightPrice : dayPrice;
  }

  bool blocked(DateTime date, String hour) {
    return blockedSlots[bookingDate(date)]?.contains(hour) ?? false;
  }

  void toggleSlot(DateTime date, String hour) {
    final slots = blockedSlots.putIfAbsent(bookingDate(date), () => {});
    if (!slots.remove(hour)) slots.add(hour);
  }

  // Contoh data untuk mencoba UI admin tanpa database.
  void prepareAdminDemo() {
    if (_bookings.isNotEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _bookings.addAll([
      FieldBooking(
        id: 'DEMO-001',
        date: today,
        hours: ['08:00'],
        customerName: 'Budi',
        customerPhone: '081234567801',
        dayPrice: dayPrice,
        nightPrice: nightPrice,
      ),
      FieldBooking(
        id: 'DEMO-002',
        date: today.add(const Duration(days: 1)),
        hours: ['19:00'],
        customerName: 'Sinta',
        customerPhone: '081234567802',
        dayPrice: dayPrice,
        nightPrice: nightPrice,
      )..status = BookingStatus.confirmed,
      FieldBooking(
        id: 'DEMO-003',
        date: today.subtract(const Duration(days: 1)),
        hours: ['09:00'],
        customerName: 'Budi',
        customerPhone: '081234567801',
        dayPrice: dayPrice,
        nightPrice: nightPrice,
      )..status = BookingStatus.confirmed,
    ]);
  }

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
      if (occupied(date, hour) || blocked(date, hour)) return null;
    }
    final booking = FieldBooking(
      id: 'SB-${DateTime.now().microsecondsSinceEpoch}',
      customerName: name,
      customerPhone: phone,
      dayPrice: dayPrice,
      nightPrice: nightPrice,
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
