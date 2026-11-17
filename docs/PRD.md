# Bloom — Android product requirements

**Status:** Watering, Light & placement, Profile/Preferences, reminder navigation, Soil health, Care timeline, guarded Back, dynamic theming, authenticated Supabase/PlantNet integration, email/password and Google authentication, and local-wins cloud sync are implemented. Verification evidence and remaining manual checks are in STATUS.md.
**Product:** Bloom for Android, a local-first Flutter app
**Owner:** Bloom product team
**Last updated:** 17 November 2026

The full product decision record—including alternatives, tradeoffs, future care-domain boundaries, and decision-revisit triggers—is in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). Sections 1–13 describe the watering baseline. Section 14 specifies the approved Light & placement release, now implemented with watering dates unchanged. Verification evidence and remaining checks are in STATUS.md. Section 15 specifies the reviewed reminder-preference and notification-navigation scope, authorized and implemented on 15 November 2026. Section 18 defines the Soil health release; sections 19–20 define the plant timeline and guarded Back navigation. The user subsequently authorized all three and confirmed integrated drainage. Current verification is recorded in STATUS.md.

## 1. Product summary

Bloom helps plant owners remember which plant to check, record what they actually did, and know when to look again. The first product loop is intentionally narrow:

> **Schedule a check → inspect the plant → choose Watered or Checked — not watered → schedule the next check.**

A date is a prompt to inspect the plant, not proof that the plant needs water. Bloom keeps the user in control and avoids presenting a calendar rule as a diagnosis.

## 2. Product and platform boundary

- The active product is the Flutter Android app in this repository.
- Garden data is stored locally on the device as JSON.
- Notifications are optional and Android-specific in the current implementation.
- Configured builds require authentication before Home. Supabase Auth supports Google and email/password registration/sign-in; unconfigured builds remain local-only for development and tests.
- The login page is a single, context-independent entry screen: email/password is the primary form, Google is a secondary option when configured, and the normal page has no toolbar Back button. A configured build shows it at startup whenever no valid session exists.
- The login page uses the existing plant artwork as its brand mark, and the Android launcher icon uses the same Snake Plant artwork.
- Registration requires a one-time six-digit email OTP. The confirmation state has a code field, **Verify email**, **Send code again**, and a Back arrow to return to registration. Successful OTP verification immediately creates the session and continues to Home; later logins use email/password without OTP.
- Local garden JSON remains the immediate source of truth. Authenticated local saves queue asynchronous cloud sync; the local payload is authoritative and guarded-overwrites differing cloud data by revision.
- Plant identification is available through the authenticated Supabase Edge Function when its endpoint is configured. PlantNet keys never ship in Flutter or the APK.
- There is no analytics service, live weather, device-location inference, sensor integration, or automatic watering hardware.
- The active plant inventory is data-driven. Profiles are managed in Supabase `plant_profiles`/`plant_profile_aliases` and cached from the bundled versioned catalog for offline use. Only profiles marked reviewed receive automatic care schedules.
- The historical iOS screenshots in `docs/previews/` are not current product behavior.

## 3. Current implementation baseline

The following behavior exists in the current Android code:

- Home shows **My plants** and **Activity → Upcoming / Past** after a plant is added.
- The catalog contains Snake Plant, Monstera, Rubber Plant, Pothos, and Spider Plant.
- A plant's reviewed care type is determined by its canonical profile, not by whether it was added from the catalog or identified from a photo. Separate physical plants retain separate IDs, while matching types share the same reviewed name, scientific identity, image, schedule interval, care cue, and light guidance.
- Setup may accept a past last-watered date; otherwise the first check is created today at the saved reminder time (09:00 initially).
- Each supported plant receives one active schedule with a profile starting interval.
- Upcoming tasks are classified as Today, Upcoming, or Overdue.
- A check records exactly one of **Watered** or **Checked — not watered**.
- Soil may be Dry, Damp, or Not sure.
- A dry **Checked — not watered** outcome schedules a three-day follow-up. Other outcomes use the plant profile interval.
- Watered updates Last watered. Checked — not watered does not.
- The next check is based on the actual recorded event, while the record retains the originally scheduled time.
- Users can edit a future next-check date and time.
- Users can remove a plant; removal also removes that plant's local schedule and watering records.
- Past shows completed watering records, with the most recent five shown on Home.
- Notifications are synchronized for future checks only. Denying permission leaves in-app tasks available.
- Plant setup and detail share species-specific light suggestions and one optional action acknowledgment.
- Acknowledgment persists per plant with its timestamp and guidance version; existing plants default to unacknowledged.
- Setting or clearing placement leaves watering state and existing reminders unchanged.
- Plant details opens a dedicated Care timeline and provides compact Soil health checks and explicit combined care records.
- Native page Back navigation protects dirty forms with Keep editing / Discard changes.
- The Add plant FAB menu offers Search by name and Identify from a photo. Configured builds can upload selected photos to the authenticated Edge Function and display normalized possible matches; unconfigured builds retain local photo intake only.
- Profile contains account controls and a focused Preferences section for reminder and notification settings. Cloud synchronization remains background behavior rather than a separate user-facing section.

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
- Automatic nutrient/repotting schedules, chemistry treatment, pruning, or disease-treatment flows. Explicit on-demand Soil health is included in section 18.
- Sharing, social features, analytics, community schedules, and cloud merge/sharing beyond local-wins synchronization.
- Watering-specific search/filters and global history correction. The per-plant Care timeline is explicitly authorized in section 19.

