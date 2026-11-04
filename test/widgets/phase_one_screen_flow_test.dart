import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flexfusion/app/app_shell.dart';
import 'package:flexfusion/app/theme/app_colors.dart';
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
    expect(finder, findsOneWidget, reason: 'Expected widget was not found after waiting.');
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_widget_');
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'widget.db'));
    AppDatabase.setInstanceForTesting(database);
    await database.database;
  });

  tearDownAll(() async {
    AppDatabase.setInstanceForTesting(null);
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('app shell exposes and switches between the three primary tabs', (tester) async {
    addTearDown(() async { await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(); });
    await tester.pumpWidget(const MaterialApp(
      home: AppShell(testScreens: [SizedBox.shrink(), SizedBox.shrink(), SizedBox.shrink()]),
    ));
    await pumpUntilFound(tester, find.byKey(const ValueKey('nav-HOME')));

    expect(find.byKey(const ValueKey('nav-TRAIN')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-HOME')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-EAT')), findsOneWidget);

    Icon navIcon(String key, IconData icon) => tester.widget<Icon>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byIcon(icon),
          ),
        );

    await tester.tap(find.byKey(const ValueKey('nav-TRAIN')));
    await tester.pump();
    expect(navIcon('nav-TRAIN', Icons.fitness_center).color, AppColors.red);

    await tester.tap(find.byKey(const ValueKey('nav-EAT')));
    await tester.pump();
    expect(navIcon('nav-EAT', Icons.restaurant).color, AppColors.red);

    await tester.tap(find.byKey(const ValueKey('nav-HOME')));
    await tester.pump();
    expect(navIcon('nav-HOME', Icons.home_filled).color, AppColors.red);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('food picker saves a custom food with its entered nutrition values', (tester) async {
    addTearDown(() async { await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(); });
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FoodPickerSheet(meal: 'BREAKFAST')),
    ));
    await pumpUntilFound(tester, find.text('ADD TO BREAKFAST'));
    await tester.tap(find.text('CUSTOM FOOD'));
    await pumpUntilFound(tester, find.text('Create custom food'));

    await tester.ensureVisible(find.byKey(const ValueKey('food-field-Food name')));
    await tester.enterText(find.byKey(const ValueKey('food-field-Food name')), 'Widget QA Paneer');
    await tester.ensureVisible(find.byKey(const ValueKey('food-field-Calories (kcal)')));
    await tester.enterText(find.byKey(const ValueKey('food-field-Calories (kcal)')), '265');
    await tester.ensureVisible(find.byKey(const ValueKey('food-field-Protein (g)')));
    await tester.enterText(find.byKey(const ValueKey('food-field-Protein (g)')), '18');
    await tester.ensureVisible(find.byKey(const ValueKey('food-field-Carbs (g)')));
    await tester.enterText(find.byKey(const ValueKey('food-field-Carbs (g)')), '2');
    await tester.ensureVisible(find.byKey(const ValueKey('food-field-Fat (g)')));
    await tester.enterText(find.byKey(const ValueKey('food-field-Fat (g)')), '21');
    await tester.ensureVisible(find.text('ADD TO MEAL'));
    await tester.pump();
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

  testWidgets('activity form validates fields and sends the saved activity to its caller', (tester) async {
    addTearDown(() async { await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(); });
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, Object?>? savedActivity;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ActivityForm(
                types: const ['Walking'],
                date: DateTime.now(),
                row: null,
                onSave: (value) async => savedActivity = value,
              ),
            ),
            child: const Text('OPEN ACTIVITY FORM'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('OPEN ACTIVITY FORM'));
    await pumpUntilFound(tester, find.text('LOG ACTIVITY'));
    expect(find.text('LOG ACTIVITY'), findsOneWidget);

    await tester.enterText(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Duration (minutes)',
    ), '25');
    await tester.enterText(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Steps (optional)',
    ), '3200');
    await tester.enterText(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Notes (optional)',
    ), 'Widget test walk');
    final saveButton = find.byKey(const ValueKey('activity-save-button'));
    await tester.ensureVisible(saveButton);
    await tester.pump();
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(savedActivity, isNotNull);
    expect(savedActivity!['type'], 'Walking');
    expect(savedActivity!['duration'], 25);
    expect(savedActivity!['steps'], 3200);
    expect(savedActivity!['notes'], 'Widget test walk');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
