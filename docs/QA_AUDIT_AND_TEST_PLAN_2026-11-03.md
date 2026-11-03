# FlexFusion V1 — Repository Audit & QA Test Plan

**Date:** 2026-11-03  
**Branch:** `flexfusion_v1`  
**Audit scope:** Current repository tree and application source at the branch head used for this review.  
**Status:** Static source review documented; user reported the full automated test run passed (20/20) on 2026-11-03. Runtime/build verification and device testing remain pending.

---

## 1. Audit summary

### Review coverage

- [x] Repository structure and Flutter entry point
- [x] App shell and bottom-tab navigation
- [x] Home dashboard and weekly progress
- [x] Eat, food logging and nutrition streak
- [x] Train, body weight, progress photos and training streak
- [x] Workout plans, exercise library, workout session and history
- [x] Activity logging and Apple Health integration
- [x] Profile, nutrition targets and settings
- [x] SQLite schema, CRUD methods, indexes and upgrade path
- [x] Dependencies, lint configuration and iOS/Android declarations
- [x] Existing automated test inventory
- [ ] Run `flutter pub get`
- [x] Run `flutter analyze` — passed 2026-11-03, no issues found.
- [x] Run `flutter test` — user reported all 20 tests passed on 2026-11-03.
- [x] iOS debug build — passed 2026-11-03 with `--no-codesign`; physical-device launch/signing still pending.
- [ ] Build and launch on a physical iPhone
- [ ] Physical-device HealthKit permission/sync verification
- [ ] Android build/device verification

A source review is not a substitute for executing the app. No Flutter/Dart runtime or physical device was available during this repository review, so no build, analyzer or test result is claimed.

---

## 2. Static audit findings

Severity definitions: **P0** = release blocker/data-loss risk; **P1** = major functional issue; **P2** = moderate issue or reliability gap; **P3** = minor polish/maintainability.

| ID | Severity | Area | Finding | Recommended action |
|---|---|---|---|---|
| AUD-001 | P1 | Eat / Nutrition streak | **Confirmed by user reproduction:** with configured targets of 1,800 kcal / 150 g protein and no food logs today, the streak screen displayed 2,200 kcal / 180 g. | Fixed by returning a zero-value current-day streak row with effective saved targets even when no food logs exist; regression test added. **Retest passed — user confirmed targeted regression test and screen behaviour.** |
| AUD-002 | P1 | Activity / Apple Health | **Confirmed by source review:** Health sync used mutable `_date` after awaiting HealthKit, allowing a date change during sync to save the result under the wrong day. | Fixed by capturing the requested date/key before the async read, persisting only under that key, allowing a new date's sync to supersede stale UI updates, and guarding refresh results. Awaiting user retest. |
| AUD-003 | P1 | Settings | “Reset App Data” was presented in Settings but did not actually reset data. | **Mitigated:** removed the incomplete destructive action from Settings until a complete, tested reset can safely clear database records and local progress-photo files. Reset is not currently offered in V1. Verify it is absent on device. |
| AUD-004 | P1 / migration risk | SQLite migration | The version upgrade path could alter `workouts` before ensuring the table exists on older installations. | **Addressed by migration fixes and coverage:** user confirmed v1→v6 through v5→v6 upgrade tests passed; see DB-003 and RUN-010. |
| AUD-005 | P2 | Training streak | The streak used a fixed 10,000-step threshold and did not expose the configured goal in Profile. | **Fix committed:** Profile → Daily Targets now lets the user edit the daily step goal (default 10,000); the Training Streak uses that saved value for goal checks, progress and labels. A day counts when a workout is completed OR the step goal is reached. A manual activity log by itself does not qualify. Automated DB tests cover the default and a custom threshold; awaiting user test run. |
| AUD-006 | P2 | Activity form | Numeric inputs previously used `tryParse` with fallback values, allowing malformed text to be treated as zero/null. | **Fix committed:** non-empty malformed duration, distance, steps and active-calorie values now show field-specific validation messages; blank optional fields remain allowed; negative and non-finite decimal values are rejected. Awaiting user retest. |
| AUD-007 | P2 | Apple Health | HealthKit errors were caught and converted to `null`, making permission, unsupported-platform and data-read failures indistinguishable. | **Fix committed:** service requests authorization only once per installation, persists that attempt, avoids repeatedly triggering the authorization flow on later Activity opens, and shows Health app instructions if the request is not granted. It continues attempting reads on later opens because iOS does not disclose read-denial state; an empty result is explicitly described as either no returned data or access needing review. Safe diagnostic logging and visible sync status are included. Awaiting analyzer, automated tests and iPhone retest. |
| AUD-008 | P2 | Automated tests | The repository currently has database-focused tests, but no visible widget/integration tests for the main screens, workout flows, HealthKit behavior or navigation. | Add widget tests for critical flows and integration/device test coverage for plugins and platform permissions. |
| AUD-009 | P2 | Database tests | Fresh-schema test expected schema version 4 although the application schema is version 6. | **Fixed:** assertion updated to version 6; included in the user-reported 20/20 passing automated test run. |
| AUD-010 | P1 | Database migration | Version-2 upgrade previously failed with `no such table: workouts` during the v6 migration. | **Fixed and retested:** migration order/guards updated; v1→v6 through v5→v6 tests passed, and the user reports 20/20 automated tests passing. |

