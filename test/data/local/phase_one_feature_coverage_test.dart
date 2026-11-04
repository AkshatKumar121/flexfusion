import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
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
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_phase_one_');
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'phase_one.db'));
  });

  tearDown(() async {
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('custom exercise can be created, edited, listed and deleted', () async {
    final id = await database.saveExercise(
      name: '  QA Dumbbell Press  ',
      muscleGroup: '  Chest ',
      equipment: ' Dumbbells ',
      instructions: ' Controlled reps ',
    );

    var exercises = await database.getExercises();
    final created = exercises.singleWhere((row) => row['id'] == id);
    expect(created['name'], 'QA Dumbbell Press');
    expect(created['muscle_group'], 'Chest');
    expect(created['equipment'], 'Dumbbells');
    expect(created['instructions'], 'Controlled reps');
    expect(created['is_custom'], 1);

    await database.saveExercise(
      id: id,
      name: 'QA Incline Dumbbell Press',
      muscleGroup: 'Chest',
      equipment: 'Dumbbells',
      instructions: 'Updated instructions',
    );
    exercises = await database.getExercises();
    final updated = exercises.singleWhere((row) => row['id'] == id);
    expect(updated['name'], 'QA Incline Dumbbell Press');
    expect(updated['instructions'], 'Updated instructions');

    await database.deleteExercise(id);
    expect(
      (await database.getExercises()).where((row) => row['id'] == id),
      isEmpty,
    );
  });

  test('only one workout plan can be active at a time', () async {
    final first = await database.createWorkoutPlan('QA Push');
    final second = await database.createWorkoutPlan('QA Pull');

    await database.setActiveWorkoutPlan(first);
    expect((await database.getActiveWorkoutPlan())?['id'], first);

    await database.setActiveWorkoutPlan(second);
    expect((await database.getActiveWorkoutPlan())?['id'], second);

    final plans = await database.getWorkoutPlans();
    expect(
      plans.where((plan) => plan['is_active'] == 1).map((plan) => plan['id']),
      [second],
    );
  });

  test('plan day and exercise settings can be updated and removed', () async {
    final planId = await database.createWorkoutPlan('QA Plan');
    final dayId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Push',
      dayOrder: 1,
    );
    final planExerciseId = await database.addExerciseToPlanDay(
      dayId: dayId,
      exerciseName: 'QA Chest Press',
      exerciseOrder: 1,
      setCount: 2,
      targetReps: 10,
      targetWeight: 20,
      restSeconds: 90,
    );

    await database.updateWorkoutPlanDay(
      id: dayId,
      label: 'Upper Body',
      dayOrder: 2,
      scheduleType: 'weekday',
      weekday: DateTime.monday,
      isRestDay: false,
    );
    var days = await database.getWorkoutPlanDays(planId);
    expect(days.single['label'], 'Upper Body');
    expect(days.single['day_order'], 2);
    expect(days.single['schedule_type'], 'weekday');
    expect(days.single['weekday'], DateTime.monday);

    await database.updatePlanExerciseSets(
      planExerciseId: planExerciseId,
      setCount: 3,
      targetReps: 8,
      targetWeight: 22.5,
      weightUnit: 'kg',
      restSeconds: 120,
    );
    final sets = await database.getPlanExerciseSets(planExerciseId);
    expect(sets, hasLength(3));
    expect(sets.map((set) => set['set_order']), [1, 2, 3]);
    expect(sets.map((set) => set['target_reps']), everyElement(8));
    expect(sets.map((set) => set['target_weight']), everyElement(22.5));
    expect(sets.map((set) => set['rest_seconds']), everyElement(120));

    await database.deletePlanExercise(planExerciseId);
    expect(await database.getPlanDayExercises(dayId), isEmpty);

    await database.deleteWorkoutPlanDay(dayId);
    days = await database.getWorkoutPlanDays(planId);
    expect(days, isEmpty);
  });

  test('exercise performance history returns all completed matching sets newest first', () async {
    Future<int> addSession({
      required String name,
      required String exercise,
      required double weight,
      required bool completed,
      required DateTime startedAt,
    }) async {
      final workoutId = await database.startWorkoutSession(sessionName: name);
      final setId = await database.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseName: exercise,
        setCount: 1,
        targetReps: 8,
        targetWeight: weight,
      );
      final db = await database.database;
      await db.update(
        'workouts',
        {'started_at': startedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [workoutId],
      );
      await database.updateWorkoutSet(
        id: setId,
        reps: 8,
        weight: weight,
        completed: completed,
      );
      await database.finishWorkoutSession(workoutId);
      return workoutId;
    }

    final older = await addSession(
      name: 'Older session',
      exercise: 'Incline Dumbbell Press',
      weight: 20,
      completed: true,
      startedAt: DateTime(2026, 1, 10, 8),
    );
    final newer = await addSession(
      name: 'Newer session',
      exercise: ' incline dumbbell press ',
      weight: 22.5,
      completed: true,
      startedAt: DateTime(2026, 2, 10, 8),
    );
    await addSession(
      name: 'Incomplete session',
      exercise: 'Incline Dumbbell Press',
      weight: 30,
      completed: false,
      startedAt: DateTime(2026, 3, 10, 8),
    );
    await addSession(
      name: 'Different exercise',
      exercise: 'Flat Dumbbell Press',
      weight: 40,
      completed: true,
      startedAt: DateTime(2026, 4, 10, 8),
    );

    final history = await database.getExercisePerformanceHistory(
      'INCLINE DUMBBELL PRESS',
    );

    expect(history, hasLength(2));
    expect(history.map((row) => row['workout_id']), [newer, older]);
    expect(history.map((row) => row['session_name']), [
      'Newer session',
      'Older session',
    ]);
    expect(history.map((row) => row['actual_weight']), [22.5, 20.0]);
    expect(history.every((row) => row['set_completed'] == 1), isTrue);
  });

  test('exercise performance history excludes abandoned workouts', () async {
    final workoutId = await database.startWorkoutSession(
      sessionName: 'Abandoned session',
    );
    final setId = await database.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseName: 'QA Row',
      setCount: 1,
      targetReps: 10,
      targetWeight: 25,
    );
    await database.updateWorkoutSet(
      id: setId,
      reps: 10,
      weight: 25,
      completed: true,
    );
    await database.abandonWorkoutSession(workoutId);

    expect(
      await database.getExercisePerformanceHistory('QA Row'),
      isEmpty,
    );
  });

  test('free workout can add exercises and persist set edits independently', () async {
    final workoutId = await database.startWorkoutSession(
      sessionName: 'Free workout QA',
    );
    final firstSetId = await database.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseName: 'QA Cable Fly',
      setCount: 2,
      targetReps: 12,
      targetWeight: 10,
      restSeconds: 75,
    );
    final sets = await database.getWorkoutSessionSets(workoutId);
    expect(sets, hasLength(2));
    expect(sets.map((row) => row['rest_seconds']), everyElement(75));

    await database.updateWorkoutSet(
      id: firstSetId,
      reps: 15,
      weight: 12.5,
      completed: true,
    );
    final updated = await database.getWorkoutSessionSets(workoutId);
    final completed = updated.singleWhere((row) => row['id'] == firstSetId);
    final untouched = updated.singleWhere((row) => row['id'] != firstSetId);
    expect(completed['actual_reps'], 15);
    expect(completed['actual_weight'], 12.5);
    expect(completed['completed'], 1);
    expect(untouched['completed'], 0);
    expect(untouched['actual_reps'], 12);
  });

  test('deleting a workout removes its set records and history entry', () async {
    final workoutId = await database.startWorkoutSession(
      sessionName: 'Delete workout QA',
    );
    await database.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseName: 'QA Lateral Raise',
      setCount: 3,
    );

    await database.deleteWorkoutSession(workoutId);

    expect(await database.getWorkoutSessionSets(workoutId), isEmpty);
    expect(
      (await database.getWorkoutHistory()).where((row) => row['id'] == workoutId),
      isEmpty,
    );
  });

  test('completed workout today lookup ignores in-progress and abandoned sessions', () async {
    final completedId = await database.startWorkoutSession(
      sessionName: 'Completed today',
    );
    await database.finishWorkoutSession(completedId);

    final abandonedId = await database.startWorkoutSession(
      sessionName: 'Will abandon',
    );
    await database.abandonWorkoutSession(abandonedId);

    final inProgressId = await database.startWorkoutSession(
      sessionName: 'Still active',
    );

    expect(
      (await database.getCompletedWorkoutToday())?['id'],
      completedId,
    );
    expect(
      (await database.getInProgressWorkout())?['id'],
      inProgressId,
    );
  });
}
