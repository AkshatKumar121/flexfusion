import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int schemaVersion = 2;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final dbPath = kIsWeb
        ? 'flexfusion_v1.db'
        : p.join(await getDatabasesPath(), 'flexfusion_v1.db');

    _database = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    await _migrateLegacyMealLogs(_database!);
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
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE food_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_id INTEGER,
        food_name_snapshot TEXT NOT NULL,
        quantity_g REAL NOT NULL,
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

  Future<List<Map<String, Object?>>> getFoodLogsForDate(String date) async {
    final db = await database;
    return db.query(
      'food_logs',
      where: 'log_date = ?',
      whereArgs: [date],
      orderBy: "CASE meal_type WHEN 'BREAKFAST' THEN 1 WHEN 'LUNCH' THEN 2 WHEN 'SNACKS' THEN 3 WHEN 'DINNER' THEN 4 ELSE 5 END, id",
    );
  }

  Future<int> insertFoodLog({
    required String date,
    required String meal,
    required String name,
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
      'food_name_snapshot': name,
      'quantity_g': grams,
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
}
