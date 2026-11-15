# Bloom — Android product requirements

**Status:** Watering baseline and approved Light & placement flow implemented; automated tests, Android build, and device flow verified on 15 November 2026; remaining manual accessibility checks in STATUS.md
**Product:** Bloom for Android, a local-first Flutter app
**Owner:** Bloom product team
**Last updated:** 15 November 2026

The full product decision record—including alternatives, tradeoffs, future care-domain boundaries, and decision-revisit triggers—is in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). Sections 1–13 describe the watering baseline. Section 14 specifies the approved Light & placement release, now implemented with watering dates unchanged. Verification evidence and remaining checks are in STATUS.md.

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
- Setup may accept a past last-watered date; otherwise the first check is created today at the default internal reminder time.
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

1. If the user supplies a valid past last-watered date, the first check is that date plus the profile starting interval at the app's default reminder time.
2. If the date is unknown, the first check is today at the default reminder time.
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
- Completing an overdue task anchors the next check to the actual completion time.
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

WateringRecord
- id
- plantId
- scheduledFor
- recordedAt
- outcome: watered | checkedNotWatered
- soil: dry | damp | unknown

AppPreferences
- reminderHour / reminderMinute (currently internal defaults)
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
2. **Schedule ergonomics:** consider a configurable reminder time and explicit latest-record correction only after the current data model and UX are validated.
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

- Show the same species-specific suggestion on plant detail in a **Light & placement** section near Watering. Keep the wording consistent between setup and detail.
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
