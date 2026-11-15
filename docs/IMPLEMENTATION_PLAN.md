# Bloom Android implementation plan

**Status:** Watering baseline and Light & placement implemented. Thirty host tests, two Android integration tests, static analysis, and the normal debug APK build pass. Remaining manual checks and the device-test incident are in STATUS.md.
**Platform:** Flutter Android.
**Source of truth:** [`STATUS.md`](STATUS.md) for shipped behavior; [`PRD.md`](PRD.md) for product intent and scope.
**Last updated:** 15 November 2026

Read [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) before changing scope. It preserves the alternatives and tradeoffs behind the current cuts and future roadmap.

## 1. Implementation principle

Bloom should make the next watering check clearer, faster, and more trustworthy. Keep schedule transitions centralized. The revised Light & placement proposal adds a species-specific suggestion and an optional saved action acknowledgment during setup and on plant detail. Placement acknowledgment leaves all watering dates and reminders unchanged in this release; watering stays the only recurring care system. Follow the review gate in section 7 before implementation.

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
- Broader environmental context, live weather, sensors, nutrition, repotting, pruning, symptom diagnosis, or specialist routing. The bounded Light & placement proposal in section 7 is the current documentation work, not implemented scope.
- Cloud accounts, sync, sharing, analytics, or a separate watering-history destination.

## 6. Definition of done for the next milestone

- Focused automated domain tests exist and pass. **Complete: 12 tests.**
- The debug APK builds and launches on the supported Android emulator. **Complete.**
- The core add → check → edit → relaunch journey is manually verified on Android. **Complete.**
- Persistence failures do not replace the saved garden with an uncommitted state.
- Notification permission and future-only scheduling are verified on-device.
- TalkBack and Android text scaling do not hide the primary action or alter the meaning of outcomes.
- `STATUS.md` reflects the evidence rather than planned behavior.

## 7. Light & placement — implementation sequence

**State:** Revised suggestion/acknowledgment scope approved and implementation explicitly authorized on 15 November 2026. The user confirmed no watering-date changes in this release. [PRD section 14](PRD.md#14-light--placement--release-requirements) is the contract; [D28–D31](PRODUCT_DECISIONS.md#13-light--placement-release-decisions) describe the current proposal. Track completed implementation and verification evidence in STATUS.md.

### L0 — Requirements approval

**Complete:** On 15 November 2026 the user confirmed that placement acknowledgment will leave watering dates unchanged and explicitly authorized implementation. The suggestion/optional acknowledgment in setup and detail is the approved flow. Other previously proposed implementation details use the documented simple defaults. Scheduling adaptation is deferred to a separate future decision.

### L1 — Species content and backward-compatible plant state

**Complete:** Species light profiles and optional versioned acknowledgment serialize backward-compatibly. Invalid optional acknowledgment data does not discard a valid plant.

- Add reviewed light guidance to the existing species model or a focused domain content file, shared by setup and detail. Use PRD 14.9 sources and review all four plant profiles.
- Add optional per-plant placement acknowledgment, with acknowledged timestamp and guidance version as the proposed minimum. Existing JSON without this field must load as unacknowledged; do not infer state from soil or watering history.
- Extend serialization, copy/update paths, and store operations to preserve the state and unrelated data. Keep actual placement location, previous light, sensor data, and room information outside scope.
- Keep persistence atomic: setup creates plant, starting schedule, and selected acknowledgment together. Detail updates the existing plant; a failed save keeps previous state and offers retry.

### L2 — Add the suggestion and optional acknowledgment in two places

**Complete:** Shared `LightPlacementSection` is used in setup and detail; detail saves with loading/failure feedback. Setup saves only on Add. Both optional setup sections use matching **Optional** heading labels (D32).

- In `lib/ui/catalog_screen.dart`, add the Light & placement section alongside Last watered, within the existing setup screen. Show the suggestion without a preliminary question. Default the input to unchecked and allow the existing Add action with or without it.
- In `lib/ui/plant_detail_screen.dart`, show the same suggestion near Watering and restore the saved state. A user who skipped setup can acknowledge here later.
- Propose one checkbox/switch with **I've placed it as suggested**, persisted immediately on detail. No separate acknowledgment-save page, questionnaire, two-concern picker, or dim/bright assessment.
- Handle saving/error state accessibly and keep corrections explicit. Do not claim the suggestion was acted upon until the write succeeds.
- No recurring light task, activity-feed completion, automatic popup, follow-up nudge, or reminder to acknowledge.

### L3 — Preserve watering behavior

**Complete:** `GardenStore.setLightPlacementAcknowledged` commits placement-only updates without notification synchronization. Tests cover unchanged schedules/history/preferences and idempotence.

- Acknowledgment-only writes use GardenStore's persistence boundary without invoking notification synchronization.
- Preserve schedules, intervals, Last watered, history, preferences, and existing reminders when setting/clearing placement. Repeated confirmations are idempotent.
- Setup uses the existing first-check calculation and one normal notification synchronization whether acknowledgment is present or absent.
- Add no new scheduling rule, reminder, activity type, date-edit step, or required user prompt. Future adaptation is a separate product decision.

### L4 — Verify the agreed implementation

**Core checks complete:** 30 domain/widget tests; 2 on-device integration tests using a cache-file repository; zero analyzer findings; normal debug APK builds. Device screenshots reviewed. Full manual TalkBack/system-setting review remains in STATUS.md.

- Cover backward-compatible JSON loading/round trips, setup skip/acknowledge/cancel, detail acknowledgment after adding, correction, relaunch, deletion, and failed saves with meaningful tests and device checks.
- Verify unchanged watering state on setup and later acknowledgment, including skip, already-correct placement, repeated actions, historical Last watered, overdue schedules, and failure rollback. Test that acknowledgment-only writes do not call reminder synchronization.
- Verify placement interactions leave the existing reminder and notification preferences alone and create no light reminders.
- Run existing domain tests, static analysis, and the Android debug build after implementation; check TalkBack, large text, narrow widths, dynamic light/dark themes, and Android navigation.
- Confirm in usability review that people understand the suggestion and that the input means acted rather than read; users should be able to skip it without help.
- Update `STATUS.md` with actual implementation and verification evidence only.

### Documentation maintenance

Keep the PRD, product decisions, implementation plan, design guidance, status, and README aligned as requirements evolve. Preserve superseded proposals as labeled decision history, not competing active requirements. The watering policy is resolved as unchanged for this release and implementation has been explicitly authorized. Keep adaptation outside this change.

### Repeatable Android verification

Use `sh tool/test_android.sh -d emulator-5554` with Flutter/JDK/Android SDK configured. The script scopes `ORG_GRADLE_PROJECT_bloomIntegrationTest=true` to test commands, prebuilds the APK so Flutter resolves the test application ID, and passes `--no-uninstall`. Gradle assigns **com.chandrika.bloom.integration**, separate from **com.chandrika.bloom**. Tests use app-cache files and do not load the user's garden. The retained test installation may be removed explicitly by its `.integration` package ID; rebuild/relaunch the normal app afterward if needed.

Use this runner instead of a raw integration-test command on an emulator containing personal test data. The first device run used the normal package and Flutter's default uninstall cleanup, clearing the emulator garden; the incident and correction are recorded in STATUS.md. Host tests were run from an identical temporary checkout without parentheses because Flutter 3.44.8's macOS native-assets parser crashes on the current `Codes (VS)` path. Do not patch the SDK or change plant behavior to work around that host-tool limitation.
