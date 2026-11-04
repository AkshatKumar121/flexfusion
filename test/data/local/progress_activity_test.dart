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

  String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_progress_test_');
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'progress.db'));
  });

  tearDown(() async {
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('daily weight upsert keeps one record per date and updates latest value', () async {
    final date = todayKey();
    await database.saveBodyWeight(date: date, weightKg: 91.5);
    await database.saveBodyWeight(date: date, weightKg: 90.8);

    final latest = await database.getLatestBodyWeight();
    final db = await database.database;
    final rows = await db.query('body_weights', where: 'log_date = ?', whereArgs: [date]);

    expect(rows, hasLength(1));
    expect(rows.single['weight_value'], 90.8);
    expect(latest?['weight_value'], 90.8);
    expect(latest?['weight_unit'], 'kg');
  });

  test('progress photos support front, side and back and replace only matching date-angle', () async {
    final date = todayKey();
    expect(await database.saveProgressPhoto(
      date: date,
      angle: 'front',
      localFilePath: '/tmp/front-a.jpg',
    ), isNull);
    await database.saveProgressPhoto(
      date: date,
      angle: 'side',
      localFilePath: '/tmp/side.jpg',
    );
    await database.saveProgressPhoto(
      date: date,
      angle: 'back',
      localFilePath: '/tmp/back.jpg',
    );

    final previous = await database.saveProgressPhoto(
      date: date,
      angle: 'front',
      localFilePath: '/tmp/front-b.jpg',
    );
    expect(previous, '/tmp/front-a.jpg');

    final photos = await database.getProgressPhotos();
    expect(photos, hasLength(3));
    expect(photos.map((row) => row['angle']).toSet(), {'front', 'side', 'back'});
    expect(
      photos.singleWhere((row) => row['angle'] == 'front')['local_file_path'],
      '/tmp/front-b.jpg',
    );

    final frontId = photos.singleWhere((row) => row['angle'] == 'front')['id'] as int;
    await database.deleteProgressPhoto(frontId);
    final remaining = await database.getProgressPhotos();
    expect(remaining, hasLength(2));
    expect(remaining.map((row) => row['angle']).toSet(), {'side', 'back'});
  });

  test('manual activity can be created, edited, queried by date and deleted', () async {
    final date = todayKey();
    final id = await database.saveActivityLog(
      activityType: 'Walking',
      activityDate: date,
      durationMinutes: 30,
      distanceKm: 2.4,
      steps: 3200,
      activeCalories: 140,
      notes: 'Evening walk',
    );

    var logs = await database.getActivityLogs(date);
    expect(logs, hasLength(1));
    expect(logs.single['activity_type'], 'Walking');
    expect(logs.single['steps'], 3200);
    expect(logs.single['source'], 'manual');

    await database.saveActivityLog(
      id: id,
      activityType: 'Running',
      activityDate: date,
      durationMinutes: 25,
      distanceKm: 3.1,
      steps: 3500,
      activeCalories: 210,
      notes: 'Updated entry',
    );
    logs = await database.getActivityLogs(date);
    expect(logs, hasLength(1));
    expect(logs.single['activity_type'], 'Running');
    expect(logs.single['duration_minutes'], 25);
    expect(logs.single['notes'], 'Updated entry');

    await database.deleteActivityLog(id);
    expect(await database.getActivityLogs(date), isEmpty);
  });

  test('Health daily summary upsert replaces the same date without duplicate rows', () async {
    final date = todayKey();
    await database.saveHealthActivitySummary(
      date: date,
      steps: 8500,
      distanceKm: 6.2,
      activeCalories: 420,
      exerciseMinutes: 45,
    );
    await database.saveHealthActivitySummary(
      date: date,
      steps: 9200,
      distanceKm: 6.8,
      activeCalories: 460,
      exerciseMinutes: 52,
    );

    final summary = await database.getHealthActivitySummary(date);
    final db = await database.database;
    final rows = await db.query(
      'activity_health_daily',
      where: 'activity_date = ?',
      whereArgs: [date],
    );

    expect(rows, hasLength(1));
    expect(summary?['steps'], 9200);
    expect(summary?['distance_km'], 6.8);
    expect(summary?['exercise_minutes'], 52);
  });

  test('manual activity history is restricted to the requested recent-day window', () async {
    final today = todayKey();
    final oldDate = DateTime.now().subtract(const Duration(days: 20));
    final oldKey = '${oldDate.year}-${oldDate.month.toString().padLeft(2, '0')}-${oldDate.day.toString().padLeft(2, '0')}';

    await database.saveActivityLog(
      activityType: 'Walking',
      activityDate: today,
      durationMinutes: 20,
      steps: 2000,
    );
    await database.saveActivityLog(
      activityType: 'Cycling',
      activityDate: oldKey,
      durationMinutes: 45,
      distanceKm: 12,
    );

    final recent = await database.getActivityHistory(days: 7);
    expect(recent, hasLength(1));
    expect(recent.single['activity_type'], 'Walking');
  });
}
