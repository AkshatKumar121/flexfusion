# Food Catalogue Integration — Rollback and Recovery

## Scope

This change introduces the FlexFusion v1 food catalogue into the existing Eat flow. It does not replace the SQLite database, change the database schema version, delete user data, or rewrite historical food logs.

## Safety checkpoint

Before the integration commit, the working branch was preserved at:

- Branch: `backup/pre-food-catalog-integration-2026-11-02`
- Baseline commit: `cf3734349c597f329ed4653ea0375bca816a9b79`

Keep this branch. Do not delete it until the catalogue integration has been tested locally and accepted.

## Files changed

- `lib/data/local/app_database.dart` — adds an idempotent JSON-to-SQLite catalogue seed and a built-in-food query.
- `lib/features/eat/eat_screen.dart` — reads built-in foods from SQLite and keeps the previous small list as a fallback.
- `pubspec.yaml` — registers `assets/data/`.
- `assets/data/README.md` — explains the required seed asset.

## Required catalogue asset

Copy the downloaded `flexfusion_food_catalog_v1.json` into:

```
assets/data/flexfusion_food_catalog_v1.json
```

The app expects the compact integration JSON generated for this project. Each record must include:

- `food_id`
- `name`
- `calories_kcal`
- `protein_g`
- `carbs_g`
- `fats_g`
- optional `verification_status`

All nutrient values are per 100 g. Piece serving weights are not populated in this catalogue version, so the current food picker continues to log grams only. Piece-based logging must be enabled only after verified serving conversions are available.

## Seed behaviour

- The catalogue is inserted into the existing `foods` table.
- Built-in rows use `source = flexfusion_catalog_v1` and the source `food_id` in `source_id`.
- The seed runs in a SQLite transaction and records a completion marker only after a successful insert.
- Re-running the seed does not duplicate rows.
- A missing or malformed asset is caught and logged; it must not prevent the app database or existing user data from opening.
- Existing custom foods, meal logs, profiles, targets, weights, workouts and photos are not deleted or rewritten.

## Local validation

From the project root:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

In the app, open Eat → Add Food and search for a few catalogue entries. Confirm custom foods still appear and existing meal logs remain visible after a refresh.

## Roll back the integration commit

Preferred: revert the single integration commit on `flexfusion_v1`:

```bash
git log --oneline -5
git revert <food-catalogue-integration-commit-sha>
git push origin flexfusion_v1
```

This creates a new commit that reverses the integration without rewriting shared history.

If you need to inspect the exact pre-integration code, use the preserved branch:

```bash
git fetch origin
git switch backup/pre-food-catalog-integration-2026-11-02
```

To restore the working branch exactly to the checkpoint, do so only after confirming no later work needs to be kept:

```bash
git switch flexfusion_v1
git reset --hard backup/pre-food-catalog-integration-2026-11-02
git push --force-with-lease origin flexfusion_v1
```

The reset/force-push option is intentionally the last resort. Prefer `git revert`.

## Database note

No schema migration is part of this integration. The catalogue seed adds rows only. If the app has already seeded catalogue rows, reverting the code does not delete those rows; this is deliberate to avoid destructive automatic cleanup. They remain inactive to the UI once the catalogue-reading code is reverted, and can be retained safely for a later retry.
