import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase._({this._databasePathOverride});

  @visibleForTesting
  AppDatabase.forTesting(String databasePath)
      : this._(databasePathOverride: databasePath);

  static final AppDatabase instance = AppDatabase._();
  static const int schemaVersion = 3;
  final String? _databasePathOverride;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final dbPath = _databasePathOverride ??
        (kIsWeb
            ? 'flexfusion_v1.db'
            : p.join(await getDatabasesPath(), 'flexfusion_v1.db'));

    _database = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    await _migrateLegacyMealLogs(_database!);
    await _seedBuiltInFoodCatalog(_database!);
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
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
    await _createEatV1Tables(db);
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
        created_at TEXT NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_workouts_started_at ON workouts(started_at)');
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
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
      await _createEatV1Tables(db);
    }
  }

  Future<void> _createEatV1Tables(Database db) async {
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


  Future<void> _seedBuiltInFoodCatalog(Database db) async {
    const seedKey = 'flexfusion_food_catalog_v1_seeded';
    final marker = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [seedKey],
      limit: 1,
    );
    if (marker.isNotEmpty && marker.first['value'] == 'true') return;

    try {
      final raw = await rootBundle.loadString(
        'assets/data/flexfusion_food_catalog_v1.json',
      );
      final decoded = jsonDecode(raw) as List<dynamic>;
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        for (final value in decoded) {
          final item = value as Map<String, dynamic>;
          final sourceId = item['food_id'] as String?;
          final existing = sourceId == null
              ? <Map<String, Object?>>[]
              : await txn.query(
                  'foods',
                  columns: ['id'],
                  where: 'source = ? AND source_id = ?',
                  whereArgs: ['flexfusion_catalog_v1', sourceId],
                  limit: 1,
                );
          if (existing.isNotEmpty) continue;

          await txn.insert('foods', {
            'name': (item['name'] as String).trim(),
            'serving_basis_g': 100,
            'calories_per_basis': (item['calories_kcal'] as num).toDouble(),
            'protein_per_basis_g': (item['protein_g'] as num).toDouble(),
            'carbs_per_basis_g': (item['carbs_g'] as num).toDouble(),
            'fat_per_basis_g': (item['fats_g'] as num).toDouble(),
            'base_unit': 'g',
            'source': 'flexfusion_catalog_v1',
            'source_id': sourceId,
            'preparation_state': 'unspecified',
            'verification_status':
                item['verification_status'] as String? ?? 'source_imported',
            'is_active': 1,
            'is_custom': 0,
            'created_at': now,
            'updated_at': now,
          });
        }

        await txn.insert(
          'app_settings',
          {
            'key': seedKey,
            'value': 'true',
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      debugPrint('FlexFusion food catalogue seeded: ${decoded.length} records.');
    } catch (error) {
      // A missing or invalid optional catalogue asset must not prevent the
      // existing app and user data from opening. The seed can be retried later.
      debugPrint('Food catalogue seed skipped; existing app data is safe: $error');
    }
  }

  Future<List<Map<String, Object?>>> getBuiltInFoods() async {
    final db = await database;
    return db.query(
      'foods',
      where: 'is_custom = 0 AND is_active = 1',
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<void> _migrateLegacyMealLogs(Database db) async {
    const migrationKey = 'flexfusion_sqlite_meal_migration_v1_complete';
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(migrationKey) == true) return;

    final keys = preferences.getKeys()
        .where((key) => key.startsWith('flexfusion_meals_'))
        .toList()
      ..sort();

    await db.transaction((txn) async {
      for (final key in keys) {
        final date = key.substring('flexfusion_meals_'.length);
        final raw = preferences.getString(key);
        if (raw == null) continue;
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          for (final meal in ['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER']) {
            final entries = decoded[meal] as List<dynamic>? ?? [];
            for (final value in entries) {
              final item = value as Map<String, dynamic>;
              await txn.insert('food_logs', {
                'log_date': date,
                'meal_type': meal,
                'food_name_snapshot': item['name'] as String? ?? 'Food',
                'quantity_g': (item['grams'] as num?)?.toDouble() ?? 0,
                'quantity_value': (item['grams'] as num?)?.toDouble() ?? 0,
                'quantity_unit': 'g',
                'base_quantity': (item['grams'] as num?)?.toDouble() ?? 0,
                'base_unit': 'g',
                'serving_name_snapshot': 'g',
                'calories': (item['kcal'] as num?)?.toDouble() ?? 0,
                'protein_g': (item['protein'] as num?)?.toDouble() ?? 0,
                'carbs_g': (item['carbs'] as num?)?.toDouble() ?? 0,
                'fat_g': (item['fat'] as num?)?.toDouble() ?? 0,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          }
        } catch (error) {
          debugPrint('Skipped invalid legacy meal data for $date: $error');
        }
      }
    });

    // Mark complete only after the database transaction succeeds.
    await preferences.setBool(migrationKey, true);
  }

  @visibleForTesting
  Future<void> closeForTesting() async {
    await _database?.close();
    _database = null;
  }

  Future<List<Map<String, Object?>>> getFoodLogsForDate(String date) async {
    final db = await database;
    return db.query(
      'food_logs',
      where: 'log_date = ?',
      whereArgs: [date],
      orderBy: "CASE meal_type WHEN 'BREAKFAST' THEN 1 WHEN 'LUNCH' THEN 2 WHEN 'SNACKS' THEN 3 WHEN 'DINNER' THEN 4 ELSE 5 END, id",
    );
  }

  Future<int> insertCustomFood({
    required String name,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'foods',
      columns: ['id', 'created_at'],
      where: 'is_custom = 1 AND name = ? COLLATE NOCASE',
      whereArgs: [name.trim()],
      limit: 1,
    );
    final values = {
      'name': name.trim(),
      'serving_basis_g': 100,
      'calories_per_basis': caloriesPer100g,
      'protein_per_basis_g': proteinPer100g,
      'carbs_per_basis_g': carbsPer100g,
      'fat_per_basis_g': fatPer100g,
      'base_unit': 'g',
      'source': 'user',
      'verification_status': 'user_entered',
      'is_active': 1,
      'is_custom': 1,
      'updated_at': now,
    };
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update('foods', values, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    return db.insert('foods', {
      ...values,
      'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> getCustomFoods() async {
    final db = await database;
    return db.query(
      'foods',
      where: 'is_custom = 1 AND is_active = 1',
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<int> insertFoodLog({
    required String date,
    required String meal,
    required String name,
    int? foodId,
    required double grams,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('food_logs', {
      'log_date': date,
      'meal_type': meal,
      'food_id': foodId,
      'food_name_snapshot': name,
      'quantity_g': grams,
      'quantity_value': grams,
      'quantity_unit': 'g',
      'base_quantity': grams,
      'base_unit': 'g',
      'serving_name_snapshot': 'g',
      'calories': calories,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<String> getAppSetting(String key, {String defaultValue = ''}) async {
    final db = await database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? defaultValue : rows.first['value'] as String;
  }

  Future<void> saveAppSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePersonalDetails({
    required String displayName,
    required int age,
    required double heightCm,
    required double weightKg,
    required String goal,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timestamp = now.toIso8601String();
    await db.transaction((txn) async {
      final existing = await txn.query('user_profile', where: 'id = 1', limit: 1);
      await txn.insert('user_profile', {
        'id': 1,
        'display_name': displayName,
        'age': age,
        'height_value': heightCm,
        'height_unit': 'cm',
        'current_goal': goal,
        'created_at': existing.isEmpty ? timestamp : existing.first['created_at'],
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('body_weights', {
        'log_date': today,
        'weight_value': weightKg,
        'weight_unit': 'kg',
        'created_at': timestamp,
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> saveNutritionTargets({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await db.insert('nutrition_targets', {
      'effective_from': today,
      'calorie_target': calories,
      'protein_target_g': protein,
      'carbs_target_g': carbs,
      'fat_target_g': fat,
    });
  }

  Future<Map<String, Object?>?> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> getNutritionTargets() async {
    final db = await database;
    final rows = await db.query(
      'nutrition_targets',
      orderBy: 'effective_from DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveProfileAndTargets({
    required String displayName,
    required int age,
    required double heightCm,
    required double weightKg,
    required String goal,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timestamp = now.toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(
        'user_profile',
        {
          'id': 1,
          'display_name': displayName.trim(),
          'age': age,
          'height_value': heightCm,
          'height_unit': 'cm',
          'current_goal': goal,
          'created_at': timestamp,
          'updated_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'body_weights',
        {
          'log_date': today,
          'weight_value': weightKg,
          'weight_unit': 'kg',
          'created_at': timestamp,
          'updated_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'nutrition_targets',
        {
          'effective_from': today,
          'calorie_target': calories,
          'protein_target_g': protein,
          'carbs_target_g': carbs,
          'fat_target_g': fat,
        },
      );
    });
  }

  Future<int> deleteFoodLog(int id) async {
    final db = await database;
    return db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getDashboardNutrition(String date) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(calories), 0) AS calories,
        COALESCE(SUM(protein_g), 0) AS protein,
        COALESCE(SUM(carbs_g), 0) AS carbs,
        COALESCE(SUM(fat_g), 0) AS fat
      FROM food_logs
      WHERE log_date = ?
      ''',
      [date],
    );
    final row = rows.first;
    return {
      'calories': (row['calories'] as num).toDouble(),
      'protein': (row['protein'] as num).toDouble(),
      'carbs': (row['carbs'] as num).toDouble(),
      'fat': (row['fat'] as num).toDouble(),
    };
  }

  Future<Map<String, Object?>> getWeeklyProgressSummary() async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final previousStart = start.subtract(const Duration(days: 7));
    String dateKey(DateTime date) =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final startDate = dateKey(start);
    final todayDate = dateKey(today);
    final previousStartDate = dateKey(previousStart);
    final previousEndDate = dateKey(start.subtract(const Duration(days: 1)));

    final nutritionRows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS logged_days,
        COALESCE(AVG(day_calories), 0) AS average_calories,
        COALESCE(AVG(day_protein), 0) AS average_protein
      FROM (
        SELECT
          log_date,
          SUM(calories) AS day_calories,
          SUM(protein_g) AS day_protein
        FROM food_logs
        WHERE log_date >= ? AND log_date <= ?
        GROUP BY log_date
      )
      ''',
      [startDate, todayDate],
    );

    final weightRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS weigh_in_days, COALESCE(AVG(weight_value), 0) AS average_weight
      FROM body_weights
      WHERE log_date >= ? AND log_date <= ?
      ''',
      [startDate, todayDate],
    );

    final previousWeightRows = await db.rawQuery(
      '''
      SELECT COALESCE(AVG(weight_value), 0) AS average_weight
      FROM body_weights
      WHERE log_date >= ? AND log_date <= ?
      ''',
      [previousStartDate, previousEndDate],
    );

    final workoutRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS completed_workouts
      FROM workouts
      WHERE status = 'completed'
        AND substr(completed_at, 1, 10) >= ?
        AND substr(completed_at, 1, 10) <= ?
      ''',
      [startDate, todayDate],
    );

    final nutrition = nutritionRows.first;
    final weights = weightRows.first;
    final previousAverageWeight =
        (previousWeightRows.first['average_weight'] as num).toDouble();

    return {
      'start_date': startDate,
      'end_date': todayDate,
      'logged_days': (nutrition['logged_days'] as num).toInt(),
      'average_calories': (nutrition['average_calories'] as num).toDouble(),
      'average_protein': (nutrition['average_protein'] as num).toDouble(),
      'weigh_in_days': (weights['weigh_in_days'] as num).toInt(),
      'average_weight': (weights['average_weight'] as num).toDouble(),
      'previous_average_weight': previousAverageWeight,
      'has_previous_weight': previousAverageWeight > 0,
      'completed_workouts':
          (workoutRows.first['completed_workouts'] as num).toInt(),
    };
  }

  Future<Map<String, Object?>> getWeeklyProgressDetails() async {
    final db = await database;
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 6));
    final previousStart = start.subtract(const Duration(days: 7));
    String dateKey(DateTime date) =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final daily = <Map<String, Object?>>[];
    for (var offset = 0; offset < 7; offset++) {
      final date = start.add(Duration(days: offset));
      final key = dateKey(date);
      final nutrition = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(calories), 0) AS calories,
               COALESCE(SUM(protein_g), 0) AS protein
        FROM food_logs WHERE log_date = ?
        ''',
        [key],
      );
      final weightRows = await db.query(
        'body_weights',
        columns: ['weight_value'],
        where: 'log_date = ?',
        whereArgs: [key],
        limit: 1,
      );
      final workoutRows = await db.rawQuery(
        '''
        SELECT COUNT(*) AS workouts FROM workouts
        WHERE status = 'completed' AND substr(completed_at, 1, 10) = ?
        ''',
        [key],
      );
      daily.add({
        'date': key,
        'day': ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
        'calories': (nutrition.first['calories'] as num).toDouble(),
        'protein': (nutrition.first['protein'] as num).toDouble(),
        'weight': weightRows.isEmpty
            ? null
            : (weightRows.first['weight_value'] as num).toDouble(),
        'workouts': (workoutRows.first['workouts'] as num).toInt(),
      });
    }

    final currentNutrition = await db.rawQuery(
      '''
      SELECT COUNT(*) AS tracked_days,
             COALESCE(AVG(day_calories), 0) AS average_calories,
             COALESCE(AVG(day_protein), 0) AS average_protein
      FROM (
        SELECT log_date, SUM(calories) AS day_calories,
               SUM(protein_g) AS day_protein
        FROM food_logs WHERE log_date >= ? AND log_date <= ?
        GROUP BY log_date
      )
      ''',
      [dateKey(start), dateKey(end)],
    );
    final previousNutrition = await db.rawQuery(
      '''
      SELECT COUNT(*) AS tracked_days,
             COALESCE(AVG(day_calories), 0) AS average_calories,
             COALESCE(AVG(day_protein), 0) AS average_protein
      FROM (
        SELECT log_date, SUM(calories) AS day_calories,
               SUM(protein_g) AS day_protein
        FROM food_logs WHERE log_date >= ? AND log_date < ?
        GROUP BY log_date
      )
      ''',
      [dateKey(previousStart), dateKey(start)],
    );

    final currentWeight = await db.rawQuery(
      'SELECT COUNT(*) AS days, COALESCE(AVG(weight_value), 0) AS average FROM body_weights WHERE log_date >= ? AND log_date <= ?',
      [dateKey(start), dateKey(end)],
    );
    final previousWeight = await db.rawQuery(
      'SELECT COUNT(*) AS days, COALESCE(AVG(weight_value), 0) AS average FROM body_weights WHERE log_date >= ? AND log_date < ?',
      [dateKey(previousStart), dateKey(start)],
    );
    final currentWorkouts = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM workouts WHERE status = 'completed' AND substr(completed_at, 1, 10) >= ? AND substr(completed_at, 1, 10) <= ?",
      [dateKey(start), dateKey(end)],
    );
    final previousWorkouts = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM workouts WHERE status = 'completed' AND substr(completed_at, 1, 10) >= ? AND substr(completed_at, 1, 10) < ?",
      [dateKey(previousStart), dateKey(start)],
    );

    final cn = currentNutrition.first;
    final pn = previousNutrition.first;
    final cw = currentWeight.first;
    final pw = previousWeight.first;
    return {
      'start_date': dateKey(start),
      'end_date': dateKey(end),
      'daily': daily,
      'tracked_days': (cn['tracked_days'] as num).toInt(),
      'average_calories': (cn['average_calories'] as num).toDouble(),
      'average_protein': (cn['average_protein'] as num).toDouble(),
      'previous_tracked_days': (pn['tracked_days'] as num).toInt(),
      'previous_average_calories': (pn['average_calories'] as num).toDouble(),
      'previous_average_protein': (pn['average_protein'] as num).toDouble(),
      'weight_days': (cw['days'] as num).toInt(),
      'average_weight': (cw['average'] as num).toDouble(),
      'previous_weight_days': (pw['days'] as num).toInt(),
      'previous_average_weight': (pw['average'] as num).toDouble(),
      'workouts': (currentWorkouts.first['total'] as num).toInt(),
      'previous_workouts': (previousWorkouts.first['total'] as num).toInt(),
    };
  }

  Future<List<Map<String, Object?>>> getRecentBodyWeights({int limit = 7}) async {
    final db = await database;
    final since = DateTime.now().subtract(const Duration(days: 6));
    final date = '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    return db.query(
      'body_weights',
      where: 'log_date >= ?',
      whereArgs: [date],
      orderBy: 'log_date DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> getLatestBodyWeight() async {
    final db = await database;
    final rows = await db.query('body_weights', orderBy: 'log_date DESC', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }


  Future<void> saveBodyWeight({
    required String date,
    required double weightKg,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'body_weights',
      columns: ['id', 'created_at'],
      where: 'log_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    await db.insert(
      'body_weights',
      {
        'log_date': date,
        'weight_value': weightKg,
        'weight_unit': 'kg',
        'created_at': existing.isEmpty ? now : existing.first['created_at'],
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getProgressPhotos({int limit = 12}) async {
    final db = await database;
    return db.query(
      'progress_photos',
      orderBy: 'photo_date DESC, id DESC',
      limit: limit,
    );
  }

  Future<void> saveProgressPhoto({
    required String date,
    required String angle,
    required String localFilePath,
  }) async {
    final db = await database;
    await db.insert(
      'progress_photos',
      {
        'photo_date': date,
        'angle': angle,
        'local_file_path': localFilePath,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  // Workout plan and exercise library operations.
  Future<List<Map<String, Object?>>> getExercises() async {
    final db = await database;
    return db.query('exercises', orderBy: 'muscle_group COLLATE NOCASE, name COLLATE NOCASE');
  }

  Future<int> saveExercise({
    int? id,
    required String name,
    required String muscleGroup,
    required String equipment,
    String? instructions,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = {
      'name': name.trim(),
      'muscle_group': muscleGroup.trim(),
      'equipment': equipment.trim(),
      'instructions': instructions?.trim(),
      'is_custom': 1,
      'updated_at': now,
    };
    if (id != null) {
      await db.update('exercises', values, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    return db.insert('exercises', {...values, 'created_at': now});
  }

  Future<void> deleteExercise(int id) async {
    final db = await database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> getWorkoutPlans() async {
    final db = await database;
    return db.query('workout_plans', orderBy: 'is_active DESC, updated_at DESC, id DESC');
  }

  Future<Map<String, Object?>?> getActiveWorkoutPlan() async {
    final db = await database;
    final rows = await db.query('workout_plans', where: 'is_active = 1', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getWorkoutPlanDays(int planId) async {
    final db = await database;
    return db.query('workout_plan_days', where: 'plan_id = ?', whereArgs: [planId], orderBy: 'day_order, id');
  }

  Future<List<Map<String, Object?>>> getPlanDayExercises(int dayId) async {
    final db = await database;
    return db.query('workout_plan_exercises', where: 'plan_day_id = ?', whereArgs: [dayId], orderBy: 'exercise_order, id');
  }

  Future<List<Map<String, Object?>>> getPlanExerciseSets(int planExerciseId) async {
    final db = await database;
    return db.query('workout_plan_sets', where: 'plan_exercise_id = ?', whereArgs: [planExerciseId], orderBy: 'set_order, id');
  }

  Future<int> createWorkoutPlan(String name, {String? description}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('workout_plans', {
      'name': name.trim(),
      'description': description?.trim(),
      'is_active': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateWorkoutPlan(int id, {required String name, String? description}) async {
    final db = await database;
    await db.update('workout_plans', {
      'name': name.trim(),
      'description': description?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setActiveWorkoutPlan(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('workout_plans', {'is_active': 0});
      await txn.update('workout_plans', {
        'is_active': 1,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteWorkoutPlan(int id) async {
    final db = await database;
    await db.delete('workout_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> duplicateWorkoutPlan(int planId, String newName) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final sourceRows = await txn.query('workout_plans', where: 'id = ?', whereArgs: [planId], limit: 1);
      if (sourceRows.isEmpty) throw StateError('Workout plan not found');
      final source = sourceRows.first;
      final newPlanId = await txn.insert('workout_plans', {
        'name': newName.trim(),
        'description': source['description'],
        'is_active': 0,
        'created_at': now,
        'updated_at': now,
      });
      final days = await txn.query('workout_plan_days', where: 'plan_id = ?', whereArgs: [planId], orderBy: 'day_order, id');
      for (final day in days) {
        final newDayId = await txn.insert('workout_plan_days', {
          'plan_id': newPlanId,
          'day_order': day['day_order'],
          'label': day['label'],
          'schedule_type': day['schedule_type'],
          'weekday': day['weekday'],
          'is_rest_day': day['is_rest_day'],
          'created_at': now,
          'updated_at': now,
        });
        final exercises = await txn.query('workout_plan_exercises', where: 'plan_day_id = ?', whereArgs: [day['id']], orderBy: 'exercise_order, id');
        for (final exercise in exercises) {
          final newExerciseId = await txn.insert('workout_plan_exercises', {
            'plan_day_id': newDayId,
            'exercise_id': exercise['exercise_id'],
            'exercise_name_snapshot': exercise['exercise_name_snapshot'],
            'exercise_order': exercise['exercise_order'],
            'notes': exercise['notes'],
            'created_at': now,
            'updated_at': now,
          });
          final sets = await txn.query('workout_plan_sets', where: 'plan_exercise_id = ?', whereArgs: [exercise['id']], orderBy: 'set_order, id');
          for (final set in sets) {
            await txn.insert('workout_plan_sets', {
              'plan_exercise_id': newExerciseId,
              'set_order': set['set_order'],
              'target_reps': set['target_reps'],
              'target_weight': set['target_weight'],
              'target_weight_unit': set['target_weight_unit'],
              'rest_seconds': set['rest_seconds'],
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      }
      return newPlanId;
    });
  }

  Future<int> addWorkoutPlanDay({
    required int planId,
    required String label,
    required int dayOrder,
    String scheduleType = 'sequence',
    int? weekday,
    bool isRestDay = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('workout_plan_days', {
      'plan_id': planId,
      'label': label.trim(),
      'day_order': dayOrder,
      'schedule_type': scheduleType,
      'weekday': weekday,
      'is_rest_day': isRestDay ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateWorkoutPlanDay({
    required int id,
    required String label,
    required int dayOrder,
    required String scheduleType,
    int? weekday,
    required bool isRestDay,
  }) async {
    final db = await database;
    await db.update('workout_plan_days', {
      'label': label.trim(),
      'day_order': dayOrder,
      'schedule_type': scheduleType,
      'weekday': weekday,
      'is_rest_day': isRestDay ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteWorkoutPlanDay(int id) async {
    final db = await database;
    await db.delete('workout_plan_days', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addExerciseToPlanDay({
    required int dayId,
    int? exerciseId,
    required String exerciseName,
    required int exerciseOrder,
    int setCount = 3,
    int targetReps = 10,
    double? targetWeight,
    String weightUnit = 'kg',
    int restSeconds = 90,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final id = await txn.insert('workout_plan_exercises', {
        'plan_day_id': dayId,
        'exercise_id': exerciseId,
        'exercise_name_snapshot': exerciseName.trim(),
        'exercise_order': exerciseOrder,
        'created_at': now,
        'updated_at': now,
      });
      for (var i = 1; i <= setCount; i++) {
        await txn.insert('workout_plan_sets', {
          'plan_exercise_id': id,
          'set_order': i,
          'target_reps': targetReps,
          'target_weight': targetWeight,
          'target_weight_unit': weightUnit,
          'rest_seconds': restSeconds,
          'created_at': now,
          'updated_at': now,
        });
      }
      return id;
    });
  }

  Future<void> deletePlanExercise(int id) async {
    final db = await database;
    await db.delete('workout_plan_exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePlanExerciseSets({
    required int planExerciseId,
    required int setCount,
    required int targetReps,
    double? targetWeight,
    required String weightUnit,
    required int restSeconds,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('workout_plan_sets', where: 'plan_exercise_id = ?', whereArgs: [planExerciseId]);
      for (var i = 1; i <= setCount; i++) {
        await txn.insert('workout_plan_sets', {
          'plan_exercise_id': planExerciseId,
          'set_order': i,
          'target_reps': targetReps,
          'target_weight': targetWeight,
          'target_weight_unit': weightUnit,
          'rest_seconds': restSeconds,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }



  // Workout session tracking and history.
  Future<int> startWorkoutSession({
    int? planId,
    int? planDayId,
    required String sessionName,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final workoutId = await txn.insert('workouts', {
        'plan_id': planId,
        'plan_day_id': planDayId,
        'started_at': now,
        'session_name': sessionName.trim(),
        'status': 'in_progress',
      });
      if (planDayId != null) {
        final exercises = await txn.query(
          'workout_plan_exercises',
          where: 'plan_day_id = ?',
          whereArgs: [planDayId],
          orderBy: 'exercise_order, id',
        );
        for (final exercise in exercises) {
          final sets = await txn.query(
            'workout_plan_sets',
            where: 'plan_exercise_id = ?',
            whereArgs: [exercise['id']],
            orderBy: 'set_order, id',
          );
          for (final set in sets) {
            await txn.insert('workout_sets', {
              'workout_id': workoutId,
              'exercise_id': exercise['exercise_id'],
              'exercise_name_snapshot': exercise['exercise_name_snapshot'],
              'set_order': set['set_order'],
              'actual_reps': set['target_reps'],
              'actual_weight': set['target_weight'],
              'weight_unit': set['target_weight_unit'] ?? 'kg',
              'completed': 0,
              'created_at': now,
            });
          }
        }
      }
      return workoutId;
    });
  }

  Future<int> addExerciseToWorkout({
    required int workoutId,
    int? exerciseId,
    required String exerciseName,
    required int setCount,
    int targetReps = 10,
    double? targetWeight,
    String weightUnit = 'kg',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'workout_sets',
      columns: ['exercise_name_snapshot'],
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
    final matching = existing.where((row) => row['exercise_name_snapshot'] == exerciseName).length;
    return db.transaction((txn) async {
      var firstId = 0;
      for (var i = 1; i <= setCount; i++) {
        final id = await txn.insert('workout_sets', {
          'workout_id': workoutId,
          'exercise_id': exerciseId,
          'exercise_name_snapshot': exerciseName,
          'set_order': matching + i,
          'actual_reps': targetReps,
          'actual_weight': targetWeight,
          'weight_unit': weightUnit,
          'completed': 0,
          'created_at': now,
        });
        if (i == 1) firstId = id;
      }
      return firstId;
    });
  }

  Future<List<Map<String, Object?>>> getWorkoutSessionSets(int workoutId) async {
    final db = await database;
    return db.query(
      'workout_sets',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'id',
    );
  }

  Future<void> updateWorkoutSet({
    required int id,
    required int reps,
    required double? weight,
    required bool completed,
  }) async {
    final db = await database;
    await db.update('workout_sets', {
      'actual_reps': reps,
      'actual_weight': weight,
      'completed': completed ? 1 : 0,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> finishWorkoutSession(int workoutId, {String? notes}) async {
    final db = await database;
    await db.update('workouts', {
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'notes': notes,
    }, where: 'id = ?', whereArgs: [workoutId]);
  }

  Future<void> abandonWorkoutSession(int workoutId) async {
    final db = await database;
    await db.update('workouts', {
      'status': 'abandoned',
      'completed_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [workoutId]);
  }

  Future<List<Map<String, Object?>>> getWorkoutHistory({int limit = 50}) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT w.*,
        (SELECT COUNT(*) FROM workout_sets s WHERE s.workout_id = w.id) AS total_sets,
        (SELECT COUNT(*) FROM workout_sets s WHERE s.workout_id = w.id AND s.completed = 1) AS completed_sets
      FROM workouts w
      WHERE w.status = 'completed'
      ORDER BY w.completed_at DESC, w.id DESC
      LIMIT ?
      ''',
      [limit],
    );
  }

  Future<Map<String, Object?>?> getInProgressWorkout() async {
    final db = await database;
    final rows = await db.query(
      'workouts',
      where: "status = 'in_progress'",
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> getSuggestedWorkoutDay() async {
    final db = await database;
    final plans = await db.query('workout_plans', where: 'is_active = 1', limit: 1);
    if (plans.isEmpty) return null;
    final plan = plans.first;
    final days = await db.query(
      'workout_plan_days',
      where: 'plan_id = ?',
      whereArgs: [plan['id']],
      orderBy: 'day_order, id',
    );
    if (days.isEmpty) return null;
    final today = DateTime.now().weekday;
    final fixed = days.where((day) =>
        day['schedule_type'] == 'weekday' && day['weekday'] == today).toList();
    if (fixed.isNotEmpty) return {...fixed.first, 'plan_name': plan['name'], 'plan_id': plan['id']};

    final sequenceDays = days.where((day) => day['schedule_type'] != 'weekday').toList();
    if (sequenceDays.isEmpty) return null;
    final previous = await db.query(
      'workouts',
      where: "plan_id = ? AND status = 'completed' AND plan_day_id IS NOT NULL",
      whereArgs: [plan['id']],
      orderBy: 'completed_at DESC, id DESC',
      limit: 1,
    );
    var nextIndex = 0;
    if (previous.isNotEmpty) {
      final lastDayId = previous.first['plan_day_id'];
      final lastIndex = sequenceDays.indexWhere((day) => day['id'] == lastDayId);
      if (lastIndex >= 0) nextIndex = (lastIndex + 1) % sequenceDays.length;
    }
    return {...sequenceDays[nextIndex], 'plan_name': plan['name'], 'plan_id': plan['id']};
  }


  Future<Map<String, Object?>> getWorkoutSessionSummary(int workoutId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT w.*,
        COUNT(s.id) AS total_sets,
        COALESCE(SUM(CASE WHEN s.completed = 1 THEN 1 ELSE 0 END), 0) AS completed_sets,
        COALESCE(SUM(CASE WHEN s.completed = 1 THEN COALESCE(s.actual_weight, 0) * COALESCE(s.actual_reps, 0) ELSE 0 END), 0) AS volume
      FROM workouts w
      LEFT JOIN workout_sets s ON s.workout_id = w.id
      WHERE w.id = ?
      GROUP BY w.id
      ''',
      [workoutId],
    );
    return rows.isEmpty ? <String, Object?>{} : rows.first;
  }

}
