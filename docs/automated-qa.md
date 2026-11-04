# FlexFusion Automated QA

## Purpose

This document tracks automated quality coverage for FlexFusion V1. Tests should verify user-visible behaviour, persisted data, calculations, and recovery paths. A passing test suite is evidence for the scenarios it executes; it is not a claim that every possible user action or device condition has been tested.

## Test layers

| Layer | Tooling | Responsibility |
| --- | --- | --- |
| Unit and calculation | `flutter_test` | Pure calculations, formatting, validation, trend and progression rules |
| Database and migration | `flutter_test` + `sqflite_common_ffi` | CRUD, constraints, migrations, aggregation, and persistence |
| Widget | `flutter_test` | Rendering, interaction, validation, loading, empty and error states |
| End-to-end | `integration_test` | Critical journeys through the running Flutter application |
| Resilience | Database/widget/integration tests | Restart, interruption, duplicate actions, invalid input and recovery |

## Current automated coverage

Existing suites:

- `test/data/local/app_database_test.dart`
- `test/data/local/workout_flow_test.dart`
- `test/data/local/progress_activity_test.dart`
- `test/widgets/flexfusion_brand_header_test.dart`
- `integration_test/app_smoke_test.dart`

New critical workflow suite:

- `test/quality/critical_workflows_test.dart`

The critical workflow suite verifies:
- Nutrition create/update/delete and dashboard macro aggregation.
- Workout plan to completed session, set volume, history and analysis rows.
- Weight and all three progress-photo angles surviving SQLite close/reopen.
- Weekly dashboard aggregation across nutrition, weight and completed workouts.
- Foreign-key integrity after mixed workout and nutrition operations.

## Scenario coverage matrix

| Feature | Automated scenarios | Remaining high-value work |
| --- | --- | --- |
| Train and plans | Plan creation, duplication, active session guard, session completion and history | Plan edit/delete UI journeys, empty states, malformed inputs |
| Workout session | Set completion, volume summary, pause/resume persistence, rest timer persistence/cleanup | App background/foreground and process termination recovery; rapid repeated actions |
| Workout analysis | Analysis data query window and set-level records | Assert calculation accuracy for volume, intensity and 7-day progressive-overload comparisons |
| Eat and nutrition | Food catalogue, custom food CRUD, food log CRUD, nutrition snapshots and macro aggregation | Full UI add/edit/delete journey, serving-unit conversion, target-boundary and empty states |
| Weight | Daily upsert and latest-weight retrieval | UI add/edit/delete, chart range boundaries and trend calculation correctness |
| Progress photos | Front/side/back records, same-angle replacement and deletion | UI capture/import permissions, missing-file handling, comparison and backup/restore |
| Activity | Manual activity CRUD, history window and health-summary upsert | UI validation and permission-denied paths |
| Dashboard | Weekly summary and streak data | Widget assertions for all dashboard states and date-boundary cases |
| Storage | Schema migration, legacy migration, foreign-key integrity, SQLite reopen | Backup/export/import and restore verification |

## Running tests locally

Run from the Flutter project root:

```bash
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter test --coverage --reporter expanded
```

Run the iOS end-to-end smoke test on an available simulator:

```bash
flutter test integration_test/app_smoke_test.dart -d <SIMULATOR_UDID> --reporter expanded
```

Coverage output is written to `coverage/lcov.info`.

## GitHub Actions

On every push or pull request to `flexfusion_v1`, CI runs:

1. `flutter analyze --no-pub`
2. All unit, database, widget and quality tests with LCOV coverage collection.
3. Uploads `coverage/lcov.info` as a 14-day workflow artifact, including when tests fail after producing coverage.

The hosted macOS iOS build and integration test remains an opt-in manual workflow input (`run_ios`) while hosted runner availability is investigated. The iOS simulator integration test has also been run successfully on the developer's Mac; local success and hosted CI success are tracked separately.

## Quality gates and interpretation

- Analyzer and automated tests must pass before merging feature work.
- A failed test must be investigated; do not weaken an assertion solely to obtain a green run.
- Do not report a scenario as covered unless an automated test actually exercises it.
- Add regression coverage for every confirmed defect.
- Keep test data isolated and deterministic; use temporary SQLite databases and avoid depending on personal production data.
- Review the scenario matrix when adding or changing a feature.
