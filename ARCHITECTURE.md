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

### 1. No individual-level *measurement*. Ever.

The research protocol commits to a system "deliberately built without any
individual identity", aggregating to squad level, with management barred from
granular developer analytics.

In practice:

- `RawActivityEvent` is the only type carrying an author. It lives in memory
  inside `lib/services/ingestion/` and is never serialised, cached or stored.
- `Anonymiser` converts it to squad totals before anything reaches Firestore.
- Squads with fewer than two contributors are **dropped entirely**, because a
  one-person "squad total" is that person's data with a different label.
- `test/unit/anonymiser_test.dart` asserts this. If it fails, stop.
- There is no per-person field on any stored document and no metric anywhere
  that resolves to a person. A change that adds one is wrong regardless of how
  useful it is.

**This constraint was narrowed on 21 October 2026, and the heading above used
to read "No individual-level data".** It was weakened deliberately, by the
team, and the honest version is this:

`Squad` still has a `headcount` and never a member list, but
`squadMembers/{uid}` now says who is on which squad, and the Capacity tab
shows each squad's roster by name. A roster beside published squad metrics
re-identifies: "Platform squad: these two people" next to "Platform squad,
velocity down 31%" is individual performance data about two named people,
reached from a direction `Anonymiser.minimumContributors` cannot see.
Suppressing a one-contributor squad does nothing for a squad of two with its
members listed.

That is the same objection that turned down a teammate's member-management
feature on 19 October 2026, recorded further down this file. It has not
stopped being true. The team decided on 21 October 2026 that being able to see
and change who is on a squad was worth it, and the proposal's ethics section
has to say so, an app whose documentation calls a capability a breach while
shipping it is worse than either choice made cleanly.

What was kept, and is what the constraint now protects:

- Membership, not measurement. A placement is **one field**, `squadId`. The
  name and role on screen come from the messaging directory, so this is not a
  second place a person's details accumulate, and `firestore.rules` refuses a
  placement document carrying any other key.
- Placement is an act of management: only somebody who **strictly outranks**
  you may move you, so a developer places nobody and nobody places a manager,
  not even themselves. There is no self-service route onto a squad, because
  which aggregate your work counts in is not the individual's to choose.
- The roster is readable by every member, not only by management. A roster
  only managers could see would be worse: people are entitled to know which
  aggregate they are counted in.
- Nothing reconciles the roster against `headcount` silently. They can
  disagree, and the screen says so.

`lib/models/squad_member.dart` carries this reasoning in full, and
`test/unit/squad_roster_test.dart` and `test/widget/squads_screen_test.dart`
pin the parts that were kept.

### 2. Load-shedding hours are reported, never deducted

Outage hours are removed from *available* time before any ratio is taken, so
the question is always "what did they do with the time they had". A team is
never scored down for a national power failure. `IdleTimeCalculator` is where
this lives, and two tests in `health_score_engine_test.dart` protect it.

### 3. Monitoring data is read-only to clients

`projects`, `squads` and `signals` are written by ingestion, never by the app.
Enforced in `firestore.rules`. This is what stops a team editing its own health
scores, and it is half the anti-gaming argument.

A client may write `sources`, `settings`, `comments` under a signal,
`projectPlans` and `squadMembers`, each with its own rule, and nothing else.
Every one of those says what something *is*; none of them says how work is
*going*. If you find yourself adding a write method to
`FirestoreProjectRepository`, that is the constraint telling you the work
belongs in ingestion.

### 4. No manual status entry

The app's whole differentiator is passive capture. There is deliberately no UI
for typing in progress, and `ProjectRepository` has no write method. Input is
confined to *Connect a source*, which is one-off setup, and to comments on a
signal, which are a discussion about the data and never the data itself.

### 5. The assistant sends squad-level data only

`lib/services/assistant/snapshot_brief.dart` is the only thing in the app that
sends project data to a third party. It can only emit squad-level data because
that is all the domain model holds, there is no per-person field to include by
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

Five weighted indicators compose into one 0-100 score:

| Indicator | Default weight | Measures |
|---|---|---|
| Budget burn | 0.25 | Spend rate against schedule elapsed |
| Task velocity | 0.25 | Throughput against the squad's *own* baseline |
| Issue complexity ratio | 0.20 | Whether remaining work is getting heavier |
| Commit volume | 0.15 | Commit activity against baseline |
| Idle-time ratio | 0.15 | Use of workable time, outages excluded |

**It is multi-dimensional on purpose.** A single linear indicator is trivially
gamed, the proposal raises this when discussing the Hawthorne effect. Commit
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
no connection), Projects, Capacity, Signals, **Schedule** and **Ask**.

