# Santiago Bernabéu

## Tugas presentasi: build release

Target saat ini adalah APK Android release untuk presentasi, belum publikasi
Play Store. APK sudah dibangun dan signature/non-debug diverifikasi. Bukti,
perintah build, sumber gambar dan daftar latihan ada di
[panduan presentasi](docs/PRESENTASI_RELEASE.md). Pengujian login/booking/email
dengan akun nyata di HP masih perlu dilakukan.

## Pengembangan menuju rilis

Alur pelanggan kini memakai Supabase Auth dan database: email/password, kode
verifikasi/pemulihan, profil tersimpan, booking melalui RPC, pembatalan, jadwal
server, serta transfer manual dengan bukti gambar privat dan verifikasi admin.
Harga dan rekening admin disimpan di database. ID Android yang dipilih adalah
`id.santiagobernabeu.booking`.

Jalankan migration tambahan `supabase/migrations/202611150001_customer_backend.sql`
setelah migration awal. Setup lengkap, worker penghapusan akun, signing dan
daftar verifikasi ada di [panduan rilis](docs/RELEASE.md).

**Belum dinyatakan siap produksi:** verifikasi alur cloud, SMTP, worker
penghapusan, kebijakan publik, dan pengujian perangkat harus diselesaikan.

Aplikasi Flutter pemesanan lapangan, dengan backend **Supabase + PostgreSQL**
untuk login admin, pengambilan daftar booking, dan perubahan status booking.

## Status implementasi

- Admin masuk menggunakan email/password **Supabase Auth**. Akses admin
  diperiksa dari tabel `booking_admins`.
- Daftar booking berasal dari PostgreSQL `bookings` melalui Supabase Data API.
- Konfirmasi/pembatalan memakai fungsi database `set_booking_status` yang
  memeriksa hak admin, tanggal, serta transisi status sebelum menyimpan.
- RLS membatasi data server ke admin. Trigger dan kunci unik slot mencegah
  dua booking aktif memakai tanggal/jam yang sama untuk satu lapangan.
- Halaman booking menyediakan loading, pencarian/filter, refresh, dan coba lagi.

Pelanggan memakai Supabase Auth; booking dan profil tersimpan di PostgreSQL.
Bukti pembayaran memakai bucket Storage privat. Verifikasi pembayaran,
perubahan harga/rekening dan penutupan slot memerlukan akses admin.

Konfigurasi koneksi publik tersedia di asset `config/supabase.public.json`.
Pengujian lokal memakai respons Supabase tiruan; migration, layanan Auth/Storage,
dan alur aplikasi pada project cloud tetap perlu diverifikasi sebelum rilis.

## Setup Supabase

Supabase sudah menyertakan PostgreSQL; tidak perlu memasang database terpisah.
Langkah berikut digunakan untuk menyiapkan backend atau memakai project sendiri.

