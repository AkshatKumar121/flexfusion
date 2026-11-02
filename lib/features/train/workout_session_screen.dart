import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'workout_plan_screen.dart';

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
    _suggested = AppDatabase.instance.getSuggestedWorkoutDay();
    _active = AppDatabase.instance.getInProgressWorkout();
  }
  void _finishAndCloseLauncher() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }
  Future<void> _start({Map<String, Object?>? day, String? name}) async {
    final title = name ?? day?['label'] as String? ?? 'Workout';
    final id = await AppDatabase.instance.startWorkoutSession(
      planId: day?['plan_id'] as int?, planDayId: day?['id'] as int?, sessionName: title);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => WorkoutSessionScreen(workoutId: id, title: title, onFinished: _finishAndCloseLauncher)));
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
    body: ListView(padding: const EdgeInsets.all(18), children: [
      FutureBuilder<Map<String, Object?>?>(future: _active, builder: (context, s) {
        final row = s.data;
        if (row == null) return const SizedBox.shrink();
        return _tile('Workout in progress', row['session_name'] as String, 'RESUME', () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => WorkoutSessionScreen(workoutId: row['id'] as int, title: row['session_name'] as String, onFinished: _finishAndCloseLauncher))));
      }),
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
        final rest = (day['is_rest_day'] as int? ?? 0) == 1;
        return _tile('Your planned session', '${day['label']} • ${day['plan_name']}', rest ? 'LOG REST DAY' : 'START', rest ? () => _logRestDay(day) : () => _start(day: day));
      }),
      _tile('Unscheduled workout', 'Start a session outside your plan.', 'START FREE WORKOUT', _startFree),
    ]),
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

class WorkoutSessionScreen extends StatefulWidget {
  final int workoutId;
  final String title;
  final VoidCallback? onFinished;
  const WorkoutSessionScreen({super.key, required this.workoutId, required this.title, this.onFinished});
  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}
class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late Future<List<Map<String, Object?>>> _sets;
  final Map<int, TextEditingController> _reps = {};
  final Map<int, TextEditingController> _weights = {};
  Timer? _timer;
  int _rest = 0;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _sets = AppDatabase.instance.getWorkoutSessionSets(widget.workoutId); }
  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _reps.values) { c.dispose(); }
    for (final c in _weights.values) { c.dispose(); }
    super.dispose();
  }
  TextEditingController _controller(Map<int, TextEditingController> map, int id, String value) => map.putIfAbsent(id, () => TextEditingController(text: value));
  Future<void> _save(Map<String, Object?> row, bool done) async {
    final id = row['id'] as int;
    await AppDatabase.instance.updateWorkoutSet(id: id,
      reps: int.tryParse(_controller(_reps, id, '${row['actual_reps'] ?? 0}').text) ?? 0,
      weight: double.tryParse(_controller(_weights, id, row['actual_weight']?.toString() ?? '').text),
      completed: done);
    if (done) _startRest(row['rest_seconds'] as int? ?? 90);
    if (mounted) setState(_reload);
  }
  void _startRest(int seconds) {
    _timer?.cancel(); setState(() => _rest = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_rest <= 1) { t.cancel(); if (mounted) setState(() => _rest = 0); }
      else if (mounted) {
        setState(() => _rest--);
      }
    });
  }
  Future<void> _addExercise() async {
    final library = await AppDatabase.instance.getExercises();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Map<String, Object?>>(context: context, backgroundColor: AppColors.card,
      builder: (context) => SafeArea(child: ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('Add exercise')),
        for (final e in library) ListTile(title: Text(e['name'] as String), subtitle: Text('${e['muscle_group'] ?? ''} • ${e['equipment'] ?? ''}'), onTap: () => Navigator.pop(context, e)),
      ])));
    if (chosen == null) return;
    await AppDatabase.instance.addExerciseToWorkout(workoutId: widget.workoutId, exerciseId: chosen['id'] as int, exerciseName: chosen['name'] as String, setCount: 3);
    if (mounted) setState(_reload);
  }
  Future<void> _finish() async {
    var rows = await AppDatabase.instance.getWorkoutSessionSets(widget.workoutId);
    for (final row in rows) {
      final id = row['id'] as int;
      await AppDatabase.instance.updateWorkoutSet(
        id: id,
        reps: int.tryParse(_controller(_reps, id, '${row['actual_reps'] ?? 0}').text) ?? 0,
        weight: double.tryParse(_controller(_weights, id, row['actual_weight']?.toString() ?? '').text),
        completed: (row['completed'] as int? ?? 0) == 1,
      );
    }
    rows = await AppDatabase.instance.getWorkoutSessionSets(widget.workoutId);
    final done = rows.where((r) => (r['completed'] as int? ?? 0) == 1).length;
    if (!mounted) return;
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.card, title: const Text('Finish workout?'),
      content: Text('You completed $done of ${rows.length} sets. Save this session to history?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP TRAINING')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('FINISH'))]));
    if (confirm == true) {
      await AppDatabase.instance.finishWorkoutSession(widget.workoutId);
      if (mounted) {
        // Return to the screen that opened the workout launcher. The launcher
        // closes itself as well, so the user lands directly on TRAIN/HOME.
        if (widget.onFinished != null) {
          widget.onFinished!();
        } else {
          Navigator.pop(context);
        }
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.white, title: Text(widget.title), actions: [TextButton(onPressed: _finish, child: const Text('FINISH'))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addExercise, label: const Text('ADD EXERCISE'), icon: const Icon(Icons.add)),
    body: FutureBuilder<List<Map<String, Object?>>>(future: _sets, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final groups = <String, List<Map<String, Object?>>>{};
      for (final row in snap.data!) { groups.putIfAbsent(row['exercise_name_snapshot'] as String, () => []).add(row); }
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (_rest > 0) Card(color: AppColors.card, child: ListTile(leading: const Icon(Icons.timer, color: AppColors.green), title: const Text('REST TIMER'), trailing: Text('${(_rest ~/ 60).toString().padLeft(2, '0')}:${(_rest % 60).toString().padLeft(2, '0')}'), onTap: () { _timer?.cancel(); setState(() => _rest = 0); })),
        if (groups.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Add exercises to begin.')),
        for (final group in groups.entries) Card(color: AppColors.card, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(group.key, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w800)),
          for (final row in group.value) Builder(builder: (context) {
            final id = row['id'] as int;
            return Row(children: [
              SizedBox(width: 42, child: Text('SET ${row['set_order']}', style: const TextStyle(color: AppColors.grey, fontSize: 10))),
              Expanded(child: TextField(controller: _controller(_reps, id, '${row['actual_reps'] ?? 0}'), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _controller(_weights, id, row['actual_weight']?.toString() ?? ''), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Weight kg', isDense: true))),
              Checkbox(value: (row['completed'] as int? ?? 0) == 1, onChanged: (v) => _save(row, v ?? false), activeColor: AppColors.green),
            ]);
          }),
        ]))),
      ]);
    }),
  );
}

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});
  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}
