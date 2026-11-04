import 'package:sqflite/sqflite.dart';

/// Owns FlexFusion's SQLite schema creation and versioned migrations.
///
/// Keep schema changes here so database access and domain queries remain
/// separate from the physical table definitions.
class AppDatabaseSchema {
  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        display_name TEXT NOT NULL DEFAULT '',
        age INTEGER,
        date_of_birth TEXT,
        height_value REAL,
        height_unit TEXT NOT NULL DEFAULT 'cm',
        current_goal TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE nutrition_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        effective_from TEXT NOT NULL,
        calorie_target REAL NOT NULL DEFAULT 2200,
        protein_target_g REAL NOT NULL DEFAULT 180,
        carbs_target_g REAL NOT NULL DEFAULT 190,
        fat_target_g REAL NOT NULL DEFAULT 65
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT,
        serving_basis_g REAL NOT NULL DEFAULT 100,
        calories_per_basis REAL NOT NULL,
        protein_per_basis_g REAL NOT NULL,
        carbs_per_basis_g REAL NOT NULL,
        fat_per_basis_g REAL NOT NULL,
        base_unit TEXT NOT NULL DEFAULT 'g',
        source TEXT NOT NULL DEFAULT 'built_in',
        source_id TEXT,
        barcode TEXT,
        category_id INTEGER,
        preparation_state TEXT NOT NULL DEFAULT 'unspecified',
        verification_status TEXT NOT NULL DEFAULT 'unverified',
        is_active INTEGER NOT NULL DEFAULT 1,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await createEatV1Tables(db);
    await db.execute('''
      CREATE TABLE food_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_id INTEGER,
        food_name_snapshot TEXT NOT NULL,
        quantity_g REAL NOT NULL,
        quantity_value REAL,
        quantity_unit TEXT NOT NULL DEFAULT 'g',
        base_quantity REAL,
        base_unit TEXT NOT NULL DEFAULT 'g',
        serving_name_snapshot TEXT,
        calories REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_food_logs_date ON food_logs(log_date)');
    await db.execute('CREATE INDEX idx_food_logs_date_meal ON food_logs(log_date, meal_type)');
    await db.execute('CREATE INDEX idx_foods_name ON foods(name COLLATE NOCASE)');

    await db.execute('''
      CREATE TABLE food_favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id INTEGER NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE body_weights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date TEXT NOT NULL UNIQUE,
        weight_value REAL NOT NULL,
        weight_unit TEXT NOT NULL DEFAULT 'kg',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE body_measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date TEXT NOT NULL,
        measurement_type TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(log_date, measurement_type)
      )
    ''');
    await db.execute('''
      CREATE TABLE progress_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_date TEXT NOT NULL,
        angle TEXT NOT NULL CHECK(angle IN ('front', 'side', 'back')),
        local_file_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(photo_date, angle)
      )
    ''');

    await createWorkoutTables(db);
    await db.execute('''CREATE TABLE IF NOT EXISTS activity_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, activity_type TEXT NOT NULL, activity_date TEXT NOT NULL, started_at TEXT, duration_minutes INTEGER NOT NULL DEFAULT 0, distance_km REAL, steps INTEGER, active_calories REAL, notes TEXT, source TEXT NOT NULL DEFAULT 'manual', created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_date ON activity_logs(activity_date, started_at)');
    await db.execute('''CREATE TABLE IF NOT EXISTS activity_health_daily (activity_date TEXT PRIMARY KEY, steps INTEGER, distance_km REAL, active_calories REAL, exercise_minutes REAL, synced_at TEXT NOT NULL)''');

  }


  static Future<void> createWorkoutTables(Database db) async {
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscle_group TEXT,
        equipment TEXT,
        instructions TEXT,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_plan_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        day_order INTEGER NOT NULL,
        label TEXT NOT NULL,
        schedule_type TEXT NOT NULL DEFAULT 'sequence',
        weekday INTEGER,
        is_rest_day INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (plan_id) REFERENCES workout_plans(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_workout_plan_days_plan ON workout_plan_days(plan_id, day_order)');
    await db.execute('''
      CREATE TABLE workout_plan_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_day_id INTEGER NOT NULL,
        exercise_id INTEGER,
        exercise_name_snapshot TEXT NOT NULL,
        exercise_order INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (plan_day_id) REFERENCES workout_plan_days(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_plan_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_exercise_id INTEGER NOT NULL,
        set_order INTEGER NOT NULL,
        target_reps INTEGER NOT NULL,
        target_weight REAL,
        target_weight_unit TEXT,
        rest_seconds INTEGER NOT NULL DEFAULT 60,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (plan_exercise_id) REFERENCES workout_plan_exercises(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        plan_day_id INTEGER,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        session_name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'in_progress',
        notes TEXT,
        paused_at TEXT,
        paused_seconds INTEGER NOT NULL DEFAULT 0,
        rest_ends_at TEXT,
        FOREIGN KEY (plan_id) REFERENCES workout_plans(id) ON DELETE SET NULL,
        FOREIGN KEY (plan_day_id) REFERENCES workout_plan_days(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER,
        exercise_name_snapshot TEXT NOT NULL,
        set_order INTEGER NOT NULL,
        actual_reps INTEGER,
        actual_weight REAL,
        weight_unit TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        rest_seconds INTEGER NOT NULL DEFAULT 90,
        created_at TEXT NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_workouts_started_at ON workouts(started_at)');
  }

  static Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN age INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE foods ADD COLUMN base_unit TEXT NOT NULL DEFAULT 'g'");
      await db.execute("ALTER TABLE foods ADD COLUMN source TEXT NOT NULL DEFAULT 'legacy'");
      await db.execute('ALTER TABLE foods ADD COLUMN source_id TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN barcode TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN category_id INTEGER');
      await db.execute("ALTER TABLE foods ADD COLUMN preparation_state TEXT NOT NULL DEFAULT 'unspecified'");
      await db.execute("ALTER TABLE foods ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'unverified'");
      await db.execute('ALTER TABLE foods ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE food_logs ADD COLUMN quantity_value REAL');
      await db.execute("ALTER TABLE food_logs ADD COLUMN quantity_unit TEXT NOT NULL DEFAULT 'g'");
      await db.execute('ALTER TABLE food_logs ADD COLUMN base_quantity REAL');
      await db.execute("ALTER TABLE food_logs ADD COLUMN base_unit TEXT NOT NULL DEFAULT 'g'");
      await db.execute('ALTER TABLE food_logs ADD COLUMN serving_name_snapshot TEXT');
      await db.execute("UPDATE food_logs SET quantity_value = quantity_g, base_quantity = quantity_g, base_unit = 'g', quantity_unit = 'g' WHERE quantity_value IS NULL");
      await createEatV1Tables(db);
    }

    // Bring legacy databases up to the workout-module baseline before v6
    // adds session pause columns. Older v2/v3 installs may not have any
    // workout tables yet.
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      final workoutTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workouts'",
      );
      if (workoutTables.isEmpty) {
        await createWorkoutTables(db);
      } else {
        final workoutSetTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workout_sets'",
        );
        if (workoutSetTables.isEmpty) {
          throw StateError('Legacy database has workouts but is missing workout_sets; refusing an unsafe migration.');
        }
        final columns = await db.rawQuery('PRAGMA table_info(workout_sets)');
        final hasRestSeconds = columns.any((column) => column['name'] == 'rest_seconds');
        if (!hasRestSeconds) {
          await db.execute('ALTER TABLE workout_sets ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 90');
        }
      }
    }

    if (oldVersion < 5) {
      await db.execute('''CREATE TABLE IF NOT EXISTS activity_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, activity_type TEXT NOT NULL, activity_date TEXT NOT NULL, started_at TEXT, duration_minutes INTEGER NOT NULL DEFAULT 0, distance_km REAL, steps INTEGER, active_calories REAL, notes TEXT, source TEXT NOT NULL DEFAULT 'manual', created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_date ON activity_logs(activity_date, started_at)');
      await db.execute('''CREATE TABLE IF NOT EXISTS activity_health_daily (activity_date TEXT PRIMARY KEY, steps INTEGER, distance_km REAL, active_calories REAL, exercise_minutes REAL, synced_at TEXT NOT NULL)''');
    }

    if (oldVersion < 6) {
      final workoutColumns = await db.rawQuery('PRAGMA table_info(workouts)');
      final hasPausedAt = workoutColumns.any((column) => column['name'] == 'paused_at');
      final hasPausedSeconds = workoutColumns.any((column) => column['name'] == 'paused_seconds');
      if (!hasPausedAt) {
        await db.execute('ALTER TABLE workouts ADD COLUMN paused_at TEXT');
      }
      if (!hasPausedSeconds) {
        await db.execute('ALTER TABLE workouts ADD COLUMN paused_seconds INTEGER NOT NULL DEFAULT 0');
      }
    }

    if (oldVersion < 7) {
      final workoutColumns = await db.rawQuery('PRAGMA table_info(workouts)');
      final hasRestEndsAt = workoutColumns.any((column) => column['name'] == 'rest_ends_at');
      if (!hasRestEndsAt) {
        await db.execute('ALTER TABLE workouts ADD COLUMN rest_ends_at TEXT');
      }
    }
  }

  static Future<void> createEatV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        slug TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_servings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id INTEGER NOT NULL,
        label TEXT NOT NULL,
        unit_key TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        base_quantity REAL NOT NULL,
        base_unit TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE,
        UNIQUE(food_id, unit_key, label)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_food_servings_food ON food_servings(food_id, sort_order)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        servings REAL NOT NULL DEFAULT 1,
        is_custom INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL DEFAULT 'user',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        food_id INTEGER,
        ingredient_name_snapshot TEXT NOT NULL,
        quantity_value REAL NOT NULL,
        quantity_unit TEXT NOT NULL,
        base_quantity REAL NOT NULL,
        base_unit TEXT NOT NULL,
        calories REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES food_recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id, sort_order)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_meal_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saved_meal_id INTEGER NOT NULL,
        food_id INTEGER,
        food_name_snapshot TEXT NOT NULL,
        quantity_value REAL NOT NULL,
        quantity_unit TEXT NOT NULL,
        base_quantity REAL NOT NULL,
        base_unit TEXT NOT NULL,
        calories REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (saved_meal_id) REFERENCES saved_meals(id) ON DELETE CASCADE,
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saved_meal_items_meal ON saved_meal_items(saved_meal_id, sort_order)');
  }


}
