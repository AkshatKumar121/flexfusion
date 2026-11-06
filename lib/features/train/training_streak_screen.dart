import 'package:flutter/material.dart';
import '../../app/auto_refresh_on_return.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/widgets/streak_components.dart';

class TrainingStreakScreen extends StatefulWidget {
  const TrainingStreakScreen({super.key});

  @override
  State<TrainingStreakScreen> createState() => _TrainingStreakScreenState();
}

class _TrainingStreakScreenState extends State<TrainingStreakScreen> with AutoRefreshOnReturn<TrainingStreakScreen> {
  @override
  Future<void> refreshAfterReturn() async {
    if (!mounted) return;
    final future = AppDatabase.instance.getTrainingStreakData();
    setState(() => _dataFuture = future);
    await future;
  }

  late Future<Map<String, Object?>> _dataFuture;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _dataFuture = AppDatabase.instance.getTrainingStreakData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text('YOUR STREAK', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.green));
          }
          final data = snapshot.data!;
          final workoutDays = (data['workout_days'] as List).cast<String>().toSet();
          final stepGoalDays = (data['step_goal_days'] as List).cast<String>().toSet();
          final healthSteps = (data['health_steps'] as Map).cast<String, int>();
          final manualSteps = (data['manual_steps'] as Map).cast<String, int>();
          final activeDays = {
            ...workoutDays,
            ...stepGoalDays,
          };
          final todayKey = _key(_today);
          final steps = healthSteps[todayKey] ?? manualSteps[todayKey] ?? 0;
          final stepGoal = (data['step_goal'] as num?)?.toInt() ?? 10000;
          final weekStart = _today.subtract(Duration(days: _today.weekday - 1));
          final week = List.generate(7, (i) => weekStart.add(Duration(days: i)));
          final weekWorkoutCount = week.where((d) => workoutDays.contains(_key(d))).length;
          final weekActivityCount = week.where((d) => stepGoalDays.contains(_key(d))).length;
          var streak = 0;
          var cursor = activeDays.contains(todayKey) ? _today : _today.subtract(const Duration(days: 1));
          while (activeDays.contains(_key(cursor))) {
            streak++;
            cursor = cursor.subtract(const Duration(days: 1));
          }
          final progress = (steps / stepGoal).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF484848), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreakHeroHeader(
                      streakDays: streak,
                      trailingIcon: const Icon(Icons.directions_walk_outlined, color: Color(0xFF999999), size: 48),
                    ),
                    const SizedBox(height: 24),
                    Container(height: 1, color: const Color(0xFF303030)),
                    const SizedBox(height: 22),
                    StreakWeekStrip(
                      week: week,
                      todayKey: todayKey,
                      isCompleted: (key) => activeDays.contains(key),
                      markIncompleteToday: true,
                    ),
                    const SizedBox(height: 30),
                    StreakSectionLabel('STEPS'),
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$steps / $stepGoal', style: GoogleFonts.inter(color: AppColors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1)),
                      const Spacer(),
                      Text('${(progress * 100).round()}%', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 22, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 15,
                        backgroundColor: const Color(0xFF173126),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                      ),
                    ),
                    const SizedBox(height: 25),
                    StreakSectionLabel('THIS WEEK'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: StreakSummaryTile(title: 'WORKOUT DAYS', value: '$weekWorkoutCount / 7', icon: Icons.fitness_center, valueFontSize: 17)),
                      const SizedBox(width: 10),
                      Expanded(child: StreakSummaryTile(title: 'ACTIVITY DAYS', value: '$weekActivityCount / 7', icon: Icons.directions_walk, valueFontSize: 17)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('A day counts toward your streak when you complete a workout or reach your daily step goal of $stepGoal steps. Steps are shown separately from Apple Health when available.',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11, height: 1.5)),
            ],
          );
        },
      ),
    );
  }

}
