-- Jalankan seluruh berkas di SQL Editor sebagai postgres setelah migration
-- dan setelah minimal satu akun diberi akses pada public.booking_admins.
-- Fixture dan perubahan status dibatalkan pada ROLLBACK terakhir.
-- Jika ada error, jalankan ROLLBACK; sebelum melanjutkan query lain.
begin;

do $$
begin
  if not exists (select 1 from public.booking_admins) then
    raise exception 'Buat akun Auth dan isi booking_admins sebelum smoke test.';
  end if;
  if exists (
    select 1 from public.bookings where id like '__SUPABASE_SMOKE_%'
  ) then
    raise exception 'ID fixture smoke test sudah dipakai; hentikan agar data lama aman.';
  end if;
end;
$$;

select pg_catalog.set_config(
  'booking_smoke.admin_id',
  (select user_id::text from public.booking_admins order by user_id limit 1),
  true
);

insert into public.bookings
  (id, date, hours, customer_name, customer_phone, status)
values
  ('__SUPABASE_SMOKE_ACTIVE',
    (pg_catalog.now() at time zone 'Asia/Singapore')::date + 3650,
    array['06:00'], 'Uji', '080000000000', 'pending'),
  ('__SUPABASE_SMOKE_PENDING',
    (pg_catalog.now() at time zone 'Asia/Singapore')::date + 3650,
    array['07:00'], 'Uji', '080000000000', 'pending'),
  ('__SUPABASE_SMOKE_PAST',
    (pg_catalog.now() at time zone 'Asia/Singapore')::date - 3650,
    array['06:00'], 'Uji', '080000000000', 'confirmed');

-- Anon: tidak dapat membaca data maupun memanggil fungsi admin.
set local role anon;
do $$
begin
  begin
    perform 1 from public.bookings;
    raise exception 'GAGAL: anon dapat membaca bookings.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.is_booking_admin();
    raise exception 'GAGAL: anon dapat memanggil fungsi admin.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.set_booking_status('__SUPABASE_SMOKE_ACTIVE', 'confirmed');
    raise exception 'GAGAL: anon dapat memanggil RPC status.';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Pengguna biasa: memakai sub acak yang tidak ada pada booking_admins.
select pg_catalog.set_config('request.jwt.claims', '{}', true);
select pg_catalog.set_config('request.jwt.claim.sub', pg_catalog.gen_random_uuid()::text, true);
set local role authenticated;
do $$
begin
  if public.is_booking_admin() then
    raise exception 'GAGAL: pengguna biasa dianggap admin.';
  end if;
  if exists (select 1 from public.bookings)
     or exists (select 1 from public.booking_admins) then
    raise exception 'GAGAL: RLS membocorkan booking atau daftar admin.';
  end if;
  begin
    perform public.set_booking_status('__SUPABASE_SMOKE_ACTIVE', 'confirmed');
    raise exception 'GAGAL: pengguna biasa dapat mengubah status.';
  exception when sqlstate 'PT403' then null;
  end;
  begin
    insert into public.booking_admins (user_id) values (auth.uid());
    raise exception 'GAGAL: pengguna dapat memberi dirinya hak admin.';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Admin: bisa membaca semua booking, tetapi hanya baris keanggotaannya sendiri.
select pg_catalog.set_config(
  'request.jwt.claim.sub', pg_catalog.current_setting('booking_smoke.admin_id'), true
);
set local role authenticated;
do $$
declare
  actual public.bookings;
