# Bloom Android status

**Last checked:** 15 November 2026
**Branch:** `main`
**Target:** Flutter Android

This is the short, current implementation record. If it conflicts with an older screenshot, planning note, or copied design document, this file and the code are authoritative.

## Implemented

- Flutter app entry point and Material 3 shell.
- Material 3 dynamic light/dark color schemes on supported Android versions, with a Bloom teal fallback.
- Local garden JSON persistence under the app support directory.
- First-run Add plant hint stored in `SharedPreferences`.
- Four catalog plants: Snake Plant, Monstera, Rubber Plant, and Pothos.
- Type-based starting watering intervals.
- Optional last-watered date during setup.
- Today, Upcoming, and Overdue schedule classification.
- Home My plants collection and Activity Upcoming/Past sections.
- Watering check flow with Dry, Damp, and Not sure soil context.
- Explicit Watered and Checked — not watered outcomes.
- Three-day follow-up after a dry non-watering check.
- Actual-event-based next scheduling with original scheduled time retained in records.
- Plant detail with next check, starting interval, Last watered, and Edit next check.
- Future next-check date/time editing.
- Check Watering uses a full-width outlined Edit next check action below the scheduled date.
- Plant removal with schedule and record cleanup.
- Optional future-only Android notifications and permission-denied messaging.
- Notification setup and scheduling are best effort and cannot block app startup.
- Domain/widget tests for watering plus placement persistence, unchanged scheduling, failure handling, setup/detail, and large-text layout.
- Shared species-specific Light & placement advice and optional persisted action acknowledgment in setup/detail.

## Not implemented

- Record-level deletion or Undo.
- Adjustable dry follow-up window; the current implementation uses three days.
- Arbitrary custom/unlisted plant creation or schedule setup.
- Exact delivery timing; Android may deliver inexact alarms within its allowed window.
- Cloud sync, accounts, analytics, environmental checks, diagnosis, nutrition, repotting, or other care domains.

## Reminder preferences and notification navigation — implemented on 15 November 2026

The user reviewed the documents and explicitly authorized implementation after confirming custom/today protection.

- Preferences has one native **Reminder time** picker with device 12/24-hour formatting, cancellation/no-op behavior, failure/retry feedback, and inline scope disclosure. It works with notifications off/denied and does not request permission on time changes.
- One atomic store transition updates the preference and automatic checks after today. Custom times (including times matching the old preference), every existing check today, overdue checks, and unclassified older checks stay exact. Missing/unknown `timeSource` loads as `legacy`; manual edits mark `custom`; first/completed automatic checks mark `preference`.
- The existing Edit next check is a one-off override. Completion uses the preferred local clock on the calculated profile/follow-up day, retaining actual recorded timestamps, Last watered, and history. Dry non-watering follow-up stays three days. Placement still changes no watering state.
- Versioned payloads identify plant/due/revision. Current tasks open Check watering, including overdue ones. Stale/completed/rescheduled/legacy links open current plant detail with feedback; deleted/invalid links recover Home. Opening a reminder writes no care history and selects no outcome.
- Cold entry puts Home beneath the check. Warm entry preserves the current stack and reuses an identical top check, including one opened manually. Initialization and root routing deduplicate launch/callback delivery and do not replay on ordinary resume.
- Incremental notifications keep unchanged requests, reuse/probe stable IDs, and schedule only future checks, one per plant. Optional permission or scheduling failure cannot roll back a saved preference. Zone/permission state refreshes at startup/resume; saved instants stay unchanged after travel.
- The first valid minute after a DST gap and first occurrence during a repeated clock are deterministic. No exact-alarm request, new reminder category, overdue burst, or background travel adaptation was added.

### Verification for this feature

