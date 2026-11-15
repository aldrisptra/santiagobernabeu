# Backend booking Supabase + PostgreSQL

Folder ini menyiapkan backend untuk login admin, daftar booking admin, dan
konfirmasi/pembatalan booking. Supabase sudah menyediakan PostgreSQL terkelola,
Auth, serta Data API. Kamu tidak perlu memasang PostgreSQL terpisah atau
menjalankan server Python untuk integrasi ini.

Alur pelanggan dan transfer manual tersedia melalui migration tambahan
`migrations/202611150001_customer_backend.sql`. Jalankan setelah migration awal.
Migration menambahkan profil, harga/rekening, penutupan slot, RPC booking
pelanggan, bukti pembayaran privat, pemeriksaan admin, serta antrean penghapusan
akun. Setup SMTP, template kode email, worker penghapusan, dan verifikasi rilis
dijelaskan di [panduan rilis](../docs/RELEASE.md).

Bagian kontrak dan smoke test di bawah menguraikan migration awal admin.
Setelah migration tambahan, pelanggan dapat membaca booking miliknya melalui
RLS; admin dapat mengubah pengaturan. Penulisan booking tetap wajib lewat RPC.
Fungsi status lama menolak konfirmasi booking pelanggan tanpa pembayaran yang
disetujui; gunakan `review_payment` untuk menyetujui/menolak bukti.

## 1. Buat project

