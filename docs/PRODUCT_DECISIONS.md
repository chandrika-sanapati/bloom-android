# Bloom product decisions and tradeoffs

**Status:** Recovered from the original Bloom product work and aligned to the Flutter Android app
**Last reviewed:** 15 November 2026
**Decision scope:** Product, UX, content safety, and roadmap choices

This document preserves the product reasoning that led to Bloom's focused watering MVP. It is intentionally separate from the implementation plan: it records **why** a choice was made, not only what code should do.

The source material was the earlier Bloom product repository. SwiftUI, Xcode, iOS, and prototype-file details have been removed or translated to platform-neutral decisions. The current Android implementation remains the authority for shipped behavior. A decision marked **Designed** is not user-research evidence until it is validated.

## How to read this document

- **Implemented** — reflected in the current Android app.
- **Deferred** — an intentional product cut; do not add it casually.
- **Planned** — a future opportunity or validation task, not current behavior.
- **Designed** — a reasoned product choice that still needs user evidence.

## 1. North-star product tradeoff: narrow the problem

### Question

Should Bloom launch as a broad plant-health platform or solve one recurring care problem completely?

### Options considered

1. Build watering, nutrition, repotting, environmental care, symptoms, pests, and pruning together.
2. Build a general plant-care assistant with many loosely connected reminders.
3. Start with one explainable watering loop and earn additional care domains later.

### Decision — Implemented / Designed

Start with one complete loop:

> **Schedule a check → inspect the plant → record what happened → schedule the next useful check.**

The Android MVP supports four reviewed catalog profiles, two explicit outcomes, local persistence, and optional notifications. Broader care domains are deferred until this loop is reliable and validated.

### Why

The broad approach increases setup work, notification volume, activity-feed density, content-maintenance risk, and diagnosis risk before Bloom has proved its basic value. A narrow loop gives the product a clear hypothesis and makes failures diagnosable.

### Scope consequence

Every new feature must answer:

> **Does this make the next watering check clearer, faster, or more trustworthy?**

If not, it belongs behind progressive disclosure, in a later release, or outside Bloom.

## 2. Core interaction principles

### Reduce memory, not agency

Bloom should remember dates and history, but the user should inspect the plant and decide what happened. A schedule is guidance, not an automatic diagnosis.

### Scheduled does not mean watered

A due or overdue task means **check this plant**. It must never imply “pour water without looking.” This is why the primary task is named **Check watering** rather than **Water now**.

### Record reality, including non-watering

Checking a plant and intentionally not watering is meaningful care. Bloom must not update Last watered unless the user explicitly chooses **Watered**.

### Late completion changes the future, not the past

When a task is completed late, the original scheduled time remains part of the record. The next check starts from the actual recorded event so the user does not receive an immediate duplicate task.

### One primary action

The home experience should prioritize the next care action. Settings, history, schedule editing, and future capabilities remain secondary.

### Explicit changes over silent automation

Bloom should not silently change a user's schedule because of hidden context, seasonality, weather, or an inferred diagnosis. Future suggestions must explain their input and require explicit acceptance.

## 3. Watering profile decisions

### D1 — Bounded range with a deterministic starting value

**Status:** Implemented / Designed

#### Question

Should Bloom use one fixed interval, ask the user to choose an interval, or show a range while selecting a predictable starting value?

#### Options considered

1. One fixed interval per plant type.
2. Ask the user to choose within a horticultural range during setup.
3. Show a bounded range and automatically use a deterministic starting value.

#### Decision

Use bounded check-in ranges with deterministic starting values for the four reviewed catalog plants:

| Plant | Range | Starting value |
| --- | ---: | ---: |
| Snake Plant | 14–30 days | 21 days |
| Monstera | 7–14 days | 10 days |
| Rubber Plant | 7–21 days | 14 days |
| Pothos | 7–21 days | 14 days |

These are check-in intervals, not universal watering instructions.

#### Why