## 6. Supported profiles

These are check-in profiles, not universal watering instructions. Actual needs vary with pot size, drainage, medium, light, temperature, humidity, season, and plant size.

| Plant | Scientific name | Check-in range | Starting interval |
| --- | --- | ---: | ---: |
| Snake Plant | *Dracaena trifasciata* | 14–30 days | 21 days |
| Monstera | *Monstera deliciosa* | 7–14 days | 10 days |
| Rubber Plant | *Ficus elastica* | 7–21 days | 14 days |
| Pothos | *Epipremnum aureum* | 7–21 days | 14 days |
| Spider Plant | *Chlorophytum comosum* | 7–14 days | 10 days |

The range and starting value are versioned product content. Updating profile content must not silently rewrite saved schedules, records, or recorded dates.

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
- show the record in Past.

For **Checked — not watered**:

- create a care-check record;
- leave Last watered unchanged;
- resolve the current task as a check, not a watering event;
- use a three-day follow-up when the soil is dry;
- use the normal profile interval for Damp or Not sure;
- show the result in Past.

### Overdue and editing

- An untouched task remains Overdue; it does not move forward every day.
- An overdue task does not mean the plant must be watered.
- Completing an overdue task anchors the next check day to the actual completion day, using the preferred reminder clock (section 15).
- Editing the next check changes future timing only. It creates no history record and does not imply that watering occurred.
- Past records retain scheduled and recorded times separately.

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
- Home opens **Profile** through a user/account icon. Profile contains account controls, with reminder and notification controls grouped under **Preferences**; cloud synchronization is intentionally not shown as a separate section.
- After a successful local persistence operation, Bloom queues cloud synchronization asynchronously. Local UI and local data do not wait for a network request, and a failed cloud write never rolls back or removes local data.
- The cloud stores one versioned garden payload per authenticated user. An empty cloud row receives the local payload. If cloud and local payloads differ, the local payload is authoritative and replaces the cloud payload only through a revision-checked update; bounded retries handle a concurrent remote write.
- Cloud sync does not download or replace the local garden, and it does not expose a merge/conflict screen under this release policy. Sign-out requires confirmation, preserves local data, stops authenticated cloud writes, and returns to the root login landing screen.
- Signed-in users can open Profile → Privacy and choose either **Delete all plant data** or **Delete account and all data**. Both require two explicit confirmations. Delete all plant data removes the authenticated cloud garden through `delete-garden`, clears the local garden, and keeps the login account/session. Delete account and all data removes the cloud garden and auth account through `delete-account`, clears the local garden, and returns to the login landing screen. If cloud deletion fails, local data is preserved and the user receives a retryable error.

### 8.2 Photo identification boundary

- When `PLANT_IDENTIFIER_ENDPOINT` is configured, selected photos are sent only to the authenticated Supabase Edge Function, which proxies PlantNet and returns normalized possible matches.
- The PlantNet API key is server-side only. Identification results are candidates, not diagnoses or care instructions.
- The user must confirm a candidate before adding it. Supported reviewed identities can use existing setup; unsupported identities may be saved without an invented watering schedule. Temporary identification photos are not saved to user Storage by the current app.
- Provider/common-name aliases for reviewed catalog plants are normalized to the canonical profile at the GardenStore boundary. Existing saved variants are normalized when loaded without merging separate plant records.
- Each physical user plant stores a stable `plantTypeId` reference and retains its own schedule/history. Discovery path never determines care behavior.

## 9. Accessibility and interaction requirements

- Use Android Material 3 controls and navigation.
- Keep interactive targets at least 48dp.
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
- name
- species
- asset
- lightPlacement (optional acknowledgment timestamp and guidance version)

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
- reminderHour / reminderMinute (editable in Profile → Preferences; initially 09:00)
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
- Next-check editing changes timing without adding Past history.
- Remove plant removes its schedule and records after confirmation.
- Relaunch preserves plants, schedules, records, and notification preference.
- Permission denial does not remove in-app work.
- The debug APK builds and launches on an Android emulator.
- Focused automated domain tests cover the schedule transitions and persistence failure behavior.
- TalkBack and large-font review do not hide or change the meaning of the primary actions.

## 12. Roadmap

Only add a later capability after the watering loop is reliable and validated.