### Audit notes / risks to verify

- HealthKit read permissions and returned data vary by iOS device, user permission state, data source and date range. Verify on a real iPhone; simulator/source review is insufficient.
- The current Activity summary uses Apple Health values when a positive value exists and falls back to manual values otherwise. Confirm the expected behavior for partial HealthKit data and mixed manual/HealthKit entries to avoid misleading totals or accidental double counting.
- The workout timer, pause/resume, session completion and nested route-pop behavior need real interaction testing, including backgrounding/locking the phone.
- Progress-photo deletion removes both the database record and local file. Verify failure recovery and that deleting one date/angle never removes another photo.
- Settings includes placeholder/not-ready actions. Inventory every visible settings row during manual testing and make sure no unfinished action appears operational.
- The app is local-first. Verify persistence after force-close/relaunch and explicitly test upgrade-in-place. Do not delete the installed app during QA unless local data has been backed up.
- Review package compatibility and platform signing/capabilities during builds. HealthKit requires a correctly configured Apple Developer capability and provisioning profile.
- The lint configuration excludes platform folders from Dart analysis; native iOS/Android configuration still needs build-level verification.

---

## 3. Feature inventory and manual test checklist

Mark each case **Pass**, **Fail**, **Blocked** or **Not applicable** during device testing. Record the device/OS, app commit, test date and evidence for every failure.

### A. App launch, shell and navigation

Implemented areas:
- Three primary tabs: Train, Home and Eat.
- Indexed-stack navigation and refresh callbacks when switching tabs.
- Activity screen opened from the Home Log Activity card.
- Profile/settings routes from Home.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| APP-001 | Fresh launch after install | App opens without crash; correct initial tab and branding display. | [ ] |
| APP-002 | Switch Train → Home → Eat repeatedly | Correct screen appears; no blank screen, stale overlay or crash. | [ ] |
| APP-003 | Switch tabs after adding data | Each screen refreshes and shows the latest saved data. | [ ] |
| APP-004 | Open Activity from Home | Activity screen opens; Back returns to Home. | [ ] |
| APP-005 | Open Profile and Settings, then Back | Navigation stack returns to the expected screen without resetting unrelated tab state. | [ ] |
| APP-006 | Rotate device / change text scale where supported | Layout remains usable; no clipped critical controls. | [ ] |
| APP-007 | Force-close and relaunch | Local data remains available. | [ ] |
| APP-008 | Rapidly tap tabs/actions | No duplicate routes, crashes or inconsistent selected-tab state. | [ ] |

### B. Home dashboard

