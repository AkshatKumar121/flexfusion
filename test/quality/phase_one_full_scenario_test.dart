import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flexfusion/data/local/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late AppDatabase db;

  String key(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_phase1_full_');
    db = AppDatabase.forTesting(p.join(tempDirectory.path, 'phase1.db'));
  });

  tearDown(() async {
    await db.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  group('Eat and nutrition scenarios', () {
    test('custom food is created, updated case-insensitively and listed once', () async {
      final first = await db.insertCustomFood(
        name: ' QA Paneer ',
        caloriesPer100g: 265,
        proteinPer100g: 18,
        carbsPer100g: 1,
        fatPer100g: 21,
      );
      final second = await db.insertCustomFood(
        name: 'qa paneer',
        caloriesPer100g: 250,
        proteinPer100g: 20,
        carbsPer100g: 2,
        fatPer100g: 19,
      );

      expect(second, first);
      final foods = await db.getCustomFoods();
      final match = foods.singleWhere((food) => food['id'] == first);
      expect(match['name'], 'qa paneer');
      expect(match['calories_per_basis'], 250);
      expect(match['protein_per_basis_g'], 20);
      expect(match['is_custom'], 1);
    });

    test('food logs are isolated by date and returned in meal order', () async {
      final today = key(DateTime.now());
      final yesterday = key(DateTime.now().subtract(const Duration(days: 1)));
      for (final meal in ['DINNER', 'SNACKS', 'LUNCH', 'BREAKFAST']) {
        await db.insertFoodLog(
          date: today,
          meal: meal,
          name: 'QA $meal',
          grams: 100,
          calories: 100,
          protein: 10,
          carbs: 10,
          fat: 5,
        );
      }
      await db.insertFoodLog(
        date: yesterday,
        meal: 'BREAKFAST',
        name: 'Yesterday only',
        grams: 100,
        calories: 50,
        protein: 5,
        carbs: 5,
        fat: 2,
      );

      final rows = await db.getFoodLogsForDate(today);
      expect(rows.map((row) => row['meal_type']).toList(),
          ['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER']);
      expect(rows, hasLength(4));
      expect(await db.getFoodLogsForDate(yesterday), hasLength(1));
    });

    test('food quantity edits recalculate all dashboard macros and deletion reverses them', () async {
      final today = key(DateTime.now());
      final id = await db.insertFoodLog(
        date: today,
        meal: 'BREAKFAST',
        name: 'QA Oats',
        grams: 50,
        calories: 195,
        protein: 8,
        carbs: 33,
        fat: 3.5,
      );
      await db.updateFoodLog(
        id: id,
        grams: 75,
        calories: 292.5,
        protein: 12,
        carbs: 49.5,
        fat: 5.25,
      );
      var totals = await db.getDashboardNutrition(today);
      expect(totals['calories'], 292.5);
      expect(totals['protein'], 12);
      expect(totals['carbs'], 49.5);
      expect(totals['fat'], 5.25);

      expect(await db.deleteFoodLog(id), 1);
      totals = await db.getDashboardNutrition(today);
      expect(totals.values, everyElement(0));
      expect(await db.getFoodLogsForDate(today), isEmpty);
    });

    test('empty-day nutrition streak uses configured targets and zero intake', () async {
      await db.saveNutritionTargets(
        calories: 1800,
        protein: 150,
        carbs: 190,
        fat: 60,
      );
      final today = key(DateTime.now());
      final rows = await db.getNutritionStreakDays();
      final row = rows.singleWhere((item) => item['day'] == today);
      expect(row['calories'], 0);
      expect(row['protein'], 0);
      expect(row['calorie_target'], 1800);
      expect(row['protein_target'], 150);
    });

    test('nutrition targets persist and latest target is returned', () async {
      await db.saveNutritionTargets(
        calories: 2200,
        protein: 180,
        carbs: 200,
        fat: 70,
      );
      await db.saveNutritionTargets(
        calories: 1800,
        protein: 150,
        carbs: 170,
        fat: 60,
      );

      final targets = await db.getNutritionTargets();
      expect(targets?['calorie_target'], 1800);
      expect(targets?['protein_target_g'], 150);
      expect(targets?['carbs_target_g'], 170);
      expect(targets?['fat_target_g'], 60);
    });

    test('built-in and custom food catalogues remain separately queryable', () async {
      final builtInBefore = await db.getBuiltInFoods();
      expect(builtInBefore, isNotEmpty);
      final id = await db.insertCustomFood(
        name: 'QA Custom Food',
        caloriesPer100g: 100,
        proteinPer100g: 10,
        carbsPer100g: 10,
        fatPer100g: 2,
      );
      expect((await db.getCustomFoods()).any((food) => food['id'] == id), isTrue);
      expect((await db.getBuiltInFoods()).any((food) => food['id'] == id), isFalse);
    });
  });

  group('Profile, settings and weight scenarios', () {
    test('profile and nutrition targets save atomically and survive reopen', () async {
      await db.saveProfileAndTargets(
        displayName: 'QA User',
        age: 27,
        heightCm: 182,
        weightKg: 88.5,
        goal: 'Build Muscle',
        calories: 2100,
        protein: 170,
        carbs: 200,
        fat: 65,
      );
      await db.closeForTesting();
      db = AppDatabase.forTesting(p.join(tempDirectory.path, 'phase1.db'));

      final profile = await db.getUserProfile();
      final targets = await db.getNutritionTargets();
      expect(profile?['display_name'], 'QA User');
      expect(profile?['age'], 27);
      expect(profile?['height_value'], 182);
      expect(profile?['current_goal'], 'Build Muscle');
      expect((await db.getLatestBodyWeight())?['weight_value'], 88.5);
      expect(targets?['calorie_target'], 2100);
      expect(targets?['protein_target_g'], 170);
    });

    test('app settings upsert values and preserve fallback for missing keys', () async {
      expect(await db.getAppSetting('weight_unit', defaultValue: 'kg'), 'kg');
      await db.saveAppSetting('weight_unit', 'lb');
      await db.saveAppSetting('weight_unit', 'kg');
      expect(await db.getAppSetting('weight_unit'), 'kg');
    });

    test('body weight upsert keeps one value per date and latest history sorts correctly', () async {
      final today = key(DateTime.now());
      final yesterday = key(DateTime.now().subtract(const Duration(days: 1)));
      await db.saveBodyWeight(date: yesterday, weightKg: 89);
      await db.saveBodyWeight(date: today, weightKg: 88.5);
      await db.saveBodyWeight(date: today, weightKg: 88.1);

      final sql = await db.database;
      final rows = await sql.query(
        'body_weights',
        where: 'log_date = ?',
        whereArgs: [today],
      );
      expect(rows, hasLength(1));
      expect(rows.single['weight_value'], 88.1);
      expect((await db.getLatestBodyWeight())?['weight_value'], 88.1);
      expect((await db.getRecentBodyWeights()).first['log_date'], today);
    });

    test('profile detail update does not create duplicate profile rows', () async {
      await db.savePersonalDetails(
        displayName: 'First',
        age: 25,
        heightCm: 180,
        weightKg: 90,
        goal: 'Lose Fat',
      );
      await db.savePersonalDetails(
        displayName: 'Updated',
        age: 26,
        heightCm: 181,
        weightKg: 89,
        goal: 'Maintain',
      );
      final sql = await db.database;
      final profiles = await sql.query('user_profile');
      expect(profiles, hasLength(1));
      expect(profiles.single['display_name'], 'Updated');
      expect((await db.getLatestBodyWeight())?['weight_value'], 89);
    });
  });

  group('Progress photo scenarios', () {
    test('photo angle and date combinations remain independent', () async {
      final today = key(DateTime.now());
      final yesterday = key(DateTime.now().subtract(const Duration(days: 1)));
      for (final angle in ['front', 'side', 'back']) {
        expect(await db.saveProgressPhoto(
          date: today,
          angle: angle,
          localFilePath: '/tmp/$angle.jpg',
        ), isNull);
      }
      await db.saveProgressPhoto(
        date: yesterday,
        angle: 'front',
        localFilePath: '/tmp/yesterday-front.jpg',
      );

      final photos = await db.getProgressPhotos();
      expect(photos, hasLength(4));
      expect(photos.where((photo) => photo['photo_date'] == today), hasLength(3));
      expect(photos.where((photo) => photo['photo_date'] == yesterday), hasLength(1));
    });

    test('photo replacement returns old path and retains a single date-angle row', () async {
      final today = key(DateTime.now());
      expect(await db.saveProgressPhoto(
        date: today,
        angle: 'front',
        localFilePath: '/tmp/old.jpg',
      ), isNull);
      final oldPath = await db.saveProgressPhoto(
        date: today,
        angle: 'front',
        localFilePath: '/tmp/new.jpg',
      );
      expect(oldPath, '/tmp/old.jpg');
      final photos = await db.getProgressPhotos();
      expect(photos, hasLength(1));
      expect(photos.single['local_file_path'], '/tmp/new.jpg');
    });

    test('photo history respects limit and deleting one row leaves others', () async {
      final today = key(DateTime.now());
      for (final angle in ['front', 'side', 'back']) {
        await db.saveProgressPhoto(
          date: today,
          angle: angle,
          localFilePath: '/tmp/$angle.jpg',
        );
      }
      expect(await db.getProgressPhotos(limit: 2), hasLength(2));
      final all = await db.getProgressPhotos();
      final front = all.singleWhere((photo) => photo['angle'] == 'front');
      await db.deleteProgressPhoto(front['id'] as int);
      final remaining = await db.getProgressPhotos();
      expect(remaining, hasLength(2));
      expect(remaining.any((photo) => photo['angle'] == 'front'), isFalse);
    });
  });

  group('Activity and streak scenarios', () {
    test('manual activity create, edit, date filter and delete lifecycle', () async {
      final today = key(DateTime.now());
      final yesterday = key(DateTime.now().subtract(const Duration(days: 1)));
      final id = await db.saveActivityLog(
        activityType: 'Walking',
        activityDate: today,
        durationMinutes: 30,
        distanceKm: 2.5,
        steps: 3000,
        activeCalories: 150,
        notes: 'Initial',
      );
      await db.saveActivityLog(
        activityType: 'Cycling',
        activityDate: yesterday,
        durationMinutes: 40,
        distanceKm: 12,
      );
      await db.saveActivityLog(
        id: id,
        activityType: 'Running',
        activityDate: today,
        durationMinutes: 25,
        distanceKm: 3,
        steps: 3500,
        activeCalories: 220,
        notes: 'Edited',
      );

      final rows = await db.getActivityLogs(today);
      expect(rows, hasLength(1));
      expect(rows.single['activity_type'], 'Running');
      expect(rows.single['duration_minutes'], 25);
      expect(rows.single['steps'], 3500);
      expect(rows.single['notes'], 'Edited');
      expect(await db.getActivityLogs(yesterday), hasLength(1));

      await db.deleteActivityLog(id);
      expect(await db.getActivityLogs(today), isEmpty);
    });

    test('Health daily summary upserts same date and preserves partial metrics', () async {
      final today = key(DateTime.now());
      await db.saveHealthActivitySummary(
        date: today,
        steps: 8500,
        distanceKm: 6.2,
        activeCalories: 420,
        exerciseMinutes: 45,
      );
      await db.saveHealthActivitySummary(date: today, steps: 9200);
      final summary = await db.getHealthActivitySummary(today);
      final sql = await db.database;
      final rows = await sql.query(
        'activity_health_daily',
        where: 'activity_date = ?',
        whereArgs: [today],
      );
      expect(rows, hasLength(1));
      expect(summary?['steps'], 9200);
      expect(summary?['distance_km'], isNull);
    });

    test('training streak uses custom step goal and sums manual steps for the day', () async {
      await db.saveAppSetting('daily_step_goal', '7000');
      final today = key(DateTime.now());
      await db.saveActivityLog(
        activityType: 'Walking',
        activityDate: today,
        durationMinutes: 15,
        steps: 3500,
      );
      await db.saveActivityLog(
        activityType: 'Walking',
        activityDate: today,
        durationMinutes: 15,
        steps: 3500,
      );
      final result = await db.getTrainingStreakData();
      expect(result['step_goal'], 7000);
      expect(result['step_goal_days'], contains(today));
    });

    test('training streak does not count steps below the configured threshold', () async {
      await db.saveAppSetting('daily_step_goal', '7000');
      final today = key(DateTime.now());
      await db.saveActivityLog(
        activityType: 'Walking',
        activityDate: today,
        durationMinutes: 20,
        steps: 6999,
      );
      final result = await db.getTrainingStreakData();
      expect(result['step_goal_days'], isNot(contains(today)));
    });

    test('weekly progress returns seven daily entries and aggregates logged metrics', () async {
      final today = DateTime.now();
      final todayKey = key(today);
      await db.insertFoodLog(
        date: todayKey,
        meal: 'BREAKFAST',
        name: 'QA Weekly Meal',
        grams: 100,
        calories: 500,
        protein: 40,
        carbs: 50,
        fat: 15,
      );
      await db.saveBodyWeight(date: todayKey, weightKg: 88.4);
      final workoutId = await db.startWorkoutSession(sessionName: 'QA Weekly Workout');
      await db.finishWorkoutSession(workoutId);

      final summary = await db.getWeeklyProgressDetails();
      final daily = (summary['daily'] as List).cast<Map<String, Object?>>();
      expect(daily, hasLength(7));
      expect(daily.last['date'], todayKey);
      expect(daily.last['calories'], 500);
      expect(daily.last['protein'], 40);
      expect(daily.last['weight'], 88.4);
      expect(summary['tracked_days'], 1);
      expect(summary['weight_days'], 1);
      expect(summary['workouts'], 1);
    });
  });

  group('Workout plan and session scenarios', () {
    test('plan update and active selection survive database reopen', () async {
      final first = await db.createWorkoutPlan('First plan');
      final second = await db.createWorkoutPlan('Second plan');
      await db.updateWorkoutPlan(first, name: 'Updated first', description: 'Updated description');
      await db.setActiveWorkoutPlan(second);
      await db.closeForTesting();
      db = AppDatabase.forTesting(p.join(tempDirectory.path, 'phase1.db'));

      expect((await db.getWorkoutPlans()).map((row) => row['name']),
          containsAll(['Updated first', 'Second plan']));
      expect((await db.getActiveWorkoutPlan())?['id'], second);
      final sql = await db.database;
      expect(await sql.query('workout_plans', where: 'is_active = 1'), hasLength(1));
    });

    test('deleting a plan cascades through days, exercises and target sets', () async {
      final plan = await db.createWorkoutPlan('Delete cascade plan');
      final day = await db.addWorkoutPlanDay(
        planId: plan,
        label: 'Day 1',
        dayOrder: 1,
      );
      final exercise = await db.addExerciseToPlanDay(
        dayId: day,
        exerciseName: 'QA Squat',
        exerciseOrder: 1,
        setCount: 3,
      );
      await db.deleteWorkoutPlan(plan);

      final sql = await db.database;
      expect(await sql.query('workout_plans', where: 'id = ?', whereArgs: [plan]), isEmpty);
      expect(await sql.query('workout_plan_days', where: 'id = ?', whereArgs: [day]), isEmpty);
      expect(await sql.query('workout_plan_exercises', where: 'id = ?', whereArgs: [exercise]), isEmpty);
      expect(await sql.query('workout_plan_sets', where: 'plan_exercise_id = ?', whereArgs: [exercise]), isEmpty);
    });

    test('substituting a plan exercise updates snapshot and linked exercise id', () async {
      final exercises = await db.getExercises();
      expect(exercises, isNotEmpty);
      final plan = await db.createWorkoutPlan('Substitution plan');
      final day = await db.addWorkoutPlanDay(planId: plan, label: 'Day', dayOrder: 1);
      final planExercise = await db.addExerciseToPlanDay(
        dayId: day,
        exerciseName: 'Original name',
        exerciseOrder: 1,
      );
      final replacement = exercises.first;
      await db.substitutePlanExercise(
        planExerciseId: planExercise,
        exerciseId: replacement['id'] as int,
        exerciseName: replacement['name'] as String,
      );
      final row = (await db.getPlanDayExercises(day)).single;
      expect(row['exercise_id'], replacement['id']);
      expect(row['exercise_name_snapshot'], replacement['name']);
    });

    test('weekday and sequence workout days are returned from active plan', () async {
      final plan = await db.createWorkoutPlan('Schedule plan');
      await db.setActiveWorkoutPlan(plan);
      final sequenceDay = await db.addWorkoutPlanDay(
        planId: plan,
        label: 'Sequence Day',
        dayOrder: 1,
      );
      await db.addWorkoutPlanDay(
        planId: plan,
        label: 'Rest Day',
        dayOrder: 2,
        isRestDay: true,
      );
      final suggested = await db.getManualStartWorkoutDay();
      expect(suggested?['id'], sequenceDay);
      expect(suggested?['plan_id'], plan);
    });

    test('plan duplication copies schedule, exercises, targets and rest duration', () async {
      final plan = await db.createWorkoutPlan('Original');
      final day = await db.addWorkoutPlanDay(
        planId: plan,
        label: 'Pull',
        dayOrder: 1,
        scheduleType: 'weekday',
        weekday: DateTime.friday,
      );
      await db.addExerciseToPlanDay(
        dayId: day,
        exerciseName: 'Lat Pulldown',
        exerciseOrder: 1,
        setCount: 4,
        targetReps: 12,
        targetWeight: 40,
        restSeconds: 150,
      );
      final copy = await db.duplicateWorkoutPlan(plan, 'Copy');
      final copiedDay = (await db.getWorkoutPlanDays(copy)).single;
      expect(copiedDay['schedule_type'], 'weekday');
      expect(copiedDay['weekday'], DateTime.friday);
      final copiedExercise = (await db.getPlanDayExercises(copiedDay['id'] as int)).single;
      final copiedSets = await db.getPlanExerciseSets(copiedExercise['id'] as int);
      expect(copiedSets, hasLength(4));
      expect(copiedSets.map((row) => row['rest_seconds']), everyElement(150));
    });

    test('completed workout advances sequence and preserves summary values', () async {
      final plan = await db.createWorkoutPlan('Sequence');
      await db.setActiveWorkoutPlan(plan);
      final firstDay = await db.addWorkoutPlanDay(planId: plan, label: 'A', dayOrder: 1);
      final secondDay = await db.addWorkoutPlanDay(planId: plan, label: 'B', dayOrder: 2);
      await db.addExerciseToPlanDay(
        dayId: firstDay,
        exerciseName: 'QA Press',
        exerciseOrder: 1,
        setCount: 2,
        targetReps: 10,
        targetWeight: 20,
      );
      final workout = await db.startWorkoutSession(
        planId: plan,
        planDayId: firstDay,
        sessionName: 'A',
      );
      final sets = await db.getWorkoutSessionSets(workout);
      await db.updateWorkoutSet(id: sets.first['id'] as int, reps: 10, weight: 20, completed: true);
      await db.updateWorkoutSet(id: sets.last['id'] as int, reps: 8, weight: 22.5, completed: true);
      final summary = await db.getWorkoutSessionSummary(workout);
      expect(summary['completed_sets'], 2);
      expect(summary['volume'], 380);
      final sql = await db.database;
      await sql.update(
        'workouts',
        {'started_at': DateTime.now().subtract(const Duration(seconds: 65)).toIso8601String()},
        where: 'id = ?',
        whereArgs: [workout],
      );
      await db.finishWorkoutSession(workout);

      final next = await db.getManualStartWorkoutDay();
      expect(next?['id'], secondDay);
      expect((await db.getWorkoutHistory()).single['id'], workout);
    });

    test('abandoning a workout allows a new session and hides abandoned history', () async {
      final abandoned = await db.startWorkoutSession(sessionName: 'Abandoned');
      await db.abandonWorkoutSession(abandoned);
      final next = await db.startWorkoutSession(sessionName: 'Replacement');
      expect(next, isNot(abandoned));
      expect((await db.getInProgressWorkout())?['id'], next);
      expect(await db.getWorkoutHistory(), isEmpty);
    });

    test('completed exercise history is case-insensitive and ignores incomplete work', () async {
      final workout = await db.startWorkoutSession(sessionName: 'History');
      final completed = await db.addExerciseToWorkout(
        workoutId: workout,
        exerciseName: 'QA Row',
        setCount: 1,
        targetReps: 10,
        targetWeight: 30,
      );
      final incomplete = await db.addExerciseToWorkout(
        workoutId: workout,
        exerciseName: 'QA Row',
        setCount: 1,
        targetReps: 10,
        targetWeight: 40,
      );
      await db.updateWorkoutSet(id: completed, reps: 10, weight: 30, completed: true);
      await db.finishWorkoutSession(workout);

      final history = await db.getExercisePerformanceHistory('qa row');
      expect(history, hasLength(1));
      expect(history.single['actual_weight'], 30);
      expect(history.single['set_completed'], 1);
      expect(history.any((row) => row['set_id'] == incomplete), isFalse);
    });

    test('rest timer is cleared when workout finishes and cannot be saved after finish', () async {
      final workout = await db.startWorkoutSession(sessionName: 'Rest cleanup');
      await db.saveWorkoutRestEnd(workout, DateTime.now().add(const Duration(seconds: 60)));
      await db.finishWorkoutSession(workout);
      expect(await db.getWorkoutRestEnd(workout), isNull);
      await db.saveWorkoutRestEnd(workout, DateTime.now().add(const Duration(seconds: 60)));
      expect(await db.getWorkoutRestEnd(workout), isNull);
    });
  });

  group('Database integrity and resilience', () {
    test('foreign key checks return no violations after mixed feature usage', () async {
      final plan = await db.createWorkoutPlan('Integrity');
      final day = await db.addWorkoutPlanDay(planId: plan, label: 'Day', dayOrder: 1);
      await db.addExerciseToPlanDay(dayId: day, exerciseName: 'QA Lift', exerciseOrder: 1);
      final food = await db.insertCustomFood(
        name: 'QA Food',
        caloriesPer100g: 100,
        proteinPer100g: 10,
        carbsPer100g: 10,
        fatPer100g: 2,
      );
      await db.insertFoodLog(
        date: key(DateTime.now()),
        meal: 'LUNCH',
        name: 'QA Food',
        foodId: food,
        grams: 100,
        calories: 100,
        protein: 10,
        carbs: 10,
        fat: 2,
      );
      final sql = await db.database;
      final violations = await sql.rawQuery('PRAGMA foreign_key_check');
      expect(violations, isEmpty);
    });

    test('catalogue seeding is idempotent across database reopen', () async {
      final firstFoods = await db.getBuiltInFoods();
      final firstExercises = await db.getExercises();
      await db.closeForTesting();
      db = AppDatabase.forTesting(p.join(tempDirectory.path, 'phase1.db'));
      final secondFoods = await db.getBuiltInFoods();
      final secondExercises = await db.getExercises();

      expect(secondFoods, hasLength(firstFoods.length));
      expect(secondExercises, hasLength(firstExercises.length));
      expect(secondExercises.map((row) => row['name']).toSet(), hasLength(secondExercises.length));
    });
  });
}
