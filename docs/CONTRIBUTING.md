# How we build this together

Five people, one codebase, no stepping on each other. This document covers who
owns what, the order things get built, and the conventions that keep sixty new
files looking like one person wrote them.

Read alongside [`DESIGN.md`](DESIGN.md) for the visual system, and the build map
for the full file list.

---

## 1. Workstreams

The codebase splits into five areas along interface boundaries. Each person owns
one. **The boundary is the point:** you can build your whole area against the
agreed interfaces without waiting for anyone else's files to exist.

Counts are uneven on purpose. Scoring and Ingestion are small by file count
because they're the hardest; Interface is large because widgets are quick. If one
area falls behind, widgets are the easiest work to hand to whoever finishes first.

### A — Data & Auth  *(foundation — starts first)*

Everything that defines what the data looks like and how it's stored.

**Owns:** `lib/models/`, `lib/data/`, `lib/data/dto/`, `lib/core/errors/`,
`lib/core/constants/`, `firestore.rules`

| File | What |
|---|---|
| `models/app_user.dart` | Signed-in user and role |
| `models/organisation.dart` | The team an account belongs to; scopes every query |
| `models/outage_window.dart` | A scheduled load-shedding slot |
| `models/ingestion_source.dart` | A connected repo or tracker |
| `models/scoring_weights.dart` | Per-organisation factor weights |
| `models/sync_state.dart` | Last sync, pending writes, connection state |
| `data/auth_repository.dart` | Interface: sign in/out, current user stream |
| `data/firebase_auth_repository.dart` | Firebase implementation |
| `data/firestore_project_repository.dart` | Real implementation of `ProjectRepository` |
| `data/outage_repository.dart` | Load-shedding schedule source |
| `data/settings_repository.dart` | Persists weights and thresholds |
| `data/dto/project_dto.dart` | Firestore ↔ `Project` |
| `data/dto/squad_dto.dart` | Firestore ↔ `Squad` |
| `data/dto/signal_dto.dart` | Firestore ↔ `Signal` |
| `core/errors/failure.dart` | Typed failures: network, auth, permission, parse |
| `core/errors/exceptions.dart` | Data-layer exceptions, converted at the repository boundary |
| `core/constants/app_constants.dart` | Collection names, default thresholds, polling intervals |

**Depends on:** nothing. **Blocks:** everyone — which is why this area does Stage 0.

**First task:** the Stage 0 interfaces PR (see §3).

### B — Scoring  *(the research contribution)*

The algorithm. Everything else is plumbing around this folder.

**Owns:** `lib/services/health_scoring/`, `lib/services/signal_engine.dart`,
their tests

| File | What |
|---|---|
| `health_scoring/factor_calculator.dart` | Interface each calculator implements |
| `health_scoring/health_score_engine.dart` | Composes weighted factors into a score and breakdown |
| `health_scoring/factor_calculators/velocity_calculator.dart` | Throughput vs the squad's own baseline |
| `health_scoring/factor_calculators/budget_burn_calculator.dart` | Spend vs schedule elapsed |
| `health_scoring/factor_calculators/complexity_ratio_calculator.dart` | Is remaining work getting heavier? |
| `health_scoring/factor_calculators/idle_time_calculator.dart` | Activity gaps, **with outage hours removed first** |
| `signal_engine.dart` | Threshold crossings → signals, each with written reasoning |
| `test/unit/health_score_engine_test.dart` | Known inputs → expected scores |
| `test/unit/factor_calculators_test.dart` | One case per calculator, including the outage path |

**Depends on:** models only. Can start the day Stage 0 lands, using hand-written
input values — real ingested data isn't needed to develop the maths.

**First task:** `factor_calculator.dart` (the interface), then the engine test
*before* the engine. Write down what score a known input should produce, then
make it produce that.

### C — Ingestion  *(passive capture)*

Reading Git and tracker metadata without anyone typing anything in.

**Owns:** `lib/services/ingestion/`, the anonymiser test

| File | What |
|---|---|
| `ingestion/anonymiser.dart` | **Build first.** Strips individual identity and aggregates to squad level before anything is stored |
| `ingestion/ingestion_service.dart` | Orchestrates adapters, writes through the repository |
| `ingestion/git_metadata_adapter.dart` | Commits and PRs from GitHub/GitLab — metadata only, never code |
| `ingestion/issue_tracker_adapter.dart` | Task state from ClickUp or Jira |
| `ingestion/ingestion_scheduler.dart` | Background polling that backs off when offline |
| `test/unit/anonymiser_test.dart` | Asserts no individual identifier survives ingestion |

