# Bloom — Android product requirements

**Status:** Watering, Light & placement, reminder preferences, and notification navigation implemented; verification evidence and remaining manual checks in STATUS.md
**Product:** Bloom for Android, a local-first Flutter app
**Owner:** Bloom product team
**Last updated:** 15 November 2026

The full product decision record—including alternatives, tradeoffs, future care-domain boundaries, and decision-revisit triggers—is in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). Sections 1–13 describe the watering baseline. Section 14 specifies the approved Light & placement release, now implemented with watering dates unchanged. Verification evidence and remaining checks are in STATUS.md. Section 15 specifies the reviewed reminder-preference and notification-navigation scope, authorized and implemented on 15 November 2026.

## 1. Product summary

Bloom helps plant owners remember which plant to check, record what they actually did, and know when to look again. The first product loop is intentionally narrow:

> **Schedule a check → inspect the plant → choose Watered or Checked — not watered → schedule the next check.**

A date is a prompt to inspect the plant, not proof that the plant needs water. Bloom keeps the user in control and avoids presenting a calendar rule as a diagnosis.

## 2. Product and platform boundary

- The active product is the Flutter Android app in this repository.
- Garden data is stored locally on the device as JSON.
- Notifications are optional and Android-specific in the current implementation.
- There are no accounts, cloud sync, analytics service, live weather, device-location inference, sensors, or automatic watering hardware.
- The four supported catalog plants are the only plants that receive an automatic watering schedule in the current product.
- The historical iOS screenshots in `docs/previews/` are not current product behavior.

## 3. Current implementation baseline

The following behavior exists in the current Android code:

- Home shows **My plants** and **Activity → Upcoming / Past** after a plant is added.
- The catalog contains Snake Plant, Monstera, Rubber Plant, and Pothos.
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
- Nutrition, fertilizer, compost, soil amendments, repotting, pruning, or symptom-treatment flows.
- Accounts, cloud sync, sharing, social features, analytics, or community schedules.
- A separate watering-history destination or watering-specific search/filter system.

## 6. Supported profiles

These are check-in profiles, not universal watering instructions. Actual needs vary with pot size, drainage, medium, light, temperature, humidity, season, and plant size.

| Plant | Scientific name | Check-in range | Starting interval |
| --- | --- | ---: | ---: |
| Snake Plant | *Dracaena trifasciata* | 14–30 days | 21 days |
| Monstera | *Monstera deliciosa* | 7–14 days | 10 days |
| Rubber Plant | *Ficus elastica* | 7–21 days | 14 days |
| Pothos | *Epipremnum aureum* | 7–21 days | 14 days |

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

AppPreferences
- reminderHour / reminderMinute (editable in Preferences; initially 09:00)
- taskNotifications
```

Keep schedule transitions in `GardenStore`. Do not make screens mutate records, dates, or derived Last watered state directly.

## 11. Acceptance criteria for the next validation milestone

- The four catalog plants can each be added and receive the documented starting interval.
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
2. **Reminder control and navigation — requirements selected:** a global reminder-time preference and direct notification entry to the relevant watering check; see section 15. Latest-record correction remains separate future work.
3. **More reviewed plant profiles:** add content one profile at a time with a range, starting value, cue, and source review.
4. **Light & placement — implemented:** species-specific light suggestions during setup and on detail, with one optional saved acknowledgment and unchanged watering dates; see section 14. Adaptation and broader environmental checks remain deferred.
5. **Additional care domains:** nutrition, repotting, and conservative symptom observations as separate, reviewed records.
6. **Sync and sharing:** only after local ownership, correction, and notification semantics are well understood.

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

- One **Reminder time** preference in Settings/Preferences, applying to all plants.
- Changing it updates eligible **existing automatic future checks on later days** and newly scheduled automatic checks. **Custom timings, today's existing checks, and overdue checks remain unchanged**, as clarified by the user.
- A valid notification tap opens that plant's **Check watering** screen.
- The documents were reviewed before implementation was explicitly authorized; keep them aligned with the code.

Not included: per-plant recurring time preferences, daily digests, repeated overdue nudges, snooze, notification buttons that record watering, new care reminders, exact-to-the-minute delivery, Undo, backup/restore, cloud sync, or sunlight-driven interval changes.

### 15.2 Baseline before this feature and implemented change

Before this feature, `AppPreferences` stored reminderHour/reminderMinute with a 09:00 fallback, but Preferences exposed only the notification switch. New plants use the stored time for their first check. Completion previously added the profile/follow-up duration to the actual completion timestamp, so later checks inherit that clock time rather than a preferred daily time.

Previously, notifications carried only a plant ID and had no tap handler. This release implements the visible preference, consistent clock rule, and validated check-specific routing described below. STATUS.md records actual verification and platform limits.

### 15.3 Minimal Preferences flow

1. Keep the existing **Watering notifications** switch.
2. Add one **Reminder time** row in the same Preferences screen, displaying the saved time in the device's 12/24-hour format; keep 09:00 as the fallback for users who have never selected a time.
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

## 16. Occasional care — direction under discussion

**State:** Adding nutrients and Pot & soil are product discussion only, not implemented or authorized for implementation. The separate light presentation refinement is implemented under section 17 / D44.

The user confirmed the label **Adding nutrients** and requested assessment-first, on-demand help for both nutrient needs and Pot & soil. Watering stays primary. Progressively disclose these infrequent capabilities rather than adding default recurring schedules or prominent everyday obligations. The sunlight-first refinement recommended in D43 is now implemented under D44 / section 17. Next refine Adding nutrients, then Pot & soil. Exact navigation, minimal questions, evidence/content rules, uncertainty handling, action records, and any future reminder policy need review before implementation. Prior proposals to expose only advice and action logging are insufficient on their own.

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
