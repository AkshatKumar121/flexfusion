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
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_workout_test_');
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'workouts.db'));
  });

  tearDown(() async {
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> markWorkoutEligibleForSequence(int workoutId) async {
    final setId = await database.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseName: 'Sequence eligibility test',
      setCount: 1,
      targetReps: 8,
      targetWeight: 20,
    );
    await database.updateWorkoutSet(
      id: setId,
      reps: 8,
      weight: 20,
      completed: true,
    );
    final db = await database.database;
    await db.update(
      'workouts',
      {'started_at': DateTime.now().subtract(const Duration(seconds: 65)).toIso8601String()},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

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

  test('deactivating a workout plan clears the active plan without deleting it', () async {
    final firstPlanId = await database.createWorkoutPlan('First plan');
    final secondPlanId = await database.createWorkoutPlan('Second plan');
    await database.setActiveWorkoutPlan(firstPlanId);

    await database.deactivateWorkoutPlan(firstPlanId);

    expect(await database.getActiveWorkoutPlan(), isNull);
    final plans = await database.getWorkoutPlans();
    expect(plans, hasLength(2));
    expect(plans.singleWhere((plan) => plan['id'] == firstPlanId)['is_active'], 0);

    await database.setActiveWorkoutPlan(secondPlanId);
    expect((await database.getActiveWorkoutPlan())?['id'], secondPlanId);
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

  test('workout analysis query includes the 14-day lower boundary and excludes tomorrow', () async {
    final reference = DateTime(2026, 11, 4, 12);
    final lowerBoundary = DateTime(2026, 10, 22);
    final beforeBoundary = DateTime(2026, 10, 21, 23, 59);
    final tomorrow = DateTime(2026, 11, 5);

    Future<int> createCompletedWorkout(String name, DateTime startedAt) async {
      final id = await database.startWorkoutSession(sessionName: name);
      final db = await database.database;
      await db.update(
        'workouts',
        {'started_at': startedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await database.finishWorkoutSession(id);
      return id;
    }

    final includedId = await createCompletedWorkout('Lower boundary', lowerBoundary);
    final oldId = await createCompletedWorkout('Outside window', beforeBoundary);
    final futureId = await createCompletedWorkout('Tomorrow', tomorrow);

    final rows = await database.getWorkoutAnalysisRows(now: reference);
    final ids = rows.map((row) => row['workout_id']).toSet();

    expect(ids, contains(includedId));
    expect(ids, isNot(contains(oldId)));
    expect(ids, isNot(contains(futureId)));
  });

  test('workout analysis excludes abandoned sessions without completed sets but retains completed work', () async {
    Future<int> createAbandonedWorkout(String name, {required bool completeSet}) async {
      final id = await database.startWorkoutSession(sessionName: name);
      final setId = await database.addExerciseToWorkout(
        workoutId: id,
        exerciseName: 'Analysis Test Press',
        setCount: 1,
        targetReps: 8,
        targetWeight: 20,
      );
      if (completeSet) {
        await database.updateWorkoutSet(
          id: setId,
          reps: 8,
          weight: 20,
          completed: true,
        );
      }
      await database.abandonWorkoutSession(id);
      return id;
    }

    final emptyAbandonedId = await createAbandonedWorkout(
      'Abandoned without work',
      completeSet: false,
    );
    final completedWorkId = await createAbandonedWorkout(
      'Abandoned after completed set',
      completeSet: true,
    );

    final rows = await database.getWorkoutAnalysisRows();
    final ids = rows.map((row) => row['workout_id']).toSet();

    expect(ids, isNot(contains(emptyAbandonedId)));
    expect(ids, contains(completedWorkId));
    final retainedSet = rows.firstWhere((row) => row['workout_id'] == completedWorkId);
    expect(retainedSet['set_completed'], 1);
    expect(retainedSet['actual_reps'], 8);
    expect(retainedSet['actual_weight'], 20);
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

  test('adding a plan day recalculates the next workout after a completed one-day plan', () async {
    final planId = await database.createWorkoutPlan('PPSA');
    await database.setActiveWorkoutPlan(planId);
    final shoulderDayId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Shoulder/Arms',
      dayOrder: 1,
    );

    final workoutId = await database.startWorkoutSession(
      planId: planId,
      planDayId: shoulderDayId,
      sessionName: 'Shoulder/Arms',
    );
    await markWorkoutEligibleForSequence(workoutId);
    await database.finishWorkoutSession(workoutId);

    final chestDayId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Chest',
      dayOrder: 2,
    );

    final nextDay = await database.getManualStartWorkoutDay();
    expect(nextDay?['id'], chestDayId);
    expect(nextDay?['label'], 'Chest');
    expect((await database.getWorkoutHistory()).single['session_name'], 'Shoulder/Arms');
  });

  test('reordering plan days recalculates next workout from the completed day position', () async {
    final planId = await database.createWorkoutPlan('Reordered plan');
    await database.setActiveWorkoutPlan(planId);
    final shoulderId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Shoulder/Arms',
      dayOrder: 1,
    );
    final chestId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Chest',
      dayOrder: 2,
    );
    final backId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Back',
      dayOrder: 3,
    );

    final workoutId = await database.startWorkoutSession(
      planId: planId,
      planDayId: shoulderId,
      sessionName: 'Shoulder/Arms',
    );
    await markWorkoutEligibleForSequence(workoutId);
    await database.finishWorkoutSession(workoutId);

    // New order: Back, Shoulder/Arms, Chest.
    await database.updateWorkoutPlanDay(
      id: backId,
      label: 'Back',
      dayOrder: 1,
      scheduleType: 'sequence',
      isRestDay: false,
    );
    await database.updateWorkoutPlanDay(
      id: shoulderId,
      label: 'Shoulder/Arms',
      dayOrder: 2,
      scheduleType: 'sequence',
      isRestDay: false,
    );
    await database.updateWorkoutPlanDay(
      id: chestId,
      label: 'Chest',
      dayOrder: 3,
      scheduleType: 'sequence',
      isRestDay: false,
    );

    final nextDay = await database.getManualStartWorkoutDay();
    expect(nextDay?['id'], chestId);
    expect(nextDay?['label'], 'Chest');
  });

  test('deleting the selected next day recalculates to the next remaining day', () async {
    final planId = await database.createWorkoutPlan('Deleted next day');
    await database.setActiveWorkoutPlan(planId);
    final shoulderId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Shoulder/Arms',
      dayOrder: 1,
    );
    final chestId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Chest',
      dayOrder: 2,
    );
    final backId = await database.addWorkoutPlanDay(
      planId: planId,
      label: 'Back',
      dayOrder: 3,
    );

    final workoutId = await database.startWorkoutSession(
      planId: planId,
      planDayId: shoulderId,
      sessionName: 'Shoulder/Arms',
    );
    await markWorkoutEligibleForSequence(workoutId);
    await database.finishWorkoutSession(workoutId);
    await database.deleteWorkoutPlanDay(chestId);

    final nextDay = await database.getManualStartWorkoutDay();
    expect(nextDay?['id'], backId);
    expect(nextDay?['label'], 'Back');
  });


  test('sequence does not advance for short or set-free completed sessions', () async {
    final planId = await database.createWorkoutPlan('Completion threshold');
    await database.setActiveWorkoutPlan(planId);
    final firstDayId = await database.addWorkoutPlanDay(
      planId: planId, label: 'Shoulder', dayOrder: 1,
    );
    final secondDayId = await database.addWorkoutPlanDay(
      planId: planId, label: 'Back', dayOrder: 2,
    );

    final shortWorkout = await database.startWorkoutSession(
      planId: planId, planDayId: firstDayId, sessionName: 'Short session',
    );
    final shortSetId = await database.addExerciseToWorkout(
      workoutId: shortWorkout, exerciseName: 'Short set', setCount: 1,
    );
    await database.updateWorkoutSet(
      id: shortSetId, reps: 8, weight: 10, completed: true,
    );
    await database.finishWorkoutSession(shortWorkout);
    expect((await database.getManualStartWorkoutDay())?['id'], firstDayId);

    final noSetWorkout = await database.startWorkoutSession(
      planId: planId, planDayId: firstDayId, sessionName: 'No completed set',
    );
    final db = await database.database;
    await db.update(
      'workouts',
      {'started_at': DateTime.now().subtract(const Duration(seconds: 70)).toIso8601String()},
      where: 'id = ?', whereArgs: [noSetWorkout],
    );
    await database.finishWorkoutSession(noSetWorkout);
    expect((await database.getManualStartWorkoutDay())?['id'], firstDayId);

    final validWorkout = await database.startWorkoutSession(
      planId: planId, planDayId: secondDayId, sessionName: 'Valid session',
    );
    await markWorkoutEligibleForSequence(validWorkout);
    await database.finishWorkoutSession(validWorkout);
    expect((await database.getManualStartWorkoutDay())?['id'], firstDayId);
  });


  test('freestyle and duplicate finish do not move the planned sequence twice', () async {
    final planId = await database.createWorkoutPlan('Freestyle isolation');
    await database.setActiveWorkoutPlan(planId);
    final shoulderId = await database.addWorkoutPlanDay(
      planId: planId, label: 'Shoulder', dayOrder: 1,
    );
    final backId = await database.addWorkoutPlanDay(
      planId: planId, label: 'Back', dayOrder: 2,
    );

    final plannedId = await database.startWorkoutSession(
      planId: planId, planDayId: shoulderId, sessionName: 'Shoulder',
    );
    await markWorkoutEligibleForSequence(plannedId);
    await database.finishWorkoutSession(plannedId);
    await database.finishWorkoutSession(plannedId);
    expect((await database.getManualStartWorkoutDay())?['id'], backId);

    final freeId = await database.startWorkoutSession(sessionName: 'Freestyle');
    await markWorkoutEligibleForSequence(freeId);
    await database.finishWorkoutSession(freeId);
    expect((await database.getManualStartWorkoutDay())?['id'], backId);
    expect((await database.getWorkoutHistory()).where((row) => row['id'] == plannedId), hasLength(1));
  });

}
