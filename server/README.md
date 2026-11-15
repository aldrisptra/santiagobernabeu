# API booking untuk demo

> Demo lama Python + SQLite. Integrasi Flutter sekarang memakai Supabase +
> PostgreSQL dan tidak memanggil server ini. Ikuti README utama dan folder
> `supabase/` untuk backend yang digunakan aplikasi.

Backend ini memakai Python 3.10+ dan SQLite dari standard library; tidak perlu `pip install`.
Jalankan dari folder utama proyek:

```powershell
python server/booking_api.py
```

API tersedia di `http://localhost:8000/bookings`. Secara default server mendengarkan
pada `0.0.0.0:8000` agar emulator/HP pada jaringan yang sama dapat mengaksesnya.
Android Emulator menggunakan alamat komputer `http://10.0.2.2:8000`.
HP fisik memakai IP LAN komputer; izinkan Python pada Windows Firewall untuk jaringan privat.
Keduanya harus terhubung ke jaringan yang sama.

Opsi konfigurasi:

```powershell
python server/booking_api.py --host 127.0.0.1 --port 8000 --database server/data/bookings.sqlite3
```

`server/data/bookings.sqlite3` dibuat otomatis dan tidak masuk Git. Saat database pertama kali
dibuat, server mengisi tiga contoh booking: `API-001` hari ini (pending), `API-002` besok
(confirmed), dan `API-003` kemarin (confirmed). Tanggal awal dan perubahan status tetap
tersimpan setelah server dimulai ulang. Untuk demo pada hari lain dengan seed baru,
hentikan server lalu gunakan `--database server/data/demo-baru.sqlite3`.

## Endpoint

`GET /bookings` mengembalikan `200` dengan contoh bentuk respons:

```json
{
  "data": [
    {
      "id": "API-001",
      "date": "2026-11-02",
      "hours": ["08:00"],
      "customer_name": "Budi",
      "customer_phone": "081234567801",
      "day_price": 250000,
      "night_price": 350000,
      "status": "pending"
    }
  ]
}
```

`PATCH /bookings/API-001` dengan header `Content-Type: application/json` dan body
`{"status":"confirmed"}` mengonfirmasi booking pending. Gunakan `{"status":"cancelled"}`
untuk membatalkan booking pending/confirmed. Respons `200` berbentuk `{"data": {...}}`.
Booking dengan tanggal sebelum hari ini menurut waktu komputer server tidak bisa diubah.
Status `cancelled` tidak bisa diubah kembali.

Contoh melalui PowerShell:

```powershell
Invoke-RestMethod http://localhost:8000/bookings
Invoke-RestMethod http://localhost:8000/bookings/API-001 -Method Patch -ContentType 'application/json' -Body '{"status":"confirmed"}'
```

Kesalahan dikirim sebagai JSON `{"message":"..."}`: `400` untuk body/status tidak valid,
`404` untuk endpoint/ID tidak ditemukan, `409` untuk perubahan status yang ditolak,
`413` jika body melebihi 16 KiB, dan `415` jika tipe konten bukan JSON.
`OPTIONS` serta header CORS tersedia untuk pengujian Flutter web.

## Tes

Jalankan dari folder utama proyek:

```powershell
python -m unittest discover -s server -p "test_*.py" -v
```

Tes mengirim request HTTP ke server loopback dengan port sementara dan database sementara,
termasuk validasi perubahan status, error JSON, CORS, dan persistensi setelah restart.

Backend ini khusus demo lokal: belum memiliki autentikasi, otorisasi, maupun HTTPS,
dan CORS mengizinkan semua origin. Gunakan data contoh dan jaringan lokal tepercaya.