A fixed interval suggests false precision. Asking a new user to choose transfers a horticultural decision to setup and adds friction. A deterministic value makes behavior predictable and testable, while the range communicates that household conditions vary.

#### Scope consequence

Profile content is versioned. Changing a range or starting value must not silently rewrite a saved schedule, recorded history, or an already selected next check.

### D2 — Hybrid first-task timing

**Status:** Implemented / Designed

#### Question

Should the first check be due immediately, calculated from known history, or delayed for the full profile interval?

#### Options considered

1. Due today for every new plant.
2. Calculate from a supplied last-watered date.
3. Wait the full starting interval after setup.

#### Decision

Use the user's valid last-watered date when available. When it is unknown, create a baseline check today at the default reminder time.

#### Why

Known history should be useful, but a new user should not wait weeks before Bloom provides value. A same-day baseline is safer than inventing a date and more useful than silently waiting.

#### Scope consequence

Last-watered input is optional. Setup must stay short. Future dates are invalid. A past date may create an immediately due or overdue task and should remain visible rather than being hidden.

### D3 — Condition-based follow-up after not watering

**Status:** Partially implemented; editable window deferred

#### Question

Should every non-watering check use the normal interval, always use a short interval, or branch on observed condition?

#### Options considered

1. Use the normal profile interval for every non-watering check.
2. Always use a short follow-up because the plant was not watered.
3. Use a shorter follow-up only when the soil is dry or the plant needs attention.

#### Decision

Use a three-day follow-up for a dry or concerning check. Use the normal plant interval when soil is damp or unknown. The current Android implementation uses the three-day default; the older 2–5 day editing window remains a future enhancement.

#### Why

A universal interval is too slow when a dry or concerning plant needs another look. An always-short interval creates unnecessary reminders for a healthy plant that was correctly left unwatered. Condition-based timing keeps the next action proportional to evidence without treating non-watering as failure.

#### Safety boundary

The shorter follow-up means **check again**, not “water now” and not “the plant will recover.” Unknown information must not be treated as evidence of urgency.

## 4. Schedule-control decisions

### D4 — Edit the next date, not the interval

**Status:** Implemented / Designed

#### Options considered

1. Add per-plant interval editing.
2. Add pause/resume with reasons and resume behavior.
3. Add calendar-triggered seasonal changes.
4. Allow explicit next-check date editing only.

#### Decision

The current release lets the user edit only the future next-check date and time. It does not persist pause, seasonal, or per-plant interval states.

#### Why

Interval editing affects every future task and requires profile-versus-user rules, validation, and recalculation. Pause/resume adds cancellation, restoration, backlog, and notification semantics. Seasonal logic introduces unexplained calendar-driven changes. Explicit date editing solves travel, dormancy, and temporary timing needs with fewer concepts.

#### Scope consequence

An untouched task remains Overdue. Editing the next date changes future timing only, creates no care record, and does not imply watering. Notifications follow the saved future date.

### D5 — Keep environmental modifiers out of schedule calculation

**Status:** Deferred / Designed

#### Question

Should pot size, light, drainage, room, growing medium, indoor/outdoor placement, or other context modify schedules now?

#### Options considered

1. Apply context to the schedule in the MVP.
2. Collect context and silently recalculate from it.
3. Keep context out of schedule calculation until a transparent experiment is ready.

#### Decision

Use plant type and explicit next-date editing only for the watering baseline. Do not silently adjust intervals from environmental details.

#### Why

Several variables make setup, behavior, testing, and explanation harder. Required context adds friction; hidden context makes schedule changes untrustworthy.

#### Future rule

Any future modifier must identify the signal used, explain the suggestion, offer accept/dismiss, and preserve the current schedule unless the user explicitly changes it. Begin with one or two high-value signals rather than an adaptive model.

## 5. Plant catalog decision

### D6 — Do not invent schedules for unsupported plants

**Status:** Implemented for the current catalog; future custom-plant route deferred

#### Options considered

1. Allow any plant name and use a generic fallback interval.
2. Allow any plant name and show no automatic schedule.
3. Restrict the watering catalog to four reviewed profiles until more profiles are ready.

