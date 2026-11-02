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

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => TrainScreenState();
}

class TrainScreenState extends State<TrainScreen> {
  final _weightController = TextEditingController();
  final _picker = ImagePicker();
  late Future<_TrainData> _dataFuture;

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

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void refreshTrainScreen() {
    if (!mounted) return;
    setState(() => _dataFuture = _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel =
        '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)} ${now.year}';

    return FutureBuilder<_TrainData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final latestWeight = (data?.latestWeight?['weight_value'] as num?)?.toDouble();
        final workoutCount = data?.weekly['workouts'] as int? ?? 0;
        final days = (data?.weekly['daily'] as List<dynamic>?) ?? const [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.green,
              backgroundColor: AppColors.card,
              onRefresh: () async => refreshTrainScreen(),
              child: SingleChildScrollView(
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
                        color: AppColors.grey,
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
                    const SizedBox(height: 5),
                    Text(
                      dateLabel,
                      style: GoogleFonts.inter(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                            'this week',
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
                    _buildPhotoCard(data?.photos ?? const []),
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
          children: [
            Text(
              'TRAIN',
              style: GoogleFonts.inter(
                color: AppColors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
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
                if (selected != null && mounted) {
                  _showInfo('Workout calendar', 'Calendar view will be added with workout planning.');
                }
              },
              icon: const Icon(Icons.calendar_month_outlined, color: AppColors.white),
              tooltip: 'Calendar',
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Track, progress, grow',
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 17),
        Container(height: 1, color: AppColors.border),
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
                'THIS WEEK',
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
              final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index];
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
          Text('Today’s weight', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
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
                    return GestureDetector(
                      onTap: () => _openProgressPhoto(path, dateLabel(entry.key), angle),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          width: 92,
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
    await AppDatabase.instance.saveBodyWeight(date: _dateKey(DateTime.now()), weightKg: value);
    _weightController.clear();
    refreshTrainScreen();
    _showInfo('Weight saved', 'Today’s weigh-in has been saved.');
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
    if (picked == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final date = _dateKey(DateTime.now());
    final fileName = 'progress_${date}_${angle}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(picked.path).copy('${directory.path}/$fileName');
    await AppDatabase.instance.saveProgressPhoto(
      date: date,
      angle: angle,
      localFilePath: saved.path,
    );
    refreshTrainScreen();
    _showInfo('Photo saved', 'Your $angle progress photo is saved on this device.');
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