Implemented areas:
- Dashboard cards and daily nutrition summary.
- Workout entry point.
- Log Activity entry point.
- Weekly progress and profile/settings navigation.
- Pull-to-refresh.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| HOME-001 | Open Home with an empty database | Empty/default states render without exceptions or misleading totals. | [ ] |
| HOME-002 | Log food, return Home | Calories/macros reflect the latest Eat logs. | [ ] |
| HOME-003 | Complete a workout, return Home | Workout/weekly progress reflects the completed session. | [ ] |
| HOME-004 | Pull to refresh | Indicator remains visible until dashboard data refresh completes. | [ ] |
| HOME-005 | Tap Eat dashboard card | Navigates to Eat and shows current day's food data. | [ ] |
| HOME-006 | Tap workout card | Opens workout launcher; Back returns to Home. | [ ] |
| HOME-007 | Tap Log Activity | Opens Activity screen. | [ ] |
| HOME-008 | Open weekly progress | Correct date range and metrics display; Back works. | [ ] |
| HOME-009 | Test day boundary / midnight | Date and dashboard metrics roll over to the new local day. | [ ] |
| HOME-010 | Test with large/small screen and text scale | Cards remain aligned and readable. | [ ] |

### C. Eat — food diary and nutrition calculations

Implemented areas:
- Date selector and daily meal groups.
- Food search/catalogue and custom food flow.
- Add/edit/delete food logs and quantity-based nutrition calculations.
- Daily calorie and macro summaries.
- Nutrition target values sourced from Profile.
- Eat header streak shortcut.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| EAT-001 | Open Eat with no logs | Empty meal states and zero totals render correctly. | [ ] |
| EAT-002 | Change date to a past date | Only that date's logs and totals display. | [ ] |
| EAT-003 | Attempt to select a future date | Future date is unavailable. | [ ] |
| EAT-004 | Search built-in food by full/partial name | Relevant results appear; no-result state is clear. | [ ] |
| EAT-005 | Add food to each meal | Entry appears under the selected meal and totals update. | [ ] |
| EAT-006 | Change quantity/grams | Calories, protein, carbs and fat scale correctly. | [ ] |
| EAT-007 | Edit an existing food log | Updated quantity and totals persist after refresh/relaunch. | [ ] |
| EAT-008 | Delete a food log | Entry disappears and all totals recalculate. | [ ] |
| EAT-009 | Create a custom food | Food saves and can be searched/logged later. | [ ] |
| EAT-010 | Enter zero, decimal, blank and invalid quantity | Validation prevents invalid values; no silent incorrect totals. | [ ] |
| EAT-011 | Add same food more than once | Entries are handled consistently and totals include each intended entry. | [ ] |
| EAT-012 | Change nutrition targets in Profile | Eat targets and progress update without requiring reinstall. | [ ] |
| EAT-013 | Pull to refresh | Data reload completes and indicator stops. | [ ] |
| EAT-014 | Navigate away/back and force-close/relaunch | Selected date behavior is understood; saved logs persist. | [ ] |

### D. Eat — Nutrition Streak

Rule: a day counts only if total logged calories are within **target − 100 kcal to target + 100 kcal inclusive**, and total protein is **at least the protein target**.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| NUT-001 | Tap flame from Eat | Nutrition Streak screen opens, not Workout/Activity Streak. | [ ] |
| NUT-002 | Calories exactly target − 100 and protein exactly target | Day qualifies. | [ ] |
| NUT-003 | Calories exactly target + 100 and protein above target | Day qualifies. | [ ] |
| NUT-004 | Calories target − 101 | Day does not qualify. | [ ] |
| NUT-005 | Calories target + 101 | Day does not qualify. | [ ] |
| NUT-006 | Calories in range but protein one gram below target | Day does not qualify. | [ ] |
| NUT-007 | Protein meets target but calories out of range | Day does not qualify. | [ ] |
| NUT-008 | No food logged today and custom targets configured | Current configured targets display; streak does not qualify. | [ ] |
| NUT-009 | Change targets mid-history | Each historical day is evaluated against the target effective on that date. | [ ] |
| NUT-010 | Qualify several consecutive days | Streak count increments correctly. | [ ] |
| NUT-011 | Miss yesterday, qualify today | Streak is one day, not a continuation of the old streak. | [ ] |
| NUT-012 | Today not yet qualified, yesterday qualified | Current streak remains based on the last completed qualifying day, per agreed streak convention. | [ ] |
| NUT-013 | Edit/delete today's food after qualifying | Today's status and streak recalculate when screen is reopened/refreshed. | [ ] |
| NUT-014 | Week boundary (Sunday/Monday) | Weekday indicators align to correct calendar dates. | [ ] |

