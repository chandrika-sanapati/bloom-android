# Case-study source material

An inventory of artifacts and facts for a future case study. This is raw material, not a write-up. Structure follows what NN/g recommends showing ([UX design portfolios](https://www.nngroup.com/articles/ux-design-portfolios/)): problem, role, process and iterations, explored-but-dropped ideas, constraints, outcomes, learnings.

## Problem and starting point

- Starting state: a working, local-first Android app (commit `bf5c48b`) under a stabilization-only feature freeze.
- Input: a 17-item UX/UI feedback list from the product owner (17 Nov 2026). Its themes:
  - plant page "looks like a mess", with poor information hierarchy
  - redundant AI-style explanatory text
  - duplicate delete actions
  - missing feedback after a check
  - no way to see a plant grow
  - inconsistent flows
- The full original list and its triage live in project history. The decision records are in [`PRODUCT_DECISIONS.md`](../PRODUCT_DECISIONS.md) section 16 (D50–D62).

## Role and team

- *To fill in:* your role, who gave feedback, who decided, who built. The implementation and design proposals were produced with an AI coding assistant (Claude Code). The owner reviewed and approved each step.

## Process artifacts

| File | What it shows |
|---|---|
| `images/01-home-before.jpg` | Home before the redesign: plant cards, Upcoming/Past toggle, floating + button |
| `images/02-plant-page-iteration-1.jpg` | First plant-page pass (status card, kebab menu) |
| `images/03-plant-page-stacked-cards.jpg` | The "mess": six equally weighted, tinted cards (Growth, Light, Timeline, Soil health) |
| `images/04-light-scene-first-version.jpg` | First room-scene light illustration and the Yes / Not yet question |
| `images/05-plant-page-final.jpg` | Final plant page: one status card, one primary action, quiet care guide |
| `images/06-home-final.jpg` | Final Home: Today card, photo grid, Add plant tile |
| `images/07-check-and-water.jpg` | Check & water: choice cards and a pinned Save button |
| `images/08-search-popular.jpg` | Add a plant: search plus Popular plants |
| `images/09-sign-in.jpg` | Redesigned sign-in with Google first |
| `images/10-catalog-photo-review.jpg` | Contact sheet used to review 42 licensed catalog photos |
| `images/11-drawn-placeholder.png` | Species-neutral placeholder drawn to replace a misleading plant photo |

Not saved as files, so recreate them if needed:
- the mockups shown during the work (plant page, light section, Home and Profile, sign-in and photo ID)
- the prioritised batch plan (A: quick fixes, B: plant page, C: new features)

## Iterations and turning points

- **Plant page, version 1:** reorganised the existing cards. The owner judged it still messy, which led to a design-first rethink (mockup → approval → build).
- **Light section, three versions:**
  - a strip diagram squeezed by its expand arrow
  - a room-scene illustration with a plain question
  - collapsed by default, at the owner's request
- **Naming:** "Check soil" and "Log care" became **Check & water** and **Soil care**. The owner proposed "Watering & check soil" or "Care". The chosen name keeps "check first, water only if needed" in the word order.
- **Theme:** from wallpaper-driven dynamic color (it came out blue on the test device) to a fixed dark forest green.
- **Placeholder imagery:** from a real snake-plant photo used for every plant, to a drawn, species-neutral plant.

## Explored, then dropped or deferred

- **Soil-health diagnosis questionnaire** (nutrients, mix, roots, drainage): removed because the owner didn't want Bloom to diagnose. Bloom now only records care the user did.
- **"Trending" plants:** relabelled **Popular plants**, because there's no usage data to back the claim.
- **Masked email on Profile:** proposed, then rejected in favour of the full address.
- **Dropped or parked:** multiple plants of the same type, water-frequency presentation, and an unclear "Babbu" item.
- **Generated illustrations for all 50 profiles:** declined in favour of licensed real photos.

## Constraints

- Local-first data. Growth photos never leave the device (privacy).
- No invented plant advice. All guidance text comes from reviewed profiles.
- Image licensing: Wikimedia Commons free licenses only, with credits in the app.
- Android/Material 3 conventions, accessibility (TalkBack, large text), and existing test coverage.

## Outcome evidence (verifiable)

- 16 commits from `bf5c48b` to `5ab7f1f` in one day (17 Nov 2026).
- `lib/` changed by about 3.6k lines added and 2.1k removed across 25 files.
- 14 of 17 feedback items shipped; 3 dropped or parked by the owner.
- 114 unit/widget tests pass. Three on-device integration suites and four native notification-tap cases pass.
- Data-safety fix found during the work: an unreadable garden file is now backed up instead of being silently overwritten.
- No user research or usage metrics exist yet. Impact claims would need, for example, a usability test or analytics after release.

## Possible learnings to reflect on

- Mockups before code made disagreement cheap: the plant page and light section changed several times without rework.
- Naming carries product principles. "Check & water" encodes the core rule.
- Consistency issues were best fixed once, centrally (theme and shared widgets), rather than screen by screen.
