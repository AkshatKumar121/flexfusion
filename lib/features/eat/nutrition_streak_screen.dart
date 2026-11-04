import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/widgets/streak_components.dart';

class NutritionStreakScreen extends StatefulWidget {
  const NutritionStreakScreen({super.key});

  @override
  State<NutritionStreakScreen> createState() => _NutritionStreakScreenState();
}

class _NutritionStreakScreenState extends State<NutritionStreakScreen> {
  late Future<List<Map<String, Object?>>> _dataFuture;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _dataFuture = AppDatabase.instance.getNutritionStreakDays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text('NUTRITION STREAK', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.green));
          }
          final rows = snapshot.data!;
          final byDay = {for (final row in rows) row['day'] as String: row};
          bool achieved(String day) {
            final row = byDay[day];
            if (row == null) return false;
            final calories = (row['calories'] as num).toDouble();
            final protein = (row['protein'] as num).toDouble();
            final calorieTarget = (row['calorie_target'] as num).toDouble();
            final proteinTarget = (row['protein_target'] as num).toDouble();
            return calories >= calorieTarget - 100 &&
                calories <= calorieTarget + 100 &&
                protein >= proteinTarget;
          }

          final todayKey = _key(_today);
          final today = byDay[todayKey];
          final todayCalories = (today?['calories'] as num?)?.toDouble() ?? 0;
          final todayProtein = (today?['protein'] as num?)?.toDouble() ?? 0;
          final calorieTarget = (today?['calorie_target'] as num?)?.toDouble() ?? 2200;
          final proteinTarget = (today?['protein_target'] as num?)?.toDouble() ?? 180;
          final calorieAchieved = todayCalories >= calorieTarget - 100 && todayCalories <= calorieTarget + 100;
          final proteinAchieved = todayProtein >= proteinTarget;
          final todayAchieved = calorieAchieved && proteinAchieved;
          final weekStart = _today.subtract(Duration(days: _today.weekday - 1));
          final week = List.generate(7, (i) => weekStart.add(Duration(days: i)));
          var streak = 0;
          var cursor = todayAchieved ? _today : _today.subtract(const Duration(days: 1));
          while (achieved(_key(cursor))) {
            streak++;
            cursor = cursor.subtract(const Duration(days: 1));
          }
          final calorieProgress = (todayCalories / calorieTarget).clamp(0.0, 1.0);
          final proteinProgress = (todayProtein / proteinTarget).clamp(0.0, 1.0);
          final weekCount = week.where((day) => achieved(_key(day))).length;

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
                    Row(children: [
                      const Icon(Icons.local_fire_department, color: Color(0xFFFF3D70), size: 66),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        StreakSectionLabel('STREAK'),
                        const SizedBox(height: 5),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$streak', style: GoogleFonts.inter(color: AppColors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1)),
                          const SizedBox(width: 9),
                          Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('DAYS', style: GoogleFonts.inter(color: AppColors.white, fontSize: 19, fontWeight: FontWeight.w800))),
                        ]),
                      ])),
                      const Icon(Icons.restaurant_outlined, color: Color(0xFF999999), size: 43),
                    ]),
                    const SizedBox(height: 24),
                    Container(height: 1, color: const Color(0xFF303030)),
                    const SizedBox(height: 22),
                    StreakWeekStrip(
                      week: week,
                      todayKey: todayKey,
                      isCompleted: (key) => achieved(key),
                      markIncompleteToday: false,
                    ),
                    const SizedBox(height: 30),
                    StreakSectionLabel('TODAY\'S CALORIES'),
                    const SizedBox(height: 10),
                    _progressRow(
                      value: todayCalories,
                      target: calorieTarget,
                      suffix: 'kcal',
                      progress: calorieProgress,
                      achieved: calorieAchieved,
                      subtitle: 'Allowed range: ${(calorieTarget - 100).round()}–${(calorieTarget + 100).round()} kcal',
                    ),
                    const SizedBox(height: 24),
                    StreakSectionLabel('TODAY\'S PROTEIN'),
                    const SizedBox(height: 10),
                    _progressRow(
                      value: todayProtein,
                      target: proteinTarget,
                      suffix: 'g',
                      progress: proteinProgress,
                      achieved: proteinAchieved,
                      subtitle: 'Minimum target: ${proteinTarget.round()} g',
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: todayAchieved ? const Color(0xFF173126) : const Color(0xFF292929),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(todayAchieved ? Icons.check_circle : Icons.flag_outlined,
                          color: todayAchieved ? AppColors.green : AppColors.grey),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          todayAchieved ? 'Daily nutrition goal achieved!' : 'Meet both targets to complete today\'s streak.',
                          style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(child: StreakSummaryTile(title: 'GOAL DAYS THIS WEEK', value: '$weekCount / 7', icon: Icons.calendar_today, valueFontSize: 15)),
                      const SizedBox(width: 10),
                      Expanded(child: StreakSummaryTile(title: 'PROTEIN GOAL', value: proteinAchieved ? 'Achieved' : 'Pending', icon: Icons.fitness_center, valueFontSize: 15)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('A day counts when logged calories are within 100 kcal below or above your calorie target, and protein meets or exceeds your protein target. Historical days use the nutrition targets that were active on that date.',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11, height: 1.5)),
            ],
          );
        },
      ),
    );
  }

  Widget StreakSectionLabel(String value) => Text(value,
    style: GoogleFonts.inter(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2));

  Widget _progressRow({
    required double value,
    required double target,
    required String suffix,
    required double progress,
    required bool achieved,
    required String subtitle,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value.round().toString(), style: GoogleFonts.inter(color: AppColors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1)),
      Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(' / ${target.round()} $suffix',
        style: GoogleFonts.inter(color: AppColors.grey, fontSize: 15))),
      const Spacer(),
      Icon(achieved ? Icons.check_circle : Icons.circle_outlined,
        color: achieved ? AppColors.green : AppColors.grey, size: 21),
    ]),
    const SizedBox(height: 5),
    Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
    const SizedBox(height: 10),
    ClipRRect(borderRadius: BorderRadius.circular(30), child: LinearProgressIndicator(
      value: progress, minHeight: 13,
      backgroundColor: const Color(0xFF173126),
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
    )),
  ]);

  Widget StreakSummaryTile(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: const Color(0xFF292929), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: AppColors.green, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 8, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      ])),
    ]),
  );
}