**Depends on:** models, external APIs.

**First task:** the anonymiser and its test. Not the adapters. The research
proposal (Section D) commits to a system built without individual identity — if
per-developer data is ever written to Firestore, even in development, that
commitment is broken in a way no later deletion undoes. The filter exists before
any data flows.

### D — Infrastructure & Sync  *(the part no competitor has)*

Separating "the team is slipping" from "the grid went down", and staying useful
while offline.

**Owns:** `lib/services/outage/`, `lib/services/sync/`, `lib/data/local_cache.dart`,
and the three state widgets

| File | What |
|---|---|
| `outage/outage_service.dart` | Adjusts capacity for outages; keeps lost hours out of delivery scores |
| `outage/outage_api_client.dart` | Fetches load-shedding schedules, with manual fallback |
| `sync/connectivity_service.dart` | Watches connection state |
| `sync/sync_service.dart` | Reconciles cache against remote when connectivity returns |
| `sync/notification_service.dart` | Push alerts on At risk / Critical transitions |
| `data/local_cache.dart` | On-device store so the app opens with real data during an outage |
| `widgets/offline_banner.dart` | States plainly how stale the data on screen is |
| `widgets/empty_state.dart` | An empty screen is an invitation to act |
| `widgets/error_state.dart` | Says what went wrong and how to fix it |

**Depends on:** the data layer.

**First task:** `connectivity_service.dart` and `offline_banner.dart` — small,
self-contained, and immediately visible in the app.

### E — Interface  *(screens, navigation, state)*

