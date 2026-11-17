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
- Use a labeled FAB menu for related plant-entry choices. Keep **Search by name** and **Identify from a photo** explicit; do not rely on icon-only discovery.

## Layout and components

- Use the existing 20dp page inset and an 8dp spacing rhythm where practical.
- Keep cards visually quiet with consistent padding and rounded corners. Do not turn every row into a competing card.
- Label optional setup sections consistently: both **Last watered** and **Light & placement** show **Optional** beside the heading with matching secondary typography, spacing, and wrapping.
- Use `ListTile`, `SegmentedButton`, `RadioListTile`, `SwitchListTile`, `FilledButton`, and native date/time pickers consistently with the existing app.
- Keep plant identity, schedule state, and the primary check action near the top of plant details.
- Home should prioritize **My plants** and **Activity → Upcoming / Past**. Upcoming tasks are action-first; Past contains completed records only.
- Keep task copy concise: **Check watering**, plant name, and the due state/date are usually sufficient.

## Watering language

- Say **Check watering** or **Check the soil**, not “Water now,” for an unresolved task.
- Explain that a schedule is a starting point and actual conditions matter.
- Use exactly two completion outcomes: **Watered** and **Checked — not watered**.
- Ask for soil condition only after **Checked — not watered** is selected. Keep the **Watered** path focused and immediately saveable.
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

Do not add custom plant intervals, diagnosis, environmental inference, live weather, cloud merge/sharing, or additional recurring care domains to the watering flow. Preserve the implemented local-wins cloud sync as a separate authenticated service.

## Light & placement

