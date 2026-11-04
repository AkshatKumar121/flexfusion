import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flexfusion/data/local/app_database.dart';
import 'package:flexfusion/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core navigation, workout logging, rest timer and dashboard routes work', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('TRAIN'), findsOneWidget);
    expect(find.text('EAT'), findsOneWidget);

    // Food diary tab remains reachable from the bottom navigation.
    await tester.tap(find.text('EAT').last);
    await tester.pumpAndSettle();
    expect(find.text('ADD FOOD'), findsOneWidget);
    await tester.tap(find.text('HOME').last);
    await tester.pumpAndSettle();

    // Prepare a real persisted session fixture, then exercise the actual UI.
    final db = AppDatabase.instance;
    final planId = await db.createWorkoutPlan('CI Workout');
    final dayId = await db.addWorkoutPlanDay(
      planId: planId,
      label: 'Test Day',
      dayOrder: 1,
    );
    await db.addExerciseToPlanDay(
      dayId: dayId,
      exerciseName: 'Integration Test Press',
      exerciseOrder: 1,
      setCount: 1,
      targetReps: 8,
      targetWeight: 10,
      restSeconds: 90,
    );
    final workoutId = await db.startWorkoutSession(
      planId: planId,
      planDayId: dayId,
      sessionName: 'CI Workout',
    );
    expect(await db.getWorkoutRestEnd(workoutId), isNull);

    await tester.tap(find.text('TRAIN').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('GO TO ONGOING WORKOUT'));
    await tester.pumpAndSettle();
    expect(find.text('Integration Test Press'), findsOneWidget);
    expect(find.text('WORKOUT DURATION'), findsOneWidget);

    // Completing a set starts its configured rest timer.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('REST TIMER'), findsOneWidget);

    // Tapping the timer card must not dismiss it; only the close control does.
    await tester.tap(find.text('REST TIMER'));
    await tester.pump();
    expect(find.text('REST TIMER'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss rest timer'));
    await tester.pump();
    expect(find.text('REST TIMER'), findsNothing);
    expect(await db.getWorkoutRestEnd(workoutId), isNull);

    await tester.tap(find.text('FINISH').first);
    await tester.pumpAndSettle();
    expect(find.text('Finish workout?'), findsOneWidget);
    await tester.tap(find.text('FINISH').last);
    await tester.pumpAndSettle();
    expect((await db.getWorkoutHistory()).single['session_name'], 'CI Workout');

    // Return to Home and open the workout analysis report.
    await tester.tap(find.text('HOME').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('WORKOUT ANALYSIS'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('WORKOUT ANALYSIS').last);
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Activity opens from the dashboard and returns to the same app shell.
    await tester.scrollUntilVisible(
      find.text('LOG ACTIVITY'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('LOG ACTIVITY'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIVITY'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