**The tabs were renamed on 21 October 2026** to say what each is for rather
than what it is about: Health became Projects, which is also where projects
are now set up; Squads became Capacity, which is the figure that screen
reports; Week became Schedule. Signals stayed, because it is the deliberate
word, milder than an alert, stronger than a note, and the copy voice rests
on it. `StartTab` in `preferences.dart` changed its labels only: the enum
*names* are what gets stored on the device, so renaming one of those
identifiers would invalidate every saved start-tab preference.

**Schedule** is the screen no competing tool has. It lays the week out as a bar
per project, then states what load-shedding has taken from it and that those
hours are excluded from every score. Grid and Calendar used to be separate
tabs; Calendar's grid panel and squad list only repeated what Grid and Squads
already said, so they were folded into one. Outage state is shown for today
only, a schedule that changes daily cannot honestly be labelled for Thursday,
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
and every client-side check is repeated in `firestore.rules`, a check only in
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
project, no email and no activity. It is also the only readable copy of
anybody's role, because `users` is readable only by its owner, which is why
both messaging and the squad roster read a role from here rather than
inventing one.

It means an organisation's names and roles are listable by its members, which
was not previously possible before 19 October 2026.

**Squad rosters.** The Capacity tab lists who is on each squad, and a lead or
manager moves people between them. Membership lives in `squadMembers/{uid}`,
one field wide, and the names shown are joined from the directory.

This is the exposure the directory was carefully built to avoid, added on
purpose a fortnight later. Read constraint 1 above and
`lib/models/squad_member.dart` before changing any of it: the short version is
that squad membership *is* now derivable, that it narrows every squad metric
to the people named beside it, and that the team chose this knowingly. The
rank rule, the single field and the absence of any per-person figure are what
is left holding, and they are each pinned by a test.

A squad's stated `headcount` and its roster can disagree, and the card says so
rather than reconciling them. Ingestion does not read the roster: capacity is
still the committed hours over the hours the squad stated, so placing somebody
changes who is accounted for and not what anything scores.

**Projects are added in the app, and still written by ingestion.** Project
setup sits at the top of the Projects tab, it was a row under Settings until
21 October 2026, which meant reading a score flagged "budget, dates or hours
missing" and then going somewhere else to fix it. A lead states what a project
is: name, client, squad, budget, schedule and weekly hours. None of it says
how the work is going, so constraint 4 holds, it is setup, like connecting a
source. A developer opens the same screen and changes nothing on it.

The trick is which collection it writes. A plan goes to `projectPlans`, which
clients may write; ingestion reads it and builds the `projects` document from
it on the next run. So `projects` stays `allow write: if false` and a project
can still be created from the app. A new project appears on the dashboard
after a run rather than instantly, which is honest: until something has been
read there is nothing to say about its health.

The rules accept exactly nine fields on a plan. One that could carry a score,
a factor list or a seam would be the read-only rule defeated by the back
door.

**There is no delete, only archive.** Removing a failing project is the
simplest possible way to make it stop looking bad, which is the behaviour the
anti-gaming argument exists to resist. Archiving marks the plan, ingestion
marks the project, and `FirestoreProjectRepository` filters archived projects
out once so every screen is unaffected. The history and the seam stay where a
post-mortem could still find them.

**Ingestion sources are managed in the app.** Settings → Connected sources
lists them with when each last synced, and a lead or manager taps one to
change its name, identifier, type or squad, to pause it, or to remove it.
Pausing keeps the source so a tracker silenced for a fortnight does not have
to be retyped.

Adding and editing are one screen, the same arrangement the project form
uses: the fields, the validation and the squad choice are identical, and two
screens would be two places for the same rules to drift apart.

Removing a source is a real delete, unlike archiving a project. A source is a
statement about where to read from, and removing one destroys no history,
the scores it contributed to stay where they are. That is the difference that
makes a delete acceptable here and not there.

**Destructive actions confirm first**, through `ConfirmDialog`. One widget
rather than a dialog written out at each call site, because what makes a
confirmation useful is that it reads the same every time: same shape, same
button order, destructive action on the right in the warning colour, and the
button names the action rather than saying OK. A dialog that moves its buttons
around trains people to tap without reading.

The connect screen takes no access token, deliberately. A source records what
to read, never how to sign in: the credential lives with the ingestion job,
and `firestore.rules` refuses any source document carrying one. A token box
would take a secret, fail to store it, and leave somebody believing they had
set it up.

