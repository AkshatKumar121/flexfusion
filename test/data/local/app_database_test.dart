import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flexfusion/data/local/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late AppDatabase appDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_db_test_');
    appDatabase = AppDatabase.forTesting(p.join(tempDirectory.path, 'test.db'));
  });

  tearDown(() async {
    await appDatabase.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('training streak includes days that reach the 10000-step goal', () async {
    final db = await appDatabase.database;
    await appDatabase.saveHealthActivitySummary(
      date: '2026-10-30',
      steps: 10000,
    );
    await appDatabase.saveHealthActivitySummary(
      date: '2026-10-31',
      steps: 9999,
    );
    await appDatabase.saveActivityLog(
      activityType: 'Walking',
      activityDate: '2026-11-01',
      durationMinutes: 20,
      steps: 6000,
    );
    await appDatabase.saveActivityLog(
      activityType: 'Walking',
      activityDate: '2026-11-01',
      durationMinutes: 15,
      steps: 4000,
    );
    final workoutId = await db.insert('workouts', {
      'started_at': '2026-11-02T07:00:00',
      'completed_at': '2026-11-02T08:00:00',
      'session_name': 'Completed workout',
      'status': 'completed',
    });
    await db.insert('workout_sets', {
      'workout_id': workoutId,
      'exercise_name_snapshot': 'Dumbbell press',
      'set_order': 1,
      'actual_reps': 10,
      'actual_weight': 15,
      'weight_unit': 'kg',
      'completed': 1,
      'created_at': '2026-11-02T07:30:00',
    });

    final data = await appDatabase.getTrainingStreakData();

    expect(data['step_goal_days'], containsAll(['2026-10-30', '2026-11-01']));
    expect(data['step_goal_days'], isNot(contains('2026-10-31')));
    expect(data['workout_days'], contains('2026-11-02'));
  });

  test('training streak uses the configured daily step goal', () async {
    await appDatabase.saveAppSetting('daily_step_goal', '7000');
    await appDatabase.saveHealthActivitySummary(
      date: '2026-10-30',
      steps: 7000,
    );
    await appDatabase.saveHealthActivitySummary(
      date: '2026-10-31',
      steps: 6999,
    );

    final data = await appDatabase.getTrainingStreakData();

    expect(data['step_goal'], 7000);
    expect(data['step_goal_days'], contains('2026-10-30'));
    expect(data['step_goal_days'], isNot(contains('2026-10-31')));
  });

  test('nutrition streak returns configured targets when today has no food logs', () async {
    await appDatabase.saveNutritionTargets(
      calories: 1800,
      protein: 150,
      carbs: 190,
      fat: 60,
    );

    final rows = await appDatabase.getNutritionStreakDays();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayRow = rows.singleWhere((row) => row['day'] == today);

    expect(todayRow['calories'], 0);
    expect(todayRow['protein'], 0);
    expect(todayRow['calorie_target'], 1800);
    expect(todayRow['protein_target'], 150);
  });

  test('fresh database creates the complete V1 schema at version 7', () async {
    final db = await appDatabase.database;
    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);

    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = rows.map((row) => row['name'] as String).toSet();

    expect(
      tables,
      containsAll([
        'foods',
        'food_logs',
        'food_favorites',
        'food_categories',
        'food_servings',
        'food_recipes',
        'recipe_ingredients',
        'saved_meals',
        'saved_meal_items',
      ]),
    );

    final foodColumns = await db.rawQuery('PRAGMA table_info(foods)');
    final foodColumnNames =
        foodColumns.map((row) => row['name'] as String).toSet();
    expect(
      foodColumnNames,
      containsAll([
        'brand',
        'base_unit',
        'source',
        'source_id',
        'barcode',
        'category_id',
        'preparation_state',
        'verification_status',
        'is_active',
        'is_custom',
      ]),
    );

    final logColumns = await db.rawQuery('PRAGMA table_info(food_logs)');
    final logColumnNames =
        logColumns.map((row) => row['name'] as String).toSet();
    expect(
      logColumnNames,
      containsAll([
        'quantity_value',
        'quantity_unit',
        'base_quantity',
        'base_unit',
        'serving_name_snapshot',
      ]),
    );
  });

  test('built-in catalogue cleanup preserves custom foods and historical meal logs', () async {
    final db = await appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final builtInId = await db.insert('foods', {
      'name': 'Legacy Built-in Food',
      'serving_basis_g': 100,
      'calories_per_basis': 120,
      'protein_per_basis_g': 5,
      'carbs_per_basis_g': 20,
      'fat_per_basis_g': 2,
      'source': 'flexfusion_catalog_v1',
      'is_custom': 0,
      'created_at': now,
      'updated_at': now,
    });
    final customId = await appDatabase.insertCustomFood(
      name: 'My Custom Food',
      caloriesPer100g: 210,
      proteinPer100g: 12,
      carbsPer100g: 18,
      fatPer100g: 8,
    );
    await appDatabase.insertFoodLog(
      date: '2026-11-06',
      meal: 'LUNCH',
      name: 'Legacy Built-in Food',
      foodId: builtInId,
      grams: 100,
      calories: 120,
      protein: 5,
      carbs: 20,
      fat: 2,
    );

    // Simulate an installation that already had the old catalogue seeded.
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['flexfusion_builtin_food_catalog_cleared_v1'],
    );
    await appDatabase.closeForTesting();
    appDatabase = AppDatabase.forTesting(p.join(tempDirectory.path, 'test.db'));

    final reopenedDb = await appDatabase.database;
    expect(await appDatabase.getBuiltInFoods(), isEmpty);
    final customFoods = await appDatabase.getCustomFoods();
    expect(customFoods, hasLength(1));
    expect(customFoods.single['id'], customId);
    expect(customFoods.single['name'], 'My Custom Food');

    final logs = await appDatabase.getFoodLogsForDate('2026-11-06');
    expect(logs, hasLength(1));
    expect(logs.single['food_id'], isNull);
    expect(logs.single['food_name_snapshot'], 'Legacy Built-in Food');
    expect(logs.single['calories'], 120);
    expect(await reopenedDb.query('foods', where: 'is_custom = 0'), isEmpty);
  });

  test('custom foods are saved, retrieved and updated without duplicates', () async {
    final firstId = await appDatabase.insertCustomFood(
      name: 'Test Paneer',
      caloriesPer100g: 265,
      proteinPer100g: 18.3,
      carbsPer100g: 1.2,
      fatPer100g: 20.8,
    );

    final secondId = await appDatabase.insertCustomFood(
      name: 'test paneer',
      caloriesPer100g: 270,
      proteinPer100g: 19,
      carbsPer100g: 1.5,
      fatPer100g: 21,
    );

    final foods = await appDatabase.getCustomFoods();
    expect(secondId, firstId);
    expect(foods, hasLength(1));
    expect(foods.single['name'], 'test paneer');
    expect(foods.single['calories_per_basis'], 270);
  });

  test('serving units belong to their food and cascade on food deletion', () async {
    final db = await appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final eggId = await appDatabase.insertCustomFood(
      name: 'Test Egg',
      caloriesPer100g: 143,
      proteinPer100g: 12.6,
      carbsPer100g: 0.7,
      fatPer100g: 9.5,
    );
    final bananaId = await appDatabase.insertCustomFood(
      name: 'Test Banana',
      caloriesPer100g: 89,
      proteinPer100g: 1.1,
      carbsPer100g: 22.8,
      fatPer100g: 0.3,
    );

    await db.insert('food_servings', {
      'food_id': eggId,
      'label': '1 medium egg',
      'unit_key': 'piece',
      'quantity': 1,
      'base_quantity': 50,
      'base_unit': 'g',
      'is_default': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('food_servings', {
      'food_id': bananaId,
      'label': '1 medium banana',
      'unit_key': 'piece',
      'quantity': 1,
      'base_quantity': 118,
      'base_unit': 'g',
      'is_default': 1,
      'created_at': now,
      'updated_at': now,
    });

    final eggServing = await db.query(
      'food_servings',
      where: 'food_id = ?',
      whereArgs: [eggId],
    );
    final bananaServing = await db.query(
      'food_servings',
      where: 'food_id = ?',
      whereArgs: [bananaId],
    );
    expect(eggServing.single['base_quantity'], 50);
    expect(bananaServing.single['base_quantity'], 118);

    await db.delete('foods', where: 'id = ?', whereArgs: [eggId]);
    final remainingEggServings = await db.query(
      'food_servings',
      where: 'food_id = ?',
      whereArgs: [eggId],
    );
    expect(remainingEggServings, isEmpty);
    expect(await db.query('food_servings'), hasLength(1));
  });

  test('recipe ingredients cascade when recipe is deleted', () async {
    final db = await appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final foodId = await appDatabase.insertCustomFood(
      name: 'Recipe Test Ingredient',
      caloriesPer100g: 100,
      proteinPer100g: 10,
      carbsPer100g: 10,
      fatPer100g: 2,
    );
    final recipeId = await db.insert('food_recipes', {
      'name': 'Test Recipe',
      'servings': 2,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('recipe_ingredients', {
      'recipe_id': recipeId,
      'food_id': foodId,
      'ingredient_name_snapshot': 'Recipe Test Ingredient',
      'quantity_value': 50,
      'quantity_unit': 'g',
      'base_quantity': 50,
      'base_unit': 'g',
      'calories': 50,
      'protein_g': 5,
      'carbs_g': 5,
      'fat_g': 1,
    });

    await db.delete('foods', where: 'id = ?', whereArgs: [foodId]);
    final ingredient = (await db.query('recipe_ingredients')).single;
    expect(ingredient['food_id'], isNull);
    expect(ingredient['ingredient_name_snapshot'], 'Recipe Test Ingredient');

    await db.delete('food_recipes', where: 'id = ?', whereArgs: [recipeId]);
    expect(await db.query('recipe_ingredients'), isEmpty);
  });

  test('saved meal items cascade when saved meal is deleted', () async {
    final db = await appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final mealId = await db.insert('saved_meals', {
      'name': 'Test Breakfast',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('saved_meal_items', {
      'saved_meal_id': mealId,
      'food_name_snapshot': 'Boiled egg',
      'quantity_value': 2,
      'quantity_unit': 'piece',
      'base_quantity': 100,
      'base_unit': 'g',
      'calories': 143,
      'protein_g': 12.6,
      'carbs_g': 0.7,
      'fat_g': 9.5,
    });

    expect(await db.query('saved_meal_items'), hasLength(1));
    await db.delete('saved_meals', where: 'id = ?', whereArgs: [mealId]);
    expect(await db.query('saved_meal_items'), isEmpty);
  });

  test('food logs retain nutrition snapshots and can be deleted', () async {
    final foodId = await appDatabase.insertCustomFood(
      name: 'Logged Test Food',
      caloriesPer100g: 200,
      proteinPer100g: 10,
      carbsPer100g: 20,
      fatPer100g: 5,
    );
    final logId = await appDatabase.insertFoodLog(
      date: '2026-11-02',
      meal: 'BREAKFAST',
      name: 'Logged Test Food',
      foodId: foodId,
      grams: 150,
      calories: 300,
      protein: 15,
      carbs: 30,
      fat: 7.5,
    );

    final logs = await appDatabase.getFoodLogsForDate('2026-11-02');
    expect(logs, hasLength(1));
    expect(logs.single['food_id'], foodId);
    expect(logs.single['quantity_g'], 150);
    expect(logs.single['quantity_value'], 150);
    expect(logs.single['quantity_unit'], 'g');
    expect(logs.single['calories'], 300);

    await appDatabase.deleteFoodLog(logId);
    expect(await appDatabase.getFoodLogsForDate('2026-11-02'), isEmpty);
  });

  test('legacy SharedPreferences meal logs migrate with gram serving metadata', () async {
    SharedPreferences.setMockInitialValues({
      'flexfusion_meals_2026-11-02': jsonEncode({
        'BREAKFAST': [
          {
            'name': 'Legacy Oats',
            'grams': 40,
            'kcal': 156,
            'protein': 6.76,
            'carbs': 26.52,
            'fat': 2.76,
          }
        ],
        'LUNCH': [],
        'SNACKS': [],
        'DINNER': [],
      }),
    });

    final logs = await appDatabase.getFoodLogsForDate('2026-11-02');
    expect(logs, hasLength(1));
    expect(logs.single['food_name_snapshot'], 'Legacy Oats');
    expect(logs.single['quantity_g'], 40);
    expect(logs.single['quantity_value'], 40);
    expect(logs.single['quantity_unit'], 'g');
    expect(logs.single['base_quantity'], 40);
    expect(logs.single['serving_name_snapshot'], 'g');
    expect(logs.single['calories'], 156);
  });

  test('legacy meal migration does not duplicate rows if preference marker is lost', () async {
    const legacyKey = 'flexfusion_meals_2026-11-02';
    const migrationKey = 'flexfusion_sqlite_meal_migration_v1_complete';
    final legacyMeals = jsonEncode({
      'BREAKFAST': [
        {
          'name': 'Crash Recovery Oats',
          'grams': 40,
          'kcal': 156,
          'protein': 6.76,
          'carbs': 26.52,
          'fat': 2.76,
        }
      ],
      'LUNCH': [],
      'SNACKS': [],
      'DINNER': [],
    });
    SharedPreferences.setMockInitialValues({legacyKey: legacyMeals});

    final firstOpenLogs = await appDatabase.getFoodLogsForDate('2026-11-02');
    expect(firstOpenLogs, hasLength(1));

    // Simulate a crash after SQLite committed but before the old
    // SharedPreferences completion flag was persisted.
    SharedPreferences.setMockInitialValues({legacyKey: legacyMeals});
    await appDatabase.closeForTesting();
    appDatabase = AppDatabase.forTesting(p.join(tempDirectory.path, 'test.db'));

    final reopenedLogs = await appDatabase.getFoodLogsForDate('2026-11-02');
    expect(reopenedLogs, hasLength(1));
    expect(reopenedLogs.single['food_name_snapshot'], 'Crash Recovery Oats');

    final db = await appDatabase.database;
    final marker = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [migrationKey],
      limit: 1,
    );
    expect(marker, hasLength(1));
  });


  test('version 1 database upgrades all modules to version 7 and preserves food logs', () async {
    final databasePath = p.join(tempDirectory.path, 'test.db');
    final oldDb = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
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
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY,
            display_name TEXT NOT NULL DEFAULT '',
            date_of_birth TEXT,
            height_value REAL,
            height_unit TEXT NOT NULL DEFAULT 'cm',
            current_goal TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );

    final now = DateTime.now().toIso8601String();
    final foodId = await oldDb.insert('foods', {
      'name': 'V1 Legacy Oats',
      'serving_basis_g': 100,
      'calories_per_basis': 389,
      'protein_per_basis_g': 16.9,
      'carbs_per_basis_g': 66.3,
      'fat_per_basis_g': 6.9,
      'is_custom': 1,
      'created_at': now,
      'updated_at': now,
    });
    await oldDb.insert('food_logs', {
      'log_date': '2026-11-01',
      'meal_type': 'BREAKFAST',
      'food_id': foodId,
      'food_name_snapshot': 'V1 Legacy Oats',
      'quantity_g': 40,
      'calories': 155.6,
      'protein_g': 6.76,
      'carbs_g': 26.52,
      'fat_g': 2.76,
      'created_at': now,
      'updated_at': now,
    });
    await oldDb.close();

    final upgradedDb = await appDatabase.database;
    final version = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);

    final profileColumns = await upgradedDb.rawQuery('PRAGMA table_info(user_profile)');
    expect(profileColumns.map((column) => column['name']), contains('age'));

    final foodColumns = await upgradedDb.rawQuery('PRAGMA table_info(foods)');
    expect(foodColumns.map((column) => column['name']), containsAll([
      'base_unit',
      'source',
      'source_id',
      'barcode',
      'category_id',
      'preparation_state',
      'verification_status',
      'is_active',
    ]));

    final logColumns = await upgradedDb.rawQuery('PRAGMA table_info(food_logs)');
    expect(logColumns.map((column) => column['name']), containsAll([
      'quantity_value',
      'quantity_unit',
      'base_quantity',
      'base_unit',
      'serving_name_snapshot',
    ]));

    final tables = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tableNames = tables.map((row) => row['name'] as String).toSet();
    expect(tableNames, containsAll([
      'app_settings',
      'exercises',
      'workout_plans',
      'workouts',
      'workout_sets',
      'activity_logs',
      'activity_health_daily',
    ]));

    final workoutColumns = await upgradedDb.rawQuery('PRAGMA table_info(workouts)');
    expect(workoutColumns.map((column) => column['name']),
        containsAll(['paused_at', 'paused_seconds', 'rest_ends_at']));

    final preservedFoods = await upgradedDb.query('foods', where: 'is_custom = 1');
    expect(preservedFoods, hasLength(1));
    expect(preservedFoods.single['name'], 'V1 Legacy Oats');

    final logs = await upgradedDb.query('food_logs');
    expect(logs, hasLength(1));
    expect(logs.single['food_name_snapshot'], 'V1 Legacy Oats');
    expect(logs.single['quantity_g'], 40);
    expect(logs.single['quantity_value'], 40);
    expect(logs.single['base_quantity'], 40);
    expect(logs.single['quantity_unit'], 'g');
    expect(logs.single['calories'], 155.6);
  });

  test('version 2 database upgrades to version 7 without losing food logs', () async {
    final databasePath = p.join(tempDirectory.path, 'test.db');
    final oldDb = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) async {
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
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY,
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
      },
    );

    final now = DateTime.now().toIso8601String();
    final foodId = await oldDb.insert('foods', {
      'name': 'Existing Paneer',
      'serving_basis_g': 100,
      'calories_per_basis': 265,
      'protein_per_basis_g': 18.3,
      'carbs_per_basis_g': 1.2,
      'fat_per_basis_g': 20.8,
      'is_custom': 1,
      'created_at': now,
      'updated_at': now,
    });
    await oldDb.insert('food_logs', {
      'log_date': '2026-11-01',
      'meal_type': 'DINNER',
      'food_id': foodId,
      'food_name_snapshot': 'Existing Paneer',
      'quantity_g': 120,
      'calories': 318,
      'protein_g': 21.96,
      'carbs_g': 1.44,
      'fat_g': 24.96,
      'created_at': now,
      'updated_at': now,
    });
    await oldDb.close();

    final upgradedDb = await appDatabase.database;
    final version = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);

    final workoutTables = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workout_sets'",
    );
    expect(workoutTables, hasLength(1));
    final workoutSetColumns = await upgradedDb.rawQuery('PRAGMA table_info(workout_sets)');
    expect(workoutSetColumns.map((column) => column['name']), contains('rest_seconds'));

    final preservedCustomFoods = await upgradedDb.query(
      'foods',
      where: 'is_custom = 1',
    );
    expect(preservedCustomFoods, hasLength(1));
    expect(preservedCustomFoods.single['name'], 'Existing Paneer');

    final builtInFoods = await upgradedDb.query(
      'foods',
      where: 'source = ?',
      whereArgs: ['flexfusion_catalog_v1'],
    );
    expect(builtInFoods, isEmpty);

    final logs = await upgradedDb.query('food_logs');
    expect(logs, hasLength(1));
    expect(logs.single['quantity_g'], 120);
    expect(logs.single['quantity_value'], 120);
    expect(logs.single['base_quantity'], 120);
    expect(logs.single['quantity_unit'], 'g');
    expect(logs.single['calories'], 318);
  });

  test('version 3 database upgrades workout and activity tables to version 7', () async {
    final db = await appDatabase.database;

    // Simulate the v3 schema: no v4 workout-module baseline,
    // no v5 activity tables, and no v6 pause columns.
    await db.execute('DROP TABLE activity_health_daily');
    await db.execute('DROP TABLE activity_logs');
    await db.execute('DROP TABLE workout_sets');
    await db.execute('DROP TABLE workouts');
    await db.execute('DROP TABLE workout_plan_sets');
    await db.execute('DROP TABLE workout_plan_exercises');
    await db.execute('DROP TABLE workout_plan_days');
    await db.execute('DROP TABLE workout_plans');
    await db.execute('DROP TABLE exercises');
    await db.execute('PRAGMA user_version = 3');
    await appDatabase.closeForTesting();

    final upgradedDb = await appDatabase.database;
    final version = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);

    final tables = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name'] as String).toSet();
    expect(names, containsAll([
      'exercises',
      'workout_plans',
      'workout_plan_days',
      'workout_plan_exercises',
      'workout_plan_sets',
      'workouts',
      'workout_sets',
      'activity_logs',
      'activity_health_daily',
    ]));

    final workoutColumns = await upgradedDb.rawQuery('PRAGMA table_info(workouts)');
    expect(workoutColumns.map((column) => column['name']),
        containsAll(['paused_at', 'paused_seconds', 'rest_ends_at']));
  });

  test('version 4 database upgrades activity tables and pause fields to version 7', () async {
    final db = await appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final workoutId = await db.insert('workouts', {
      'started_at': now,
      'session_name': 'Legacy v4 workout',
      'status': 'in_progress',
    });

    // A v4 database has workout tables but predates activity tables and
    // the v6 workout pause fields.
    await db.execute('DROP TABLE activity_health_daily');
    await db.execute('DROP TABLE activity_logs');
    await db.execute('ALTER TABLE workouts DROP COLUMN paused_at');
    await db.execute('ALTER TABLE workouts DROP COLUMN paused_seconds');
    await db.execute('PRAGMA user_version = 4');
    await appDatabase.closeForTesting();

    final upgradedDb = await appDatabase.database;
    final version = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);

    final activityTables = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('activity_logs', 'activity_health_daily')",
    );
    expect(activityTables.map((row) => row['name']).toSet(),
        containsAll(['activity_logs', 'activity_health_daily']));

    final workoutColumns = await upgradedDb.rawQuery('PRAGMA table_info(workouts)');
    final names = workoutColumns.map((column) => column['name'] as String).toSet();
    expect(names, containsAll(['paused_at', 'paused_seconds', 'rest_ends_at']));

    final workout = (await upgradedDb.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [workoutId],
    )).single;
    expect(workout['session_name'], 'Legacy v4 workout');
    expect(workout['paused_at'], isNull);
    expect(workout['paused_seconds'], 0);
  });

  test('version 5 database upgrades pause fields to version 7 and preserves workouts', () async {
    final db = await appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final workoutId = await db.insert('workouts', {
      'started_at': now,
      'session_name': 'Legacy v5 workout',
      'status': 'in_progress',
      'notes': 'Keep this workout',
    });

    // Convert the freshly-created schema into a v5 fixture: retain all v5
    // tables/data but remove the two columns introduced in v6.
    await db.execute('ALTER TABLE workouts DROP COLUMN paused_at');
    await db.execute('ALTER TABLE workouts DROP COLUMN paused_seconds');
    await db.execute('PRAGMA user_version = 5');
    await appDatabase.closeForTesting();

    final upgradedDb = await appDatabase.database;
    final version = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);

    final columns = await upgradedDb.rawQuery('PRAGMA table_info(workouts)');
    final names = columns.map((column) => column['name'] as String).toSet();
    expect(names, containsAll(['paused_at', 'paused_seconds', 'rest_ends_at']));

    final workout = (await upgradedDb.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [workoutId],
    )).single;
    expect(workout['session_name'], 'Legacy v5 workout');
    expect(workout['notes'], 'Keep this workout');
    expect(workout['paused_at'], isNull);
    expect(workout['paused_seconds'], 0);
  });

  test('version 6 database adds persisted rest timer field without losing workout', () async {
    final db = await appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final workoutId = await db.insert('workouts', {
      'started_at': now,
      'session_name': 'Legacy v6 workout',
      'status': 'in_progress',
    });
    await db.execute('ALTER TABLE workouts DROP COLUMN rest_ends_at');
    await db.execute('PRAGMA user_version = 6');
    await appDatabase.closeForTesting();
    final upgradedDb = await appDatabase.database;
    final version = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);
    final columns = await upgradedDb.rawQuery('PRAGMA table_info(workouts)');
    expect(columns.map((column) => column['name']), contains('rest_ends_at'));
    final workout = (await upgradedDb.query('workouts', where: 'id = ?', whereArgs: [workoutId])).single;
    expect(workout['session_name'], 'Legacy v6 workout');
    expect(workout['rest_ends_at'], isNull);
  });

  test('version 6 migration preserves all existing user data and database integrity', () async {
    final db = await appDatabase.database;
    const now = '2026-11-06T07:00:00.000';
    const workoutDate = '2026-11-05';

    final exerciseId = await db.insert('exercises', {
      'name': 'Migration Dumbbell Press',
      'muscle_group': 'Chest',
      'equipment': 'Dumbbell',
      'is_custom': 1,
      'created_at': now,
      'updated_at': now,
    });
    final planId = await db.insert('workout_plans', {
      'name': 'Migration Test Plan',
      'description': 'Must survive schema upgrade',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    final planDayId = await db.insert('workout_plan_days', {
      'plan_id': planId,
      'day_order': 1,
      'label': 'Push',
      'schedule_type': 'sequence',
      'is_rest_day': 0,
      'created_at': now,
      'updated_at': now,
    });
    final planExerciseId = await db.insert('workout_plan_exercises', {
      'plan_day_id': planDayId,
      'exercise_id': exerciseId,
      'exercise_name_snapshot': 'Migration Dumbbell Press',
      'exercise_order': 1,
      'notes': 'Preserve plan exercise',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('workout_plan_sets', {
      'plan_exercise_id': planExerciseId,
      'set_order': 1,
      'target_reps': 10,
      'target_weight': 20,
      'target_weight_unit': 'kg',
      'rest_seconds': 90,
      'created_at': now,
      'updated_at': now,
    });
    final workoutId = await db.insert('workouts', {
      'plan_id': planId,
      'plan_day_id': planDayId,
      'started_at': '${workoutDate}T07:00:00.000',
      'completed_at': '${workoutDate}T08:00:00.000',
      'session_name': 'Migration Push Workout',
      'status': 'completed',
      'notes': 'Preserve completed session',
      'paused_seconds': 15,
    });
    await db.insert('workout_sets', {
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'exercise_name_snapshot': 'Migration Dumbbell Press',
      'set_order': 1,
      'actual_reps': 10,
      'actual_weight': 20,
      'weight_unit': 'kg',
      'completed': 1,
      'rest_seconds': 90,
      'created_at': now,
    });

    await db.insert('activity_logs', {
      'activity_type': 'Walking',
      'activity_date': workoutDate,
      'started_at': '${workoutDate}T06:00:00.000',
      'duration_minutes': 35,
      'distance_km': 2.8,
      'steps': 4200,
      'active_calories': 180,
      'notes': 'Migration activity log',
      'source': 'manual',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('activity_health_daily', {
      'activity_date': workoutDate,
      'steps': 9200,
      'distance_km': 6.4,
      'active_calories': 420,
      'exercise_minutes': 45,
      'synced_at': now,
    });
    await db.insert('body_weights', {
      'log_date': workoutDate,
      'weight_value': 88.4,
      'weight_unit': 'kg',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('body_measurements', {
      'log_date': workoutDate,
      'measurement_type': 'waist',
      'value': 86,
      'unit': 'cm',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('progress_photos', {
      'photo_date': workoutDate,
      'angle': 'front',
      'local_file_path': '/tmp/migration-front.jpg',
      'created_at': now,
    });

    // Version 7 only adds workouts.rest_ends_at over version 6.
    // Downgrade this isolated fixture to the exact v6 shape before reopening.
    await db.execute('ALTER TABLE workouts DROP COLUMN rest_ends_at');
    await db.execute('PRAGMA user_version = 6');
    await appDatabase.closeForTesting();

    final upgradedDb = await appDatabase.database;
    final version = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 7);

    final workout = (await upgradedDb.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [workoutId],
    )).single;
    expect(workout['session_name'], 'Migration Push Workout');
    expect(workout['status'], 'completed');
    expect(workout['notes'], 'Preserve completed session');
    expect(workout['rest_ends_at'], isNull);

    final plan = (await upgradedDb.query(
      'workout_plans',
      where: 'id = ?',
      whereArgs: [planId],
    )).single;
    expect(plan['name'], 'Migration Test Plan');
    final planExercise = (await upgradedDb.query(
      'workout_plan_exercises',
      where: 'id = ?',
      whereArgs: [planExerciseId],
    )).single;
    expect(planExercise['exercise_name_snapshot'], 'Migration Dumbbell Press');
    expect(await upgradedDb.query(
      'workout_plan_sets',
      where: 'plan_exercise_id = ?',
      whereArgs: [planExerciseId],
    ), hasLength(1));

    final workoutSet = (await upgradedDb.query(
      'workout_sets',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    )).single;
    expect(workoutSet['actual_reps'], 10);
    expect(workoutSet['actual_weight'], 20);
    expect(workoutSet['completed'], 1);

    final activity = (await upgradedDb.query(
      'activity_logs',
      where: 'activity_date = ?',
      whereArgs: [workoutDate],
    )).single;
    expect(activity['steps'], 4200);
    expect(activity['distance_km'], 2.8);
    final healthSummary = (await upgradedDb.query(
      'activity_health_daily',
      where: 'activity_date = ?',
      whereArgs: [workoutDate],
    )).single;
    expect(healthSummary['steps'], 9200);
    expect(healthSummary['active_calories'], 420);

    final weight = (await upgradedDb.query(
      'body_weights',
      where: 'log_date = ?',
      whereArgs: [workoutDate],
    )).single;
    expect(weight['weight_value'], 88.4);
    final measurement = (await upgradedDb.query(
      'body_measurements',
      where: 'log_date = ?',
      whereArgs: [workoutDate],
    )).single;
    expect(measurement['value'], 86);
    final photo = (await upgradedDb.query(
      'progress_photos',
      where: 'photo_date = ?',
      whereArgs: [workoutDate],
    )).single;
    expect(photo['local_file_path'], '/tmp/migration-front.jpg');
    expect(photo['angle'], 'front');

    final indexes = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final indexNames = indexes.map((row) => row['name'] as String).toSet();
    expect(indexNames, containsAll([
      'idx_workouts_started_at',
      'idx_activity_logs_date',
      'idx_food_logs_date',
      'idx_food_logs_date_meal',
    ]));

    final foreignKeyViolations = await upgradedDb.rawQuery('PRAGMA foreign_key_check');
    expect(foreignKeyViolations, isEmpty);
  });

  test('rest timer end timestamp persists on the active workout', () async {
    final workoutId = await appDatabase.startWorkoutSession(sessionName: 'Rest timer test');
    final end = DateTime.now().add(const Duration(seconds: 90));
    await appDatabase.saveWorkoutRestEnd(workoutId, end);
    expect(await appDatabase.getWorkoutRestEnd(workoutId), end);
    await appDatabase.saveWorkoutRestEnd(workoutId, null);
    expect(await appDatabase.getWorkoutRestEnd(workoutId), isNull);
  });

  test('only one workout session can be in progress at a time', () async {
    final firstId = await appDatabase.startWorkoutSession(
      sessionName: 'First session',
    );

    await expectLater(
      appDatabase.startWorkoutSession(sessionName: 'Second session'),
      throwsA(isA<StateError>()),
    );

    final active = await appDatabase.getInProgressWorkout();
    expect(active?['id'], firstId);
    expect(active?['session_name'], 'First session');
  });

  test('finishing a workout advances its sequence only once', () async {
    final planId = await appDatabase.createWorkoutPlan('Sequence test');
    await appDatabase.setActiveWorkoutPlan(planId);
    final firstDayId = await appDatabase.addWorkoutPlanDay(
      planId: planId,
      label: 'Day 1',
      dayOrder: 1,
    );
    final secondDayId = await appDatabase.addWorkoutPlanDay(
      planId: planId,
      label: 'Day 2',
      dayOrder: 2,
    );
    await appDatabase.addExerciseToPlanDay(
      dayId: firstDayId,
      exerciseName: 'Sequence test press',
      exerciseOrder: 1,
      setCount: 1,
      targetReps: 10,
      targetWeight: 20,
    );

    final workoutId = await appDatabase.startWorkoutSession(
      planId: planId,
      planDayId: firstDayId,
      sessionName: 'Day 1',
    );
    final sets = await appDatabase.getWorkoutSessionSets(workoutId);
    await appDatabase.updateWorkoutSet(
      id: sets.single['id'] as int,
      reps: 10,
      weight: 20,
      completed: true,
    );
    final db = await appDatabase.database;
    await db.update(
      'workouts',
      {'started_at': DateTime.now().subtract(const Duration(seconds: 65)).toIso8601String()},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
    await appDatabase.finishWorkoutSession(workoutId);
    await appDatabase.finishWorkoutSession(workoutId);

    final suggestedToday = await appDatabase.getSuggestedWorkoutDay();
    expect(suggestedToday, isNull);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayIso = DateTime(yesterday.year, yesterday.month, yesterday.day, 12).toIso8601String();
    final yesterdayStartIso = DateTime(yesterday.year, yesterday.month, yesterday.day, 11).toIso8601String();
    await db.update(
      'workouts',
      {'started_at': yesterdayStartIso, 'completed_at': yesterdayIso},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
    final suggestedNextEligibleDay = await appDatabase.getSuggestedWorkoutDay();
    expect(suggestedNextEligibleDay?['id'], secondDayId);
  });

  test('replacing a progress photo returns the previous local path', () async {
    final firstPrevious = await appDatabase.saveProgressPhoto(
      date: '2026-11-03',
      angle: 'front',
      localFilePath: '/tmp/front-first.jpg',
    );
    expect(firstPrevious, isNull);

    final secondPrevious = await appDatabase.saveProgressPhoto(
      date: '2026-11-03',
      angle: 'front',
      localFilePath: '/tmp/front-second.jpg',
    );
    expect(secondPrevious, '/tmp/front-first.jpg');

    final photos = await appDatabase.getProgressPhotos();
    expect(photos, hasLength(1));
    expect(photos.single['local_file_path'], '/tmp/front-second.jpg');
  });

  test('weekly progress day labels match their actual dates', () async {
    final progress = await appDatabase.getWeeklyProgressDetails();
    final daily = progress['daily'] as List<Map<String, Object?>>;
    expect(daily, hasLength(7));
    for (final row in daily) {
      final date = DateTime.parse(row['date'] as String);
      final expected = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];
      expect(row['day'], expected);
    }
  });

  test('foreign key check reports no violations', () async {
    final db = await appDatabase.database;
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    expect(violations, isEmpty);
  });
}
