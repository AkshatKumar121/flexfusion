import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'workout_plan_screen.dart';
import 'workout_session_screen.dart';

class WorkoutLauncherScreen extends StatefulWidget {
  const WorkoutLauncherScreen({super.key});
  @override
  State<WorkoutLauncherScreen> createState() => _WorkoutLauncherScreenState();
}
class _WorkoutLauncherScreenState extends State<WorkoutLauncherScreen> {
  late Future<Map<String, Object?>?> _suggested;
  late Future<Map<String, Object?>?> _active;
  late Future<Map<String, Object?>?> _activePlan;
  late Future<List<Map<String, Object?>>> _planDays;
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    _suggested = AppDatabase.instance.getManualStartWorkoutDay();
    _active = AppDatabase.instance.getInProgressWorkout();
    _activePlan = AppDatabase.instance.getActiveWorkoutPlan();
    _planDays = _loadPlanDays();
  }
  Future<List<Map<String, Object?>>> _loadPlanDays() async {
    final plan = await AppDatabase.instance.getActiveWorkoutPlan();
    if (plan == null) return [];
    final days = await AppDatabase.instance.getWorkoutPlanDays(plan['id'] as int);
    return days.map((day) => <String, Object?>{
      ...day,
      'plan_id': plan['id'],
      'plan_name': plan['name'],
    }).toList();
  }

  void _finishAndCloseLauncher() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }
  Future<void> _start({Map<String, Object?>? day, String? name}) async {
    final active = await AppDatabase.instance.getInProgressWorkout();
    if (!mounted) return;
    final title = active?['session_name'] as String? ??
        name ?? day?['label'] as String? ?? 'Workout';
    final id = active?['id'] as int? ?? await AppDatabase.instance.startWorkoutSession(
      planId: day?['plan_id'] as int?,
      planDayId: day?['id'] as int?,
      sessionName: title,
    );
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => WorkoutSessionScreen(
        workoutId: id,
        title: title,
        onFinished: _finishAndCloseLauncher,
      ),
    ));
    if (mounted) setState(_load);
  }

  Future<void> _resume(Map<String, Object?> row) async {
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => WorkoutSessionScreen(
        workoutId: row['id'] as int,
        title: row['session_name'] as String,
        onFinished: _finishAndCloseLauncher,
      ),
    ));
    if (mounted) setState(_load);
  }
  Future<void> _logRestDay(Map<String, Object?> day) async {
    await AppDatabase.instance.advanceWorkoutPlanSequence(day['plan_id'] as int, day['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rest day logged. Your next plan day is ready.')));
    setState(_load);
  }
  Future<void> _startFree() async {
    final c = TextEditingController(text: 'Free Workout');
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.card, title: const Text('Unscheduled workout'),
      content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Workout name')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('START'))]));
    c.dispose();
    if (name != null && name.isNotEmpty && mounted) await _start(name: name);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.white, title: const Text('START WORKOUT')),
    body: FutureBuilder<Map<String, Object?>?>(
      future: _active,
      builder: (context, activeSnapshot) {
        if (activeSnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final activeWorkout = activeSnapshot.data;
        if (activeWorkout != null) {
          // Only allow resuming the existing session until it is finished.
          // This prevents creating another active session in parallel.
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _tile(
                'Workout in progress',
                activeWorkout['session_name'] as String,
                'RESUME',
                () => _resume(activeWorkout),
              ),
            ],
          );
        }

        return ListView(padding: const EdgeInsets.all(18), children: [
          FutureBuilder<Map<String, Object?>?>(future: _activePlan, builder: (context, planSnapshot) {
            if (planSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final activePlan = planSnapshot.data;
            if (activePlan == null) {
              return _tile(
                'No active plan found',
                'Start a freestyle workout without a plan.',
                'START FREESTYLE',
                _startFree,
              );
            }
            return FutureBuilder<List<Map<String, Object?>>>(future: _planDays, builder: (context, daysSnapshot) {
              if (daysSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return FutureBuilder<Map<String, Object?>?>(
              future: _suggested,
              builder: (context, suggestedSnapshot) {
                if (suggestedSnapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final days = daysSnapshot.data ?? [];
                final suggested = suggestedSnapshot.data;
                if (days.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _activePlanHeading(activePlan['name'] as String? ?? ''),
                      _tile('No workout days yet', 'Add training days to this plan, or start freestyle.', 'START FREESTYLE', _startFree),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _activePlanHeading(activePlan['name'] as String? ?? ''),
                    const SizedBox(height: 5),
                    Text('Choose any day in your plan. The suggested next workout is highlighted.',
                      style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                    const SizedBox(height: 14),
                    for (final day in days)
                      _tile(
                        '${day['label']}${day['id'] == suggested?['id'] ? '  •  SUGGESTED NEXT' : ''}',
                        (day['is_rest_day'] as int? ?? 0) == 1
                            ? 'Rest day • ${day['plan_name']}'
                            : 'Planned workout • ${day['plan_name']}',
                        (day['is_rest_day'] as int? ?? 0) == 1 ? 'LOG REST DAY' : 'START WORKOUT',
                        (day['is_rest_day'] as int? ?? 0) == 1
                            ? () => _logRestDay(day)
                            : () => _start(day: day),
                        highlighted: day['id'] == suggested?['id'],
                      ),
                    _tile('Unscheduled workout', 'Start a session outside your plan.', 'START FREE WORKOUT', _startFree),
                  ],
                );
              },
              );
            });
          }),
        ]);
      },
    ),
  );
  Widget _activePlanHeading(String planName) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('YOUR ACTIVE PLAN', style: GoogleFonts.inter(
        color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1,
      )),
      const SizedBox(height: 4),
      Text(
        planName,
        softWrap: true,
        style: GoogleFonts.inter(color: AppColors.green, fontSize: 20, fontWeight: FontWeight.w800),
      ),
    ],
  );

  Widget _tile(String title, String subtitle, String button, VoidCallback? onTap, {bool highlighted = false}) => Container(
    margin: const EdgeInsets.only(bottom: 13), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: highlighted ? AppColors.green : AppColors.border, width: highlighted ? 1.5 : 1)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.inter(color: highlighted ? AppColors.green : AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6), Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, child: Text(button))),
    ]),
  );
}
