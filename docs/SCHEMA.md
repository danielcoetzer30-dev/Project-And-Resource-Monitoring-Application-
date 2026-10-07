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
  └── settings/scoringWeights
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
| `capacityUsed` | number | Fraction; above 1 is over-allocation |
| `activeProjectCount` | number | |
| `velocityTrend` | number | Fraction against own baseline; negative is slowing |
| `updatedAt` | timestamp | |

**There is deliberately no member list, and there must never be one.** The
research protocol commits to aggregation at squad level; a field holding
identities here would break that commitment at the database layer no matter
what the app does.

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

## `organisations/{orgId}/settings/scoringWeights`

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

## What is deliberately absent

No collection anywhere holds per-developer activity. There is no
`users/{uid}/commits`, no `contributions`, no `activity` keyed by person.

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
- `settings` is the one thing a team may write, so weights can be tuned
