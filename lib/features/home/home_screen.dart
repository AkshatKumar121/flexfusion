
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/flexfusion_brand_header.dart';
import '../../data/local/app_database.dart';
import '../profile/profile_screen.dart';
import 'weekly_progress_screen.dart';
import 'workout_analysis_screen.dart';
import '../train/workout_session_screen.dart';
import '../train/workout_launcher_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenEat;
  final VoidCallback? onOpenActivity;
  const HomeScreen({super.key, this.onOpenEat, this.onOpenActivity});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late Future<_DashboardData> _dashboardFuture;
  _DashboardData? _cachedDashboardData;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatWeightDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _showWeightLogger() async {
    final database = AppDatabase.instance;
    var selectedDate = DateTime.now();
    final dateKey = _dateKey(selectedDate);
    final existing = await database.getBodyWeightForDate(dateKey);

    if (!mounted) return;
    final controller = TextEditingController(
      text: existing == null
          ? ''
          : (existing['weight_value'] as num).toString(),
    );
    var hasExistingEntry = existing != null;
    var isSaving = false;
    String? errorMessage;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            hasExistingEntry ? 'Edit weight' : 'Log weight',
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One entry per day. You can update it anytime.',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked == null) return;
                  final date = DateTime(picked.year, picked.month, picked.day);
                  final record = await database.getBodyWeightForDate(_dateKey(date));
                  setDialogState(() {
                    selectedDate = date;
                    hasExistingEntry = record != null;
                    controller.text = record == null
                        ? ''
                        : (record['weight_value'] as num).toString();
                    errorMessage = null;
                  });
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_formatWeightDate(selectedDate)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: !hasExistingEntry,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                  labelStyle: GoogleFonts.inter(color: AppColors.grey),
                  suffixStyle: GoogleFonts.inter(color: AppColors.green),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.green),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: GoogleFonts.inter(color: AppColors.red, fontSize: 11),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(false),
              child: Text('CANCEL', style: GoogleFonts.inter(color: AppColors.grey)),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final value = double.tryParse(controller.text.trim());
                      if (value == null || !value.isFinite || value <= 0 || value > 500) {
                        setDialogState(() => errorMessage = 'Enter a valid weight in kg.');
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });
                      try {
                        await database.saveBodyWeight(
                          date: _dateKey(selectedDate),
                          weightKg: value,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (_) {
                        setDialogState(() {
                          isSaving = false;
                          errorMessage = 'Could not save weight. Please try again.';
                        });
                      }
                    },
              child: Text(
                hasExistingEntry ? 'UPDATE WEIGHT' : 'SAVE WEIGHT',
                style: GoogleFonts.inter(
                  color: AppColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true) await refreshDashboard();
  }

  Future<_DashboardData> _loadDashboard() async {
    final db = AppDatabase.instance;
    final results = await Future.wait<Object?>([
      db.getDashboardNutrition(_dateKey(DateTime.now())),
      db.getRecentBodyWeights(),
      db.getLatestBodyWeight(),
      db.getNutritionTargets(),
      db.getWeeklyProgressDetails(),
      db.getSuggestedWorkoutDay(),
      db.getInProgressWorkout(),
      db.getCompletedWorkoutToday(),
      db.getAppSetting('weight_unit', defaultValue: 'kg'),
      db.getUserProfile(),
    ]);
    final nutrition = results[0] as Map<String, double>;
    final weights = results[1] as List<Map<String, Object?>>;
    final latestWeight = results[2] as Map<String, Object?>?;
    final targets = results[3] as Map<String, Object?>?;
    final weekly = results[4] as Map<String, Object?>;
    final suggestedWorkoutDay = results[5] as Map<String, Object?>?;
    final activeWorkout = results[6] as Map<String, Object?>?;
    final completedWorkoutToday = results[7] as Map<String, Object?>?;
    final weightUnit = results[8] as String;
    final profile = results[9] as Map<String, Object?>?;
    final displayName = (profile?['display_name'] as String? ?? '').trim();
    final suggestedExercises = suggestedWorkoutDay == null ||
            (suggestedWorkoutDay['is_rest_day'] as int? ?? 0) == 1
        ? <Map<String, Object?>>[]
        : await db.getPlanDayExercises(suggestedWorkoutDay['id'] as int);
    return _DashboardData(
      nutrition: nutrition,
      weights: weights,
      latestWeight: latestWeight,
      targets: targets,
      weekly: weekly,
      weightUnit: weightUnit,
      displayName: displayName,
      suggestedWorkoutDay: suggestedWorkoutDay,
      suggestedExerciseCount: suggestedExercises.length,
      activeWorkout: activeWorkout,
      completedWorkoutToday: completedWorkoutToday,
    );
  }

  Future<_DashboardData> _loadDashboardAndCache() async {
    final data = await _loadDashboard();
    _cachedDashboardData = data;
    return data;
  }

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardAndCache();
  }

  Future<void> refreshDashboard() async {
    if (!mounted) return;
    final future = _loadDashboardAndCache();
    setState(() {
      _dashboardFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    // CURRENT DATE AND TIME
    final now = DateTime.now();

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    // DYNAMIC GREETING
    final hour = now.hour;

    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // TODAY'S DATE
    final today =
        '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}';

    return FutureBuilder<_DashboardData>(
      future: _dashboardFuture,
      initialData: _cachedDashboardData,
      builder: (dashboardContext, snapshot) {
        final data = snapshot.data ?? _cachedDashboardData;
        final kcal = data?.nutrition['calories'] ?? 0.0;
        final protein = data?.nutrition['protein'] ?? 0.0;
        final calorieTarget = (data?.targets?['calorie_target'] as num?)?.toDouble() ?? 2200.0;
        final proteinTarget = (data?.targets?['protein_target_g'] as num?)?.toDouble() ?? 180.0;
        final currentWeight = data?.latestWeight == null
            ? null
            : (data!.latestWeight!['weight_value'] as num).toDouble();
        return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          backgroundColor: AppColors.card,
          onRefresh: refreshDashboard,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlexFusionBrandHeader(
                trailingAction: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                  tooltip: 'Profile',
                ),
              ),

              const SizedBox(height: 32),

              // PERSONALIZED GREETING
              Text(
                data == null || data.displayName.isEmpty
                    ? '$greeting!'
                    : '$greeting, ${data.displayName}!',
                style: GoogleFonts.inter(
                  color: AppColors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 6),

              // TODAY'S DAY AND DATE
              Text(
                today,
                style: GoogleFonts.inter(
                  color: AppColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Ready to get stronger?',
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'YOUR FITNESS JOURNEY STARTS HERE',
                style: GoogleFonts.inter(
                  color: AppColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 28),

              // TRAIN AND EAT SECTION
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Expanded(
                    child: _DashboardCard(
                      icon: Icons.fitness_center,
                      title: 'TRAIN',
                      subtitle: 'Today\'s workout',
                      description: data?.activeWorkout != null
                          ? data!.activeWorkout!['session_name'] as String
                          : data?.completedWorkoutToday != null
                              ? data!.completedWorkoutToday!['session_name'] as String
                              : data?.suggestedWorkoutDay == null
                                  ? 'No workout scheduled'
                                  : (data!.suggestedWorkoutDay!['is_rest_day'] as int? ?? 0) == 1
                                      ? 'Rest Day'
                                      : data.suggestedWorkoutDay!['label'] as String,
                      detail: data?.activeWorkout != null
                          ? ((data!.activeWorkout!['paused_at'] != null)
                              ? 'Workout paused'
                              : 'Workout in progress')
                          : data?.completedWorkoutToday != null
                              ? ''
                              : data?.suggestedWorkoutDay == null
                                  ? 'Create or activate a plan'
                                  : (data!.suggestedWorkoutDay!['is_rest_day'] as int? ?? 0) == 1
                                      ? 'Recovery day'
                                      : '${data.suggestedExerciseCount} Exercises',
                      accentColor: AppColors.red,
                      buttonText: data?.activeWorkout != null
                          ? ((data!.activeWorkout!['paused_at'] != null)
                              ? 'RESUME WORKOUT'
                              : 'IN PROGRESS')
                          : data?.completedWorkoutToday != null
                              ? 'WORKOUT COMPLETED'
                              : 'START WORKOUT',
                      onTap: () async {
                              final active = data?.activeWorkout;
                              if (active != null) {
                                await Navigator.of(dashboardContext).push(MaterialPageRoute<void>(
                                  builder: (_) => WorkoutSessionScreen(
                                    workoutId: active['id'] as int,
                                    title: active['session_name'] as String,
                                  ),
                                ));
                                if (dashboardContext.mounted) refreshDashboard();
                                return;
                              }
                              if (data?.completedWorkoutToday != null) {
                                final sessionName = data!.completedWorkoutToday!['session_name'] as String;
                                final startAnother = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    backgroundColor: AppColors.card,
                                    title: Text(
                                      'Workout completed',
                                      style: GoogleFonts.inter(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    content: Text(
                                      '$sessionName is complete. Would you like to start another session?',
                                      style: GoogleFonts.inter(color: AppColors.grey),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('NOT NOW'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        child: const Text('GO TO WORKOUT'),
                                      ),
                                    ],
                                  ),
                                );
                                if (startAnother == true && dashboardContext.mounted) {
                                  await Navigator.of(dashboardContext).push(MaterialPageRoute<void>(
                                    builder: (_) => const WorkoutLauncherScreen(),
                                  ));
                                  if (dashboardContext.mounted) refreshDashboard();
                                }
                                return;
                              }
                              await Navigator.of(dashboardContext).push(MaterialPageRoute<void>(
                                builder: (_) => const WorkoutLauncherScreen(),
                              ));
                              if (dashboardContext.mounted) refreshDashboard();
                            },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _DashboardCard(
                      icon: Icons.restaurant,
                      title: 'EAT',
                      subtitle: 'Daily nutrition',
                      description: '${kcal.round()} kcal',
                      detail: 'of ${calorieTarget.round()} kcal',
                      accentColor: AppColors.green,
                      buttonText: 'LOG MEAL',
                      onTap: widget.onOpenEat,
                    ),
                  ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // WORKOUT ANALYSIS
              InkWell(
                onTap: () => Navigator.of(dashboardContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkoutAnalysisScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: AppColors.red,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WORKOUT ANALYSIS',
                              style: GoogleFonts.inter(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Training volume, load and progressive overload',
                              style: GoogleFonts.inter(
                                color: AppColors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.red,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // WEIGHT AND PROTEIN CARDS
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Expanded(
                    child: InkWell(
                      onTap: _showWeightLogger,
                      borderRadius: BorderRadius.circular(12),
                      child: _MetricCard(
                        title: 'WEIGHT',
                        value: currentWeight?.toStringAsFixed(1) ?? '—',
                        unit: currentWeight == null ? '' : 'kg',
                        subtitle: currentWeight == null ? 'Tap to log weight' : 'Tap to edit entry',
                        icon: Icons.monitor_weight_outlined,
                        accentColor: AppColors.red,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _MetricCard(
                      title: 'PROTEIN',
                      value: protein.round().toString(),
                      unit: 'g',
                      subtitle: 'of ${proteinTarget.round()} g daily goal',
                      icon: Icons.egg_alt_outlined,
                      accentColor: AppColors.green,
                    ),
                  ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // LOG ACTIVITY CARD
              InkWell(
                onTap: widget.onOpenActivity,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    // Activity icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.directions_walk,
                        color: AppColors.green,
                        size: 25,
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Activity details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOG ACTIVITY',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'Track your daily movement',
                            style: GoogleFonts.inter(
                              color: AppColors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action icon
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.green,
                      size: 16,
                    ),
                  ],
                ),
              ),
              ),

              const SizedBox(height: 24),

              // PROGRESS ANALYTICS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PROGRESS ANALYTICS',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),

                        Icon(
                          Icons.show_chart,
                          color: AppColors.red,
                          size: 21,
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Your weight journey',
                      style: GoogleFonts.inter(
                        color: AppColors.grey,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Weight chart
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: data == null || data.weights.isEmpty
                          ? Center(
                              child: Text(
                                'Log your weight to see your progress here',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11),
                              ),
                            )
                          : CustomPaint(
                              painter: _WeightChartPainter(
                                values: data.weights.reversed
                                    .map((row) => (row['weight_value'] as num).toDouble())
                                    .toList(),
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    Divider(color: AppColors.border),

                    const SizedBox(height: 14),

                    // Progress metrics
                    Row(
                      children: [
                        Expanded(
                          child: _ProgressMetric(
                            title: 'CURRENT',
                            value: currentWeight == null ? '—' : '${currentWeight.toStringAsFixed(1)} kg',
                            color: AppColors.white,
                          ),
                        ),

                        Expanded(
                          child: _ProgressMetric(
                            title: 'WEEKLY CHANGE',
                            value: data == null || data.weights.length < 2
                                ? '—'
                                : '${(((data.weights.first['weight_value'] as num).toDouble()) - ((data.weights.last['weight_value'] as num).toDouble())).toStringAsFixed(1)} kg',
                            color: AppColors.green,
                          ),
                        ),

                        Expanded(
                          child: _ProgressMetric(
                            title: 'AVERAGE',
                            value: data == null || data.weights.isEmpty
                                ? '—'
                                : '${(data.weights.map((row) => (row['weight_value'] as num).toDouble()).reduce((a, b) => a + b) / data.weights.length).toStringAsFixed(1)} kg',
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              if (data != null) _buildWeeklySummaryCard(data),
            ],
          ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildWeeklySummaryCard(_DashboardData data) {
    final weekly = data.weekly;
    final trackedDays = weekly['tracked_days'] as int;
    final weightDays = weekly['weight_days'] as int;
    final workouts = weekly['workouts'] as int;
    final averageCalories = weekly['average_calories'] as double;
    final averageWeight = weekly['average_weight'] as double;
    final averageProtein = weekly['average_protein'] as double;
    final factor = data.weightUnit == 'lb' ? 2.20462 : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'THIS WEEK',
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WeeklyProgressScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.green,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'VIEW DETAILS  →',
                  style: GoogleFonts.inter(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WeeklyMiniMetric(
                  label: 'AVG. CALORIES',
                  value: trackedDays == 0 ? '—' : '${averageCalories.round()}',
                  unit: 'kcal/day',
                  note: '$trackedDays/7 days logged',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeeklyMiniMetric(
                  label: 'AVG. WEIGHT',
                  value: weightDays == 0
                      ? '—'
                      : (averageWeight * factor).toStringAsFixed(1),
                  unit: data.weightUnit,
                  note: '$weightDays weigh-ins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WeeklyMiniMetric(
                  label: 'AVG. PROTEIN',
                  value: trackedDays == 0 ? '—' : '${averageProtein.round()}',
                  unit: 'g/day',
                  note: 'On logged days',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeeklyMiniMetric(
                  label: 'WORKOUTS',
                  value: '$workouts',
                  unit: 'completed',
                  note: 'This week',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  final Map<String, double> nutrition;
  final List<Map<String, Object?>> weights;
  final Map<String, Object?>? latestWeight;
  final Map<String, Object?>? targets;
  final Map<String, Object?> weekly;
  final String weightUnit;
  final String displayName;
  final Map<String, Object?>? suggestedWorkoutDay;
  final int suggestedExerciseCount;
  final Map<String, Object?>? activeWorkout;
  final Map<String, Object?>? completedWorkoutToday;

  const _DashboardData({
    required this.nutrition,
    required this.weights,
    required this.latestWeight,
    required this.targets,
    required this.weekly,
    required this.weightUnit,
    required this.displayName,
    required this.suggestedWorkoutDay,
    required this.suggestedExerciseCount,
    required this.activeWorkout,
    required this.completedWorkoutToday,
  });
}

class _WeeklyMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String note;

  const _WeeklyMiniMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.grey,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(color: AppColors.grey, fontSize: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// DASHBOARD CARD
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String detail;
  final Color accentColor;
  final String buttonText;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.detail,
    required this.accentColor,
    required this.buttonText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 23,
          ),

          const SizedBox(height: 15),

          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppColors.grey,
              fontSize: 10,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            description,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: GoogleFonts.inter(
                color: AppColors.grey,
                fontSize: 11,
              ),
            ),
          ],

          const Spacer(),

          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                buttonText,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// METRIC CARD
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppColors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),

              Icon(
                icon,
                color: accentColor,
                size: 19,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(width: 4),

              Text(
                unit,
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppColors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// PROGRESS METRIC
class _ProgressMetric extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _ProgressMetric({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppColors.grey,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// WEIGHT CHART
class _WeightChartPainter extends CustomPainter {
  final List<double> values;

  const _WeightChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.7;

    final linePaint = Paint()
      ..color = AppColors.red
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;
    final points = List<Offset>.generate(values.length, (index) {
      final x = values.length == 1 ? size.width / 2 : index * size.width / (values.length - 1);
      final y = size.height - 12 - ((values[index] - minValue) / range) * (size.height - 24);
      return Offset(x, y);
    });

    // Horizontal grid lines
    for (int i = 0; i < 4; i++) {
      final y = i * size.height / 3;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw chart line
    final path = Path()
      ..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (points.length > 1) canvas.drawPath(path, linePaint);

    // Draw data points
    final dotPaint = Paint()
      ..color = AppColors.red
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
