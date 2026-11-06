import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/auto_refresh_on_return.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class DailySnapScreen extends StatefulWidget {
  const DailySnapScreen({super.key});

  @override
  State<DailySnapScreen> createState() => _DailySnapScreenState();
}

class _DailySnapScreenState extends State<DailySnapScreen> with AutoRefreshOnReturn<DailySnapScreen> {
  @override
  Future<void> refreshAfterReturn() => _refresh();

  final ImagePicker _picker = ImagePicker();
  late Future<List<Map<String, Object?>>> _photosFuture;
  DateTime _selectedDay = DateTime.now();

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void initState() {
    super.initState();
    _photosFuture = _loadPhotos();
  }

  Future<List<Map<String, Object?>>> _loadPhotos() =>
      AppDatabase.instance.getProgressPhotos(limit: 1000);

  Future<void> _refresh() async {
    final future = _loadPhotos();
    setState(() => _photosFuture = future);
    await future;
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isAfter(today) ? today : _selectedDay,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'SELECT PHOTO DATE',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.green,
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDay = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _addPhoto() async {
    if (kIsWeb) {
      _showInfo('Photo logging', 'Progress photo logging is currently available only in the iOS app.');
      return;
    }

    final angle = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose photo angle', style: GoogleFonts.inter(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final value in ['front', 'side', 'back'])
                ListTile(
                  leading: const Icon(Icons.person_outline, color: AppColors.green),
                  title: Text(value[0].toUpperCase() + value.substring(1), style: GoogleFonts.inter(color: AppColors.white)),
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (angle == null || !mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.green),
              title: Text('Choose from photos', style: GoogleFonts.inter(color: AppColors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.green),
              title: Text('Take a photo', style: GoogleFonts.inter(color: AppColors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 88);
    if (picked == null || !mounted) return;

    final date = _dateKey(_selectedDay);
    File? saved;
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (!mounted) return;
      final fileName = 'progress_${date}_${angle}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      saved = await File(picked.path).copy('${directory.path}/$fileName');
      final previousPath = await AppDatabase.instance.saveProgressPhoto(
        date: date,
        angle: angle,
        localFilePath: saved.path,
      );
      if (previousPath != null && previousPath != saved.path) {
        try {
          final previousFile = File(previousPath);
          if (await previousFile.exists()) await previousFile.delete();
        } catch (_) {
          // Keep the newly saved photo even if cleanup of the old file fails.
        }
      }
      if (!mounted) return;
      await _refresh();
      _showInfo('Photo saved', 'Your $angle progress photo is saved on this device.');
    } catch (error) {
      if (saved != null) {
        try {
          if (await saved.exists()) await saved.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      debugPrint('[DailySnap] Photo save failed: $error');
      _showInfo('Photo not saved', 'Please check photo permissions and available device storage, then try again.');
    }
  }

  Future<void> _deletePhoto(Map<String, Object?> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete progress photo?', style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete this photo from this device and remove its record from FlexFusion.',
          style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('DELETE', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final photoId = photo['id'] as int;
    final path = photo['local_file_path'] as String?;
    String? pendingPath;
    try {
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          pendingPath = '$path.delete_pending';
          await file.rename(pendingPath);
        }
      }
      try {
        await AppDatabase.instance.deleteProgressPhoto(photoId);
      } catch (_) {
        if (pendingPath != null) {
          final pendingFile = File(pendingPath);
          if (await pendingFile.exists()) await pendingFile.rename(path!);
        }
        rethrow;
      }
      if (pendingPath != null) {
        try {
          final pendingFile = File(pendingPath);
          if (await pendingFile.exists()) await pendingFile.delete();
        } catch (error) {
          debugPrint('[DailySnap] Deleted photo left a pending file: $error');
        }
      }
      if (!mounted) return;
      await _refresh();
      _showInfo('Photo deleted', 'The photo and its local database record have been deleted.');
    } catch (error) {
      if (!mounted) return;
      debugPrint('[DailySnap] Photo deletion failed: $error');
      _showInfo('Delete failed', 'The photo could not be deleted. Please try again.');
    }
  }

  void _openPhoto(String path, String date, String angle) {
    if (kIsWeb) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: AppColors.white,
          title: Text('$date • $angle', style: GoogleFonts.inter(fontSize: 12)),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: AppColors.grey, size: 48),
            ),
          ),
        ),
      ),
    ));
  }

  String _dateLabel(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[parsed.weekday - 1]}, ${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  void _showInfo(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$title — $message', style: const TextStyle(color: AppColors.white)),
      backgroundColor: AppColors.surface,
    ));
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        title: Text('LOG DAILY SNAP', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _photosFuture,
        builder: (context, snapshot) {
          final photos = snapshot.data ?? const <Map<String, Object?>>[];
          final grouped = <String, List<Map<String, Object?>>>{};
          for (final photo in photos) {
            final date = photo['photo_date'] as String? ?? 'Unknown date';
            grouped.putIfAbsent(date, () => []).add(photo);
          }
          return RefreshIndicator(
            color: AppColors.green,
            backgroundColor: AppColors.card,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: _cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('DAILY PROGRESS PHOTO', style: GoogleFonts.inter(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 7),
                    Text('Capture your progress consistently.', style: GoogleFonts.inter(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Choose a date and save a front, side or back photo. Your photos stay stored on this device.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          const Icon(Icons.calendar_month_outlined, color: AppColors.green, size: 18),
                          const SizedBox(width: 9),
                          Expanded(child: Text(_formatDate(_selectedDay), style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                          const Icon(Icons.chevron_right, color: AppColors.grey, size: 18),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: const Text('ADD DAILY SNAP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          textStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('PHOTO TIMELINE', style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .7)),
                  Text('${photos.length} PHOTOS', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                  const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: AppColors.green)))
                else if (grouped.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: _cardDecoration(),
                    child: Column(children: [
                      const Icon(Icons.photo_library_outlined, color: AppColors.grey, size: 32),
                      const SizedBox(height: 9),
                      Text('No progress photos yet. Add your first daily snap above.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                    ]),
                  )
                else
                  for (final entry in grouped.entries) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(13),
                      decoration: _cardDecoration(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.calendar_today_outlined, color: AppColors.green, size: 14),
                          const SizedBox(width: 7),
                          Expanded(child: Text(_dateLabel(entry.key), style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                          Text('${entry.value.length} photo${entry.value.length == 1 ? '' : 's'}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9)),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: entry.value.map((photo) {
                            final path = photo['local_file_path'] as String;
                            final angle = (photo['angle'] as String? ?? '').toUpperCase();
                            return SizedBox(
                              width: 92,
                              height: 126,
                              child: Stack(children: [
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () => _openPhoto(path, _dateLabel(entry.key), angle),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Column(children: [
                                        Expanded(child: kIsWeb
                                            ? Container(color: AppColors.surface, child: const Icon(Icons.image, color: AppColors.grey))
                                            : Image.file(File(path), width: 92, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surface, child: const Icon(Icons.broken_image_outlined, color: AppColors.grey)))),
                                        Container(width: double.infinity, color: AppColors.surface, padding: const EdgeInsets.symmetric(vertical: 5), child: Text(angle, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700))),
                                      ]),
                                    ),
                                  ),
                                ),
                                Positioned(top: 4, right: 4, child: Material(
                                  color: Colors.black.withValues(alpha: .72),
                                  shape: const CircleBorder(),
                                  child: InkWell(customBorder: const CircleBorder(), onTap: () => _deletePhoto(photo), child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.delete_outline, color: Colors.white, size: 16))),
                                )),
                              ]),
                            );
                          }).toList(),
                        ),
                      ]),
                    ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}
