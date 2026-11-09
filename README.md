# PRAHM

Project Resource and Health Monitor. A Flutter application that reports how
software projects are doing, using data the teams already produce rather than
status somebody types into a form.

A scheduled job reads the repositories and trackers a squad already uses,
aggregates everything to squad level, and scores each project out of 100
against five weighted indicators. The application shows the score, the five
figures behind it, the reason each one holds the value it does, and a banded
history of how it has moved.

Built for module ITDMA3-B22 at Eduvos by group SE1.

## What it will not do

Most of the design follows from these. They came from a research protocol with
an ethics commitment, so a change that breaks one is a defect, not a
preference.

1. **No individual is measured.** No per-person metric is stored, scored or
   displayed. A squad below the anonymity threshold produces no metrics at all.
2. **Load-shedding hours are reported, never deducted.** An infrastructure
   failure is shown beside the figures, not quietly subtracted from them.
3. **Monitoring data is read-only to clients.** The application has no write
   path to a score. Plans go to `projectPlans`; ingestion builds the scored
   `projects` document from them.
4. **No manual status entry.** If a number cannot be measured, it is absent.
5. **The assistant sends squad-level data only.**
6. **Status is never colour alone.** Every band carries a word, and the history
   strip describes its trend to a screen reader.

## Start here

**[ARCHITECTURE.md](ARCHITECTURE.md)** is the orientation document: the
constraints in full, the scoring model, the current state of each feature, and
a record of which contributed features were merged, rebuilt or declined and
why. Read it before changing anything that touches individual data, scoring
arithmetic or security rules.

## Running it

### Requirements

- Flutter 3.47 or later, Dart SDK ^3.12.2
- A Firebase project with Authentication and Cloud Firestore
- An Android device or emulator (iOS is configured but has never been built)

### Setup

```bash
flutter pub get
flutter run
```

Firebase configuration is not in the repository. You need your own
`android/app/google-services.json`, and the Android `applicationId`,
the iOS bundle id and the `package_name` inside that file must agree, or
Authentication and Firestore will both fail.

> The application id is still `za.co.diego.keel`, from before the project was
> renamed. Firebase matches the running app against that string, so changing
> it means re-registering the app and downloading a fresh
> `google-services.json`. It is invisible to users. See ARCHITECTURE.md.

### Tests

```bash
flutter test      # 363 tests
flutter analyze   # must be clean before committing
```

The suite is split so a failure says something:

| Layer | What it covers |
| --- | --- |
| `test/pure` | Scoring, ingestion and parsing logic, with no Flutter dependency |
| `test/unit` | Repositories, notifiers, models, validation, the anonymiser |
| `test/widget` | Individual screens driven: taps, entry, dialogs, error and empty states |
| `test/integration` | Whole flows across several screens |

Screens never import `cloud_firestore`. Everything goes through a repository
interface, which is why the suite runs with no network and no emulator.

## Ingestion

`tool/ingest.dart` is the scheduled run, normally invoked by
`.github/workflows/ingest.yml`. Everything it needs comes from the
environment, because all of it is either a credential or a mapping that must
not be committed:

| Variable | Purpose |
| --- | --- |
| `FIREBASE_SERVICE_ACCOUNT` | The service-account JSON key |
| `KEEL_SOURCE_TOKENS` | `{"sourceId": "token", ...}` |
| `KEEL_ORG_ID` | Defaults to `demo-org` |
| `KEEL_WINDOW_HOURS` | Defaults to 336 (fourteen days) |
| `KEEL_SQUAD_OF_AUTHOR` | Optional, and better left unset |

These are GitHub repository secrets of the same names. Renaming one in code
without renaming the secret leaves ingestion running with no tokens and no
error.

To try it against real data without writing anything:

```bash
dart run tool/ingest.dart --dry-run
```

## Security rules

`firestore.rules` is a second, independent gate rather than a copy of the
checks in the application. Validate before publishing:

```bash
firebase deploy --only firestore:rules --dry-run
```

Two things worth knowing before editing it. An update is a merge, so
`request.resource.data` is the whole post-write document rather than the
fields being changed. And a function must be declared before the `allow`
statements that use it.

## Layout

```
lib/
  data/        Repository interfaces, Firestore implementations, in-memory fakes
  models/      Domain types and validation rules
  screens/     UI, one folder or file per screen
  state/       Riverpod providers
  routing/     Routes and the router
  scoring/     The scoring engine, no Flutter dependency
test/          pure / unit / widget / integration
tool/          Ingestion and maintenance scripts
```

## Status

363 tests passing, `flutter analyze` clean. Ten defects found during the test
phase and all ten resolved, each with a test that failed before the change.
Runs on a physical Android handset against live Firebase.

Not done: iOS has never been built, performance under load is untested, and
push notification delivery has never been captured on a device. The outstanding
list with reasons is at the end of ARCHITECTURE.md.
