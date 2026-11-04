import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flexfusion/data/local/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late AppDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_workout_test_');
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'workouts.db'));
  });

  tearDown(() async {
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('plan rest settings flow into session sets and completed workout summary', () async {
    final planId = await database.createWorkoutPlan('Push Day');
    await database.setActiveWorkoutPlan(planId);
    final dayId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Chest and shoulders',
      dayOrder: 1,
    );
    await database.addExerciseToPlanDay(
      dayId: dayId,
      exerciseName: 'Incline Dumbbell Press',
      exerciseOrder: 1,
      setCount: 3,
      targetReps: 10,
      targetWeight: 15,
      restSeconds: 135,
    );

    final workoutId = await database.startWorkoutSession(
      planId: planId,
      planDayId: dayId,
      sessionName: 'Push Day',
    );
    final sets = await database.getWorkoutSessionSets(workoutId);

    expect(sets, hasLength(3));
    expect(sets.map((row) => row['rest_seconds']), everyElement(135));
    expect(sets.map((row) => row['completed']), everyElement(0));

    await database.updateWorkoutSet(
      id: sets.first['id'] as int,
      reps: 10,
      weight: 15,
      completed: true,
    );
    final summary = await database.getWorkoutSessionSummary(workoutId);
    expect(summary['total_sets'], 3);
    expect(summary['completed_sets'], 1);
    expect(summary['volume'], 150);

    await database.finishWorkoutSession(workoutId);
    final history = await database.getWorkoutHistory();
    expect(history, hasLength(1));
    expect(history.single['id'], workoutId);
    expect(history.single['completed_sets'], 1);
  });

  test('duplicating a plan preserves exercises, set targets and custom rest duration', () async {
    final sourcePlanId = await database.createWorkoutPlan('Original Plan');
    final dayId = await database.addWorkoutPlanDay(
      planId: sourcePlanId,
      label: 'Pull',
      dayOrder: 1,
    );
    final exerciseId = await database.addExerciseToPlanDay(
      dayId: dayId,
      exerciseName: 'Lat Pulldown',
      exerciseOrder: 1,
      setCount: 4,
      targetReps: 12,
      targetWeight: 40,
      restSeconds: 150,
    );

    final copyId = await database.duplicateWorkoutPlan(sourcePlanId, 'Copy Plan');
    final copiedDays = await database.getWorkoutPlanDays(copyId);
    expect(copiedDays, hasLength(1));
    expect(copiedDays.single['label'], 'Pull');

    final copiedExercises = await database.getPlanDayExercises(copiedDays.single['id'] as int);
    expect(copiedExercises, hasLength(1));
    expect(copiedExercises.single['exercise_name_snapshot'], 'Lat Pulldown');
    expect(copiedExercises.single['id'], isNot(exerciseId));

    final copiedSets = await database.getPlanExerciseSets(copiedExercises.single['id'] as int);
    expect(copiedSets, hasLength(4));
    expect(copiedSets.map((row) => row['target_reps']), everyElement(12));
    expect(copiedSets.map((row) => row['target_weight']), everyElement(40));
    expect(copiedSets.map((row) => row['rest_seconds']), everyElement(150));
  });

  test('workout pause and resume persist elapsed paused time', () async {
    final workoutId = await database.startWorkoutSession(sessionName: 'Pause test');
    final db = await database.database;
    await db.update(
      'workouts',
      {'paused_at': DateTime.now().subtract(const Duration(seconds: 4)).toIso8601String()},
      where: 'id = ?',
      whereArgs: [workoutId],
    );

    await database.resumeWorkoutSession(workoutId);
    final rows = await db.query('workouts', where: 'id = ?', whereArgs: [workoutId]);
    expect(rows.single['paused_at'], isNull);
    expect(rows.single['paused_seconds'] as int, greaterThanOrEqualTo(3));

    await database.pauseWorkoutSession(workoutId);
    final paused = await db.query('workouts', where: 'id = ?', whereArgs: [workoutId]);
    expect(paused.single['paused_at'], isNotNull);
  });

  test('rest timer survives reload and can be cleared', () async {
    final workoutId = await database.startWorkoutSession(sessionName: 'Rest timer');
    final restEnd = DateTime.now().add(const Duration(seconds: 75));

    await database.saveWorkoutRestEnd(workoutId, restEnd);
    expect(await database.getWorkoutRestEnd(workoutId), restEnd);

    await database.saveWorkoutRestEnd(workoutId, null);
    expect(await database.getWorkoutRestEnd(workoutId), isNull);
  });

  test('a second active workout is rejected and abandoned workouts can be replaced', () async {
    final firstId = await database.startWorkoutSession(sessionName: 'First');
    await expectLater(
      database.startWorkoutSession(sessionName: 'Duplicate'),
      throwsA(isA<StateError>()),
    );

    await database.abandonWorkoutSession(firstId);
    final secondId = await database.startWorkoutSession(sessionName: 'Second');
    expect(secondId, isNot(firstId));
    expect((await database.getInProgressWorkout())?['id'], secondId);
  });

  test('workout analysis query returns set rows for the requested 14-day window', () async {
    final reference = DateTime(2026, 11, 4, 12);
    final workoutId = await database.startWorkoutSession(sessionName: 'Analysis fixture');
    final db = await database.database;
    await db.update(
      'workouts',
      {'started_at': reference.toIso8601String()},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
    await database.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseName: 'Dumbbell Row',
      setCount: 2,
      targetReps: 10,
      targetWeight: 20,
      restSeconds: 90,
    );
    final sets = await database.getWorkoutSessionSets(workoutId);
    await database.updateWorkoutSet(
      id: sets.first['id'] as int,
      reps: 10,
      weight: 20,
      completed: true,
    );

    final rows = await database.getWorkoutAnalysisRows(now: reference);
    final matching = rows.where((row) => row['workout_id'] == workoutId).toList();
    expect(matching, hasLength(2));
    expect(matching.where((row) => row['set_completed'] == 1), hasLength(1));
    expect(matching.first['exercise_name_snapshot'], 'Dumbbell Row');
  });

  test('finishing a workout clears any persisted rest timer', () async {
    final workoutId = await database.startWorkoutSession(sessionName: 'Finish cleanup');
    await database.saveWorkoutRestEnd(
      workoutId,
      DateTime.now().add(const Duration(seconds: 60)),
    );

    await database.finishWorkoutSession(workoutId);

    final rows = await database.getWorkoutHistory();
    expect(rows, hasLength(1));
    expect(rows.single['session_name'], 'Finish cleanup');
    expect(await database.getWorkoutRestEnd(workoutId), isNull);
  });
}
