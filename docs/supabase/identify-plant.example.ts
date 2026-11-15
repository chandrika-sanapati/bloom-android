// Architecture-only Edge Function example.
// The production implementation must validate the JWT, request body, image
// limits, rate limits, and PlantNet response before returning candidates.

export default async function identifyPlant(request: Request): Promise<Response> {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  // TODO: verify the Supabase JWT with the Edge Function runtime.
  // TODO: accept one to five JPEG/PNG images of the same plant.
  // TODO: call PlantNet with Deno.env.get('PLANTNET_API_KEY').
  // TODO: normalize candidates and write a short-lived audit row.
  return Response.json(
    {
      error: 'PlantNet identification is not configured yet.',
      candidates: [],
    },
    { status: 501 },
  );
}