1. **Verification hardening:** automated domain tests, Android build/emulator checks, notification timing, date entry, persistence recovery, and accessibility review.
2. **Reminder control and navigation — implemented:** a global reminder-time preference and direct notification entry to the relevant watering check; see section 15. Latest-record correction remains separate future work.
3. **More reviewed plant profiles — deferred:** Five reviewed catalog profiles are currently shipped; additional catalog content requires a future scope decision.
4. **Light & placement — implemented:** species-specific light suggestions during setup and on detail, with one optional saved acknowledgment and unchanged watering dates; see section 14. Adaptation and broader environmental checks remain deferred.
5. **Soil health — implemented:** on-demand help for Adding nutrients, Refresh potting mix, and Repotting, with distinct actions and explicitly recorded overlap; see section 18. Drainage is an approved cross-cutting check, not a fourth care action. Symptom diagnosis remains separate future scope.
6. **Cloud sync — implemented:** configured builds authenticate users and asynchronously synchronize local-authoritative garden payloads with revision guards. Sharing and merge features remain deferred.

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
- Label both **Last watered** and **Light & placement** headings with **Optional**, using matching secondary typography and spacing. Both inputs remain skippable; this consistency decision was confirmed on 15 November 2026.
- Show the species' recommended light and a short practical placement suggestion immediately. The user does not have to answer a question to see it.
- Use one optional, initially unchecked acknowledgment, labelled **I've placed it as suggested**. It means the user acted on the suggestion, not merely read it. It also applies when the plant was already in a suitable position.
- The user may leave it unchecked and press the existing **Add** action. Do not require a separate Skip action, add a page, preselect acknowledgment, or block adding the plant.
- Keep the choice in setup state until Add. On Add, save the plant, its normal starting watering schedule, and the acknowledgment if supplied in one store/persistence transaction. Cancelling setup creates no plant or saved acknowledgment.
- The existing Last watered input and first-check calculation remain available. Placement acknowledgment has no effect on that first check in this release (14.5).

### 14.3 Plant detail and later acknowledgment

- Keep **Watering** primary. On plant detail, show a collapsed **Light & placement** card after Watering, with the species light requirement and saved placement status. Expanding reveals the same placement advice and optional checkbox used in setup; collapse/review writes no data. See section 17 for the approved presentation refinement.
- Show the saved acknowledgment state. A plant added without acknowledgment offers the same optional input here, so the user can act and confirm later.
- Checking **I've placed it as suggested** saves immediately through the store, with no extra Save page or confirmation dialog. Publish the selected state only after persistence succeeds; show a concise error and allow retry after failure.
- On reopening or relaunching, show the saved state. Do not repeatedly prompt users who have skipped it; the inline option remains available.
- Correction behavior: the same control can be unchecked if the user acknowledged by mistake or the statement is no longer accurate. Clearing it returns to unacknowledged; it does not claim that the light is unsuitable. Watering dates remain unchanged when it is cleared (14.5).
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

Both setup and plant detail use the same store/persistence boundary. Save failure preserves the previous garden and leaves the input retryable. Preserve all unrelated plants, schedules, records, and preferences. Plant removal removes its acknowledgment with the plant. Relaunch restores it. A future guidance revision preserves the saved acknowledgment and its version, without changing dates or claiming agreement to updated copy. When versions differ, show a quiet inline note that the acknowledgment refers to earlier guidance; the user may clear and re-check after following updated advice. No automatic expiry or reminder.

### 14.7 Acceptance criteria

- Every supported species has a reviewed short light requirement and practical position suggestion, displayed consistently in setup and detail.
- The only added input is the optional action acknowledgment. There are no dim/bright choices, placement questionnaire, or required light setup steps.
- The acknowledgment starts unchecked; the user can add a plant without it and confirm later on detail.
- Setup cancellation writes nothing. Add saves the chosen state with the plant; detail acknowledgment persists and survives relaunch.
- Skipping the input remains unacknowledged, never a negative light assessment. Acknowledgment means acted, not just read.
- Unchecking clears only acknowledgment. Older guidance acknowledgments retain their timestamp/version with an inline explanatory note; no automatic reconfirmation prompt.
- Failed saves preserve existing data, expose useful retry feedback, and do not show a falsely saved acknowledgment or schedule.
- Reading advice or leaving without acting changes no state or date. Existing plants load with acknowledgment absent by default.
- Setup and later acknowledgment, correction, and repeated confirmation preserve all watering state and trigger no notification synchronization.
- No placement interaction changes an existing reminder, creates a light reminder, or re-enables notifications.
- TalkBack, large text, narrow widths, dynamic light/dark themes, and Android back support both placements of the input.
- Authorization to implement was given on 15 November 2026 after the watering policy was resolved. Verify implementation against this approved scope.

### 14.8 Approval and future work

The user confirmed the simplified proposal, resolved watering dates as unchanged, and explicitly authorized implementation on 15 November 2026. Use one optional acknowledgment in setup/detail, immediate persistence on detail, correction through the same control, and versioned acknowledgment as documented above. Keep scheduling adaptation and any change to the damp/non-watering default as separate future product work. Do not expand implementation into the superseded concern picker or a new scheduling system.

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

Let the user choose a useful time for watering reminders from Preferences, then reach the relevant plant's watering check by tapping a notification. Keep one app-wide time, one existing watering schedule per plant, and the existing optional notification switch. Add no onboarding or required plant-setup input.