### E. Train — weight, progress photos and dashboard

Implemented areas:
- Date selector matching Eat.
- Daily body-weight logger.
- Progress photos for Front, Side and Back.
- Photo timeline and delete confirmation.
- Weekly workout progress, workout tools and refresh.
- Training streak shortcut.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| TRN-001 | Open Train with no weight/photos/workouts | Empty states render without crash. | [ ] |
| TRN-002 | Select a past date and save weight | Weight is stored against selected date. | [ ] |
| TRN-003 | Save weight twice for same date | Existing date entry updates rather than creating conflicting duplicates. | [ ] |
| TRN-004 | Enter zero, negative, alphabetic and very large weight | Invalid/out-of-range values are rejected safely. | [ ] |
| TRN-005 | Switch kg/lb if supported | Display and saved canonical value remain correct. | [ ] |
| TRN-006 | Add Front, Side and Back photos | Correct angle/date association and local file display. | [ ] |
| TRN-007 | Add another photo for same date/angle | Existing-photo replacement behavior is clear and safe. | [ ] |
| TRN-008 | Delete one photo and confirm | Only selected photo and file are removed. | [ ] |
| TRN-009 | Cancel photo deletion | Photo remains. | [ ] |
| TRN-010 | Deny camera/photo permission | User receives a clear fallback/error; app does not crash. | [ ] |
| TRN-011 | Pull to refresh | Refresh indicator remains until data load completes. | [ ] |
| TRN-012 | Tap streak flame | Workout & Activity Streak screen opens. | [ ] |
| TRN-013 | Verify header/divider spacing and date selector | Branding remains left-aligned; divider and selector do not overlap. | [ ] |

### F. Train — Workout plans and exercise library

Implemented areas:
- Create/manage plans and plan days.
- Sequence/weekday scheduling and rest days.
- Add, search, edit, substitute and remove exercises.
- Exercise catalogue seeded from bundled JSON; custom exercises.
- Built-in exercises are protected from deletion.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| PLAN-001 | Create a plan with valid name | Plan saves and appears in plan list. | [ ] |
| PLAN-002 | Save blank/whitespace plan name | Validation prevents invalid plan. | [ ] |
| PLAN-003 | Add/edit/delete plan day | Correct day changes persist. | [ ] |
| PLAN-004 | Configure weekday schedule | Correct weekday is shown and selected. | [ ] |
| PLAN-005 | Configure sequence schedule | Next plan day advances in correct sequence. | [ ] |
| PLAN-006 | Mark rest day and log it | Rest day advances sequence without starting a workout. | [ ] |
| PLAN-007 | Add exercises to a day | Exercise order and selected exercises persist. | [ ] |
| PLAN-008 | Search exercise by name | Matching exercises appear. | [ ] |
| PLAN-009 | Search by muscle group/equipment/instructions | Matching catalogue entries appear. | [ ] |
| PLAN-010 | Search with no matches / clear search | Empty state and reset work correctly. | [ ] |
| PLAN-011 | Edit sets, reps, weight and rest | Values persist and display correctly. | [ ] |
| PLAN-012 | Substitute/remove an exercise | Correct exercise changes; no unrelated day is altered. | [ ] |
| PLAN-013 | Attempt to delete built-in exercise | Built-in catalogue entry remains protected. | [ ] |
| PLAN-014 | Add/edit/delete custom exercise | Custom entry behaves correctly and can be deleted. | [ ] |
| PLAN-015 | Reopen app after first catalogue seed | No duplicate built-in exercises are created. | [ ] |
| PLAN-016 | Delete plan with child days/exercises | Related records are handled according to intended cascade behavior. | [ ] |

