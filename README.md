# Bloom for Android

Bloom is a focused Flutter app for intentional plant care. It helps a user add a supported houseplant, check its soil, record what actually happened, and see the next check.

The Android app is local-first: garden data is stored on the device and watering notifications are optional. A schedule is a prompt to inspect the plant, not an instruction to water on a date.

## Current scope

Supported catalog plants:

- Snake Plant — *Dracaena trifasciata*
- Monstera — *Monstera deliciosa*
- Rubber Plant — *Ficus elastica*
- Pothos — *Epipremnum aureum*
- Spider Plant — *Chlorophytum comosum*

The current app supports:

- Adding one of the five reviewed catalog plants.
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
- Denied notification permission is recoverable from Profile → Preferences through Android settings; in-app checks remain available.
- Material 3 light/dark themes using Android dynamic colors when available, with Bloom teal as the fallback.
- A labeled FAB menu for Search by name and Identify from a photo.
- Photo identification through the authenticated Supabase Edge Function, normalized candidate results, candidate confirmation, and safe unsupported-identity handling.
- Species-specific light/placement advice during setup and on plant detail.
- Optional saved acknowledgment that the user placed the plant as suggested; watering dates stay unchanged.
- On-demand Soil health checks, including drainage, plus separate or combined nutrient/mix-refresh/repotting records.
- A dedicated Care timeline from each plant page, with soil-care correction/removal.
- Native back arrows and confirmation before discarding unsaved form changes.

Current limitations and manual verification status are tracked in [`docs/STATUS.md`](docs/STATUS.md). In particular, arbitrary custom plants, exact notification timing, and several manual Android/accessibility checks remain outside the current scope.

## Light & placement

Bloom shows a species-specific Light & placement suggestion during Add a plant and on plant detail. Users can optionally acknowledge acting on it during setup or later, and the app stores that state per plant. This replaces the earlier dim/bright concern-picker proposal. Placement acknowledgment adds no recurring light reminders.

The user confirmed that placement acknowledgment will leave watering schedules unchanged in this release; adaptation will be handled separately later. Review [PRD section 14](docs/PRD.md#14-light--placement--release-requirements), [current decisions D28–D31](docs/PRODUCT_DECISIONS.md#13-light--placement-release-decisions), and [the implementation plan](docs/IMPLEMENTATION_PLAN.md#7-light--placement--implementation-sequence). The flow was implemented and verified on 15 November 2026. See [STATUS.md](docs/STATUS.md) for verification evidence, remaining checks, and the emulator-data incident.

## Reminder time and notification navigation

Profile contains account controls, cloud-sync status, and a Preferences section with a global **Reminder time** native time picker. Changes update automatic checks after today; custom, today's, overdue, and unclassified older check times are preserved. First/completed automatic checks use the preferred local clock. Notification taps open the specific current watering check; stale/legacy reminders open plant detail, and unavailable targets return Home. See [PRD section 15](docs/PRD.md#15-reminder-preferences-and-notification-navigation--requirements), [D33–D40](docs/PRODUCT_DECISIONS.md#14-reminder-preferences-and-navigation-decisions), and [implementation plan section 8](docs/IMPLEMENTATION_PLAN.md#8-reminder-preferences-and-navigation--implementation-plan).

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

The domain/widget suite covers watering, placement, reminder timing, soil health, care timeline, and notification navigation. Run `sh tool/test_android.sh -d emulator-5554` for placement, or set `BLOOM_TEST_TARGET` to `integration_test/care_timeline_test.dart` or `integration_test/reminders_test.dart` for the other Android integration suites. All use the separate test package and disable uninstall cleanup. Run `python3 tool/check_notification_launch.py` for real notification-drawer taps after process death. These runners grant notification permission only to the isolated test package. See [`docs/STATUS.md`](docs/STATUS.md) for the macOS path limitation and verification notes.

## Project layout

- `lib/domain/` — garden models, supported plant profiles, and schedule transitions.
- `lib/data/` — local JSON persistence, first-run flags, and Android watering notifications.
- `lib/ui/` — Home, catalog/setup, plant detail, watering check, Profile/Preferences, photo identification, and care screens.
- `assets/images/` — bundled plant and empty-state images.
- `android/` — the Android host and Gradle configuration.
- `docs/` — product requirements, Android/Flutter design guidance, status, and roadmap.

## Documentation

- [`docs/STATUS.md`](docs/STATUS.md) — current implementation and verification source of truth.
- [`docs/STABILIZATION_CHECKLIST.md`](docs/STABILIZATION_CHECKLIST.md) — active stabilization-only verification queue.
- [`docs/PRD.md`](docs/PRD.md) — product intent, behavior contract, scope, and roadmap.
- [`docs/PRODUCT_DECISIONS.md`](docs/PRODUCT_DECISIONS.md) — recovered product decisions, alternatives, tradeoffs, and revisit triggers.
- [`docs/DESIGN_GUIDELINES.md`](docs/DESIGN_GUIDELINES.md) — Android/Flutter interaction and accessibility guidance.
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) — completed work and the next engineering steps.
- [`docs/AGENTS.md`](docs/AGENTS.md) — contribution and UX/engineering guidance.
- [`docs/previews/README.md`](docs/previews/README.md) — explicitly historical iOS design references; not a specification for the Android UI.
- [`docs/BACKEND_PLAN.md`](docs/BACKEND_PLAN.md) — Supabase, Google sign-in, PlantNet proxy, sync, privacy, and rollout plan.

