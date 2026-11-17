# Repository guidance

## Project context

The active target is the Flutter Android app in this repository. The Android implementation and [`STATUS.md`](STATUS.md) are the source of truth for what exists. The product documents describe intended behavior, but must not claim that a feature is shipped until it is present in `lib/` and verified.

The app is local-first and currently focused on watering check-ins for five reviewed catalog plants. Configured builds require authentication and synchronize the local-authoritative garden asynchronously. Preserve local garden data and existing user changes when modifying persistence or the domain model. Prefer small, focused changes that match the existing Flutter structure.

## Scope freeze

On 17 November 2026 the owner approved a UX improvement list (plant page redesign, growth photos, multi-select delete, single account deletion) as an explicit exception to the freeze below.


The repository is currently in a stabilization-only feature freeze. Do not add new product features, care domains, plant profiles, sync modes, identification behavior, or navigation destinations. Work only on bugs, reliability, data safety, accessibility, test coverage, documentation, and release readiness for behavior already present. Future ideas may be documented but must not be implemented without explicit scope approval.

## Product and UX responsibility

Work at a senior mobile UX/UI designer level as well as an engineer. Aim for a finished, customer-ready interface rather than a merely functional arrangement of controls.

- Keep the primary customer task direct. Avoid unnecessary setup, friction, duplicate information, and making optional features feel mandatory.
- Use hierarchy and restraint: establish one clear primary action, group related information, apply spacing consistently, and reveal secondary configuration progressively.
- Use Android conventions and Flutter Material 3 controls while preserving Bloom's calm, plant-focused visual language.
- Sweat the details: concise labels, useful empty/loading/error/success states, accessible touch targets, text scaling, TalkBack semantics, and sensible back navigation.
- A due date means “check the plant,” not “water automatically.” Do not use language or defaults that imply otherwise.
- Never record watering unless the user explicitly chooses **Watered**. **Checked — not watered** is a meaningful outcome.
- When a requested change seems likely to harm usability, briefly explain the tradeoff and recommend a stronger alternative before making a materially different change.
- Ask a focused question when the intended product tradeoff is unclear. Do not silently override an explicit decision.

## Engineering guidance

- Keep schedule transitions in `lib/domain/garden_store.dart`; do not let screens mutate schedule state directly.
- Keep profile content in `lib/domain/models.dart` or a dedicated domain file rather than hard-coding plant-specific behavior in widgets.
- Persist schedule and record changes through the repository's single save boundary.
- Treat notification permission as optional. In-app tasks must remain usable if permission is denied or unavailable.
- Do not add silent schedule changes, unsupported plant advice, or fake fallback intervals.
- Run tests and build checks when the user requests verification or when a change requires validation. State clearly when a check is unavailable because tooling or test coverage is missing.
- Before pushing, inspect `git diff`, confirm the working tree contains only intentional changes, and use a descriptive commit message.
