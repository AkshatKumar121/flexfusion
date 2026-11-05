import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

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
    try {
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
    } catch (error) {
      debugPrint('Could not update workout pause state: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update workout timer. Please try again.')),
        );
      }
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
    try {
      await AppDatabase.instance.updateWorkoutSet(
        id: id,
        reps: reps,
        weight: weight,
        completed: done,
      );
      if (!mounted) return;
      if (done) _startRest(row['rest_seconds'] as int? ?? 90);
      setState(_reload);
    } catch (error) {
      debugPrint('Could not save workout set: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this set. Please try again.')),
        );
      }
    }
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

    try {
      var rows = await AppDatabase.instance.getWorkoutSessionSets(widget.workoutId);
      if (!mounted) {
        _finishing = false;
        return;
      }

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

        if (reps == null ||
            reps <= 0 ||
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
      if (!mounted) {
        _finishing = false;
        return;
      }

      final done = rows.where((r) => (r['completed'] as int? ?? 0) == 1).length;
      final sessionDuration = _isPaused || _startedAt == null
          ? _elapsed
          : DateTime.now().difference(_startedAt!) -
              Duration(seconds: _pausedSeconds);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Finish workout?'),
          content: Text(
            'You completed $done of ${rows.length} sets.\n\n'
            'Time spent: ${_formatDuration(sessionDuration)}\n\n'
            'Save this session to history?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('KEEP TRAINING'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('FINISH'),
            ),
          ],
        ),
      );

      if (!mounted) {
        _finishing = false;
        return;
      }
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
    } catch (error) {
      debugPrint('Could not finish workout: $error');
      _finishing = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish workout. Your session is still saved; please try again.',
            ),
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.white, title: Text(widget.title), actions: [TextButton(onPressed: _finish, child: const Text('FINISH'))]),
    floatingActionButton: FloatingActionButton.small(
      onPressed: _addExercise,
      tooltip: 'Add exercise',
      backgroundColor: AppColors.red,
      foregroundColor: AppColors.white,
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(future: _sets, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final groups = <String, List<Map<String, Object?>>>{};
      for (final row in snap.data!) { groups.putIfAbsent(row['exercise_name_snapshot'] as String, () => []).add(row); }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
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
        if (_restEndsAt != null) Card(color: AppColors.card, child: ListTile(leading: const Icon(Icons.timer, color: AppColors.green), title: Text(_restComplete ? 'REST COMPLETE' : 'REST TIMER'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (_restComplete) const Icon(Icons.check_circle, color: AppColors.green) else Text('${(_rest ~/ 60).toString().padLeft(2, '0')}:${(_rest % 60).toString().padLeft(2, '0')}'), const SizedBox(width: 8), IconButton(tooltip: 'Dismiss rest timer', onPressed: _clearRestTimer, icon: const Icon(Icons.close, color: AppColors.grey, size: 20))]))),
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
