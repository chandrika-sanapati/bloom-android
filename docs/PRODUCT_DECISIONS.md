# Bloom product decisions and tradeoffs

**Status:** Watering, Light & placement, Profile/Preferences, reminder preferences/navigation, Soil health, Care timeline, guarded Back, authenticated Supabase/PlantNet integration, email/password and Google authentication, and local-wins cloud sync implemented; reviewed authorization and final decisions remain historical context.
**Last reviewed:** 17 November 2026
**Decision scope:** Product, UX, content safety, and roadmap choices

## Current implementation constraint

Bloom is currently under a **stabilization-only feature freeze**. The implemented product surface is the scope to harden; the roadmap and future decisions below are not implementation authorization. Do not add capabilities until the freeze is explicitly lifted.

This document preserves the product reasoning that led to Bloom's focused watering MVP. It is intentionally separate from the implementation plan: it records **why** a choice was made, not only what code should do.

The source material was the earlier Bloom product repository. SwiftUI, Xcode, iOS, and prototype-file details have been removed or translated to platform-neutral decisions. The current Android implementation remains the authority for shipped behavior. A decision marked **Designed** is not user-research evidence until it is validated.

## Current implementation decisions

- **Authentication:** Configured builds require Supabase authentication before Home. Users can register/sign in with email/password or sign in with Google when the Google Web Client ID is configured. Registration uses a one-time six-digit email OTP and immediately signs the user in after verification; later email/password sign-ins do not require OTP. Builds without Supabase configuration remain local-only.
- **Login UX:** Email/password is the primary login and registration path. Google is a secondary option when configured. The login page is context-independent and has no toolbar Back button; configured startup without a session renders the same page used for Profile sign-in.
- **Sign-out UX:** Sign-out requires confirmation, preserves local data, stops authenticated cloud writes, and returns to the root login gate.
- **Deletion UX:** Profile exposes two separate two-step privacy actions: **Delete all plant data** keeps the login account, while **Delete account and all data** removes the account. Server-side deletion succeeds before local data is cleared; failure preserves local data and offers retry.
- **Profile:** The Home account action is labeled **Profile** and uses a user icon. Profile contains account controls and a focused **Preferences** section for notifications and reminder time; cloud synchronization remains background behavior.
- **Cloud ownership:** The local garden is authoritative. Successful local persistence is never blocked by cloud sync. Every saved garden queues asynchronous sync; differing cloud payloads are overwritten using a revision guard, with bounded retry if another write races.
- **Identification boundary:** PlantNet is called only through the authenticated Supabase Edge Function. Results are possible matches, not diagnoses or automatic care guidance. Confirmed unsupported identities do not receive invented schedules.

## How to read this document

- **Implemented** — reflected in the current Android app.
- **Deferred** — an intentional product cut; do not add it casually.
- **Planned** — a future opportunity or validation task, not current behavior.
- **Designed** — a reasoned product choice that still needs user evidence.
- **Confirmed scope** — selected by the user in product discussion; this does not authorize implementation or establish usability evidence.
- **Draft for review** — a proposed detail to review in the local documents before implementation.

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

The Android MVP supports five reviewed catalog profiles, two explicit outcomes, local persistence, and optional notifications. Broader care domains were deferred for the watering MVP. The user then selected bounded Light & placement work; section 13 records the approved implemented suggestion/acknowledgment flow with watering dates unchanged.

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

Use bounded check-in ranges with deterministic starting values for the five reviewed catalog plants:

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
3. Restrict the watering catalog to reviewed profiles until more profiles are ready.

#### Decision

Only the five reviewed catalog plants are currently addable through Android's catalog. No generic interval is invented for an unsupported plant. If custom plants are reintroduced, they must show an explicit **Set up watering schedule** state rather than receiving false guidance.

#### Why

The five profiles have reviewed ranges and deterministic values. A generic fallback would appear more authoritative than the available evidence and would blur the content boundary.

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

**Status:** Historical environmental proposal; current light scope is the optional action acknowledgment in D28–D31

#### Options considered

