# Firestore schema

What lives where in `project-health-monitor-436da`, which workstream writes it,
and why the structure is shaped this way.

The field names here match the DTOs in `lib/data/dto/` exactly. If you change
one, change both — a mismatch fails silently, because Firestore returns null
for a field that does not exist and the DTO falls back to a default.

---

## Shape

```
users/{uid}
organisations/{orgId}
  ├── projects/{projectId}
  ├── squads/{squadId}
  ├── signals/{signalId}
  ├── outages/{outageId}
  ├── sources/{sourceId}
  ├── projectPlans/{projectId}
  ├── settings/scoringweights
  ├── directory/{uid}
  ├── squadMembers/{uid}
  └── conversations/{conversationId}
        └── messages/{messageId}
```

**Everything hangs off an organisation.** That is what makes the security rules
simple: one membership check scopes every read, and no team can ever see
another's data. `users` sits at the root because a user has to be readable
before we know which organisation they belong to.

---

## `users/{uid}`

Document id is the Firebase Auth uid.

| Field | Type | Notes |
|---|---|---|
| `email` | string | |
| `displayName` | string | Shown to the team |
| `orgId` | string | Scopes every query this user makes |
| `role` | string | `developer`, `lead` or `manager` |
| `createdAt` | timestamp | Server timestamp |

**Written by:** the app, on registration. Roles are never raised by the client —
promoting someone is an administrative action done in the console.

**No activity data ever goes here.** This document says who someone is, never
what they have done.

---

## `organisations/{orgId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | |
| `createdAt` | timestamp | |
| `memberCount` | number | A count, not a list of people |

---

## `organisations/{orgId}/projects/{projectId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | |
| `client` | string | |
| `squadId` | string | References a sibling squad document |
| `score` | number | 0–100 composite |
| `factors` | array of maps | See below |
| `seam` | array of maps | See below |
| `openSignals` | number | |
| `budgetBurn` | number | Fraction, 0–1, can exceed 1 |
| `scheduleDaysRemaining` | number | |
| `loadSheddingHoursLost` | number | Reported, never deducted from `score` |
| `scheduleTotalDays` | number | Total planned duration. Needed for a burn *rate* |
| `velocityRatio` | number | Throughput vs own baseline; 1.0 is on baseline |
| `updatedAt` | timestamp | |

`scheduleTotalDays` and `velocityRatio` exist for the forecaster. Burn alone
cannot produce a date — 94% spent means nothing until you know whether that
took three weeks or three months. Both default safely when absent (0 and 1),
and a project missing them produces no forecast rather than a wrong one.

**`factors[]`** — each entry:

| Field | Type |
|---|---|
| `name` | string |
| `value` | number (0–100) |
| `weight` | number (weights sum to 1) |
| `detail` | string — the sentence explaining the number |

**`seam[]`** — each entry, oldest first:

| Field | Type |
|---|---|
| `state` | string — `onTrack`, `watch`, `atRisk`, `critical` |
| `periodLabel` | string — e.g. "12 Sep" |
| `flagged` | boolean — a risk flag fired in this period |

Factors and seam segments are stored **inline rather than as subcollections**.
They are always read with the project and never queried alone, so a
subcollection would cost an extra read per project for no benefit.

**Written by:** ingestion, server-side. Never by a client — which is what stops
a team editing its own scores.

---

## `organisations/{orgId}/squads/{squadId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | |
| `headcount` | number | How many people. **Not who.** |
| `weeklyHours` | number | Hours the squad has in a week, across everything. Stated by the team, like the headcount — a commit log knows somebody worked, not how many hours they had. Absent means capacity is not computed rather than guessed. |
| `capacityUsed` | number | Committed hours over `weeklyHours`; above 1 is over-allocation |
| `activeProjectCount` | number | |
| `velocityTrend` | number | Fraction against own baseline; negative is slowing |
| `updatedAt` | timestamp | |

**There is deliberately no member list on this document**, and there must
never be one: a squad's own record stays a set of totals, so every query that
reads a score reads no identity with it.

Membership is held separately, in `squadMembers/{uid}` below. That collection
was added on 21 October 2026 and it does mean squad membership is now
derivable — see constraint 1 in `CLAUDE.md` for what that cost and what was
kept. No metric moved with it: nothing on a squad, a project or a signal
resolves to a person.

---

## `organisations/{orgId}/signals/{signalId}`

| Field | Type | Notes |
|---|---|---|
| `title` | string | What is happening, in the team's terms |
| `because` | string | **Required.** Why it fired |
| `severity` | string | Same four state names as `seam.state` |
| `projectId` | string | |
| `raisedAt` | timestamp | |
| `infrastructureRelated` | boolean | True means grid or connectivity, not delivery |