**Alerts.** A project crossing into at risk or critical raises one alert, and
so does one recovering. `NotificationService` decides whether anything is
worth saying, `AlertPresenter` decides how it is said, and `AlertNotifier` is
the wire between them and the snapshot, which did not exist until 21 October
2026, so the service was correct and unreachable for weeks. Nothing called
`evaluate` and nothing listened to `alerts`.

It fires on the **transition**, not the state: a project sitting at critical
for a fortnight produces one alert, not one a day. An early warning system
that cries wolf gets muted, and a muted warning system is worse than none.
Recovery is announced too, so the tool does not read as purely punitive.

Two halves. The in-app banner always shows, because it is a change on a screen
somebody is already looking at. The tray notification is opt-in under Settings
→ Customisations, off by default, and asks for the Android permission at the
moment it is switched on rather than at launch, a prompt before anybody knows
what it is for gets refused, and on Android a refusal is remembered. A refused
permission leaves the switch off rather than claiming to be on while nothing
can be shown.

They are local notifications, not push. The alert is produced on the device
from a snapshot the app has already read, so there is nothing for a server to
send, and the Spark plan has no Cloud Functions to send it from. The honest
consequence is that alerts are raised while the app is running; this is not a
background service.

An alert carries a project and never a person, and `alert_notifier_test.dart`
asserts it.

**Display preferences** live under Settings → Preferences: date and time
format, density, which tab the app opens on, how many signals the dashboard
lists, whether the grid strip shows, and whether a declining project notifies
you. Text size and bold text sit
separately under Accessibility, and have their own reset, somebody who needs
large text should not lose it by tidying up their date format.

All of it is on-device only, in `shared_preferences`, and never sent anywhere:
how somebody likes their dates written is not something the organisation needs
to know. Defaults reproduce how the app looked before any of this existed, so
nobody sees a change until they choose one, and a storage failure falls back
to those defaults rather than surfacing an error.

`StartTab` in `preferences.dart` is indexed straight into the shell's
`_sections`, so the two lists have to stay in step. A stored tab that no
longer exists falls back to Home rather than opening the wrong screen,
`preferences_store_test.dart` and the start-tab case in
`app_flow_test.dart` are what hold that together.

**Forecasting** projects the current trend forward, `forecaster.dart` turns
burn rate and velocity into "the budget runs out eight days before the work
does". Deliberately linear: "at the current rate" honestly means a straight
line, and there is no historical outcome data to fit anything against. Every
field is nullable and null means *cannot say*; a project with no schedule
total, one that has not started, or a squad at 2% of baseline all produce no
date rather than a wrong one.

**The assistant** (Ask tab) answers questions about the current snapshot. Each
user supplies their own Anthropic API key, stored on-device, a shared key
would ship inside the APK where anyone could extract it. Nobody has added a
key yet, so it is inert until someone does.

**Ingestion runs.** `tool/ingest.dart` reads the sources, aggregates, scores
and writes, reusing the same anonymiser and engine the app was built around.
It authenticates as a service account, which is not subject to
`firestore.rules`, that is the point: `projects`, `squads` and `signals` stay
unwritable by every client and this is the only identity that can change them.

`.github/workflows/ingest.yml` runs it daily at 04:00 UTC, which is 06:00
SAST. Manual runs work too and default to a dry run, which reads and scores
and writes nothing.

**The window is fourteen days, measured rather than guessed.** The anonymiser
needs two contributors in a window or it suppresses the squad, and a week does
not reliably contain two. Sampled on 19 October 2026: riverpod had 2 commits
from 1 author in seven days, directus had none at all, and both cleared the
threshold comfortably over fourteen. A busy project can have a silent week.
For the small teams this is built for, a fortnight is the shortest period that
holds a signal rather than noise.

**Demonstration data comes from a public repository**, `rrousselGit/riverpod`,
set up by `tool/configure_demo_source.dart`. Chosen because its shape
resembles the teams this app is for, around eight contributors at a few
commits a day, rather than a corporate monorepo. Only public commit metadata
is read, and the anonymiser aggregates before anything is stored. The team's
own repository is too quiet to demonstrate anything: five commits a week with
one author per window is the privacy protection working, not the system.

**All five indicators are live**, from that one source. A Git source reads
pull requests as well as commits: a merged pull request is work finished, an
opened one is work arriving, and the ratio between them is what the
complexity calculator reads. Issues are deliberately not read, riverpod has
86 open and closed none in a fortnight, so weighing that stock against a
fortnight's throughput would clamp the indicator to zero and say more about
open-source culture than about a team.

`weeklyHours` on the plan has to match what the source actually reports, and
it has been wrong twice in both directions. Thirty-six hours a week against
six person-hours a fortnight read 7% utilisation; five hours against eleven
pegged it at 100%. Nine reads 61%. The figure is a fact about the roster
until it matches the work.

