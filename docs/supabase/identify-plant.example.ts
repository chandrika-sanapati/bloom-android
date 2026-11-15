// Deploy as a Supabase Edge Function named `identify-plant`.
// Required secret: PLANTNET_API_KEY
// This function intentionally does not persist raw images.

const MAX_IMAGES = 5;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function allowedImage(contentType: string | null): boolean {
  return contentType === 'image/jpeg' || contentType === 'image/png';
}

function normalizeCandidate(value: Record<string, unknown>) {
  const species = value.species;
  if (!species || typeof species !== 'object') return null;
  const item = species as Record<string, unknown>;
  const scientific = item.scientificNameWithoutAuthor;
  if (typeof scientific !== 'string' || scientific.trim().length === 0) return null;
  const commonNames = Array.isArray(item.commonNames)
    ? item.commonNames.filter((name): name is string => typeof name === 'string')
    : [];
  const gbif = value.gbif;
  const powo = value.powo;
  return {
    scientificName: scientific,
    commonNames,
    score: typeof value.score === 'number' ? value.score : 0,
    gbifId: gbif && typeof gbif === 'object' ? String((gbif as Record<string, unknown>).id ?? '') : null,
    powoId: powo && typeof powo === 'object' ? String((powo as Record<string, unknown>).id ?? '') : null,
  };
}

export default async function handler(request: Request): Promise<Response> {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'Authentication required' }, 401);

  // Supabase Edge Functions can enforce JWT verification with verify_jwt=true.
  // Keep the explicit header check here as a clear boundary for local testing.
  const apiKey = Deno.env.get('PLANTNET_API_KEY');
  if (!apiKey) return json({ error: 'Plant identification is not configured' }, 503);

  let form: FormData;
  try {
    form = await request.formData();
  } catch (_) {
    return json({ error: 'Send one or more JPEG or PNG images' }, 400);
  }

  const images = form.getAll('images');
  if (images.length < 1 || images.length > MAX_IMAGES) {
    return json({ error: `Send between one and ${MAX_IMAGES} images of the same plant` }, 400);
  }

  const plantNet = new FormData();
  for (const value of images) {
    if (!(value instanceof File) || !allowedImage(value.type) || value.size > MAX_IMAGE_BYTES) {
      return json({ error: 'Each image must be a JPEG or PNG under 10 MB' }, 400);
    }
    plantNet.append('images', value, value.name);
    plantNet.append('organs', 'auto');
  }

  const response = await fetch(
    `https://my-api.plantnet.org/v2/identify/all?api-key=${encodeURIComponent(apiKey)}&nb-results=5`,
    { method: 'POST', body: plantNet },
  );
  if (!response.ok) {
    return json({ error: 'Plant identification is temporarily unavailable' }, response.status === 429 ? 429 : 502);
  }

  const result = await response.json() as Record<string, unknown>;
  const candidates = Array.isArray(result.results)
    ? result.results.map((value) => value && typeof value === 'object' ? normalizeCandidate(value as Record<string, unknown>) : null).filter(Boolean)
    : [];
  return json({
    candidates,
    version: result.version,
    remainingIdentificationRequests: result.remainingIdentificationRequests,
  });
}
