# Bloom Android interface guidelines

These guidelines apply to the Flutter Android app and describe the shared design system as of the 17 November 2026 UX overhaul (D50–D62, [PRD section 21](PRD.md#21-ux-overhaul--current-screen-contract-17-november-2026)). They preserve the product principles: calm hierarchy, explicit outcomes, progressive disclosure, and trustworthy history. New screens should reuse the pieces below rather than restyling locally.

## Theme and typography

- Use Flutter Material 3 components and Android interaction conventions.
- Color comes from a fixed Bloom forest green seed (`#2E6B3A`, `DynamicSchemeVariant.fidelity`) for both light and dark schemes, following the system theme mode. Android wallpaper dynamic color is not used.
- Shared component styling lives in `bloomTheme` in `lib/main.dart`. Do not override these per screen:
  - Cards: flat (elevation 0), `surfaceContainerLow`, 16dp corner radius, no margin.
  - Text fields: filled (`surfaceContainerHighest`), 14dp radius, no border; a 2dp primary border on focus. Add a leading icon where it helps recognition (sign-in fields).
  - Filled and outlined buttons: 48dp minimum height. Pinned primary flow buttons may be 52dp.
  - App bar titles are left-aligned. Snackbars float.
  - Overscroll stretch is disabled app-wide (clamping scroll).
- Use the theme's `TextTheme` roles; do not introduce arbitrary text sizes. Typical roles: `headlineMedium` for a plant name or welcome title, `headlineSmall` for a key value (next check), `titleMedium` for section headers, `bodyLarge`/`bodyMedium` for content, `bodySmall`/`labelLarge` for metadata.
- Keep common and scientific plant names together, with the scientific name italicized and `onSurfaceVariant`.
- Allow font scaling to reflow content. Never truncate the primary action, outcome labels, dates, or error guidance.

## Color and meaning

- Primary green is for the one primary action, selected states, and the Home **Today** card (filled primary with `onPrimary` text).
- Tint a status surface only when it needs attention: the plant status card uses `primaryContainer` when the check is due or overdue, otherwise `surfaceContainerHigh`.
- Red (`error`) is reserved for overdue status text and destructive actions. Do not use it for emphasis.
- Neutral `onSurfaceVariant` is for metadata, hints, and empty states.
- Never communicate a state by color alone. Pair color with text (**Overdue · 2 days**), an icon, or control state.

## Shared components (`lib/ui/widgets.dart`)

| Component | Use |
| --- | --- |
| `SectionHeader(title, action:, onAction:)` | Every section title, in sentence case (**My plants · 3**, **Care guide**, **What did you do?**). Optional trailing text action such as **See all** or **Select**. Marked as a heading for TalkBack. |
| `MessageBanner(message, isError:)` | Inline status or error: tinted container (`errorContainer` or `secondaryContainer`), icon, live region. Use for form and flow errors instead of dialogs. |
| `BottomAction(child:)` | The single primary action pinned above the system bar on form and flow screens, full width with 20dp side insets. |
| `PlantImage(store:, plant:, height:)` | The plant's chosen growth photo (including the identification photo), falling back to the catalog image, then the drawn placeholder — never a photo of a different species. Use wherever a plant is pictured. |
| `HistoryRow(plant:, entry:)` | One activity entry: round icon badge (highlighted for watering, soil care, photos), or a photo thumbnail for growth photos; title, optional plant name/soil line, and a short date. |
| `relativeCheckLabel(when, now)` | Next-check text: **Today**, **Tomorrow**, **In N days · Dec 1**, **Overdue · N days**. |
| `relativeAgo(when, now)` | Past text: **today**, **yesterday**, **N days ago**. |
| `EmptyActivityCard`, `pickNextCheck` | Empty-history card; shared next-check date/time picker that rejects past times. |

Other shared pieces: `DiscardChangesGuard` (dirty-form Back), `LightPlacementSection`/`LightPlacementPanel`/`LightPlacementScene` (setup and plant-page light guidance), and `growth_photos.dart` (add, view, gallery, thumbnails).

## Actions and navigation

- One primary filled action per screen. On forms and flows, pin it at the bottom with `BottomAction`: **Save** (Check & water, Soil care), **Add plant** (setup), **Sign in / Create account / Verify**, **Identify** / **Add <name>**. Disable it until the required input exists, and show **Saving…** / **Adding…** while in flight.
- Secondary actions are outlined or tonal buttons, or text buttons (**Edit next check**, **Change**, **See all**).
- Destructive actions live in a ⋮ menu (plant **Delete**) or as red text (**Delete account**), and always confirm with a dialog that states what will be removed. The confirm button is red text, not the default focus.
- Prefer a bottom sheet for a small set of entry choices (**Search by name** / **Identify from a photo**).
- Use standard Android back arrows and `Navigator`. Dirty forms use `DiscardChangesGuard` (**Discard changes?** — **Keep editing** / **Discard changes**).
- Toolbar icons over photos (plant-page Back and ⋮) get a translucent round background so they stay visible on any image.
- Do not preselect **Watered**.

## Layout

- 20dp page inset and an 8dp spacing rhythm; 24–28dp between sections.
- Plant photos use 16dp rounded corners (12dp for small thumbnails). Home uses a two-column photo grid.
- Keep cards quiet; do not turn every row into a competing card. Group related rows in one card separated by inset dividers (Profile).
- Optional sections say so in the header: **Last watered · optional**, **Light & placement · optional**.
- Reveal occasional content progressively: the Care guide light row is collapsed by default; History shows five entries with **See all**.

## Dates and status

- Show relative dates instead of timestamps in lists and status: next checks with `relativeCheckLabel`, last watering with `relativeAgo` (**Last watered 9 days ago**). Month headers group the full history.
- Use full dates only where precision matters (history rows, pickers, confirmations).
- Use **Overdue** without blame. An overdue check remains visible until completed or explicitly rescheduled.

## Care language

- The task is **Check & water**: check first, water only if needed. Home rows use **Check**. Never say “Water now.”
- Exactly two outcomes: **Watered** and **Checked — not watered**, as choice cards. Ask **How did the soil feel?** (Dry / Damp / Not sure) only after **Checked — not watered**.
- **Soil care** records what the user did (**Select everything you did.**). Do not present advice, results, or a health score.
- Show only the plant profile's own care text (watering cue, light requirement, placement). Do not add new advice in UI copy.
- Photo identification shows likelihood words (**Very likely / Possible / Less likely**), never percentages, and says **no care guide yet** when Bloom has no profile.

## Accessibility

- Target at least 48dp for interactive controls.
- Give icon buttons tooltips (Add plant, Profile, More options, Delete photo) and images meaningful semantics (the room scene names the best spot).
- Announce inline status with `MessageBanner`'s live region; expose selected, disabled, and error states.
- Test at large font sizes, narrow widths, and dark theme. Rows wrap or stack rather than overflow.
- Respect system animation settings; motion is limited to short size transitions.
- Do not rely on long-press alone: Home multi-select is also reachable with **Select**.

## Empty, error, and permission states

- Empty Home: image, **Add your first plant**, one line of context, and **Add plant**.
- Nothing due: the Today card says **Nothing to check today**.
- Empty history: **No care recorded yet** — **Checks, care and photos will appear here.**
- Missing plant targets show **Plant unavailable** with **Go to Home**.
- Persistence failures leave the garden unchanged and show inline, retryable feedback.
- Notification denial explains that checks stay in Bloom; when Android notifications are blocked, Profile shows **Open Android settings**. Do not prompt repeatedly.

## Product boundaries

Do not add custom plant intervals, diagnosis, environmental inference, live weather, cloud merge/sharing, photo upload, or additional recurring care domains. Preserve the implemented local-wins cloud sync as a separate authenticated service. Multiple-plants-of-one-type handling and water-frequency presentation are out of scope for now.

## Light & placement

Follow [PRD sections 14 and 17](PRD.md#14-light--placement--release-requirements) and D28–D31, D55.

- Setup: requirement, room-scene illustration, placement text, and the optional **I've placed it as suggested** checkbox. Adding remains possible without it.
- Plant page: a collapsed Care guide row (requirement, check mark when confirmed). Expanded: scene, placement text, and **Is it in a spot like this?** — **Yes, it is** / **Not yet**; confirmed shows **In a good spot · Confirmed <date>** with **Change**. When the guidance version changes, ask again only inside the row.
- Confirmation means the user reports the plant is in such a spot; never present it as measured light. It never changes watering dates or reminders. No light reminders, expiry, or nudges.

## Reminders, Profile, and sign-in

Follow [PRD section 15](PRD.md#15-reminder-preferences-and-notification-navigation--requirements) and D33–D40, D58–D59.

- Profile: avatar header (email initial, email, **N plants · Synced / Syncing… / Sync pending**), **Reminders** (Notifications switch, Reminder time with native picker), **Account** (Sign out, red **Delete account** with subtitle). Show the scope line under Reminders: **Applies to future checks. Custom check times stay as they are.**
- Changing the reminder time never requests permission or enables notifications.
- Notification title **Check & water**; body names the plant and asks for a soil check. A tap opens Check & water with no outcome selected.
- Sign-in: welcome image header, **Continue with Google** first when configured, **or use email**, Sign in / Create account segmented switch, filled fields with icons, password strength bar while registering, inline `MessageBanner`, primary button pinned. No toolbar Back. Email confirmation: six digit boxes, auto-verify on the sixth digit, **Resend code** after a 45-second countdown.

## Soil care, history, and growth photos

- Soil care: action checkboxes, **When**, optional **Details** revealed per selected action, **Save** pinned. Editing adds **Remove record** with confirmation.
- History: plant page shows five `HistoryRow`s; **<plant> history** groups by month, marks tappable rows with a chevron (soil care → edit, latest watering → delete with Undo, photo → viewer).
- Growth photos: device-only. **Add photo** shows a small dot badge after 30 days without a photo — a cue, not a task. Viewer offers delete and **Use as plant image**. Make clear deletion removes the photo from this device.
