import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/local/app_database.dart';

/// Creates a portable ZIP containing every SQLite table and optional
/// progress-photo files. The live database and photo files are never changed.
class DataExportService {
  DataExportService({Future<Directory> Function()? tempDirectoryProvider})
      : _tempDirectoryProvider =
            tempDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDirectoryProvider;

  Future<File> createExport({required bool includePhotos}) async {
    final db = await AppDatabase.instance.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name",
    );

    final archive = Archive();
    final exportedTables = <String, List<Map<String, Object?>>>{};
    final missingPhotoIds = <int>[];
    final photoManifest = <Map<String, Object?>>[];

    for (final tableRow in tables) {
      final tableName = tableRow['name'] as String;
      final rows = await db.query(tableName);
      final exportedRows = <Map<String, Object?>>[];

      for (final row in rows) {
        final record = Map<String, Object?>.from(row);
        if (tableName == 'progress_photos') {
          final photoId = record['id'] as int?;
          final sourcePath = record['local_file_path'] as String?;
          String? archivePath;

          if (includePhotos && sourcePath != null && sourcePath.isNotEmpty) {
            final sourceFile = File(sourcePath);
            if (await sourceFile.exists()) {
              final extension = p.extension(sourcePath).isEmpty
                  ? '.jpg'
                  : p.extension(sourcePath).toLowerCase();
              final date = _safeFilePart(record['photo_date']?.toString() ?? 'unknown');
              final angle = _safeFilePart(record['angle']?.toString() ?? 'photo');
              archivePath = 'progress/photos/${date}_${angle}_${photoId ?? 0}$extension';
              final bytes = await sourceFile.readAsBytes();
              archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
            } else if (photoId != null) {
              missingPhotoIds.add(photoId);
            }
          } else if (includePhotos && photoId != null) {
            missingPhotoIds.add(photoId);
          }

          record['local_file_path'] = archivePath;
          photoManifest.add({
            'id': photoId,
            'date': record['photo_date'],
            'angle': record['angle'],
            'file': archivePath,
            'included': archivePath != null,
          });
        }
        exportedRows.add(record);
      }

      exportedTables[tableName] = exportedRows;
      final csv = _toCsv(exportedRows);
      archive.addFile(
        ArchiveFile('data/$tableName.csv', utf8.encode(csv).length, utf8.encode(csv)),
      );
    }

    final exportedAt = DateTime.now().toUtc().toIso8601String();
    final backup = <String, Object?>{
      'format': 'flexfusion_complete_backup',
      'format_version': 1,
      'app': 'FlexFusion',
      'exported_at_utc': exportedAt,
      'database_schema_version': AppDatabase.schemaVersion,
      'progress_photos_included': includePhotos,
      'progress_photo_manifest': photoManifest,
      'missing_progress_photo_ids': missingPhotoIds,
      'tables': exportedTables,
    };
    _addTextFile(
      archive,
      'complete_backup.json',
      const JsonEncoder.withIndent('  ').convert(backup),
    );

    final readme = '''
FlexFusion data export

Exported at (UTC): $exportedAt
Database schema version: ${AppDatabase.schemaVersion}
Progress photos requested: ${includePhotos ? 'Yes' : 'No'}

Contents:
- complete_backup.json: structured snapshot of all app database tables.
- data/: CSV version of each exported database table, suitable for spreadsheet tools.
- progress/photos/: original progress photo files, when included and available.

Progress photo records retain their date and angle. In the JSON backup, local_file_path
contains the relative path inside this ZIP when the image was included; it is null
when the image was excluded or its source file was unavailable.

This export does not modify or delete any FlexFusion data. Keep this ZIP in a
private, secure location because it may contain personal fitness information.
''';
    _addTextFile(archive, 'README.txt', readme);

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('FlexFusion could not create the export archive.');
    }

    final tempDirectory = await _tempDirectoryProvider();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final output = File(p.join(tempDirectory.path, 'FlexFusion_Export_$timestamp.zip'));
    await output.writeAsBytes(encoded, flush: true);
    return output;
  }

  void _addTextFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _safeFilePart(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  String _toCsv(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return '';
    final columns = <String>[];
    for (final row in rows) {
      for (final key in row.keys) {
        if (!columns.contains(key)) columns.add(key);
      }
    }

    String cell(Object? value) {
      if (value == null) return '';
      final text = value is Map || value is List
          ? jsonEncode(value)
          : value.toString();
      return '"${text.replaceAll('"', '""')}"';
    }

    return '${[columns.map(cell).join(','), ...rows.map((row) => columns.map((key) => cell(row[key])).join(','))].join('\r\n')}\r\n';
  }
}
