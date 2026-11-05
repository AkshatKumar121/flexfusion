import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/flexfusion_brand_header.dart';
import '../../data/local/app_database.dart';
import 'workout_plan_screen.dart';
import 'exercise_library_screen.dart';
import 'workout_session_screen.dart';
import 'workout_launcher_screen.dart';
import 'workout_history_screen.dart';
import 'training_streak_screen.dart';
import 'daily_snap_screen.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => TrainScreenState();
}

class TrainScreenState extends State<TrainScreen> {
  final _weightController = TextEditingController();
  late Future<_TrainData> _dataFuture;
  _TrainData? _cachedTrainData;
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
    final weekly = await db.getWeeklyProgressDetails();
    final activeWorkout = await db.getInProgressWorkout();
    return _TrainData(
      latestWeight: latestWeight,
      weekly: weekly,
      activeWorkout: activeWorkout,
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
    super.dispose();
  }

  Future<void> refreshTrainScreen() async {
    if (!mounted) return;
    final refreshedData = _loadDataAndCache();
    setState(() {
      _dataFuture = refreshedData;
    });
    await refreshedData;
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
                    _buildWorkoutCard(data),
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
                    _buildSectionTitle('DAILY PROGRESS PHOTO', 'Track visual changes'),
                    const SizedBox(height: 12),
                    _buildToolTile(
                      Icons.add_a_photo_outlined,
                      'Log Daily Snap',
                      'Capture and review your progress photos',
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DailySnapScreen())),
                    ),
                    const SizedBox(height: 12),
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
    return FlexFusionBrandHeader(
      trailingAction: IconButton(
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
    );
  }

  Widget _buildWorkoutCard(_TrainData? trainData) {
    final activeWorkout = trainData?.activeWorkout;
    final hasActiveWorkout = activeWorkout != null;
    final isWorkoutPaused = activeWorkout?['paused_at'] != null;
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
                hasActiveWorkout
                    ? (isWorkoutPaused ? 'WORKOUT PAUSED' : 'WORKOUT IN PROGRESS')
                    : 'READY WHEN YOU ARE',
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
          FutureBuilder<Map<String, Object?>?>(
            future: AppDatabase.instance.getManualStartWorkoutDay(),
            builder: (context, snapshot) {
              final nextDay = snapshot.data;
              final workoutName = hasActiveWorkout
                  ? '${isWorkoutPaused ? 'Resume' : 'Ongoing'} ${activeWorkout['session_name']}'
                  : nextDay == null || nextDay['no_days'] == true
                      ? 'Your next workout'
                      : 'Your next workout ${nextDay['label']}';
              return Text(
                workoutName,
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 5),
          Text(
            hasActiveWorkout
                ? (isWorkoutPaused
                    ? 'Your workout is paused. Resume when you are ready.'
                    : 'Your workout is underway. Continue your current session.')
                : 'Start your planned session or create a workout plan.',
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (activeWorkout != null) {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => WorkoutSessionScreen(
                      workoutId: activeWorkout['id'] as int,
                      title: activeWorkout['session_name'] as String,
                    ),
                  ));
                } else {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkoutLauncherScreen()));
                }
                if (mounted) refreshTrainScreen();
              },
              icon: Icon(hasActiveWorkout ? Icons.play_arrow_rounded : Icons.play_arrow, size: 18),
              label: Text(
                hasActiveWorkout
                    ? (isWorkoutPaused ? 'RESUME WORKOUT' : 'GO TO ONGOING WORKOUT')
                    : 'START WORKOUT',
              ),
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
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: GoogleFonts.inter(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: latestWeight?.toStringAsFixed(1) ?? 'Enter weight in kg',
                    hintStyle: GoogleFonts.inter(color: AppColors.grey, fontSize: 14),
                    suffixText: 'kg',
                    suffixIcon: IconButton(
                      tooltip: 'Hide keyboard',
                      onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                      icon: const Icon(Icons.keyboard_hide_outlined, color: AppColors.grey),
                    ),
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

  void _showInfo(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — $message', style: const TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.surface,
      ),
    );
  }

}

class _TrainData {
  final Map<String, Object?>? latestWeight;
  final Map<String, Object?> weekly;
  final Map<String, Object?>? activeWorkout;

  const _TrainData({
    required this.latestWeight,
    required this.weekly,
    required this.activeWorkout,
  });
}
