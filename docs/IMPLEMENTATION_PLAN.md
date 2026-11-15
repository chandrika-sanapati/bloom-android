# Bloom Android implementation plan

**Status:** Watering and Light & placement implemented and verified as recorded in STATUS.md. Reminder preferences/navigation were reviewed, authorized, and implemented in section 8; verification is in STATUS.md.
**Platform:** Flutter Android.
**Source of truth:** [`STATUS.md`](STATUS.md) for shipped behavior; [`PRD.md`](PRD.md) for product intent and scope.
**Last updated:** 15 November 2026

Read [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) before changing scope. It preserves the alternatives and tradeoffs behind the current cuts and future roadmap.

## 1. Implementation principle

Bloom should make the next watering check clearer, faster, and more trustworthy. Keep schedule transitions centralized. The revised Light & placement proposal adds a species-specific suggestion and an optional saved action acknowledgment during setup and on plant detail. Placement acknowledgment leaves all watering dates and reminders unchanged in this release; watering stays the only recurring care system. The light-placement review gate in section 7 is complete. The reminder review gate in section 8 is also complete.

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
- Configurable reminder time and notification navigation are implemented under the reviewed scope in section 8.
- Broader environmental context, live weather, sensors, nutrition, repotting, pruning, symptom diagnosis, or specialist routing. Light & placement in section 7 is implemented; broader environmental behavior remains outside it.
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

## 8. Reminder preferences and notification navigation — implementation plan

