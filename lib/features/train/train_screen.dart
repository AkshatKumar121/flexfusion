import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'workout_plan_screen.dart';
import 'workout_session_screen.dart';
import 'training_streak_screen.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => TrainScreenState();
}

class TrainScreenState extends State<TrainScreen> {
  final _weightController = TextEditingController();
  final _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  late Future<_TrainData> _dataFuture;
  _TrainData? _cachedTrainData;
  final Set<int> _deletedProgressPhotoIds = <int>{};
  late DateTime _selectedDay;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<_TrainData> _loadData() async {
    final db = AppDatabase.instance;
    final latestWeight = await db.getLatestBodyWeight();
    final photos = await db.getProgressPhotos(limit: 1000);
    final weekly = await db.getWeeklyProgressDetails();
    return _TrainData(
      latestWeight: latestWeight,
      photos: photos,
      weekly: weekly,
    );
  }

  Future<_TrainData> _loadDataAndCache() async {
    final data = await _loadData();
    _cachedTrainData = data;
    return data;
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _today;
    _dataFuture = _loadDataAndCache();
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2000),
      lastDate: _today,
      helpText: 'SELECT TRAINING LOG DATE',
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
    if (picked == null || !mounted) return;
    setState(() => _selectedDay = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  void dispose() {
    _weightController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refreshTrainScreen() async {
    if (!mounted) return;
    final refreshedData = _loadDataAndCache();
    setState(() => _dataFuture = refreshedData);
    await refreshedData;
    if (mounted && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TrainData>(
      future: _dataFuture,
      initialData: _cachedTrainData,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _cachedTrainData;
        final latestWeight = (data?.latestWeight?['weight_value'] as num?)?.toDouble();
        final workoutCount = data?.weekly['workouts'] as int? ?? 0;
        final days = (data?.weekly['daily'] as List<dynamic>?) ?? const [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.green,
              backgroundColor: AppColors.card,
              onRefresh: refreshTrainScreen,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    Text(
                      'YOUR TRAINING SPACE',
                      style: GoogleFonts.inter(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Build strength. Track progress.',
                      style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, color: AppColors.green, size: 19),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _selectedDay == _today
                                    ? 'TODAY • ${_formatDate(_selectedDay)}'
                                    : _formatDate(_selectedDay),
                                style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text('CHANGE DATE', style: GoogleFonts.inter(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 5),
                            const Icon(Icons.chevron_right, color: AppColors.grey, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildWorkoutCard(),
                    const SizedBox(height: 14),
                    _buildWeekCard(workoutCount, days),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'LATEST WEIGHT',
                            latestWeight == null ? '—' : latestWeight.toStringAsFixed(1),
                            latestWeight == null ? 'Log today' : 'kg',
                            Icons.monitor_weight_outlined,
                            AppColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'WORKOUTS',
                            workoutCount.toString(),
                            'last 7 days',
                            Icons.fitness_center,
                            AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _buildSectionTitle('DAILY BODY WEIGHT', 'Log your weigh-in'),
                    const SizedBox(height: 12),
                    _buildWeightLogCard(latestWeight),
                    const SizedBox(height: 22),
                    _buildSectionTitle('PROGRESS PHOTOS', 'Track visual changes'),
                    const SizedBox(height: 12),
                    _buildPhotoCard((data?.photos ?? const []).where((photo) => !_deletedProgressPhotoIds.contains(photo['id'] as int)).toList()),
                    const SizedBox(height: 22),
                    _buildSectionTitle('YOUR WORKOUT TOOLS', 'Plan and review'),
                    const SizedBox(height: 12),
                    _buildToolTile(
                      Icons.calendar_month_outlined,
                      'My Plan',
                      'Create and manage your training split',
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkoutPlanScreen())),
                    ),
                    _buildToolTile(
                      Icons.fitness_center,
                      'Exercise Library',
                      'Browse exercises and target muscles',
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExerciseLibraryScreen())),
                    ),
                    _buildToolTile(
                      Icons.history,
                      'Workout History',
                      'Review completed training sessions',
                      () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const WorkoutHistoryScreen()),
                        );
                        if (mounted) refreshTrainScreen();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 130,
              height: 48,
              child: Image.asset(
                'assets/images/fxf_logo.jpg',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
            Transform.translate(
              offset: const Offset(-25, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(height: 38, width: 2, color: const Color(0xFF555555)),
                  const SizedBox(width: 13),
                  Transform.translate(
                    offset: const Offset(0, 1),
                    child: Text(
                      'TRAINER',
                      style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Workout and activity streak',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TrainingStreakScreen(),
                ),
              ),
              icon: const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF3D70),
                size: 29,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(height: 1, color: const Color(0xFF292929)),
      ],
    );
  }

  Widget _buildWorkoutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.green, size: 19),
              const SizedBox(width: 7),
              Text(
                'READY WHEN YOU ARE',
                style: GoogleFonts.inter(
                  color: AppColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Your next workout',
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Start your planned session or create a workout plan.',
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkoutLauncherScreen()));
                if (mounted) refreshTrainScreen();
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('START WORKOUT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCard(int count, List<dynamic> days) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'LAST 7 DAYS',
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '$count completed',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(7, (index) {
              final day = index < days.length ? days[index] as Map : <String, dynamic>{};
              final completed = (day['workouts'] as int? ?? 0) > 0;
              final label = (day['day'] as String?) ?? '—';
              return Expanded(
                child: Column(
                  children: [
                    Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
                    const SizedBox(height: 8),
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completed ? AppColors.green : AppColors.surface,
                        border: Border.all(color: completed ? AppColors.green : AppColors.border),
                      ),
                      child: Icon(
                        completed ? Icons.check : Icons.circle_outlined,
                        size: 14,
                        color: completed ? Colors.black : AppColors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String unit, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
              Icon(icon, color: accent, size: 19),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(width: 5),
              Text(unit, style: GoogleFonts.inter(color: accent, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
        ),
        Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildWeightLogCard(double? latestWeight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_selectedDay == _today ? 'Today’s weight' : 'Weight • ${_formatDate(_selectedDay)}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: latestWeight?.toStringAsFixed(1) ?? 'Enter weight in kg',
                    hintStyle: GoogleFonts.inter(color: AppColors.grey, fontSize: 14),
                    suffixText: 'kg',
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saveWeight,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                child: Text('SAVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('One entry per day. Saving again updates today’s weigh-in.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(List<Map<String, Object?>> photos) {
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final photo in photos) {
      final date = photo['photo_date'] as String? ?? 'Unknown date';
      grouped.putIfAbsent(date, () => []).add(photo);
    }

    String dateLabel(String value) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return value;
      return '${_weekday(parsed.weekday)}, ${parsed.day} ${_month(parsed.month)} ${parsed.year}';
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addProgressPhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('ADD PROGRESS PHOTO'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (grouped.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.photo_library_outlined, color: AppColors.grey, size: 30),
                    const SizedBox(height: 8),
                    Text('Your date-wise progress photo timeline will appear here.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
                  ],
                ),
              ),
            )
          else
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.green, size: 14),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        dateLabel(entry.key),
                        style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${entry.value.length} photo${entry.value.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 126,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.value.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final photo = entry.value[index];
                    final path = photo['local_file_path'] as String;
                    final angle = (photo['angle'] as String? ?? '').toUpperCase();
                    return SizedBox(
                      width: 92,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => _openProgressPhoto(path, dateLabel(entry.key), angle),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: kIsWeb
                                          ? Container(color: AppColors.surface, child: const Icon(Icons.image, color: AppColors.grey))
                                          : Image.file(
                                              File(path),
                                              width: 92,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: AppColors.surface,
                                                child: const Icon(Icons.broken_image_outlined, color: AppColors.grey),
                                              ),
                                            ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      color: AppColors.surface,
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      child: Text(
                                        angle,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.72),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _deleteProgressPhoto(photo),
                                child: const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Icon(Icons.delete_outline, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }

  Future<void> _deleteProgressPhoto(Map<String, Object?> photo) async {
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final photoId = photo['id'] as int;
    final path = photo['local_file_path'] as String?;

    // Hide the tile while the file and database record are removed safely.
    setState(() => _deletedProgressPhotoIds.add(photoId));
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
        // Restore the original file if the database record could not be deleted.
        if (pendingPath != null) {
          final pendingFile = File(pendingPath);
          if (await pendingFile.exists()) {
            await pendingFile.rename(path!);
          }
        }
        rethrow;
      }

      // The DB record is now gone. Cleanup failure must not report the
      // deletion as failed or attempt to restore a record that no longer exists.
      if (pendingPath != null) {
        try {
          final pendingFile = File(pendingPath);
          if (await pendingFile.exists()) await pendingFile.delete();
        } catch (error) {
          debugPrint('[ProgressPhoto] Deleted photo left a pending file: $error');
        }
      }
      if (!mounted) return;
      refreshTrainScreen();
      _showInfo('Photo deleted', 'The photo and its local database record have been deleted.');
    } catch (error) {
      debugPrint('[ProgressPhoto] Photo deletion failed: $error');
      if (!mounted) return;
      setState(() => _deletedProgressPhotoIds.remove(photoId));
      refreshTrainScreen();
      _showInfo('Delete failed', 'The photo could not be deleted. Please try again.');
    }
  }

  void _openProgressPhoto(String path, String date, String angle) {
    if (kIsWeb) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
      ),
    );
  }

  Widget _buildToolTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.green, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  );

  Future<void> _saveWeight() async {
    final value = double.tryParse(_weightController.text.trim());
    if (value == null || value < 20 || value > 400) {
      _showInfo('Check weight', 'Enter a valid weight in kg.');
      return;
    }
    await AppDatabase.instance.saveBodyWeight(date: _dateKey(_selectedDay), weightKg: value);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    _weightController.clear();
    refreshTrainScreen();
    _showInfo('Weight saved', 'Your ${_formatDate(_selectedDay)} weigh-in has been saved.');
  }

  Future<void> _addProgressPhoto() async {
    if (kIsWeb) {
      _showInfo('Photo logging', 'Progress photo logging is currently available only in the iOS app. Web support will be added separately.');
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
    final directory = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    final date = _dateKey(_selectedDay);
    final fileName = 'progress_${date}_${angle}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    File? saved;
    try {
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
      refreshTrainScreen();
      _showInfo('Photo saved', 'Your $angle progress photo is saved on this device.');
    } catch (_) {
      if (saved != null) {
        try {
          if (await saved.exists()) await saved.delete();
        } catch (_) {
          // Best-effort cleanup after a failed save.
        }
      }
      if (!mounted) return;
      _showInfo('Photo not saved', 'Please check photo permissions and available device storage, then try again.');
    }
  }

  void _showInfo(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — $message', style: const TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  String _weekday(int day) => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day - 1];
  String _month(int month) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];
}

class _TrainData {
  final Map<String, Object?>? latestWeight;
  final List<Map<String, Object?>> photos;
  final Map<String, Object?> weekly;

  const _TrainData({
    required this.latestWeight,
    required this.photos,
    required this.weekly,
  });
}