Selected scope:

- One **Reminder time** preference in Profile → Preferences, applying to all plants.
- Changing it updates eligible **existing automatic future checks on later days** and newly scheduled automatic checks. **Custom timings, today's existing checks, and overdue checks remain unchanged**, as clarified by the user.
- A valid notification tap opens that plant's **Check watering** screen.
- The documents were reviewed before implementation was explicitly authorized; keep them aligned with the code.

Not included: per-plant recurring time preferences, daily digests, repeated overdue nudges, snooze, notification buttons that record watering, new care reminders, exact-to-the-minute delivery, backup/restore, cloud sharing/merge, or sunlight-driven interval changes. Authenticated local-wins garden sync is implemented separately from reminder behavior.

### 15.2 Baseline before this feature and implemented change

Before this feature, `AppPreferences` stored reminderHour/reminderMinute with a 09:00 fallback, but Preferences exposed only the notification switch. New plants use the stored time for their first check. Completion previously added the profile/follow-up duration to the actual completion timestamp, so later checks inherit that clock time rather than a preferred daily time.

Previously, notifications carried only a plant ID and had no tap handler. This release implements the visible preference, consistent clock rule, and validated check-specific routing described below. STATUS.md records actual verification and platform limits.

### 15.3 Minimal Preferences flow

1. Keep the existing **Watering notifications** switch.
2. Add one **Reminder time** row in the Profile → Preferences section, displaying the saved time in the device's 12/24-hour format; keep 09:00 as the fallback for users who have never selected a time.
3. Tapping the row opens the native Flutter/Android time picker at the saved value. Its final confirmation saves the choice; no extra settings page, bulk-application questionnaire, or second confirmation dialog.
4. Explain the scope beside the control: **Applies to automatic checks after today. Custom times and today's checks stay unchanged.** Include a concise note that Android may deliver reminders later.
5. The row remains available when notifications are off or permission is denied. Choosing a time does not enable notifications or request permission. Explain in that state: **Turn on watering notifications to receive reminders.** In-app check times still follow the confirmed preference policy.
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

**Adopted one-off scope:** Interpret custom timing as the existing **Edit next check** date/time override, applying to that specific check. It stays protected from global preference changes, app startup/resume, and notification resynchronization until the check is completed or explicitly edited by the user. Completion creates a new automatic check using the preferred time. Recurring per-plant custom clock preferences remain outside this scope. Do not introduce an extra reset/override question in Preferences.

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

Use the existing one-shot watering reminder. Include the plant name in visible notification copy so plants are distinguishable. The reminder still asks the user to inspect soil; it never instructs automatic watering.

For a valid current check:

- If Bloom is closed, load the garden, mount Home, then open the matching Check watering screen. Navigation cannot depend on a live screen context before startup completes, and notification setup failure must not block Home.
- If Bloom is backgrounded or already open, handle the tap and open the matching current check once. If that same check is already on top, reuse it without clearing user selections or pushing another copy.
- Cold-launch Back/Cancel returns to Home. Warm navigation uses the existing app stack and preserves unfinished work underneath rather than silently saving/discarding it. No additional confirmation dialog is required just to open a reminder.
- Opening a reminder changes no task state or date, creates no history, selects neither watering outcome, and does not enable notifications.
- Deduplicate the same event if startup launch details and a live callback both deliver it. Merely launching the app normally must not replay a previously consumed notification.

Resolve against **current local data**, not a cached plant object. A notification is about a specific scheduled check, not every later check belonging to that plant.

| Tap target | Destination |
| --- | --- |
| Plant exists; payload identifies its still-current check, including a now-overdue one | Open that Check watering screen. |
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

- Preferences offers one native time picker, correct current/default value, device-format display, cancellation, one-confirmation saving, and durable restoration after relaunch.
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

**State:** Light presentation is implemented under section 17 / D44. The three Soil health actions are defined in the release requirements in section 18 / D45–D49; the user subsequently authorized implementation and confirmed integrated drainage.

Watering remains the primary frequent journey. Light and Soil health are progressively disclosed, occasional care. The earlier separate Adding nutrients / Pot & soil exploration is consolidated into one **Soil health** section with three distinct, potentially overlapping actions: **Adding nutrients**, **Refresh potting mix**, and **Repotting**. The adopted interaction and advisory rules, including integrated drainage, are specified in section 18. The sunlight-first refinement is complete; version-1 nutrient/mix/root-space checks are now implemented, with further content changes requiring review.

### 16.1 Light placement is also occasional

The user clarified that suitable light placement is ordinarily established once and revisited occasionally, not performed frequently. Keep watering primary and add no recurring light task, relocation prompt, acknowledgment expiry, or automatic reset. Preserve the existing optional Light & placement suggestion during setup and on detail, including its saved user-reported acknowledgment and unchanged watering behavior. The compact/expandable detail presentation was subsequently approved under D44 / section 17. Grouping under a new Other care destination remains outside that authorization. See D42.


## 17. Light & placement — occasional-care presentation refinement

