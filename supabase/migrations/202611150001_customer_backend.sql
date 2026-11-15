-- Apply AFTER 202611020001. One field; times use Asia/Singapore.
begin;
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 100),
  phone text not null check (phone ~ '^\+?[0-9]{9,15}$')
);
create table public.venue_settings (
  id boolean primary key default true check (id),
  day_price integer not null check (day_price between 1 and 10000000),
  night_price integer not null check (night_price between 1 and 10000000),
  bank_name text not null default '',
  bank_account text not null default '',
  bank_holder text not null default ''
);
insert into public.venue_settings(id, day_price, night_price) values(true,250000,350000);
create table public.closed_slots (
  date date not null,
  hour text not null check (hour = any(array['08:00','09:00','10:00','11:00','13:00','14:00','15:00','16:00','19:00','20:00','21:00','22:00'])),
  primary key(date,hour)
);
alter table public.bookings add column request_id uuid unique;
-- User deletion must not leave customer names/phones on detached bookings.
alter table public.bookings drop constraint bookings_customer_id_fkey;
alter table public.bookings add constraint bookings_customer_id_fkey
  foreign key(customer_id) references auth.users(id) on delete cascade;
alter table public.bookings add column payment_path text;
alter table public.bookings add column payment_status text not null default 'unpaid'
  check (payment_status in ('unpaid','submitted','approved','rejected'));
