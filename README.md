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

Current limitations are tracked in [`docs/STATUS.md`](docs/STATUS.md). In particular, record-level deletion, a configurable reminder time screen, notification tap routing, and support for arbitrary custom plants are not yet implemented.

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

The focused domain suite currently contains 12 tests. See the verification notes in [`docs/STATUS.md`](docs/STATUS.md).

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

Bloom is an assistant for remembering and recording plant checks. It does not diagnose disease, guarantee plant health, or claim that a date proves a plant needs water. Future environmental checks, nutrition, repotting, symptom guidance, additional plant profiles, and cloud sync are roadmap items, not current behavior.
