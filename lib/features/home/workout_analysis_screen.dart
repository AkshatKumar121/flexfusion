import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'workout_analysis_calculator.dart';
import 'exercise_performance_screen.dart';

class WorkoutAnalysisScreen extends StatefulWidget {
  const WorkoutAnalysisScreen({super.key});

  @override
  State<WorkoutAnalysisScreen> createState() => _WorkoutAnalysisScreenState();
}

class _WorkoutAnalysisScreenState extends State<WorkoutAnalysisScreen> {
  late Future<_AnalysisData> _future;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalysisData> _load() async {
    final rows = await AppDatabase.instance.getWorkoutAnalysisRows();
    final today = _today;
    final currentStart = today.subtract(const Duration(days: 6));
    final previousStart = today.subtract(const Duration(days: 13));
    final currentRows = rows.where((r) {
      final d = DateTime.tryParse(r['started_at'] as String? ?? '');
      return WorkoutAnalysisCalculator.isInRange(d, currentStart, today.add(const Duration(days: 1)));
    }).toList();
    final previousRows = rows.where((r) {
      final d = DateTime.tryParse(r['started_at'] as String? ?? '');
      return WorkoutAnalysisCalculator.isInRange(d, previousStart, currentStart);
    }).toList();
    final todayRows = rows.where((r) {
      final d = DateTime.tryParse(r['started_at'] as String? ?? '');
      return WorkoutAnalysisCalculator.isInRange(d, today, today.add(const Duration(days: 1)));
    }).toList();
    return _AnalysisData(
      today: _buildPeriod(todayRows, today),
      currentWeek: _buildPeriod(currentRows, currentStart),
      previousWeek: _buildPeriod(previousRows, previousStart),
    );
  }

  _PeriodStats _buildPeriod(List<Map<String, Object?>> rows, DateTime start) {
    final sessions = <int, _SessionStats>{};
    final exercises = <String, _ExerciseStats>{};
    var totalSets = 0;
    var loggedSets = 0;
    var totalReps = 0;
    var volumeKg = 0.0;
    var maxWeightKg = 0.0;
    var weightedSetCount = 0;
    var weightedLoadSumKg = 0.0;
    var durationMinutes = 0;

    for (final row in rows) {
      final id = row['workout_id'] as int;
      final session = sessions.putIfAbsent(id, () => _SessionStats(
        id: id,
        name: row['session_name'] as String? ?? 'Workout',
        startedAt: DateTime.tryParse(row['started_at'] as String? ?? ''),
        completedAt: DateTime.tryParse(row['completed_at'] as String? ?? ''),
        status: row['status'] as String? ?? '',
        pausedSeconds: (row['paused_seconds'] as num?)?.toInt() ?? 0,
        pausedAt: DateTime.tryParse(row['paused_at'] as String? ?? ''),
      ));
      final setId = row['set_id'];
      if (setId == null) continue;
      loggedSets++;
      session.loggedSets++;
      if ((row['set_completed'] as num? ?? 0).toInt() != 1) continue;
      final reps = (row['actual_reps'] as num?)?.toInt() ?? 0;
      final rawWeight = (row['actual_weight'] as num?)?.toDouble();
      final unit = (row['weight_unit'] as String? ?? 'kg').toLowerCase();
      final weightKg = rawWeight == null ? null : WorkoutAnalysisCalculator.toKilograms(rawWeight, unit);
      totalSets++;
      session.completedSets++;
      totalReps += reps;
      session.reps += reps;
      if (weightKg != null) {
        final setVolume = weightKg * reps;
        volumeKg += setVolume;
        session.volumeKg += setVolume;
        if (weightKg > maxWeightKg) maxWeightKg = weightKg;
        weightedSetCount++;
        weightedLoadSumKg += weightKg;
      }
      final name = (row['exercise_name_snapshot'] as String? ?? 'Unknown exercise').trim();
      final key = name.toLowerCase();
      final exercise = exercises.putIfAbsent(key, () => _ExerciseStats(
        name: name,
        muscleGroup: row['muscle_group'] as String? ?? 'Other',
      ));
      exercise.sets++;
      exercise.reps += reps;
      if (weightKg != null) {
        exercise.volumeKg += weightKg * reps;
        if (weightKg > exercise.maxWeightKg) exercise.maxWeightKg = weightKg;
        final estimated = WorkoutAnalysisCalculator.estimateOneRepMax(weightKg, reps);
        if (estimated > exercise.estimatedOneRepMaxKg) exercise.estimatedOneRepMaxKg = estimated;
        if (weightKg > exercise.bestSetWeightKg ||
            (weightKg == exercise.bestSetWeightKg && reps > exercise.bestSetReps)) {
          exercise.bestSetWeightKg = weightKg;
          exercise.bestSetReps = reps;
        }
      }
      exercise.hasWeight = exercise.hasWeight || weightKg != null;
    }

    for (final session in sessions.values) {
      final startTime = session.startedAt;
      if (startTime == null) continue;
      final endTime = session.pausedAt ?? session.completedAt ?? DateTime.now();
      final elapsed = endTime.difference(startTime).inSeconds - session.pausedSeconds;
      if (elapsed > 0) durationMinutes += elapsed ~/ 60;
    }
    final muscleVolumes = <String, double>{};
    for (final exercise in exercises.values) {
      muscleVolumes.update(exercise.muscleGroup, (v) => v + exercise.volumeKg,
          ifAbsent: () => exercise.volumeKg);
    }
    final sortedExercises = exercises.values.toList()
      ..sort((a, b) => b.volumeKg.compareTo(a.volumeKg));
    return _PeriodStats(
      sessions: sessions.values.toList()..sort((a, b) => (b.startedAt ?? DateTime(2000)).compareTo(a.startedAt ?? DateTime(2000))),
      exercises: sortedExercises,
      totalSets: totalSets,
      loggedSets: loggedSets,
      totalReps: totalReps,
      volumeKg: volumeKg,
      maxWeightKg: maxWeightKg,
      weightedSetCount: weightedSetCount,
      averageLoadKg: WorkoutAnalysisCalculator.averageLoadPerWeightedSet(weightedLoadSumKg, weightedSetCount),
      durationMinutes: durationMinutes,
      muscleVolumes: muscleVolumes,
    );
  }

