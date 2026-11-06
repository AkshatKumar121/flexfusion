part of 'app_database.dart';

extension AppDatabaseProgress on AppDatabase {
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

    final startKey = dateKey(start);
    final endKey = dateKey(end);
    final previousStartKey = dateKey(previousStart);

    // Fetch each dataset in one grouped query instead of issuing queries
    // separately for every day on the dashboard.
    final results = await Future.wait([
      db.rawQuery(
        '''
        SELECT log_date, SUM(calories) AS calories, SUM(protein_g) AS protein
        FROM food_logs
        WHERE log_date >= ? AND log_date <= ?
        GROUP BY log_date
        ''',
        [previousStartKey, endKey],
      ),
      db.query(
        'body_weights',
        columns: ['log_date', 'weight_value'],
        where: 'log_date >= ? AND log_date <= ?',
        whereArgs: [previousStartKey, endKey],
      ),
      db.rawQuery(
        '''
        SELECT substr(completed_at, 1, 10) AS workout_date, COUNT(*) AS total
        FROM workouts
        WHERE status = 'completed'
          AND substr(completed_at, 1, 10) >= ?
          AND substr(completed_at, 1, 10) <= ?
        GROUP BY substr(completed_at, 1, 10)
        ''',
        [previousStartKey, endKey],
      ),
    ]);

    final nutritionByDate = {
      for (final row in results[0]) row['log_date'] as String: row,
    };
    final weightByDate = {
      for (final row in results[1]) row['log_date'] as String: row,
    };
    final workoutsByDate = {
      for (final row in results[2]) row['workout_date'] as String: row,
    };

    final daily = <Map<String, Object?>>[];
    for (var offset = 0; offset < 7; offset++) {
      final date = start.add(Duration(days: offset));
      final key = dateKey(date);
      final nutrition = nutritionByDate[key];
      final weight = weightByDate[key];
      daily.add({
        'date': key,
        'day': ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
        'calories': (nutrition?['calories'] as num? ?? 0).toDouble(),
        'protein': (nutrition?['protein'] as num? ?? 0).toDouble(),
        'weight': weight == null ? null : (weight['weight_value'] as num).toDouble(),
        'workouts': (workoutsByDate[key]?['total'] as num? ?? 0).toInt(),
      });
    }

    double averageForNutrition(DateTime from, DateTime to, String field) {
      final values = nutritionByDate.entries
          .where((entry) => entry.key.compareTo(dateKey(from)) >= 0 &&
              entry.key.compareTo(dateKey(to)) <= 0)
          .map((entry) => (entry.value[field] as num).toDouble())
          .toList();
      return values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
    }

    int nutritionDays(DateTime from, DateTime to) => nutritionByDate.keys
        .where((key) => key.compareTo(dateKey(from)) >= 0 &&
            key.compareTo(dateKey(to)) <= 0)
        .length;

    final currentWeights = results[1].where((row) =>
        (row['log_date'] as String).compareTo(startKey) >= 0).toList();
    final previousWeights = results[1].where((row) =>
        (row['log_date'] as String).compareTo(previousStartKey) >= 0 &&
        (row['log_date'] as String).compareTo(startKey) < 0).toList();

    double averageWeight(List<Map<String, Object?>> rows) => rows.isEmpty
        ? 0
        : rows.map((row) => (row['weight_value'] as num).toDouble())
            .reduce((a, b) => a + b) / rows.length;

    int workoutCount(DateTime from, DateTime to) => workoutsByDate.entries
        .where((entry) => entry.key.compareTo(dateKey(from)) >= 0 &&
            entry.key.compareTo(dateKey(to)) <= 0)
        .fold<int>(0, (total, entry) => total + (entry.value['total'] as num).toInt());

    return {
      'start_date': startKey,
      'end_date': endKey,
      'daily': daily,
      'tracked_days': nutritionDays(start, end),
      'average_calories': averageForNutrition(start, end, 'calories'),
      'average_protein': averageForNutrition(start, end, 'protein'),
      'previous_tracked_days': nutritionDays(previousStart, start.subtract(const Duration(days: 1))),
      'previous_average_calories': averageForNutrition(previousStart, start.subtract(const Duration(days: 1)), 'calories'),
      'previous_average_protein': averageForNutrition(previousStart, start.subtract(const Duration(days: 1)), 'protein'),
      'weight_days': currentWeights.length,
      'average_weight': averageWeight(currentWeights),
      'previous_weight_days': previousWeights.length,
      'previous_average_weight': averageWeight(previousWeights),
      'workouts': workoutCount(start, end),
      'previous_workouts': workoutCount(previousStart, start.subtract(const Duration(days: 1))),
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


  Future<Map<String, Object?>?> getBodyWeightForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'body_weights',
      where: 'log_date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveBodyWeight({
    required String date,
    required double weightKg,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'body_weights',
        columns: ['id'],
        where: 'log_date = ?',
        whereArgs: [date],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.update(
          'body_weights',
          {
            'weight_value': weightKg,
            'weight_unit': 'kg',
            'updated_at': now,
          },
          where: 'log_date = ?',
          whereArgs: [date],
        );
      } else {
        await txn.insert('body_weights', {
          'log_date': date,
          'weight_value': weightKg,
          'weight_unit': 'kg',
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> getProgressPhotos({int limit = 12}) async {
    final db = await database;
    return db.query(
      'progress_photos',
      orderBy: 'photo_date DESC, id DESC',
      limit: limit,
    );
  }

  Future<void> deleteProgressPhoto(int id) async {
    final db = await database;
    await db.delete('progress_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> saveProgressPhoto({
    required String date,
    required String angle,
    required String localFilePath,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'progress_photos',
        columns: ['local_file_path'],
        where: 'photo_date = ? AND angle = ?',
        whereArgs: [date, angle],
        limit: 1,
      );
      await txn.insert(
        'progress_photos',
        {
          'photo_date': date,
          'angle': angle,
          'local_file_path': localFilePath,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return existing.isEmpty ? null : existing.first['local_file_path'] as String?;
    });
  }


  // Workout plan and exercise library operations.
}