#### Decision

Only the four reviewed catalog plants are currently addable through Android's catalog. No generic interval is invented for an unsupported plant. If custom plants are reintroduced, they must show an explicit **Set up watering schedule** state rather than receiving false guidance.

#### Why

The four profiles have reviewed ranges and deterministic values. A generic fallback would appear more authoritative than the available evidence and would blur the content boundary.

## 6. Outcome, history, and correction decisions

### D7 — Remove Check later from the watering task

**Status:** Implemented / Designed

#### Options considered

1. Keep Watered, Checked — not watered, and Check later.
2. Persist a deferred activity and reschedule it.
3. Keep only two completed outcomes; untouched tasks remain open and can become Overdue.

#### Decision

The watering task has exactly two outcomes: **Watered** and **Checked — not watered**. There is no deferred watering record. A temporary timing change uses explicit next-check editing.

#### Why

Deferral adds another history type, date semantics, notification transitions, and ambiguity between not checking, checking without watering, and intentionally changing a schedule. Two outcomes keep the core loop legible.

### D8 — Keep both meaningful outcomes in Past

**Status:** Implemented / Designed

#### Options considered

1. Show Watered and Checked — not watered in the existing Past feed.
2. Show only actual watering events.
3. Create a separate watering-history area.

#### Decision

Keep both completed outcomes in Activity → Past. Keep the default view compact, with the most recent five records on Home. Untouched overdue tasks and schedule configuration changes are not history records.

#### Why

Showing only Watered loses the distinction between a plant that was checked and intentionally left dry and a plant that was never checked. A separate history destination adds navigation and mental overhead. Progressive disclosure keeps the distinction without creating another system.

#### Future trigger

If the feed becomes dense, try grouping or filtering before creating a separate history destination.

### D9 — Delete the most recent mistaken record rather than edit history in place

**Status:** Designed; Android implementation deferred

#### Options considered

1. Edit a past record in place.
2. Add a correction record while preserving the original.
3. Delete the most recent mistaken watering record and recalculate affected state.

#### Decision

When correction is implemented, limit it to the most recent watering record, require confirmation, explain schedule impact, preserve unrelated history, and offer immediate Undo where safe.

#### Why

Editing is less transparent. Correction records preserve an audit trail but introduce a second record concept. Most-recent-only deletion is the smallest understandable correction model and avoids reconstructing ambiguous later schedule decisions.

#### Safety boundary

Deleting a mistaken record is not the same as recording Checked — not watered. The first removes an accidental entry; the second records a real care decision. Revisit this decision if sync, sharing, compliance, or immutable analytics are introduced.

## 7. Future care-domain decisions

These decisions preserve the original product thinking without implying that the Android app currently supports these features.

### D10 — Environmental context should be descriptive, optional, and local

**Status:** Planned / Deferred

#### Options considered

1. Use device location and live weather.
2. Ask a detailed questionnaire about room, light, airflow, humidity, and temperature.
3. Capture one optional, user-observed location context without permissions or sensors.

#### Decision

If environmental context is introduced, start with one optional field:

- Outdoor
- Indoor — direct light and airflow
- Indoor — indirect light and airflow

It should be descriptive, skippable, and used for on-demand checks—not silent watering recalculation or a new set of recurring reminders.

#### Why

Location and weather add privacy, permission, network, and seasonal-model complexity. A detailed questionnaire asks users for precision they may not have. Three choices capture a useful mental model while avoiding claims that Bloom measured light, air, humidity, or temperature.

#### Content boundary

Environmental checks should distinguish light, airflow, humidity, drafts, and temperature. “Too much or too little air” is not precise enough. Advice should prefer gradual changes and should not present misting as a universal humidity solution.

### D11 — Nutrition must distinguish materials and avoid universal remedies

**Status:** Planned / Deferred

#### Product reasoning

