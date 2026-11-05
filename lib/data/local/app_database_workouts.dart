part of 'app_database.dart';

extension AppDatabaseWorkouts on AppDatabase {
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
      final active = await txn.query(
        'workouts',
        columns: ['id'],
        where: "status = 'in_progress'",
        limit: 1,
      );
      if (active.isNotEmpty) {
        throw StateError(
          'A workout is already in progress. Resume or abandon it before starting another.',
        );
      }
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
              'rest_seconds': set['rest_seconds'] ?? 90,
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
    int restSeconds = 90,
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
          'rest_seconds': restSeconds,
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
    await db.transaction((txn) async {
      final rows = await txn.query(
        'workouts',
        columns: ['status', 'plan_id', 'plan_day_id'],
        where: 'id = ?',
        whereArgs: [workoutId],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['status'] != 'in_progress') return;

      final pausedAt = rows.first['paused_at'] as String?;
      final existingPausedSeconds = rows.first['paused_seconds'] as int? ?? 0;
      final pausedDuration = pausedAt == null
          ? 0
          : DateTime.now().difference(DateTime.tryParse(pausedAt) ?? DateTime.now()).inSeconds;
      final updated = await txn.update(
        'workouts',
        {
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
          'notes': notes,
          'paused_at': null,
          'rest_ends_at': null,
          'paused_seconds': existingPausedSeconds + (pausedDuration > 0 ? pausedDuration : 0),
        },
        where: "id = ? AND status = 'in_progress'",
        whereArgs: [workoutId],
      );
      if (updated == 0) return;

      final planId = rows.first['plan_id'] as int?;
      final dayId = rows.first['plan_day_id'] as int?;
      if (planId == null || dayId == null) return;

      final currentRows = await txn.query(
        'workout_plan_days',
        columns: ['schedule_type'],
        where: 'id = ?',
        whereArgs: [dayId],
        limit: 1,
      );
      if (currentRows.isEmpty || currentRows.first['schedule_type'] == 'weekday') return;

      final days = await txn.query(
        'workout_plan_days',
        where: "plan_id = ? AND schedule_type != 'weekday'",
        whereArgs: [planId],
        orderBy: 'day_order, id',
      );
      if (days.isEmpty) return;

      final currentIndex = days.indexWhere((day) => day['id'] == dayId);
      final next = days[(currentIndex < 0 ? 0 : currentIndex + 1) % days.length];
      final key = 'workout_plan_sequence_$planId';
      await txn.insert(
        'app_settings',
        {
          'key': key,
          'value': (next['id'] as int).toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteWorkoutSession(int workoutId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('workout_sets', where: 'workout_id = ?', whereArgs: [workoutId]);
      await txn.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
    });
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

  Future<void> saveWorkoutRestEnd(int workoutId, DateTime? endsAt) async {
    final db = await database;
    await db.update(
      'workouts',
      {'rest_ends_at': endsAt?.toIso8601String()},
      where: "id = ? AND status = 'in_progress'",
      whereArgs: [workoutId],
    );
  }

  Future<DateTime?> getWorkoutRestEnd(int workoutId) async {
    final db = await database;
    final rows = await db.query(
      'workouts',
      columns: ['rest_ends_at'],
      where: 'id = ?',
      whereArgs: [workoutId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['rest_ends_at'] as String? ?? '');
  }

  Future<Map<String, Object?>?> getCompletedWorkoutToday() async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day + 1).toIso8601String();
    final rows = await db.query(
      'workouts',
      where: "status = 'completed' AND completed_at >= ? AND completed_at < ?",
      whereArgs: [start, end],
      orderBy: 'completed_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
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

  Future<void> advanceWorkoutPlanSequence(int planId, int currentDayId) async {
    final db = await database;
    final currentRows = await db.query('workout_plan_days', columns: ['schedule_type'], where: 'id = ?', whereArgs: [currentDayId], limit: 1);
    if (currentRows.isEmpty || currentRows.first['schedule_type'] == 'weekday') return;
    final days = await db.query('workout_plan_days', where: "plan_id = ? AND schedule_type != 'weekday'", whereArgs: [planId], orderBy: 'day_order, id');
    if (days.isEmpty) return;
    final currentIndex = days.indexWhere((day) => day['id'] == currentDayId);
    final next = days[(currentIndex < 0 ? 0 : currentIndex + 1) % days.length];
    await saveAppSetting('workout_plan_sequence_$planId', (next['id'] as int).toString());
  }

  // Manual starts from the Train screen may use the active plan even when
  // today's scheduled slot has already been completed.
  Future<Map<String, Object?>?> getManualStartWorkoutDay() async {
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
    if (days.isEmpty) return {...plan, 'plan_name': plan['name'], 'plan_id': plan['id'], 'no_days': true};

    final today = DateTime.now().weekday;
    final fixedToday = days.where((day) =>
        day['schedule_type'] == 'weekday' && day['weekday'] == today).toList();
    if (fixedToday.isNotEmpty) {
      return {...fixedToday.first, 'plan_name': plan['name'], 'plan_id': plan['id']};
    }

    final sequenceDays = days.where((day) => day['schedule_type'] != 'weekday').toList();
    if (sequenceDays.isNotEmpty) {
      final pointer = await db.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['workout_plan_sequence_${plan['id']}'],
        limit: 1,
      );
      var nextIndex = 0;
      if (pointer.isNotEmpty) {
        final pointerId = int.tryParse(pointer.first['value'] as String? ?? '');
        final pointerIndex = sequenceDays.indexWhere((day) => day['id'] == pointerId);
        if (pointerIndex >= 0) nextIndex = pointerIndex;
      } else {
        final previous = await db.query(
          'workouts',
          where: "plan_id = ? AND status = 'completed' AND plan_day_id IS NOT NULL",
          whereArgs: [plan['id']],
          orderBy: 'completed_at DESC, id DESC',
          limit: 1,
        );
        if (previous.isNotEmpty) {
          final lastIndex = sequenceDays.indexWhere((day) => day['id'] == previous.first['plan_day_id']);
          if (lastIndex >= 0) nextIndex = (lastIndex + 1) % sequenceDays.length;
        }
      }
      return {...sequenceDays[nextIndex], 'plan_name': plan['name'], 'plan_id': plan['id']};
    }

    // Fixed-weekday plans can still be started manually on a different day.
    return {...days.first, 'plan_name': plan['name'], 'plan_id': plan['id']};
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

    // A sequence plan advances after completion, but its next item is not
    // eligible until the next local calendar day.
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final completedToday = await db.query(
      'workouts',
      columns: ['id'],
      where: "plan_id = ? AND status = 'completed' AND completed_at >= ? AND completed_at < ?",
      whereArgs: [plan['id'], todayStart, tomorrowStart],
      limit: 1,
    );
    if (completedToday.isNotEmpty) return null;

    final pointer = await db.query('app_settings', columns: ['value'], where: 'key = ?', whereArgs: ['workout_plan_sequence_${plan['id']}'], limit: 1);
    var nextIndex = 0;
    if (pointer.isNotEmpty) {
      final pointerId = int.tryParse(pointer.first['value'] as String? ?? '');
      final pointerIndex = sequenceDays.indexWhere((day) => day['id'] == pointerId);
      if (pointerIndex >= 0) nextIndex = pointerIndex;
    } else {
      final previous = await db.query(
        'workouts',
        where: "plan_id = ? AND status = 'completed' AND plan_day_id IS NOT NULL",
        whereArgs: [plan['id']],
        orderBy: 'completed_at DESC, id DESC',
        limit: 1,
      );
      if (previous.isNotEmpty) {
        final lastIndex = sequenceDays.indexWhere((day) => day['id'] == previous.first['plan_day_id']);
        if (lastIndex >= 0) nextIndex = (lastIndex + 1) % sequenceDays.length;
      }
    }
    return {...sequenceDays[nextIndex], 'plan_name': plan['name'], 'plan_id': plan['id']};
  }


  Future<void> pauseWorkoutSession(int workoutId) async {
    final db = await database;
    await db.update(
      'workouts',
      {'paused_at': DateTime.now().toIso8601String()},
      where: "id = ? AND status = 'in_progress' AND paused_at IS NULL",
      whereArgs: [workoutId],
    );
  }

  Future<void> resumeWorkoutSession(int workoutId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'workouts',
        columns: ['paused_at', 'paused_seconds'],
        where: "id = ? AND status = 'in_progress'",
        whereArgs: [workoutId],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['paused_at'] == null) return;
      final pausedAt = DateTime.tryParse(rows.first['paused_at'] as String);
      if (pausedAt == null) return;
      final previousPausedSeconds = rows.first['paused_seconds'] as int? ?? 0;
      final addedSeconds = DateTime.now().difference(pausedAt).inSeconds;
      await txn.update(
        'workouts',
        {
          'paused_at': null,
          'paused_seconds': previousPausedSeconds + (addedSeconds > 0 ? addedSeconds : 0),
        },
        where: 'id = ?',
        whereArgs: [workoutId],
      );
    });
  }

