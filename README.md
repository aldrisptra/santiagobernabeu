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
Perpindahan halaman memakai `Navigator.push`, `Navigator.pop`, dan
`MaterialPageRoute`. Setelah login/daftar, stack halaman dibersihkan supaya
tombol kembali tidak membawa pengguna ke form login.

Struktur kode:
- `lib/main.dart`: menjalankan aplikasi dan mengatur tema.
- `lib/models/booking.dart`: model booking, harga, dan status.
- `lib/data/demo_data.dart`: data demo, format rupiah, dan validasi form.
- `lib/pages/`: satu file untuk setiap halaman (splash, login, daftar,
  beranda, booking, detail booking, pembayaran, riwayat, profil, edit profil,
  notifikasi, lupa password, dan bantuan).

Data demo dibagikan lewat constructor. Tampilan diperbarui dengan `setState`
setelah kembali dari halaman yang mengubah data. Layout menggunakan `Row`,
`Column`, `Padding`, dan `SizedBox`, tanpa widget `Center`. Halaman panjang
tetap dapat digulir dengan `SingleChildScrollView` atau `ListView`.

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

## UI admin (demo)

Dari halaman login pelanggan, pilih **Masuk admin demo**.
Gunakan username `admin` dan password `admin123` untuk mencoba UI.
Ini hanya pemeriksaan lokal untuk demo, bukan autentikasi admin sungguhan.

Halaman admin dipisah dalam file `lib/pages/admin_*.dart`:
- Dashboard: ringkasan booking dan pendapatan demo.
- Booking: pencarian, filter status, detail, konfirmasi dan pembatalan.
- Jadwal: pilih tanggal dan buka/tutup slot lapangan.
- Pelanggan: nama, nomor telepon dan jumlah booking; pencarian pelanggan.
- Pengaturan: harga siang dan malam untuk booking baru.

Saat masuk admin tanpa booking, tiga contoh booking ditambahkan untuk mencoba UI.
Perubahan admin dan pelanggan memakai objek `DemoData` yang sama selama aplikasi
terbuka. Keluar admin kembali ke login pelanggan tanpa menghapus perubahan.
Slot yang sudah dipesan tidak dapat ditutup melalui Jadwal; batalkan booking dulu.
Perubahan harga tidak mengubah total booking yang sudah dibuat.
Database, verifikasi pembayaran, dan otorisasi server belum diimplementasikan.
