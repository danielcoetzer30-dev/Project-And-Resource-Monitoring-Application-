# Project & Resource Monitoring Application

Read this before changing anything. It is the orientation for the whole
codebase; the three documents in `docs/` go deeper on design, schema and
workflow.

---

## What this is

A Flutter app giving small South African software teams a live view of project
health, so failure signals surface early rather than at the post-mortem.

It implements a university research project, and that matters more than usual:
several things in here that look like design choices are commitments made in a
research proposal with an ethics section. Those are marked **Non-negotiable**
below. Breaking one is not a refactor, it is a breach.

**Users:** developers and team leads at SME software shops, often under sixteen
people, frequently with developers acting as their own project managers.

**Why it exists:** Jira, Trello and GitHub Projects are reactive, need constant
manual updating, are priced for enterprises, and have no concept of a team
losing four hours to load-shedding.

---

## Non-negotiable constraints

### 1. No individual-level data. Ever.

The research protocol commits to a system "deliberately built without any
individual identity", aggregating to squad level, with management barred from
granular developer analytics.

In practice:

- `Squad` has a `headcount`, never a member list. Do not add one.
- `RawActivityEvent` is the only type carrying an author. It lives in memory
  inside `lib/services/ingestion/` and is never serialised, cached or stored.
- `Anonymiser` converts it to squad totals before anything reaches Firestore.
- Squads with fewer than two contributors are **dropped entirely**, because a
  one-person "squad total" is that person's data with a different label.
- `test/unit/anonymiser_test.dart` asserts this. If it fails, stop.

If a change would let a person's activity be identified, it is wrong regardless
of how useful it is.

### 2. Load-shedding hours are reported, never deducted

Outage hours are removed from *available* time before any ratio is taken, so
the question is always "what did they do with the time they had". A team is
never scored down for a national power failure. `IdleTimeCalculator` is where
this lives, and two tests in `health_score_engine_test.dart` protect it.

### 3. Monitoring data is read-only to clients

`projects`, `squads` and `signals` are written by ingestion, never by the app.
Enforced in `firestore.rules`. This is what stops a team editing its own health
scores, and it is half the anti-gaming argument.

### 4. No manual status entry

The app's whole differentiator is passive capture. There is deliberately no UI
for typing in progress, and `ProjectRepository` has no write method. The one
screen that accepts input is *Connect a source*, which is one-off setup.

### 5. The assistant sends squad-level data only

`lib/services/assistant/snapshot_brief.dart` is the only thing in the app that
sends project data to a third party. It can only emit squad-level data because
that is all the domain model holds — there is no per-person field to include by
accident. `test/unit/snapshot_brief_test.dart` asserts it.

If you ever add individual data to a model, that test fails, and it should.

### 6. Status is never colour alone

Every health state renders as colour **and** icon **and** word, via
`StatusPill`. Colour-blind users, greyscale and glare all have to work.

---

## Architecture

```
UI (screens, widgets)
      ↓  reads only
Riverpod providers  ──  lib/state/providers.dart
      ↓
Repository interfaces  ──  lib/data/*_repository.dart
      ↓
Implementations: Firestore (live) or Mock (seeded, offline)
```

**The repository interface is the seam that makes everything else possible.**
Screens depend on `ProjectRepository`, never on Firestore. That is why the app
can run with no backend, why tests need no Firebase, and why swapping
implementations is one line in `providers.dart`.

Keep it that way. A screen importing `cloud_firestore` is a bug.

### Layers

| Folder | Holds | Depends on |
|---|---|---|
| `lib/core/` | Constants, typed errors, formatting | Nothing |
| `lib/models/` | Plain data classes | Nothing (no Firestore imports) |
| `lib/data/` | Repository interfaces + implementations, DTOs | Models |
| `lib/services/health_scoring/` | The scoring engine and calculators | Models |
| `lib/services/ingestion/` | Passive capture, the anonymiser | Models |
| `lib/services/outage/`, `sync/` | Load-shedding, cache, connectivity | Data |
| `lib/state/` | Riverpod providers and notifiers | Everything above |
| `lib/screens/`, `lib/widgets/` | UI | Interfaces only |

---