Coco coir primarily changes medium structure and water-holding behavior; it is not a complete nutrient source. Compost or manure varies in maturity, concentration, salts, and indoor suitability. Fertilizer depends on product, dilution, timing, and plant conditions.

#### Decision

A future nutrition experience must distinguish **changed growing medium** from **fed**, capture only useful product/material context, encourage following the product label, and avoid treating pale leaves alone as proof of nutrient deficiency.

#### Options rejected

- A universal fertilizer recommendation.
- Manure, compost, or coco coir as a cure for an unconfirmed infection.
- A recurring feed task without reviewed plant/product guidance.

#### Safe outcomes

Potential outcomes are **Fed**, **Changed growing medium**, **Checked — no amendment**, and **Not sure — inspect first**. A follow-up must not imply that the symptom is resolved.

### D12 — Repotting should be evidence-led, not routine

**Status:** Planned / Deferred

#### Options considered

1. Add routine annual repotting reminders.
2. Recommend a larger pot when a symptom appears.
3. Offer a guided, user-initiated root-space inspection when evidence supports it.

#### Decision

Use a guided inspection based on evidence such as circling roots, roots at drainage holes, unusually rapid drying, severely degraded medium, instability, or a recent purchase transition. “Bigger” is not automatically better because a larger pot can keep roots wet.

#### Safe outcomes

Potential outcomes are **Repotted**, **Inspected — not needed**, **Changed medium only**, and **Check later**. Repotting history must remain separate from watering and nutrition history, and aftercare must not imply guaranteed recovery.

### D13 — Symptoms require suggestive, conservative triage

**Status:** Planned / Deferred

#### Options considered

1. Map each symptom directly to a remedy.
2. Use a large cause-first diagnostic questionnaire.
3. Record the observation, check urgency, show a short set of possible contributors, and offer one conservative next action.

#### Decision

Use progressive disclosure:

1. Record what the user noticed in plain language, with optional note/photo.
2. Check for urgency.
3. Show a small set of possible contributors, not an exhaustive diagnosis list.
4. Offer one safe action: inspect, stabilize, isolate, compare later, or seek help.
5. Reveal more detail only when requested.

Use **could**, **may**, and **possible**. Do not say “your plant has a nutrient deficiency” from a symptom or photo alone.

#### Why

Direct symptom-to-remedy routes are too confident. Large questionnaires create friction without removing uncertainty. Progressive disclosure keeps the first decision simple while allowing explanation when useful.

### D14 — Use three urgency levels with one interruptive route

**Status:** Planned / Deferred

#### Options considered

1. Treat every symptom the same.
2. Create many detailed severity states.
3. Use three broad levels.

#### Decision

Use:

- **Monitor** — mild, isolated, or stable change.
- **Check soon** — several affected leaves, visible insects/webbing, slowly spreading symptoms, or environmental stress.
- **Get plant-care help** — rapid decline/collapse, soft or dark stem/base, severe/widespread damage, major root concern, heavy pests, worsening after a reasonable first step, or a case outside reviewed guidance.

Only **Get plant-care help** interrupts the normal flow.

#### Why

A single flow can delay help for serious decline. Many levels make ordinary plant stress feel like an emergency. Three broad levels communicate priority without diagnosis or alarmism.

### D15 — Specialist escalation is a safety boundary, not a failure state

**Status:** Planned / Deferred

When evidence is insufficient, a symptom is outside reviewed guidance, or the plant is worsening, Bloom should stop short of treatment and recommend a plant specialist, garden centre, or appropriate local service. Photos and notes are evidence, not automatic diagnosis. Chemical treatments, homemade mixtures, and dosage instructions require specific reviewed guidance.

## 8. Roadmap sequencing tradeoffs

### D16 — Add environmental checks before high-risk treatment domains

**Status:** Planned

#### Options considered

1. Add all major care domains together.
2. Add a collection of recurring schedules for light, humidity, temperature, nutrition, and repotting.
3. Add lightweight, on-demand environmental checks first.

#### Decision

Keep watering as the only recurring care system initially. If the watering loop validates, add on-demand environmental observations before nutrition, repotting, or symptom treatment.

