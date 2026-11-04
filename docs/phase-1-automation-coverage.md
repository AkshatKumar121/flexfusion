# FlexFusion V1 — Phase 1 automation coverage

Branch: flexfusion_v1

## CI command

~~~bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --coverage --reporter expanded
~~~

The GitHub Actions workflow runs analyzer and all Flutter unit/widget/quality tests on pushes and pull requests to flexfusion_v1, then uploads LCOV coverage. The iOS simulator build and integration smoke test are opt-in and are not part of ordinary Linux CI.

## Automated scenario inventory

| Feature area | Automated coverage in repository | Remaining verification |
|---|---|---|
| SQLite schema and upgrades | Fresh schema, supported v1–v6 upgrade paths, schema version, indexes/foreign keys, legacy meal migration/idempotence | Upgrade a real installed app while retaining its on-device data |
| Eat / food diary | Custom and built-in catalogue separation, custom food upsert, food log create/edit/delete, macro aggregation, meal ordering, date isolation, persistence, empty-day nutrition targets | Food picker search, quantity form validation, picker cancellation and screen-level date-switch race |
| Nutrition streak | Empty-day configured targets and existing streak database cases | Full streak UI boundary matrix and historical target-change behaviour |
| Profile / settings | Profile and target persistence, settings upsert, weight capture through profile flow | Profile form validation, unit conversion controls, settings navigation and placeholder visibility |
| Weight / progress photos | Same-date weight upsert, latest/recent weight, photo date-angle uniqueness, replacement path, list limit, deletion, persistence | Camera/gallery picker, filesystem failure/recovery and photo-permission denial on device |
| Activity | Manual create/edit/delete, date isolation, Health summary upsert/partial metrics, configured step threshold and manual step aggregation | Activity form widget validation, HealthKit permission/revocation, async sync/date race and platform fallback |
| Workout plans | Create/update/delete, active-plan uniqueness, day/exercise/target edits, plan duplication, substitution, sequence/weekday selection, cascade cleanup | Plan editor and exercise library search/dialog interaction widgets |
| Workout sessions | Free/planned session, one-active-session rule, set persistence, completion summary/volume, pause/resume, rest-end persistence/cleanup, abandonment, history, exercise history | Keyboard behaviour, background timer notifications, confirmation dialogs and real lifecycle transitions |
| Workout analysis | Date-window query, abandoned-session inclusion policy, Epley, unit conversion, intensity and progression calculator tests | Analysis screen rendering, chart/card values and navigation to exercise history |
| Home / navigation | Database aggregation consumed by Home and weekly progress; brand header widget test | Full dashboard refresh, bottom-tab routing, screen-to-screen navigation and visual responsive checks |
| Data resilience | SQLite reopen, mixed workflows, foreign-key integrity, catalogue seed idempotence | Low-storage, abrupt process termination and physical filesystem failure injection |

## Platform-only / manual scenarios

These cannot be fully validated by Linux flutter test with SQLite FFI:

- iOS HealthKit permission prompt, authorization state, revoked access, real daily metrics and background refresh.
- Camera and photo-library permissions, image picker behaviour, local file copying/deletion and storage errors.
- Notification permission and delivery while the app is backgrounded or the phone is locked.
- iOS simulator/physical iPhone build, signing, install, launch and lifecycle behaviour.
- Android build, install and manual activity fallback.
- Screen reader, device text scaling, keyboard/IME and physical small-screen layout.

## Exit criteria

Phase 1 automation is considered green only when:
1. flutter analyze --no-pub passes.
2. flutter test --no-pub --coverage --reporter expanded passes with zero failures.
3. The CI run for the exact Phase 1 test commit is successful.
4. Device-only scenarios above are recorded separately as manual/device verification; they must not be represented as covered by Linux CI.

A passing database test is not evidence that a corresponding screen interaction or operating-system permission flow has been tested.