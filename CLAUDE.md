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

A client may write exactly three things, each with its own rule: `sources`,
`settings`, and `comments` under a signal. Nothing else. If you find yourself
adding a write method to `FirestoreProjectRepository`, that is the constraint
telling you the work belongs in ingestion.

### 4. No manual status entry

The app's whole differentiator is passive capture. There is deliberately no UI
for typing in progress, and `ProjectRepository` has no write method. Input is
confined to *Connect a source*, which is one-off setup, and to comments on a
signal, which are a discussion about the data and never the data itself.

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

**Working:** builds for Android, iOS and web; reads live Firestore data scoped
to the signed-in user's organisation; Firebase Auth with email and password;
security rules open per collection and verified denying anonymous access;
offline cache so it stays usable during an outage.

Six tabs: **Home** (a neutral landing that needs no data, so it renders with
no connection), Health, Squads, Signals, **Week** and **Ask**.

**Week** is the screen no competing tool has. It lays the week out as a bar
per project, then states what load-shedding has taken from it and that those
hours are excluded from every score. Grid and Calendar used to be separate
tabs; Calendar's grid panel and squad list only repeated what Grid and Squads
already said, so they were folded into one. Outage state is shown for today
only — a schedule that changes daily cannot honestly be labelled for Thursday,
so a future day says so rather than reading as outage-free.
`test/widget/week_screen_test.dart` holds that promise in place.

**Comments on signals.** The one thing people write that carries a name, and
fenced in deliberately: four fields only, enforced in `firestore.rules`, no
editing, delete your own only. Nothing queries them by author, and they are
not part of `HealthSnapshot`, so the assistant cannot see them. The reasoning
is in the doc comment on `lib/models/comment.dart`, which is worth reading
before touching any of it.

**Roles** limit what you can change, never what can be seen about you. A
developer reads every setting and every score and writes none of them, which
is the point: scoring a team with numbers it cannot inspect is the thing this
project exists to argue against. `AppUser.canChangeSettings` is the predicate,
`currentUserProvider` and friends in `auth_notifier.dart` are how screens ask,
and every client-side check is repeated in `firestore.rules` — a check only in
the client is a courtesy, not a control.

**Scoring weights persist.** `SettingsNotifier` reads the organisation's saved
weights and writes them back through `SettingsRepository`. An edit in progress
is never overwritten by a teammate's save, and a refused save keeps the draft
so nobody loses work to a permission they could not see.

**Messaging.** Direct messages and groups, reached from an icon in the app
bar rather than from a tab: the six sections are what the app measures, and a
conversation is not a measurement.

Anybody may message anybody directly. Only a lead or manager creates a group
or adds to one; anybody may leave; removing somebody else needs a strictly
higher role, so a lead cannot remove another lead. Messages cannot be edited
or deleted by anyone, which is what makes a conversation a record rather than
a draft. `MessagingRules` holds this and `firestore.rules` repeats it, with
roles always read from `users` and never from the directory.

**The directory** is how one person finds another: a display name and a role,
written by each person about themselves on sign-in. It carries no squad, no
project, no email and no activity, and that absence is the point. A directory
with a squad on it would be a squad member list, and a squad member list beside
published squad metrics is individual performance data about named people —
which is what `Anonymiser.minimumContributors` exists to prevent. The same
reasoning is why a separate member-management feature was turned down.

It does mean an organisation's names and roles are listable by its members,
which was not previously possible. That is a real change and worth stating
plainly: squad membership is still not derivable, which is the property
constraint 1 actually protects.

**Ingestion sources are managed in the app.** Settings → Connected sources
lists them with when each last synced, and a lead or manager can add, pause
or remove one. Pausing keeps the source so a tracker silenced for a fortnight
does not have to be retyped.

The connect screen takes no access token, deliberately. A source records what
to read, never how to sign in: the credential lives with the ingestion job,
and `firestore.rules` refuses any source document carrying one. A token box
would take a secret, fail to store it, and leave somebody believing they had
set it up.

