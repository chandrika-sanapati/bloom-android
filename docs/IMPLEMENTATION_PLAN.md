# Bloom Android implementation plan

**Status:** Watering MVP baseline and repeatable verification implemented; device-level accessibility and notification delivery checks remain.
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
- Material 3 dynamic light/dark color schemes through `dynamic_color` 1.9.0, with Bloom teal fallback.
- Optional last-watered date during setup, with a same-day baseline when it is unknown.
- One active schedule per supported plant.
- Today, Upcoming, and Overdue classification.
- Explicit Watered and Checked — not watered outcomes.
- Dry non-watering checks use a three-day follow-up; other checks use the profile interval.
- Late completion schedules from the actual recorded time and retains the original scheduled time in the record.
- Home Upcoming/Past activity, plant details, next-check editing, and plant removal.
- Check Watering uses a full-width outlined secondary Edit next check action below the scheduled date.
- Local persistence with failed-save protection at the store boundary.
- Optional future-only Android notifications, permission-denied behavior, inexact scheduling, and non-blocking startup.

## 4. Next engineering steps

### P0 — Establish repeatable verification

**Status:** Complete.

1. Add focused Dart tests for profile values, first-check calculation, timing classification, watering transitions, dry follow-up, late completion, edit validation, and failed persistence. **Done: 12 tests pass.**
2. Make `flutter analyze` pass with zero findings. **Done.**
3. Build a debug APK with the Android Studio JDK and install it on the available emulator. **Done.**
4. Keep verification results and known environment limitations in `docs/STATUS.md`. **Done.**

### P1 — Verify the complete Android journey

**Status:** Core journey complete; notification permission/delivery and accessibility checks remain.

- Add each catalog plant and confirm its starting schedule. **Covered by domain tests; Snake Plant verified on emulator.**
- Enter a valid last-watered date and confirm the calculated next check. **Date/time picker verified on emulator; calculation covered by domain tests.**
- Reject future last-watered dates. **Covered by domain tests.**
- Complete Watered and confirm Last watered, Past, and the next schedule. **Verified on emulator and covered by domain tests.**
- Complete Checked — not watered for dry, damp, and unknown soil. **Covered by domain tests; device interaction remains.**
- Resolve an overdue task without creating a duplicate immediate task. **Covered by domain behavior; device interaction remains.**
- Edit a future next-check date and confirm it changes Upcoming without creating history. **Verified on emulator.**
- Remove a plant and confirm its schedule and records are removed. **Covered by current store behavior; device interaction remains.**
- Deny notification permission and confirm in-app tasks remain intact. **Remaining device check.**
- Relaunch the app and confirm the garden, records, and preferences persist. **Verified on emulator.**

### P2 — Accessibility and resilience

- Review TalkBack labels, selected states, disabled Save, errors, destructive confirmation, and the new Edit next check action.
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

- Focused automated domain tests exist and pass. **Complete: 12 tests.**
- The debug APK builds and launches on the supported Android emulator. **Complete.**
- The core add → check → edit → relaunch journey is manually verified on Android. **Complete.**
- Persistence failures do not replace the saved garden with an uncommitted state.
- Notification permission and future-only scheduling are verified on-device.
- TalkBack and Android text scaling do not hide the primary action or alter the meaning of outcomes.
- `STATUS.md` reflects the evidence rather than planned behavior.
