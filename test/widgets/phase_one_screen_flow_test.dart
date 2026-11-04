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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_widget_');
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'widget.db'));
    AppDatabase.setInstanceForTesting(database);
    await database.database;
  });

  tearDown(() async {
    AppDatabase.setInstanceForTesting(null);
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('app shell exposes and switches between the three primary tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await pumpUntilFound(tester, find.text('Ready to get stronger?'));

    expect(find.text('TRAIN'), findsNWidgets(2));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('EAT'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('nav-TRAIN')));
    await pumpUntilFound(tester, find.text('YOUR TRAINING SPACE'));
    expect(find.text('YOUR TRAINING SPACE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-EAT')));
    await pumpUntilFound(tester, find.text('YOUR NUTRITION'));
    expect(find.text('YOUR NUTRITION'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-HOME')));
    await pumpUntilFound(tester, find.text('Ready to get stronger?'));
    expect(find.text('Ready to get stronger?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('food picker saves a custom food with its entered nutrition values', (tester) async {
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
    await tester.tap(find.text('CUSTOM FOOD'));
    await pumpUntilFound(tester, find.text('Create custom food'));

    await tester.enterText(find.byKey(const ValueKey('food-field-Food name')), 'Widget QA Paneer');
    await tester.enterText(find.byKey(const ValueKey('food-field-Calories (kcal)')), '265');
    await tester.enterText(find.byKey(const ValueKey('food-field-Protein (g)')), '18');
    await tester.enterText(find.byKey(const ValueKey('food-field-Carbs (g)')), '2');
    await tester.enterText(find.byKey(const ValueKey('food-field-Fat (g)')), '21');
    await tester.tap(find.text('ADD TO MEAL'));
    await tester.pump(const Duration(milliseconds: 500));

    final foods = await AppDatabase.instance.getCustomFoods();
    final saved = foods.singleWhere((food) => food['name'] == 'Widget QA Paneer');
    expect(saved['calories_per_basis'], 265);
    expect(saved['protein_per_basis_g'], 18);
    expect(saved['carbs_per_basis_g'], 2);
    expect(saved['fat_per_basis_g'], 21);

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