`because` is required in the model, so an unexplained warning cannot be
constructed in code. Anything written here without it is a bug.

---

## `organisations/{orgId}/outages/{outageId}`

| Field | Type | Notes |
|---|---|---|
| `stage` | number | Load-shedding stage, 1–8 |
| `start` | timestamp | |
| `end` | timestamp | |
| `affectedSquadIds` | array of strings | Squads, not people |

---

## `organisations/{orgId}/sources/{sourceId}`

| Field | Type | Notes |
|---|---|---|
| `type` | string | `github`, `gitlab`, `clickUp`, `jira` |
| `label` | string | What the team calls it |
| `remoteId` | string | e.g. `owner/repo` or a ClickUp list id |
| `isEnabled` | boolean | |
| `lastSyncedAt` | timestamp or null | Null until the first sync |

**No access token is stored here.** Credentials belong to the backend; a client
borrows one per request and never persists it. A token in this collection would
be readable by every member of the organisation.

---

## `organisations/{orgId}/projectPlans/{projectId}`

What a team states a project *is*, as against what ingestion measures about
it. The document id is shared with the `projects` document ingestion builds
from it.

| Field | Type | Notes |
|---|---|---|
| `name` | string | Required, 1–80 characters |
| `client` | string | May be empty, up to 80 characters |
| `squadId` | string | Which squad does the work. Required, or the project is never scored |
| `budgetTotal` | number | Cannot be negative |
| `budgetSpent` | number | Cannot be negative. May exceed the total — an overrun is the thing worth reporting |
| `startDate` | timestamp or null | Null is written rather than omitted, so a date cleared on purpose reaches the document |
| `endDate` | timestamp or null | Must be after `startDate` |
| `weeklyHours` | number | Hours rostered to this project. Idle time is measured against it |
| `isArchived` | boolean | Absent means active |

**Written by:** a lead or manager, from project setup on the Projects tab.
**Read by:** ingestion, which creates or updates `projects/{projectId}` from
it on the next run — which is what lets the app offer project setup while
`projects` stays unwritable by every client.

**Exactly these nine fields**, enforced with `hasOnly` in the rules. One that
could carry a score, a factor list or a seam would be the read-only rule
defeated by the back door. There is no delete: archiving is the removal,
because deleting a failing project is the simplest way to make it stop
looking bad.

---

## `organisations/{orgId}/settings/scoringweights`

The document id is all lower case, matching `AppConstants.scoringWeightsDoc`.
It is spelled that way in the code, so it is spelled that way here: a capital
W produced a second, unread settings document that quietly held different
weights for weeks.

A single document.

| Field | Type | Default |
|---|---|---|
| `budgetBurn` | number | 0.25 |
| `taskVelocity` | number | 0.25 |
| `issueComplexity` | number | 0.20 |
| `commitVolume` | number | 0.15 |
| `idleTime` | number | 0.15 |

Weights must sum to 1. The app normalises them before scoring rather than
trusting them, because this document is user-editable from the settings screen.

---

## `organisations/{orgId}/directory/{uid}`

Document id is the Firebase Auth uid. Who can be messaged.

| Field | Type | Notes |
|---|---|---|
| `displayName` | string | Must match `users/{uid}.displayName` |
| `role` | string | Must match `users/{uid}.role` |

**Written by:** each person, for themselves only, on every sign-in. That keeps
the entry in step when a role is raised in the console, and lists people who
registered before messaging existed.

**Why it exists:** `users` is readable only by its owner, so nothing else lets
one person find another. The directory is the deliberate, narrow exception: a
name and a role, nothing else. No email, no squad, no activity. It is also the
only readable copy of anybody's role, which is why both messaging and the
squad roster read a role from here rather than inventing one.

**The role here is a display copy.** The rules refuse an entry whose role
differs from the one on the person's real `users` document, and they never read
this collection when deciding who may remove whom. They read `users`.

---

## `organisations/{orgId}/squadMembers/{uid}`

Document id is the Firebase Auth uid. Who is on which squad.

| Field | Type | Notes |
|---|---|---|
| `squadId` | string | The squad they are on. Empty means in the organisation and on no squad |

**One field, and the rules refuse any document with another key.** The name
and role a roster shows are joined from the directory, so this is not a second
place a person's details accumulate — and if this document ever grew a field,
every write would start being rejected rather than quietly succeeding.

**Written by:** somebody who **strictly outranks** the person being placed. A
manager places leads and developers, a lead places developers, and nobody
places a manager — not even themselves. Same ladder as group removal in
messaging, and roles are read from `users`, never from the directory.

**Read by:** every member of the organisation. A roster only management could
see would be worse than one everybody can see: people are entitled to know
which aggregate their work is counted in.

**No delete.** Taking somebody off a squad writes an empty `squadId`, so a
placement stays a record of a decision somebody made.