1. Buka [Supabase Dashboard](https://supabase.com/dashboard) dan buat project baru.
2. Pilih organisasi, nama project, password database, dan region yang sesuai.
3. Tunggu project siap, lalu buka **SQL Editor**.
4. Salin seluruh isi
   [`migrations/202611020001_booking_backend.sql`](migrations/202611020001_booking_backend.sql)
   ke query baru dan jalankan sekali.
5. Untuk data demonstrasi, jalankan seluruh [`seed.sql`](seed.sql) di query baru.

Migration ditujukan untuk project kosong. Migration membuat objek baru dalam
satu transaksi; tidak menghapus data/tabel lama. Jika tabel bernama sama sudah
ada, hentikan dan sesuaikan migration sebelum menjalankannya. Jangan menghapus
tabel lama hanya agar migration bisa dijalankan ulang.

Seed menambahkan tiga booking: `API-001` hari ini pukul 08:00 berstatus pending,
`API-002` besok pukul 19:00 berstatus confirmed, dan `API-003` kemarin pukul 09:00
berstatus confirmed. Tanggal mengikuti Asia/Singapore. Menjalankan seed lagi
tidak menimpa tanggal atau status baris dengan ID yang sama; data tersebut tidak
otomatis bergeser setiap hari.

Untuk mengganti nama pelanggan pada booking demo yang sudah ada, jalankan
[`rename_demo_customers.sql`](rename_demo_customers.sql) melalui SQL Editor
sebagai `postgres`. Skrip mengganti nama `DEMO-005` menjadi Andi Pratama,
`DEMO-006` menjadi Rizky Ramadhan, dan `DEMO-007` menjadi Fajar Maulana.
Hanya kolom `customer_name` yang berubah; status, tanggal, jam, harga, ID,
dan booking lainnya tetap sama. Skrip boleh dijalankan ulang dan tidak membuat
booking yang belum ada. Setelah query berhasil, muat ulang permintaan API atau
tekan tombol muat ulang di halaman Booking admin agar nama terbaru tampil.

## 2. Buat akun admin

1. Buka **Authentication > Users**, lalu tambahkan pengguna dengan email dan
   password yang akan dipakai untuk login admin. Pastikan email akun sudah
   dikonfirmasi; jika dialog menyediakan pilihan auto-confirm, aktifkan untuk
   akun demo yang kamu buat sendiri.
2. Salin UUID pengguna tersebut dari daftar pengguna.
3. Di SQL Editor, ganti UUID contoh berikut dengan UUID akunmu, lalu jalankan:

```sql
insert into public.booking_admins (user_id)
values ('GANTI-DENGAN-UUID-PENGGUNA'::uuid)
on conflict (user_id) do nothing;
```

Hak admin diberikan melalui tabel ini oleh pemilik project. Mengisi
`user_metadata`, mengirim `role: admin`, atau sekadar berhasil login tidak
memberi akses admin. Akun pelanggan biasa tidak dapat membaca daftar booking
atau mengubah statusnya.

## 3. Hubungkan Flutter

Ambil **Project URL** dan **publishable key** dari dialog **Connect** atau
pengaturan API project. Project lama juga dapat memakai `anon` key. Gunakan
nilai konfigurasi berikut sesuai panduan menjalankan aplikasi di README utama:

```text
SUPABASE_URL=https://PROJECT-REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=publishable-key-atau-anon-key
```

Salin `config/supabase.example.json` ke `config/supabase.local.json`, lalu isi
kedua nilai tersebut. Jalankan Flutter dengan:

```powershell
flutter run --dart-define-from-file=config/supabase.local.json
```

`SUPABASE_ANON_KEY` juga diterima sebagai pengganti nama konfigurasi key di atas
untuk project lama. Key publik hanya mengidentifikasi project. Login admin tetap membutuhkan sesi
Supabase Auth, sedangkan izin data dijaga oleh database. Jangan memasukkan
`service_role`, secret key, password database, atau JWT admin ke Flutter maupun
repository.

## Kontrak API

| Operasi | Implementasi |
| --- | --- |
| Login admin | Supabase Auth menggunakan email dan password |
| Periksa admin | `public.is_booking_admin()` atau baca baris sendiri pada `public.booking_admins` |
| Daftar booking | `GET /rest/v1/bookings?select=*&order=date.desc,id.asc` menggunakan sesi admin |
| Ubah status | `POST /rest/v1/rpc/set_booking_status` dengan sesi admin |

Body perubahan status:

```json
{"p_booking_id":"API-001","p_status":"confirmed"}
```

RPC mengembalikan satu baris komposit bertipe `public.bookings`. Gunakan
representasi objek tunggal dari client/PostgREST jika diperlukan; jangan
memakai format lama `{"data": ...}` dari server Python. Kolom booking:

| Kolom | Tipe / makna |
| --- | --- |
| `id` | `text`, primary key |
| `customer_id` | UUID pengguna Auth, opsional untuk pengembangan berikutnya |
| `date` | `date`, format JSON `YYYY-MM-DD` |
| `hours` | `text[]`, jam utuh unik seperti `["08:00", "09:00"]` |
| `customer_name`, `customer_phone` | `text` |
| `day_price`, `night_price` | `integer` tidak negatif |
| `status` | `pending`, `confirmed`, atau `cancelled` |
| `created_at` | `timestamptz` |

Perubahan yang diizinkan adalah `pending -> confirmed`, `pending -> cancelled`,
dan `confirmed -> cancelled`. Booking dengan tanggal sebelum hari ini di
Asia/Singapore tidak bisa diubah. Aturan ini memeriksa tanggal booking;
booking hari ini masih dapat diubah meskipun jamnya sudah berlalu.

RPC mengunci baris sebelum memeriksa status. Fungsi menolak pengguna nonadmin
dengan `PT403`, input tidak valid dengan `PT400`, ID tidak ditemukan dengan
`PT404`, serta status/tanggal yang tidak mengizinkan perubahan dengan `PT409`.
Data API memetakan kode tersebut ke HTTP 403/400/404/409.

RLS aktif pada seluruh tabel. `anon` tidak memiliki akses. Pengguna login hanya
dapat membaca booking jika tercatat sebagai admin; pada `booking_admins` mereka
hanya dapat membaca baris sendiri. Aplikasi tidak mendapat izin langsung untuk
INSERT, UPDATE, atau DELETE, termasuk ketika login sebagai admin. Perubahan
status hanya melalui RPC yang memeriksa keanggotaan admin di dalam fungsi.

`booking_slots` merupakan tabel internal, dengan primary key `(date, hour)`
untuk satu lapangan. Trigger menyinkronkan slot booking aktif dan melepaskannya
ketika dibatalkan. Bentrok slot ditolak secara atomik oleh database, termasuk
pada request bersamaan. Tabel ini tidak dapat diakses langsung oleh aplikasi.
Jika sistem nanti memiliki beberapa lapangan, tambahkan `field_id` pada desain
tabel dan kunci slot sebelum membuka fitur tersebut.

## Uji setelah project siap

Jalankan seluruh [`tests/booking_smoke.sql`](tests/booking_smoke.sql) di SQL
Editor sebagai `postgres` setelah membuat admin. Skrip memeriksa penolakan anon,
RLS pengguna biasa/admin, larangan penulisan langsung, transisi status,
penolakan booking lampau, validasi jam, bentrok slot, dan pelepasan slot setelah
pembatalan. Fixture serta perubahan status dibatalkan dengan `ROLLBACK`.
Jika skrip berhenti karena error, jalankan `ROLLBACK;` sebelum query lain.

Smoke test ini belum membuktikan perilaku dua koneksi serentak atau respons
HTTP dari project milikmu. Setelah konfigurasi Flutter diisi, login memakai
akun admin, buka Booking, konfirmasi `API-001`, lalu periksa perubahan di
Table Editor. Setelah migration tambahan, uji pula registrasi pelanggan,
pembuatan booking, unggah bukti, dan pemeriksaan admin menggunakan dua akun.

Rujukan resmi: [Database Functions](https://supabase.com/docs/guides/database/functions),
[Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security),
dan [kode error PostgREST](https://docs.postgrest.org/en/stable/references/errors.html).