  String _volume(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(2)}k kg'
      : '${value.round()} kg';

  String _duration(int minutes) {
    if (minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _change(double current, double previous) {
    if (previous == 0) return current == 0 ? '—' : 'NEW';
    final percent = ((current - previous) / previous) * 100;
    return '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(1)}%';
  }

  Color _changeColor(double current, double previous) =>
      current > previous ? AppColors.green : current < previous ? AppColors.red : AppColors.grey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        title: Text('WORKOUT ANALYSIS', style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      body: FutureBuilder<_AnalysisData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load workout analysis.', style: GoogleFonts.inter(color: AppColors.grey)));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            color: AppColors.green,
            backgroundColor: AppColors.card,
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                _sectionLabel('TODAY', 'All sessions combined'),
                const SizedBox(height: 12),
                if (data.today.sessions.isEmpty)
                  _emptyCard('No workout recorded today', 'Your completed sets and workout statistics will appear here.')
                else ...[
                  _metricGrid(data.today),
                  const SizedBox(height: 10),
                  _panel(
                    title: 'SET COMPLETION',
                    subtitle: '${data.today.totalSets} completed out of ${data.today.loggedSets} logged sets',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.today.loggedSets == 0
                              ? 'No sets logged'
                              : '${(data.today.totalSets / data.today.loggedSets * 100).round()}% completed',
                          style: GoogleFonts.inter(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: data.today.loggedSets == 0 ? 0 : data.today.totalSets / data.today.loggedSets,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _panel(
                    title: 'TODAY\'S EXERCISES',
                    subtitle: '${data.today.exercises.length} exercises with completed sets',
                    child: Column(children: data.today.exercises.map(_exerciseTile).toList()),
                  ),
                  const SizedBox(height: 14),
                  _panel(
                    title: 'SESSIONS',
                    subtitle: '${data.today.sessions.length} session(s) today',
                    child: Column(children: data.today.sessions.map(_sessionTile).toList()),
                  ),
                ],
                const SizedBox(height: 26),
                _sectionLabel('7-DAY PROGRESS', 'Last 7 days vs previous 7 days'),
                const SizedBox(height: 12),
                _panel(
                  title: 'WEEKLY COMPARISON',
                  subtitle: 'Rolling 7-day periods • based on recorded workouts',
                  child: Column(children: [
                    _comparisonRow('Training volume', _volume(data.currentWeek.volumeKg), _volume(data.previousWeek.volumeKg), data.currentWeek.volumeKg, data.previousWeek.volumeKg),
                    _comparisonRow('Avg load / weighted set', data.currentWeek.weightedSetCount == 0 ? '—' : '${data.currentWeek.averageLoadKg.toStringAsFixed(1)} kg', data.previousWeek.weightedSetCount == 0 ? '—' : '${data.previousWeek.averageLoadKg.toStringAsFixed(1)} kg', data.currentWeek.averageLoadKg, data.previousWeek.averageLoadKg),
                    _comparisonRow('Completed sets', '${data.currentWeek.totalSets}', '${data.previousWeek.totalSets}', data.currentWeek.totalSets.toDouble(), data.previousWeek.totalSets.toDouble()),
                    _comparisonRow('Total reps', '${data.currentWeek.totalReps}', '${data.previousWeek.totalReps}', data.currentWeek.totalReps.toDouble(), data.previousWeek.totalReps.toDouble()),
                    _comparisonRow('Workout sessions', '${data.currentWeek.sessions.length}', '${data.previousWeek.sessions.length}', data.currentWeek.sessions.length.toDouble(), data.previousWeek.sessions.length.toDouble()),
                    _comparisonRow('Training time', _duration(data.currentWeek.durationMinutes), _duration(data.previousWeek.durationMinutes), data.currentWeek.durationMinutes.toDouble(), data.previousWeek.durationMinutes.toDouble()),
                    _comparisonRow('Exercises trained', '${data.currentWeek.exercises.length}', '${data.previousWeek.exercises.length}', data.currentWeek.exercises.length.toDouble(), data.previousWeek.exercises.length.toDouble()),
                  ]),
                ),
                const SizedBox(height: 14),
                _panel(
                  title: 'PROGRESSIVE OVERLOAD',
                  subtitle: 'Exercise volume and estimated strength comparison',
                  child: data.currentWeek.exercises.isEmpty
                      ? _inlineEmpty('No completed sets in the current 7-day period.')
                      : Column(children: data.currentWeek.exercises.map((exercise) {
                          final previous = _matchingExercise(data.previousWeek.exercises, exercise.name);
                          final hasBaseline = previous != null && previous.hasWeight && exercise.hasWeight && previous.estimatedOneRepMaxKg > 0;
                          final volumeChange = hasBaseline ? _change(exercise.volumeKg, previous.volumeKg) : 'NEW';
                          final strengthChange = hasBaseline ? _change(exercise.estimatedOneRepMaxKg, previous.estimatedOneRepMaxKg) : '—';
                          final progression = WorkoutAnalysisCalculator.classifyProgression(
                            currentEstimatedOneRepMaxKg: exercise.estimatedOneRepMaxKg,
                            previousEstimatedOneRepMaxKg: previous?.estimatedOneRepMaxKg,
                            currentHasWeight: exercise.hasWeight,
                            previousHasWeight: previous?.hasWeight ?? false,
                          );
                          final status = progression.label;
                          final color = progression == WorkoutProgression.progressing
                              ? AppColors.green
                              : progression == WorkoutProgression.declining
                                  ? AppColors.red
                                  : AppColors.grey;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(exercise.name, style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                                Text(status, style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
                              ]),
                              const SizedBox(height: 5),
                              Text('${exercise.sets} sets • ${exercise.reps} reps • ${_volume(exercise.volumeKg)}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
                              const SizedBox(height: 3),
                              Text('Volume: $volumeChange   •   Est. 1RM: $strengthChange', style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                            ]),
                          );
                        }).toList()),
                ),
                const SizedBox(height: 14),
                _panel(
                  title: 'EXERCISE PERFORMANCE',
                  subtitle: 'Last 7 days vs previous 7 days • completed weighted sets',
                  child: data.currentWeek.exercises.isEmpty
                      ? _inlineEmpty('No completed exercises in the current 7-day period.')
                      : Column(
                          children: data.currentWeek.exercises.map((exercise) {
                            final previous = _matchingExercise(data.previousWeek.exercises, exercise.name);
                            return _exercisePerformanceTile(exercise, previous);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _panel(
                  title: 'MUSCLE GROUP DISTRIBUTION',
                  subtitle: 'Recorded lifted volume by muscle group',
                  child: data.currentWeek.muscleVolumes.isEmpty
                      ? _inlineEmpty('No muscle-group data recorded this week.')
                      : Column(children: _muscleGroupRows(data.currentWeek)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Volume uses completed reps × recorded weight, converted to kg. Average load is the arithmetic mean of recorded loads across completed weighted sets; it is a basic load-intensity proxy, not %1RM or effort/RIR. Estimated 1RM uses the Epley formula and is an estimate, not a tested max. Cardio, bodyweight-only sets and sets without a recorded load are counted in set/repetition totals but not weighted volume.',
                  style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10, height: 1.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: GoogleFonts.inter(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    const SizedBox(height: 4),
    Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
  ]);

  Widget _metricGrid(_PeriodStats stats) => Column(children: [
    Row(children: [
      Expanded(child: _metric('TOTAL VOLUME', _volume(stats.volumeKg), Icons.fitness_center, AppColors.red)),
      const SizedBox(width: 10),
      Expanded(child: _metric('DURATION', _duration(stats.durationMinutes), Icons.timer_outlined, AppColors.green)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _metric('WORKING SETS', '${stats.totalSets}', Icons.repeat, AppColors.green)),
      const SizedBox(width: 10),
      Expanded(child: _metric('TOTAL REPS', '${stats.totalReps}', Icons.format_list_numbered, AppColors.red)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _metric('HEAVIEST LOAD', stats.weightedSetCount == 0 ? '—' : '${stats.maxWeightKg.toStringAsFixed(1)} kg', Icons.monitor_weight_outlined, AppColors.red)),
      const SizedBox(width: 10),
      Expanded(child: _metric('EXERCISES', '${stats.exercises.length}', Icons.sports_gymnastics, AppColors.green)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _metric('AVG LOAD / WEIGHTED SET', stats.weightedSetCount == 0 ? '—' : '${stats.averageLoadKg.toStringAsFixed(1)} kg', Icons.speed, AppColors.green)),
      const SizedBox(width: 10),
      const Expanded(child: SizedBox()),
    ]),
  ]);

  Widget _metric(String label, String value, IconData icon, Color accent) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: accent, size: 18),
      const SizedBox(height: 10),
      Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .5)),
    ]),
  );

  Widget _panel({required String title, required String subtitle, required Widget child}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6)),
      const SizedBox(height: 4),
      Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Widget _comparisonRow(String label, String current, String previous, double currentValue, double previousValue) {
    final delta = _change(currentValue, previousValue);
    final color = _changeColor(currentValue, previousValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11))),
        SizedBox(width: 76, child: Text(current, textAlign: TextAlign.end, style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        SizedBox(width: 76, child: Text(previous, textAlign: TextAlign.end, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10))),
        SizedBox(width: 58, child: Text(delta, textAlign: TextAlign.end, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _exercisePerformanceTile(_ExerciseStats current, _ExerciseStats? previous) {
    final priorWeighted = previous != null && previous.hasWeight;
    final currentWeighted = current.hasWeight;
    final strengthStatus = WorkoutAnalysisCalculator.classifyProgression(
      currentEstimatedOneRepMaxKg: current.estimatedOneRepMaxKg,
      previousEstimatedOneRepMaxKg: previous?.estimatedOneRepMaxKg,
      currentHasWeight: currentWeighted,
      previousHasWeight: priorWeighted,
    );
    final statusColor = strengthStatus == WorkoutProgression.progressing
        ? AppColors.green
        : strengthStatus == WorkoutProgression.declining
            ? AppColors.red
            : AppColors.grey;
    String load(double value, bool available) =>
        available ? '${value.toStringAsFixed(1)} kg' : '—';
    String bestSet(_ExerciseStats? stats) => stats == null || !stats.hasWeight
        ? '—'
        : '${stats.bestSetWeightKg.toStringAsFixed(1)} kg × ${stats.bestSetReps}';
    Widget comparison(String label, String currentValue, String previousValue) =>
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Row(
            children: [
              Expanded(child: Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10))),
              Expanded(child: Text(currentValue, textAlign: TextAlign.right,
                  style: GoogleFonts.inter(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              Expanded(child: Text(previousValue, textAlign: TextAlign.right,
                  style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10))),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(current.name,
              style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          Text(strengthStatus.label,
              style: GoogleFonts.inter(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(child: SizedBox()),
          Expanded(child: Text('LAST 7 DAYS', textAlign: TextAlign.right,
              style: GoogleFonts.inter(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.w700))),
          Expanded(child: Text('PREVIOUS 7', textAlign: TextAlign.right,
              style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9))),
        ]),
        comparison('Best set', bestSet(current), bestSet(previous)),
        comparison('Est. 1RM', load(current.estimatedOneRepMaxKg, currentWeighted),
            load(previous?.estimatedOneRepMaxKg ?? 0, priorWeighted)),
        comparison('Top load', load(current.maxWeightKg, currentWeighted),
            load(previous?.maxWeightKg ?? 0, priorWeighted)),
        comparison('Volume', currentWeighted ? _volume(current.volumeKg) : '—',
            priorWeighted ? _volume(previous.volumeKg) : '—'),
        comparison('Completed sets', '${current.sets}', previous == null ? '—' : '${previous.sets}'),
        comparison('Total reps', '${current.reps}', previous == null ? '—' : '${previous.reps}'),
      ]),
    );
  }

  Widget _exerciseTile(_ExerciseStats e) => InkWell(
    onTap: () => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExercisePerformanceScreen(exerciseName: e.name),
    )),
    borderRadius: BorderRadius.circular(8),
    child: Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.name, style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        Text('${e.muscleGroup} • ${e.sets} sets • ${e.reps} reps', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9)),
        if (e.hasWeight)
          Text(
            'Best set: ${e.bestSetWeightKg.toStringAsFixed(1)} kg × ${e.bestSetReps} reps • Est. 1RM ${e.estimatedOneRepMaxKg.toStringAsFixed(1)} kg',
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9),
          ),
      ])),
      Text(e.hasWeight ? _volume(e.volumeKg) : 'No load', style: GoogleFonts.inter(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  ),
  );

  Widget _sessionTile(_SessionStats s) {
    final date = s.startedAt;
    final time = date == null ? '' : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const Icon(Icons.fitness_center, color: AppColors.red, size: 17),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          Text('${time.isEmpty ? 'Time unavailable' : time} • ${s.status == 'completed' ? 'Completed' : 'In progress'}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9)),
          Text('${s.completedSets}/${s.loggedSets} sets • ${s.reps} reps • ${_volume(s.volumeKg)}', style: GoogleFonts.inter(color: AppColors.green, fontSize: 9)),
        ])),
        const Icon(Icons.chevron_right, color: AppColors.grey, size: 17),
      ]),
    );
  }

  _ExerciseStats? _matchingExercise(List<_ExerciseStats> list, String name) {
    for (final exercise in list) {
      if (exercise.name.toLowerCase() == name.toLowerCase()) return exercise;
    }
    return null;
  }

  List<Widget> _muscleGroupRows(_PeriodStats stats) {
    final entries = stats.muscleVolumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) => _barRow(entry.key, entry.value, stats.volumeKg)).toList();
  }

  Widget _barRow(String label, double value, double total) {
    final fraction = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(color: AppColors.white, fontSize: 10))),
          Text(_volume(value), style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: fraction, minHeight: 5, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green))),
      ]),
    );
  }

  Widget _emptyCard(String title, String subtitle) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      const Icon(Icons.insights_outlined, color: AppColors.green, size: 30),
      const SizedBox(height: 10),
      Text(title, style: GoogleFonts.inter(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
    ]),
  );

  Widget _inlineEmpty(String text) => Text(text, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10));
}

