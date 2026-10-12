import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santiago_bernabeu/data/demo_data.dart';
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
    await tester.tap(find.text('Konfirmasi pembayaran'));
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

  testWidgets('Cancellation refreshes notifications and history', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await login(tester);
    await tester.ensureVisible(find.text('09:00'));
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    final button = find.text('BOOKING 1 JAM • Rp 250.000');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Booking'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menunggu pembayaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Batalkan booking'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Dibatalkan'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Dibatalkan'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dibatalkan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin manages bookings, slots and prices without a database', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openLogin(tester);
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk admin'));
    await tester.tap(find.text('Masuk admin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('Masuk dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Username atau password tidak sesuai'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'admin123');
    await tester.tap(find.text('Masuk dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan pengelolaan lapangan'), findsOneWidget);
    await tester.ensureVisible(find.text('Kelola booking'));
    await tester.tap(find.text('Kelola booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('DEMO-001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, lanjutkan'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Terkonfirmasi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jadwal'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Ditutup admin'), findsOneWidget);
    await tester.tap(find.text('Pelanggan'));
    await tester.pumpAndSettle();
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Sinta'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Sinta');
    await tester.pumpAndSettle();
    expect(find.text('Budi'), findsNothing);
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '300000');
    await tester.tap(find.text('Simpan harga'));
    await tester.pumpAndSettle();
    expect(find.text('Harga berhasil disimpan'), findsOneWidget);
    await tester.tap(find.byTooltip('Keluar admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '081234567890');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('11:00'));
    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();
    expect(find.text('BOOKING 1 JAM • Rp 300.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Admin closure rejects booking and price edits preserve existing totals',
    () {
      final data = DemoData();
      final date = DateTime(2026, 10, 20);
      final booking = data.createBooking(date, ['08:00'])!;
      data.dayPrice = 300000;
      expect(booking.total, 250000);
      data.toggleSlot(date, '09:00');
      expect(data.createBooking(date, ['09:00']), isNull);
      data.toggleSlot(date, '09:00');
      expect(data.createBooking(date, ['09:00'])!.total, 300000);
    },
  );

  test('Booking prevents overlapping slots and cancellation frees them', () {
    final state = DemoData();
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
  });
}