A squad states its own `weeklyHours`, and capacity is the committed hours
over that. It used to be a headcount times a forty-hour week, which assumed
everybody is full-time on this work and made a part-time squad read as
permanently idle at 11%. A squad that has stated nothing gets no capacity
written rather than a guess.

`tool/backfill_history.dart` gave the source the history it had but had not
been asked about. Velocity and commit volume compare a window against the one
before it, so a source connected today abstains for a fortnight, avoidably,
since those fortnights already happened. Same adapters, same anonymiser, same
contributor threshold, over windows that have closed. Scores are not
backdated: a score is a statement about a project now, and the seam should
show when the app started watching.

**Signing in, and getting back in.** One screen does sign-in and
registration, toggled, because a team of five setting this up for the first
time will do both within a minute of each other. Registration pins the role to
developer in `firestore.rules`, so an account cannot grant itself a higher
one; raising a role is done in the console.

A forgotten password sends a Firebase reset email. The screen deliberately
says the same thing whether or not the address has an account, and
`FirebaseAuthRepository.sendPasswordReset` swallows `user-not-found` and
`invalid-email` to match: an app built around not exposing its members should
not hand out which addresses are registered at the front door. Everything
else, no connection, too many attempts, is reported, because somebody
otherwise waits for an email that was never sent.

`SplashScreen` is what the app draws while it works out whether anybody is
signed in. The wait is real, Firebase restores the session, then the user's
document is read for their organisation and role, and it replaced a bare
spinner, which on a slow connection reads as an app that has failed to start.
It needs no data, so it renders whatever the network is doing.

**Firebase project:** `project-health-monitor-436da`. Demo data lives under
`organisations/demo-org`. Register with organisation code `demo-org` or you
will sign in successfully to an empty dashboard.

---

## Conventions

**Never hardcode a colour, font or size.** Everything resolves through
`Tokens` (`lib/theme/tokens.dart`) and `AppType` (`lib/theme/typography.dart`).
Full system in `docs/DESIGN.md`.

**Naming:** `snake_case.dart`, one primary class per file, named after it.
Suffixes carry meaning, `_repository`, `_service`, `_calculator`, `_notifier`,
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

Both must be clean. There are 317 tests and they all pass; a failure is
something you introduced.

Format with `dart format lib/ test/`, the project is formatted and an
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
| `lib/models/squad_member.dart` | The one place a person is tied to a squad, and what that cost |
| `firestore.rules` | The only thing actually enforcing any of it |
| `lib/screens/week_screen.dart` | The Schedule tab: outage loss stated, then excluded |
| `lib/models/preferences.dart` | On-device display choices, and their defaults |
| `lib/widgets/health_seam.dart` | The signature component |
| `lib/widgets/labelled_field.dart` | The shared text field, used by all three forms |
| `lib/widgets/confirm_dialog.dart` | How the app asks before something hard to undo |
| `lib/state/alert_notifier.dart` | The wire from a snapshot to a notification |

---

## Per-project ownership

There is deliberately no project owner or lead field, and no
`canManageProject`. Both existed briefly and were removed because the feature
they implied cannot be built as things stand.

The original reason was structural: assigning a lead means picking a person,
picking a person needs a list of the organisation's members, and there was no
such list to pick from.

**That reason is gone, and it is worth being straight about it.** The
messaging directory names everybody, `squadMembers` says who is on which
squad, and `projectPlans` is a collection a client may write, so a `leadId`
on a plan is now perfectly buildable, and the rules could gate it to a lead or
manager the same way they gate everything else there.

What is left is a choice rather than an impossibility. The argument against
it is the one in constraint 1: a project with a named lead, beside that
project's score and its squad's roster, is the narrowest attribution in the
app, one score, one name. The squad roster at least aggregates to a handful
of people. If the team wants per-project ownership, that is the sentence the
proposal has to answer, not a technical obstacle.

Note also that `Project` has carried and lost a `leadId` twice already, both
times arriving in a teammate's archive. Removing it again is not a rejection
of the idea; it is that the field keeps appearing without the decision behind
it.

---

## What is outstanding

In rough order of value to the research:

1. **Amend the proposal's ethics section for the squad roster.** This is now
   the most important outstanding item, ahead of anything technical. The
   protocol says the system is "deliberately built without any individual
   identity"; since 21 October 2026 it names who is on which squad and lets
   management move them. The code says so, this file says so, and the
   submitted document does not. An ethics section that describes a system
   other than the one shipped is the one defect a marker will certainly find.
   Messaging needs the same amendment, below.