- `flutter analyze --no-pub`: **zero findings**.
- `flutter test --no-pub`: **53 tests passed**. Includes original watering/placement tests plus atomic preference/provenance transitions, custom/today/overdue/legacy protection, concurrent writes, failure rollback, no-op revisions, preferred-clock successors, DST gap/fold, payload/ID/sync behavior, native-picker save/cancel/retry, permission denial, large text/dark layout, and cold/warm navigation/back-stack/deduplication.
- Host checks ran from an identical temporary checkout without parentheses because of the existing Flutter 3.44.8 macOS native-assets issue below. Final source hashes were compared with the local repository.
- Android reminder integration: **1 test passed**, covering persisted preference/custom provenance and posted native notification PendingIntents in foreground/background, including stale/deleted fallbacks.
- Cold-launch Android verification: **4 drawer-tap cases passed** (current → check, legacy → detail, malformed/deleted → Home), with the fixture process confirmed ended before each actual SystemUI tap. Each retained unchanged garden state and no records. The separate headless Android 16 emulator used only `com.chandrika.bloom.integration` and cache fixtures.
- Light-placement Android regression: **2 tests passed again** after the reminder changes, including setup skip/acknowledgment, detail correction, reload, and unchanged watering state.
- Normal `flutter build apk --debug --target lib/main.dart`: **passed**. The normal APK's dex was checked to exclude IntegrationActivity/test receiver code. Installed with `adb install -r` and launched successfully as `com.chandrika.bloom`.
- Before device testing, the normal app's saved files were backed up locally. All **8 saved files** matched the backup after isolated tests and before installation; the garden JSON remained **byte-for-byte unchanged** after in-place update and launch. This is evidence for this reminder implementation run; it does not undo the earlier placement-test incident described below.
- Preferences and notification-opened check screenshots from isolated Android fixtures were visually inspected. System time formatting was 12-hour on device; widget tests also verified 24-hour display.
- Remaining manual checks: full TalkBack/animation/font-setting audit; real OS permission-dialog denial/re-enable; delayed inexact delivery, long-idle battery restrictions, and OEM behavior. Deterministic DST/zone rules and routing tests do not prove exact or continuous background delivery.

