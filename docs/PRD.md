# Bloom — Android product requirements

**Status:** Check & water, Light & placement, Profile/Reminders, reminder navigation, record-only Soil care, plant history, growth photos, multi-select delete, guarded Back, the fixed Bloom green theme, authenticated Supabase/PlantNet integration, email/password and Google authentication, and local-wins cloud sync are implemented. The 17 November 2026 UX overhaul (section 21) is the current screen contract. Verification evidence and remaining manual checks are in STATUS.md.
**Product:** Bloom for Android, a local-first Flutter app
**Owner:** Bloom product team
**Last updated:** 17 November 2026

The full product decision record—including alternatives, tradeoffs, future care-domain boundaries, and decision-revisit triggers—is in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). Sections 1–13 describe the watering baseline. Section 14 specifies the approved Light & placement release, now implemented with watering dates unchanged. Verification evidence and remaining checks are in STATUS.md. Section 15 specifies the reviewed reminder-preference and notification-navigation scope, authorized and implemented on 15 November 2026. Section 18 defines Soil care (record-only since 17 November 2026; the earlier advisory questionnaire was removed); sections 19–20 define the plant history and guarded Back navigation. Section 21 records the 17 November 2026 UX overhaul and supersedes earlier screen-level wording where they differ. Current verification is recorded in STATUS.md.

## 1. Product summary

Bloom helps plant owners remember which plant to check, record what they actually did, and know when to look again. The first product loop is intentionally narrow:

> **Schedule a check → inspect the plant → choose Watered or Checked — not watered → schedule the next check.**

A date is a prompt to inspect the plant, not proof that the plant needs water. Bloom keeps the user in control and avoids presenting a calendar rule as a diagnosis.

## 2. Product and platform boundary

- The active product is the Flutter Android app in this repository.
- Garden data is stored locally on the device as JSON.
- Notifications are optional and Android-specific in the current implementation.
- Configured builds require authentication before Home. Supabase Auth supports Google and email/password registration/sign-in; unconfigured builds remain local-only for development and tests.
- The login page is a single, context-independent entry screen with no toolbar Back button. It opens with a welcome image header (**Welcome to Bloom**), then **Continue with Google** first when configured, an **or use email** divider, a **Sign in / Create account** segmented switch, filled email/password fields with icons, a password strength bar while registering, inline errors in a MessageBanner, and the primary button pinned at the bottom. A configured build shows it at startup whenever no valid session exists. The Android launcher icon uses the Snake Plant artwork.
- Registration requires a one-time six-digit email OTP. The confirmation state (**Check your email**) shows six digit boxes, verifies automatically when the sixth digit is entered (a **Verify** button remains), and offers **Resend code** after a 45-second countdown, plus a Back arrow to return to registration. Successful OTP verification immediately creates the session and continues to Home; later logins use email/password without OTP.
- Local garden data remains the immediate source of truth on-device. Authenticated local saves queue asynchronous sync to one normalized cloud `plant_collection`; the local snapshot is authoritative and guarded-overwrites differing cloud data by revision.
- Plant identification is available through the authenticated Supabase Edge Function when its endpoint is configured. PlantNet keys never ship in Flutter or the APK.
- There is no analytics service, live weather, device-location inference, sensor integration, or automatic watering hardware.
- The active plant inventory is data-driven. Profiles are managed in Supabase `plant_profiles`/`plant_profile_aliases` and cached from the bundled versioned catalog for offline use. The current test seed contains 50 common houseplant profiles; profile content requires review before production release.
- The historical iOS screenshots in `docs/previews/` are not current product behavior.

## 3. Current implementation baseline

The following behavior exists in the current Android code:

- Home shows a greeting header, a **Today** card for due/overdue checks, a **My plants · N** photo grid, and **Recent** activity (section 21.1). The former Upcoming/Past toggle and FAB menu were removed on 17 November 2026.
- The data-driven catalog contains a 50-profile test inventory; the five original profiles have dedicated care assets/content and the remaining seeded profiles are under content review.
- A plant's reviewed care type is determined by its canonical profile, not by whether it was added from the catalog or identified from a photo. Separate physical plants retain separate IDs, while matching types share the same reviewed name, scientific identity, image, schedule interval, care cue, and light guidance.
- Setup may accept a past last-watered date; otherwise the first check is created today at the saved reminder time (09:00 initially).
- Each supported plant receives one active schedule with a profile starting interval.
- Checks are classified as Today, Upcoming, or Overdue and shown as relative dates (**Today**, **Tomorrow**, **In N days · date**, **Overdue · N days**).
- The recurring task is named **Check & water**: a check comes first, watering only if needed. A check records exactly one of **Watered** or **Checked — not watered**.
- Soil may be Dry, Damp, or Not sure, but the question is shown only after the user chooses **Checked — not watered**. **Watered** can be saved without a soil selection.
- A dry **Checked — not watered** outcome schedules a three-day follow-up. Other outcomes use the plant profile interval.
- Watered updates Last watered. Checked — not watered does not.
- The next check is based on the actual recorded event, while the record retains the originally scheduled time.
- Users can edit a future next-check date and time.
- Users can delete one plant from its ⋮ menu or several from Home multi-select, after one confirmation; deletion removes the plants' schedules, care records, and growth photo files.
- Home **Recent** shows the last three activities across plants; **See all** opens Recent activity. Each plant page shows its last five entries and links to the full history.
- Notifications are synchronized for future checks only. Denying permission leaves in-app tasks available.
- Plant setup and the plant page share species-specific light guidance and one optional placement confirmation, persisted per plant with its timestamp and guidance version; existing plants default to unconfirmed.
- Setting or clearing placement leaves watering state and existing reminders unchanged.
- The plant page has a collapsing hero photo, a status card, Add photo / Soil care quick actions, a Care guide, and History (section 21.3).
- Soil care records what the user did; Bloom does not assess or diagnose soil health (section 18).
- Growth photos are stored on the device only and are never synced (section 21.4).
- Native page Back navigation protects dirty forms with Keep editing / Discard changes.
- Home's **+** opens a bottom sheet with **Search by name** and **Identify from a photo**. Configured builds can upload selected photos to the authenticated Edge Function and display normalized possible matches; unconfigured builds show that identification is unavailable.
- Profile shows an avatar header with the account email and plant/sync status, a **Reminders** section (Notifications, Reminder time), and an **Account** section (Sign out, Delete account).
- An unreadable `garden.json` is backed up as `garden.unreadable-<timestamp>.json` before an empty garden is used.

## 4. Product goals

1. Reduce the memory burden of caring for several common houseplants.
2. Make the next action obvious without telling users to water blindly.
3. Preserve the difference between watering and checking without watering.
4. Make late completion produce a useful next date rather than an immediate duplicate task.
5. Keep setup, notifications, and history small enough to trust.
6. Establish a dependable Android foundation before adding other care domains.

## 5. Non-goals for this release