alter table public.bookings add column payment_note text not null default '';
create index bookings_customer_idx on public.bookings(customer_id,date desc);
alter table public.profiles enable row level security;
alter table public.venue_settings enable row level security;
alter table public.closed_slots enable row level security;
-- Keep PUBLIC in its own statement for Dashboard SQL parser compatibility.
revoke all privileges on table public.profiles,public.venue_settings,public.closed_slots from public;
revoke all privileges on table public.profiles,public.venue_settings,public.closed_slots from anon;
revoke all privileges on table public.profiles,public.venue_settings,public.closed_slots from authenticated;
grant select on public.profiles,public.venue_settings to authenticated;
grant insert,update(name,phone) on public.profiles to authenticated;
grant update(day_price,night_price,bank_name,bank_account,bank_holder) on public.venue_settings to authenticated;
create policy profiles_read on public.profiles for select to authenticated using (id = (select auth.uid()) or (select public.is_booking_admin()));
create policy profiles_insert on public.profiles for insert to authenticated with check(id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated using(id = (select auth.uid())) with check(id = (select auth.uid()));
create policy settings_read on public.venue_settings for select to authenticated using(true);
create policy settings_update on public.venue_settings for update to authenticated using((select public.is_booking_admin())) with check((select public.is_booking_admin()));
create policy bookings_read_customer on public.bookings for select to authenticated using(customer_id = (select auth.uid()));

-- All creation and closure operations share a transaction advisory lock per day.
-- This also serializes closure vs booking creation, not just booking vs booking.
create function public.get_availability(p_date date)
returns table(hour text, closed boolean, occupied boolean)
language sql stable security definer set search_path = '' as $$
 select h, exists(select 1 from public.closed_slots c where c.date=p_date and c.hour=h),
 exists(select 1 from public.booking_slots s where s.date=p_date and s.hour=h)
 from unnest(array['08:00','09:00','10:00','11:00','13:00','14:00','15:00','16:00','19:00','20:00','21:00','22:00']) h
 where auth.uid() is not null;
$$;
create function public.create_booking(p_date date,p_hours text[],p_request_id uuid)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare b public.bookings; p public.profiles; s public.venue_settings;
begin
 if auth.uid() is null then raise sqlstate 'PT401' using message='Silakan login terlebih dahulu.'; end if;
 if public.account_deletion_pending() then raise sqlstate 'PT403' using message='Penghapusan akun sedang diproses.'; end if;
 if p_request_id is null or p_date is null or p_date < (now() at time zone 'Asia/Singapore')::date
 or p_date > (now() at time zone 'Asia/Singapore')::date + 365 then
 raise sqlstate 'PT400' using message='Tanggal booking tidak valid.'; end if;
 perform pg_advisory_xact_lock(15001, p_date - date '2000-01-01');
 select * into b from public.bookings where request_id=p_request_id;
 if found then
   if b.customer_id <> auth.uid() or b.date <> p_date or b.hours <> p_hours then
    raise sqlstate 'PT409' using message='Permintaan booking tidak sesuai.';
   end if;
   return b;
 end if;
 if array_ndims(p_hours) is distinct from 1 or cardinality(p_hours) not between 1 and 12
 or cardinality(p_hours) <> (select count(distinct h) from unnest(p_hours) h)
 or exists(select 1 from unnest(p_hours) h where h is null or h <> all(array['08:00','09:00','10:00','11:00','13:00','14:00','15:00','16:00','19:00','20:00','21:00','22:00'])) then
 raise sqlstate 'PT400' using message='Jam booking tidak valid.'; end if;
 if exists(select 1 from unnest(p_hours) h where (p_date + h::time) <= (now() at time zone 'Asia/Singapore')) then
 raise sqlstate 'PT409' using message='Jam tersebut sudah lewat.'; end if;
 if exists(select 1 from public.closed_slots c where c.date=p_date and c.hour=any(p_hours)) then
 raise sqlstate 'PT409' using message='Slot ditutup pengelola.'; end if;
 select * into p from public.profiles where id=auth.uid();
 if not found then raise sqlstate 'PT400' using message='Lengkapi profil terlebih dahulu.'; end if;
 select * into strict s from public.venue_settings where id=true;
 if s.bank_name='' or s.bank_account='' or s.bank_holder='' then
 raise sqlstate 'PT409' using message='Rekening pembayaran belum disiapkan pengelola.'; end if;
 insert into public.bookings(id,customer_id,date,hours,customer_name,customer_phone,day_price,night_price,request_id)
 values('SB-' || gen_random_uuid()::text,auth.uid(),p_date,p_hours,p.name,p.phone,s.day_price,s.night_price,p_request_id)
 returning * into b;
 return b;
end; $$;

create function public.set_slot_closed(p_date date,p_hour text,p_closed boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_booking_admin() then raise sqlstate 'PT403' using message='Akses admin diperlukan.'; end if;
 if p_date is null or p_date < (now() at time zone 'Asia/Singapore')::date or p_closed is null then
 raise sqlstate 'PT400' using message='Tanggal tidak valid.'; end if;
 perform pg_advisory_xact_lock(15001,p_date-date '2000-01-01');
 if exists(select 1 from public.booking_slots where date=p_date and hour=p_hour) then
 raise sqlstate 'PT409' using message='Slot sudah dipesan.'; end if;
 if p_closed then insert into public.closed_slots values(p_date,p_hour) on conflict do nothing;
 else delete from public.closed_slots where date=p_date and hour=p_hour; end if;
end; $$;

create function public.cancel_customer_booking(p_booking_id text)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare b public.bookings;
begin
 select * into b from public.bookings where id=p_booking_id and customer_id=auth.uid() for update;
 if not found then raise sqlstate 'PT404' using message='Booking tidak ditemukan.'; end if;
 if b.status='cancelled' then return b; end if;
 if b.status<>'pending' or b.payment_status='submitted' or b.date < (now() at time zone 'Asia/Singapore')::date then
 raise sqlstate 'PT409' using message='Hubungi pengelola untuk pembatalan booking ini.'; end if;
 update public.bookings set status='cancelled' where id=b.id returning * into b;
 return b;
end; $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('payment-proofs','payment-proofs',false,5242880,array['image/jpeg','image/png']);
create policy proof_insert on storage.objects for insert to authenticated with check(
 bucket_id='payment-proofs' and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists(select 1 from public.bookings b where b.id=(storage.foldername(name))[2]
 and b.customer_id=(select auth.uid()) and b.status='pending' and b.payment_status in ('unpaid','rejected')));
create policy proof_read on storage.objects for select to authenticated using(
 bucket_id='payment-proofs' and ((storage.foldername(name))[1]=(select auth.uid())::text or (select public.is_booking_admin())));

create function public.submit_payment(p_booking_id text,p_path text)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare b public.bookings;
begin
 select * into b from public.bookings where id=p_booking_id and customer_id=auth.uid() for update;
 if not found then raise sqlstate 'PT404' using message='Booking tidak ditemukan.'; end if;
 if b.payment_path=p_path and b.payment_status='submitted' then return b; end if;
 if b.status<>'pending' or b.payment_status not in ('unpaid','rejected') then raise sqlstate 'PT409' using message='Bukti sudah dikirim atau booking tidak aktif.'; end if;
 if p_path is null or split_part(p_path,'/',1)<>auth.uid()::text or split_part(p_path,'/',2)<>b.id
 or not exists(select 1 from storage.objects where bucket_id='payment-proofs' and name=p_path) then
 raise sqlstate 'PT400' using message='Bukti pembayaran tidak ditemukan.'; end if;
 update public.bookings set payment_path=p_path,payment_status='submitted',payment_note='' where id=b.id returning * into b;
 return b;
end; $$;

create function public.review_payment(p_booking_id text,p_approve boolean,p_note text default '')
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare b public.bookings;
begin
 if not public.is_booking_admin() then raise sqlstate 'PT403' using message='Akses admin diperlukan.'; end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then raise sqlstate 'PT404' using message='Booking tidak ditemukan.'; end if;
 if p_approve is null or b.status<>'pending' or b.payment_status<>'submitted' then
 raise sqlstate 'PT409' using message='Bukti tidak menunggu verifikasi.'; end if;
 if not p_approve and length(btrim(coalesce(p_note,'')))=0 then raise sqlstate 'PT400' using message='Isi alasan penolakan.'; end if;
 update public.bookings set payment_status=case when p_approve then 'approved' else 'rejected' end,
 status=case when p_approve then 'confirmed' else 'pending' end,payment_note=left(coalesce(p_note,''),500)
 where id=b.id returning * into b;
 return b;
end; $$;

-- Block the legacy status RPC from bypassing payment verification.
create function public.guard_payment_confirmation() returns trigger
language plpgsql set search_path = '' as $$
begin
 if new.status='confirmed' and old.status<>'confirmed' and new.customer_id is not null and new.payment_status<>'approved' then
 raise sqlstate 'PT409' using message='Verifikasi bukti pembayaran terlebih dahulu.'; end if;
 return new;
end; $$;
create trigger payment_confirmation_guard before update on public.bookings for each row execute function public.guard_payment_confirmation();

-- Request is durable; a trusted worker removes storage through the Storage API,
-- then Auth. Never delete storage.objects directly (that leaves orphan files).
create table public.account_deletion_requests (
 user_id uuid primary key references auth.users(id) on delete cascade,
 requested_at timestamptz not null default now()
);
alter table public.account_deletion_requests enable row level security;
revoke all privileges on table public.account_deletion_requests from public;
revoke all privileges on table public.account_deletion_requests from anon;
revoke all privileges on table public.account_deletion_requests from authenticated;
create function public.request_account_deletion() returns void
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise sqlstate 'PT401' using message='Silakan login.'; end if;
 if public.is_booking_admin() then raise sqlstate 'PT409' using message='Alihkan hak admin melalui pengelola sebelum menghapus akun.'; end if;
 insert into public.account_deletion_requests(user_id) values(auth.uid()) on conflict do nothing;
end; $$;

create function public.account_deletion_pending() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.account_deletion_requests where user_id=auth.uid());
$$;
revoke all privileges on function public.account_deletion_pending() from public;
revoke all privileges on function public.account_deletion_pending() from anon;
revoke all privileges on function public.account_deletion_pending() from authenticated;
grant execute on function public.account_deletion_pending() to authenticated;
alter policy proof_insert on storage.objects with check(
 bucket_id='payment-proofs' and not public.account_deletion_pending()
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists(select 1 from public.bookings b where b.id=(storage.foldername(name))[2]
 and b.customer_id=(select auth.uid()) and b.status='pending' and b.payment_status in ('unpaid','rejected')));

revoke all privileges on function public.get_availability(date),public.create_booking(date,text[],uuid),public.set_slot_closed(date,text,boolean),public.cancel_customer_booking(text),public.submit_payment(text,text),public.review_payment(text,boolean,text),public.request_account_deletion(),public.guard_payment_confirmation() from public;
revoke all privileges on function public.get_availability(date),public.create_booking(date,text[],uuid),public.set_slot_closed(date,text,boolean),public.cancel_customer_booking(text),public.submit_payment(text,text),public.review_payment(text,boolean,text),public.request_account_deletion(),public.guard_payment_confirmation() from anon;
revoke all privileges on function public.get_availability(date),public.create_booking(date,text[],uuid),public.set_slot_closed(date,text,boolean),public.cancel_customer_booking(text),public.submit_payment(text,text),public.review_payment(text,boolean,text),public.request_account_deletion(),public.guard_payment_confirmation() from authenticated;
grant execute on function public.get_availability(date),public.create_booking(date,text[],uuid),public.set_slot_closed(date,text,boolean),public.cancel_customer_booking(text),public.submit_payment(text,text),public.review_payment(text,boolean,text),public.request_account_deletion() to authenticated;
notify pgrst,'reload schema';
commit;