### G. Workout launcher, session, timer and history

Implemented areas:
- Start planned workout or free workout.
- Resume existing in-progress workout; prevent duplicate active sessions.
- Add exercises and log set reps/weights/completion.
- Rest timer and workout duration timer.
- Pause/resume workout and finish confirmation.
- Completed workout history.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| WKO-001 | Start planned workout | One in-progress session is created with correct plan/day. | [ ] |
| WKO-002 | Start free workout | Session starts with supplied name. | [ ] |
| WKO-003 | Start another workout while one is active | Duplicate active session is blocked; Resume is offered. | [ ] |
| WKO-004 | Resume active workout | Same session, sets and timer continue. | [ ] |
| WKO-005 | Add exercise during session | Exercise and sets appear in active workout. | [ ] |
| WKO-006 | Log reps and weight for each set | Values persist after leaving/reopening session. | [ ] |
| WKO-007 | Mark sets complete/incomplete | Completion state is correct. | [ ] |
| WKO-008 | Enter invalid reps/weight | Validation prevents malformed values. | [ ] |
| WKO-009 | Start rest timer | Countdown reaches zero and stops. | [ ] |
| WKO-010 | Pause and resume workout | Elapsed duration excludes paused time. | [ ] |
| WKO-011 | Background/lock phone during workout | Timer resumes with correct elapsed time; no duplicate timer. | [ ] |
| WKO-012 | Finish workout and cancel confirmation | Session remains in progress. | [ ] |
| WKO-013 | Finish workout and confirm | Session becomes completed and appears once in history. | [ ] |
| WKO-014 | Finish with incomplete/empty sets | App behavior matches agreed policy; no silent data loss. | [ ] |
| WKO-015 | Open workout history | Completed sessions sort newest first and show correct details. | [ ] |
| WKO-016 | Return from history/session to Train | Dashboard refreshes completed workout metrics. | [ ] |
| WKO-017 | Force-close during active workout and relaunch | Active session can be resumed with timer/state intact. | [ ] |

### H. Workout & Activity Streak

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| STR-001 | Open streak from Train | Streak screen displays. | [ ] |
| STR-002 | Complete a workout today | Today is marked complete and streak updates. | [ ] |
| STR-003 | Log a manual activity today | Today is marked complete and streak updates. | [ ] |
| STR-004 | Have both workout and activity on same day | Day counts once, not twice. | [ ] |
| STR-005 | Set a custom step goal in Profile → Daily Targets, then sync HealthKit steps | Streak goal/progress label reflects the saved target; reaching it counts, falling short does not. | [ ] |
| STR-006 | Have manual steps reach the configured goal across multiple logs | Day counts once summed manual steps reach the saved goal. | [ ] |
| STR-007 | Complete a workout below the step goal | Day still counts as active. | [ ] |
| STR-008 | Log a manual activity without reaching the step goal or completing a workout | Day does not count as active. | [ ] |
| STR-009 | Consecutive workout/step-goal days | Streak increments once per calendar day. | [ ] |
| STR-009 | Miss a day | Streak resets according to last completed day convention. | [ ] |
| STR-010 | Cross Sunday/Monday | Weekday row and dates align correctly. | [ ] |
| STR-011 | No Health permissions/data | Screen still works and manual data remains available. | [ ] |

### I. Activity — manual logging and Apple Health

