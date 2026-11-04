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

  static final AppDatabase instance = AppDatabase._();
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
    await _seedBuiltInFoodCatalog(_database!);
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


}
