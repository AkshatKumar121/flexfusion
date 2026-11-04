import 'dart:io';

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

  Future<void> pumpLoaded(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
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
    await pumpLoaded(tester);

    expect(find.text('TRAIN'), findsNWidgets(2));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('EAT'), findsNWidgets(2));

    await tester.tap(find.text('TRAIN').last);
    await pumpLoaded(tester);
    expect(find.text('YOUR TRAINING SPACE'), findsOneWidget);

    await tester.tap(find.text('EAT').last);
    await pumpLoaded(tester);
    expect(find.text('YOUR NUTRITION'), findsOneWidget);

    await tester.tap(find.text('HOME').last);
    await pumpLoaded(tester);
    expect(find.text('Ready to get stronger?'), findsOneWidget);
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
    await pumpLoaded(tester);
    expect(find.text('ADD TO BREAKFAST'), findsOneWidget);

    await tester.tap(find.text('CUSTOM FOOD'));
    await pumpLoaded(tester);

    await tester.tap(find.text('ADD TO MEAL'));
    await tester.pump();
    expect(find.text('Enter a food name.'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Widget QA Paneer');
    await tester.enterText(fields.at(1), '265');
    await tester.enterText(fields.at(2), '18');
    await tester.enterText(fields.at(3), '2');
    await tester.enterText(fields.at(4), '21');
    await tester.enterText(fields.at(5), '0');
    await tester.tap(find.text('ADD TO MEAL'));
    await tester.pump();
    expect(find.text('Enter a quantity greater than zero.'), findsOneWidget);

    await tester.enterText(fields.at(5), '150');
    await tester.tap(find.text('ADD TO MEAL'));
    await pumpLoaded(tester);

    final foods = await AppDatabase.instance.getCustomFoods();
    expect(foods.any((food) => food['name'] == 'Widget QA Paneer'), isTrue);
  });

  testWidgets('activity form validates empty input and persists a manual activity', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ActivityScreen()));
    await pumpLoaded(tester);

    await tester.tap(find.text('LOG AN ACTIVITY'));
    await pumpLoaded(tester);
    expect(find.text('LOG ACTIVITY'), findsOneWidget);

    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pump();
    expect(find.text('Enter duration, distance, or steps.'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '25');
    await tester.enterText(fields.at(2), '3200');
    await tester.enterText(fields.at(4), 'Widget test walk');
    await tester.tap(find.text('SAVE ACTIVITY'));
    await pumpLoaded(tester);

    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('25 min · 3200 steps'), findsOneWidget);
    final history = await AppDatabase.instance.getActivityHistory(days: 1);
    expect(history.any((row) => row['notes'] == 'Widget test walk'), isTrue);
  });
}
