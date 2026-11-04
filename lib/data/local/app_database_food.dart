part of 'app_database.dart';

extension AppDatabaseFood on AppDatabase {
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

    // Keep the completion marker in SQLite so imported rows and the marker
    // commit atomically. SharedPreferences alone leaves a crash window where
    // rows are committed but the marker is not, causing duplicate imports.
    final completed = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [migrationKey],
      limit: 1,
    );
    if (completed.isNotEmpty) return;

    // Upgrade installations that used the old preference-only marker.
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
      // Recheck inside the transaction in case another initialization path
      // completed this migration while the preference keys were collected.
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

    // Retain the old marker for compatibility, but SQLite is authoritative.
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

  Future<void> updateFoodLog({
    required int id,
    required double grams,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final db = await database;
    await db.update('food_logs', {
      'quantity_g': grams,
      'quantity_value': grams,
      'base_quantity': grams,
      'calories': calories,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
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
}