**State:** Explicitly authorized by the user on 15 November 2026. Implemented and verified; evidence and remaining manual accessibility checks are recorded in STATUS.md. D44 records scope and rationale.

Watering is the frequent recurring task. Light placement is setup and occasional voluntary review, so its detail presentation should stay useful without occupying the same visual space on every visit.

- Setup retains the existing fully visible species suggestion and optional acknowledgment alongside optional Last watered. No extra setup page or input.
- Detail retains Light & placement after Watering. Each new detail page starts collapsed, whether acknowledgment is pending or recorded. The summary displays the light requirement plus **Not recorded · Optional**, **You've placed it as suggested**, or **Placement recorded for earlier advice**, according to saved state. These states describe the user's report, not verified light sufficiency.
- Tapping the card header expands/collapses the placement advice and existing **I've placed it as suggested** checkbox. Native Material expansion semantics expose the expanded/collapsed control. No nested settings page or mandatory prompt.
- Expansion is transient presentation state, not a persisted care record. Reopening detail starts compact again; the acknowledgment remains saved. Expanding/collapsing never saves, clears, or timestamps acknowledgment and changes no watering or notification state.
- Checking/clearing retains immediate persistence, old state until success, **Saving…** feedback, duplicate-write prevention, failure feedback/retry, and guidance-version handling. The section stays expanded after an acknowledgment change so the user can see the result and correct it.
- Support long labels, narrow screens, large text, light/dark themes, and existing back behavior. No truncated placement advice or checkbox label.
- No recurring light reminders, acknowledgment expiry/reset, relocation nudges, measurement, new assessment, or automatic watering changes. Adding nutrients and Pot & soil remain separate requirements work.

Acceptance: both saved/pending summaries start compact; expanding reveals full advice and the correct checkbox; collapse/review performs no write; setup remains fully visible/skippable; success/failure/correction and reload preserve existing data semantics; large-text/dark layouts remain usable. Run focused/relevant host checks, isolated placement Android regression, analysis, and the normal APK build. Preserve and verify the normal emulator garden during update.


## 18. Soil health — release requirements

**Documented:** 15 November 2026. **Stage:** Implementation explicitly authorized after the initial documentation-only pass. The user also confirmed drainage inside the checks while retaining three actions. D49 records the release defaults adopted under that authorization; implementation and verification are complete as recorded in STATUS.md.

### 18.1 Problem, goals, and agreement boundary

Users need help deciding whether an occasional soil-related action is warranted. Keep everyday watering direct and provide assessment-first help on demand. A date, generic symptom, or acknowledgment cannot establish nutrient sufficiency or the need to repot.

The user confirmed a separate **Soil health** section, three distinct actions with overlap, plain language, progressive disclosure, and integrated drainage checks. The implemented interaction follows the documented minimal approach: focused guidance, optional explicit multi-action recording, and local history. Soil-care correction/removal, unchanged watering, and conservative version-1 rules are the implementation defaults in D49; they do not add a fourth action, a diagnosis, or a feeding schedule.

### 18.2 Three actions and their meanings

| Action label | Meaning in Bloom | Distinction and overlap |
| --- | --- | --- |
| Adding nutrients | Deliberately applying a nutrient source, such as a suitable fertilizer or nutrient amendment. | Different from changing mix structure. Do not classify coco coir alone as a complete plant food or infer this action from a product name. |
| Refresh potting mix | Replacing some or all of the existing growing mix with suitable fresh mix. | Can be done while retaining the same pot. Adding fertilizer alone is not a mix refresh. |
| Repotting | Removing and replanting the plant to address pot/root-space needs or another supported reason. | May use the same or another suitable pot; does not always mean a larger pot. May overlap with a mix refresh and/or deliberate nutrient addition. |

These are action categories, not three diagnoses or three mandatory tasks. The name Soil health is a navigation/grouping label, not a measured health score. Plant-specific advice requires reviewed content for the current catalog; do not invent recommendations for unsupported plants.

### 18.3 Progressive disclosure and entry

- **SH-01:** Add a compact, initially collapsed **Soil health** section on plant detail, below existing watering/light content. Keep watering visually primary. Do not move Light & placement into Soil health.
- **SH-02:** Opening Soil health reveals on-demand checks for nutrient needs, potting mix, and pot/root space, with brief explanations linking them to the three actions. No new Home task, required Add plant field, auto-opening questionnaire, or attention badge.
- **SH-03:** Start with the concern the user chooses. Ask one relevant question at a time; reuse saved facts when useful, allow correction, and offer **I don't know** where needed. Ask only questions that can change the guidance. Do not require all three checks or a root inspection to use the app.
- **SH-04:** Return a short result with a reason and a useful next step. Draft result meanings: **No action suggested now**, **This action may help**, or **Inspect this first / more information needed**. No-action and uncertainty are valid stopping points. Do not force treatment or an extended questionnaire to finish.
- Reading, expanding, answering, abandoning a check, or receiving advice creates no completed-care record. No outcome is preselected as performed. A recommendation never asserts measured nutrient sufficiency, a definitive deficiency, or guaranteed recovery.

