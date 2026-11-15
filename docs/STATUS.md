# Bloom Android status

**Last checked:** 15 November 2026
**Branch:** `main`
**Target:** Flutter Android

This is the short, current implementation record. If it conflicts with an older screenshot, planning note, or copied design document, this file and the code are authoritative.

## Implemented

- Flutter app entry point and Material 3 shell.
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
- Focused domain tests for profiles, timing, watering transitions, editing, and failed persistence.

## Not implemented

- Record-level deletion or Undo.
- Adjustable dry follow-up window; the current implementation uses three days.
- A user-facing default reminder-time editor; the current default is 09:00.
- Arbitrary custom/unlisted plant creation or schedule setup.
- Notification tap deep-link routing to a specific check screen.
- Exact delivery timing; Android may deliver inexact alarms within its allowed window.
- Cloud sync, accounts, analytics, environmental checks, diagnosis, nutrition, repotting, or other care domains.

## Verification snapshot

- Flutter SDK available locally: 3.44.8.
- Dart SDK: 3.12.2.
- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed; 12 focused tests.
- `flutter doctor -v`: Android toolchain, Android SDK, emulator, and network resources are available. Xcode/CocoaPods warnings are irrelevant to this Android target.
- Android debug APK build: passed using Android Studio's JDK; output is `build/app/outputs/flutter-apk/app-debug.apk`.
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

## Product decision record

The full tradeoff history recovered from the original Bloom product work is maintained in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). It is platform-neutral and distinguishes current Android behavior from deferred and planned capabilities.

## Remaining verification

1. Verify notification delivery and permission denial on-device.
2. Review TalkBack labels, selected states, large Android font sizes, narrow layouts, dark theme behavior, and system animation settings.
3. Decide whether record-level correction/Undo and a configurable reminder time belong in the next release.
