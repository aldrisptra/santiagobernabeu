import '../models/booking.dart';
import '../services/booking_api.dart';

import 'dart:math';

// Shared state; durable data and authorization live in Supabase.
class DemoData {
  DemoData({BookingApi? bookingApi}) : bookingApi = bookingApi ?? BookingApi();

  final BookingApi bookingApi;
  final Map<String, FieldBooking> _apiBookings = {};
  int _bookingRevision = 0;
  int _adminSessionRevision = 0;
  int _customerSessionRevision = 0;
  bool hasLoadedApiBookings = false;
  int get apiBookingCount => _apiBookings.length;
  List<FieldBooking> get adminBookings =>
      List.unmodifiable(_apiBookings.values);

  bool isApiBooking(FieldBooking booking) =>
      _apiBookings.containsKey(booking.id);

  Future<void> loadAdminBookings() async {
    final revision = ++_bookingRevision;
    final bookings = await bookingApi.fetchBookings();
    // Abaikan respons lama yang tiba setelah perubahan status atau logout.
    if (revision != _bookingRevision) return;
    _apiBookings
      ..clear()
      ..addEntries(bookings.map((booking) => MapEntry(booking.id, booking)));
    hasLoadedApiBookings = true;
  }

  Future<void> changeAdminBookingStatus(
    FieldBooking booking,
    BookingStatus status,
  ) async {
    if (isApiBooking(booking)) {
      final sessionRevision = _adminSessionRevision;
      _bookingRevision++;
      final updated = await bookingApi.updateStatus(booking.id, status);
      if (sessionRevision != _adminSessionRevision) return;
      _bookingRevision++;
      booking.status = updated.status;
      _apiBookings[booking.id] = updated;
    } else {
      throw const BookingApiException(
        'Muat ulang booking sebelum mengubah status.',
      );
    }
  }

  Future<void> signInAdmin(String email, String password) async {
    await bookingApi.signInAdmin(email: email, password: password);
    _clearAdminBookings();
  }

  Future<void> signOutAdmin() async {
    _clearAdminBookings();
    try {
      await bookingApi.signOutAdmin();
    } finally {
      _clearAdminBookings();
    }
  }

  void _clearAdminBookings() {
    _adminSessionRevision++;
    _bookingRevision++;
    _apiBookings.clear();
    hasLoadedApiBookings = false;
  }

  void dispose() => bookingApi.close();

  String name = 'Pemain';
  String phone = '';
  String bankName = '', bankAccount = '', bankHolder = '';
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

  Future<void> toggleSlot(DateTime date, String hour) async {
    await bookingApi.setSlotClosed(date, hour, !blocked(date, hour));
    await loadAvailability(date);
  }

  final List<FieldBooking> _bookings = [];
  List<FieldBooking> get bookings => List.unmodifiable(_bookings);
  Future<void> signIn(String email, String password) async {
    await bookingApi.signInCustomer(email, password);
    await loadCustomer();
  }

  Future<void> loadCustomer() async {
    final revision = _customerSessionRevision;
    final profile = await bookingApi.loadProfile();
    if (revision != _customerSessionRevision) return;
    name = profile['name'] as String;
    phone = profile['phone'] as String;
    await refreshCustomer();
    if (revision != _customerSessionRevision) return;
    signedIn = true;
  }

  Future<void> refreshCustomer() async {
    final revision = _customerSessionRevision;
    final records = await bookingApi.fetchMyBookings();
    await loadSettings();
    if (revision != _customerSessionRevision) return;
    _bookings
      ..clear()
      ..addAll(records);
  }

  Future<void> loadSettings() async {
    final settings = await bookingApi.fetchSettings();
    dayPrice = settings['day_price'] as int;
    nightPrice = settings['night_price'] as int;
    bankName = settings['bank_name'] as String;
    bankAccount = settings['bank_account'] as String;
    bankHolder = settings['bank_holder'] as String;
  }

  final Map<String, Set<String>> _occupiedSlots = {};
  Future<void> loadAvailability(DateTime date) async {
    final slots = await bookingApi.availability(date);
    blockedSlots[bookingDate(date)] = {
      for (final s in slots)
        if (s['closed'] == true) s['hour'] as String,
    };
    _occupiedSlots[bookingDate(date)] = {
      for (final s in slots)
        if (s['occupied'] == true) s['hour'] as String,
    };
  }

  Future<void> signOut() async {
    _customerSessionRevision++;
    try {
      await bookingApi.signOutAdmin();
    } finally {
      _clearAdminBookings();
      signedIn = false;
      name = 'Pemain';
      phone = '';
      _bookings.clear();
      blockedSlots.clear();
      _occupiedSlots.clear();
      _pendingRequest = null;
      _pendingSelection = null;
    }
  }

  Future<void> updateProfile(String newName, String number) async {
    await bookingApi.saveProfile(newName, number);
    name = newName;
    phone = number;
  }

  bool occupied(DateTime date, String hour) {
    if (_occupiedSlots[bookingDate(date)]?.contains(hour) ?? false) return true;
    for (final booking in adminBookings) {
      if (booking.date == date &&
          booking.status != BookingStatus.cancelled &&
          booking.hours.contains(hour)) {
        return true;
      }
    }
    return false;
  }

  String? _pendingRequest, _pendingSelection;
  Future<FieldBooking> createBooking(DateTime date, List<String> hours) async {
    final selection = '${bookingDate(date)}:${hours.join(',')}';
    if (_pendingSelection != selection || _pendingRequest == null) {
      final random = Random.secure();
      final bytes = List.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _pendingRequest =
          '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
      _pendingSelection = selection;
    }
    final booking = await bookingApi.createCustomerBooking(
      date,
      hours,
      _pendingRequest!,
    );
    _pendingRequest = null;
    _pendingSelection = null;
    _bookings.removeWhere((b) => b.id == booking.id);
    _bookings.insert(0, booking);
    return booking;
  }

  void applyBooking(FieldBooking target, FieldBooking updated) {
    target.status = updated.status;
    target.paymentPath = updated.paymentPath;
    target.paymentStatus = updated.paymentStatus;
    target.paymentNote = updated.paymentNote;
    final index = _bookings.indexWhere((b) => b.id == updated.id);
    if (index >= 0) _bookings[index] = updated;
    if (_apiBookings.containsKey(updated.id)) {
      _apiBookings[updated.id] = updated;
    }
  }

  Future<void> cancel(FieldBooking booking) async {
    applyBooking(booking, await bookingApi.cancelCustomerBooking(booking.id));
    await loadAvailability(booking.date);
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

String? emailValidator(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Masukkan email yang valid';