**State:** Reviewed and explicitly authorized on 15 November 2026; implementation complete. [PRD section 15](PRD.md#15-reminder-preferences-and-notification-navigation--requirements) is the contract; decisions D33–D40 explain the final rules. Verification evidence and outstanding manual checks are in STATUS.md.

### R0 — Review completed

The user authorized one global preference, automatic-only updates after today, custom/today/overdue/legacy protection, one-off overrides, preferred-clock completion, deterministic DST handling, and current/stale notification destinations. No extra migration or setup questionnaire is required.

### R1 — Pure time rules, preferences, and atomic persistence

- Extend AppPreferences copy/update paths for existing reminderHour/reminderMinute fields; validate inputs and preserve legacy/default behavior safely.
- Introduce testable local-calendar time helpers for first checks, completion/follow-up checks, eligible automatic changes after today, and DST resolution. Do not add Duration hours to a UTC instant as a substitute for a local preferred clock.
- Add a GardenStore preference transition that commits the new time and eligible automatic timestamps after today atomically. Preserve custom times, every existing check dated today, overdue checks, dates/history/intervals/placement, and protected notification trigger times.
- Add persisted time provenance to WateringSchedule: preference/custom/legacy. Manual edits mark custom, including edits that match the global clock; global changes and sync must never clear that protection. Under the adopted one-off lifecycle, completing the check creates an automatic successor.
- For old/unknown provenance, apply legacy protection without inferring intent or changing timestamps. Preserve old checks on upgrade and explain the limitation only when relevant; do not add a user classification flow. This policy was adopted with implementation authorization.
- Distinguish a failed garden write from a notification resync failure after a successful write. Publish no uncommitted preference or task changes.

### R2 — Minimal Preferences UI

- Add one Reminder time row beside the existing notification controls, using the native time picker and device time formatting.
- Save on final picker confirmation, with no second confirmation dialog or required setup input. Show scope and platform timing expectations inline.
- Allow saving with notifications off/denied; never enable notifications or ask for permission solely because the user chose a time. Preserve/retry on persistence failure and disable duplicate in-flight saves.

### R3 — Future-only notification synchronization and payload identity

- Retain one-shot inexact watering reminders and one pending reminder per plant; update eligible changed automatic requests after committed time changes. Preserve protected custom/today/overdue request trigger times and avoid catch-up bursts.
- Use stable, collision-safe bounded Android IDs. Make resync idempotent and explicitly clean up eligible old pending requests.
- Replace the plant-only payload with a versioned plant/check/revision descriptor and a pure validator/resolver. Handle existing prefix-only payloads with the documented detail fallback.
- Compare notification identity with current saved data; an edited/completed task must not redirect an old reminder into a new future check.
- Refresh timezone/permission status and reconcile at startup/resume without blocking Home, promising exact delivery, or requesting exact-alarm access.

### R4 — Handle startup and warm navigation

- Extend WateringNotifications initialization with onDidReceiveNotificationResponse and inspect getNotificationAppLaunchDetails for notification-triggered startup using the pinned plugin API.
- Queue/validate a target while the garden or Navigator is not ready. Share one resolver for cold and warm entry and deduplicate callback/launch-detail delivery.
- Coordinate navigation in BloomApp/root navigation rather than navigating from a background isolate or service-owned stale BuildContext.
- Cold entry establishes Home beneath the requested CheckScreen; warm entry preserves the existing stack/unfinished work and reuses an already-open identical check.
- Deleted/missing/malformed targets recover to Home; stale or legacy targets with an existing plant recover to detail with concise feedback. Every fallback retains Back/Home recovery.
- Opening a notification must not commit a care outcome, change a date, enable permissions, or replay an event on normal launch.

### R5 — Verification and documentation

- Unit tests: preference validation; provenance JSON/migration; first/completed check clock rules; preservation of custom/today/overdue/legacy timestamps and notification times; custom times equal to the old preference; repeated global changes/relaunch; one-off completion reset; DST cases; atomic failure/idempotence; versioned/legacy/malformed/stale target resolution; duplicate launch handling.
- Widget tests: native-picker value/cancel/save, notifications-off and failed-save states, correct-route/back behavior, repeated taps, large text, and device-format display.
- Android integration: real notifications/taps from foreground/background/terminated states, persisted preference/provenance updates, protected custom/today notification times, stale/deleted-target fallback, denied permission, no catch-up burst, timezone/DST where controllable, and preservation of the separate normal installation.
- Use `sh tool/test_android.sh -d <test-device>` and isolated cache-file repositories. Extend the runner's targets if new integration files are added; do not test against or uninstall the normal app/data. Real tap delivery verification needs an actual notification tap, not merely calling the Dart resolver.
- Add deterministic injectable clock/notification/navigation seams as needed. Keep temporary device time/timezone/font settings confined to the test device and restore them after testing.
- Run relevant existing tests, analysis, and debug build after implementation. Record actual results and unverified OS delivery cases in STATUS.md; do not reuse the previous feature's evidence as proof of this release.
- Align all six main docs with the reviewed decision and final implementation. Implementation and tests are authorized; a new commit or push has not been requested for this change.

### R6 — Implemented boundaries and repeatable verification

- `reminder_time.dart` resolves local calendar clocks, including DST gaps/folds. `GardenStore` serializes whole persistence transitions, so concurrent screens cannot overwrite each other's saved changes. Preference and eligible check times share one atomic write; optional notification failures cannot undo it. Schedule revisions change only when a timestamp changes.
- `watering_notification.dart` validates bounded versioned payloads carrying plant, due instant, revision, and zone. Legacy payloads fall back to detail. Stable 31-bit IDs probe occupied requests; synchronization preserves unchanged pending requests and replaces changed ones at their saved instants.
- `WateringNotifications` handles single-flight initialization, queued/cold/live responses, startup duplicate suppression, serialized incremental sync, permission/status feedback, and retry on resume. `BloomApp` owns routing after Navigator readiness; manually opened checks use the same route identity for duplicate suppression.
- `tool/test_android.sh` prebuilds, installs/grants only `com.chandrika.bloom.integration`, and uses `--no-uninstall`. Select `BLOOM_TEST_TARGET=integration_test/reminders_test.dart` for the native intent suite. `tool/check_notification_launch.py` builds the isolated standalone fixture and a UI Automator test from the local SDK/JUnit cache, then taps real notifications after confirming the fixture process is gone.
- The integration-only activity/channel is compiled from `src/integration/kotlin` only with the test Gradle flag. The normal APK uses MainActivity and contains no test channel or exported test receiver. Cold fixtures use cache files, never the normal garden.
- Refresh the zone and pending request conversion on resume; preserve saved instants. Do not silently rebase existing protected checks after travel. Live background travel adaptation and exact delivery guarantees remain excluded.

## 9. Occasional care — requirements refinement only

Follow PRD section 16 and decisions D41–D43. The compact/expandable sunlight presentation is implemented and verified in section 10; existing light functionality remains its foundation. After that, refine **Adding nutrients** before Pot & soil: start from the user's need to decide whether an action is warranted, with progressive disclosure and watering kept primary. Review the smallest useful inputs and evidence-supported result/uncertainty handling before specifying records or reminders. Exact flows and implementation remain unapproved; do not add care schedules or code from these discussion notes.

Apply D42 to the hierarchy discussion: Light & placement is setup/occasional review, not another recurring care task. Do not add expiry, automatic acknowledgment resets, or light reminders. Preserve setup, acknowledgment behavior, and saved placement data. D44 / section 10 authorize compact summaries and expandable advice on detail; relocation under Other care remains outside scope.


## 10. Compact light presentation — implemented and verified

D44 / PRD section 17 authorize this refinement. Add an opt-in compact presentation to the shared LightPlacementSection and enable it only on detail; keep a single shared guidance/checkbox body and unchanged setup. Use Material ExpansionTile, default collapsed, with light requirement and report status always visible. Keep expansion local to the view; make no domain/model/storage/scheduling change.

Verify pending/acknowledged collapse/expand without writes, existing save/failure/correction, setup skip/acknowledgment, and narrow 2x-text dark layout. Update the isolated Android placement test to expand explicitly and assert initial compact state; capture a compact preview. Run host tests from a path without parentheses, analysis, isolated Android regression, and normal APK build. Back up and compare saved normal-app data; install normal APK with -r. Record actual results in STATUS.md and keep the six main docs aligned.

Validation: 55 host tests and both isolated Android placement tests passed, analysis returned zero findings, and the normal APK built/installed in place. Compact Android preview visually reviewed. Source hashes matched the tested checkout; four normal saved files matched the pre-test backup before update and the garden JSON remained identical after launch. Full manual TalkBack review remains separate. See STATUS.md.
