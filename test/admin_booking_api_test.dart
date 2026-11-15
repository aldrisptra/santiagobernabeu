import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiago_bernabeu/data/demo_data.dart';
import 'package:santiago_bernabeu/models/booking.dart';
import 'package:santiago_bernabeu/pages/admin_booking_page.dart';
import 'package:santiago_bernabeu/services/booking_api.dart';

import 'support/booking_fixtures.dart';

// Transport and Supabase authentication are covered in booking_api_test.dart.
// UI tests inject callbacks so they can control completion without worker
// isolates or network resources inside the widget test's fake clock.
class CallbackBookingApi extends BookingApi {
  CallbackBookingApi({required this.fetch, this.update});

  final Future<List<FieldBooking>> Function() fetch;
  final Future<FieldBooking> Function(String id, BookingStatus status)? update;

  @override
  bool get isConfigured => true;

  @override
  Future<List<FieldBooking>> fetchBookings() => fetch();

  @override
  Future<FieldBooking> updateStatus(String id, BookingStatus status) {
    final callback = update;
    if (callback == null) {
      throw StateError('Status update callback was not supplied by this test.');
    }
    return callback(id, status);
  }
}

List<FieldBooking> parseBookings(List<Map<String, dynamic>> records) =>
    records.map(FieldBooking.fromJson).toList();

Future<void> showBookingPage(WidgetTester tester, DemoData data) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(data.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminBookingPage(data: data, onChanged: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('Server bookings load, search and filter by status', (
    tester,
  ) async {
    final response = Completer<List<FieldBooking>>();
    final data = DemoData(
      bookingApi: CallbackBookingApi(fetch: () => response.future),
    );
    await showBookingPage(tester, data);
    expect(find.text('Memuat booking dari server...'), findsOneWidget);
    expect(find.text('Tidak ada booking yang sesuai.'), findsNothing);
    response.complete(parseBookings(bookingFixtures()));
    await tester.pumpAndSettle();
    expect(find.text('3 booking dari server'), findsOneWidget);
    expect(find.textContaining('API-001'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sinta');
    await tester.pumpAndSettle();
    expect(find.textContaining('API-001'), findsNothing);
    expect(find.textContaining('API-002'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menunggu pembayaran').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('API-001'), findsOneWidget);
    expect(find.textContaining('API-002'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed fetch shows retry and empty response shows empty state', (
    tester,
  ) async {
    var requests = 0;
    final data = DemoData(
      bookingApi: CallbackBookingApi(
        fetch: () async {
          requests++;
          if (requests == 1) {
            throw const BookingApiException(
              'Tidak dapat terhubung ke server booking. Periksa koneksi lalu coba lagi.',
            );
          }
          return [];
        },
      ),
    );
    await showBookingPage(tester, data);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak dapat terhubung'), findsOneWidget);
    expect(find.text('Tidak ada booking yang sesuai.'), findsNothing);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('0 booking dari server'), findsOneWidget);
    expect(find.text('Tidak ada booking yang sesuai.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);
  });

  testWidgets(
    'Failed refresh preserves previous server bookings with a message',
    (tester) async {
      var requests = 0;
      final data = DemoData(
        bookingApi: CallbackBookingApi(
          fetch: () async {
            requests++;
            if (requests > 1) {
              throw const BookingApiException('Server sibuk');
            }
            return parseBookings(bookingFixtures());
          },
        ),
      );
      await showBookingPage(tester, data);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Muat ulang booking'));
      await tester.pumpAndSettle();
      expect(find.text('Server sibuk'), findsOneWidget);
      expect(find.textContaining('data server terakhir'), findsOneWidget);
      expect(find.textContaining('API-001'), findsOneWidget);
    },
  );

  testWidgets('Status changes only after server success and survives reload', (
    tester,
  ) async {
    final records = bookingFixtures();
    var updates = 0;
    final data = DemoData(
      bookingApi: CallbackBookingApi(
        fetch: () async => parseBookings(records),
        update: (id, status) async {
          updates++;
          if (updates == 1) {
            throw const BookingApiException('Gagal menyimpan');
          }
          final record = records.firstWhere((item) => item['id'] == id);
          record['status'] = status.name;
          return FieldBooking.fromJson(record);
        },
      ),
    );
    await showBookingPage(tester, data);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('API-001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, lanjutkan'));
    await tester.pumpAndSettle();
    expect(find.text('Gagal menyimpan'), findsOneWidget);
    expect(find.text('Status: Menunggu pembayaran'), findsOneWidget);
    expect(
      data.adminBookings.firstWhere((b) => b.id == 'API-001').status,
      BookingStatus.pending,
    );
    await tester.tap(find.text('Konfirmasi booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, lanjutkan'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Terkonfirmasi'), findsOneWidget);
    expect(find.text('Gagal menyimpan'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Muat ulang booking'));
    await tester.pumpAndSettle();
    expect(
      data.adminBookings.firstWhere((b) => b.id == 'API-001').status,
      BookingStatus.confirmed,
    );
    expect(updates, 2);
    expect(tester.takeException(), isNull);
  });
}