**Somebody is on one squad at a time.** Hours committed to two squads at once
would be counted twice.

**What this cost.** This collection, added 21 October 2026, makes squad
membership derivable, and a roster beside a squad's published metrics narrows
those metrics to the people named. That is a real reduction in the privacy
property the rest of this schema is built around, taken knowingly by the team.
Constraint 1 in `CLAUDE.md` and the doc comment on
`lib/models/squad_member.dart` set out the full reasoning. Ingestion does not
read this collection: capacity is still committed hours over the hours a squad
stated, so placing somebody changes who is accounted for and not what anything
scores.

---

## `organisations/{orgId}/conversations/{conversationId}`

A direct conversation or a group.

| Field | Type | Notes |
|---|---|---|
| `kind` | string | `direct` or `group` |
| `name` | string | Groups only. 1–60 characters |
| `memberIds` | array of strings | Uids. Two for `direct`; 1–50 for `group` |
| `createdBy` | string | Uid of whoever made it |
| `createdAt` | timestamp | Server timestamp |
| `lastMessageAt` | timestamp | Orders the inbox. Set when it is made and on every send |

**Direct conversations** have the id `{uidA}_{uidB}`, the two uids in sorted
order, so the same pair always lands in the same conversation. Anybody in the
organisation can start one with anybody else, whether or not they share a
group.

**Groups** are created by a lead or a manager with the creator as the only
member, and everybody else is added one write at a time. A rule can check one
person's organisation per write but cannot loop over a list.

Who may do what to a group, enforced in `firestore.rules` and mirrored in
`lib/models/messaging_rules.dart`:

| Action | Developer | Lead | Manager |
|---|---|---|---|
| Create a group | No | Yes | Yes |
| Add somebody | No | Yes | Yes |
| Leave | Yes | Yes | Yes |
| Remove a developer | No | Yes | Yes |
| Remove a lead | No | No | Yes |
| Remove a manager | No | No | No |

Removing somebody needs a role strictly above theirs, so peers cannot remove
each other: a lead cannot remove a lead, and a manager cannot remove a manager.
Roles are read from the real `users` documents.

Only members read a conversation. A person who is removed loses access to its
messages at once. The only fields that change after creation are `memberIds`
(one person in or out per write) and `lastMessageAt`. A conversation is never
deleted.

The inbox query filters on `memberIds` and sorts on the device, so it needs no
composite index.

---

## `organisations/{orgId}/conversations/{conversationId}/messages/{messageId}`

| Field | Type | Notes |
|---|---|---|
| `body` | string | 1–2000 characters |
| `senderId` | string | Must be the signed-in uid |
| `senderName` | string | Snapshot of the display name when sent. At most 80 characters |
| `createdAt` | timestamp | Server timestamp |

**Written by:** members of the conversation, as themselves. Exactly these four
fields: anything else is refused, so a message cannot carry a squad id, a score
or an activity count. Messages are never edited or deleted.

Messages are not part of `HealthSnapshot`, so `SnapshotBrief` cannot send them to
the assistant. Nothing queries them by sender or counts them per person, and
nothing ingestion produces is attached to one.

---

## What is deliberately absent

No collection anywhere holds per-developer **activity**. There is no
`users/{uid}/commits`, no `contributions`, no `activity` keyed by person, and
no field on any document that resolves a number to a name.

`squadMembers` holds identity without measurement, and is the one place a
person is attached to anything the app reports on. The line this schema still
holds is between knowing who somebody works with and knowing what they
produced.

`RawActivityEvent` — the only type in the codebase carrying an author — exists
in memory inside the ingestion layer and is never serialised. The anonymiser
converts it to squad totals before anything reaches Firestore, and drops squads
with fewer than two contributors entirely, because a one-person aggregate is
individual data with a different label.

This is not a limitation to be worked around later. It is the commitment in
Section D of the research proposal, implemented at the layer where it cannot be
bypassed by a UI change.

---

## Security rules

Live in `firestore.rules`, deployed with:

```bash
firebase deploy --only firestore:rules
```

The shape:

- A user reads and updates only their own `users/{uid}` document
- Organisation data is readable by members of that organisation, checked
  against `users/{uid}.orgId`
- `projects`, `squads` and `signals` are **read-only to clients** — they are
  written by ingestion, never by the app
- `settings` is writable by a lead or manager, so weights can be tuned
- `projectPlans` is writable by a lead or manager, nine fields exactly, and is
  how a project comes into existence without `projects` becoming writable
- `squadMembers` is writable only by somebody who strictly outranks the person
  being placed, one field exactly
- `directory`, `conversations` and `messages` are written by people, as
  themselves. Group creation, adding and removing follow the role ranking and
  are enforced in the rules; see the conversations section above
