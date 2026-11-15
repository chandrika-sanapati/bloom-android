# Bloom for Android

Bloom is a focused Flutter app for intentional plant care. It helps a user add a supported houseplant, check its soil, record what actually happened, and see the next check.

The Android app is local-first: garden data is stored on the device and watering notifications are optional. A schedule is a prompt to inspect the plant, not an instruction to water on a date.

## Current scope

Supported catalog plants:

- Snake Plant — *Dracaena trifasciata*
- Monstera — *Monstera deliciosa*
- Rubber Plant — *Ficus elastica*
- Pothos — *Epipremnum aureum*

The current app supports:

- Adding one of the four catalog plants.
- Optionally supplying a last-watered date during setup.
- A plant-type starting check interval.
- Home with **My plants** and **Activity → Upcoming / Past**.
- **Watered** and **Checked — not watered** outcomes.
- Soil context: Dry, Damp, or Not sure.
- A three-day follow-up after a dry, non-watering check.
- Editing the next check date and time.
- Removing a plant and its local watering history.
- Local JSON persistence and optional future-check notifications.
- Android notification permission handling that leaves in-app tasks available when permission is denied.
- Notifications use best-effort inexact Android scheduling and never block app startup.
- Material 3 light/dark themes using Android dynamic colors when available, with Bloom teal as the fallback.
- Species-specific light/placement advice during setup and on plant detail.
- Optional saved acknowledgment that the user placed the plant as suggested; watering dates stay unchanged.

Current limitations are tracked in [`docs/STATUS.md`](docs/STATUS.md). In particular, record-level deletion, a configurable reminder time screen, notification tap routing, and support for arbitrary custom plants are not yet implemented.

## Light & placement

Bloom shows a species-specific Light & placement suggestion during Add a plant and on plant detail. Users can optionally acknowledge acting on it during setup or later, and the app stores that state per plant. This replaces the earlier dim/bright concern-picker proposal. Placement acknowledgment adds no recurring light reminders.

The user confirmed that placement acknowledgment will leave watering schedules unchanged in this release; adaptation will be handled separately later. Review [PRD section 14](docs/PRD.md#14-light--placement--release-requirements), [current decisions D28–D31](docs/PRODUCT_DECISIONS.md#13-light--placement-release-decisions), and [the implementation plan](docs/IMPLEMENTATION_PLAN.md#7-light--placement--implementation-sequence). The flow was implemented and verified on 15 November 2026. See [STATUS.md](docs/STATUS.md) for verification evidence, remaining checks, and the emulator-data incident.

## Requirements

- Flutter 3.44.8 or later.
- Dart 3.12.2 or later.
- Android SDK with the platform and build tools required by `android/app/build.gradle.kts`.
- A JDK supplied by Android Studio or another Android-compatible JDK.

Flutter is not committed to this repository. Use the `flutter` command if it is on your PATH, or configure a local Flutter version manager and run the equivalent commands through it.

## Run locally

```sh
flutter pub get
flutter run
```

Build a debug APK:

```sh
flutter build apk --debug
```

Useful checks:

```sh
flutter analyze
flutter test
```

The domain/widget suite contains 30 tests. Two Android integration tests cover the light-placement flow; run them with `sh tool/test_android.sh -d emulator-5554` to use the separate test package and disable uninstall cleanup. See [`docs/STATUS.md`](docs/STATUS.md) for the macOS path limitation and verification notes.

## Project layout

- `lib/domain/` — garden models, supported plant profiles, and schedule transitions.
- `lib/data/` — local JSON persistence, first-run flags, and Android watering notifications.
- `lib/ui/` — Home, catalog/setup, plant detail, watering check, and preferences screens.
- `assets/images/` — bundled plant and empty-state images.
- `android/` — the Android host and Gradle configuration.
- `docs/` — product requirements, Android/Flutter design guidance, status, and roadmap.

## Documentation

- [`docs/STATUS.md`](docs/STATUS.md) — current implementation and verification source of truth.
- [`docs/PRD.md`](docs/PRD.md) — product intent, behavior contract, scope, and roadmap.
- [`docs/PRODUCT_DECISIONS.md`](docs/PRODUCT_DECISIONS.md) — recovered product decisions, alternatives, tradeoffs, and revisit triggers.
- [`docs/DESIGN_GUIDELINES.md`](docs/DESIGN_GUIDELINES.md) — Android/Flutter interaction and accessibility guidance.
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) — completed work and the next engineering steps.
- [`docs/AGENTS.md`](docs/AGENTS.md) — contribution and UX/engineering guidance.
- [`docs/previews/README.md`](docs/previews/README.md) — explicitly historical iOS design references; not a specification for the Android UI.

## Product boundary

Bloom is an assistant for remembering and recording plant checks. It does not diagnose disease, guarantee plant health, or claim that a date proves a plant needs water. Broader environmental assessments, nutrition, repotting, symptom guidance, additional plant profiles, and cloud sync remain roadmap items.
