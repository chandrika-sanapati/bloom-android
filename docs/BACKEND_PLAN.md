# Bloom backend and identification plan

**Decision:** Supabase Auth + Postgres + Storage + Edge Functions
**Status:** Supabase project linked, `identify-plant`, `delete-garden`, and `delete-account` Edge Functions deployed, Flutter provider/auth seams implemented, mandatory-auth gate, email/password and Google authentication, OTP registration confirmation, revision-guarded local-wins garden sync, and normalized candidate flow implemented; live OTP email QA, provider UI-state QA, and production-release verification remain. Migration/RLS schema checks are green.
**Last updated:** 17 November 2026

## Goals

- Keep Bloom usable offline and preserve the current local garden behavior.
- Support Google and email/password authentication; configured builds require an account before Home while unconfigured builds remain local-only.
- Sync a user's garden, watering history, Soil health history, placement acknowledgment, and preferences after explicit sign-in.
- Proxy PlantNet identification through a server-side Edge Function so the PlantNet API key never ships in the APK.
- Keep identification uploads short-lived. Private saved-photo Storage is deferred and is not part of the current app.

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

- Use Supabase Auth with Google and email/password providers. Registration confirmation uses a one-time email OTP; later password sign-ins do not require OTP.
- Native Android Google sign-in supplies an ID token to `signInWithIdToken`.
- Store the Supabase session using the package's secure/session persistence strategy; never store Google client secrets in the app.
- Login is mandatory in configured builds. Signed-out users remain local-only only when Supabase is not configured; sign-out preserves local data and stops authenticated writes.
- Sign-in preserves the local garden and uploads it when cloud data differs.
- Never replace local garden data from the cloud during sign-in or background sync.

Configured production builds currently gate Home until authentication succeeds. Builds without Supabase defines remain usable for local development and tests. After sign-in, an empty remote garden receives the local garden; when both differ, the local garden is uploaded with a revision guard. The deployed `gardens` migration is applied; final RLS and production-release review remain.

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

The current sync implementation stores one versioned garden payload per user rather than normalizing every plant/event. The payload uses the existing local JSON schema and an explicit schema version. Normalized tables remain deferred.

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

### Email template requirement

- The hosted Supabase **Confirm signup** template must send `{{ .Token }}` as a six-digit code rather than only `{{ .ConfirmationURL }}`. The Flutter app verifies the code with `verifyOtp(type: email)`.
- The confirmation state supports resend and a Back arrow to return to registration. Successful verification signs the user in immediately.

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

The current local store remains the source used by the UI. Remote sync is an explicit application service that coordinates local persistence, authentication, guarded local-wins upload, and failure recovery. Screens do not call Supabase directly.

The current code includes `SupabasePlantIdentifier`, which calls a configured Edge Function endpoint with multipart photos and normalizes PlantNet-style candidates. It uses the current Supabase session access token when one is available. Configure the project only at build time:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=PLANT_IDENTIFIER_ENDPOINT=https://<project-ref>.supabase.co/functions/v1/identify-plant
```

Without those defines, photo intake remains local-only and clearly reports that identification is not configured. The PlantNet API key is never accepted by the Flutter client. A publishable Supabase key is not a PlantNet secret, but it still belongs in build-time configuration rather than tracked source.

## Sync policy

### Initial sign-in

- No configured Supabase: use local storage only. In configured builds, Home remains behind authentication.
- Sign in with an existing local garden: preserve and upload the local garden.
- Empty local garden: upload the local garden; the current release does not download or replace it from the cloud.
- Cloud garden empty: upload the local garden.

### Ongoing sync

- Sync only when authenticated in a configured build; there is no separate sync-enable preference.
- Save locally first; queue a remote upload.
- When mandatory-auth mode is enabled, the app gates Home until a valid session exists; local writes remain the immediate source and are uploaded after persistence.
- If the network is unavailable, local writes continue and the next app resume/save retries sync.
- A failed upload never removes or rolls back local data.
- Use a revision/updated-at guard for local-wins cloud overwrites.
- Retry when another device changes the remote row during the write; never replace local data from the cloud.
- Cloud sync has no user-facing merge screen under the current local-wins policy. A future review/diff merge would require an explicit scope decision.
- Preserve scheduled and recorded timestamps separately.
- Do not duplicate watering or Soil health events by retrying the same mutation; IDs are client-generated and idempotent.

### Sign-out

- Keep the local garden on the device after sign-out.
- Stop remote sync immediately.
- Do not delete local care history as a side effect of sign-out.

### Account and data deletion

- The client never uses a service-role key. Profile's **Delete all plant data** action calls the authenticated `delete-garden` Edge Function; **Delete account and all data** calls `delete-account`.
- Both functions validate the caller's JWT and use the server-side service-role binding. `delete-garden` deletes only the user's `gardens` row; `delete-account` deletes the garden and auth user.
- Flutter clears the local garden only after the server confirms deletion. Plant-data deletion keeps the session; account deletion clears the local session and returns to login. A failed server deletion leaves local data intact for retry.
- Both deletion flows require two explicit confirmations.

## Google sign-in setup checklist

Project-specific values are intentionally not committed. Before enabling the feature:

1. Create a Google Cloud project and Android OAuth client using the app application ID and debug/release SHA-1 fingerprints.
2. Create a Web client ID; Supabase's Google provider requires the Web client ID as well.
3. Enable Google in Supabase Auth and register the client IDs.
4. Add the Android client configuration required by the chosen Flutter Google sign-in package.
5. Add the Supabase URL and publishable key through Flutter build-time configuration, for example `--dart-define-from-file`; do not hard-code secrets.
6. Add privacy policy and account deletion behavior before production release.
7. Test sign-in cancellation, OTP registration/resend/verification, no network, expired sessions, confirmed sign-out, local-wins retry behavior, and reinstall.

## PlantNet setup checklist

1. Create a PlantNet account/API key according to the provider terms.
2. Store the key only as a Supabase Edge Function secret.
3. Confirm the free-tier quota and attribution requirements before enabling the feature for users.
4. Add rate limiting, image-size limits, timeout/retry behavior, and quota exhaustion UI.
5. Review PlantNet terms and image reuse requirements. Candidate images/results must not be copied into the app without complying with provider attribution/licensing rules.
6. Keep identification separate from reviewed Bloom profiles. A candidate match does not automatically grant Bloom watering guidance.

## Rollout sequence

1. **Current slice:** FAB menu, local photo intake, and authenticated candidate identification through the Edge Function.
2. **Provider seam:** add `PlantIdentifier` and fake/test implementation; no production credentials.
3. **Edge Function:** proxy PlantNet, return normalized candidates, enforce auth/quota/limits.
4. **Candidate confirmation:** implemented; user confirms a candidate, supported profiles enter setup, and unsupported candidates remain without an invented schedule.
5. **Supabase Auth:** Google and email/password sign-in/registration, email-confirmation messaging, and configured-build Home gating are implemented.
6. **Local/cloud sync:** implemented; first sign-in uploads an empty cloud row, differing cloud data is guarded-overwritten by the local garden, and every local save queues asynchronous sync.
7. **Photo persistence:** deferred; identification photos are temporary request inputs and are not saved to Storage by the current app.
8. **Manual QA:** auth cancellation, offline use, quota errors, permission states, privacy, local-wins retry behavior, and account deletion.

Do not implement all layers in one change. Each layer should preserve the offline watering app and have its own tests and rollback behavior.
