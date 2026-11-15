# Bloom Android implementation plan

**Status:** Watering MVP baseline implemented; verification and hardening remain.
**Platform:** Flutter Android.
**Source of truth:** [`STATUS.md`](STATUS.md) for shipped behavior; [`PRD.md`](PRD.md) for product intent and scope.
**Last updated:** 15 November 2026

Read [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) before changing scope. It preserves the alternatives and tradeoffs behind the current cuts and future roadmap.

## 1. Implementation principle

Bloom should make the next watering check clearer, faster, and more trustworthy. Keep the domain small, keep schedule transitions centralized, and do not add a second care system until the watering loop has evidence behind it.

## 2. Current architecture

| Area | Current implementation |
| --- | --- |
| App entry | `lib/main.dart` loads the local garden, initializes notifications, and starts `BloomApp`. |
| Domain model | `lib/domain/models.dart` contains `Plant`, `WateringSchedule`, `WateringRecord`, preferences, profiles, and timing enums. |
| State transitions | `lib/domain/garden_store.dart` owns add, edit, completion, removal, notification preference, and persistence transitions. |
| Persistence | `lib/data/garden_repository.dart` stores JSON under the application support directory using a temporary file replacement. |
| Notifications | `lib/data/watering_notifications.dart` schedules future watering checks only and removes stale Bloom requests during sync. |
| UI | `lib/ui/` contains Home, catalog/setup, plant detail, watering check, preferences, and shared widgets. |
| Assets | `assets/images/` contains the four plant images and the empty-state image. |

## 3. Completed baseline

- Four supported catalog profiles with bounded ranges and deterministic starting intervals.
- Optional last-watered date during setup, with a same-day baseline when it is unknown.
- One active schedule per supported plant.
- Today, Upcoming, and Overdue classification.
- Explicit Watered and Checked — not watered outcomes.
- Dry non-watering checks use a three-day follow-up; other checks use the profile interval.
- Late completion schedules from the actual recorded time and retains the original scheduled time in the record.
- Home Upcoming/Past activity, plant details, next-check editing, and plant removal.
- Local persistence with failed-save protection at the store boundary.
- Optional future-only Android notifications and permission-denied behavior.

## 4. Next engineering steps

### P0 — Establish repeatable verification

1. Add focused Dart tests for profile values, first-check calculation, timing classification, watering transitions, dry follow-up, late completion, edit validation, and failed persistence.
2. Decide whether `flutter analyze` should pass with zero findings; currently it reports two `prefer_initializing_formals` info findings in `garden_repository.dart` and `garden_store.dart`.
3. Run a debug APK build with the Android Studio JDK configured for the shell environment, then install on the available emulator.
4. Keep verification results and any known environment limitations in `docs/STATUS.md`.

### P1 — Verify the complete Android journey

- Add each catalog plant and confirm its starting schedule.
- Enter a valid last-watered date and confirm the calculated next check.
- Reject future last-watered dates.
- Complete Watered and confirm Last watered, Past, and the next schedule.
- Complete Checked — not watered for dry, damp, and unknown soil.
- Resolve an overdue task without creating a duplicate immediate task.
- Edit a future next-check date and confirm it changes Upcoming without creating history.
- Remove a plant and confirm its schedule and records are removed.
- Deny notification permission and confirm in-app tasks remain intact.
- Relaunch the app and confirm the garden, records, and preferences persist.

### P2 — Accessibility and resilience

- Review TalkBack labels, selected states, disabled Save, errors, and destructive confirmation.
- Review large Android font sizes, narrow widths, dark theme behavior, and system animation settings.
- Verify notification tap routing when notification deep-link handling is added.
- Decide whether record-level deletion/Undo belongs in the next release; it is not currently implemented despite older product notes mentioning it.

## 5. Deliberately deferred

Do not add these to the watering baseline without a new product decision:

- Arbitrary custom plant schedules or a fallback interval.
- Per-plant interval editing, pause/resume, seasonal logic, or adaptive schedule changes.
- Configurable reminder time UI.
- Environmental context, live weather, sensors, nutrition, repotting, pruning, symptom diagnosis, or specialist routing.
- Cloud accounts, sync, sharing, analytics, or a separate watering-history destination.

## 6. Definition of done for the next milestone

- Focused automated domain tests exist and pass.
- The debug APK builds and launches on the supported Android emulator.
- The complete watering journey is manually verified on Android.
- Persistence failures do not replace the saved garden with an uncommitted state.
- Notification permission and future-only scheduling are verified on-device.
- TalkBack and Android text scaling do not hide the primary action or alter the meaning of outcomes.
- `STATUS.md` reflects the evidence rather than planned behavior.