- Automatic watering hardware or smart-home integrations.
- Photo-based disease or moisture diagnosis.
- Live weather, climate, humidity, temperature, or location-based schedule calculation.
- Automatic schedules for arbitrary custom or unlisted plants.
- Per-plant interval editing, pause/resume, seasonal logic, or silent adaptive changes.
- Deferred/Check later outcomes.
- Soil-health assessment or diagnosis, automatic nutrient/repotting schedules, chemistry treatment, pruning, or disease-treatment flows. Record-only Soil care is included in section 18.
- Sharing, social features, analytics, community schedules, and cloud merge/sharing beyond local-wins synchronization. Growth photos are never uploaded.
- Watering-specific search/filters and global history correction. The per-plant history is specified in section 19.
- Out of scope for now (owner decision, 17 November 2026): special handling for multiple plants of the same type, and showing watering frequency.

## 6. Supported profiles and profile inventory

These are check-in profiles, not universal watering instructions. Actual needs vary with pot size, drainage, medium, light, temperature, humidity, season, and plant size.

| Plant | Scientific name | Check-in range | Starting interval |
| --- | --- | ---: | ---: |
| Snake Plant | *Dracaena trifasciata* | 14–30 days | 21 days |
| Monstera | *Monstera deliciosa* | 7–14 days | 10 days |
| Rubber Plant | *Ficus elastica* | 7–21 days | 14 days |
| Pothos | *Epipremnum aureum* | 7–21 days | 14 days |
| Spider Plant | *Chlorophytum comosum* | 7–14 days | 10 days |

The range and starting value are versioned product content. Updating profile content must not silently rewrite saved schedules, records, or recorded dates.

The complete inventory is data-driven in Supabase `plant_profiles` and `plant_profile_aliases`, with the bundled JSON catalog as the offline cache. The table above documents the original five reviewed profiles; the additional seeded inventory is available for identity/profile testing and must be reviewed before production content release.

## 7. Schedule behavior

### First check

When a catalog plant is added:

1. If the user supplies a valid past last-watered date, the first check is that date plus the profile starting interval at the app's saved reminder time.
2. If the date is unknown, the first check is today at the saved reminder time.
3. A future last-watered date must not be accepted.
4. Setup remains optional and short; the user can add a plant without knowing the previous watering date.

### Completion

For **Watered**:

- create a watering record;
- update Last watered;
- resolve the current task;
- schedule the next check from the recorded event plus the profile interval;
- show the record in the plant's history and Home Recent.

For **Checked — not watered**:

- create a care-check record;
- leave Last watered unchanged;
- resolve the current task as a check, not a watering event;
- use a three-day follow-up when the soil is dry;
- use the normal profile interval for Damp or Not sure;
- show the result in the plant's history and Home Recent.

The Check & water screen keeps the soil question (Dry / Damp / Not sure) hidden for **Watered** and reveals it only for **Checked — not watered**. After saving, a snackbar confirms the outcome and the next check date. This keeps the common watering path concise without changing stored soil semantics or follow-up rules.

### Overdue and editing

- An untouched task remains Overdue; it does not move forward every day.
- An overdue task does not mean the plant must be watered.
- Completing an overdue task anchors the next check day to the actual completion day, using the preferred reminder clock (section 15).
- Editing the next check changes future timing only. It creates no history record and does not imply that watering occurred.
- History records retain scheduled and recorded times separately.

## 8. Notifications and persistence

- Notifications are disabled by default until the user enables them.
- Permission is requested only after the user chooses to enable notifications.
- Only future checks are scheduled.
- Android delivery is best effort and inexact; special exact-alarm access is not required.
- Initial notification synchronization runs after the app starts and must not block the core UI.
- Enabling, disabling, completing a check, or editing the next date synchronizes watering notifications.
- Overdue history never creates a burst of notifications.
- If permission is denied, the task remains visible in the app.
- Garden writes use a temporary file before replacement. A failed save must not update the in-memory garden or notify listeners.

### 8.1 Authentication, Profile, and cloud persistence

- When Supabase build-time configuration is present, authentication is required before Home. The login surface offers Google when its Web Client ID is configured and email/password registration/sign-in in all configured builds. Registration sends a one-time six-digit email OTP; the app verifies it with Supabase `verifyOtp` before creating the session.
- Builds without Supabase configuration remain local-only for development and tests. Local garden persistence remains available and authoritative in every build.
- Home opens **Profile** through an avatar showing the account email's initial. Profile shows an avatar header with the email and **N plants · Synced / Syncing… / Sync pending** (or **On this device** when signed out), a **Reminders** section (Notifications switch, Reminder time), and an **Account** section (Sign out, Delete account). There is no separate cloud-sync section.
- After a successful local persistence operation, Bloom queues cloud synchronization asynchronously. Local UI and local data do not wait for a network request, and a failed cloud write never rolls back or removes local data.
- The cloud stores one normalized `plant_collection` per authenticated user. Its individual `plants` reference `plant_profiles`; schedules, watering records, and soil-care events reference individual plant IDs. A transactional sync function replaces the collection snapshot only through a revision-checked update; bounded retries handle a concurrent remote write.
- The legacy single-row JSON `gardens` cloud table is retired. Normalized plant collections are the only cloud garden representation.
- Cloud sync does not download or replace the local garden, and it does not expose a merge/conflict screen under this release policy. Sign-out requires confirmation, preserves local data, stops authenticated cloud writes, and returns to the root login landing screen.
- Signed-in users can open Profile → Account and choose **Delete account** (red text, subtitle **Removes your account and all plants**). After one explicit confirmation it removes the cloud garden and auth account through `delete-account`, clears the local garden and growth photo files, and returns to the login landing screen. If cloud deletion fails, local data is preserved and the user receives a retryable error. The separate plant-data-only deletion was removed on 17 November 2026.
- Growth photos and the chosen plant image (`coverPhotoId`) are excluded from the cloud payload.

### 8.2 Photo identification boundary

- When `PLANT_IDENTIFIER_ENDPOINT` is configured, selected photos are sent only to the authenticated Supabase Edge Function, which proxies PlantNet and returns normalized possible matches.
- The PlantNet API key is server-side only. Identification results are candidates, not diagnoses or care instructions.
- The user must confirm a candidate before adding it. Supported reviewed identities can use existing setup; unsupported identities may be saved without an invented watering schedule. Temporary identification photos are not saved to user Storage by the current app.
- Provider/common-name aliases for reviewed catalog plants are normalized to the canonical profile at the GardenStore boundary. Existing saved variants are normalized when loaded without merging separate plant records.
- Each physical user plant stores a stable `plantTypeId` reference and retains its own schedule/history. Discovery path never determines care behavior.

## 9. Accessibility and interaction requirements

- Use Android Material 3 controls and navigation, styled by the shared Bloom theme (see DESIGN_GUIDELINES.md).
- Keep interactive targets at least 48dp; filled and outlined buttons have a 48dp minimum height.
- Each screen has one primary filled action; on forms and flows it is pinned at the bottom.
- Show errors inline (MessageBanner, announced as a live region) rather than in blocking dialogs.
- Support Android font scaling without truncating decisions, dates, errors, or the primary action.
- TalkBack must distinguish Watered from Checked — not watered and expose selected/disabled states.
- Do not preselect Watered.
- Use clear empty, unavailable, failure, confirmation, and permission-denied states.
- Respect Android animation settings.

## 10. Data model direction

The current domain is deliberately small:

```text
Plant
- id
- plantTypeId (canonical profile reference)
- displayName (optional user-edited name)
- coverPhotoId (optional growth photo used as the plant image; device-only)
- lightPlacement (optional confirmation timestamp and guidance version)

GrowthPhoto (device-only, never synced)
- id / plantId
- takenAt
- path (file in app storage)

WateringSchedule
- plantId
- intervalDays
- nextCheckAt
- createdAt
- updatedAt
- timeSource: preference | custom | legacy

WateringRecord
- id
- plantId
- scheduledFor
- recordedAt
- outcome: watered | checkedNotWatered
- soil: dry | damp | unknown

SoilCareEvent
- id / plantId
- occurredOn (actual local care date) / recordedAt (UTC)
- actions: one or more of nutrientsAdded | mixRefreshed | repotted
- optional product / notes / mixContainsFeed

AppPreferences
- reminderHour / reminderMinute (editable in Profile → Reminders; initially 09:00)
- taskNotifications
```

Keep schedule transitions in `GardenStore`. Do not make screens mutate records, dates, or derived Last watered state directly.

## 11. Acceptance criteria for the next validation milestone

- The five catalog plants can each be added and receive the documented starting interval.
- A known last-watered date and an unknown date produce the documented first checks.
- Future last-watered dates are rejected.
- Watered and Checked — not watered produce the documented history and schedule changes.
- Dry non-watering checks use the three-day follow-up; damp and unknown checks use the normal interval.
- Late completion does not create an immediate duplicate task.
- Next-check editing changes timing without adding history.
- Deleting a plant (singly or by multi-select) removes its schedule, records, and photo files after confirmation.
- Relaunch preserves plants, schedules, records, and notification preference.
- Permission denial does not remove in-app work.
- The debug APK builds and launches on an Android emulator.
- Focused automated domain tests cover the schedule transitions and persistence failure behavior.
- TalkBack and large-font review do not hide or change the meaning of the primary actions.

## 12. Roadmap

Only add a later capability after the watering loop is reliable and validated.

1. **Verification hardening:** automated domain tests, Android build/emulator checks, notification timing, date entry, persistence recovery, and accessibility review.
2. **Reminder control and navigation — implemented:** a global reminder-time preference and direct notification entry to the relevant Check & water screen; see section 15. Latest-watering-record deletion with Undo is available from the plant history (section 19).
3. **More reviewed plant profiles — deferred:** Five reviewed catalog profiles are currently shipped; additional catalog content requires a future scope decision.
4. **Light & placement — implemented:** species-specific light suggestions during setup and on detail, with one optional saved acknowledgment and unchanged watering dates; see section 14. Adaptation and broader environmental checks remain deferred.
5. **Soil care — implemented, record-only:** record Added nutrients, Refreshed potting mix, and Repotted, with explicitly recorded overlap; see section 18. The advisory soil-health questionnaire was removed on 17 November 2026; Bloom does not diagnose soil health. Symptom diagnosis remains separate future scope.
6. **Cloud sync — implemented:** configured builds authenticate users and asynchronously synchronize local-authoritative normalized collection snapshots with revision guards. Sharing and merge features remain deferred.

## 13. Product principles

- **Reduce memory, not agency.** Bloom remembers dates; the user observes the plant.
- **Scheduled does not mean watered.** Every due task is a check prompt.
- **Record reality.** A non-watering check is meaningful and must not update Last watered.
- **Late completion changes the future, not the past.** Preserve scheduled and recorded times.
- **Prefer explicit changes.** Do not silently adapt schedules or infer plant conditions.
- **Earn complexity.** Broader care features must follow validated user problems, not an old feature list.

## 14. Light & placement — release requirements

**State:** Revised scope and unchanged-watering policy confirmed on 15 November 2026. The user explicitly authorized implementation. The approved flow is implemented; completion, test evidence, the test-runner incident, and remaining checks are tracked in STATUS.md.

### 14.1 Current user goal and scope

Give the user a clear, species-specific suggestion about light and where to place the plant. The only new input is an optional acknowledgment that the user has acted on that suggestion. Persist it per plant so it can be given during setup or later on plant detail and be available to the watering system.

This supersedes the earlier dim/bright concern picker, conditional advice branches, transient concern state, and a light flow centered on manual next-date editing. There is no placement questionnaire or light assessment flow in this proposal.

### 14.2 Add a plant

- Add a **Light & placement** section alongside the existing optional Last watered section, within the same setup screen.
- Both optional sections use the same sentence-case header pattern: **Last watered · optional** and **Light & placement · optional**. Both inputs remain skippable (D32, restyled 17 November 2026).
- Show the species' recommended light, a room-scene illustration of the recommended spot, and the profile's placement text immediately. The user does not have to answer a question to see it.
- Use one optional, initially unchecked acknowledgment, labelled **I've placed it as suggested**. It means the user acted on the suggestion, not merely read it. It also applies when the plant was already in a suitable position.
- The user may leave it unchecked and press **Add plant**, pinned at the bottom of the setup screen. Do not require a separate Skip action, add a page, preselect acknowledgment, or block adding the plant.
- Keep the choice in setup state until Add. On Add, save the plant, its normal starting watering schedule, and the acknowledgment if supplied in one store/persistence transaction. Cancelling setup creates no plant or saved acknowledgment.
- The existing Last watered input and first-check calculation remain available. Placement acknowledgment has no effect on that first check in this release (14.5).

### 14.3 Plant detail and later acknowledgment

- Keep the status card and **Check & water** primary. On the plant page, light is a collapsed row in the **Care guide** (section 17). Expanding it shows the room scene, the profile's placement text, and **Is it in a spot like this?** with **Yes, it is** / **Not yet**. Collapse/review and **Not yet** write no data.
- A confirmed plant shows **In a good spot · Confirmed <date>** with **Change**, and a check mark on the collapsed row. A plant added without confirmation can be confirmed here later.
- **Yes, it is** saves immediately through the store, with no extra Save page or confirmation dialog. Publish the confirmed state only after persistence succeeds; show **Saving…** and allow retry after failure.
- On reopening or relaunching, show the saved state. Do not repeatedly prompt users who have skipped it; the question appears only when the user expands the row.
- Correction: **Change** clears the confirmation and returns to the question. Clearing does not claim that the light is unsuitable. Watering dates remain unchanged (14.5).
- Setup keeps the **I've placed it as suggested** checkbox; both entry points save the same state.
- Do not require a placement name, window direction, distance, sun hours, photo, device location, sensor, dim/bright classification, or another form. Keep ordinary Android back navigation and existing watering actions.

### 14.4 Plant guidance and meaning of the input

Use sourced species guidance rather than a universal direct/indirect rule. Explain indirect light as daylight reaching the plant without strong sun shining directly on its leaves. Species that tolerate some direct sun need qualified guidance rather than an all-day direct-sun prescription.

Implemented version-1 content direction (shared by setup and detail):

| Catalog plant | Light and placement suggestion direction | Source |
| --- | --- | --- |
| Snake Plant | Choose a position with good daylight. Some direct sun is tolerated; lower-light tolerance is not a reason to recommend a dark corner. Introduce stronger exposure gradually. | NC State Snake Plant; general light references in 14.9 |
| Monstera | Choose a position with indirect daylight, sheltered from strong direct sun. | NC State Monstera |
| Rubber Plant | Choose a position with bright indirect light, protected from strong afternoon sun. | NC State Rubber Plant |
| Pothos | Choose a position with bright indirect light. Lower light is tolerated, but preferred light and mere survival are different. | NC State Pothos |

