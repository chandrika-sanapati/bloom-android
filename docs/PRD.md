# Bloom — Android watering MVP product requirements

**Status:** Implemented baseline; validation and hardening in progress
**Product:** Bloom for Android, a local-first Flutter app
**Owner:** Bloom product team
**Last updated:** 15 November 2026

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
4. **Environmental checks:** optional observations for light, airflow, drafts, and temperature without silently changing watering schedules.
5. **Additional care domains:** nutrition, repotting, and conservative symptom observations as separate, reviewed records.
6. **Sync and sharing:** only after local ownership, correction, and notification semantics are well understood.

## 13. Product principles

- **Reduce memory, not agency.** Bloom remembers dates; the user observes the plant.
- **Scheduled does not mean watered.** Every due task is a check prompt.
- **Record reality.** A non-watering check is meaningful and must not update Last watered.
- **Late completion changes the future, not the past.** Preserve scheduled and recorded times.
- **Prefer explicit changes.** Do not silently adapt schedules or infer plant conditions.
- **Earn complexity.** Broader care features must follow validated user problems, not an old feature list.