**Owns:** `lib/screens/`, `lib/widgets/` (except D's three), `lib/routing/`,
`lib/state/`, `lib/core/utils/`, `lib/theme/`, widget and integration tests

| File | What |
|---|---|
| `state/auth_notifier.dart` | Sign-in state and session lifecycle |
| `state/dashboard_notifier.dart` | Filtering and sort order over the snapshot |
| `state/settings_notifier.dart` | Scoring weights and ingestion sources |
| `routing/app_router.dart` | Named routes, auth guards, deep links |
| `routing/routes.dart` | Route name constants |
| `screens/auth/sign_in_screen.dart` | Sign in and register |
| `screens/auth/auth_gate.dart` | Shell or sign-in, based on session |
| `screens/onboarding/connect_source_screen.dart` | Link a repo or tracker |
| `screens/settings/settings_screen.dart` | Account, organisation, notifications |
| `screens/settings/scoring_weights_screen.dart` | Tune factor weights |
| `screens/settings/ingestion_sources_screen.dart` | Manage connected sources |
| `widgets/capacity_bar.dart` | Extract from `squads_screen.dart` |
| `widgets/metric_tile.dart` | Label, value, optional delta |
| `widgets/sparkline.dart` | Compact trend line |
| `core/utils/date_format.dart` | Currently duplicated in the mock repository |
| `core/utils/duration_format.dart` | Currently duplicated across two screens |
| `test/widget/health_seam_test.dart` | Rendering across segment counts, plus semantics |
| `test/widget/dashboard_test.dart` | Worst-first ordering and state counts |
| `test/integration/app_flow_test.dart` | Sign in → dashboard → project → signal |

**Depends on:** repository interfaces only — never on implementations.

**First task:** extract `capacity_bar.dart` and `metric_tile.dart` from the
existing screens. Zero dependencies, teaches the widget conventions, and
unblocks nothing else — so it's safe to do while Stage 0 is in review.

### Assigning people

|  | Workstream | Suits someone who… | Person |
|---|---|---|---|
| A | Data & Auth | Set up Firebase, or wants to understand the schema | |
| B | Scoring | Is comfortable with the maths and wants to own the research contribution | |
| C | Ingestion | Is happy working against external APIs and reading their docs | |
| D | Infrastructure | Likes systems problems — caching, connectivity, background work | |
| E | Interface | Has an eye for the design system and wants to build screens | |

Fill in the last column as a group. Whoever takes **A** should be the most
available person over the first week, because everyone is waiting on Stage 0.

---

## 2. Build order

The build map lists six integration stages. Two things about them:

**Creation is parallel. Integration is sequential.** Once Stage 0 lands,
everyone starts their own area at once. The stages say when each area's work
gets *wired in*, not when it gets *written*.

**Each area has something to do from day one.** Nobody waits.

| Stage | What lands | Who's integrating | Everyone else is… |
|---|---|---|---|
| **0** | Interfaces, models, schema, providers skeleton | A drafts, all review | Reading the PR |
| **1** | Rules opened per collection, auth, user model | A | Building against Stage 0 |
| **2** | Anonymiser, then adapters | C | — |
| **3** | Scoring engine and calculators | B | — |
| **4** | Firestore repository; mock swapped out in `providers.dart` | A + E | Screens change not at all |
| **5** | Cache, sync, outage service | D | — |
| **6** | Settings, notifications, onboarding | E + D | Testing end to end |

### Stage 0 — the one meeting that matters

Do this in one sitting, together, before anyone writes a feature. **A** drafts,
opens one pull request, and everyone reviews it. Nothing else starts until it
merges.

The PR contains:

1. **The six new models**, as plain Dart classes with `const` constructors — no
   Firestore imports.
2. **The three new repository interfaces** — `AuthRepository`, `OutageRepository`,
   `SettingsRepository` — as `abstract interface class`, mirroring
   `ProjectRepository`. Method signatures only.
3. **A Firestore schema document** — `docs/SCHEMA.md` — listing every collection,
   its path, its fields, and which workstream writes to it. Ten minutes of
   agreement here saves days of DTO rework.
4. **The Riverpod provider skeleton** — `state/providers.dart` gains a provider per
   repository interface, each returning a mock for now.

Everyone else's job during Stage 0: read that PR properly, and ask about anything
you'd need to call that isn't there. **Once it merges, the interfaces are frozen.**
Changing one afterwards means a PR that touches every consumer, reviewed by every
owner.

Also during Stage 0, the repo owner turns on branch protection for `main`:
Settings → Branches → Add rule → require a pull request, require one approval.
Without this the whole workflow below is voluntary.

---

## 3. Working in git

One branch per task. One pull request per branch. One reviewer from a *different*
workstream.

### The loop

```bash
git checkout main
git pull
git checkout -b feature/scoring-velocity-calculator
```

Work. Commit often — small commits are easier to review and to revert.

```bash
git add lib/services/health_scoring/factor_calculators/velocity_calculator.dart
git commit -m "Add velocity calculator against squad baseline"
```

Before you open the PR:

```bash
flutter analyze
flutter test
```

Both must be clean. Then:

```bash
git push -u origin feature/scoring-velocity-calculator
```

Open the PR on GitHub. Fill in the template below. Request one reviewer from
another workstream. When approved, **squash and merge**, then delete the branch.

```bash
git checkout main
git pull
git branch -d feature/scoring-velocity-calculator
```

### Branch names

`<type>/<area>-<what>`, lowercase, hyphens.

| Type | For |
|---|---|
| `feature/` | New files or capability |
| `fix/` | Correcting something that's merged |
| `docs/` | Documentation only |
| `chore/` | Dependencies, config, tooling |

Area is the workstream: `data`, `scoring`, `ingestion`, `infra`, `ui`.

```
feature/data-auth-repository
feature/ui-sign-in-screen
fix/scoring-idle-time-outage-exclusion
docs/schema
chore/riverpod-upgrade
```

### Commit messages

Subject line: imperative mood, no full stop, under 72 characters. Say what the
commit *does*, not what you did.

```
Add anonymiser stripping author identity before aggregation
```
not
```
added the anonymiser file and fixed some stuff
```

If the *why* isn't obvious, add a blank line and a body explaining it. The body is
for reasoning, not a list of files changed — git already knows the files.

### Pull request template

```
## What
One or two sentences: what this adds or changes.

## Why
The reason. Link the ClickUp task.

## How to check
What the reviewer should look at or run.

## Checklist
- [ ] flutter analyze is clean
- [ ] flutter test passes
- [ ] No hardcoded colours, fonts or sizes (uses Tokens / AppType)
- [ ] No per-person data anywhere
- [ ] New public class has a doc comment
```

### Keep PRs small

One file group per PR — a calculator and its test, a screen and its widgets. A
PR touching thirty files across three workstreams can't be reviewed properly and
won't be. If a task is genuinely big, land it as a sequence of PRs that each
compile on their own.

### Reviewing

You're checking four things, in order:

1. Does it do what the PR says?
2. Does it follow the conventions in this document and `DESIGN.md`?
3. Would you understand this file in three months with no context?
4. Does anything here touch individual-level data? (If yes, request changes.)

A review is a conversation, not a verdict. Ask questions. Approve when you'd be
happy to maintain it.

---

## 4. Naming conventions

### Files

`snake_case.dart`. One primary class per file, and the file is named after it.

| Kind | Pattern | Example |
|---|---|---|
| Model | `<noun>.dart` | `outage_window.dart` |
| Repository interface | `<noun>_repository.dart` | `auth_repository.dart` |
| Repository implementation | `<backend>_<noun>_repository.dart` | `firestore_project_repository.dart` |
| DTO | `<noun>_dto.dart` | `project_dto.dart` |
| Service | `<noun>_service.dart` | `outage_service.dart` |
| Engine / calculator | `<noun>_engine.dart`, `<noun>_calculator.dart` | `velocity_calculator.dart` |
| Adapter / client | `<source>_adapter.dart`, `<source>_client.dart` | `git_metadata_adapter.dart` |
| Riverpod notifier | `<feature>_notifier.dart` | `dashboard_notifier.dart` |
| Screen | `<name>_screen.dart` | `sign_in_screen.dart` |
| Widget | `<name>.dart` | `capacity_bar.dart` |
| Test | mirrors the source path, `_test.dart` | `test/unit/anonymiser_test.dart` |

### Dart

| Thing | Style | Example |
|---|---|---|
| Class, enum, typedef | `PascalCase` | `HealthScoreEngine` |
| Variable, function, parameter | `lowerCamelCase` | `capacityUsed` |
| Constant | `lowerCamelCase` | `Tokens.space4`, `defaultPollInterval` |
| Private | leading underscore | `_SeamPainter`, `_emit()` |
| Riverpod provider | `<noun>Provider` | `healthSnapshotProvider` |
| Riverpod notifier | `<Noun>Notifier` | `DashboardNotifier` |
| Boolean | reads as a question | `isLive`, `isShedding`, `hasFlags` |
| Repository interface | `abstract interface class` | `abstract interface class AuthRepository` |
| Firestore field | `lowerCamelCase` | `capturedAt`, `orgId` |
| Firestore collection | lowercase plural | `organisations`, `signals` |

Screen-private widgets are private classes in the screen file (`_ProjectRow`,
`_GridStrip`). The moment a second screen needs one, promote it to `lib/widgets/`
and drop the underscore.

### Riverpod

We use Riverpod **without code generation** — no `build_runner`, no `.g.dart`.
Three provider types cover everything:

| Need | Use |
|---|---|
| A dependency (repository, service) | `Provider<T>` |
| A stream from the data layer | `StreamProvider<T>` |
| Mutable state with methods | `NotifierProvider<XNotifier, XState>` |

Repositories and services are provided in `state/providers.dart`. Feature state
lives in its own `state/<feature>_notifier.dart`. Screens are `ConsumerWidget`
or `ConsumerStatefulWidget` and read with `ref.watch`. **Never construct a
repository or service inside a widget.**

### Documentation in code

Every public class gets a `///` doc comment saying what it's *for* — the
responsibility, not a restatement of the name. Where a decision isn't obvious,
say why in a comment. The existing files show the register: see `squad.dart`
for a constraint explained, `health_seam.dart` for a rendering choice explained.

---

## 5. Definition of done

A file is done when all of these hold. Not before.

- [ ] It compiles and `flutter analyze` reports nothing
- [ ] It has a test, if it contains logic (models and pure widgets are exempt;
      calculators, services and repositories are not)
- [ ] `flutter test` passes
- [ ] No colour, font or size is hardcoded — everything comes from `Tokens` and
      `AppType`
- [ ] Nothing in it exposes, stores or displays individual-level data
- [ ] Public classes have doc comments
- [ ] It's been reviewed and merged by someone from a different workstream
- [ ] Its ClickUp task is marked complete, with the PR linked

---

## 6. If you get stuck

- **Blocked on someone else's file?** Build against the interface with a mock.
  That's what the interfaces are for.
- **Need to change an interface after Stage 0?** Open a PR touching only the
  interface, tag every workstream owner, and don't merge until they've all
  approved. Then each owner updates their consumers.
- **Merge conflict?** It almost always means two people edited the same file,
  which means a boundary was crossed. Fix the conflict, then talk about the
  boundary.
- **Not sure where a file goes?** Check the build map. If it's genuinely not
  there, ask before creating it — a new file in the wrong folder is a small
  problem today and a large one in a month.
