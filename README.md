# Bloom for Android

Bloom is a focused Flutter app for intentional plant care. It helps a user add a supported houseplant, check its soil, record what actually happened, and see the next check.

The Android app is local-first: garden data is stored on the device and watering notifications are optional. A schedule is a prompt to inspect the plant, not an instruction to water on a date.

## Current scope

Bloom uses the existing Snake Plant artwork as its in-app brand mark and Android launcher icon.

The bundled offline profile catalog holds the current 50-profile test inventory; all 50 are marked reviewed and searchable in Add a plant. Supabase is the managed profile source when available. The five curated **Popular plants** shown before typing are Pothos, Snake Plant, Monstera, Spider Plant, and Rubber Plant.

The current app supports:

- **Theme:** a fixed dark-forest-green Material 3 light/dark theme (seed `#2E6B3A`, fidelity variant); Android wallpaper dynamic color is not used. Shared component styling lives in `bloomTheme` in `lib/main.dart`; overscroll stretch is disabled app-wide.
- **Home:** greeting header with **+** (add plant) and an avatar initial that opens Profile; a **Today** card listing due/overdue plants with a **Check** button each (or "Nothing to check today"); a **My plants · N** two-column photo grid with an Add plant tile; **Recent** (last three activities across plants, all care types, with See all).
- **Add a plant:** a bottom sheet offers **Search by name** or **Identify from a photo**. Search filters live by common name, scientific name, and aliases (name matches first). Setup shows the species photo, an optional last-watered date, Light & placement with a room-scene illustration and an optional "I've placed it as suggested" checkbox, and **Add plant** pinned at the bottom.
- **Plant page:** collapsing hero photo with Back and a ⋮ menu (Edit name and plant image; Delete); a photo-count chip opens the growth gallery. A status card shows **Next check** (tap to change), **Last watered**, and the primary **Check & water** button, tinted only when due. Quick actions: **Add photo** (dot badge when no photo in 30 days) and **Soil care**. The care guide shows the watering cue and a collapsed light row that expands to a room-scene illustration, placement text, and "Is it in a spot like this?" (Yes / Not yet); it asks again when the guidance version changes. History shows the last five entries with See all.
- **Check & water:** **Watered** and **Checked — not watered** outcome cards; soil feel (Dry, Damp, Not sure) is asked only when not watered; Save pinned at the bottom, with a snackbar showing the next check date. A dry, non-watering check schedules a three-day follow-up. Edit next check is available from the check screen and the plant page.
- **Full timeline** ("<plant> history"): grouped by month; tap a soil-care entry to edit, the latest watering record to delete (with Undo), or a photo to view it.
- **Soil care:** records care the user did (adding nutrients, refreshed mix, repotting; combinable in one record). Bloom no longer runs a soil-health questionnaire.
- **Growth photos:** camera or gallery, stored only in app-private storage and never synced; viewer with delete and "Use as plant image"; deleted with the plant or account.
- **Multi-select delete on Home:** long-press a plant (or tap Select), then delete several plants with one confirmation, including their history and photos.
- **Profile:** avatar header with email and "N plants · Synced / Syncing… / Sync pending"; **Reminders** (Notifications switch, Reminder time); **Account** (Sign out, Delete account).
- Local JSON persistence; an unreadable `garden.json` is backed up as `garden.unreadable-<timestamp>.json` before Bloom starts with an empty garden.
- Optional, best-effort inexact Android notifications ("Check & water") that never block startup; denied permission is recoverable from Profile through Android settings, and in-app checks remain available.
- Photo identification through the authenticated Supabase Edge Function, with likelihood labels (Very likely, Possible, Less likely) and safe handling of identities without a Bloom care guide.
- Plants added through search or photo identification share the canonical care profile when the type matches; separate plants keep separate histories.
- Native back arrows and confirmation before discarding unsaved form changes.

Current limitations and manual verification status are tracked in [`docs/STATUS.md`](docs/STATUS.md). In particular, arbitrary custom plants, exact notification timing, and several manual Android/accessibility checks remain outside the current scope.

## Light & placement

Bloom shows a species-specific Light & placement suggestion during Add a plant and on plant detail. Users can optionally acknowledge acting on it during setup or later, and the app stores that state per plant. This replaces the earlier dim/bright concern-picker proposal. Placement acknowledgment adds no recurring light reminders.