**Display preferences** live under Settings → Preferences: date and time
format, density, which tab the app opens on, how many signals the dashboard
lists, and whether the grid strip shows. Text size and bold text sit
separately under Accessibility, and have their own reset — somebody who needs
large text should not lose it by tidying up their date format.

All of it is on-device only, in `shared_preferences`, and never sent anywhere:
how somebody likes their dates written is not something the organisation needs
to know. Defaults reproduce how the app looked before any of this existed, so
nobody sees a change until they choose one, and a storage failure falls back
to those defaults rather than surfacing an error.

`StartTab` in `preferences.dart` is indexed straight into the shell's
`_sections`, so the two lists have to stay in step. A stored tab that no
longer exists falls back to Home rather than opening the wrong screen —
`preferences_store_test.dart` and the start-tab case in
`app_flow_test.dart` are what hold that together.

**Forecasting** projects the current trend forward — `forecaster.dart` turns
burn rate and velocity into "the budget runs out eight days before the work
does". Deliberately linear: "at the current rate" honestly means a straight
line, and there is no historical outcome data to fit anything against. Every
field is nullable and null means *cannot say*; a project with no schedule
total, one that has not started, or a squad at 2% of baseline all produce no
date rather than a wrong one.

**The assistant** (Ask tab) answers questions about the current snapshot. Each
user supplies their own Anthropic API key, stored on-device — a shared key
would ship inside the APK where anyone could extract it. Nobody has added a
key yet, so it is inert until someone does.

**Not working yet:** nothing is *producing* data. The Firestore documents were
written once by `tool/seed_firestore.js`, which is why scores no longer move.
The ingestion layer is fully written and tested but has nowhere server-side to
run — that is the next significant decision. Cloud Functions need the Blaze
plan; a scheduled GitHub Action is the free alternative and probably the right
first move.

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

Both must be clean. There are 180 tests and they all pass; a failure is
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
| `lib/services/health_scoring/forecaster.dart` | Projects the trend, and refuses to guess |
| `lib/services/ingestion/anonymiser.dart` | The ethics commitment in code |
| `lib/services/assistant/snapshot_brief.dart` | Everything the assistant is told |
| `lib/models/comment.dart` | Why attribution is allowed here and nowhere else |
| `firestore.rules` | The only thing actually enforcing any of it |
| `lib/screens/week_screen.dart` | Outage loss stated, then excluded |
| `lib/models/preferences.dart` | On-device display choices, and their defaults |
| `lib/widgets/health_seam.dart` | The signature component |

---

## Per-project ownership

There is deliberately no project owner or lead field, and no
`canManageProject`. Both existed briefly and were removed because the feature
they implied cannot be built as things stand.

To assign a lead you have to pick a person. Picking a person needs a list of
the organisation's members, and `users` is readable only by its own owner —
that rule is in `firestore.rules` precisely so a squad's membership cannot be
enumerated, which is constraint 1 doing its job. Relaxing it to add an
assignment screen would trade a commitment from the ethics section for a
feature nothing in the app currently needs.

There is also nothing on a project a client may write, so even a correctly
assigned lead would have no permission to act on it.

If the team does want it later, it belongs where roles already live: set in
the Firebase console, written by ingestion, read-only to the app. Adding a
`leadId` the app can write is the version to refuse.

---

## What is outstanding

In rough order of value to the research:

1. **Ingestion running somewhere.** Everything else is built around it and
   nothing currently produces data. A scheduled GitHub Action is free and the
   team already has the repo; Cloud Functions need Blaze.
2. **Onboard the remaining teammates** — only two of five have working
   environments.
3. **A decision on the app name.** `keel` is the package name and the display
   name; the shortlist was Keel, Sightline, Plumb and Trim. Anything that
   sounds like surveillance was ruled out, for the reasons in section 1 above.
4. **An API key for the assistant**, if the team wants it live.

