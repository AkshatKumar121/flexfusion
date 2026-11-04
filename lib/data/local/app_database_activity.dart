part of 'app_database.dart';

extension AppDatabaseActivity on AppDatabase {
  Future<int> saveActivityLog({int? id, required String activityType, required String activityDate, String? startedAt, required int durationMinutes, double? distanceKm, int? steps, double? activeCalories, String? notes}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{'activity_type': activityType, 'activity_date': activityDate, 'started_at': startedAt, 'duration_minutes': durationMinutes, 'distance_km': distanceKm, 'steps': steps, 'active_calories': activeCalories, 'notes': notes, 'source': 'manual', 'updated_at': now};
    if (id == null) { values['created_at'] = now; return db.insert('activity_logs', values); }
    await db.update('activity_logs', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }
  Future<void> deleteActivityLog(int id) async { final db = await database; await db.delete('activity_logs', where: 'id = ?', whereArgs: [id]); }
  Future<List<Map<String, Object?>>> getActivityLogs(String date) async { final db = await database; return db.query('activity_logs', where: 'activity_date = ?', whereArgs: [date], orderBy: 'started_at DESC, id DESC'); }
  Future<List<Map<String, Object?>>> getActivityHistory({int days = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days - 1)).toIso8601String().substring(0, 10);
    return db.query('activity_logs', where: 'activity_date >= ?', whereArgs: [cutoff], orderBy: 'activity_date DESC, started_at DESC');
  }
  Future<void> saveHealthActivitySummary({required String date, int? steps, double? distanceKm, double? activeCalories, double? exerciseMinutes}) async {
    final db = await database;
    await db.insert('activity_health_daily', {'activity_date': date, 'steps': steps, 'distance_km': distanceKm, 'active_calories': activeCalories, 'exercise_minutes': exerciseMinutes, 'synced_at': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<Map<String, Object?>?> getHealthActivitySummary(String date) async {
    final db = await database;
    final rows = await db.query('activity_health_daily', where: 'activity_date = ?', whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>> getTrainingStreakData() async {
    final db = await database;
    final stepGoal = int.tryParse(await getAppSetting('daily_step_goal', defaultValue: '10000')) ?? 10000;
    final workouts = await db.rawQuery("""
      SELECT DISTINCT substr(COALESCE(completed_at, started_at), 1, 10) AS day
      FROM workouts
      WHERE EXISTS (
        SELECT 1
        FROM workout_sets
        WHERE workout_sets.workout_id = workouts.id
          AND workout_sets.completed = 1
      )
    """);
    final activities = await db.rawQuery("""
      SELECT DISTINCT activity_date AS day
      FROM activity_logs
    """);
    final health = await db.rawQuery("""
      SELECT activity_date AS day, steps
      FROM activity_health_daily
      WHERE steps IS NOT NULL
    """);
    final manualSteps = await db.rawQuery("""
      SELECT activity_date AS day, SUM(steps) AS steps
      FROM activity_logs
      WHERE steps IS NOT NULL
      GROUP BY activity_date
    """);
    final stepGoalDays = await db.rawQuery("""
      WITH manual_daily AS (
        SELECT activity_date, SUM(steps) AS steps
        FROM activity_logs
        WHERE steps IS NOT NULL
        GROUP BY activity_date
      )
      SELECT health.activity_date AS day
      FROM activity_health_daily health
      LEFT JOIN manual_daily
        ON manual_daily.activity_date = health.activity_date
      WHERE CASE
        WHEN health.steps > 0 THEN health.steps
        ELSE COALESCE(manual_daily.steps, 0)
      END >= ?
      UNION
      SELECT manual_daily.activity_date AS day
      FROM manual_daily
      LEFT JOIN activity_health_daily health
        ON health.activity_date = manual_daily.activity_date
      WHERE health.activity_date IS NULL
        AND manual_daily.steps >= ?
    """, [stepGoal, stepGoal]);
    return {
      'workout_days': workouts.map((row) => row['day'] as String).toList(),
      'activity_days': activities.map((row) => row['day'] as String).toList(),
      'step_goal': stepGoal,
      'step_goal_days': stepGoalDays.map((row) => row['day'] as String).toList(),
      'health_steps': {
        for (final row in health)
          row['day'] as String: (row['steps'] as num).toInt(),
      },
      'manual_steps': {
        for (final row in manualSteps)
          row['day'] as String: (row['steps'] as num).toInt(),
      },
    };
  }

  Future<List<Map<String, Object?>>> getNutritionStreakDays() async {
    final db = await database;
    return db.rawQuery("""
      WITH daily_logs AS (
        SELECT
          log_date AS day,
          SUM(calories) AS calories,
          SUM(protein_g) AS protein
        FROM food_logs
        GROUP BY log_date
      ),
      streak_days AS (
        SELECT day, calories, protein FROM daily_logs
        UNION ALL
        SELECT date('now', 'localtime') AS day, 0 AS calories, 0 AS protein
        WHERE NOT EXISTS (
          SELECT 1 FROM daily_logs
          WHERE day = date('now', 'localtime')
        )
      )
      SELECT
        streak_days.day AS day,
        streak_days.calories AS calories,
        streak_days.protein AS protein,
        COALESCE(
          (SELECT nt.calorie_target FROM nutrition_targets nt
           WHERE nt.effective_from <= streak_days.day
           ORDER BY nt.effective_from DESC, nt.id DESC LIMIT 1),
          2200
        ) AS calorie_target,
        COALESCE(
          (SELECT nt.protein_target_g FROM nutrition_targets nt
           WHERE nt.effective_from <= streak_days.day
           ORDER BY nt.effective_from DESC, nt.id DESC LIMIT 1),
          180
        ) AS protein_target
      FROM streak_days
      ORDER BY streak_days.day DESC
    """);
  }
}