class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  late Future<List<Map<String, Object?>>> _history;
  @override
  void initState() { super.initState(); _history = AppDatabase.instance.getWorkoutHistory(); }
  Future<void> _deleteWorkout(Map<String, Object?> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete workout?'),
        content: Text(
          'Delete "${row['session_name']}" from workout history? This will permanently remove its sets and recorded details.',
          style: const TextStyle(color: AppColors.grey),
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
    await AppDatabase.instance.deleteWorkoutSession(row['id'] as int);
    if (!mounted) return;
    setState(() {
      _history = AppDatabase.instance.getWorkoutHistory();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout removed from history.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.white, title: const Text('WORKOUT HISTORY')),
    body: FutureBuilder<List<Map<String, Object?>>>(future: _history, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data!;
      if (rows.isEmpty) return const Center(child: Text('Completed workouts will appear here.'));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: rows.length, itemBuilder: (context, i) {
        final row = rows[i];
        final date = DateTime.tryParse(row['completed_at'] as String? ?? '');
        final dateLabel = date == null ? '' : '${date.day}/${date.month}/${date.year}';
        return Card(color: AppColors.card, child: ListTile(
          title: Text(row['session_name'] as String, style: const TextStyle(color: AppColors.white)),
          subtitle: Text('$dateLabel • ${row['completed_sets']}/${row['total_sets']} sets completed', style: const TextStyle(color: AppColors.grey, fontSize: 11)),
          trailing: PopupMenuButton<String>(
            iconColor: AppColors.grey,
            onSelected: (value) {
              if (value == 'delete') _deleteWorkout(row);
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Remove from history'),
                ]),
              ),
            ],
          ),
          onTap: () async {
            final sets = await AppDatabase.instance.getWorkoutSessionSets(row['id'] as int);
            if (!context.mounted) return;
            await showModalBottomSheet<void>(context: context, backgroundColor: AppColors.card, builder: (context) => SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(row['session_name'] as String, style: const TextStyle(color: AppColors.white, fontSize: 18)),
              for (final s in sets) ListTile(title: Text('${s['exercise_name_snapshot']} • Set ${s['set_order']}', style: const TextStyle(color: AppColors.white, fontSize: 12)), subtitle: Text('${s['actual_weight'] ?? '—'} kg × ${s['actual_reps'] ?? '—'} reps', style: const TextStyle(color: AppColors.grey, fontSize: 10)), trailing: Icon((s['completed'] as int? ?? 0) == 1 ? Icons.check_circle : Icons.radio_button_unchecked, color: AppColors.green)),
            ])));
          },
        ));
      });
    }),
  );
}


class WorkoutSummaryScreen extends StatelessWidget {
  final int workoutId;
  const WorkoutSummaryScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.white,
      automaticallyImplyLeading: false,
      title: const Text('WORKOUT COMPLETE'),
    ),
    body: FutureBuilder<Map<String, Object?>>(
      future: AppDatabase.instance.getWorkoutSessionSummary(workoutId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final started = DateTime.tryParse(data['started_at'] as String? ?? '');
        final ended = DateTime.tryParse(data['completed_at'] as String? ?? '');
        final duration = started == null || ended == null ? 0 : ended.difference(started).inMinutes;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.green, size: 64),
                const SizedBox(height: 16),
                Text(data['session_name'] as String? ?? 'Workout', style: GoogleFonts.inter(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Great work. Your session is saved in Workout History.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12)),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: _summaryMetric('SETS', '${data['completed_sets'] ?? 0}/${data['total_sets'] ?? 0}')),
                  Expanded(child: _summaryMetric('DURATION', '$duration min')),
                  Expanded(child: _summaryMetric('VOLUME', '${(data['volume'] as num? ?? 0).round()} kg')),
                ]),
                const SizedBox(height: 28),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('DONE'),
                )),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _summaryMetric(String label, String value) => Column(children: [
    Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700)),
    const SizedBox(height: 7),
    Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
  ]);
}