The user's direct-sun Rubber Plant example described the desired interaction, not approved horticultural content. The reviewed Rubber Plant reference recommends indoor indirect light with protection from afternoon sun. Version-1 plant copy was reviewed against the sources in 14.9 during implementation.

The saved input is **user-reported action on the displayed suggestion**. It is not a measured light level, proof of sufficient daylight, a report of previous conditions, an exact movement time, or a soil reading. Use **acknowledged at** for the recorded timestamp. Do not label the plant's light as verified or diagnose damage.

An unchecked input means only **not acknowledged**: the user may have skipped it, not acted yet, or withdrawn it. It must not be treated as evidence that the position is too dim or too bright. Retain the earlier data-insufficiency rationale in the decision history: extra questions to resolve uncertain light would create the more involved experience this release aims to avoid. This revised flow asks about action, not about classifying light.

### 14.5 Watering integration — unchanged in this release

**Decision confirmed by the user on 15 November 2026:** Keep watering schedules unchanged for this release. Handle acknowledgment-driven adaptation separately later. The user explicitly authorized implementation of the simplified suggestion/acknowledgment flow after this decision.

- Save and restore the optional placement acknowledgment as plant state, available for a separately reviewed future feature.
- Acknowledging, skipping, correcting, or reopening placement changes no next-check date, interval, scheduled/recorded watering history, Last watered, preferences, or reminder. Do not invoke notification synchronization for acknowledgment-only writes.
- Setup with or without acknowledgment uses exactly the same existing first-check calculation, including optional Last watered and same-day baseline behavior.
- Keep one watering schedule/reminder per plant. Add no light reminders, acknowledgment nudges, or light task/history type.
- Existing Watered / Checked — not watered outcomes and manual next-check editing continue independently.
- No automatic light formula, extra date confirmation, or adaptation control in this release. The checkbox is the only new input.
- Future adaptation requires a separate documented decision specifying evidence, species rule, disclosure/acceptance, idempotence, interval versus next-check effects, overdue/Last watered handling, and correction. Acknowledgment does not supply previous light, movement direction, or current soil moisture.

This replaces the previously unresolved watering policy; it is not an implementation blocker.

### 14.6 Data and persistence direction

Keep species guidance separate from the user's per-plant acknowledgment. The backward-compatible shape is:

```text
Species light guidance
- version
- preferred light, short placement suggestion, content references

Plant.lightPlacement (optional)
- acknowledgedAt
- guidanceVersion
```

A missing/null `lightPlacement` means not acknowledged. A non-null value means the user confirmed acting on that version of the suggestion. Do not silently backfill acknowledgments for existing plants or infer them from past watering.

Both setup and plant detail use the same store/persistence boundary. Save failure preserves the previous garden and leaves the input retryable. Preserve all unrelated plants, schedules, records, and preferences. Plant removal removes its acknowledgment with the plant. Relaunch restores it. A future guidance revision preserves the saved acknowledgment and its version, without changing dates or claiming agreement to updated copy. When versions differ, the expanded light row asks again (**The advice was updated. Is it still in a spot like this?**); answering **Yes, it is** records the current version. This is shown only when the user opens the row — no automatic expiry, notification, or reminder.

### 14.7 Acceptance criteria

- Every supported species has a reviewed short light requirement and practical position suggestion, displayed consistently in setup and detail.
- The only added input is the optional action acknowledgment. There are no dim/bright choices, placement questionnaire, or required light setup steps.
- The acknowledgment starts unchecked; the user can add a plant without it and confirm later on detail.
- Setup cancellation writes nothing. Add saves the chosen state with the plant; detail acknowledgment persists and survives relaunch.
- Skipping the input remains unacknowledged, never a negative light assessment. Acknowledgment means acted, not just read.
- Clearing (setup checkbox or **Change**) clears only acknowledgment. Older guidance acknowledgments retain their timestamp/version until the user answers the in-row question again; no notification or automatic prompt.
- Failed saves preserve existing data, expose useful retry feedback, and do not show a falsely saved acknowledgment or schedule.
- Reading advice or leaving without acting changes no state or date. Existing plants load with acknowledgment absent by default.
- Setup and later acknowledgment, correction, and repeated confirmation preserve all watering state and trigger no notification synchronization.
- No placement interaction changes an existing reminder, creates a light reminder, or re-enables notifications.
- TalkBack, large text, narrow widths, light/dark themes, and Android back support both placements of the input.
- Authorization to implement was given on 15 November 2026 after the watering policy was resolved. Verify implementation against this approved scope.

### 14.8 Approval and future work

The user confirmed the simplified proposal, resolved watering dates as unchanged, and explicitly authorized implementation on 15 November 2026. Use one optional acknowledgment in setup/detail, immediate persistence on detail, correction through **Change**, and versioned acknowledgment as documented above. Keep scheduling adaptation and any change to the damp/non-watering default as separate future product work. Do not expand implementation into the superseded concern picker or a new scheduling system.

### 14.9 Horticultural references

Reviewed for requirements on 15 November 2026. Use these to review species copy before implementation; do not turn broad guidance into precise date formulas.