## The scoring engine

`lib/services/health_scoring/` is the research contribution. Everything else is
plumbing around it.

Five weighted indicators compose into one 0–100 score:

| Indicator | Default weight | Measures |
|---|---|---|
| Budget burn | 0.25 | Spend rate against schedule elapsed |
| Task velocity | 0.25 | Throughput against the squad's *own* baseline |
| Issue complexity ratio | 0.20 | Whether remaining work is getting heavier |
| Commit volume | 0.15 | Commit activity against baseline |
| Idle-time ratio | 0.15 | Use of workable time, outages excluded |

**It is multi-dimensional on purpose.** A single linear indicator is trivially
gamed — the proposal raises this when discussing the Hawthorne effect. Commit
volume is weighted lowest precisely because it is easiest to inflate, and a
test proves thousands of fake commits still leave a failing project failing.

Each calculator compares a squad against **its own history**, never an industry
benchmark. Context-blind benchmarks are part of why existing tools fail small
teams here.

Score thresholds live in `HealthState.fromScore`: ≥75 on track, ≥55 watch,
≥35 at risk, below that critical. They are provisional and will move once
interview data says where the real boundaries sit.

---

## Current state

**Working:** the app builds for Android, iOS and web; reads live Firestore data
scoped to the signed-in user's organisation; Firebase Auth with email and
password; security rules open per collection and verified denying anonymous
access; offline cache so it stays usable during an outage.

**Not working yet:** nothing is *producing* data. The Firestore documents were
written once by `tool/seed_firestore.js`, which is why scores no longer move.
The ingestion layer is fully written and tested but has nowhere server-side to
run — that is the next significant decision, and it needs either Cloud
Functions (requires the Blaze plan) or a scheduled GitHub Action.

**Firebase project:** `project-health-monitor-436da`. Demo data lives under
`organisations/demo-org`. Register with organisation code `demo-org` or you
will sign in successfully to an empty dashboard.

---

## Conventions

**Never hardcode a colour, font or size.** Everything resolves through
`Tokens` (`lib/theme/tokens.dart`) and `AppType` (`lib/theme/typography.dart`).
Full system in `docs/DESIGN.md`.

**Naming:** `snake_case.dart`, one primary class per file, named after it.
Suffixes carry meaning — `_repository`, `_service`, `_calculator`, `_notifier`,
`_dto`, `_screen`.

**Riverpod without code generation.** No `build_runner`, no `.g.dart`.
`Provider` for dependencies, `StreamProvider` for streams, `NotifierProvider`
for mutable state. Screens are `ConsumerWidget` and read with `ref.watch`.
Never construct a repository inside a widget.

**Doc comments say why, not what.** `squad.dart` and `health_seam.dart` are the
register to match: they explain the constraint or the decision, not the
obvious.

**Copy:** active voice, plain words, from the user's side of the screen. It is
a *signal*, not an alert. A *squad*, never a person. Errors say what went wrong
and how to fix it. An empty screen is an invitation to act.

---

## Before you commit

```bash
flutter analyze
flutter test
```

Both must be clean. There are 37 tests and they all pass; a failure is
something you introduced.

Format with `dart format lib/ test/` — the project is formatted and an
unformatted file shows up as noise in every later diff.

---

## Where to look

| File | Why |
|---|---|
| `docs/DESIGN.md` | Palette, type, components, copy voice |
| `docs/SCHEMA.md` | Every Firestore collection and field |
| `docs/CONTRIBUTING.md` | Workstreams, naming, definition of done |
| `lib/state/providers.dart` | How everything is wired; swap mock for live here |
| `lib/data/project_repository.dart` | The central interface |
| `lib/services/health_scoring/health_score_engine.dart` | The research contribution |
| `lib/services/ingestion/anonymiser.dart` | The ethics commitment in code |
| `lib/services/assistant/snapshot_brief.dart` | Everything the assistant is told |
| `lib/widgets/health_seam.dart` | The signature component |

---

## If you are unsure

Ask rather than guess, particularly about anything touching individual data,
scoring arithmetic or security rules. The constraints above came from a
research protocol with an ethics review, and a reasonable-looking change can
breach one without being obviously wrong.