Implemented areas:
- Daily steps, active minutes, distance and active calories.
- Manual activity entry for walking, running, cycling, swimming, hiking, yoga/mobility, sports and Other.
- Edit/delete manual entries and history.
- Apple Health read-only daily summary on iOS; manual fallback.
- Date selector and sync action.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| ACT-001 | Open Activity with no data | Zero/empty states display without crash. | [ ] |
| ACT-002 | Log each activity type | Entry saves with correct type/date/time. | [ ] |
| ACT-003 | Save duration only | Valid entry appears and totals update. | [ ] |
| ACT-004 | Save distance/steps/calories | Optional metrics save and aggregate correctly. | [ ] |
| ACT-005 | Enter malformed numeric values | Field validation rejects invalid text. | [ ] |
| ACT-006 | Enter negative values | Validation rejects negatives. | [ ] |
| ACT-007 | Save an entry with all metrics blank/zero | Validation prevents meaningless entry. | [ ] |
| ACT-008 | Edit activity | Original entry updates; no duplicate created. | [ ] |
| ACT-009 | Delete activity and cancel/confirm | Cancel preserves; confirm deletes only selected entry. | [ ] |
| ACT-010 | Select past date | Correct day's logs and summaries display. | [ ] |
| ACT-011 | Pull to refresh / tap Health sync | Refresh/sync state is accurate and finishes. | [ ] |
| ACT-012 | Grant HealthKit read permissions | Steps, distance, active energy and exercise minutes are read correctly. | [ ] |
| ACT-013 | Deny HealthKit permissions | Manual tracking remains usable; clear status is shown. | [ ] |
| ACT-014 | Revoke HealthKit permission in Settings | App handles revoked permission without crash. | [ ] |
| ACT-015 | No HealthKit data for selected day | Manual fallback displays. | [ ] |
| ACT-016 | Partial HealthKit metrics only | Each metric fallback behaves as intended; no double counting. | [ ] |
| ACT-017 | Change selected date during sync | Data is saved only against the date actually queried. | [ ] |
| ACT-018 | Test Android/non-iOS | Manual activity logging works; HealthKit is not invoked. | [ ] |
| ACT-019 | Force-close/relaunch | Manual activity history persists. | [ ] |

### J. Profile, targets and settings

Implemented areas:
- Profile details, height/weight display and units.
- Nutrition targets (calories, protein, carbs and fat).
- Goal selection and profile persistence.
- Settings page with reset-data placeholder.

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| PRO-001 | Open Profile with empty profile | Empty/default state renders safely. | [ ] |
| PRO-002 | Save profile details | Values persist after reload. | [ ] |
| PRO-003 | Edit height/weight and switch units | Conversion and display are correct. | [ ] |
| PRO-004 | Enter invalid age/height/weight | Validation prevents invalid profile values. | [ ] |
| PRO-005 | Save calorie/protein/carbs/fat targets | Targets persist and update Eat calculations. | [ ] |
| PRO-006 | Enter zero, negative, blank and malformed targets | Validation prevents invalid targets. | [ ] |
| PRO-007 | Change goal | Selected goal persists and dashboard/profile reflects it. | [ ] |
| SET-001 | Open Settings | All visible actions and labels match actual implementation. | [ ] |
| SET-002 | Tap placeholder settings rows | No misleading success or destructive behavior. | [ ] |
| SET-003 | Tap Reset App Data and cancel | All local data remains unchanged. | [ ] |
| SET-004 | Inspect Data Management in Settings | Reset App Data is not shown until a safe reset workflow is implemented; Export/Restore remain clearly identified as unavailable placeholders. | [ ] |
| SET-005 | Verify settings persistence after relaunch | Saved settings remain correct. | [ ] |

### K. Database, persistence and migration

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| DB-001 | Fresh database creation | All expected tables/indexes are created and `PRAGMA user_version` equals the current schema version (6). | **Pass — included in user-reported 20/20 automated test run.** |
| DB-002 | Upgrade a v5 database to v6 | Pause fields are added and existing records remain. | **Pass — user confirmed targeted fresh-schema and v5→v6 migration tests.** |
| DB-003 | Upgrade each supported older schema version | Migration completes without missing-table/duplicate-column errors. | **Pass — v1→v6, v2→v6, v3→v6, v4→v6 and v5→v6 targeted migration tests passed; included in user-reported 20/20 automated test run.** |
| DB-004 | Force-close during writes | Database remains consistent on next launch. | [ ] |
| DB-005 | Insert/update/delete each entity | Correct rows are changed; no orphan records. | [ ] |
| DB-006 | Verify foreign-key cascade/set-null behavior | Related records follow documented rules. | [ ] |
| DB-007 | Seed food/exercise catalogues twice | No duplicate seed rows. | [ ] |
| DB-008 | Reinstall/upgrade-in-place | Existing local data is preserved on app update. | [ ] |
| DB-009 | Low storage / file deletion failure | Clear error/recovery behavior; DB and local files do not silently diverge. | [ ] |
| DB-010 | Large food catalogue search | Search remains responsive and correct. | [ ] |

