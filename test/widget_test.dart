import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiago_bernabeu/app_state.dart';
import 'package:santiago_bernabeu/main.dart';

Future<void> openLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(const SantiagoBernabeuApp());
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester) async {
  await openLogin(tester);
  await tester.enterText(find.byType(TextFormField).at(0), '081234567890');
  await tester.enterText(find.byType(TextFormField).at(1), 'password');
  await tester.tap(find.text('LOGIN'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Splash routes to login and forms reject empty values', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openLogin(tester);
    expect(find.text('SANTIAGO BERNABÉU'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan nomor telepon yang valid'), findsOneWidget);
    expect(find.text('Minimal 6 karakter'), findsOneWidget);
    await tester.tap(find.text('Lupa password?'));
    await tester.pumpAndSettle();
    expect(find.text('Pemulihan akun'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Belum memiliki akun? Daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(4));
    await tester.enterText(find.byType(TextFormField).at(0), 'Tim Santiago');
    await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
    await tester.enterText(find.byType(TextFormField).at(2), 'password');
    await tester.enterText(find.byType(TextFormField).at(3), 'password');
    await tester.ensureVisible(find.text('DAFTAR'));
    await tester.tap(find.text('DAFTAR'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Tanggal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Booking routes to payment, notifications, profile and logout', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await login(tester);
    await tester.ensureVisible(find.text('08:00'));
    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();
    final bookingButton = find.text('BOOKING 1 JAM • Rp 250.000');
    await tester.ensureVisible(bookingButton);
    await tester.tap(bookingButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Booking'), findsOneWidget);
    expect(find.text('Total: Rp 250.000'), findsOneWidget);
    await tester.tap(find.text('Lanjut ke pembayaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulasikan pembayaran berhasil'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Terkonfirmasi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.receipt_long));
    await tester.pumpAndSettle();
    expect(find.text('Booking Saya'), findsOneWidget);
    expect(find.textContaining('Terkonfirmasi'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada riwayat booking'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Terkonfirmasi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Tim Baru');
    await tester.tap(find.text('Simpan profil'));
    await tester.pumpAndSettle();
    expect(find.text('Tim Baru'), findsOneWidget);
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Booking prevents overlapping slots and cancellation frees them', () {
    final state = AppState();
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final booking = state.createBooking(date, ['08:00', '19:00'])!;
    expect(booking.total, 600000);
    expect(state.createBooking(date, ['08:00']), isNull);
    state.cancel(booking);
    expect(booking.isHistory, isTrue);
    expect(state.occupied(date, '08:00'), isFalse);
    expect(state.createBooking(date, ['08:00']), isNotNull);
    state.signOut();
    expect(state.bookings, isEmpty);
    state.dispose();
  });
}