The user confirmed that placement acknowledgment will leave watering schedules unchanged in this release; adaptation will be handled separately later. Review [PRD section 14](docs/PRD.md#14-light--placement--release-requirements), [current decisions D28–D31](docs/PRODUCT_DECISIONS.md#13-light--placement-release-decisions), and [the implementation plan](docs/IMPLEMENTATION_PLAN.md#7-light--placement--implementation-sequence). The flow was implemented and verified on 15 November 2026. See [STATUS.md](docs/STATUS.md) for verification evidence, remaining checks, and the emulator-data incident.

## Reminder time and notification navigation

Profile contains a **Reminders** section (Notifications switch and a global **Reminder time** native time picker) and an **Account** section. Cloud synchronization runs in the background; Profile shows only a short sync status next to the plant count. Changes update automatic checks after today; custom, today's, overdue, and unclassified older check times are preserved. First/completed automatic checks use the preferred local clock. Notification taps open the specific current watering check; stale/legacy reminders open plant detail, and unavailable targets return Home. See [PRD section 15](docs/PRD.md#15-reminder-preferences-and-notification-navigation--requirements), [D33–D40](docs/PRODUCT_DECISIONS.md#14-reminder-preferences-and-navigation-decisions), and [implementation plan section 8](docs/IMPLEMENTATION_PLAN.md#8-reminder-preferences-and-notification-navigation--implementation-plan).

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

Build a debug APK (local-only, no cloud configuration):

```sh
flutter build apk --debug
```

Useful checks:

```sh
flutter analyze
flutter test
```

The domain/widget suite (111 tests) covers watering, placement, reminder timing, soil care, the care timeline, growth photos, auth UI, sync, and notification navigation. Run `sh tool/test_android.sh -d emulator-5554` for placement, or set `BLOOM_TEST_TARGET` to `integration_test/care_timeline_test.dart` or `integration_test/reminders_test.dart` for the other Android integration suites. All use the separate test package and disable uninstall cleanup. Run `python3 tool/check_notification_launch.py` for real notification-drawer taps after process death. These runners grant notification permission only to the isolated test package. See [`docs/STATUS.md`](docs/STATUS.md) for the macOS path limitation and verification notes.

## Project layout

- `lib/domain/` — garden models, plant profiles, soil care, activity, and schedule transitions.
- `lib/data/` — local JSON persistence, growth-photo files, profile catalog, auth, cloud sync, plant identification, and Android watering notifications.
- `lib/ui/` — Home, catalog/setup, plant page, Check & water, timeline, growth photos, soil care, Profile, login, and photo identification. Shared pieces (SectionHeader, MessageBanner, BottomAction, PlantImage, HistoryRow, relative date labels) are in `lib/ui/widgets.dart`.
- `assets/data/` — bundled plant profile catalog. `assets/images/` — bundled plant and illustration images.
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

When Supabase configuration is supplied, Bloom requires authentication before Home and supports Google plus email/password registration and sign-in. Registration uses a six-digit email OTP and immediately signs the user in after verification; later email/password logins do not require OTP. The Supabase Confirm signup template must include `{{ .Token }}`. The local garden remains authoritative: an empty cloud row receives the local garden, and differing cloud data is guarded-overwritten using the remote revision. Every successful local save queues asynchronous cloud synchronization; local persistence never waits for or rolls back because of a cloud failure. Sync runs quietly in the background. Without Supabase configuration, local/test builds remain usable without an account.

The login page has a welcome header image, **Continue with Google** first (when `GOOGLE_WEB_CLIENT_ID` is configured), then email with a Sign in / Create account switch and a password strength bar while registering. Email confirmation uses six code boxes that verify automatically on the sixth digit, with a 45-second resend countdown. The page has no toolbar Back button. When a user signs out, Bloom confirms the action, preserves the local garden, stops authenticated sync, and returns to the root login page.

Photo identification is configured only with a Supabase Edge Function endpoint at build time. Never put the PlantNet API key in Flutter, Git, or an APK; store it as an Edge Function secret.

Configured builds read their settings from a local JSON file. Copy `config/prod.example.json` to `config/prod.json` (`config/*.json` is git-ignored apart from the template), fill in `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `PLANT_IDENTIFIER_ENDPOINT`, and optionally `GOOGLE_WEB_CLIENT_ID`, then build or run with:

```sh
flutter build apk --release --dart-define-from-file=config/prod.json
flutter run --dart-define-from-file=config/prod.json
```

Without these values Bloom remains local-first.

The Android OAuth client and Supabase Google provider must be configured before Google sign-in is enabled. The current Android OAuth client uses package `com.chandrika.bloom` and the debug keystore SHA-1. Release builds are currently signed with the debug key; a real release key (and its SHA-1 registered with Google) is still required before a Play Store release. Email/password authentication only requires the configured Supabase project and its email provider settings. In configured builds, authentication is mandatory before Home; unconfigured builds remain local-only for development and tests.

## Product boundary

Bloom is an assistant for remembering and recording plant checks. It does not diagnose disease, guarantee plant health, or claim that a date proves a plant needs water. Broader environmental assessments, soil diagnosis/chemistry, additional plant profiles, sharing, analytics, and social capabilities remain outside the current scope. Soil care records only what the user did.

## Current development mode: stabilization only

Bloom is currently under a feature freeze. No new product features or feature expansion should be implemented. On 17 November 2026 the owner approved a UX overhaul as an explicit exception; it is complete and described above. Engineering work is otherwise limited to stabilizing the existing watering, reminders, auth/cloud sync, PlantNet/photo, growth photo, soil care, timeline, correction, placement, and navigation flows; improving persistence, accessibility, error handling, tests, documentation, and release readiness; and fixing regressions.

## Soil care, plant timeline, and Back navigation

The **Soil care** form records three distinct, overlapping actions: **Added nutrients**, **Refreshed potting mix**, and **Repotted**. One combined record supports jobs involving multiple actions, with edit/remove available through the timeline. Watering remains primary and no recurring soil-care schedule exists.

*Superseded (17 November 2026):* the on-demand Soil health questionnaire (three checks, including drainage) implemented on 15 November 2026 was removed; Bloom no longer assesses soil. The per-plant timeline and guarded Back navigation remain. Historical context: [PRD section 18](docs/PRD.md#18-soil-health--release-requirements), [D45–D47](docs/PRODUCT_DECISIONS.md#15-soil-health-requirements-decisions), and STATUS.md.

## Compact sunlight guidance

The plant page shows the light row collapsed by default inside the care guide; it expands to a room-scene illustration, placement text, and a Yes / Not yet confirmation. First implemented and verified on 15 November 2026; restyled in the 17 November 2026 UX overhaul. See [PRD section 17](docs/PRD.md#17-light--placement--occasional-care-presentation-refinement), decision D44, implementation plan section 10, and STATUS.md for the detailed contract and verification. This does not add recurring light tasks or nutrient features.
