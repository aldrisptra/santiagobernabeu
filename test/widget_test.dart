import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiago_bernabeu/main.dart';
import 'package:santiago_bernabeu/models/booking.dart';
import 'package:santiago_bernabeu/services/booking_api.dart';
import 'package:santiago_bernabeu/pages/payment_page.dart';
import 'package:santiago_bernabeu/data/demo_data.dart';

class CustomerApi extends BookingApi {
  final records = <FieldBooking>[];
  bool loggedIn = false, failCreate = false;
  String? requestId;
  @override
  bool get isConfigured => true;
  @override
  Future<void> signInCustomer(String email, String password) async {
    if (password != 'password') {
      throw const BookingApiException('Email atau password tidak sesuai.');
    }
    loggedIn = true;
  }

  @override
  Future<Map<String, dynamic>> loadProfile() async => {
    'name': 'Tim Santiago',
    'phone': '081234567890',
  };
  @override
  Future<Map<String, dynamic>> fetchSettings() async => {
    'day_price': 250000,
    'night_price': 350000,
    'bank_name': 'Bank Uji',
    'bank_account': '123456',
    'bank_holder': 'Pengelola',
  };
  @override
  Future<List<FieldBooking>> fetchBookings() async => List.of(records);
  @override
  Future<List<FieldBooking>> fetchMyBookings() async => List.of(records);
  @override
  Future<List<Map<String, dynamic>>> availability(DateTime date) async => [
    for (final h in DemoData.hours)
      {'hour': h, 'closed': false, 'occupied': false},
  ];
  @override
  Future<FieldBooking> createCustomerBooking(
    DateTime date,
    List<String> hours,
    String requestId,
  ) async {
    this.requestId = requestId;
    if (failCreate) throw const BookingApiException('Koneksi terputus');
    final booking = FieldBooking(id: 'SB-TEST', date: date, hours: hours);
    records.add(booking);
    return booking;
  }

  @override
  Future<FieldBooking> cancelCustomerBooking(String id) async {
    final b = records.singleWhere((b) => b.id == id);
    b.status = BookingStatus.cancelled;
    return b;
  }

  @override
  Future<void> signOutAdmin() async {
    loggedIn = false;
  }

  @override
  Future<FieldBooking> uploadPayment(
    String id,
    Uint8List bytes,
    String extension,
  ) async => throw UnimplementedError();
}

Future<void> openLogin(WidgetTester tester, {BookingApi? api}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(SantiagoBernabeuApp(bookingApi: api));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Login validates email and rejects invalid password through backend',
    (tester) async {
      final api = CustomerApi();
      await openLogin(tester, api: api);
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle();
      expect(find.text('Masukkan email yang valid'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'pemain@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle();
      expect(find.text('Email atau password tidak sesuai.'), findsOneWidget);
      expect(api.loggedIn, isFalse);
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Tanggal'), findsOneWidget);
      expect(api.loggedIn, isTrue);
    },
  );
  testWidgets(
    'Unconfigured application cannot bypass customer authentication',
    (tester) async {
      await openLogin(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'pemain@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Konfigurasi Supabase belum diisi'),
        findsOneWidget,
      );
      expect(find.text('Pilih Tanggal'), findsNothing);
      await tester.ensureVisible(find.text('Masuk admin'));
      await tester.tap(find.text('Masuk admin'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Masuk dashboard'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  test(
    'Failed booking retry keeps idempotency key and only caches server success',
    () async {
      final api = CustomerApi()..failCreate = true;
      final state = DemoData(bookingApi: api);
      final date = DateTime(2030, 1, 1);
      await expectLater(
        state.createBooking(date, ['08:00']),
        throwsA(isA<BookingApiException>()),
      );
      final firstId = api.requestId;
      expect(state.bookings, isEmpty);
      api.failCreate = false;
      final booking = await state.createBooking(date, ['08:00']);
      expect(api.requestId, firstId);
      expect(state.bookings.single.id, booking.id);
      await state.cancel(booking);
      expect(booking.status, BookingStatus.cancelled);
      await state.signOut();
      expect(state.bookings, isEmpty);
    },
  );
  testWidgets(
    'Submitted transfer stays pending and cannot be confirmed by customer',
    (tester) async {
      final state = DemoData(bookingApi: CustomerApi());
      await state.loadSettings();
      final booking = FieldBooking(
        id: 'SB-TEST',
        date: DateTime(2030),
        hours: ['08:00'],
        paymentStatus: 'submitted',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentPage(data: state, booking: booking),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Menunggu verifikasi admin'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Unggah bukti transfer'),
            )
            .onPressed,
        isNull,
      );
      expect(booking.status, BookingStatus.pending);
    },
  );
}