### 18.4 Assessment inputs and content contract

The table defines relevant evidence, not a diagnosis or a mandatory full questionnaire. Version-1 branches are specified in 18.11. They use the same conservative condition checks for the current five foliage-plant profiles and do not prescribe species-specific fertilizer formulations or infer measured conditions.

| Check | Relevant facts to consider when they affect guidance | Required limits |
| --- | --- | --- |
| Nutrient needs | Recent nutrient application and product directions; recent mix refresh/repotting; whether that mix already contains feed; reported active growth and relevant growing conditions. | Do not prescribe universal doses/intervals or diagnose deficiency from yellow leaves alone. Saved placement acknowledgment is not measured light. Product/feed uncertainty must not produce an automatic add-more recommendation. |
| Potting mix | Observable mix condition and wetting/draining behavior, recent mix changes, and possible overlap with watering or root-space issues. | Mix age or one symptom alone does not prove that replacement is needed. Do not prescribe one universal mix recipe or treat mix refresh as an infection cure. |
| Pot/root space | User-observed root crowding, pot/drainage context, and changes in plant/mix behavior that warrant inspection. | Plant height, time since purchase, or a root at a drainage hole alone must not trigger an automatic bigger-pot instruction. Do not force unpotting or assume larger is always better. |

- **SH-05:** Use source-backed, versioned guidance suited to the supported species and the available evidence. Missing history means **unknown**, not never fed/refreshed/repotted. Do not infer seasons from month alone or diagnose symptoms using a calendar rule.
- **SH-06:** Recognize overlapping concerns without routing users through every branch. Recent nutrient-containing mix can affect nutrient advice, but it does not establish a new fertilizer dose or prove that nutrient addition is needed. Show limitations plainly and link to only the next relevant check when helpful.
- Excessively wet mix, root distress, and unexplained decline must not be converted directly into a fertilizer recommendation. Detailed disease/pest diagnosis is outside this feature. Keep any limited inspection guidance within reviewed content.

### 18.5 Integrated drainage and adjacent topics

