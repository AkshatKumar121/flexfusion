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

  test('fresh database creates the complete V1 schema at version 6', () async {
    final db = await appDatabase.database;
    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 6);

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

  test('version 2 database upgrades to version 6 without losing food logs', () async {
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
    expect(version.single['user_version'], 6);

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
    expect(builtInFoods, hasLength(1014));

    final logs = await upgradedDb.query('food_logs');
    expect(logs, hasLength(1));
    expect(logs.single['quantity_g'], 120);
    expect(logs.single['quantity_value'], 120);
    expect(logs.single['base_quantity'], 120);
    expect(logs.single['quantity_unit'], 'g');
    expect(logs.single['calories'], 318);
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

    final workoutId = await appDatabase.startWorkoutSession(
      planId: planId,
      planDayId: firstDayId,
      sessionName: 'Day 1',
    );
    await appDatabase.finishWorkoutSession(workoutId);
    await appDatabase.finishWorkoutSession(workoutId);

    final suggested = await appDatabase.getSuggestedWorkoutDay();
    expect(suggested?['id'], secondDayId);
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
