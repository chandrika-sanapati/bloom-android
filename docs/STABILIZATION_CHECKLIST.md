# Bloom stabilization checklist

**Mode:** Stabilization only — no feature expansion
**Effective:** 16 November 2026
**Owner:** Bloom engineering

This checklist is the active work queue during the feature freeze. It covers only behavior already present in the app. Do not add new product capabilities while these items are open.

The owner-approved UX overhaul exception (17 November 2026) is complete; the items below now refer to the redesigned screens.

## Automated checks

- [x] `flutter analyze` reports zero findings.
- [x] Host/widget/domain tests pass (111 tests, 17 November 2026).
- [x] Normal debug APK builds with the Android Studio JDK.
- [x] Existing isolated placement integration tests pass (re-run after the UX overhaul).
- [x] Existing isolated care timeline integration tests pass (re-run after the UX overhaul).
- [x] Existing isolated reminder/notification integration tests pass (re-run after the UX overhaul).
- [x] Existing native cold-launch notification cases pass (not re-run after the UX overhaul).
- [x] Add deterministic tests for cloud sync status transitions using a fake backend seam.
- [x] Add deterministic tests for local-save/cloud-sync boundaries, signed-out writes, ordered snapshots, and provider errors.

## Auth and cloud sync

- [x] Configured builds gate Home behind Google/Supabase authentication.
- [x] Configured builds offer Google and email/password sign-in and registration.
- [x] Configured release build from `config/prod.json` reaches the Google account picker on the emulator.
- [ ] Create a real release signing key and register its SHA-1 with the Android OAuth client (release builds are currently signed with the debug key).
- [x] OTP registration confirmation state supports six-box code entry with auto-verify, resend after a 45-second countdown, and immediate sign-in after verification.
- [x] Local/test builds without cloud defines remain usable.
- [x] Empty remote garden accepts the local garden on first sync.
- [x] Non-empty remote differences are guarded-overwritten by the local garden.
- [x] Every successful local garden save queues asynchronous cloud synchronization.
- [x] Revision-checked remote updates are implemented.
- [x] Verify local-wins revision-checked overwrite and retry behavior with fake-backend tests.
- [x] Verify failed network/write leaves local data intact and exposes retry state through deterministic tests.
- [x] Verify signed-out sync does not call the backend through deterministic tests; live sign-out remains a manual check.
- [x] Review the deployed migration and RLS schema: migration matches production and `supabase db lint --linked` reports no schema errors.
- [x] Verify normalized plant collection migration and transactional sync function are deployed with JWT authentication.
- [x] Seed 50 plant profiles and aliases into the managed production catalog for testing.
- [ ] Review and source the seeded profile content before production release.

## PlantNet/photo flow

- [x] Photo intake supports camera/gallery, preview, removal, and cancel/back.
- [x] Authenticated Edge Function request reaches PlantNet.
- [x] Edge Function validates JWT, image count/type/size, and provider errors.
- [x] Normalized candidate results render in Flutter with likelihood labels.
- [x] Reviewed candidates route into existing setup.
- [x] Unreviewed candidates can be added without an invented schedule.
- [x] Add deterministic provider coverage for HTTP failure, timeout boundary, empty-result, and malformed-result handling. Live UI state verification remains manual.
- [ ] Review provider quota and image-retention/privacy behavior.
- [ ] Verify camera/gallery activity recreation and lost-picker-data recovery.

## Existing UI/data reliability

- [ ] Complete TalkBack review for login, Home (Today card, grid, multi-select), Add plant sheet, Profile, photo identification, plant page, growth photos, timeline, correction, and Check & water choices.
- [ ] Review large text, narrow layout, dark theme, and reduced-motion behavior on the existing screens.
- [ ] Verify Android Back and predictive Back for all dirty forms.
- [ ] Verify notification permission denial/re-enable and long-idle/inexact delivery behavior.
- [ ] Review old garden JSON migration and malformed optional fields. (An unreadable `garden.json` is now backed up to `garden.unreadable-<timestamp>.json` before an empty garden is used.)
- [ ] Rotate credentials that were shared during setup.
- [x] Confirm no high-risk credentials are present in tracked files; Edge Function logs contain no tokens, garden payloads, or photo contents by inspection.
- [x] Deploy and verify authenticated `delete-garden` and `delete-account` Edge Function boundaries.
- [x] ~~Manually confirm plant-data deletion keeps the account and removes local/cloud plant data.~~ Superseded 17 November 2026: plant-data-only deletion was removed from the app.
- [ ] Manually confirm account deletion removes the account, local/cloud plant data, and device growth photos.

## Explicitly frozen

Do not implement during this stage:

- Additional plant profiles or catalog expansion.
- New care domains or new recurring schedules.
- New identification providers or broader ML behavior.
- Cloud merge automation beyond the local-wins policy.
- Search/history expansion.
- Widgets, sharing, analytics, subscriptions, or social features.

Document future ideas in `docs/PRODUCT_DECISIONS.md` only. Implementation requires an explicit scope-freeze lift.
