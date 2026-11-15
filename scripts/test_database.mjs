// npm install --prefix build/db-tools embedded-postgres pg --no-audit --no-fund
// node scripts/test_database.mjs
// Real temporary PostgreSQL, with minimal Auth/Storage schema stubs.
// Does not connect to Supabase or test its HTTP/Auth/Storage services.
import EmbeddedPostgres from '../build/db-tools/node_modules/embedded-postgres/dist/index.js';
import { readFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { createServer } from 'node:net';

const folder = resolve('build/db-tests', `run-${Date.now()}`);
await mkdir(folder, { recursive: true });
const probe = createServer();
await new Promise(done=>probe.listen(0,'127.0.0.1',done));
const port=probe.address().port;
await new Promise(done=>probe.close(done));
const pg = new EmbeddedPostgres({ databaseDir: folder, port, user: 'postgres', password: 'local-test-only', persistent: true,
  postgresFlags: ['-h', '127.0.0.1'], onLog: () => {}, onError: e=>console.error(e) });
const clients = [];
let started = false;
const user = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';
const admin = '10000000-0000-4000-8000-000000000003';
let checks = 0;
async function rejects(query, code) {
  await assert.rejects(query, e => e.code === code); checks++;
}
try {
  await pg.initialise(); await pg.start(); started = true;
  const root = pg.getPgClient(); await root.connect(); clients.push(root);
  await root.query(`
    create role anon nologin; create role authenticated nologin;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,storage,public to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,primary key(bucket_id,name));
    alter table storage.objects enable row level security;
    grant select,insert on storage.objects to authenticated;
    create function storage.foldername(text) returns text[] language sql immutable as $$ select (string_to_array($1,'/'))[1:array_length(string_to_array($1,'/'),1)-1] $$;
  `);
  for (const file of ['202611020001_booking_backend.sql', '202611150001_customer_backend.sql']) {
    await root.query(await readFile(resolve('supabase/migrations', file), 'utf8'));
  }
  checks += 2;
  await root.query('insert into auth.users values($1),($2),($3)', [user,other,admin]);
  await root.query('insert into public.booking_admins values($1)',[admin]);
  await root.query(await readFile('supabase/tests/booking_smoke.sql','utf8')); checks++;
  await root.query("update public.venue_settings set bank_name='Test',bank_account='123',bank_holder='Test'");
  async function asUser(id) {
    const c=pg.getPgClient();await c.connect();clients.push(c);
    await c.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);
    await c.query('set role authenticated'); return c;
  }
  const a=await asUser(user), b=await asUser(other), owner=await asUser(admin);
  await a.query('insert into public.profiles values($1,$2,$3)',[user,'Player A','081234567890']);
  await b.query('insert into public.profiles values($1,$2,$3)',[other,'Player B','081234567891']);
  await rejects(a.query('insert into public.profiles values($1,$2,$3)',[admin,'Intruder','081234567899']),'42501');
  assert.equal((await b.query('select * from public.profiles where id=$1',[user])).rowCount,0);checks++;
  assert.equal((await a.query('update public.venue_settings set day_price=1 returning *')).rowCount,0);checks++;
  const date=(await root.query("select ((now() at time zone 'Asia/Singapore')::date+2)::text d")).rows[0].d;
  const rpc='select * from public.create_booking($1,$2,$3)';
  const key='20000000-0000-4000-8000-000000000001';
  const created=(await a.query(rpc,[date,['08:00'],key])).rows[0];checks++;
  assert.equal(created.customer_id,user); assert.equal(created.day_price,250000);checks+=2;
  assert.equal((await a.query(rpc,[date,['08:00'],key])).rows[0].id,created.id);checks++;
  await rejects(b.query(rpc,[date,['08:00'],'20000000-0000-4000-8000-000000000002']),'PT409');
  assert.equal((await b.query('select * from public.bookings')).rowCount,0);checks++;
  await rejects(a.query("update public.bookings set status='confirmed' where id=$1",[created.id]),'42501');
  await rejects(a.query("select public.set_booking_status($1,'confirmed')",[created.id]),'PT403');
  await rejects(owner.query("select public.set_booking_status($1,'confirmed')",[created.id]),'PT409');
  await owner.query('select public.set_slot_closed($1,$2,true)',[date,'09:00']);
  await rejects(a.query(rpc,[date,['09:00'],'20000000-0000-4000-8000-000000000003']),'PT409');
  await rejects(a.query(rpc,[date,['12:00'],'20000000-0000-4000-8000-000000000004']),'PT400');
  await rejects(a.query(rpc,[date,['10:00','10:00'],'20000000-0000-4000-8000-000000000005']),'PT400');
  await rejects(a.query('select public.set_slot_closed($1,$2,true)',[date,'10:00']),'PT403');
  const availability=await b.query('select * from public.get_availability($1)',[date]);
  assert.equal(availability.rows.find(r=>r.hour==='08:00').occupied,true);checks++;
  assert.equal(availability.rows.find(r=>r.hour==='09:00').closed,true);checks++;
  assert.deepEqual(Object.keys(availability.rows[0]).sort(),['closed','hour','occupied']);checks++;
  // Storage ownership and submit/review transitions.
  const path=`${user}/${created.id}/proof.jpg`;
  await rejects(b.query('insert into storage.objects(bucket_id,name) values($1,$2)',['payment-proofs',path]),'42501');
  await a.query('insert into storage.objects(bucket_id,name) values($1,$2)',['payment-proofs',path]);
  assert.equal((await b.query('select * from storage.objects')).rowCount,0);checks++;
  const submitted=(await a.query('select * from public.submit_payment($1,$2)',[created.id,path])).rows[0];
  assert.equal(submitted.status,'pending');assert.equal(submitted.payment_status,'submitted');checks+=2;
  await rejects(a.query('select public.review_payment($1,true,\'\')',[created.id]),'PT403');
  await rejects(a.query('select public.cancel_customer_booking($1)',[created.id]),'PT409');
  await rejects(owner.query('select public.review_payment($1,false,\'\')',[created.id]),'PT400');
  const rejected=(await owner.query('select * from public.review_payment($1,false,$2)',[created.id,'Nominal tidak sesuai'])).rows[0];
  assert.equal(rejected.payment_status,'rejected');checks++;
  await a.query('select public.submit_payment($1,$2)',[created.id,path]);
  const approved=(await owner.query('select * from public.review_payment($1,true,\'\')',[created.id])).rows[0];
  assert.equal(approved.status,'confirmed');assert.equal(approved.payment_status,'approved');checks+=2;
  // Two connections competing for one slot: exactly one succeeds.
  const results=await Promise.allSettled([
    a.query(rpc,[date,['11:00'],'20000000-0000-4000-8000-000000000006']),
    b.query(rpc,[date,['11:00'],'20000000-0000-4000-8000-000000000007'])
  ]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);checks++;
  const loser=results.find(r=>r.status==='rejected');assert.equal(loser.reason.code,'PT409');checks++;
  await a.query('select public.request_account_deletion()');
  assert.equal((await root.query('select * from public.account_deletion_requests')).rowCount,1);checks++;
  await rejects(a.query(rpc,[date,['13:00'],'20000000-0000-4000-8000-000000000008']),'PT403');
  await rejects(owner.query('select public.request_account_deletion()'),'PT409');
  // Auth deletion cascades personal booking data, including slot reservations.
  await root.query('delete from auth.users where id=$1',[user]);
  assert.equal((await root.query('select * from public.bookings where customer_id=$1',[user])).rowCount,0);checks++;
  assert.equal((await root.query('select * from public.booking_slots where booking_id=$1',[created.id])).rowCount,0);checks++;
  console.log(`PASS: ${checks} database checks, original smoke suite, migrations, RLS, private proof policies, payment review, and concurrent slot conflict.`);
} finally {
  for(const client of clients) await client.end().catch(()=>{});
  if(started) await pg.stop();
}
