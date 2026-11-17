function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

async function handler(request: Request): Promise<Response> {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return json({ error: 'Authentication required' }, 401);
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) return json({ error: 'Sync is not configured' }, 503);

  let body: { expectedRevision?: number | null; payload?: Record<string, unknown> };
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: 'Invalid sync payload' }, 400);
  }
  if (!body.payload || typeof body.payload !== 'object') return json({ error: 'Invalid sync payload' }, 400);

  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/sync_plant_collection`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: authorization,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      p_expected_revision: body.expectedRevision ?? null,
      p_payload: body.payload,
    }),
  });
  if (!response.ok) return json({ error: 'Collection sync failed' }, 502);
  const result = await response.json() as Array<{ applied: boolean; revision: number }>;
  const row = result[0];
  if (!row?.applied) return json({ applied: false, revision: row?.revision ?? 0 }, 409);
  return json({ applied: true, revision: row.revision });
}

Deno.serve(handler);