#### Why

Multiple recurring schedules turn Bloom into another chore. Environmental checks can provide useful context without immediately creating new obligations or higher-risk treatment claims.

### D17 — Future capabilities must reuse the same care loop

**Status:** Planned

Each later domain should reuse:

> **Notice a signal → inspect context → choose a conservative next step → record what happened → schedule a useful follow-up.**

New domains should be separate records with explicit outcomes. They must not be conflated with watering history or silently rewrite earlier care decisions.

## 9. Progressive disclosure decisions

### D18 — Explain by doing, not by onboarding

**Status:** Implemented / Designed

- First launch opens directly to Home.
- Empty Home names the next action: add a plant.
- The one-time Add plant hint introduces only the primary control.
- Notifications remain secondary until the user has a plant.
- Optional details should not block adding a plant or reaching the first check.

### D19 — Keep secondary controls out of the primary task

**Status:** Implemented / Designed

Schedule editing, notification preferences, profile ranges, and future capabilities should remain available but secondary. Do not add a control simply because the model can support it, and do not preserve a visible feature merely because it existed in the old prototype.

## 10. Decision pattern

Across the product decisions, Bloom consistently prefers:

1. One clear primary task over simultaneous obligations.
2. Explicit user choices over silent schedule changes.
3. Inspection over unsupported diagnosis or treatment.
4. Records that distinguish what the user actually did.
5. Progressive disclosure over exposing every option at once.
6. Small, deterministic rules before adaptive personalization.
7. Local, reversible actions before cloud, sharing, or audit complexity.
8. A calm overdue state over guilt or notification spam.

## 11. Case-study and evidence decisions

### D20 — Separate Designed, Observed, and Planned

**Status:** Designed

Product decisions must not be presented as user-research findings without evidence:

- **Observed** — supported by user behavior, tests, or recorded feedback.
- **Designed** — selected from principles, constraints, domain guidance, or expert judgment.
- **Planned** — a future hypothesis that has not been validated.

The current Android project has automated domain evidence but does not yet have a structured usability study. Case-study writing must say so plainly.

### D21 — Measure the MVP at the level it can support

**Status:** Planned

Useful validation measures include:

- whether users understand that due means check, not automatically water;
- whether users distinguish Watered from Checked — not watered;
- whether users resolve overdue tasks without guessing;
- whether the next check feels trustworthy after late completion;
- whether empty, failure, permission, and disabled states are understandable;
- whether users feel less need to remember dates.

Do not claim improved plant health, prevented plant loss, increased retention, or business impact until evidence exists. The local-only app has no analytics service; use manual QA, usability sessions, and opt-in diagnostic evidence instead.

### D22 — Preserve rejected directions as learning

The case study should show why Bloom did not choose:

- generic recurring reminders;
- one fixed interval for every plant;
- user-selected intervals during setup;
- Check later/deferred activity;
- per-plant pause/resume;
- seasonal automatic changes;
- silent environmental modifiers;
- automatic schedules for unsupported plants;
- environmental setup in the watering release;
- new diagnosis or specialist UI before review;
- a separate watering history or new filters before density requires them;
- arbitrary historical deletion and schedule reconstruction.

The tradeoff for each cut is lower friction, fewer state transitions, less notification complexity, safer content boundaries, or more reliable history.

## 12. Decision revisit triggers

Revisit these decisions only when there is evidence or a changed constraint:

- Add profiles when users are blocked by the four-plant limit and reviewed content is available.
- Add environmental context when users need help explaining watering outcomes and can provide useful observations.
- Add correction/Undo when accidental records appear in validation or data recovery becomes important.
- Add more history tools when the five-record Past view becomes demonstrably dense.
- Add sync or sharing only after local ownership, correction, and notification semantics are trustworthy.
- Add adaptive scheduling only when the product can explain the signal, preserve user control, and measure whether complexity reduces effort.

Do not turn a roadmap item into a requirement merely because it appears in this document.
