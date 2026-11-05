import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flexfusion/data/local/app_database.dart';
import 'package:flexfusion/features/profile/data_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Directory outputDirectory;
  late AppDatabase database;
  late DataExportService exportService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('flexfusion_export_test_');
    outputDirectory = Directory(p.join(tempDirectory.path, 'exports'));
    await outputDirectory.create();
    database = AppDatabase.forTesting(p.join(tempDirectory.path, 'test.db'));
    AppDatabase.setInstanceForTesting(database);
    exportService = DataExportService(
      tempDirectoryProvider: () async => outputDirectory,
    );
  });

  tearDown(() async {
    AppDatabase.setInstanceForTesting(null);
    await database.closeForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<Archive> readArchive(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files, isNotEmpty);
    return archive;
  }

  String readText(Archive archive, String path) {
    final file = archive.findFile(path);
    expect(file, isNotNull, reason: 'Expected ZIP entry $path');
    return utf8.decode(file!.content as List<int>);
  }

  test('exports every database table as JSON and CSV', () async {
    final db = await database.database;
    await database.saveBodyWeight(date: '2026-11-05', weightKg: 88.4);
    await database.saveActivityLog(
      activityType: 'Walking',
      activityDate: '2026-11-05',
      durationMinutes: 25,
      steps: 3200,
      notes: 'Evening, walk',
    );
    await db.insert('food_logs', {
      'log_date': '2026-11-05',
      'meal_type': 'BREAKFAST',
      'food_name_snapshot': 'Oats',
      'quantity_g': 50,
      'quantity_value': 50,
      'quantity_unit': 'g',
      'base_quantity': 50,
      'base_unit': 'g',
      'serving_name_snapshot': 'g',
      'calories': 190,
      'protein_g': 6,
      'carbs_g': 32,
      'fat_g': 4,
      'created_at': '2026-11-05T07:00:00',
      'updated_at': '2026-11-05T07:00:00',
    });

    final output = await exportService.createExport(includePhotos: false);
    expect(await output.exists(), isTrue);
    expect(output.path, contains('FlexFusion_Export_'));

    final archive = await readArchive(output);
    final backup = jsonDecode(readText(archive, 'complete_backup.json'))
        as Map<String, dynamic>;
    final tables = backup['tables'] as Map<String, dynamic>;

    expect(backup['format'], 'flexfusion_complete_backup');
    expect(backup['format_version'], 1);
    expect(backup['progress_photos_included'], isFalse);
    expect(tables['body_weights'], isA<List>());
    expect(tables['food_logs'], isA<List>());
    expect(tables['activity_logs'], isA<List>());
    expect(archive.findFile('data/body_weights.csv'), isNotNull);
    expect(archive.findFile('data/workout_sets.csv'), isNotNull);
    expect(readText(archive, 'README.txt'), contains('FlexFusion data export'));

    final foodCsv = readText(archive, 'data/food_logs.csv');
    expect(foodCsv, contains('"Oats"'));
    expect(foodCsv, contains('"190'));
  });

  test('includes original progress photo bytes and portable relative path', () async {
    final photoFile = File(p.join(tempDirectory.path, 'front.jpg'));
    final photoBytes = [0, 1, 2, 3, 250, 251, 252];
    await photoFile.writeAsBytes(photoBytes);
    await database.saveProgressPhoto(
      date: '2026-11-05',
      angle: 'front',
      localFilePath: photoFile.path,
    );

    final output = await exportService.createExport(includePhotos: true);
    final archive = await readArchive(output);
    final backup = jsonDecode(readText(archive, 'complete_backup.json'))
        as Map<String, dynamic>;
    final tables = backup['tables'] as Map<String, dynamic>;
    final photo = (tables['progress_photos'] as List).single as Map<String, dynamic>;
    final relativePath = photo['local_file_path'] as String;

    expect(relativePath, startsWith('progress/photos/'));
    expect(relativePath, contains('2026-11-05_front_'));
    expect(relativePath, endsWith('.jpg'));
    expect(photo['photo_date'], '2026-11-05');
    expect(photo['angle'], 'front');

    final archivedPhoto = archive.findFile(relativePath);
    expect(archivedPhoto, isNotNull);
    expect(archivedPhoto!.content, photoBytes);
    expect(backup['missing_progress_photo_ids'], isEmpty);
    expect(await photoFile.readAsBytes(), photoBytes);
  });

  test('excludes photo files when photos are disabled and preserves source data', () async {
    final photoFile = File(p.join(tempDirectory.path, 'side.jpg'));
    await photoFile.writeAsBytes([10, 20, 30]);
    await database.saveProgressPhoto(
      date: '2026-11-04',
      angle: 'side',
      localFilePath: photoFile.path,
    );

    final output = await exportService.createExport(includePhotos: false);
    final archive = await readArchive(output);
    final backup = jsonDecode(readText(archive, 'complete_backup.json'))
        as Map<String, dynamic>;
    final tables = backup['tables'] as Map<String, dynamic>;
    final photo = (tables['progress_photos'] as List).single as Map<String, dynamic>;

    expect(backup['progress_photos_included'], isFalse);
    expect(photo['local_file_path'], isNull);
    expect(archive.files.where((file) => file.name.startsWith('progress/photos/')), isEmpty);
    expect(await photoFile.exists(), isTrue);

    final db = await database.database;
    final storedPhoto = (await db.query('progress_photos')).single;
    expect(storedPhoto['local_file_path'], photoFile.path);
  });
}
