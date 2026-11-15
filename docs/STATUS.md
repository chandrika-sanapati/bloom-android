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
- Plant removal with schedule and record cleanup.
- Optional future-only Android notifications and permission-denied messaging.

## Not implemented

- Automated Dart tests: there is currently no `test/` directory.
- Record-level deletion or Undo.
- Adjustable dry follow-up window; the current implementation uses three days.
- A user-facing default reminder-time editor; the current default is 09:00.
- Arbitrary custom/unlisted plant creation or schedule setup.
- Notification tap deep-link routing to a specific check screen.
- Cloud sync, accounts, analytics, environmental checks, diagnosis, nutrition, repotting, or other care domains.

## Verification snapshot

- Flutter SDK available locally: 3.44.8.
- Dart SDK: 3.12.2.
- `flutter pub get`: passed.
- `flutter analyze`: completes, but exits non-zero with two `prefer_initializing_formals` info findings:
  - `lib/data/garden_repository.dart:13`
  - `lib/domain/garden_store.dart:11`
- `flutter test`: cannot run a suite because the `test/` directory does not exist.
- `flutter doctor -v`: Android toolchain, Android SDK, emulator, and network resources are available. Xcode/CocoaPods warnings are irrelevant to this Android target.
- Android Gradle build was not completed in the shell check because the shell's `java` command was not configured, although Flutter is configured to use Android Studio's JDK. Configure `JAVA_HOME` or `org.gradle.java.home` before treating the APK build as verified.

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

## Immediate next checks

1. Fix or intentionally document the two analyzer findings.
2. Add focused domain tests.
3. Configure the Android Studio JDK for Gradle and build a debug APK.
4. Run the complete add → check → edit → relaunch flow on the Android emulator.
5. Verify date entry, notification delivery, permission denial, TalkBack, and large-font layouts.