See [PRD section 15](PRD.md#15-reminder-preferences-and-notification-navigation--requirements), [D33–D40](PRODUCT_DECISIONS.md#14-reminder-preferences-and-navigation-decisions), and [implementation plan section 8](IMPLEMENTATION_PLAN.md#8-reminder-preferences-and-notification-navigation--implementation-plan) for the contract and implementation boundaries.

## Light & placement — implemented and verified on 15 November 2026

The user replaced the concern-picker draft with a species suggestion and one optional saved acknowledgment, then explicitly authorized implementation with watering dates unchanged.

- The same reviewed species guidance and **I've placed it as suggested** checkbox appear in setup and on plant detail near Watering.
- Both Last watered and Light & placement setup headings show matching Optional labels; both inputs remain skippable. Follow-up verification: static analysis passed, the debug APK rebuilt successfully, and the normal package was updated in place and relaunched.
- Setup can skip it; Add commits the selected acknowledgment with the plant and normal first schedule. Cancelling setup writes nothing.
- Detail acknowledgment saves immediately, can be cleared, and restores from JSON with timestamp/guidance version. Loading/error feedback prevents a falsely saved state.
- Old JSON defaults to unacknowledged; invalid optional acknowledgment data does not discard a valid plant. Earlier guidance versions remain recorded until explicit correction.
- Placement-only writes change no schedules, intervals, Last watered, watering history, preferences, or reminders, and do not invoke notification synchronization. Adaptation is deferred.
- No extra placement inputs, light reminders, or activity records. Existing watering transitions remain covered by the original tests.
- Large-text verification exposed an existing trailing-date layout failure in plant detail; information rows now stack when needed.

Verification:

- `flutter analyze --no-pub`: zero findings.
- `flutter test --no-pub`: **30 tests passed** (12 existing watering tests plus 18 placement/domain/UI tests), run against identical source from a temporary path without parentheses.
- `sh tool/test_android.sh -d emulator-5554`: **2 integration tests passed**, covering setup skip/acknowledge, later acknowledgment, disk reload, correction, and unchanged watering state. Both normal and `.integration` packages were confirmed installed separately.
- Android setup and saved-detail screenshots were captured from isolated test fixtures and visually inspected.
- Normal `flutter build apk --debug --no-pub`: passed after test-package isolation was added. Output is `build/app/outputs/flutter-apk/app-debug.apk`.
- Final normal app installed and relaunched successfully with no Flutter startup errors; empty Home visually confirmed after the documented data-loss incident. The isolated test package was removed.
- Full manual TalkBack, notification delivery/denial, and system font/dark-mode setting audits remain separate checks; automated narrow/dark/2x-text detail layout passed.

### Device-test incident and corrected procedure

The first Android integration run used the normal `com.chandrika.bloom` package. Flutter 3.44.8 defaults to uninstalling its test app after completion, which removed Bloom and cleared the emulator's existing local garden. No pre-test backup was taken, and those prior entries/history have not been restored. This was a verification mistake, not a plant-data migration. For that earlier run, do not claim that the user's emulator garden was preserved; subsequent reminder testing has separate backup/hash evidence above.

The corrected `tool/test_android.sh` prebuilds an isolated APK using a test-only Gradle property, assigns `com.chandrika.bloom.integration`, and disables uninstall cleanup with `--no-uninstall`. Tests also use their own cache-file repositories. The corrected run verified package separation and passed both tests. The normal app is rebuilt/reinstalled afterward; the isolated test package can be removed explicitly. Use this runner for repeatable Android checks rather than a raw test invocation against the normal installation.

### Host-test environment limitation

Flutter 3.44.8's macOS native-assets `otool` parser crashes when the project path contains parentheses, as in `Codes (VS)`. Host tests were run from a temporary checkout without parentheses; implementation/test file hashes were checked against the local repository. The SDK was not modified. Android builds/device tests are unaffected. Run host tests from a path without parentheses until the SDK issue is resolved.

See [PRD section 14](PRD.md#14-light--placement--release-requirements), [decisions D28–D31](PRODUCT_DECISIONS.md#13-light--placement-release-decisions), and [implementation plan section 7](IMPLEMENTATION_PLAN.md#7-light--placement--implementation-sequence).

## Watering baseline verification snapshot (prior evidence)

- Flutter SDK available locally: 3.44.8.
- Dart SDK: 3.12.2.
- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed; 12 focused tests.
- `flutter doctor -v`: Android toolchain, Android SDK, emulator, and network resources are available. Xcode/CocoaPods warnings are irrelevant to this Android target.
- Android debug APK build: passed using Android Studio's JDK; output is `build/app/outputs/flutter-apk/app-debug.apk`.
- Dynamic color verification: `dynamic_color` 1.9.0 detected the emulator's Android system core palette and Bloom launched successfully with the dynamic theme.
- Emulator smoke check: initial launch exposed exact-alarm permission failure; notification scheduling was changed to inexact, best-effort delivery so the app can start without special-alarm access.
- Clean emulator smoke flow passed: empty Home → add Snake Plant → Watered → verify Last watered/next check → edit next check to December 15 → force-stop/relaunch → verify the edited date persisted.
- Date picker and time picker both opened and saved successfully during the emulator smoke flow.

## Current source map

- `lib/domain/models.dart` — data model, profiles, outcomes, and timing.
- `lib/domain/garden_store.dart` — serialized state transitions and atomic persistence boundary.
- `lib/domain/reminder_time.dart` — local calendar clocks and DST resolution.
- `lib/domain/watering_notification.dart` — bounded payload parsing, current/stale resolution, and stable IDs.
- `lib/main.dart` / `lib/ui/check_route.dart` — lifecycle-aware root routing and shared check identity.
- `lib/data/garden_repository.dart` — JSON file storage and first-run flags.
- `lib/data/watering_notifications.dart` — notification initialization, permission, and synchronization.
- `lib/ui/home_screen.dart` — Home, collection, and activity.
- `lib/ui/catalog_screen.dart` — supported catalog and setup.
- `lib/ui/check_screen.dart` — watering check and outcome flow.
- `lib/ui/plant_detail_screen.dart` — schedule details and removal.
- `lib/ui/preferences_screen.dart` — optional notification switch and global time picker.
- `lib/ui/light_placement_section.dart` — shared advice and optional checkbox.
- `integration_test/light_placement_test.dart` — on-device setup/detail/persistence checks with cache-file fixtures.
- `integration_test/reminders_test.dart` — persisted preference/custom timing and actual native notification-intent checks.
- `integration_test/notification_launch_app.dart` / `tool/check_notification_launch.py` / `tool/android/NotificationTapTest.java` — isolated cold-launch fixture and real drawer taps from a separate UI Automator process.
- `tool/test_android.sh` — isolated Android test runner; see the incident/procedure above.

## Product decision record

The full tradeoff history recovered from the original Bloom product work is maintained in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). It is platform-neutral and distinguishes current Android behavior from deferred and planned capabilities.

## Remaining verification

1. Review long-idle/OEM notification delivery and the real permission-denial/re-enable interaction. Notification routing has automated Android evidence above.
2. Review TalkBack labels, selected states, large Android font sizes, narrow layouts, dark theme behavior, and system animation settings.
3. Consider record-level correction/Undo as separate future scope; the configurable reminder time is now implemented.

## Soil health, Care timeline, and guarded Back — implemented and verified on 15 November 2026

The user requested timeline and navigation implementation, followed by Soil health, and explicitly confirmed drainage inside the checks while retaining the three actions (D48–D49 / PRD 18–20). This supersedes the earlier documentation-only stage. Soil health provides on-demand advice, explicit combined action records, optional date/context, and edit/remove through the timeline. It leaves watering/light/reminders unchanged.

Care timeline opens as a separate page from plant details and reads actual watering outcomes, combined soil events, and the current saved light confirmation. Existing light storage is a current snapshot; earlier light changes are not recoverable. Toolbar back arrows replace Close/Cancel page controls. Dirty setup/check/soil/assessment drafts require Keep editing / Discard changes on toolbar or system Back; clean/read-only pages leave immediately.

All six docs include scope, rationale, conservative assessment rules, navigation/discard behavior, and remaining limits. Current verification evidence follows; earlier release results below remain historical snapshots. No nutrition calendar, fourth drainage action, chemistry/health score, or pest/environmental feature is added.

Verification for this release:

- `flutter test --no-pub`: **73 tests passed**, including all seven non-empty action combinations, 81 complete assessment answer combinations, early/unknown exits, legacy JSON, future-date/ownership/failed-write checks, combined timeline events, nested routes, toolbar/system Back, keep/discard, successful-save exit, unavailable-reminder draft protection, soil edit/removal, and narrow 2x-text dark layouts.
- `flutter analyze --no-pub`: **zero findings**. Host checks ran from an identical temporary checkout without parentheses; source/test hashes were compared with the repo.
- `BLOOM_TEST_TARGET=integration_test/care_timeline_test.dart sh tool/test_android.sh -d emulator-5554`: **1 Android integration test passed**, exercising drainage's early result without a record, native Activity Back dispatch, preserved/discarded drafts, all three actions in one persisted event, disk reload, unchanged watering records/schedules, timeline editing, and return to the parent plant. The dedicated test package/cache file was used.
- Normal debug APK: **built successfully**, checked to exclude IntegrationActivity, installed in place with `adb install -r`, and launched successfully. Four normal saved files matched the pre-test backup before installation. After launch, the user explicitly confirmed saving a watering check; verified existing plants/preferences/soil history and prior records remained intact, and the new record/schedule transition matched that action. Post-launch byte equality is therefore not claimed. The isolated test package was removed afterward.
- Timeline Android fixture screenshot visually inspected. Full manual TalkBack and physical predictive-Back gesture audits remain outstanding; automated semantics/layout and native Activity Back coverage do not claim a complete manual accessibility audit.
- Known boundary: the light row reflects only the currently saved placement confirmation. The old model does not contain earlier confirmations/moves, so no historical events are invented. Watering records remain read-only; edit/remove applies to soil records only.


## Compact light presentation — implemented and verified on 15 November 2026

The user authorized the detail-card refinement on 15 November 2026 (D44 / PRD section 17), and reiterated the documentation requirement. Detail uses a collapsed requirement/report summary and expands to the existing advice/checkbox; setup, saved acknowledgment, watering, and reminders retain their established behavior. Expansion itself is not persisted and writes nothing. Verification:

- `flutter analyze --no-pub`: **zero findings**.
- `flutter test --no-pub`: **55 tests passed** (including pending/acknowledged compact states, expansion/collapse without writes, existing save/failure/correction, setup, and narrow 2x-text dark layout). Host source came from the same temporary checkout used to avoid the macOS path limitation above; changed file hashes match the repo.
- `sh tool/test_android.sh -d emulator-5554`: **2 isolated Android integration tests passed**, now also asserting the initially collapsed detail state before expansion. Setup remains fully visible and skippable; persistence/reload/correction and unchanged watering passed.
- Normal debug APK build: **passed**; dex checked to exclude IntegrationActivity. Installed with `adb install -r` and relaunched successfully.
- Compact Android detail screenshot captured from an isolated cache fixture and visually reviewed. A full manual TalkBack audit remains outstanding; Material expansion semantics are retained.
- Normal saved data backed up before device tests: all **4 saved files** matched before the normal update, and the **garden JSON stayed byte-for-byte identical after launch**. The separate `.integration` test package was removed afterward.

Soil health is now implemented under D49 / PRD section 18; current evidence is recorded above.
