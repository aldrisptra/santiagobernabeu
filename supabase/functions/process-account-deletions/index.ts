// Invoke only from a trusted scheduler/operator. Never put WORKER_SECRET or
// SUPABASE_SERVICE_ROLE_KEY in Flutter. Each step is retryable after failures.
import { createClient } from 'npm:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  const secret = Deno.env.get('WORKER_SECRET');
  if (!secret || req.headers.get('authorization') !== `Bearer ${secret}`) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: requests, error } = await client.from('account_deletion_requests').select('user_id').order('requested_at').limit(20);
  if (error) return Response.json({ error: 'Cannot load deletion requests' }, { status: 500 });
  let completed = 0;
  const failed: string[] = [];
  for (const { user_id: id } of requests ?? []) {
    try {
      // Defend against an account becoming an admin after its request.
      const { data: admin, error: roleError } = await client.from('booking_admins').select('user_id').eq('user_id', id).maybeSingle();
      if (roleError || admin) throw new Error('Admin removal requires operator');
      const bucket = client.storage.from('payment-proofs');
      // Objects live at user/booking/file; repeatedly remove first page.
      while (true) {
        const { data: folders, error: folderError } = await bucket.list(id, { limit: 100 });
        if (folderError) throw folderError;
        if (!folders?.length) break;
        for (const folder of folders) {
          const prefix = `${id}/${folder.name}`;
          while (true) {
            const { data: files, error: listError } = await bucket.list(prefix, { limit: 100 });
            if (listError) throw listError;
            if (!files?.length) break;
            const { error: removeError } = await bucket.remove(files.map(f => `${prefix}/${f.name}`));
            if (removeError) throw removeError;
          }
        }
      }
      const { error: bookingError } = await client.from('bookings').delete().eq('customer_id', id);
      if (bookingError) throw bookingError;
      const { error: authError } = await client.auth.admin.deleteUser(id);
      if (authError) throw authError;
      completed++;
    } catch { failed.push(id); }
  }
  return Response.json({ completed, failed }, { status: failed.length ? 207 : 200 });
});