  /// Returns workout sessions and their set-level records for the last 14
  /// calendar days. The first 7 days are used for the current report and the
  /// preceding 7 days provide the comparison baseline.
  Future<List<Map<String, Object?>>> getWorkoutAnalysisRows({DateTime? now}) async {
    final db = await database;
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final rangeStart = today.subtract(const Duration(days: 13));
    final rangeEnd = today.add(const Duration(days: 1));
    return db.rawQuery(
      '''
      SELECT
        w.id AS workout_id,
        w.session_name,
        w.started_at,
        w.completed_at,
        w.status,
        w.paused_seconds,
        w.paused_at,
        s.id AS set_id,
        s.exercise_id,
        s.exercise_name_snapshot,
        s.set_order,
        s.actual_reps,
        s.actual_weight,
        s.weight_unit,
        s.completed AS set_completed,
        e.muscle_group
      FROM workouts w
      LEFT JOIN workout_sets s ON s.workout_id = w.id
      LEFT JOIN exercises e ON e.id = s.exercise_id
      WHERE w.started_at >= ? AND w.started_at < ?
        AND (w.status != 'abandoned' OR EXISTS (
          SELECT 1 FROM workout_sets sx
          WHERE sx.workout_id = w.id AND sx.completed = 1
        ))
      ORDER BY w.started_at DESC, w.id DESC, s.id ASC
      ''',
      [rangeStart.toIso8601String(), rangeEnd.toIso8601String()],
    );
  }

  /// Returns all recorded sessions for one exercise, newest first.
  /// Set details are preserved from workout-time snapshots.
  Future<List<Map<String, Object?>>> getExercisePerformanceHistory(
    String exerciseName,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT
        w.id AS workout_id,
        w.session_name,
        w.started_at,
        w.completed_at,
        w.status,
        s.id AS set_id,
        s.set_order,
        s.actual_reps,
        s.actual_weight,
        s.weight_unit,
        s.completed AS set_completed
      FROM workouts w
      INNER JOIN workout_sets s ON s.workout_id = w.id
      WHERE LOWER(TRIM(s.exercise_name_snapshot)) = LOWER(TRIM(?))
        AND s.completed = 1
        AND w.status != 'abandoned'
      ORDER BY w.started_at DESC, w.id DESC, s.set_order ASC, s.id ASC
      ''',
      [exerciseName],
    );
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


  Future<void> substitutePlanExercise({
    required int planExerciseId,
    required int exerciseId,
    required String exerciseName,
  }) async {
    final db = await database;
    await db.update('workout_plan_exercises', {
      'exercise_id': exerciseId,
      'exercise_name_snapshot': exerciseName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [planExerciseId]);
  }
}
