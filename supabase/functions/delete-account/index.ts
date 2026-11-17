function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

async function handler(request: Request): Promise<Response> {
  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return json({ error: 'Authentication required' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Account deletion is not configured' }, 503);
  }

  const headers = {
    apikey: serviceRoleKey,
    Authorization: authorization,
  };
  const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers,
  });
  if (!userResponse.ok) return json({ error: 'Authentication required' }, 401);

  const user = await userResponse.json() as { id?: string };
  if (!user.id) return json({ error: 'Authenticated user was not found' }, 401);

  const gardenResponse = await fetch(
    `${supabaseUrl}/rest/v1/gardens?user_id=eq.${encodeURIComponent(user.id)}`,
    {
      method: 'DELETE',
      headers: {
        ...headers,
        Prefer: 'return=minimal',
      },
    },
  );
  if (!gardenResponse.ok) {
    return json({ error: 'Cloud garden could not be deleted' }, 502);
  }

  const accountResponse = await fetch(
    `${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(user.id)}`,
    { method: 'DELETE', headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` } },
  );
  if (!accountResponse.ok) {
    return json({ error: 'Account could not be deleted' }, 502);
  }

  return json({ deleted: true });
}

Deno.serve(handler);
