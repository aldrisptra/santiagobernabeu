-- Jalankan melalui Supabase SQL Editor sebagai postgres.
-- Hanya mengganti nama pelanggan pada tiga booking demo yang sudah ada.
update public.bookings
set customer_name = case id
  when 'DEMO-005' then 'Andi Pratama'
  when 'DEMO-006' then 'Rizky Ramadhan'
  when 'DEMO-007' then 'Fajar Maulana'
end
where id in ('DEMO-005', 'DEMO-006', 'DEMO-007')
returning id, customer_name, status;