- [University of Minnesota Extension — Lighting for indoor plants](https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/lighting-for-indoor-plants): lower light can reduce growth and water use; warmer, brighter positions can increase drying.
- [University of Minnesota Extension — Spring houseplant care](https://extension.umn.edu/houseplants/spring-houseplant-care): inspect soil and introduce stronger outdoor exposure gradually.
- [RHS — Growing houseplants](https://www.rhs.org.uk/plants/types/houseplants/growing-guide): placement and watering depend on growing conditions; inspect before watering.
- [NC State Extension — Snake Plant](https://plants.ces.ncsu.edu/plants/dracaena-trifasciata/): shade tolerance and partial direct-sun tolerance; avoid a blanket rule that all direct sun is harmful.
- [NC State Extension — Monstera](https://plants.ces.ncsu.edu/plants/monstera-deliciosa/): indoor light preferences and cultivar differences.
- [NC State Extension — Rubber Plant](https://plants.ces.ncsu.edu/plants/ficus-elastica/): indoor indirect light and afternoon-sun protection.
- [NC State Extension — Pothos](https://plants.ces.ncsu.edu/plants/epipremnum-aureum/): preferred indirect light and lower-light tolerance.

## 15. Reminder preferences and notification navigation — requirements

**State:** Features selected for refinement and local documentation on 15 November 2026. The user confirmed updates to existing future checks, then clarified that custom timings and today's existing checks must be preserved. The global change therefore applies only to eligible automatic checks on later days. The user explicitly authorized implementation on 15 November 2026 after reviewing the updated protection rules. Implemented with verification recorded in STATUS.md. The legacy safeguard and one-off override lifecycle below are adopted.

### 15.1 Goals and scope

Let the user choose a useful time for watering reminders from Profile → Reminders, then reach the relevant plant's watering check by tapping a notification. Keep one app-wide time, one existing watering schedule per plant, and the existing optional notification switch. Add no onboarding or required plant-setup input.

Selected scope:

- One **Reminder time** preference in Profile → Reminders, applying to all plants.
- Changing it updates eligible **existing automatic future checks on later days** and newly scheduled automatic checks. **Custom timings, today's existing checks, and overdue checks remain unchanged**, as clarified by the user.
- A valid notification tap opens that plant's **Check & water** screen.
- The documents were reviewed before implementation was explicitly authorized; keep them aligned with the code.

Not included: per-plant recurring time preferences, daily digests, repeated overdue nudges, snooze, notification buttons that record watering, new care reminders, exact-to-the-minute delivery, backup/restore, cloud sharing/merge, or sunlight-driven interval changes. Authenticated local-wins garden sync is implemented separately from reminder behavior.

### 15.2 Baseline before this feature and implemented change

Before this feature, `AppPreferences` stored reminderHour/reminderMinute with a 09:00 fallback, but Preferences exposed only the notification switch. New plants use the stored time for their first check. Completion previously added the profile/follow-up duration to the actual completion timestamp, so later checks inherit that clock time rather than a preferred daily time.

Previously, notifications carried only a plant ID and had no tap handler. This release implements the visible preference, consistent clock rule, and validated check-specific routing described below. STATUS.md records actual verification and platform limits.

### 15.3 Minimal Reminders flow

1. Keep the existing notification switch, labelled **Notifications**.
2. Add one **Reminder time** row in the Profile → Reminders section, displaying the saved time in the device's 12/24-hour format; keep 09:00 as the fallback for users who have never selected a time.
3. Tapping the row opens the native Flutter/Android time picker at the saved value. Its final confirmation saves the choice; no extra settings page, bulk-application questionnaire, or second confirmation dialog.
4. Explain the scope below the section: **Applies to future checks. Custom check times stay as they are.** (When legacy checks exist: **Custom and older check times stay as they are.**) The full rule, including today's checks, is in 15.4.
5. The row remains available when notifications are off or permission is denied. Choosing a time does not enable notifications or request permission. When the switch is on but Android notifications are blocked, show **Android notifications are off** with **Open Android settings**. In-app check times still follow the confirmed preference policy.
6. Cancellation or choosing the unchanged value is a no-op. Persist before displaying a newly saved value or updated schedule. A failed save keeps the old preference/dates, explains failure, and allows retry. Avoid repeated taps while saving.

The bulk time effect is disclosed inline and accepted through the time-picker confirmation, keeping the flow to one choice.

### 15.4 Apply the preference without changing custom or today's times

**Confirmed by the user on 15 November 2026:** Include existing future checks, but preserve timings explicitly set by the user and preserve today's existing checks. This replaces the earlier draft that would have overwritten custom times and changed today's time when still ahead.

| State immediately before the preference is saved | Required behavior |
| --- | --- |
| Explicitly automatic check on a later local calendar day | Keep that day; replace its hour/minute with the new preferred time. |
| User-customized next check, on any day | Preserve its exact saved date/time, even when its time happens to match the old global preference. |
| Any existing check dated today | Preserve its saved timestamp, whether the new preferred time is earlier or later and whether it has already passed. |
| Check is already due/overdue | Preserve its timestamp; do not postpone unresolved care or send catch-up notifications. |
| Plant has no schedule | Save the preference; do not invent a schedule. |
| Older schedule whose time origin is not recorded | Adopted migration safeguard: preserve its current timestamp rather than guess whether the user customized it. |

The global preference must never overwrite a user-set custom time. This protection does not depend on how recently it was edited or whether it differs from the old preference. Existing checks dated today are also protected unconditionally; newly created automatic checks may use the newly selected preference even if their calculated day is today.

**Adopted one-off scope:** Interpret custom timing as the existing **Edit next check** date/time override, applying to that specific check. It stays protected from global preference changes, app startup/resume, and notification resynchronization until the check is completed or explicitly edited by the user. Completion creates a new automatic check using the preferred time. Recurring per-plant custom clock preferences remain outside this scope. Do not introduce an extra reset/override question in Profile → Reminders.

Save the preference and eligible changed timestamps atomically, then replace only eligible changed future reminders if enabled. Leave protected custom/today/overdue reminder trigger times unchanged. Preserve profile intervals, Last watered, existing records, and placement acknowledgment. Generate no care history and update schedule revision metadata only when a schedule actually changes. An unchanged preference remains a no-op.

**Legacy-data constraint:** Current saved schedules contain timestamps but no automatic/custom provenance. The adopted migration is to classify missing provenance as legacy/unknown and preserve those existing checks. After an explicit edit, classify that check as custom; after completion creates its successor, classify the new check as automatic. This means the first preference change after upgrade may leave older saved checks untouched. Explain that behavior briefly when relevant, without requiring users to classify their garden or inferring intent from timestamps/history. This migration safeguard was adopted when implementation was authorized.

### 15.5 New checks, local time, and daylight saving

Implemented clock rule: automatic checks use the preferred device-local clock time on the computed check day. Keep the same species interval and existing dry/non-watering follow-up days.

- Initial setup: use the existing known-last-watered/unknown-date calculation, setting the resulting day to the preferred time. An unknown history can still create a same-day due/overdue baseline; it does not trigger a retrospective reminder.
- Completion: compute the next local calendar day from the actual completion day plus the existing interval/follow-up days, then apply the preferred hour/minute. Last watered and recordedAt retain the actual event timestamp.
- Example: with a 14-day profile and an 18:30 preference, a check completed on November 15 produces a November 29 check at 18:30. This deliberately differs from the current rule that inherits the completion's clock time.
- A saved one-off next-check edit uses the user's selected timestamp and is protected from global preference changes, app startup/resume, and synchronization. Only explicit editing or completion replaces that check; its new automatic successor uses the global preferred time.
- Store the preferred wall-clock hour/minute, not a fixed UTC offset. Reconcile device timezone and pending reminders on app startup/resume; calendar check days should remain understandable in local time.
- Implemented DST policy: if a selected wall-clock time does not exist on that check day, use the first valid local time after the gap; if it occurs twice, use the first occurrence once. Do not issue duplicate reminders. Cover this with deterministic tests.
- If the device changes timezone while Bloom stays closed, reliable reconciliation is guaranteed only when Bloom next opens/resumes in this scope. Do not promise continuous background travel adaptation without implementing and verifying it.

The same preferred clock applies to future automatic **Watered** and **Checked — not watered** scheduling. This is a clock-time change, not a change to interval length, soil rules, or the separate deferred light-adaptation policy.

### 15.6 Notification tap and navigation contract

Use the existing one-shot watering reminder, titled **Check & water**, with the body **Check <plant>'s soil before deciding whether to water.** so plants are distinguishable. The reminder still asks the user to inspect soil; it never instructs automatic watering.

For a valid current check:

- If Bloom is closed, load the garden, mount Home, then open the matching Check & water screen. Navigation cannot depend on a live screen context before startup completes, and notification setup failure must not block Home.
- If Bloom is backgrounded or already open, handle the tap and open the matching current check once. If that same check is already on top, reuse it without clearing user selections or pushing another copy.
- Cold-launch Back/Cancel returns to Home. Warm navigation uses the existing app stack and preserves unfinished work underneath rather than silently saving/discarding it. No additional confirmation dialog is required just to open a reminder.
- Opening a reminder changes no task state or date, creates no history, selects neither watering outcome, and does not enable notifications.
- Deduplicate the same event if startup launch details and a live callback both deliver it. Merely launching the app normally must not replay a previously consumed notification.

Resolve against **current local data**, not a cached plant object. A notification is about a specific scheduled check, not every later check belonging to that plant.

| Tap target | Destination |
| --- | --- |
| Plant exists; payload identifies its still-current check, including a now-overdue one | Open that Check & water screen. |
| Plant exists; its check was completed, edited, or rescheduled after the notification was created | Open plant detail showing the current schedule with a brief message that the reminder is out of date. Do not open a future replacement task as though it were the old task. |
| Legacy plant-ID-only payload | Open the identified plant's detail page, since the original check cannot be verified. |
| Plant was removed or no longer has a usable task/detail | Stay/open Home with brief unavailable feedback. |
| Payload is empty, malformed, unsupported, or not a recognized Bloom watering payload | Open/stay Home safely; do not infer a plant or follow an arbitrary route. |

Use lightweight inline/snackbar feedback for stale/unavailable cases, not blocking dialogs. If the target disappears while its page is open, retain a working Back/Home recovery path. Existing local notifications must fail safely after upgrade, and already-delivered notifications may remain tappable even after their pending request was cancelled.

### 15.7 Data, scheduling, and failure boundaries

- Reuse the existing preference fields; support changing them in copy/update/store operations and validate hour 0–23 and minute 0–59. Existing valid values survive upgrades; missing/invalid optional time data falls back without discarding the garden.
- Keep schedule transitions, bulk preference updates, and persistence in GardenStore. Screens and notification callbacks must not mutate domain state directly.
- Add explicit per-check time provenance (values: preference / custom / legacy). New automatic first/completed checks use preference; an explicit next-check edit uses custom even if the value matches the preference. Missing or unrecognized provenance is conservatively legacy. Persist and round-trip this metadata without rewriting existing timestamps.
- Adopt a versioned, bounded watering payload containing plantId and check identity/revision (for example scheduled timestamp plus schedule updatedAt). Validate all fields before navigation and compare with the current schedule. The payload carries data, never executable route instructions.
- Wire both running-app notification responses and notification-launched startup. Consume a queued launch target only when the repository, store, and Navigator are ready.
- After a successful preference change, replace enabled requests for eligible changed automatic checks. Preserve protected request trigger times and keep one pending watering reminder per plant with stable, collision-safe Android IDs. Do not send a burst for due/overdue history.
- Permission denial, disabled OS notifications, or a notification scheduling failure must not discard a successfully saved preference, block in-app tasks, or claim guaranteed delivery. Differentiate persistence failure from best-effort notification failure in feedback.
- Refresh permission/timezone status on relevant startup/resume/settings transitions without repeatedly requesting permission. Changing the time alone never asks for notification or exact-alarm access.

### 15.8 Acceptance criteria for this release

- Profile → Reminders offers one native time picker, correct current/default value, device-format display, cancellation, one-confirmation saving, and durable restoration after relaunch.
- Saving while notifications are off/denied works without turning them on or requesting permission.
- Only eligible automatic checks after today adopt a changed global clock. Custom times, all existing checks dated today, overdue checks, calendar dates, intervals, records, placement state, and Last watered remain unchanged.
- Custom protection survives relaunch and repeated global changes, including when custom time equals the previous preference. Provenance and protected timestamps survive JSON round trips.
- Legacy schedules without provenance are preserved under the reviewed migration rule; explicit edits mark custom and completed checks produce automatic successors. No timestamp-based guessing or new classification questionnaire.
- Preference and changed schedules commit together; save failure changes neither, and an unchanged value produces no write/reschedule.
- New first/completed checks use the preferred local clock on the calculated day, including the dry follow-up. The adopted one-off custom override ends only through explicit editing or completion of that check, not a global preference change.
- Today protection is tested with the newly selected time both before and after now, and with existing check times both future and overdue. Cover DST gap/repeat, timezone reconciliation, and no-duplicate/no-catch-up reminders.
- Valid taps open the correct check from closed, backgrounded, and foreground states, with useful Back/Cancel behavior.
- Current overdue targets remain actionable; completed/rescheduled/deleted/legacy/malformed targets follow the safe fallback table.
- Duplicate delivery opens one route, normal launch replays nothing, and tapping a reminder never records watering or changes a schedule.
- Existing light-placement acknowledgment continues to leave watering unchanged.
- Unit/widget tests cover time transitions, payload validation/navigation, failure, and duplicate events. Android tests verify real notification taps and persistence using isolated test installation/data.
- Accessibility review covers time formatting, TalkBack labels and selected states, large text, dark theme, and navigation. Device checks cover permission denial, inexact delivery, and app lifecycle.

### 15.9 Review completed and implementation authorized

The user authorized implementation on 15 November 2026 after the documents captured custom/today protection, conservative legacy migration, the one-off Edit next check lifecycle, preferred-clock completion, DST behavior, and stale/legacy routing. These rules are implemented without extra setup inputs. Current test/build evidence and remaining manual checks are in STATUS.md; earlier watering/placement evidence alone is not proof of this feature.

Timezone reconciliation refreshes the device zone and pending request conversion on startup/resume. It preserves saved check instants and does not bulk-rewrite existing custom/today/legacy timestamps after travel. New automatic checks use the current device-local preferred clock; continuous background timezone adaptation remains outside scope.

### 15.10 Technical references

Reviewed on 15 November 2026; implementation must use the versions pinned by the repository.

- [Android — Notification navigation](https://developer.android.com/develop/ui/views/notifications/navigation): preserve meaningful app navigation after a tap.
- [Android — Notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission): permission is distinct from an in-app preferred time.
- [Android — Schedule alarms](https://developer.android.com/develop/background-work/services/alarms): inexact delivery has platform and battery constraints; do not promise an exact minute.
- [flutter_local_notifications 23.0.2](https://pub.dev/packages/flutter_local_notifications/versions/23.0.2): separate response callbacks and notification-launch details, zoned scheduling, and pending-request management. The installed package documentation was also inspected.

## 16. Occasional care — product direction

**State:** Light presentation is implemented under section 17 (revised 17 November 2026). Soil care is record-only under section 18; the advisory Soil health questionnaire (D45–D49) was removed on 17 November 2026 (D51).

Check & water remains the primary frequent journey. Light placement and soil care are occasional and progressively disclosed. Soil care offers three distinct, potentially overlapping recorded actions — **Added nutrients**, **Refreshed potting mix**, and **Repotted** — without assessing whether they are needed.

### 16.1 Light placement is also occasional

The user clarified that suitable light placement is ordinarily established once and revisited occasionally, not performed frequently. Keep watering primary and add no recurring light task, relocation prompt, acknowledgment expiry, or automatic reset. Preserve the optional Light & placement guidance during setup and on the plant page, including its saved user-reported confirmation and unchanged watering behavior. See D42 and section 17.


## 17. Light & placement — occasional-care presentation refinement

**State:** First authorized on 15 November 2026 (D44) as a collapsed card; revised on 17 November 2026 into the plant page's Care guide (D55). Verification is recorded in STATUS.md.

- Setup shows the full guidance: requirement, room-scene illustration, the profile's placement text, and the optional **I've placed it as suggested** checkbox, under **Light & placement · optional**. No extra setup page or input.
- On the plant page, the **Care guide** lists the profile's watering cue and a light row showing the light requirement. The light row is collapsed by default on every visit; a confirmed plant shows a check mark on the row.
- Expanding the row shows the room-scene illustration (spot **By the window**, **A few steps in**, or **Deeper in the room**, mapped from the profile's light requirement text), the profile's placement text, and either **Is it in a spot like this?** with **Yes, it is** / **Not yet**, or the confirmed state **In a good spot · Confirmed <date>** with **Change**.
- When the saved guidance version differs from the current profile, the expanded row asks again: **The advice was updated. Is it still in a spot like this?**
- Bloom adds no light advice beyond the profile text. The illustration is a visual summary of that text, not a measurement.
- Expansion is transient presentation state. Expanding, collapsing, and **Not yet** never save, clear, or timestamp the confirmation and change no watering or notification state.
- **Yes, it is** and **Change** keep immediate persistence, old state until success, **Saving…** feedback, duplicate-write prevention, and failure feedback/retry.
- Support long labels, narrow screens, large text, light/dark themes, and existing back behavior. The illustration has a TalkBack label naming the best spot.
- No recurring light reminders, confirmation expiry, relocation nudges, measurement, assessment, or automatic watering changes.

Acceptance: the light row starts collapsed in both states; expanding reveals the scene, advice, and the correct question/confirmed state; collapse/review/Not yet perform no write; setup remains fully visible/skippable; success/failure/correction and reload preserve data semantics; large-text/dark layouts remain usable.


<a id="18-soil-health--release-requirements"></a>
## 18. Soil care — release requirements

**Documented:** 15 November 2026 as Soil health. **Revised:** 17 November 2026 — the advisory questionnaire was removed; Bloom does not diagnose soil health (D51). The record-only flow below is the current contract.

### 18.1 Problem, goals, and boundary

Users want to remember occasional soil work they did. Bloom records what the user reports doing; it does not assess nutrient sufficiency, mix condition, drainage, or root space, and it does not recommend whether an action is needed.

### 18.2 Three actions and their meanings

| Recorded label | Meaning in Bloom | Distinction and overlap |
| --- | --- | --- |
| Added nutrients | Deliberately applying a nutrient source, such as a suitable fertilizer or nutrient amendment. | Different from changing mix structure. Do not infer this action from a product name. |
| Refreshed potting mix | Replacing some or all of the existing growing mix with fresh mix. | Can be done while retaining the same pot. Adding fertilizer alone is not a mix refresh. |
| Repotted | Removing and replanting the plant, in the same or another pot. | May overlap with a mix refresh and/or nutrient addition. |

These are record categories, not diagnoses or tasks.

### 18.3 Entry

- **SH-01:** The plant page's **Soil care** quick action opens **Record soil care**. There is no Soil health section, assessment, Home task, setup field, or attention badge.

### 18.4 Assessment — removed

The version-1 advisory checks (nutrient needs, potting mix, pot/root space) were removed on 17 November 2026. Their rationale remains in D45–D49 as history.

### 18.5 Drainage and adjacent topics

Drainage, aeration, salts/pH, environmental care, and pest/disease triage are not assessed. Any future assessment needs a new reviewed decision.

### 18.6 Recording performed care and overlap

- **SH-07:** One care event holds one or more explicitly selected actions (**Select everything you did.**). A combined event is saved once and shown once in history.
- **SH-08:** No action is preselected or inferred from another.
- **SH-09:** Minimum input: at least one action and the actual care date (**When**, defaulting to today; future dates are not selectable). Optional **Details**: fertilizer or amendment name (shown when Added nutrients is selected; 120 characters), **Fresh mix contains fertilizer?** Yes/No/Not sure (shown when Refreshed potting mix is selected), and notes (500 characters). **Save** is pinned at the bottom and disabled until an action is chosen.
- Save before showing success. Back on a dirty form uses the discard guard (section 20); a failed save keeps the draft for retry. Prevent duplicate in-flight submissions.
- Tapping a soil-care entry in the plant history opens **Edit soil care**, which also offers **Remove record** after confirmation. Removal does not change watering.

### 18.7 State, persistence, and boundaries

- **SH-10:** Store soil-care events separately from watering records, through the atomic persistence boundary. Old garden JSON loads with no soil-care history and all other data intact.
- **SH-11:** Recording soil care must not mark Watered, change Last watered, clear a watering task, alter an interval or custom check time, reset light placement, or enable notifications.
- **SH-12:** No recurring feeding, mix-refresh, or repotting reminders, no health score, and no automatic treatment.

### 18.8 Acceptance criteria

1. Each action alone and every combination of the three can be saved as one event; nothing is preselected; cancellation/failure/duplicate-save behavior is correct.
2. Old JSON and overlapping records round-trip; saves are atomic; watering dates/history/Last watered, custom times, reminders, and light confirmation are unchanged by soil care.
3. No recurring task, notification, badge, health score, or advisory result exists.
4. Large text, narrow/dark layouts, screen-reader labels, and Back behavior keep all choices usable.

### 18.9 Evidence and content review

The references reviewed on 15 November 2026 informed the action distinctions above; they are retained for any future, separately approved guidance.

- [Wisconsin Extension — Houseplant care](https://hort.extension.wisc.edu/articles/houseplant-care/)
- [RHS — Growing media for houseplants](https://www.rhs.org.uk/plants/types/houseplants/growing-media-houseplants)
- [University of Minnesota Extension — Fertilizing and watering container plants](https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/fertilizing-and-watering-container-plants)
- [University of Maryland Extension — Mineral and fertilizer deposits](https://extension.umd.edu/resource/mineral-and-fertilizer-salt-deposits-indoor-plants)

### 18.10 Adopted decisions and limits

Combined-event recording, date-only `occurredOn` plus UTC `recordedAt`, optional context, and edit/remove of soil events remain as adopted under D49. The advisory parts of D49 are superseded by D51.

### 18.11 Version-1 advisory rules — removed

Removed on 17 November 2026 (D51). Do not reintroduce questions, results, or recommendations without a new reviewed decision.

## 19. Per-plant history

**State:** Introduced as Care timeline on 15 November 2026 (D48); restyled on 17 November 2026 as **<plant> history**. Evidence in STATUS.md.

- **TL-01:** The plant page's **History** section shows the last five entries; **See all** (or tapping an entry) opens the full **<plant> history** page. Back returns to the plant page.
- **TL-02:** Show all records for that plant, newest first, grouped under month headers. Watering uses the actual recorded time, not due time. Soil events show the actual care date without inventing a clock time.
- **TL-03:** Entries: **Watered**, **Checked — not watered** (with soil feel), combined soil care (once, with selected actions and optional context), **Light placement confirmed** (the current saved confirmation snapshot only), and **Growth photo** (with thumbnail). Rows use a round icon badge, or the photo thumbnail for photos.
- **TL-04:** Tap a soil-care entry to edit/remove it; tap a photo to open the viewer; tap the latest watering record to delete it after confirmation (**Delete this record? Last watered and the next check may update.**), followed by a snackbar with **Undo**. Older watering records are read-only. A chevron marks tappable rows.
- **TL-05:** Empty state: **No care recorded yet** / **Checks, care and photos will appear here.** No fabricated milestones, reminders, or unfinished checks appear as completed care.
- **TL-06:** Reading history never creates or changes care, schedules, notifications, or preferences. Deleted targets show **Plant unavailable** with **Go to Home**.
- **TL-07:** Support long combined labels/notes, large text, narrow/dark layouts, and device-formatted local dates.

Acceptance: correct plant filtering, ordering, and month grouping; combined jobs once; current light confirmation honestly labelled; latest-watering delete/Undo updates Last watered and the next check; empty/deleted states; live updates after edits; nested Back; no read-side writes.

## 20. Back navigation and unsaved-form protection

**State:** Explicit user request, implemented and verified on 15 November 2026; D48 defines the contract.

- Use native Android **back arrows** for page navigation, on Profile, Add a plant, setup, Check & water, history, and soil care pages. On the plant page the back arrow sits on a translucent round background over the hero photo. Native dialogs/pickers retain their ordinary Cancel actions. Use normal nested routes rather than fullscreen-dialog treatment for Check & water. Photo identification uses a Close action and asks **Discard this photo?** (**Keep editing** / **Discard photo**) when a photo or result would be lost.
- **NAV-01:** Clean forms and read-only pages return immediately to their parent. Home remains the navigation root; successful Add still returns Home, and successful recorded checks return to the caller.
- **NAV-02:** Toolbar Back and Android system Back from a dirty form show one dialog: **Discard changes?** with **Keep editing** and **Discard changes**. Dismissing the dialog also keeps the form. Keep editing preserves all draft selections/text/date. Discard exits without writing.
- **NAV-03:** Dirty means a change to unsaved form values compared with their initial values. Covers plant setup's optional watering/placement inputs, Check & water outcome/soil, and soil-care action/date/context/notes edits. Returning all fields to their initial state is clean.
- **NAV-04:** An in-flight save is not a discardable draft: wait for it to finish, showing saving feedback if Back is attempted. A successful save releases the guard and exits without a spurious discard dialog; failure preserves the draft and allows retry or confirmed discard. Guard repeated Back presses against duplicate prompts.
- **NAV-05:** The guard does not roll back actions already saved immediately, such as next-check edits, Reminders settings, or plant-page placement confirmation. New nested routes preserve unfinished work beneath them. An invalid reminder must not forcibly pop dirty forms; show unavailable feedback in place in that case.

Acceptance: toolbar/system Back, keep/discard/dismiss, clean/reverted state, save success/failure/in-flight handling, nested page return, no duplicate prompt, preserved draft underneath reminder navigation, and no accidental care records from leaving. Android predictive Back may not preview a pop while a dirty form is guarded; manual TalkBack and physical-gesture audit remains separate from automated checks.

## 21. UX overhaul — current screen contract (17 November 2026)

**State:** Approved by the owner on 17 November 2026 as an explicit exception to the stabilization freeze, implemented on main. Decisions D50–D62 record the rationale. Where earlier sections describe different screen wording, this section and the revised sections above are current. Shared visual rules are in DESIGN_GUIDELINES.md.

### 21.1 Home

- Header: greeting (**Good morning / Good afternoon / Good evening**) above **Your garden**, with **+** (Add plant) and an avatar with the email initial (opens Profile).
- **Today** card (filled primary green): **N plants to check**, one row per due or overdue plant with photo, relative date, and a **Check** button. When nothing is due: **Nothing to check today**.
- **My plants · N**: two-column photo grid (plant image, name, relative next check; **Overdue** status in red) ending with an Add plant tile. Long-press or **Select** enters multi-select; the toolbar shows **N selected**, Select all, and Delete selected. One confirmation (**Delete N plants?** — care history and photos are deleted too) removes them all.
- **Recent**: the last three activities across plants with **See all** (Recent activity page).
- Empty Home: image, **Add your first plant**, **Bloom reminds you when to check its soil.**, and **Add plant**.
- **+** opens a bottom sheet: **Search by name** / **Identify from a photo**.

### 21.2 Add a plant

- Search bar (**Search plants, e.g. fern**) with live filtering across common name, scientific name, and aliases; name matches rank first (prefix, then contains). Result count or **No matches** is shown.
- Before typing, five curated **Popular plants** are shown (Pothos, Snake Plant, Monstera, Spider Plant, Rubber Plant). The list is fixed, not usage-based.
- Setup: species photo, **Last watered · optional** (switch **I know when I last watered it** plus date), **Light & placement · optional** (section 17), and **Add plant** pinned at the bottom.

### 21.3 Plant page

- Collapsing hero photo (cover growth photo, else catalog image). Back and ⋮ sit on translucent round backgrounds. ⋮ offers **Edit** (name and plant image: default image or a growth photo) and **Delete** (red, with confirmation). A photo-count chip opens the growth gallery.
- Name and italic scientific name, then the status card: **Next check** with a relative date (tap to change date/time), **Last watered N days ago** (or **not recorded**), and the primary **Check & water**. The card is tinted only when the check is due or overdue. Plants without a care profile show **No care guide yet. You can still log care and add photos.**
- Quick actions: **Add photo** (a dot badge when there is no photo in the last 30 days) and **Soil care**.
- **Care guide**: the profile's watering cue and the light row (section 17). No advice beyond profile text.
- **History**: last five entries with **See all** (section 19).

### 21.4 Growth photos

- Taken with the camera or chosen from the gallery; stored as files on the device and listed in the garden JSON as device-only data. Photos and the chosen cover are never synced.
- After adding: a snackbar with **Use as plant image**. The viewer offers delete (**Delete this photo?** — removed from this device) and **Use as plant image** / **Use default plant image**. The gallery (**<plant> growth**) shows all photos.
- Photo files are deleted with the plant (single or multi-select) and with the account.

### 21.5 Check & water

- Plant header with thumbnail, name, relative due label, and **Edit next check**; the profile's watering cue when available.
- **What did you do?** as two choice cards: **Watered** and **Checked — not watered**. Neither is preselected.
- **How did the soil feel?** (Dry / Damp / Not sure) only when not watered.
- **Save** pinned at the bottom, disabled until an outcome is chosen. Errors appear inline. On success the screen closes and a snackbar confirms the outcome and next check date. Watering is never recorded unless **Watered** is chosen.

### 21.6 Photo identification

- **What plant is this?** with **Take a photo** / **Choose from gallery** tiles and the hint **A clear photo of the leaves works best.**
- The chosen photo shows a **Change photo** chip and in-place progress (**Comparing with plant references…**); **Identify** is pinned at the bottom.
- Results: photo thumbnail with **Retake**; the best match as a featured card (with the catalog image when the species is in Bloom) and other matches as compact rows. Likelihood labels replace percentages: **Very likely** (score ≥ 60%), **Possible** (≥ 25%), **Less likely**. Matches without a reviewed profile say **no care guide yet**. The best match is preselected; one pinned **Add <name>** button continues. No matches offers **Try another photo**.
- Adding an unreviewed match asks for confirmation and creates no watering schedule (8.2).

### 21.7 Naming

- **Check & water** is the task everywhere: plant-page button, Check screen title, and notification title. Home uses **Check** on each due row.
- **Soil care** is the secondary care action. **Reminders** is the Profile section for notification settings.

### 21.8 Data safety

- If `garden.json` cannot be read, it is copied to `garden.unreadable-<timestamp>.json` before an empty garden is used, so later saves do not destroy the original.

### 21.9 Out of scope for now

Dropped by the owner on 17 November 2026: special handling for multiple plants of the same type, a watering-frequency presentation, and the "Babbu" item. Do not implement without a new decision.
