# santiago_bernabeu

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Alur pelanggan

Splash → Login / Daftar → Beranda → Detail Booking → Pembayaran.
Tab utama: Beranda, Booking Saya, Riwayat, dan Profil.
Profil menyediakan Edit Profil, Notifikasi, Bantuan, dan Keluar.
Rute bernama didefinisikan dalam `lib/app_state.dart` dan didaftarkan di
`lib/main.dart`; rute booking memerlukan objek `FieldBooking` sebagai argumen.
Rute pelanggan memerlukan sesi login demo.

Versi ini adalah prototipe: login/daftar belum memverifikasi akun melalui server,
pembayaran hanya simulasi, dan data booking/profil tersimpan dalam memori.
Keluar atau menutup aplikasi menghapus data demo. Pemulihan password belum aktif.
Booking dibatalkan atau tanggalnya sudah lewat ditampilkan dalam Riwayat.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run
```

Untuk mencoba di HP tanpa membuka Android Studio, aktifkan USB debugging,
hubungkan HP ke komputer lokal, lalu gunakan `flutter devices` dan `flutter run`.
Flutter SDK dan Android SDK tetap diperlukan pada komputer lokal.
