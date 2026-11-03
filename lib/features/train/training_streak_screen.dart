import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class TrainingStreakScreen extends StatefulWidget {
  const TrainingStreakScreen({super.key});

  @override
  State<TrainingStreakScreen> createState() => _TrainingStreakScreenState();
}

class _TrainingStreakScreenState extends State<TrainingStreakScreen> {
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
          final activityDays = (data['activity_days'] as List).cast<String>().toSet();
          final healthSteps = (data['health_steps'] as Map).cast<String, int>();
          final activeDays = {...workoutDays, ...activityDays};
          final todayKey = _key(_today);
          final steps = healthSteps[todayKey] ?? 0;
          final weekStart = _today.subtract(Duration(days: _today.weekday - 1));
          final week = List.generate(7, (i) => weekStart.add(Duration(days: i)));
          final weekWorkoutCount = week.where((d) => workoutDays.contains(_key(d))).length;
          final weekActivityCount = week.where((d) => activityDays.contains(_key(d))).length;
          var streak = 0;
          var cursor = activeDays.contains(todayKey) ? _today : _today.subtract(const Duration(days: 1));
          while (activeDays.contains(_key(cursor))) {
            streak++;
            cursor = cursor.subtract(const Duration(days: 1));
          }
          final progress = (steps / 10000).clamp(0.0, 1.0);

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
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Color(0xFFFF3D70), size: 66),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('STREAK'),
                              const SizedBox(height: 5),
                              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('$streak', style: GoogleFonts.inter(color: AppColors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1)),
                                const SizedBox(width: 9),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text('DAYS', style: GoogleFonts.inter(color: AppColors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        const Icon(Icons.directions_walk_outlined, color: Color(0xFF999999), size: 48),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(height: 1, color: const Color(0xFF303030)),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (i) {
                        final day = week[i];
                        final key = _key(day);
                        final done = activeDays.contains(key);
                        final isToday = key == todayKey;
                        return Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done ? AppColors.green : (isToday ? Colors.transparent : const Color(0xFF292929)),
                                  border: isToday && !done ? Border.all(color: AppColors.green, width: 2.5) : null,
                                ),
                                child: done
                                    ? const Icon(Icons.check, color: Colors.black, size: 34)
                                    : (isToday ? const Icon(Icons.circle, color: AppColors.green, size: 8) : null),
                              ),
                              const SizedBox(height: 8),
                              Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                                style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 30),
                    _label('STEPS'),
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(steps.toString(), style: GoogleFonts.inter(color: AppColors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('/10,000', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 20)),
                      ),
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
                    _label('THIS WEEK'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _summary('WORKOUT DAYS', '$weekWorkoutCount / 7', Icons.fitness_center)),
                      const SizedBox(width: 10),
                      Expanded(child: _summary('ACTIVITY DAYS', '$weekActivityCount / 7', Icons.directions_walk)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('A day counts toward your streak when you complete a workout or log an activity. Steps are shown separately from Apple Health when available.',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11, height: 1.5)),
            ],
          );
        },
      ),
    );
  }

  Widget _label(String value) => Text(value,
    style: GoogleFonts.inter(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2));

  Widget _summary(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: const Color(0xFF292929), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: AppColors.green, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 8, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
      ])),
    ]),
  );
}