1. Buat project di [Supabase Dashboard](https://supabase.com/dashboard).
2. Buka SQL Editor dan jalankan seluruh
   [migration](supabase/migrations/202611020001_booking_backend.sql) **sekali**
   pada project yang masih kosong. Lanjutkan dengan migration
   `supabase/migrations/202611150001_customer_backend.sql`.
3. Jalankan [seed.sql](supabase/seed.sql) untuk tiga contoh booking.
4. Buat akun email/password di **Authentication > Users**. Konfirmasi email akun
   demo tersebut, lalu salin UUID penggunanya.
5. Berikan hak admin di SQL Editor, dengan mengganti UUID contoh:

```sql
insert into public.booking_admins (user_id)
values ('GANTI-DENGAN-UUID-PENGGUNA'::uuid)
on conflict (user_id) do nothing;
```

6. Jika ingin mengganti koneksi bawaan, ambil **Project URL** dan **publishable
   key** dari Connect/pengaturan API. Konfigurasi lokal bersifat opsional; salin
   contoh dari terminal project:

```powershell
Copy-Item config/supabase.example.json config/supabase.local.json
```

Isi `config/supabase.local.json` dengan nilai project kamu:

```json
{
  "SUPABASE_URL": "https://PROJECT-REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "GANTI-DENGAN-PUBLISHABLE-KEY"
}
```

File lokal tersebut diabaikan Git dan hanya dipakai jika diteruskan melalui
`--dart-define-from-file`. Sediakan URL dan key lengkap dari project yang sama
untuk mengganti koneksi bawaan. Untuk project lama, `SUPABASE_ANON_KEY` juga
diterima sebagai pengganti `SUPABASE_PUBLISHABLE_KEY`. File contoh juga memuat
identitas pengelola, email bantuan dan URL kebijakan privasi untuk konfigurasi
rilis; isi URL publik yang benar-benar aktif sebelum rilis.

Asset bawaan hanya berisi URL dan publishable key yang memang boleh dibundel
dalam aplikasi. Keamanan data tetap bergantung pada Supabase Auth, RLS tabel
dan Storage, serta pemeriksaan hak akses di fungsi server. Jangan masukkan
secret key, `service_role`, password database, password admin, SMTP secret,
atau worker secret ke konfigurasi Flutter.

## Menjalankan aplikasi

Di terminal dari folder proyek jalankan:

```powershell
flutter pub get --enforce-lockfile
flutter run
```

Aplikasi otomatis memuat `config/supabase.public.json`; file lokal dan argumen
dart-define tidak diperlukan untuk menjalankan koneksi bawaan.

Untuk server web dengan alamat tetap di PowerShell Windows:

```powershell
.\run-web.cmd
```

Setelah server siap, buka `http://127.0.0.1:7357`. Launcher ini memakai koneksi
bawaan dan port tetap. Jika halaman lama masih terbuka, hentikan proses lama
dan buka alamat dari launcher ini. Dependency Flutter harus sudah terpasang;
launcher memakai `--no-pub`.

Untuk memakai konfigurasi lokal sebagai override opsional:

```powershell
flutter run --dart-define-from-file=config/supabase.local.json
```

Di VS Code, pilih konfigurasi **Flutter + Supabase** (perangkat yang dipilih)
atau **Chrome + Supabase** pada Run and Debug, lalu tekan F5. Keduanya memuat
asset publik bawaan tanpa file lokal. Jika pasangan URL dan key dart-define
tersedia lengkap, aplikasi menggunakannya sebagai pengganti asset bawaan.
Setelah mengubah asset, argumen atau file JSON, hentikan proses aplikasi dan
jalankan ulang; hot reload tidak menjalankan ulang inisialisasi Supabase.

Emulator dan HP memakai URL HTTPS Supabase yang sama. Komputer tidak perlu
menjalankan server Python atau membuka port lokal. Setelah mengganti konfigurasi,
hentikan dan jalankan ulang aplikasi.

Jika konfigurasi terpilih tidak valid, login pelanggan/admin ditolak dengan
pesan konfigurasi.
Tidak ada fallback ke login lokal, backend Python, atau akun admin hardcoded.

Untuk membangun Android App Bundle dengan koneksi bawaan:

```powershell
flutter build appbundle --release
```

Untuk rilis yang memakai konfigurasi lokal, termasuk URL kebijakan privasi:

```powershell
flutter build appbundle --release --dart-define-from-file=config/supabase.local.json
```

Folder `server/` menyimpan demo Python + SQLite terdahulu. Flutter sekarang
tidak menggunakannya. Data SQLite lama tidak otomatis disalin ke PostgreSQL.

## Demonstrasi API saat asistensi

1. Pilih **Masuk admin**, lalu login dengan akun Supabase yang diberi hak admin.
2. Buka **Booking**. Tunjukkan data API-001/002/003 dari PostgreSQL.
3. Tunjukkan pemanggilan `.from('bookings').select(...)` pada `BookingApi`:
   request dikirim ke `GET /rest/v1/bookings` menggunakan sesi pengguna.
4. Cari Budi/Sinta dan coba filter status. Buka detail booking yang belum lewat,
   lalu konfirmasi/batalkan. Aplikasi memanggil
   `POST /rest/v1/rpc/set_booking_status`.
5. Periksa perubahan di Table Editor. Muat ulang daftar atau jalankan ulang
   aplikasi untuk menunjukkan data tetap tersimpan.
6. Keluar admin: sesi Supabase ditutup dan cache data admin dibersihkan.

Tanggal seed mengikuti Asia/Singapore saat SQL seed pertama dijalankan.
Menjalankan seed lagi tidak menimpa tanggal/status booking yang sudah ada.

## Struktur dan pengujian

- `config/supabase.public.json`: asset URL dan publishable key bawaan.
- `lib/config/supabase_config.dart`: validasi konfigurasi publik Supabase.
- `lib/main.dart`: pemuatan konfigurasi dan inisialisasi Supabase Flutter.
- `lib/services/booking_api.dart`: Auth, pemeriksaan admin, SELECT, RPC, dan error.
- `lib/models/booking.dart`: konversi/validasi JSON booking.
- `lib/data/demo_data.dart`: state aplikasi dan pemisahan booking server/lokal.
- `lib/pages/admin_*.dart`: login dan pengelolaan admin.
- `supabase/`: migration, seed, SQL smoke test, dan panduan database.

```powershell
flutter analyze
flutter test
```

Tes Flutter memakai client Supabase dengan transport tiruan. Setelah project
siap, jalankan [SQL smoke test](supabase/tests/booking_smoke.sql) sesuai
[panduan backend](supabase/README.md), lalu uji login dan perubahan booking
langsung dari aplikasi. SQL smoke test membatalkan fixture lewat ROLLBACK.

Rujukan: [Supabase Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter),
[API keys](https://supabase.com/docs/guides/getting-started/api-keys),
dan [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
