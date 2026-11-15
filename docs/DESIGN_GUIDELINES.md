# Bloom Android interface guidelines

These guidelines apply to the Flutter Android app. They replace the former iOS/SwiftUI-specific guidance while preserving the product principles: calm hierarchy, explicit outcomes, progressive disclosure, and trustworthy history.

## Platform and typography

- Use Flutter Material 3 components and Android interaction conventions.
- Use the Android dynamic color scheme when available; fall back to Bloom teal on unsupported devices. Keep semantic statuses such as overdue/caution distinguishable from the theme's primary action color.
- Use the theme's system sans-serif typography and semantic `TextTheme` roles. Do not introduce arbitrary text sizes for emphasis.
- Allow Android font scaling to reflow content. Never truncate the primary action, outcome labels, dates, or error guidance to preserve a single-line layout.
- Use `headlineSmall` or `headlineMedium` for the screen title, `titleMedium`/`titleSmall` for sections, `bodyLarge`/`bodyMedium` for content, and `bodySmall`/`labelLarge` for supporting metadata.
- Keep common and scientific plant names together, with the scientific name italicized and visually secondary.

## Color and meaning

- Teal is the primary action and selected-state color.
- Blue/teal may identify watering information; amber may identify overdue or caution states.
- Neutral colors are for metadata, unselected controls, and empty states.
- Never communicate a state by color alone. Pair color with text, icon shape, or control state.
- Maintain readable contrast in light and dark themes where supported by the Material theme.

## Actions and navigation

- Give each screen one clear primary action.
- Use text-labelled buttons for commands such as **Add**, **Save**, **Check watering**, and **Remove plant**.
- Keep secondary actions explicit, such as **Edit next check** and **Cancel**; do not hide important commands behind an icon-only menu.
- Use standard Android back navigation and Flutter `Navigator` behavior. Screen titles should identify the current context without repeating the plant name unnecessarily.
- Do not preselect **Watered**. A save action must remain disabled or explain the missing outcome until the user chooses one.
- Use confirmation dialogs for destructive actions and state exactly what will be removed.

## Layout and components

- Use the existing 20dp page inset and an 8dp spacing rhythm where practical.
- Keep cards visually quiet with consistent padding and rounded corners. Do not turn every row into a competing card.
- Use `ListTile`, `SegmentedButton`, `RadioListTile`, `SwitchListTile`, `FilledButton`, and native date/time pickers consistently with the existing app.
- Keep plant identity, schedule state, and the primary check action near the top of plant details.
- Home should prioritize **My plants** and **Activity → Upcoming / Past**. Upcoming tasks are action-first; Past contains completed records only.
- Keep task copy concise: **Check watering**, plant name, and the due state/date are usually sufficient.

## Watering language

- Say **Check watering** or **Check the soil**, not “Water now,” for an unresolved task.
- Explain that a schedule is a starting point and actual conditions matter.
- Use exactly two completion outcomes: **Watered** and **Checked — not watered**.
- A dry or concerning non-watering check may receive a shorter follow-up. This is another check, not an instruction or a recovery promise.
- Use **Overdue** without blame. An overdue task remains visible until the user completes it or explicitly edits its next date.

## Accessibility

- Target at least 48dp for interactive controls, matching Android Material guidance.
- Ensure controls have useful TalkBack labels and expose selected, disabled, and error states semantically.
- Test at large Android font sizes and narrow widths. Rows should wrap or stack rather than overflow.
- Keep dates readable and provide enough context for a screen reader, including whether a date is a scheduled check or a recorded event.
- Respect Android system animation settings and avoid decorative motion.
- Do not rely on swipe-only discovery. Horizontal plant cards need visible identity and a tappable surface.

## Empty, error, and permission states

- Empty Home should name the next action: add a supported plant.
- Empty Upcoming should explain how to create the first check.
- Empty Past should explain that completed checks will appear there.
- Persistence failures must leave the in-memory garden unchanged and show actionable feedback.
- Notification denial must explain that in-app tasks remain available. Do not repeatedly prompt without an explicit user action.
- Missing or unavailable task data should fail safely with a clear recovery path.

## Product boundaries

Do not add custom plant intervals, diagnosis, environmental inference, live weather, cloud sync, or additional recurring care domains to the watering flow without a documented product decision and updated status entry.