class _AnalysisData {
  final _PeriodStats today;
  final _PeriodStats currentWeek;
  final _PeriodStats previousWeek;
  const _AnalysisData({required this.today, required this.currentWeek, required this.previousWeek});
}

class _PeriodStats {
  final List<_SessionStats> sessions;
  final List<_ExerciseStats> exercises;
  final int totalSets;
  final int loggedSets;
  final int totalReps;
  final double volumeKg;
  final double maxWeightKg;
  final int weightedSetCount;
  final double averageLoadKg;
  final int durationMinutes;
  final Map<String, double> muscleVolumes;
  const _PeriodStats({required this.sessions, required this.exercises, required this.totalSets, required this.loggedSets, required this.totalReps, required this.volumeKg, required this.maxWeightKg, required this.weightedSetCount, required this.averageLoadKg, required this.durationMinutes, required this.muscleVolumes});
}

class _SessionStats {
  final int id;
  final String name;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String status;
  final int pausedSeconds;
  final DateTime? pausedAt;
  int loggedSets = 0;
  int completedSets = 0;
  int reps = 0;
  double volumeKg = 0;
  _SessionStats({required this.id, required this.name, required this.startedAt, required this.completedAt, required this.status, required this.pausedSeconds, required this.pausedAt});
}

class _ExerciseStats {
  final String name;
  final String muscleGroup;
  int sets = 0;
  int reps = 0;
  double volumeKg = 0;
  double maxWeightKg = 0;
  double bestSetWeightKg = 0;
  int bestSetReps = 0;
  double estimatedOneRepMaxKg = 0;
  bool hasWeight = false;
  _ExerciseStats({required this.name, required this.muscleGroup});
}
