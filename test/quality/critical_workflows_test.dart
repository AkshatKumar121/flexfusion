import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flexfusion/data/local/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late String databasePath;
  late AppDatabase database;

  String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_qa_test_');
    databasePath = p.join(tempDirectory.path, 'quality.db');
    database = AppDatabase.forTesting(databasePath);
  });

  tearDown(() async {
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('nutrition logging, editing and deletion keep dashboard macros accurate', () async {
    final today = dateKey(DateTime.now());
    final foodId = await database.insertCustomFood(
      name: 'QA Test Oats',
      caloriesPer100g: 390,
      proteinPer100g: 16,
      carbsPer100g: 66,
      fatPer100g: 7,
    );

    final breakfastId = await database.insertFoodLog(
      date: today,
      meal: 'BREAKFAST',
      name: 'QA Test Oats',
      foodId: foodId,
      grams: 50,
      calories: 195,
      protein: 8,
      carbs: 33,
      fat: 3.5,
    );
    await database.insertFoodLog(
      date: today,
      meal: 'LUNCH',
      name: 'QA Test Paneer',
      grams: 100,
      calories: 265,
      protein: 18,
      carbs: 1,
      fat: 21,
    );

    var totals = await database.getDashboardNutrition(today);
    expect(totals['calories'], 460);
    expect(totals['protein'], 26);
    expect(totals['carbs'], 34);
    expect(totals['fat'], 24.5);

    await database.updateFoodLog(
      id: breakfastId,
      grams: 60,
      calories: 234,
      protein: 9.6,
      carbs: 39.6,
      fat: 4.2,
    );
    totals = await database.getDashboardNutrition(today);
    expect(totals['calories'], 499);
    expect(totals['protein'], closeTo(27.6, 0.001));

    await database.deleteFoodLog(breakfastId);
    totals = await database.getDashboardNutrition(today);
    expect(totals['calories'], 265);
    expect((await database.getFoodLogsForDate(today)), hasLength(1));
  });

  test('completed workout preserves set details, volume and analysis rows', () async {
    final planId = await database.createWorkoutPlan('QA Push Day');
    final dayId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Chest',
      dayOrder: 1,
    );
    await database.addExerciseToPlanDay(
      dayId: dayId,
      exerciseName: 'Dumbbell Press',
      exerciseOrder: 1,
      setCount: 2,
      targetReps: 10,
      targetWeight: 20,
      restSeconds: 90,
    );

    final workoutId = await database.startWorkoutSession(
      planId: planId,
      planDayId: dayId,
      sessionName: 'QA Push Day',
    );
    final sets = await database.getWorkoutSessionSets(workoutId);
    expect(sets, hasLength(2));

    await database.updateWorkoutSet(
      id: sets.first['id'] as int,
      reps: 10,
      weight: 20,
      completed: true,
    );
    await database.updateWorkoutSet(
      id: sets.last['id'] as int,
      reps: 8,
      weight: 22.5,
      completed: true,
    );

    final summary = await database.getWorkoutSessionSummary(workoutId);
    expect(summary['total_sets'], 2);
    expect(summary['completed_sets'], 2);
    expect(summary['volume'], 380);

    await database.finishWorkoutSession(workoutId);
    final history = await database.getWorkoutHistory();
    expect(history, hasLength(1));
    expect(history.single['session_name'], 'QA Push Day');
    expect(history.single['completed_sets'], 2);

    final analysisRows = await database.getWorkoutAnalysisRows();
    final workoutRows = analysisRows
        .where((row) => row['workout_id'] == workoutId)
        .toList();
    expect(workoutRows, hasLength(2));
    expect(workoutRows.where((row) => row['set_completed'] == 1), hasLength(2));
  });

  test('weight and progress photo records survive closing and reopening SQLite', () async {
    final today = dateKey(DateTime.now());
    await database.saveBodyWeight(date: today, weightKg: 88.4);
    await database.saveProgressPhoto(
      date: today,
      angle: 'front',
      localFilePath: '/qa-fixtures/front.jpg',
    );
    await database.saveProgressPhoto(
      date: today,
      angle: 'side',
      localFilePath: '/qa-fixtures/side.jpg',
    );
    await database.saveProgressPhoto(
      date: today,
      angle: 'back',
      localFilePath: '/qa-fixtures/back.jpg',
    );

    await database.closeForTesting();
    database = AppDatabase.forTesting(databasePath);

    expect((await database.getLatestBodyWeight())?['weight_value'], 88.4);
    final photos = await database.getProgressPhotos();
    expect(photos, hasLength(3));
    expect(
      photos.map((photo) => photo['angle']).toSet(),
      {'front', 'side', 'back'},
    );
    expect(
      photos.map((photo) => photo['local_file_path']).toSet(),
      {
        '/qa-fixtures/front.jpg',
        '/qa-fixtures/side.jpg',
        '/qa-fixtures/back.jpg',
      },
    );
  });

  test('weekly dashboard summary aggregates nutrition, weight and workouts', () async {
    final today = dateKey(DateTime.now());
    await database.insertFoodLog(
      date: today,
      meal: 'BREAKFAST',
      name: 'QA Summary Meal',
      grams: 100,
      calories: 500,
      protein: 40,
      carbs: 50,
      fat: 15,
    );
    await database.saveBodyWeight(date: today, weightKg: 88.4);

    final workoutId = await database.startWorkoutSession(
      sessionName: 'QA Summary Workout',
    );
    await database.finishWorkoutSession(workoutId);

    final summary = await database.getWeeklyProgressSummary();
    expect(summary['logged_days'], 1);
    expect(summary['average_calories'], 500);
    expect(summary['average_protein'], 40);
    expect(summary['weigh_in_days'], 1);
    expect(summary['average_weight'], 88.4);
    expect(summary['completed_workouts'], 1);
  });

  test('database foreign key integrity remains clean after a mixed workflow', () async {
    final planId = await database.createWorkoutPlan('Integrity Plan');
    final dayId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Day 1',
      dayOrder: 1,
    );
    await database.addExerciseToPlanDay(
      dayId: dayId,
      exerciseName: 'Integrity Press',
      exerciseOrder: 1,
      setCount: 2,
    );
    final foodId = await database.insertCustomFood(
      name: 'Integrity Food',
      caloriesPer100g: 100,
      proteinPer100g: 10,
      carbsPer100g: 10,
      fatPer100g: 2,
    );
    await database.insertFoodLog(
      date: dateKey(DateTime.now()),
      meal: 'DINNER',
      name: 'Integrity Food',
      foodId: foodId,
      grams: 100,
      calories: 100,
      protein: 10,
      carbs: 10,
      fat: 2,
    );

    final db = await database.database;
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
