import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flexfusion/app/app_shell.dart';
import 'package:flexfusion/data/local/app_database.dart';
import 'package:flexfusion/features/activity/activity_screen.dart';
import 'package:flexfusion/features/eat/food_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late AppDatabase database;

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump();
  }

  Finder textFieldWithHint(String hint) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == hint,
      );

  Finder textFieldWithLabel(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_widget_');
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'widget.db'));
    AppDatabase.setInstanceForTesting(database);
    await database.database;
  });

  tearDown(() async {
    await database.closeForTesting();
    AppDatabase.setInstanceForTesting(null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('app shell exposes and switches between the three primary tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await pumpUntilFound(tester, find.text('Ready to get stronger?'));

    expect(find.text('TRAIN'), findsNWidgets(2));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('EAT'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.fitness_center).last);
    await pumpUntilFound(tester, find.text('YOUR TRAINING SPACE'));
    expect(find.text('YOUR TRAINING SPACE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restaurant).last);
    await pumpUntilFound(tester, find.text('YOUR NUTRITION'));
    expect(find.text('YOUR NUTRITION'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_filled).last);
    await pumpUntilFound(tester, find.text('Ready to get stronger?'));
    expect(find.text('Ready to get stronger?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('food picker validates quantity and persists a custom food', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FoodPickerSheet(meal: 'BREAKFAST'),
            ),
            child: const Text('OPEN FOOD PICKER'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('OPEN FOOD PICKER'));
    await pumpUntilFound(tester, find.text('ADD TO BREAKFAST'));
    expect(find.text('ADD TO BREAKFAST'), findsOneWidget);

    await tester.tap(find.text('CUSTOM FOOD'));
    await pumpUntilFound(tester, find.text('Create custom food'));

    await tester.tap(find.text('ADD TO MEAL'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Enter a food name.'), findsOneWidget);

    await tester.enterText(textFieldWithHint('Food name'), 'Widget QA Paneer');
    await tester.enterText(textFieldWithHint('Calories (kcal)'), '265');
    await tester.enterText(textFieldWithHint('Protein (g)'), '18');
    await tester.enterText(textFieldWithHint('Carbs (g)'), '2');
    await tester.enterText(textFieldWithHint('Fat (g)'), '21');
    await tester.enterText(textFieldWithHint('Grams (g)'), '0');
    await tester.tap(find.text('ADD TO MEAL'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Enter a quantity greater than zero.'), findsOneWidget);

    await tester.enterText(textFieldWithHint('Grams (g)'), '150');
    await tester.tap(find.text('ADD TO MEAL'));
    await tester.pump(const Duration(milliseconds: 500));

    final foods = await AppDatabase.instance.getCustomFoods();
    expect(foods.any((food) => food['name'] == 'Widget QA Paneer'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('activity form validates empty input and persists a manual activity', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ActivityScreen()));
    await pumpUntilFound(tester, find.text('LOG AN ACTIVITY'));
    expect(find.text('LOG AN ACTIVITY'), findsOneWidget);

    await tester.tap(find.text('LOG AN ACTIVITY'));
    await pumpUntilFound(tester, find.text('LOG ACTIVITY'));
    expect(find.text('LOG ACTIVITY'), findsOneWidget);

    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Enter duration, distance, or steps.'), findsOneWidget);

    await tester.enterText(textFieldWithLabel('Duration (minutes)'), '25');
    await tester.enterText(textFieldWithLabel('Steps (optional)'), '3200');
    await tester.enterText(textFieldWithLabel('Notes (optional)'), 'Widget test walk');
    await tester.tap(find.text('SAVE ACTIVITY'));
    await pumpUntilFound(tester, find.text('25 min · 3200 steps'));

    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('25 min · 3200 steps'), findsOneWidget);
    final history = await AppDatabase.instance.getActivityHistory(days: 1);
    expect(history.any((row) => row['notes'] == 'Widget test walk'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