begin
  if not public.is_booking_admin() then
    raise exception 'GAGAL: akun yang ditunjuk tidak dianggap admin.';
  end if;
  if (select pg_catalog.count(*) from public.bookings
      where id like '__SUPABASE_SMOKE_%') <> 3 then
    raise exception 'GAGAL: admin tidak dapat membaca fixture.';
  end if;
  if (select pg_catalog.count(*) from public.booking_admins) <> 1 then
    raise exception 'GAGAL: admin dapat membaca keanggotaan milik akun lain.';
  end if;
  begin
    update public.bookings set status = 'cancelled'
      where id = '__SUPABASE_SMOKE_ACTIVE';
    raise exception 'GAGAL: admin dapat melewati RPC memakai UPDATE langsung.';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.bookings where id = '__SUPABASE_SMOKE_ACTIVE';
    raise exception 'GAGAL: admin dapat menghapus booking langsung.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.booking_slots;
    raise exception 'GAGAL: aplikasi dapat mengakses tabel slot internal.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.set_booking_status('__SUPABASE_SMOKE_ACTIVE', 'pending');
    raise exception 'GAGAL: status tujuan tidak valid diterima.';
  exception when sqlstate 'PT400' then null;
  end;
  begin
    perform public.set_booking_status('__SUPABASE_SMOKE_MISSING', 'confirmed');
    raise exception 'GAGAL: booking tidak ditemukan diterima.';
  exception when sqlstate 'PT404' then null;
  end;
  begin
    perform public.set_booking_status('__SUPABASE_SMOKE_PAST', 'cancelled');
    raise exception 'GAGAL: booking lampau dapat diubah.';
  exception when sqlstate 'PT409' then null;
  end;

  select * into actual
    from public.set_booking_status('__SUPABASE_SMOKE_ACTIVE', 'confirmed');
  if actual.id <> '__SUPABASE_SMOKE_ACTIVE' or actual.status <> 'confirmed' then
    raise exception 'GAGAL: konfirmasi tidak mengembalikan booking yang sesuai.';
  end if;
  begin
    perform public.set_booking_status('__SUPABASE_SMOKE_ACTIVE', 'confirmed');
    raise exception 'GAGAL: konfirmasi berulang diterima.';
  exception when sqlstate 'PT409' then null;
  end;

  -- pending -> cancelled juga diizinkan.
  select * into actual
    from public.set_booking_status('__SUPABASE_SMOKE_PENDING', 'cancelled');
  if actual.status <> 'cancelled' then
    raise exception 'GAGAL: pembatalan pending tidak disimpan.';
  end if;
end;
$$;
reset role;

-- Bentrok harus ditolak oleh database, termasuk penulisan server tepercaya.
do $$
begin
  begin
    insert into public.bookings
      (id, date, hours, customer_name, customer_phone)
      select '__SUPABASE_SMOKE_CONFLICT', date, hours, 'Uji', '080000000000'
      from public.bookings where id = '__SUPABASE_SMOKE_ACTIVE';
    raise exception 'GAGAL: dua booking aktif dapat memakai slot sama.';
  exception when sqlstate 'PT409' then null;
  end;
  begin
    insert into public.bookings
      (id, date, hours, customer_name, customer_phone)
      values ('__SUPABASE_SMOKE_INVALID', current_date + 3650,
        array['08:30'], 'Uji', '080000000000');
    raise exception 'GAGAL: jam pecahan diterima.';
  exception when sqlstate 'PT400' then null;
  end;
  begin
    insert into public.bookings
      (id, date, hours, customer_name, customer_phone)
      values ('__SUPABASE_SMOKE_INVALID', current_date + 3650,
        array['08:00', '08:00'], 'Uji', '080000000000');
    raise exception 'GAGAL: jam duplikat diterima.';
  exception when sqlstate 'PT400' then null;
  end;
  if exists (select 1 from public.bookings
      where id in ('__SUPABASE_SMOKE_CONFLICT', '__SUPABASE_SMOKE_INVALID')) then
    raise exception 'GAGAL: operasi gagal meninggalkan booking parsial.';
  end if;
end;
$$;

set local role authenticated;
select public.set_booking_status('__SUPABASE_SMOKE_ACTIVE', 'cancelled');
do $$
begin
  begin
    perform public.set_booking_status('__SUPABASE_SMOKE_ACTIVE', 'confirmed');
    raise exception 'GAGAL: booking dibatalkan dapat diaktifkan kembali.';
  exception when sqlstate 'PT409' then null;
  end;
end;
$$;
reset role;

-- Pembatalan harus melepaskan slot untuk booking baru.
insert into public.bookings
  (id, date, hours, customer_name, customer_phone)
  select '__SUPABASE_SMOKE_REUSE', date, hours, 'Uji', '080000000000'
  from public.bookings where id = '__SUPABASE_SMOKE_ACTIVE';
do $$
begin
  if exists (select 1 from public.booking_slots
      where booking_id in ('__SUPABASE_SMOKE_ACTIVE', '__SUPABASE_SMOKE_PENDING'))
     or (select pg_catalog.count(*) from public.booking_slots
      where booking_id = '__SUPABASE_SMOKE_REUSE') <> 1 then
    raise exception 'GAGAL: slot tidak dilepas/dipakai kembali dengan benar.';
  end if;
end;
$$;

rollback;
select 'Smoke test selesai; semua fixture dan perubahan dibatalkan.' as hasil;
