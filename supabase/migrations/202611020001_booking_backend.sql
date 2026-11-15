-- Jalankan sekali pada project Supabase baru melalui SQL Editor sebagai postgres.
-- Seluruh perubahan atomik; tidak menghapus atau mengganti tabel yang sudah ada.
begin;

create table public.bookings (
  id text primary key check (pg_catalog.btrim(id) <> ''),
  customer_id uuid references auth.users (id) on delete set null,
  date date not null,
  hours text[] not null,
  customer_name text not null,
  customer_phone text not null,
  day_price integer not null default 250000 check (day_price >= 0),
  night_price integer not null default 350000 check (night_price >= 0),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  created_at timestamptz not null default pg_catalog.now()
);

create index bookings_date_id_idx on public.bookings (date desc, id);

-- Hanya pemilik project/server tepercaya yang boleh memberi hak admin.
-- Hak admin tidak berasal dari user_metadata atau nilai yang dikirim Flutter.
create table public.booking_admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

-- Satu lapangan: satu pasangan tanggal/jam hanya dapat dimiliki satu booking aktif.
-- Primary key tetap mencegah bentrok ketika request datang bersamaan.
create table public.booking_slots (
  date date not null,
  hour text not null check (hour ~ '^([01][0-9]|2[0-3]):00$'),
  booking_id text not null references public.bookings (id) on delete cascade,
  primary key (date, hour)
);

create index booking_slots_booking_id_idx on public.booking_slots (booking_id);

alter table public.bookings enable row level security;
alter table public.booking_admins enable row level security;
alter table public.booking_slots enable row level security;

revoke all on table public.bookings, public.booking_admins, public.booking_slots
  from public, anon, authenticated;
grant select on table public.bookings, public.booking_admins to authenticated;

create function public.is_booking_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.booking_admins as admins
    where admins.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_booking_admin() from public, anon, authenticated;
grant execute on function public.is_booking_admin() to authenticated;

create policy bookings_select_admin
  on public.bookings for select to authenticated
  using ((select public.is_booking_admin()));

create policy booking_admins_select_self
  on public.booking_admins for select to authenticated
  using (user_id = (select auth.uid()));

-- Tidak ada policy INSERT/UPDATE/DELETE untuk aplikasi, termasuk admin.
-- booking_slots tidak memiliki policy maupun grant akses untuk aplikasi.
create function public.sync_booking_slots()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if pg_catalog.array_ndims(new.hours) is distinct from 1
     or pg_catalog.cardinality(new.hours) = 0
     or exists (
       select 1 from pg_catalog.unnest(new.hours) as selected(hour)
       where selected.hour is null
          or selected.hour !~ '^([01][0-9]|2[0-3]):00$'
     )
     or pg_catalog.cardinality(new.hours) <> (
       select pg_catalog.count(distinct selected.hour)
       from pg_catalog.unnest(new.hours) as selected(hour)
     ) then
    raise sqlstate 'PT400'
      using message = 'Jam booking harus unik, tidak kosong, dan berformat HH:00 (00:00 sampai 23:00).';
  end if;

  delete from public.booking_slots where booking_id = new.id;
  if new.status in ('pending', 'confirmed') then
    insert into public.booking_slots (date, hour, booking_id)
      select new.date, selected.hour, new.id
      from pg_catalog.unnest(new.hours) as selected(hour)
      order by selected.hour;
  end if;
  return new;
exception when unique_violation then
  raise sqlstate 'PT409'
    using message = 'Salah satu jam pada tanggal tersebut sudah dipesan.';
end;
$$;

revoke all on function public.sync_booking_slots() from public, anon, authenticated;

create trigger bookings_sync_slots
  after insert or update of date, hours, status on public.bookings
  for each row execute function public.sync_booking_slots();

create function public.set_booking_status(p_booking_id text, p_status text)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_booking public.bookings;
begin
  if not public.is_booking_admin() then
    raise sqlstate 'PT403'
      using message = 'Akun ini tidak memiliki akses admin booking.';
  end if;

  if p_booking_id is null or pg_catalog.btrim(p_booking_id) = '' then
    raise sqlstate 'PT400' using message = 'Kode booking wajib diisi.';
  end if;
  if p_status is null or p_status not in ('confirmed', 'cancelled') then
    raise sqlstate 'PT400'
      using message = 'Status tujuan harus confirmed atau cancelled.';
  end if;

  -- Kunci baris sebelum memeriksa status agar perubahan bersamaan tidak
  -- mengandalkan hasil baca yang sudah kedaluwarsa.
  select * into selected_booking
    from public.bookings where id = p_booking_id for update;
  if not found then
    raise sqlstate 'PT404' using message = 'Booking tidak ditemukan.';
  end if;
  if selected_booking.date < (
    pg_catalog.now() at time zone 'Asia/Singapore'
  )::date then
    raise sqlstate 'PT409'
      using message = 'Booking yang sudah lewat tidak dapat diubah.';
  end if;
  if not (
    (selected_booking.status = 'pending' and p_status = 'confirmed')
    or (selected_booking.status in ('pending', 'confirmed') and p_status = 'cancelled')
  ) then
    raise sqlstate 'PT409'
      using message = 'Status booking tidak mengizinkan perubahan tersebut.';
  end if;

  update public.bookings set status = p_status
    where id = p_booking_id returning * into selected_booking;
  return selected_booking;
end;
$$;

revoke all on function public.set_booking_status(text, text)
  from public, anon, authenticated;
grant execute on function public.set_booking_status(text, text) to authenticated;

-- Meminta Data API mengenali tabel/fungsi yang baru dibuat.
notify pgrst, 'reload schema';
commit;
