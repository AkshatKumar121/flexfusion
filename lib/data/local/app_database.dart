import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;

import 'app_database_schema.dart';

part 'app_database_food.dart';
part 'app_database_progress.dart';
part 'app_database_workouts.dart';
part 'app_database_activity.dart';

class AppDatabase {
  AppDatabase._({this._databasePathOverride});

  @visibleForTesting
  AppDatabase.forTesting(String databasePath)
      : this._(databasePathOverride: databasePath);

  static final AppDatabase _defaultInstance = AppDatabase._();
  static AppDatabase? _testingInstance;

  static AppDatabase get instance => _testingInstance ?? _defaultInstance;

  @visibleForTesting
  static void setInstanceForTesting(AppDatabase? value) {
    _testingInstance = value;
  }

  @visibleForTesting
  Future<void> closeForTesting() async {
    await _database?.close();
    _database = null;
  }

  static const int schemaVersion = 7;
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
      onCreate: AppDatabaseSchema.createSchema,
      onUpgrade: AppDatabaseSchema.upgradeSchema,
    );
    await _migrateLegacyMealLogs(_database!);
    await _clearBuiltInFoodCatalog(_database!);
    await _seedBuiltInExerciseCatalog(_database!);
    return _database!;
  }

  Future<void> _seedBuiltInExerciseCatalog(Database db) async {
    const seedKey = 'exercise_catalog_v1_seeded';
    final settings = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [seedKey],
      limit: 1,
    );
    if (settings.isNotEmpty && settings.first['value'] == '1') return;

    final source = await rootBundle.loadString('assets/data/exercise_catalog.json');
    final catalog = jsonDecode(source) as List<dynamic>;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final item in catalog) {
        final exercise = item as Map<String, dynamic>;
        final name = exercise['name'] as String;
        final existing = await txn.query(
          'exercises',
          columns: ['id'],
          where: 'name = ? COLLATE NOCASE',
          whereArgs: [name],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        await txn.insert('exercises', {
          'name': name,
          'muscle_group': exercise['muscle_group'],
          'equipment': exercise['equipment'],
          'instructions': exercise['instructions'],
          'is_custom': 0,
          'created_at': now,
          'updated_at': now,
        });
      }
      await txn.insert(
        'app_settings',
        {'key': seedKey, 'value': '1', 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Removes the imported built-in catalogue once while preserving user data.
  ///
  /// Food logs keep their nutrition/name snapshots; the FK sets food_id to null.
  /// User-created foods remain available in the Custom Food flow.
  Future<void> _clearBuiltInFoodCatalog(Database db) async {
    const cleanupKey = 'flexfusion_builtin_food_catalog_cleared_v1';
    final marker = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [cleanupKey],
      limit: 1,
    );
    if (marker.isNotEmpty && marker.first['value'] == '1') return;

    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('foods', where: 'is_custom = 0');
      await txn.insert(
        'app_settings',
        {'key': cleanupKey, 'value': '1', 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    debugPrint('FlexFusion built-in food catalogue cleared.');
  }

  Future<void> _migrateLegacyMealLogs(Database db) async {
    const migrationKey = 'flexfusion_sqlite_meal_migration_v1_complete';
    final preferences = await SharedPreferences.getInstance();
    final completed = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [migrationKey],
      limit: 1,
    );
    if (completed.isNotEmpty) return;

    if (preferences.getBool(migrationKey) == true) {
      await db.insert(
        'app_settings',
        {
          'key': migrationKey,
          'value': '1',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final keys = preferences.getKeys()
        .where((key) => key.startsWith('flexfusion_meals_'))
        .toList()
      ..sort();

    await db.transaction((txn) async {
      final marker = await txn.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [migrationKey],
        limit: 1,
      );
      if (marker.isNotEmpty) return;

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
              final timestamp = DateTime.now().toIso8601String();
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
                'created_at': timestamp,
                'updated_at': timestamp,
              });
            }
          }
        } catch (error) {
          debugPrint('Skipped invalid legacy meal data for $date: $error');
        }
      }

      await txn.insert(
        'app_settings',
        {
          'key': migrationKey,
          'value': '1',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    await preferences.setBool(migrationKey, true);
  }
}