1. Use device location and live weather.
2. Ask a detailed questionnaire about room, light, airflow, humidity, and temperature.
3. Capture one optional, user-observed location context without permissions or sensors.

#### Decision

The earlier proposal was to start with one optional field:

- Outdoor
- Indoor — direct light and airflow
- Indoor — indirect light and airflow

This three-option input and the later concern-picker draft are historical alternatives. D28–D31 define the current proposal: show the species suggestion and optionally persist that the user acted on it. Broader environmental inputs remain deferred; any schedule effect requires an agreed, disclosed rule.

#### Why

Location and weather add privacy, permission, network, and seasonal-model complexity. A detailed questionnaire asks users for precision they may not have. Three choices capture a useful mental model while avoiding claims that Bloom measured light, air, humidity, or temperature.

#### Content boundary

Environmental checks should distinguish light, airflow, humidity, drafts, and temperature. “Too much or too little air” is not precise enough. Advice should prefer gradual changes and should not present misting as a universal humidity solution.

### D11 — Nutrition must distinguish materials and avoid universal remedies

**Status:** Soil health is implemented for the approved on-demand scope; broader nutrition guidance remains deferred.

#### Product reasoning

Coco coir primarily changes medium structure and water-holding behavior; it is not a complete nutrient source. Compost or manure varies in maturity, concentration, salts, and indoor suitability. Fertilizer depends on product, dilution, timing, and plant conditions.

#### Decision

The implemented Soil health experience distinguishes **Adding nutrients** from **Refresh potting mix** and **Repotting**, supports explicitly recorded overlapping actions, and does not create a nutrition schedule or claim a measured health score. Any broader nutrition guidance must distinguish **changed growing medium** from **fed**, capture only useful product/material context, encourage following the product label, and avoid treating pale leaves alone as proof of nutrient deficiency.

#### Options rejected

- A universal fertilizer recommendation.
- Manure, compost, or coco coir as a cure for an unconfirmed infection.
- A recurring feed task without reviewed plant/product guidance.

#### Safe outcomes

Earlier exploration considered Fed, Changed growing medium, Checked — no amendment, and Not sure — inspect first. These are historical candidate outcomes, not the current event taxonomy. D45 / PRD section 18 define three distinct actions; advice and no-action/unknown assessment results must not imply treatment or symptom resolution.

### D12 — Repotting should be evidence-led, not routine

**Status:** Implemented inside the approved on-demand Soil health scope; recurring or chemistry-heavy guidance remains deferred.

#### Options considered

1. Add routine annual repotting reminders.
2. Recommend a larger pot when a symptom appears.
3. Offer a guided, user-initiated root-space inspection when evidence supports it.

#### Decision

Use a guided inspection based on evidence such as circling roots, roots at drainage holes, unusually rapid drying, severely degraded medium, instability, or a recent purchase transition. The current Soil health flow also includes drainage checks. “Bigger” is not automatically better because a larger pot can keep roots wet.

#### Safe outcomes

Earlier candidate outcomes included Repotted, Inspected — not needed, Changed medium only, and Check later. D45 now groups three distinct soil actions under Soil health with overlap possible. Repotting remains distinguishable from nutrient addition/mix refresh and separate from watering history, but one explicitly recorded event may contain multiple soil actions. No-action/inspection results are not completed treatment, and aftercare must not imply recovery.

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

**Status:** Light & placement implemented after document review and explicit user authorization; watering remains the only recurring care system

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

Future domains that record a care action must not be conflated with watering history or silently rewrite earlier care decisions. In the current light proposal, reading advice alone creates no state; acting on it can be acknowledged and stored per plant under D28–D31. This acknowledgment is not a watering record or a new recurring task.

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

- Add profiles only after a future scope decision and reviewed content is available; catalog expansion is frozen during stabilization.
- Add environmental context when users need help explaining watering outcomes and can provide useful observations.
- Add correction/Undo when accidental records appear in validation or data recovery becomes important.
- Add more history tools when the five-record Past view becomes demonstrably dense.
- Add sync or sharing only after local ownership, correction, and notification semantics are trustworthy.
- Add adaptive scheduling only when the product can explain the signal, preserve user control, and measure whether complexity reduces effort.

