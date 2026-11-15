# Bloom (Android)

A focused Flutter app for intentional plant care: add a supported plant, check its soil, record whether you watered it, and see the next check.

Supported plants: Snake Plant, Monstera, Rubber Plant, and Pothos.

## Run

Requires Flutter 3.44 or later, and the Android SDK with a JDK (Android Studio's bundled JDK works).

```sh
flutter pub get
flutter run
```

Build a debug APK:

```sh
flutter build apk --debug
```

## Project layout

- `lib/domain/` — models, watering profiles, and the store that applies watering transitions.
- `lib/data/` — JSON persistence, first-run flags, and watering reminders.
- `lib/ui/` — Home, catalog and setup, plant detail, watering check, and preferences.
- `assets/images/` — plant photographs, shared with the iOS app.

## Product context

The `docs/` folder holds the product and design context, copied from the iOS repo:

- `docs/PRD.md` — product requirements.
- `docs/DESIGN_GUIDELINES.md` — interface and accessibility rules.
- `docs/IMPLEMENTATION_PLAN.md` — phases and simplification rules.
- `docs/AGENTS.md` — working guidance for contributors.
- `docs/previews/` — screenshots of the iOS design, for visual reference.

Those documents were written for the iOS app. They carry a banner noting which parts still apply.

## Status

Ported so far: the watering flow (add, check, next-check editing, removal), Home (Upcoming and Past), and preferences. Watering reminders are scheduled for future checks only, with permission requested when the user turns them on.

Not yet verified: date entry in "Edit next check," and that a reminder fires at its scheduled time.