**Messaging was excluded and then included.** The original position was that
general messaging duplicates the WhatsApp the team already uses and answers
none of the research questions. The team revisited that on 19 October 2026
and decided to keep it. The proposal needs to say so too — an app that ships a
feature its own documentation calls deliberately absent is worse than either
choice made cleanly.

What held across the reversal is the reason the exclusion existed: messaging
must not become a second, unmonitored place where project data accumulates
outside the model. It did not. Conversations carry no project, squad, score or
signal, nothing in `HealthSnapshot` touches them, and the assistant cannot see
them for the same structural reason it cannot see comments.

---

## Work that was submitted and not merged

Three features arrived from teammates on 19 October 2026. One was merged, two
were not, and a third is waiting on a decision. This is written down because
the reasons are not obvious from the code, and whoever wrote them deserves an
answer better than silence.

**Merged: managing ingestion sources from the app.** The idea was right and
filled a real gap — the sources screen could only ever show an empty list,
because nothing provided it one. Reimplemented rather than taken as-is: the
submitted version also re-added `Project.leadId`, removed the doc comments
explaining why it had been removed, and stripped the stale-sync highlighting
from the sources screen for the second time. The idea was kept and the
regressions were not.

**Not merged: creating and editing projects from the app.** It adds
`createProject`, `updateProject` and `deleteProject` to `ProjectRepository`,
against constraints 3 and 4. It also cannot work: the same archive's
`firestore.rules` is byte-identical to this one, so `projects` is still
`allow write: if false` and every save would be refused. If the team ever
wants this, the research position has to change first, not the code.

**Not merged: member management.** The team confirmed on 19 October 2026 that
the need behind it was knowing who is in the organisation, which the messaging
directory already serves — one directory, not two.

The implementation could not have been kept regardless. `Member` carried a
name, an email, a `squadId` and a list of `projectIds`. That is a squad member
list, which
constraint 1 rules out by name. The submitted doc comment argued it is safe
because a member has no metric attached, which is true on its own and misses
the combination: a member list is harmless, squad metrics are harmless, and
together they re-identify. "Platform squad: two people, here they are" beside
"Platform squad, velocity down 31%" is individual performance data about two
named people — exactly what `Anonymiser.minimumContributors` exists to
prevent, reached from a direction the anonymiser cannot see.

**Mostly not merged: a navigation dropdown and a split calendar.** A fourth
archive arrived the same day, forked from before the Week fold. It restored
Grid and Calendar as separate tabs, taking the bottom bar back to seven, and
added an app-bar popup menu to navigate between them.

The dropdown is a reasonable answer to too many sections — it is just a
different answer to the one the team had already chosen, and its
implementation hardcoded colours, listed five of the seven destinations, and
duplicated the `_sections` list that exists so a section is named and iconed
in one place.

`calendar_screen.dart` turned out to be the pre-fold `timeline_screen.dart`
with a `StreamBuilder` wrapped round it, taking a repository as a constructor
argument. That is a second, independent subscription to the project stream
alongside `healthSnapshotProvider`, and it reintroduced the hardcoded palette
that the Week rewrite removed. The shell already hands every data tab a
snapshot; that is the integration.

One thing was kept: its Grid screen stated the load-shedding stage in the
status badge rather than only that shedding was on. Stage 2 and stage 6 are
different days, and the number is the first thing a team here asks, so the
badge moved into `week_screen.dart` with a test.

**Merged on the team's decision: messaging.** Careful work — forked from
current main, thorough security rules, roles read from `users` rather than
from the directory it adds, messages immutable. Its directory carries a name
and a role and deliberately no squad, so constraint 1 holds. The team chose
on 19 October 2026 to keep it and amend the proposal to match.

One correction made while merging: its rules comment claimed the `users` rule
"still stops anybody listing the organisation", which stopped being true the
moment the directory became readable org-wide. The directory is the lighter
exposure of the two, but it is an exposure.

---

## If you are unsure

Ask rather than guess, particularly about anything touching individual data,
scoring arithmetic or security rules. The constraints above came from a
research protocol with an ethics review, and a reasonable-looking change can
breach one without being obviously wrong.