**State:** Approved flow implemented on 15 November 2026; verification evidence and remaining checks in STATUS.md. Follow [PRD section 14](PRD.md#14-light--placement--release-requirements) and current decisions D28–D31. The earlier concern-picker flow is superseded. The user has reviewed the proposal and explicitly authorized this scope; adaptation is deferred.

- Add the Light & placement section inside the existing Add a plant screen alongside Last watered, with no extra page. Show a short species light requirement and practical placement suggestion immediately.
- Show the same suggestion near Watering on plant detail, including the current saved acknowledgment state.
- Use one optional, initially unchecked control labelled **I've placed it as suggested**. It means acted rather than read. Adding a plant must remain possible without checking it; no separate Skip action is necessary.
- A user who skipped setup can acknowledge on detail later. The control saves immediately, shows saving/error feedback, and supports correction through the same control. No separate placement-save page or required date edit.
- Remove dim/bright choices, a third uncertainty route, concern-specific response branches, and location/light questionnaires. Additional inputs to resolve insufficient light data would add complexity; this release asks only about action on the species suggestion.
- Treat absence of acknowledgment as unconfirmed, not unsuitable light. Do not claim measured/verified exposure, an exact movement date, or diagnose damage. Use source-reviewed copy with species-specific nuance around direct sun.
- Checking/unchecking affects only placement acknowledgment. No watering-date effect, additional confirmation, or adaptation control in this release. Keep an old-version acknowledgment as earlier guidance with a quiet inline note; never expire it or prompt automatically.
- Keep Watered, Checked — not watered, Last watered, and existing watering controls understandable. Placement acknowledgment is a different fact and must not appear as a watering completion.
- No new recurring light reminders, light activity tasks, repeated acknowledgment nudges, or automatic onboarding prompts. A user can leave the input unacknowledged indefinitely.
- Use 48dp targets, text with icons, dynamic light/dark themes, reflowing content, TalkBack selected/saving/error states, and ordinary Android back navigation.

## Reminder preferences and notification navigation

**State:** Reviewed, authorized, and implemented on 15 November 2026. Follow [PRD section 15](PRD.md#15-reminder-preferences-and-notification-navigation--requirements) and decisions D33–D40. Verification evidence and remaining manual accessibility checks are in STATUS.md.

- Keep Profile compact: account first, followed by a Reminders section containing the Notifications switch plus one Reminder time row. Do not expose implementation-level cloud-sync status as a separate section. Show device-formatted local time and use the native picker with one final confirmation, not another settings page or dialog.
- Keep authentication compact and consistent: use one email-first login page for both the startup gate and Profile sign-in, place Google below it as a secondary option when configured, and do not add a toolbar Back button. Sign-out uses an explicit confirmation and returns to the root login gate.
- Use the existing Snake Plant artwork consistently as the Bloom brand mark in the Home title, login page, and Android launcher icon. Keep the artwork readable at small launcher sizes.
- Registration confirmation is a separate positive verification state with a six-digit code field, Verify email, Send code again, and a Back arrow to return to registration.
- Offer one destructive **Delete account** control in a clearly labeled Data & privacy section. It removes the account and all plant data after one explicit confirmation that states what is removed; preserve data if server deletion fails.
- Explain the scope simply: **Applies to automatic checks after today. Custom times and today's checks stay unchanged.** Preserve calendar dates and overdue checks as specified in PRD 15.4. Do not offer bulk overwrite of user-set times.
- Proposed legacy safeguard: when an older saved check's origin is unknown, preserve its time and explain only when relevant. Do not ask users to classify their garden. Custom provenance is internal state, not a new required field or recurring per-plant settings flow.
- Keep the row usable with notifications off/denied and explain that enabling notifications is separate. Changing time alone never opens a permission prompt.
- Distinguish a failed save from a saved preference with unavailable notifications. Use brief inline/snackbar feedback, preserve the last committed state, and avoid repeated taps while saving.
- State that Android may deliver later; do not show an exact-delivery guarantee or add technical alarm/permission controls to the flow.
- Notification copy names the plant and asks for a soil check. A valid tap opens Check watering with neither outcome selected; no lock-screen action records care in this scope.
- Cold-entry Back/Cancel goes to Home. Warm entry preserves the existing stack and unfinished inputs; duplicate delivery reuses an open identical check.
- Old/rescheduled reminders with an existing plant open its current detail with concise out-of-date feedback. Removed/malformed targets recover to Home. Always offer normal Back/Home recovery; avoid blocking error dialogs.
- Respect TalkBack, large text, system 12/24-hour preferences, dynamic themes, and 48dp targets. This feature adds no plant setup input, recurring reminder category, or repeated nudge.

## Occasional care — direction under discussion

The Soil health release groups Adding nutrients, Refresh potting mix, and Repotting as three distinct, potentially overlapping actions with on-demand checks and progressive disclosure, keeping watering primary (D41/D45 / PRD section 18). Do not expose a large mandatory setup form or default recurring care obligations. D49 / PRD 18.11 define the implemented version-1 questions and early exits; later content changes require review. Reading guidance or answering a question must not automatically record treatment or imply proven nutrient sufficiency.

Light & placement is also occasional care (D42). Initial guidance should help the user settle the plant; subsequent access is for voluntary review, without repeated relocation/confirmation prompts. Keep watering visually primary. The compact saved-state summary with expandable guidance is approved under D44 / PRD section 17. Preserve existing setup and acknowledgment semantics. Acknowledgment must not be presented as verified adequate light.


## Approved compact light presentation

Implemented and verified under D44 / PRD section 17: a collapsed Light & placement card on detail, showing the species requirement and a neutral report summary. Pending uses **Not recorded · Optional**; saved uses **You've placed it as suggested**; older versions use **Placement recorded for earlier advice**. Expand to see advice and the optional acknowledgment/correction control; preserve Material expansion semantics and wrapping at large text sizes. Setup continues to show full guidance. No Other care container or recurring light obligation is introduced. Earlier presentation-review gates are superseded for this scope.


## Soil health — design contract

Follow [PRD section 18](PRD.md#18-soil-health--release-requirements) and decisions D45–D47. Confirmed direction: a separate Soil health section, three distinct actions, overlap allowed, assessment-first help, and occasional use. D48–D49 / PRD 18–20 record the adopted UI/assessment/correction details; implementation and verification are recorded in STATUS.md.

- Hierarchy: a compact Soil health section on plant detail below watering/light; no new setup requirement, Home obligation, health score, or overdue badge.
- Disclose only the selected concern's relevant questions. Allow unknown and exit; show a brief reason/next step, including valid no-action or inspect-first outcomes. Advice must not look like a diagnosis or a completed action.
- Use Adding nutrients, Refresh potting mix, and Repotting consistently. Combined recording allows explicit multi-selection in one save; do not preselect related actions or make the user log one job several times. Record only what happened.
- Distinguish no history from no need; distinguish user-reported work from verified soil health. Keep product context optional at recording time and explain later uncertainty without forcing a detailed setup form.
- Preserve readable labels, native selection semantics, large-text wrapping, Back, cancellation, save/retry, and clear result states. Do not introduce universal fertilizer/mix recipes in UI copy.
- Drainage is included as an integrated optional condition check, not a fourth action. Aeration/compaction are related observations; pH/salts, environmental care, and pest diagnosis remain separate review/future topics. A simple drainage correction must not require an invented completed-care selection.


## Approved Soil health, timeline, and Back navigation

D48–D49 / PRD 18–20 supersede the earlier proposal-only gates for these features. Soil health remains compact and occasional; expand to choose one check or record work already done. Ask one question at a time, finish early when possible, and show concise no-action/uncertain/may-help guidance without a numeric health score. Drainage is integrated, not a fourth action. Keep three record actions unselected until the user chooses them; permit overlap in one job, with optional context disclosed only when relevant.

Open Care timeline on a separate page from the plant. Show the plant name, newest-first recorded events, real date precision, and wrapped labels/context. Combined jobs appear once. The current light acknowledgment is explicitly a saved confirmation snapshot; old changes must not appear invented. Soil rows open correction; other records remain read-only. Full history does not crowd plant details.

Use native back arrows for pages and normal nested routes. Dirty forms ask Discard changes? with Keep editing / Discard changes; dismiss keeps work. Do not pre-focus the destructive action. Native picker/dialog cancellation stays conventional. A pending save shows waiting feedback and cannot be discarded as though nothing committed. Success exits without another prompt. Preserve readable/announced states, touch targets, large-text wrapping, dark themes, and the parent navigation context.