When Supabase configuration is supplied, Bloom requires authentication before Home and supports Google plus email/password registration and sign-in. Email confirmation is explained when Supabase requires it. The local garden remains authoritative: an empty cloud row receives the local garden, and differing cloud data is guarded-overwritten using the remote revision. Every successful local save queues asynchronous cloud synchronization; local persistence never waits for or rolls back because of a cloud failure. Sync status is visible in Profile. Without Supabase configuration, local/test builds remain usable without an account.

Photo identification is configured only with a Supabase Edge Function endpoint at build time. Never put the PlantNet API key in Flutter, Git, or an APK; store it as an Edge Function secret.

Configured cloud/identification run example:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=PLANT_IDENTIFIER_ENDPOINT=https://<project-ref>.supabase.co/functions/v1/identify-plant
```

Without these defines Bloom remains local-first.

Optional Google sign-in also requires:

```sh
--dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

The Android OAuth client and Supabase Google provider must be configured before Google sign-in is enabled. Email/password authentication only requires the configured Supabase project and its email provider settings. In configured builds, authentication is mandatory before Home; unconfigured builds remain local-only for development and tests.

## Product boundary

Bloom is an assistant for remembering and recording plant checks. It does not diagnose disease, guarantee plant health, or claim that a date proves a plant needs water. Broader environmental assessments, chemistry/diagnosis, additional plant profiles, sharing, analytics, and social capabilities remain outside the current scope. Soil health supports the on-demand care described below.

## Current development mode: stabilization only

Bloom is currently under a feature freeze. No new product features or feature expansion should be implemented. Engineering work is limited to stabilizing the existing watering, reminders, auth/cloud sync, PlantNet/photo, Soil health, timeline, correction, placement, and navigation flows; improving persistence, accessibility, error handling, tests, documentation, and release readiness; and fixing regressions.

## Soil health, plant timeline, and Back navigation

The app includes a separate **Soil health** section with three distinct, overlapping actions: **Adding nutrients**, **Refresh potting mix**, and **Repotting**. On-demand checks help users decide whether to act; watering remains primary and no automatic recurring soil-care schedule is approved. One combined record supports jobs involving multiple actions, with edit/remove available through the timeline.

The user subsequently requested implementation of Soil health, a dedicated per-plant Care timeline, and back arrows with unsaved-form discard confirmation. Drainage is confirmed inside the checks while retaining three actions. These features are implemented and verified; evidence is in STATUS.md; PRD sections 18–20 and D48–D49 define the release. See [PRD section 18](docs/PRD.md#18-soil-health--release-requirements), [D45–D47](docs/PRODUCT_DECISIONS.md#15-soil-health-requirements-decisions), [implementation plan section 11](docs/IMPLEMENTATION_PLAN.md#11-soil-health--documentation-and-implementation-plan-for-review), and STATUS.md for boundaries and open decisions.

## Compact sunlight guidance

Plant details now shows a compact, expandable Light & placement section, with watering kept primary and existing setup/acknowledgment behavior retained. Implemented and verified on 15 November 2026. See [PRD section 17](docs/PRD.md#17-light--placement--occasional-care-presentation-refinement), decision D44, implementation plan section 10, and STATUS.md for the detailed contract and verification. This does not add recurring light tasks or nutrient features.
