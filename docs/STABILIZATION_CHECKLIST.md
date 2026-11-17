# Bloom stabilization checklist

**Mode:** Stabilization only — no feature expansion
**Effective:** 16 November 2026
**Owner:** Bloom engineering

This checklist is the active work queue during the feature freeze. It covers only behavior already present in the app. Do not add new product capabilities while these items are open.

## Automated checks

- [x] `flutter analyze` reports zero findings.
- [x] Host/widget/domain tests pass.
- [x] Normal debug APK builds with the Android Studio JDK.
- [x] Existing isolated placement integration tests pass.
- [x] Existing isolated care timeline integration tests pass.
- [x] Existing isolated reminder/notification integration tests pass.
- [x] Existing native cold-launch notification cases pass.
- [x] Add deterministic tests for cloud sync status transitions using a fake backend seam.
- [x] Add deterministic tests for normalized PlantNet candidate parsing and provider errors.

## Auth and cloud sync

- [x] Configured builds gate Home behind Google/Supabase authentication.
- [x] Configured builds offer Google and email/password sign-in and registration.
- [x] Email confirmation-required registration is explained without creating a local session.
- [x] Local/test builds without cloud defines remain usable.
- [x] Empty remote garden accepts the local garden on first sync.
- [x] Non-empty remote differences are guarded-overwritten by the local garden.
- [x] Every successful local garden save queues asynchronous cloud synchronization.
- [x] Revision-checked remote updates are implemented.
- [x] Verify local-wins revision-checked overwrite and retry behavior with fake-backend tests.
- [ ] Verify failed network/write leaves local data intact and exposes retry state.
- [ ] Verify sign-out preserves local data and stops cloud writes.
- [ ] Review RLS policies against the deployed schema.

## PlantNet/photo flow

- [x] Photo intake supports camera/gallery, preview, removal, and cancel/back.
- [x] Authenticated Edge Function request reaches PlantNet.
- [x] Edge Function validates JWT, image count/type/size, and provider errors.
- [x] Normalized candidate results render in Flutter.
- [x] Reviewed candidates route into existing setup.
- [x] Unreviewed candidates can be added without an invented schedule.
- [ ] Verify 401, 429, 502/504, timeout, empty-result, and malformed-result UI states.
- [ ] Review provider quota and image-retention/privacy behavior.
- [ ] Verify camera/gallery activity recreation and lost-picker-data recovery.

## Existing UI/data reliability

- [ ] Complete TalkBack review for login, Profile/Preferences, FAB menu, photo flow, timeline, correction, and watering choices.
- [ ] Review large text, narrow layout, dark theme, and reduced-motion behavior on the existing screens.
- [ ] Verify Android Back and predictive Back for all dirty forms.
- [ ] Verify notification permission denial/re-enable and long-idle/inexact delivery behavior.
- [ ] Review old garden JSON migration and malformed optional fields.
- [ ] Rotate credentials that were shared during setup.
- [ ] Confirm no tokens, API keys, garden payloads, or photo contents appear in tracked files or logs.

## Explicitly frozen

Do not implement during this stage:

- Additional plant profiles or catalog expansion.
- New care domains or new recurring schedules.
- New identification providers or broader ML behavior.
- Cloud merge automation beyond the local-wins policy.
- Search/history expansion.
- Widgets, sharing, analytics, subscriptions, or social features.

Document future ideas in `docs/PRODUCT_DECISIONS.md` only. Implementation requires an explicit scope-freeze lift.
