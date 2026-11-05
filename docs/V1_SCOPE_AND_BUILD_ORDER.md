# FlexFusion V1 Scope, Database Design & Build Order

## Product decisions

- App: FlexFusion.
- V1 is local-first and offline-first. No account, cloud sync, or social features.
- SQLite is the primary store for structured app data.
- Local files store progress photos; SQLite stores their paths and metadata.
- SharedPreferences may remain for small, non-critical UI preferences only. Food logs and other structured fitness records must move to SQLite.
- Data export/import is part of V1.
- Keep the approved dark matte visual designs for Home/Dashboard and Eat. Do not redesign these screens as part of the database migration.

## V1 build order

1. **SQLite foundation:** add SQLite dependency, initialize database, define schema/versioning/migrations, and add repository/data-access layer.
2. **Eat completion:** migrate daily food logs from SharedPreferences to SQLite; complete food catalogue/custom foods, meal logging, quantity scaling, editing/removal, and date-based history.
3. **Dashboard completion:** remove hardcoded demo values and read calorie intake, protein intake, and latest weight from persisted data. Keep approved layout.
4. **Profile and Settings integration:** persist profile details, goals, calorie/macronutrient targets, units and preferences; use targets consistently in Eat and Dashboard.
5. **Train/workout module:** begin only after steps 1–4 pass analysis and functional testing.

Do not begin the Workout screen before the SQLite foundation, Eat screen and Dashboard are complete and tested.

## V1 database schema

Use SQLite with foreign keys enabled. Use integer primary keys unless a stable text identifier is more useful. Store timestamps in ISO-8601 UTC or a consistent documented local-date format. Store nutrition and body measurements using REAL values with explicit units. Add indexes for common date and foreign-key lookups.

### Profile and settings

- `user_profile`: id, display_name, date_of_birth, height_value, height_unit, current_goal, created_at, updated_at.
- `nutrition_targets`: id, effective_from, calorie_target, protein_target_g, carbs_target_g, fat_target_g.
- `app_settings`: key, value, updated_at. Use only for small preferences such as units, reminders and UI preferences.

### Food and nutrition

- `foods`: id, name, brand, serving_basis_g, calories_per_basis, protein_per_basis_g, carbs_per_basis_g, fat_per_basis_g, is_custom, created_at, updated_at.
- `food_logs`: id, log_date, meal_type, food_id nullable, food_name_snapshot, quantity_g, calories, protein_g, carbs_g, fat_g, created_at, updated_at.
- `food_favorites` (optional V1 if needed for the agreed favourites feature): id, food_id, created_at.

Food log entries keep a food-name/nutrition snapshot so historical logs remain correct if a catalogue food is later edited. Custom foods are saved in `foods` and can be reused. Meal types are Breakfast, Lunch, Snacks and Dinner. Quantities are entered in grams for the initial V1 implementation.

### Body progress

- `body_weights`: id, log_date, weight_value, weight_unit, created_at, updated_at. Enforce one primary daily entry per date, with a clear edit/replace flow.
- `body_measurements`: id, log_date, measurement_type, value, unit, created_at, updated_at.
- `progress_photos`: id, photo_date, angle (front/side/back), local_file_path, created_at. Store image files in app-managed local storage, not as image blobs in SQLite.

### Flexible workout planner and workout history (schema planned now; UI comes later)

- `workout_plans`: id, name, description, is_active, created_at, updated_at.
- `workout_plan_days`: id, plan_id, day_order, label, schedule_type, weekday nullable, is_rest_day, created_at, updated_at.
- `workout_plan_exercises`: id, plan_day_id, exercise_id, exercise_order, notes, created_at, updated_at.
- `workout_plan_sets`: id, plan_exercise_id, set_order, target_reps, target_weight nullable, target_weight_unit nullable, rest_seconds, created_at, updated_at.
- `exercises`: id, name, muscle_group, equipment, instructions nullable, is_custom, created_at, updated_at.
- `workouts`: id, plan_id nullable, plan_day_id nullable, started_at, completed_at nullable, session_name, status, notes nullable. Keep the session record independent from future plan edits.
- `workout_sets`: id, workout_id, exercise_id, exercise_name_snapshot, set_order, actual_reps, actual_weight nullable, weight_unit nullable, completed, created_at.

Workout planning must be flexible, not limited to one weekly schedule:
- Users can create multiple named plans and select one active plan.
- A plan can contain any number of ordered sessions/days.
- A session can be weekday-based (e.g. Monday) or sequence-based (e.g. Day 1, Day 2, Rest, Day 3).
- Users can label sessions freely (e.g. Chest, Push Day, Upper Body).
- Sessions can be marked as rest days.
- Each session can contain ordered exercises and configurable planned sets, reps, optional target weight and rest duration.
- Users can edit, duplicate, reorder and delete plans/sessions/exercises.
- Users can start an unscheduled workout.
- A one-session substitution or change must not silently alter the saved plan.
- Planned targets and actual completed sets are separate records.
- Completed workout history must remain intact if a plan is edited or deleted. Use nullable plan references and snapshots where needed.

### Export and restore

V1 export/import must include structured SQLite data and progress-photo files (or a documented archive containing both). Validate imported data before replacing local data. Never silently overwrite the user's current data.

## Data integrity and migration rules

- Enable SQLite foreign-key enforcement.
- Use database transactions for multi-row writes such as adding a food log with related data or completing a workout.
- Add schema versioning and forward migrations from the first release.
- Do not drop user data during migrations.
- Migrate existing SharedPreferences meal logs into SQLite once, verify the import, then mark migration complete. Do not delete the old preference data until successful migration is confirmed.
- Keep repositories/data-access code separate from widgets. Screens should not contain raw SQL.
- Use parameterized queries.
- Add indexes for log dates, foreign keys and common lookups.
- Handle empty database, malformed legacy JSON and failed writes without crashing.

## Completion gates before Workout UI

### SQLite foundation
- Database opens on supported target platforms.
- Schema and migration tests pass.
- Foreign keys and transaction behaviour are verified.
- Repository layer is usable by screens without raw SQL in widgets.

### Eat
- Existing saved meal entries migrate from SharedPreferences without loss.
- Add, edit, remove and reload food logs successfully.
- Logs are separated by date and meal.
- Custom foods can be saved and reused.
- Nutrition totals recalculate from persisted entries and active targets.

### Dashboard
- Calorie and protein values come from the same persisted food logs as Eat.
- Latest weight comes from body-weight records; show an empty state when no weight exists.
- No fabricated demo metrics or chart points are presented as real user data.
- Navigation and approved visual layout remain intact.

### Quality
- `flutter analyze` reports no issues.
- Relevant unit/widget tests pass.
- Manual Chrome test confirms persistence after refresh/relaunch.
- iOS behaviour is checked once the compatible Xcode toolchain is available.

Only after these gates pass should the Workout UI be started.
