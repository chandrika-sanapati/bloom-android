# Bloom backend and identification plan

**Decision:** Supabase Auth + Postgres + Storage + Edge Functions
**Status:** Architecture approved; project wiring not configured yet
**Last updated:** 15 November 2026

## Goals

- Keep Bloom usable offline and preserve the current local garden behavior.
- Add optional Google sign-in without making an account required for the core watering loop.
- Sync a user's garden, watering history, Soil health history, placement acknowledgment, and preferences after explicit sign-in.
- Proxy PlantNet identification through a server-side Edge Function so the PlantNet API key never ships in the APK.
- Keep user photos private and short-lived unless the user explicitly saves one to their plant.

## Architecture

```text
Flutter Android
  ├─ local GardenRepository (always available)
  ├─ optional Supabase Auth session
  ├─ optional SyncRepository (authenticated only)
  ├─ optional PlantIdentifier client
  │    └─ Supabase Edge Function: identify-plant
  │         └─ PlantNet API (server-side key)
  └─ optional Supabase Storage for user-confirmed plant photos
```

The Flutter app must not call PlantNet directly. The PlantNet key is a secret and must be stored as an Edge Function secret. The mobile app may contain only the Supabase project URL and publishable key.

## Supabase components

### Auth

- Use Supabase Auth with Google provider.
- Native Android Google sign-in supplies an ID token to `signInWithIdToken`.
- Store the Supabase session using the package's secure/session persistence strategy; never store Google client secrets in the app.
- Login is optional. Signed-out users remain local-only.
- Sign-in must offer a clear merge choice when local data exists:
  - **Keep this device's garden and upload it**
  - **Use the cloud garden and replace this device's garden**
  - **Review differences** (later)
- Never silently overwrite local garden data during first sign-in.

### Postgres

Use user-owned rows with Row Level Security enabled:

```sql
profiles
- user_id uuid primary key references auth.users(id)
- created_at timestamptz not null default now()

gardens
- id uuid primary key
- user_id uuid not null references auth.users(id)
- schema_version integer not null
- payload jsonb not null
- revision bigint not null default 0
- updated_at timestamptz not null default now()
- unique(user_id)

identification_runs
- id uuid primary key
- user_id uuid not null references auth.users(id)
- status text not null
- provider text not null default 'plantnet'
- provider_version text
- candidates jsonb not null default '[]'::jsonb
- created_at timestamptz not null default now()
- expires_at timestamptz
```

The first sync implementation may store one versioned garden payload per user rather than normalizing every plant/event immediately. The payload must use the existing local JSON schema and an explicit schema version. Normalized tables can follow after conflict behavior is validated.

RLS requirements:

- A user can select/insert/update only their own profile and garden.
- A user can select only their own identification runs.
- Anonymous/public clients cannot read garden payloads.
- Service-role keys are used only inside trusted Edge Functions, never in Flutter.

### Storage

- Use a private bucket for confirmed user plant photos.
- Object paths must be user-scoped, for example `user_id/plant_id/photo_id.jpg`.
- Storage policies must require `auth.uid()` to match the path owner.
- Identification uploads should not be stored permanently by default. Use an Edge Function multipart request or a short-lived private object with cleanup.
- The UI must explain that a photo is uploaded for identification before sending it.

### Edge Function: `identify-plant`

Responsibilities:

1. Require a valid Supabase JWT.
2. Accept one to five JPEG/PNG images of the same plant.
3. Validate MIME type, size, image count, and request rate.
4. Call `https://my-api.plantnet.org/v2/identify/all` with the server-side PlantNet API key.
5. Request a bounded candidate list, such as `nb-results=5`, and `organs=auto` unless the user later selects an organ.
6. Normalize only the safe candidate fields needed by the app:
   - scientific name
   - common names
   - confidence score
   - provider/model version
   - optional GBIF/POWO IDs
7. Store a short-lived identification audit row without retaining raw images by default.
8. Return candidates with an explicit `possible matches` meaning.

The function must never return a diagnosis, watering recommendation, or confidence claim beyond PlantNet's candidate score. Rate-limit by authenticated user and handle PlantNet quota exhaustion with a retryable in-app state.

## Flutter seams

Add these interfaces before wiring a provider:

```dart
abstract interface class PlantIdentifier {
  Future<PlantIdentificationResult> identify(List<XFile> photos);
}

abstract interface class GardenSyncRepository {
  Future<RemoteGardenState?> load();
  Future<void> save(Garden garden, {required int expectedRevision});
}
```

The current local store remains the source used by the UI. Remote sync should be an explicit application service that coordinates local persistence, authentication, upload/download, merge, and failure recovery. Screens should not call Supabase directly.

## Sync policy

### Initial sign-in

- No account: use local storage only.
- Sign in with an existing local garden: show a merge decision before upload/download.
- Empty local garden: offer download of the user's cloud garden.
- Cloud garden empty: offer upload of local garden.

### Ongoing sync

- Sync only when authenticated and enabled by the user.
- Save locally first; queue a remote upload.
- A failed upload never removes or rolls back local data.
- Use a revision/updated-at conflict check. Do not silently last-write-wins across devices.
- Present a conflict screen when both local and remote changed since the last sync.
- Preserve scheduled and recorded timestamps separately.
- Do not duplicate watering or Soil health events by retrying the same mutation; IDs are client-generated and idempotent.

### Sign-out

- Keep the local garden on the device unless the user explicitly chooses **Remove cloud account data from this device**.
- Stop remote sync immediately.
- Do not delete local care history as a side effect of sign-out.

## Google sign-in setup checklist

Project-specific values are intentionally not committed. Before enabling the feature:

1. Create a Google Cloud project and Android OAuth client using the app application ID and debug/release SHA-1 fingerprints.
2. Create a Web client ID; Supabase's Google provider requires the Web client ID as well.
3. Enable Google in Supabase Auth and register the client IDs.
4. Add the Android client configuration required by the chosen Flutter Google sign-in package.
5. Add the Supabase URL and publishable key through Flutter build-time configuration, for example `--dart-define-from-file`; do not hard-code secrets.
6. Add privacy policy and account deletion behavior before production release.
7. Test sign-in cancellation, no network, expired sessions, sign-out, local/cloud merge, and reinstall.

## PlantNet setup checklist

1. Create a PlantNet account/API key according to the provider terms.
2. Store the key only as a Supabase Edge Function secret.
3. Confirm the free-tier quota and attribution requirements before enabling the feature for users.
4. Add rate limiting, image-size limits, timeout/retry behavior, and quota exhaustion UI.
5. Review PlantNet terms and image reuse requirements. Candidate images/results must not be copied into the app without complying with provider attribution/licensing rules.
6. Keep identification separate from reviewed Bloom profiles. A candidate match does not automatically grant Bloom watering guidance.

## Rollout sequence

1. **Current slice:** FAB menu, local photo intake, reviewed candidate contract, no external call.
2. **Provider seam:** add `PlantIdentifier` and fake/test implementation; no production credentials.
3. **Edge Function:** proxy PlantNet, return normalized candidates, enforce auth/quota/limits.
4. **Candidate confirmation:** user confirms a candidate; supported profiles can enter setup, unsupported candidates remain without an invented schedule.
5. **Supabase Auth:** optional Google sign-in and session state.
6. **Local/cloud merge:** explicit first-sign-in choice and revisioned garden sync.
7. **Photo persistence:** optional private storage only after user confirmation.
8. **Manual QA:** auth cancellation, offline use, quota errors, permission states, privacy, conflict/recovery, and account deletion.

Do not implement all layers in one change. Each layer should preserve the offline watering app and have its own tests and rollback behavior.