2. **Confirm the scheduled run actually fires.** The cron was switched on on
   19 October 2026 and the first scheduled run wrote nothing, GitHub delays
   scheduled workflows, sometimes by hours, and a job that has never run in
   Actions has never had its environment tested. Check the Actions tab before
   trusting the dashboard's timestamps.
3. **Onboard the remaining teammates**, only two of five have working
   environments.
4. **An API key for the assistant**, if the team wants it live.

**The app is called PRAHM**, decided by the team on 22 October 2026. It was
Keel until then, and the shortlist was Keel, Sightline, Plumb and Trim.
Anything that sounded like surveillance was ruled out, for the reasons in
section 1 above.

The rename reached the Dart package (`package:prahm/...`), the display name on
every platform, and every string a user can read. Two things it deliberately
did **not** reach, both because they are identities registered elsewhere that
the app is matched against:

- **`za.co.diego.keel`**, the Android `applicationId`, the iOS bundle id and
  the `package_name` inside `google-services.json`. Firebase matches the
  running app against that string, so changing it breaks Auth and Firestore
  until a new Android app is registered in the console and a fresh
  `google-services.json` downloaded. It is invisible to users.
- **`KEEL_SOURCE_TOKENS` and `KEEL_SQUAD_OF_AUTHOR`**, environment variables
  read by `tool/ingest.dart`, supplied from GitHub repository secrets of the
  same name. Renaming them in code without renaming the secrets in the GitHub
  settings would leave ingestion running with no tokens and no error.

Changing either is a deliberate, coordinated job rather than a find-and-
replace, and neither affects what anybody sees.

**Messaging was excluded and then included.** The original position was that
general messaging duplicates the WhatsApp the team already uses and answers
none of the research questions. The team revisited that on 19 October 2026
and decided to keep it. The proposal needs to say so too, an app that ships a
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
filled a real gap, the sources screen could only ever show an empty list,
because nothing provided it one. Reimplemented rather than taken as-is: the
submitted version also re-added `Project.leadId`, removed the doc comments
explaining why it had been removed, and stripped the stale-sync highlighting
from the sources screen for the second time. The idea was kept and the
regressions were not.

**Rebuilt rather than merged: creating and editing projects from the app.**
The submitted version added `createProject`, `updateProject` and
`deleteProject` to `ProjectRepository`, against constraints 3 and 4, and it
could not have worked: that archive's own `firestore.rules` was
byte-identical to this one, so `projects` was still `allow write: if false`
and every save would have been refused.

The need behind it was real, and was built on 20 October 2026. A plan is
written to `projectPlans`, ingestion builds the `projects` document from it,
and the read-only rule stays intact. See "Projects are added in the app"
above. Delete became archive, for the reason given there.

**Not merged, then largely conceded: member management.** The team confirmed
on 19 October 2026 that the need behind it was knowing who is in the
organisation, which the messaging directory already serves, one directory,
not two.

The implementation was refused on more than that. `Member` carried a name, an
email, a `squadId` and a list of `projectIds`. That is a squad member list,
which constraint 1 ruled out by name. The submitted doc comment argued it is
safe because a member has no metric attached, which is true on its own and
misses the combination: a member list is harmless, squad metrics are harmless,
and together they re-identify. "Platform squad: two people, here they are"
beside "Platform squad, velocity down 31%" is individual performance data
about two named people, exactly what `Anonymiser.minimumContributors` exists
to prevent, reached from a direction the anonymiser cannot see.

**On 21 October 2026 the team overruled that, and the squad roster was
built.** Whoever wrote the original is owed the plain version: the objection
above was not wrong, and it was not withdrawn, the capability was judged
worth the cost anyway. What the rebuild changed is the shape, not the
principle:

- Membership is one field in its own collection, not a `Member` record. No
  email, no `projectIds`, and the name comes from the directory.
- Moving somebody needs a role strictly above theirs, so it is an act of
  management rather than self-service.
- Nothing per-person is measured, stored or scored, which is the half of
  constraint 1 that survived.

So the honest summary is that the idea was right, the first implementation
would still be refused today, and the position it ran into has since moved.
See constraint 1 and `lib/models/squad_member.dart`.

**Mostly not merged: a navigation dropdown and a split calendar.** A fourth
archive arrived the same day, forked from before the Week fold. It restored
Grid and Calendar as separate tabs, taking the bottom bar back to seven, and
added an app-bar popup menu to navigate between them.

The dropdown is a reasonable answer to too many sections, it is just a
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

**Merged on the team's decision: messaging.** Careful work, forked from
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