Do not turn a roadmap item into a requirement merely because it appears in this document.

## 13. Light & placement release decisions

Revised on 15 November 2026 after explicit user clarification. The current proposal is **D28–D31** and [PRD section 14](PRD.md#14-light--placement--release-requirements). D23–D26 are retained below only as superseded history; they must not guide implementation. D27's document-review workflow remains active. The user explicitly authorized implementation after confirming unchanged watering dates; see D31.

### Superseded proposal history — D23–D26

- **D23 — Learning and two placement concerns:** The earlier draft asked the user to select a dim spot or strong direct sun, then showed conditional advice. Superseded by D28: species advice appears immediately and the only input is whether the user acted on it.
- **D24 — Exclude uncertain placement:** The user's primary rationale was data insufficiency: uncertain light needs more input to produce tailored advice, increasing complexity and user investment. Preserve this reasoning. The revised flow removes light classification altogether; an unchecked action acknowledgment is not an uncertain/dim/bright assessment.
- **D25 — One optional concern with transient state:** The earlier draft deliberately did not store placement state. This is superseded by the explicit requirement to store an optional action acknowledgment per plant. Minimal inputs and no additional recurring reminders remain active principles.
- **D26 — Advice plus manual next-date editing:** The earlier draft made the existing manual date editor the watering connection. That is superseded as the new flow: the saved acknowledgment should be available to watering logic, and its possible future schedule effect is deferred by D31. The existing watering editor remains part of the app.

These alternatives and their tradeoffs remain documented so the reason for the scope change is visible, without retaining contradictory current requirements.

### D28 — Show one species suggestion and ask only whether the user acted

**Status:** User-supplied direction implemented and verified. The control is an optional checkbox labelled **I've placed it as suggested**.

#### Decision

During Add a plant, show a Light & placement section alongside the existing Last watered section. Give a short species-specific light requirement and position suggestion. The single optional input acknowledges that the user has acted on that suggestion. It starts unchecked and can be skipped by using the existing Add action.

Show the same suggestion and acknowledgment on plant detail near Watering. A user who skipped it during setup can act and confirm later. Remove the dim/bright picker, branch-based assessment, separate placement workflow, and required date-edit step from the proposal.

#### Rationale

Bloom already knows the selected species, so it can provide useful placement guidance without asking users to judge light conditions. Asking only whether they acted is easier to follow, requires less input, and supports care at the time they are ready. Repeating the suggestion on detail supports later action without repeated prompts or reminders.

#### Content boundary

Use reviewed light requirements, not a rigid rule that all plants either require direct sun or must avoid it. Rubber Plant was an interaction example; reviewed guidance favors indoor indirect light with protection from strong afternoon sun. Keep a concise placement sentence in the UI and maintain the sources in PRD 14.9.

### D29 — Persist the acknowledgment as plant state

**Status:** Implemented: optional timestamp/version state, immediate detail persistence, correction with the same checkbox, and backward-compatible loading.

#### Decision

Persist whether the user has acknowledged acting, so both entry points show the same saved state and future watering logic can use it. The implemented state is an optional acknowledgment timestamp plus the guidance version. Missing data is unacknowledged, including for existing plants; it never means inadequate light.

In setup, save the acknowledgment with the plant and its starting schedule on Add. On detail, persist immediately when the control is changed, with no separate Save page. The same control clears acknowledgment; watering state is unaffected in this release.

#### Rationale and boundaries

The earlier transient concern state could not support later acknowledgment or a future schedule decision. A small durable state now directly serves the requested behavior. The timestamp records acknowledgment, not an exact plant movement, and the version identifies the advice acted upon. It remains user-reported information rather than measured placement suitability, light exposure, or soil moisture.

Unchecked may mean skipped, not acted yet, or withdrawn. Reading the advice alone records nothing. Do not fabricate confirmations for old plants, add a room questionnaire, create watering history, or add recurring light reminders. Save failure preserves previous data and exposes retry feedback.

### D30 — Preserve potential future scheduling use as a separate decision

**Status:** Future adaptation deferred by D31; the earlier open policy is resolved for this release.

The user initially said acknowledgment could affect watering. Acknowledgment is now stored and available for future reviewed work, but no schedule adaptation is implemented in this release. A checkbox does not establish previous light, movement direction, or current soil moisture, so it does not support a precise date multiplier. Any future adaptation must specify its evidence, rule, disclosure, idempotence, and correction semantics and preserve explicit watering history. Sources in PRD 14.9 support the general relationship, not a numerical acknowledgment-to-date formula.

### D31 — Keep watering unchanged and begin implementation

**Status:** Explicitly confirmed and authorized by the user on 15 November 2026.

#### Decision and rationale

For this release, save the optional placement acknowledgment without changing watering dates, intervals, history, Last watered, or reminders. Handle adaptation separately later. This keeps the experience simple and avoids an unsupported scheduling rule or extra prompts. Existing plants remain unacknowledged until the user acts; already-suitable placement counts. The user accepted this first-release policy and explicitly instructed the team to document it and move into implementation.

#### Implementation consequences

- Use the same sourced species suggestion in setup and detail, and one optional unchecked acknowledgment.
- Save acknowledgment timestamp and guidance version per plant. Detail writes save immediately; the same control can clear it. Preserve older-version acknowledgments with inline context and no expiry or forced prompt.
- During setup save the selected state together with the plant and its normal starting schedule on Add; Cancel writes nothing.
- Do not synchronize reminders for placement-only writes. Repeated confirmations do not rewrite the timestamp or any watering state.
- Save failures preserve committed state and allow retry. No added recurring light reminders, assessment questionnaire, or light activity history.
- Verification must cover old JSON, persistence/relaunch, setup skip and confirmation, detail changes and correction, failed writes, unchanged watering, and narrow/large-text layouts.

D27's review-and-authorization gate has been satisfied for this scope. New scheduling behavior would require a new reviewed decision.

### D32 — Label both optional setup sections consistently

**Status:** Confirmed by the user and implemented on 15 November 2026.

Show **Optional** next to both **Last watered** and **Light & placement** in Add a plant, with matching secondary typography, spacing, and wrapping. Labelling only one optional section can make the other appear required. The user preferred showing the label in both rather than removing it from both. This is a presentation change; both inputs remain skippable and all persistence/watering behavior stays the same.

### D27 — Document, review, then explicitly authorize implementation


**Status:** Confirmed workflow, explicitly requested by the user.

#### Decision

Discuss requirements first. Document material decisions, alternatives, rationale, tradeoffs, and open questions in the local repository. Review the PRD, implementation plan, and related documents with the user. Begin app implementation only after the user confirms the documents and explicitly authorizes that implementation.

#### Documentation ownership

- `PRD.md`: scope, behavior contract, acceptance criteria, sources, and unresolved product questions.
- `PRODUCT_DECISIONS.md`: selected alternatives, why they were selected, scope cuts, and revisit triggers.
- `IMPLEMENTATION_PLAN.md`: gated sequence, architecture direction, validation work, and documentation upkeep.
- `DESIGN_GUIDELINES.md`: language, input budget, hierarchy, navigation, and reminder restraint.
- `STATUS.md`: separate current implementation from requirements/planning; record actual verification evidence only.
- `README.md`: entry point to the current release and proposed scope.

Keep these aligned as decisions evolve. Do not leave a material product decision only in chat or implement an unresolved choice silently. Product discussion, document editing, and an implementation plan are not implementation approval.

## 14. Reminder preferences and navigation decisions

Recorded on 15 November 2026. Feature selection and protection rules were reviewed before implementation was authorized; the adopted contract is in [PRD section 15](PRD.md#15-reminder-preferences-and-notification-navigation--requirements). D27's document-first gate is complete; D39 records explicit implementation authorization.

### D33 — Put one global reminder time in Profile → Preferences

**Status:** Selected, reviewed, and implemented under D39.

Offer one Reminder time row beside the existing Watering notifications switch, native time picker, existing 09:00 fallback, and local 12/24-hour display. Save on final picker confirmation with inline scope explanation. No new plant-setup fields or per-plant recurring preferences.

The alternative of separate per-plant preferences would add setup and precedence rules. One global time makes the setting easier to understand and maintain. It remains editable while notifications are off/denied; saving it must not enable notifications or request permission. In-app check times follow the chosen policy; delivery remains optional.

### D34 — Update eligible automatic future checks, preserving user choices

**Status:** Confirmed by the user: update existing future checks too, with custom timings and today's existing checks preserved. Migration/lifecycle details in D38 were adopted under D39.

Apply a changed global clock only to explicitly automatic checks on later local calendar days, and to newly generated automatic checks. Preserve their calendar dates. Custom date/time edits, today's existing checks, and overdue checks retain their exact saved timestamps and reminder trigger times.

The earlier draft would have overwritten custom future times and updated today's checks when the new time was still ahead. The user explicitly rejected custom-time overwriting and asked to keep today's checks as they are. Preserve this as a replaced proposal rather than implementing the old broad rule. User intent takes precedence over a bulk normalization shortcut.

Commit preference and eligible timestamp changes together. Preserve intervals, history, Last watered, and placement state; do not generate care history or catch-up notifications. Choosing an unchanged preference remains a no-op. The legacy schedule constraint and proposed way to record time provenance are in D38.

### D35 — Use the preferred clock consistently for automatic next checks

**Status:** Adopted under D39 and implemented; preserves the pre-feature rationale below.

Before this change, the app used the preference only for the first check and inherited the completion clock afterward. The implemented rule calculates the next local calendar day from the actual completion day plus the existing profile/follow-up days, then applying the preferred hour/minute. Preserve actual recordedAt and Last watered. This makes the visible task time and notification time agree, avoiding two unexplained clocks.

Use device-local wall-clock semantics. Adopted DST handling is the first valid time after a gap and the first occurrence during a repeated time, with only one reminder. Reconcile timezone changes on startup/resume; do not promise continuous travel adaptation while the app stays closed. Exact per-check edits remain protected across global preference changes and synchronization. The adopted one-off lifecycle ends that override only when the user explicitly edits or completes the check; a new automatic successor follows the preference (D38).

### D36 — Open a specific current check, and handle stale taps safely

**Status:** Direct navigation and the identity/fallback contract adopted under D39 and implemented.

A valid notification opens the identified plant's Check watering screen from closed, background, or foreground states. Cold entry has Home beneath it; warm entry preserves existing navigation/unfinished work. Repeated delivery of the same event must not open duplicate screens or replay on a normal launch.

Identify the specific scheduled check/revision as well as the plant, then resolve against current local data. A plant-only link could send a reminder for a completed task into its newly scheduled future task, so new payloads must carry enough identity to reject that mismatch. Adopted stale/legacy fallback is the existing plant detail with current schedule and brief feedback; removed/invalid targets recover to Home. Payloads are validated data, not arbitrary route commands.

A tap never records watering, preselects an outcome, changes a schedule, or enables notifications. Use both running-app response callbacks and notification-launch details, coordinated after garden/navigation readiness. No mandatory new confirmation prompt.

### D37 — Keep reminders restrained and complete the document review first

**Status:** Reviewed, authorized under D39, and implemented.

Retain the existing optional switch, future-only one-shot reminders, and one pending watering reminder per plant. Add no daily digest, repeated overdue nudge, snooze, direct watering action, or new light reminder. Use inline scope/timing feedback rather than additional forms. Android delivery remains best effort/inexact; do not promise a guaranteed minute or request special exact-alarm access for this feature.

Preference persistence and notification acceptance are different outcomes: a saved preference must survive a denied permission or OS scheduling failure, while a failed garden write must leave preference/tasks unchanged. Device testing must use the isolated test package and verify real tap entry without risking the normal app/data.

The initial instruction authorized documents only. That review was completed, and D39 records the subsequent explicit authorization for implementation. Undo, backup/restore, nutrition, repotting, and sunlight-driven adaptation are separate future scope. Technical references and the baseline/code differences are captured in PRD 15.

### D38 — Preserve custom times and today's checks; record provenance

**Status:** Protection requirements explicitly confirmed by the user on 15 November 2026. Provenance representation, conservative migration, and one-off lifecycle were adopted under D39 and are implemented.

#### Confirmed decision and rationale

Changing the global Reminder time must not affect custom timings set by the user. Keep all today's existing checks at their saved times as well. A preference should not undo a deliberate next-check choice or rearrange the user's current day. Existing future-check updates therefore apply only to eligible automatic checks after today.

#### Adopted implementation direction and tradeoffs

The pre-feature model stored nextCheckAt, createdAt, and updatedAt without manual/automatic provenance. Timestamp equality with the old preference cannot prove intent. Add explicit per-check provenance (preference/custom/legacy) so automatic and custom choices can be distinguished without new user inputs.

Mark new automatic first/completed checks as preference-based. Mark explicit Edit next check saves as custom even when the chosen time equals the preference. Protect a custom check across global changes, app startup/resume, and notification sync. Interpret the existing editor as a one-off override: after explicit completion, create a new automatic check at the preferred time. Recurring custom per-plant times would be separate scope.

For old data without provenance, the adopted conservative migration is to preserve all those saved check times as legacy/unknown until the user edits or completes each check. This means the first global change after upgrade may not change older saved checks. It avoids overwriting genuine custom times, and adds no migration questionnaire or timestamp/history heuristic. This tradeoff was reviewed and adopted under D39; it is not a claim that all old checks were manually customized.

Persist provenance backward-compatibly and test it with scheduling, cancellation/resync, repeated preference changes, relaunch, and future successor generation. Custom/today protection is confirmed; migration and one-off lifecycle review is recorded as completed in PRD 15.9.


### D39 — Authorize reminder implementation with protected timings

**Status:** Explicitly authorized by the user on 15 November 2026.

Implement the reviewed reminder-time preference and notification navigation. Preserve custom, today, overdue, and unclassified legacy check times; use explicit per-check time provenance going forward. Adopt the conservative legacy migration and one-off custom lifecycle from PRD 15.4. Keep the separate test installation and back up normal emulator data before device verification. This authorization covers implementation and verification, not a new commit or push. Update all related docs with final behavior and evidence.

### D40 — Preserve committed state and verify platform entry honestly

**Status:** Implemented and verified within the limits recorded in STATUS.md.

Serialize complete store transitions to preserve concurrent changes from stacked screens. Commit preference/provenance/timestamp changes before publishing them; an optional notification failure leaves the saved choice intact and surfaces retry feedback. Incremental synchronization leaves unchanged pending requests alone and resolves notifications against due instant plus schedule revision, not a plant ID alone.

The native test activity/channel is compiled only into the isolated integration build. Foreground/background tests dispatch posted notifications' actual PendingIntents; cold-launch verification uses a separate UI Automator shell process to tap the notification drawer after confirming the fixture process has ended. This distinction matters: a receiver sending its own PendingIntent after process death is blocked by Android 16 background-activity rules and does not model a SystemUI user tap. No production exemption or permission was added to work around that test limitation.

Timezone refresh converts pending requests using the current device zone while preserving saved instants, including custom and legacy checks. It does not silently rewrite the existing garden after travel. New automatic checks use the current preferred local clock. Keep long-idle/OEM delivery and manual TalkBack review separate from deterministic timing/routing evidence.

### D41 — Assess occasional care needs on demand; disclose progressively

**Status:** User-confirmed product direction on 15 November 2026; detailed requirements remain under discussion. No implementation authorization for these domains.

Use **Adding nutrients** as customer-facing wording rather than Feeding. The user wants a way to check whether adding nutrients or pot/soil work is needed before taking action, rather than simply creating recurring schedules. Watering remains the primary, most frequent care journey. Develop the occasional-care requirements step by step, starting with Adding nutrients.

Use progressive disclosure to keep these infrequent features from overwhelming everyday watering. Exact placement, labels, question branches, assessment rules, outcomes, persistence, and any later reminders are unresolved proposals. Earlier guidance-plus-history suggestions alone do not meet the user's assessment-first requirement. D11/D12 remain horticultural boundaries; do not claim nutrient sufficiency or diagnose a problem from an acknowledgment or a single symptom. Unknown information must not force treatment or a lengthy mandatory questionnaire. Document and review detailed flows before implementation under D27.

### D42 — Light placement is occasional care, not a recurring task

**Status:** User-confirmed product direction on 15 November 2026; future hierarchy changes remain proposals.

Once a user has placed a plant in suitable light, Bloom should not imply it needs frequent relocation or repeated confirmation. Watering is the frequent recurring journey. Light & placement belongs to initial setup and occasional, user-initiated review; Adding nutrients and Pot & soil are also occasional care. Add no recurring light check, acknowledgment expiry, automatic reset, or relocation nudge.

Preserve the implemented optional setup/detail suggestion and saved acknowledgment. That acknowledgment remains a user-reported action, not verified light sufficiency. A compact summary with expandable advice or grouping under Other care is a future layout proposal requiring review, not authorization to move or hide the existing controls. Revisit guidance when the user chooses to review changed placement/conditions; this creates no automatic watering change. Read alongside D41 and PRD sections 14/16.

### D43 — Finish the occasional-light presentation before adding another care domain

**Status:** Recommended sequencing in response to the user's sunlight-first proposal on 15 November 2026; detailed presentation still needs review. No new app implementation authorization inferred from the sequencing discussion.

The existing sunlight feature already provides optional setup/detail guidance, persistent acknowledgment, and correction. The remaining proposed work is the progressive-disclosure presentation: keep watering primary; offer a compact Light & placement summary on detail, clear access to full guidance, and voluntary review/correction. Unacknowledged placement must remain easy to find without repeated prompts. Preserve setup, saved state, watering dates, and the absence of recurring light tasks.

Recommend reviewing and finishing this small presentation refinement before refining Adding nutrients, then Pot & soil. It establishes the occasional-care interaction pattern without introducing nutrient assessment at the same time. Agree pending/acknowledged summaries and expand/review behavior in the docs before implementation; do not reopen measured-light assessment or automatic scheduling adaptation.


### D44 — Authorize compact, expandable light guidance on plant detail

**Status:** Explicitly authorized, implemented, and verified on 15 November 2026 after agreeing the sunlight-first refinement. Supersedes the presentation-review gate in D42/D43 for this scope only.

Implement the reviewed compact Light & placement section on plant detail, keeping setup fully visible and watering primary. New detail pages start collapsed in both pending and acknowledged states. Show the species requirement plus a neutral saved-state summary, with Material expansion revealing existing advice/checkbox. Use Not recorded · Optional, You've placed it as suggested, or Placement recorded for earlier advice; none implies measured adequacy.

Expansion is temporary UI state and writes nothing. Preserve optional setup, persisted acknowledgment/time/version, immediate save and correction, failure/retry, and unchanged watering/notification behavior. No new reminders, automatic resets, assessment, or Other care navigation container. This is a small presentation refinement, not new sunlight logic. Define exact behavior in PRD section 17 and record verification in STATUS.md. The user reiterated that every implemented product feature must be captured in the PRD and related repo docs. The user subsequently requested committing and pushing the completed, verified work upstream.


## 15. Soil health requirements decisions

### D45 — One Soil health section, three distinct actions, overlap permitted

**Status:** Explicit user direction on 15 November 2026; formalized in PRD section 18. Documentation only, not app implementation authorization.

Group **Adding nutrients**, **Refresh potting mix**, and **Repotting** within a separate Soil health section. The user accepted the distinction between nutrient replenishment, renewing growing mix, and removing/replanting for pot/root-space needs. Refreshing mix does not necessarily require another pot; repotting does not always require a larger pot. Actions can overlap in one real-world job and must remain distinguishable.

Keep watering primary and these features occasional, assessment-first, and progressively disclosed (D41). Replaces the earlier two-entry Adding nutrients / Pot & soil framing; Pot & soil remains useful explanatory language, not a fourth action. Earlier D11/D12 candidate outcomes are historical, not a competing record schema. The reason for distinguishing actions is to avoid confusing fertilizer, structural mix ingredients, and root-space work, while avoiding duplicate effort when one job includes several actions.

### D46 — Draft assessment and combined-record behavior for review

**Status:** Proposed requirements, not yet user-approved interaction or content rules.

PRD 18 proposes on-demand focused checks, explicit no-action/unknown outcomes, and optional recording afterward. One event can contain one or more user-selected actions so a combined job need not be logged repeatedly. No action is automatically inferred from another, and nutrient-containing mix must not silently become a fertilizer application record. Missing historical facts stay unknown. Read-only checks and abandoned guidance create no treatment record.

The proposed first release keeps watering/light/reminders unchanged, uses local atomic persistence, adds no automatic soil-care schedules or numeric health scores, and asks only useful information. Exact branches, combined-record UX/correction, minimum fields, and the unchanged-watering boundary require review before implementation. The user's request is to create the formal documents; it does not authorize coding or a new push.

### D47 — Drainage belongs with Soil health checks — recommendation pending review

**Status:** Initially recommended, then explicitly confirmed by the user on 15 November 2026: include drainage in the checks while retaining three actions. D49 records implementation authorization.

Recommend integrating drainage as a cross-cutting optional check about pot, mix, and water context, rather than a fourth care action or another recurring task. A simple drainage correction may require none of the three actions; do not force repotting/mix refresh or invent an event to make it fit the taxonomy. A future drainage-adjustment action needs its own product decision.

Aeration/compaction are closely related observations for consideration. Salt buildup/pH are later Soil health topics needing suitable evidence; temperature/humidity/airflow fit environmental care, and pest/disease triage remains separate. These are possible extensions, not an automatically approved backlog or release scope. PRD 18.5/18.10 retain the scope question and reviewed references.


### D48 — Authorize a dedicated plant timeline and guarded Back navigation

**Status:** Explicitly requested, implemented, and verified on 15 November 2026.

Open Care timeline as a nested page from plant details, rather than expanding detail into a long feed. Combine existing watering outcomes and future/current soil-care records in one read projection per plant; a combined soil job stays one entry. Show the existing light acknowledgment only as an honestly labelled current confirmation snapshot, not a fabricated movement/history log. Historical light changes are unavailable under current storage.

The user requested back arrows instead of Close, then explicitly required confirmation before leaving a partially filled form. Apply one shared discard guard to toolbar/system Back on editable setup/check/soil/assessment pages. Keep editing preserves state; Discard changes leaves without writing. Clean pages return immediately; committed saves exit without prompting. Do not turn a save in flight into a false promise to discard it. Preserve dirty forms if an unavailable reminder would otherwise pop the stack. PRD sections 19–20 hold acceptance criteria.

### D49 — Authorize Soil health after timeline/navigation; include drainage

**Status:** Implemented and verified after the user requested Soil health following timeline/navigation and explicitly selected integrated drainage on 15 November 2026. Supersedes documentation-only gates in D45/D46 and the pending drainage scope in D47 for this release.

Adopt the documented compact Soil health section, focused advisory checks, three explicit action types with one combined record, optional actual-date/context recording, and correction/removal of soil events through the timeline. Keep watering, placement, and reminders unchanged; add no automatic schedules. Version-1 rules are conservative observations for the existing five foliage profiles, not a diagnosis or product recommendation engine; PRD 18.11 specifies early exits and unknown handling.

Implementation defaults resolve the previous recording questions: date-only actual care date plus UTC recording timestamp; optional product/mix/notes fields; edit and confirmed removal for soil records only. No universal feed dose/interval, health score, fourth drainage action, pH/salt treatment, environmental assessment, or pest diagnosis is included. Future content can expand after separate review. The prior upstream push covered reminder/light work. After this release was completed and verified, the user explicitly requested committing and pushing it upstream.
