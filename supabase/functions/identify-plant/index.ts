const MAX_IMAGES = 5;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

function withTimeout<T>(promise: Promise<T>, milliseconds: number, message: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => setTimeout(() => reject(new Error(message)), milliseconds)),
  ]);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function normalizeCandidate(value: Record<string, unknown>) {
  const species = value.species;
  if (!species || typeof species !== 'object') return null;
  const item = species as Record<string, unknown>;
  const scientific = item.scientificNameWithoutAuthor;
  if (typeof scientific !== 'string' || scientific.trim().length === 0) {
    return null;
  }
  const commonNames = Array.isArray(item.commonNames)
    ? item.commonNames.filter((name): name is string => typeof name === 'string')
    : [];
  const gbif = value.gbif;
  const powo = value.powo;
  return {
    scientificName: scientific,
    commonNames,
    score: typeof value.score === 'number' ? value.score : 0,
    gbifId: gbif && typeof gbif === 'object'
      ? String((gbif as Record<string, unknown>).id ?? '')
      : null,
    powoId: powo && typeof powo === 'object'
      ? String((powo as Record<string, unknown>).id ?? '')
      : null,
  };
}

async function handler(request: Request): Promise<Response> {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  // The Supabase function gateway verifies the JWT because config.toml sets
  // verify_jwt=true. Keep a header check here as an additional boundary.
  if (!request.headers.get('authorization')?.startsWith('Bearer ')) {
    return json({ error: 'Authentication required' }, 401);
  }

  const apiKey = Deno.env.get('PLANTNET_API_KEY');
  if (!apiKey) return json({ error: 'Plant identification is not configured' }, 503);

  let form: FormData;
  try {
    form = await withTimeout(request.formData(), 8_000, 'multipart parsing timed out');
  } catch (_) {
    return json({ error: 'Send one or more JPEG or PNG images' }, 400);
  }

  const images = form.getAll('images');
  console.log(`identify-plant: received ${images.length} image part(s)`);
  if (images.length < 1 || images.length > MAX_IMAGES) {
    return json({ error: `Send between one and ${MAX_IMAGES} images of the same plant` }, 400);
  }

  const plantNet = new FormData();
  for (const value of images) {
    if (!(value instanceof File) || !['image/jpeg', 'image/png'].includes(value.type)) {
      return json({ error: 'Each image must be a JPEG or PNG under 10 MB' }, 400);
    }
    if (value.size > MAX_IMAGE_BYTES) {
      return json({ error: 'Each image must be a JPEG or PNG under 10 MB' }, 413);
    }
    plantNet.append('images', value, value.name);
    plantNet.append('organs', 'auto');
  }
  console.log('identify-plant: multipart validated; calling PlantNet');

  let upstream: Response;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  try {
    upstream = await withTimeout(fetch(
      `https://my-api.plantnet.org/v2/identify/all?api-key=${encodeURIComponent(apiKey)}&nb-results=5`,
      { method: 'POST', body: plantNet, signal: controller.signal },
    ), 20_000, 'PlantNet request timed out');
    console.log(`identify-plant: PlantNet returned HTTP ${upstream.status}`);
  } catch (error) {
    console.error(`identify-plant: PlantNet request failed: ${String(error)}`);
    if (error instanceof Error && error.message.includes('timed out')) {
      return json({ error: 'Plant identification provider timed out' }, 504);
    }
    return json({ error: 'Plant identification provider is unavailable' }, 502);
  } finally {
    clearTimeout(timeout);
  }

  if (!upstream.ok) {
    return json({
      error: upstream.status === 429
          ? 'Plant identification quota is exhausted'
          : `PlantNet returned HTTP ${upstream.status}`,
    }, upstream.status === 429 ? 429 : 502);
  }

  try {
    const result = await upstream.json() as Record<string, unknown>;
    const candidates = Array.isArray(result.results)
      ? result.results
          .map((value) => value && typeof value === 'object'
            ? normalizeCandidate(value as Record<string, unknown>)
            : null)
          .filter(Boolean)
      : [];
    return json({
      candidates,
      version: result.version,
      remainingIdentificationRequests: result.remainingIdentificationRequests,
    });
  } catch (_) {
    return json({ error: 'Plant identification returned an invalid result' }, 502);
  }
}

Deno.serve(handler);
