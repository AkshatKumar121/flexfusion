import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            final rest = (day['is_rest_day'] as int? ?? 0) == 1;
            return _tile('Your planned session', '${day['label']} • ${day['plan_name']}', rest ? 'LOG REST DAY' : 'START', rest ? () => _logRestDay(day) : () => _start(day: day));
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

class WorkoutSessionScreen extends StatefulWidget {
  final int workoutId;
  final String title;
  final VoidCallback? onFinished;
  const WorkoutSessionScreen({super.key, required this.workoutId, required this.title, this.onFinished});
  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}
class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> with WidgetsBindingObserver {
  static const MethodChannel _restChannel = MethodChannel('com.flexfusion/rest_timer');
  late Future<List<Map<String, Object?>>> _sets;
  final Map<int, TextEditingController> _reps = {};
  final Map<int, TextEditingController> _weights = {};
  Timer? _timer;
  Timer? _workoutTimer;
  DateTime? _startedAt;
  int _pausedSeconds = 0;
  bool _isPaused = false;
  Duration _elapsed = Duration.zero;
  int _rest = 0;
  DateTime? _restEndsAt;
  bool _restComplete = false;
  bool _finishing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _loadWorkoutStartTime();
    _restoreRestTimer();
  }

  Future<void> _loadWorkoutStartTime() async {
    final summary = await AppDatabase.instance.getWorkoutSessionSummary(widget.workoutId);
    final startedAt = DateTime.tryParse(summary['started_at'] as String? ?? '');
    if (!mounted || startedAt == null) return;
    final pausedAt = DateTime.tryParse(summary['paused_at'] as String? ?? '');
    final pausedSeconds = summary['paused_seconds'] as int? ?? 0;
    final isPaused = pausedAt != null;
    final effectiveEnd = isPaused ? pausedAt : DateTime.now();
    final elapsed = effectiveEnd.difference(startedAt) - Duration(seconds: pausedSeconds);
    setState(() {
      _startedAt = startedAt;
      _pausedSeconds = pausedSeconds;
      _isPaused = isPaused;
      _elapsed = elapsed.isNegative ? Duration.zero : elapsed;
    });
    _workoutTimer?.cancel();
    if (!isPaused) {
      _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final current = DateTime.now().difference(startedAt) - Duration(seconds: _pausedSeconds);
        setState(() => _elapsed = current.isNegative ? Duration.zero : current);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWorkoutStartTime();
      _restoreRestTimer();
    }
  }

  Future<void> _restoreRestTimer() async {
    final end = await AppDatabase.instance.getWorkoutRestEnd(widget.workoutId);
    if (!mounted) return;
    _timer?.cancel();
    if (end == null) {
      setState(() { _restEndsAt = null; _rest = 0; _restComplete = false; });
      return;
    }
    final remaining = end.difference(DateTime.now()).inSeconds;
    setState(() {
      _restEndsAt = end;
      _rest = remaining > 0 ? remaining : 0;
      _restComplete = remaining <= 0;
    });
    if (remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshRestCountdown());
    }
  }

  void _refreshRestCountdown() {
    final end = _restEndsAt;
    if (end == null || !mounted) return;
    final remaining = end.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _timer?.cancel();
      setState(() { _rest = 0; _restComplete = true; });
    } else {
      setState(() => _rest = remaining);
    }
  }

  Future<void> _toggleWorkoutPause() async {
    if (_isPaused) {
      await AppDatabase.instance.resumeWorkoutSession(widget.workoutId);
      if (!mounted) return;
      await _loadWorkoutStartTime();
    } else {
      await AppDatabase.instance.pauseWorkoutSession(widget.workoutId);
      if (!mounted) return;
      _workoutTimer?.cancel();
      setState(() {
        _isPaused = true;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  void _reload() { _sets = AppDatabase.instance.getWorkoutSessionSets(widget.workoutId); }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _workoutTimer?.cancel();
    for (final c in _reps.values) { c.dispose(); }
    for (final c in _weights.values) { c.dispose(); }
    super.dispose();
  }
  TextEditingController _controller(Map<int, TextEditingController> map, int id, String value) => map.putIfAbsent(id, () => TextEditingController(text: value));
  Future<void> _save(Map<String, Object?> row, bool done) async {
    final id = row['id'] as int;
    final reps = int.tryParse(
      _controller(_reps, id, '${row['actual_reps'] ?? 0}').text.trim(),
    );
    final weightText = _controller(
      _weights,
      id,
      row['actual_weight']?.toString() ?? '',
    ).text.trim();
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);
    if (reps == null || reps <= 0 ||
        (weightText.isNotEmpty && (weight == null || weight < 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid reps and a non-negative weight.')),
      );
      return;
    }
    await AppDatabase.instance.updateWorkoutSet(
      id: id,
      reps: reps,
      weight: weight,
      completed: done,
    );
    if (!mounted) return;
    if (done) _startRest(row['rest_seconds'] as int? ?? 90);
    setState(_reload);
  }
  Future<void> _startRest(int seconds) async {
    _timer?.cancel();
    if (seconds <= 0) return;
    final end = DateTime.now().add(Duration(seconds: seconds));
    await AppDatabase.instance.saveWorkoutRestEnd(widget.workoutId, end);
    if (!mounted) return;
    setState(() { _restEndsAt = end; _rest = seconds; _restComplete = false; });
    try {
      final granted = await _restChannel.invokeMethod<bool>('requestPermission') ?? false;
      if (granted) {
        await _restChannel.invokeMethod<bool>('scheduleRest', {
          'endAt': end.millisecondsSinceEpoch.toDouble(),
        });
      }
    } on PlatformException {
      // The persisted countdown still works when notifications are unavailable.
    } on MissingPluginException {
      // Non-iOS platforms retain the in-app timer without native notifications.
    }
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshRestCountdown());
  }

  Future<void> _clearRestTimer() async {
    _timer?.cancel();
    await AppDatabase.instance.saveWorkoutRestEnd(widget.workoutId, null);
    try {
      await _restChannel.invokeMethod<bool>('cancelRest');
    } on PlatformException {
      // Ignore notification cleanup failures; clear the in-app timer regardless.
    } on MissingPluginException {
      // Native notifications are iOS-only.
    }
    if (mounted) setState(() { _restEndsAt = null; _rest = 0; _restComplete = false; });
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
    if (_finishing) return;
    _finishing = true;
    var rows = await AppDatabase.instance.getWorkoutSessionSets(widget.workoutId);
    if (!mounted) { _finishing = false; return; }
    final pending = <Map<String, Object?>>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final reps = int.tryParse(
        _controller(_reps, id, '${row['actual_reps'] ?? 0}').text.trim(),
      );
      final weightText = _controller(
        _weights,
        id,
        row['actual_weight']?.toString() ?? '',
      ).text.trim();
      final weight = weightText.isEmpty ? null : double.tryParse(weightText);
      if (reps == null || reps <= 0 ||
          (weightText.isNotEmpty && (weight == null || weight < 0))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fix invalid reps or weight before finishing.')),
        );
        _finishing = false;
        return;
      }
      pending.add({
        'id': id,
        'reps': reps,
        'weight': weight,
        'completed': (row['completed'] as int? ?? 0) == 1,
      });
    }
    for (final set in pending) {
      await AppDatabase.instance.updateWorkoutSet(
        id: set['id'] as int,
        reps: set['reps'] as int,
        weight: set['weight'] as double?,
        completed: set['completed'] as bool,
      );
    }
    rows = await AppDatabase.instance.getWorkoutSessionSets(widget.workoutId);
    final done = rows.where((r) => (r['completed'] as int? ?? 0) == 1).length;
    if (!mounted) return;
    final sessionDuration = _isPaused || _startedAt == null
        ? _elapsed
        : DateTime.now().difference(_startedAt!) - Duration(seconds: _pausedSeconds);
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.card, title: const Text('Finish workout?'),
      content: Text('You completed $done of ${rows.length} sets.\n\nTime spent: ${_formatDuration(sessionDuration)}\n\nSave this session to history?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP TRAINING')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('FINISH'))]));
    if (confirm == true) {
      await _clearRestTimer();
      await AppDatabase.instance.finishWorkoutSession(widget.workoutId);
      _workoutTimer?.cancel();
      if (mounted) {
        // Return to the screen that opened the workout launcher. The launcher
        // closes itself as well, so the user lands directly on TRAIN/HOME.
        if (widget.onFinished != null) {
          widget.onFinished!();
        } else {
          Navigator.pop(context);
        }
      }
    } else {
      _finishing = false;
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
        Card(
          color: AppColors.card,
          child: ListTile(
            leading: const Icon(Icons.timer_outlined, color: AppColors.green, size: 25),
            title: Text('WORKOUT DURATION', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            subtitle: Text(_formatDuration(_elapsed), style: GoogleFonts.inter(color: AppColors.white, fontSize: 25, fontWeight: FontWeight.w800, fontFeatures: const [])),
            trailing: TextButton.icon(
              onPressed: _toggleWorkoutPause,
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 18),
              label: Text(_isPaused ? 'RESUME' : 'PAUSE'),
              style: TextButton.styleFrom(foregroundColor: AppColors.green),
            ),
          ),
        ),
        if (_restEndsAt != null) Card(color: AppColors.card, child: ListTile(leading: const Icon(Icons.timer, color: AppColors.green), title: Text(_restComplete ? 'REST COMPLETE' : 'REST TIMER'), trailing: _restComplete ? const Icon(Icons.check_circle, color: AppColors.green) : Text('${(_rest ~/ 60).toString().padLeft(2, '0')}:${(_rest % 60).toString().padLeft(2, '0')}'), onTap: _clearRestTimer)),
        if (groups.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Add exercises to begin.')),
        for (final group in groups.entries) Card(color: AppColors.card, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(group.key, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w800)),
          for (final row in group.value) Builder(builder: (context) {
            final id = row['id'] as int;
            return Row(children: [
              SizedBox(width: 42, child: Text('SET ${row['set_order']}', style: const TextStyle(color: AppColors.grey, fontSize: 10))),
              Expanded(child: TextField(controller: _controller(_reps, id, '${row['actual_reps'] ?? 0}'), keyboardType: TextInputType.number, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus(), onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(), decoration: const InputDecoration(labelText: 'Reps', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _controller(_weights, id, row['actual_weight']?.toString() ?? ''), keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done, onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(), onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(), decoration: const InputDecoration(labelText: 'Weight kg', isDense: true))),
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
        final pausedSeconds = data['paused_seconds'] as int? ?? 0;
        final rawDuration = started == null || ended == null
            ? Duration.zero
            : ended.difference(started) - Duration(seconds: pausedSeconds);
        final duration = rawDuration.isNegative ? 0 : rawDuration.inMinutes;
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
