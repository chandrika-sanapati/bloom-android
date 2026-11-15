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
- A user-facing default reminder-time editor; the current default is 09:00.
- Arbitrary custom/unlisted plant creation or schedule setup.
- Notification tap deep-link routing to a specific check screen.
- Exact delivery timing; Android may deliver inexact alarms within its allowed window.
- Cloud sync, accounts, analytics, environmental checks, diagnosis, nutrition, repotting, or other care domains.

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

The first Android integration run used the normal `com.chandrika.bloom` package. Flutter 3.44.8 defaults to uninstalling its test app after completion, which removed Bloom and cleared the emulator's existing local garden. No pre-test backup was taken, and those prior entries/history have not been restored. This was a verification mistake, not a plant-data migration. Do not claim that the user's emulator garden was preserved.

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
- `lib/domain/garden_store.dart` — state transitions and persistence boundary.
- `lib/data/garden_repository.dart` — JSON file storage and first-run flags.
- `lib/data/watering_notifications.dart` — notification initialization, permission, and synchronization.
- `lib/ui/home_screen.dart` — Home, collection, and activity.
- `lib/ui/catalog_screen.dart` — supported catalog and setup.
- `lib/ui/check_screen.dart` — watering check and outcome flow.
- `lib/ui/plant_detail_screen.dart` — schedule details and removal.
- `lib/ui/preferences_screen.dart` — notification preference.
- `lib/ui/light_placement_section.dart` — shared advice and optional checkbox.
- `integration_test/light_placement_test.dart` — on-device setup/detail/persistence checks with cache-file fixtures.
- `tool/test_android.sh` — isolated Android test runner; see the incident/procedure above.

## Product decision record

The full tradeoff history recovered from the original Bloom product work is maintained in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). It is platform-neutral and distinguishes current Android behavior from deferred and planned capabilities.

## Remaining verification

1. Verify notification delivery and permission denial on-device.
2. Review TalkBack labels, selected states, large Android font sizes, narrow layouts, dark theme behavior, and system animation settings.
3. Decide whether record-level correction/Undo and a configurable reminder time belong in the next release.
