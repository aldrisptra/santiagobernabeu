-- Data demonstrasi opsional. Jalankan sebagai postgres setelah migration.
-- Tanggal mengikuti Asia/Singapore; pengulangan tidak menimpa booking lama.
begin;

insert into public.bookings
  (id, date, hours, customer_name, customer_phone, day_price, night_price, status)
values
  ('API-001', (pg_catalog.now() at time zone 'Asia/Singapore')::date,
    array['08:00'], 'Budi', '081234567801', 250000, 350000, 'pending'),
  ('API-002', (pg_catalog.now() at time zone 'Asia/Singapore')::date + 1,
    array['19:00'], 'Sinta', '081234567802', 250000, 350000, 'confirmed'),
  ('API-003', (pg_catalog.now() at time zone 'Asia/Singapore')::date - 1,
    array['09:00'], 'Budi', '081234567801', 250000, 350000, 'confirmed')
on conflict (id) do nothing;

commit;
