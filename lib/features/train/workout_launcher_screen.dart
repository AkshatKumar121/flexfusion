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
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    _suggested = AppDatabase.instance.getManualStartWorkoutDay();
    _active = AppDatabase.instance.getInProgressWorkout();
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
          FutureBuilder<Map<String, Object?>?>(future: _suggested, builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final day = s.data;
            if (day == null) {
              return _tile('No active plan', 'Create a plan to see your next session.', 'CREATE PLAN', () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const WorkoutPlanScreen()));
                if (mounted) {
                  setState(_load);
                }
              });
            }
            if (day['no_days'] == true) {
              return _tile(
                'Active plan: ${day['plan_name']}',
                'Add training days to this plan before starting a planned session.',
                'MANAGE PLAN',
                () async {
                  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const WorkoutPlanScreen()));
                  if (mounted) setState(_load);
                },
              );
            }
            final rest = (day['is_rest_day'] as int? ?? 0) == 1;
            return _tile('Active plan: ${day['plan_name']}', '${day['label']}', rest ? 'LOG REST DAY' : 'START', rest ? () => _logRestDay(day) : () => _start(day: day));
          }),
          _tile('Unscheduled workout', 'Start a session outside your plan.', 'START FREE WORKOUT', _startFree),
        ]);
      },
    ),
  );
  Widget _tile(String title, String subtitle, String button, VoidCallback? onTap) => Container(
    margin: const EdgeInsets.only(bottom: 13), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.inter(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6), Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, child: Text(button))),
    ]),
  );
}