### L. Platform, permissions, accessibility and resilience

| ID | Test case | Expected result | Status / notes |
|---|---|---|---|
| SYS-001 | iOS debug build | Build succeeds with HealthKit entitlement and valid signing configuration. | [ ] |
| SYS-002 | iOS release build | Release build/archive succeeds. | [ ] |
| SYS-003 | Android debug/release build | Build succeeds; manual Activity works. | [ ] |
| SYS-004 | Camera permission denied/re-enabled | Progress photo flow recovers gracefully. | [ ] |
| SYS-005 | Health permission denied/re-enabled | Activity sync handles permission changes. | [ ] |
| SYS-006 | App background/foreground | No stale state, timer duplication or crash. | [ ] |
| SYS-007 | Network unavailable | Core local-first functions continue working; font loading has acceptable fallback. | [ ] |
| SYS-008 | Small screen / large text | Buttons, dialogs and bottom sheets remain accessible. | [ ] |
| SYS-009 | Keyboard open in forms | Fields and Save buttons remain reachable. | [ ] |
| SYS-010 | Accessibility labels / screen reader | Important icon-only actions have meaningful labels/tooltips. | [ ] |

---

## 4. Test execution log

Use one row per test run. Link screenshots/videos or note the evidence filename.

| Run ID | Date/time | App commit | Device / OS | Test IDs | Pass | Fail | Blocked | Notes / evidence |
|---|---|---|---|---|---:|---:|---:|---|
| RUN-001 | 2026-11-03 | Local branch commit not supplied | Mac (Flutter test / sqflite FFI) | Database suite | 9 | 2 | 0 | Failed: stale schema-version assertion (expected 4, actual 6); v2→current migration fails because `workouts` table is missing during v6 ALTER TABLE. Full output supplied in chat. |
| RUN-002 | 2026-11-03 | Local branch commit not supplied | Mac | `flutter analyze` | 1 | 0 | 0 | Passed: “No issues found!” (1.9s). |
| RUN-003 | 2026-11-03 | Local branch commit not supplied | Mac / iOS device target | `flutter build ios --debug --no-codesign` | 1 | 0 | 0 | Passed: Xcode build completed and `build/ios/iphoneos/Runner.app` was produced. Codesigning was disabled; physical-device install/launch and signing remain unverified. |
| RUN-004 | 2026-11-03 | `flexfusion_v1` before `d8efaba` | Mac (Flutter test / sqflite FFI) | DB-001 fresh-schema test | 0 | 1 | 0 | Reproduced stale test assertion: expected schema version 4, actual 6. Test title and assertion corrected in `d8efaba`; retest pending. |
| RUN-005 | 2026-11-03 | `1a2e306` | Mac (Flutter test / sqflite FFI) | DB-002 v5→v6 migration and DB-001 fresh-schema retest | 2 | 0 | 0 | User confirmed both targeted tests passed after pulling the fix/test commits. |
| RUN-006 | 2026-11-03 | `42c008a` | Mac (Flutter test / sqflite FFI) | DB-003 v4→v6 migration | 1 | 0 | 0 | User confirmed targeted v4→v6 migration test passed; activity tables and pause columns were created while existing workout data was preserved. |
| RUN-007 | 2026-11-03 | `609b314` | Mac (Flutter test / sqflite FFI) | DB-003 v3→v6 migration | 1 | 0 | 0 | User confirmed targeted v3→v6 migration test passed. |
| RUN-008 | 2026-11-03 | `1b756fcd` | Mac (Flutter test / sqflite FFI) | DB-003 v1→v6 migration | 1 | 0 | 0 | User confirmed targeted v1→v6 migration test passed; existing food/log data and all migrated schema modules verified. |
| RUN-009 | 2026-11-03 | `e6497b1` | Mac (Flutter test / sqflite FFI) | AUD-001 empty-day nutrition targets regression test | 1 | 0 | 0 | User confirmed targeted test passed after pulling the fix. |
| RUN-010 | 2026-11-03 | `flexfusion_v1` (exact commit not supplied) | Mac (Flutter test) | Full automated test suite | 20 | 0 | 0 | User reported all 20 tests passed. Exact terminal command and commit SHA were not supplied; device/manual QA remains pending. |