**Confirmed by the user:** include drainage as a cross-cutting condition within the checks, while retaining three care actions and no drainage schedule. The pot, growing mix, and watering context interact; a drainage concern does not automatically mean refresh the mix or repot. Roots need air as well as water; compaction and waterlogging can reduce air in the growing medium. [RHS growing-media guidance](https://www.rhs.org.uk/plants/types/houseplants/growing-media-houseplants)

The relevant check asks whether excess water can escape, whether the inner pot is standing in collected water, and how the mix behaves. Ask only when relevant; do not instruct a user to water an already-wet plant simply to run a test. A simple pot/saucer correction may be enough and must not fabricate any of the three care actions. A possible fourth action such as drainage adjustment, or recording inspection-only outcomes, needs a separate product decision before adding event types.

Adjacent-topic boundaries:

| Topic | Recommended place / boundary |
| --- | --- |
| Aeration and compaction | Compaction is an observation in the mix check; no separate aeration task or treatment is introduced. |
| Salt/mineral buildup and pH | Later Soil health guidance; reliable treatment needs appropriate evidence and plant/product context. Do not infer exact chemistry from appearance or prescribe generic pH correction. |
| Temperature, humidity, drafts/airflow | Separate environmental-care area alongside light, rather than soil-care actions. |
| Pests and disease symptoms | Separate observation/triage scope; do not fold diagnosis/treatment into nutrient or repotting advice. |

### 18.6 Recording performed care and overlap

- **SH-07:** Keep three distinct action types while supporting **one care event with one or more explicitly selected actions**. A combined event is saved once, shown once, and contributes to the relevant per-action history. Users must not have to log the same job repeatedly.
- Example: repotted and replaced mix → select **Repotted + Refreshed potting mix** in one event. If nutrients were deliberately added as part of that job, the user may also select **Added nutrients**. Each action can also be recorded on its own.
- **SH-08:** Do not automatically select mix refresh when Repotted is selected, nutrient addition when fresh mix is used, or repotting when mix is refreshed. Briefly explain related actions so the user can select what actually happened. A mix's existing fertilizer content is contextual information, not an automatically performed action.
- **SH-09:** The default path is check → guidance → optional **Record care**. Provide a secondary way to record work already done without forcing an assessment first. Minimum input: at least one action and the actual date, defaulting to today; optional product/mix context and notes. No mandatory pot measurements, exact fertilizer dose, photo, location, sensor, or shopping flow. Do not accept future-dated completed care.
- Save before showing success. Cancel writes nothing; a failed save keeps the previous state and the user's draft for retry. Prevent duplicate in-flight submissions. Records represent what the user reports doing, not that the plant is now healthy.
- Show the latest recorded date for each action inside Soil health, with **Not recorded** for missing history. Full events appear once in the per-plant Care timeline (section 19). Tap a soil-care event to edit it or remove it after confirmation. Correction/removal updates the affected action histories; it does not alter watering records.

### 18.7 State, persistence, and boundaries

- **SH-10:** Store soil-care events separately from watering records. Reuse the app's local-first, atomic persistence boundary. Old garden JSON must load with no soil-care history and all existing plant, schedule, preference, placement, and watering data intact.
- **SH-11:** Recording any soil action must not silently mark Watered, change Last watered, clear a watering task, alter an interval or custom check time, reset light placement, or enable notifications. Liquid nutrient application does not automatically complete a watering check. Watering schedule adaptation is outside this release.
- **SH-12:** No automatic recurring feeding, mix-refresh, repotting, drainage, or repeated assessment reminders. Opening/revisiting Soil health does not create obligations. No health score, sensor inference, automatic treatment, or new account/analytics requirement.
- Product/mix details are optional during recording; guidance may later explain why missing details limit a recommendation. Do not require a product database or infer a formulation from free text.

### 18.8 Acceptance criteria

1. SH-01–04: watering stays primary; Soil health is separate and progressively disclosed; a user can perform one check, choose unknown, accept no action, or exit without new tasks or writes.
2. SH-05–06: reviewed rules consider relevant recent care and avoid unsupported deficiency/repotting claims; missing data returns limited guidance rather than fabricated certainty. Version-1 advisory rules apply across the five current catalog plants, with explicit uncertainty and no universal dosage or interval.
3. SH-07–09: each action alone and every combination of the three can be saved in one event; no action is inferred/preselected; cancellation/failure/duplicate-save behavior is correct. One event updates only its selected action histories.
4. SH-10–11: old JSON and overlapping records round-trip; saves are atomic; concurrent changes survive; watering dates/history/Last watered, custom times, reminders, and light acknowledgment remain unchanged by soil care.
5. SH-12: no default recurring task, notifications prompt, overdue Soil health badge, or apparent numeric health measurement is introduced.
6. Large text, narrow/dark layouts, screen-reader action/result labels, expanded/collapsed semantics, and Back behavior keep all choices usable without mandatory setup.
7. For integrated drainage, verify that optional checks can end with a simple correction/no action, without forcing repotting, fertilizer, a water test, or a fabricated care record.

### 18.9 Evidence and content review

Sources reviewed on 15 November 2026. These support content boundaries, not a finished Bloom recommendation algorithm. Species branches, inputs, and product instructions still need explicit review; do not transplant generic container/garden fertilizer schedules into this houseplant feature.

- [Wisconsin Extension — Houseplant care](https://hort.extension.wisc.edu/articles/houseplant-care/): feeding depends on growth/product instructions; inspect root crowding before repotting; an oversized pot may keep roots too wet.
- [RHS — Growing media for houseplants](https://www.rhs.org.uk/plants/types/houseplants/growing-media-houseplants): mix components serve different structural, water, air, and nutrient roles; roots need air. Coco coir is a growing-medium component, not a complete feeding plan.
- [University of Minnesota Extension — Fertilizing and watering container plants](https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/fertilizing-and-watering-container-plants): nutrient-containing mixes, product types, and label instructions matter. This is broader container guidance, not a houseplant-specific schedule for adoption.
- [University of Maryland Extension — Mineral and fertilizer deposits](https://extension.umd.edu/resource/mineral-and-fertilizer-salt-deposits-indoor-plants): mineral/salt buildup is distinct from insufficient feeding and can affect nutrient uptake; consider as later scope, not proof of deficiency.

### 18.10 Adopted release decisions and limits

The user authorized Soil health after timeline/navigation and confirmed drainage in the checks. Adopt the combined-event record, secondary already-done recording, edit/remove support for soil events, and unchanged-watering boundary described above. Broader chemistry, pest diagnosis, automatic intervals, and environmental care remain deferred. The original documentation-only state and open questions are retained as decision history in D45–D47; D49 supersedes those gates for this release.

A record requires the actual date (today initially) and one or more actions. Optional fields: fertilizer/amendment name (120 characters), notes (500 characters), and whether fresh mix contains fertilizer (Yes/No/Not sure). Store care date separately from the UTC recording timestamp; do not invent a time for date-only soil work. These inputs are user-reported context, not chemical measurements.

### 18.11 Version-1 advisory rules

At most three relevant questions are shown, one at a time; finish early when an answer determines the result. Yes/No/Not sure are explicit choices. Partial checks are protected by the discard policy in section 20. Completed guidance creates no care event and can be left without confirmation.

| Check | Questions / early exit | Result boundaries |
| --- | --- | --- |
| Adding nutrients | Active growth? If No/Not sure, stop with no action/inspect growth. Is a feed or fertilized mix still supplying nutrients? If Yes/Not sure, stop and ask the user to consult its label. Otherwise ask whether watering, actual light, and drainage have been checked. | Only active growth + no current nutrient supply + checked conditions yields **Adding nutrients may help**. Follow a suitable houseplant product's label; no deficiency diagnosis, dose, interval, or automatic reminder. Reuse recorded nutrient/mix dates and optional context as a memory aid, never as proof of duration. |
| Refresh potting mix | Can excess water escape? If No/Not sure, stop at **Check drainage first**. Otherwise ask about compaction/ongoing uneven wetting and observed dense roots with little mix. | Observed crowding can suggest repotting; mix problems can suggest refresh; both can be relevant. Unknown/no evidence yields inspect-first/no action. A drainage correction need not become any recorded action. |
| Repotting | Same drainage early exit; otherwise ask about observed root crowding and ongoing mix wetting/drying problems. | Crowding can suggest repotting; a mix problem without crowding can suggest refresh instead. Do not infer pot size from plant height or a single root. No required unpotting to complete the check. |

The result explains why an action may help and offers optional **Record soil care**. All recorded action selections start empty, even when guidance suggests an action. A user can record actual work without an assessment; showing a recommendation does not establish that the work was done. Sources are in 18.9; the rule version lives separately from persistence and can be reviewed without adding a diagnosis system.

## 19. Per-plant Care timeline

**State:** Explicitly requested, implemented, and verified on 15 November 2026; evidence in STATUS.md. D48 records scope.

- **TL-01:** Add a **Care timeline** entry to plant details, opening a dedicated page for that plant. Keep detail compact; do not embed the full feed or add a global navigation tab. Back returns to the same plant page.
- **TL-02:** Show all available records for that plant, newest first, in a lazy list. Show a real date, a clear action/outcome, and available context. Watering uses actual recorded/completed time, not due time. Soil events show the actual care date without inventing a clock time; within-day ties use recording time then identity for stability and do not imply a known time of soil work.
- **TL-03:** Include Watered and Checked — not watered as distinct outcomes with soil observations. A combined soil event appears once with all selected actions and optional product/mix/notes context. Tapping a soil event opens its edit/remove flow; existing watering records stay read-only.
- **TL-04:** The saved light acknowledgment can appear as **Light placement acknowledged**, dated by its confirmation timestamp and explicitly labelled the current saved confirmation. This is not a plant-movement time or an immutable log of light changes. Existing storage has only the current acknowledgment: clearing it removes that snapshot; earlier confirmations cannot be reconstructed and are not invented.
- **TL-05:** Empty state: **No care recorded yet**, with brief explanatory copy. No overdue warning, fabricated Plant added milestone, scheduled reminder, or unfinished check appears as completed care. Home's existing Past list remains unchanged.
- **TL-06:** Reading timeline never creates or changes care, schedules, notifications, or preferences. Deleted targets retain Back/Home recovery. Existing stored watering records are immediately usable; no duplicate history store or speculative migration is needed for them.
- **TL-07:** Support long combined labels/notes, large text, narrow/dark layouts, device-formatted local dates/times, and accessible action labels. Display only the selected plant; do not truncate history to Home's recent-five preview.

Acceptance: correct plant filtering, ordering and real-date precision; combined jobs once; pending care excluded; current light confirmation honestly labelled; empty/deleted states; live updates after soil edits/removal; nested Back to the parent plant; no read-side writes. Persistence and care data sources remain distinct; the timeline is a read projection, not another care schedule.

## 20. Back navigation and unsaved-form protection

**State:** Explicit user request, implemented and verified on 15 November 2026; D48 defines the contract.

- Use native Android **back arrows** for page navigation, replacing custom Close/Cancel toolbar labels in Preferences, catalog, setup, and Check watering, and using them on the new timeline/soil pages. Native dialogs/pickers retain their ordinary Cancel actions. Use normal nested routes rather than fullscreen-dialog treatment for Check watering.
- **NAV-01:** Clean forms and read-only pages return immediately to their parent. Home remains the navigation root; successful Add still returns Home, and successful recorded checks return to the caller.
- **NAV-02:** Toolbar Back and Android system Back from a dirty form show one dialog: **Discard changes?** with **Keep editing** and **Discard changes**. Dismissing the dialog also keeps the form. Keep editing preserves all draft selections/text/date. Discard exits without writing.
- **NAV-03:** Dirty means a change to unsaved form values compared with their initial values. Covers plant setup's optional watering/placement inputs, Check watering soil/outcome, soil-care action/date/context/notes edits, and partial assessment answers. Returning all fields to their initial state is clean. Completed advisory guidance is not an unsaved care record.
- **NAV-04:** An in-flight save is not a discardable draft: wait for it to finish, showing saving feedback if Back is attempted. A successful save releases the guard and exits without a spurious discard dialog; failure preserves the draft and allows retry or confirmed discard. Guard repeated Back presses against duplicate prompts.
- **NAV-05:** The guard does not roll back actions already saved immediately, such as next-check edits, Preferences, or detail placement acknowledgment. New nested routes preserve unfinished work beneath them. An invalid reminder must not forcibly pop dirty forms; show unavailable feedback in place in that case.

Acceptance: toolbar/system Back, keep/discard/dismiss, clean/reverted state, save success/failure/in-flight handling, nested page return, no duplicate prompt, preserved draft underneath reminder navigation, and no accidental care records from leaving. Android predictive Back may not preview a pop while a dirty form is guarded; manual TalkBack and physical-gesture audit remains separate from automated checks.