## 5. Bug / issue register

Create one record for every failure. Do not combine unrelated bugs.

| Bug ID | Severity | Screen / area | Steps to reproduce | Expected | Actual | Evidence | Status | Fix commit | Retest |
|---|---|---|---|---|---|---|---|---|---|
| BUG-004 | P1 | Activity / Apple Health sync date race | Start Health sync for one date, change selected date before sync completes | Health summary is saved only to the date queried; stale result must not overwrite the newly selected date's UI | Source confirmed mutable selected date was reused after await; sync now captures immutable date/key and guards stale refresh/sync responses | Fixed in source; awaiting user retest | `3fedb79` | Pending — user retest |
| BUG-003 | P1 | Nutrition streak uses fallback targets on empty current day | Configure targets different from 2,200 kcal / 180 g, leave today without food logs, open Eat → Nutrition Streak | Streak should show configured targets with zero logged intake | Reproduced by user; query now supplies today's row and effective targets even without logs; regression test added | Fixed / Retest passed | `079df09`, `e6497b1` | Pass — user confirmed targeted test and screen behaviour |
| BUG-001 | P1 | SQLite migration v2→v6 | Run targeted v2→v6 migration test using a temporary database | Migration completes and preserves existing food logs; workout schema is created/upgraded | Pre-fix: `no such table: workouts` while adding `paused_at`; after migration-order/column guards, targeted test passes | Terminal output 2026-11-03; user confirmed post-fix pass | Fixed / Retest passed | `5dac8c9` (migration), `69d1a8c` (test) | Pass — targeted test |
| BUG-002 | P2 | Database test expectation | Run `flutter test` on fresh database | Test expects current schema version 6 | Test expected 4; actual schema version is 6 | Terminal output 2026-11-03 | Fixed / Retest passed | `d8efaba` | Pass — user confirmed targeted test |

Severity guidance:
- **Blocker:** app cannot launch/use a core feature, data corruption/loss, security/privacy issue.
- **Critical:** major workflow unusable or wrong persistent data/calculation.
- **Major:** important feature partially broken with workaround.
- **Minor:** cosmetic or low-impact behavior.

## 6. Recommended QA additions

1. Add automated widget tests for navigation, empty states, forms, nutrition calculations and streak boundaries.
2. Add migration tests for every historical schema version, not just the latest database schema.
3. Add deterministic test fixtures and an injectable clock so date-boundary and streak tests do not depend on the real current date.
4. Add a visible backup/export and restore workflow before any destructive reset or uninstall-based testing.
5. Add crash/error diagnostics that avoid collecting sensitive health or personal data.
6. Add a repeatable iOS release build and Android build to CI, plus analyzer and test commands.
7. Add a release checklist: version/build number, permissions/privacy text, app icon/splash, signing, backup, changelog and rollback plan.
8. Keep test data separate from real personal logs; never use destructive reset on the primary device without a verified backup.

## 7. Exit criteria

QA is complete only when:
- All P0/P1 issues are fixed and retested.
- Every applicable test case is Pass or has an explicitly accepted known limitation.
- No unexplained analyzer errors or test failures remain.
- iOS build and target-device smoke tests pass.
- Android build is verified if Android is a supported V1 target.
- Data migration, persistence and backup/restore risks are documented.
- Final regression run is recorded against the exact release commit.
