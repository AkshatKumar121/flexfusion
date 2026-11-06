import 'package:flutter/material.dart';
import '../../app/auto_refresh_on_return.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'workout_analysis_calculator.dart';

class ExercisePerformanceScreen extends StatefulWidget {
  final String exerciseName;

  const ExercisePerformanceScreen({super.key, required this.exerciseName});

  @override
  State<ExercisePerformanceScreen> createState() => _ExercisePerformanceScreenState();
}

class _ExercisePerformanceScreenState extends State<ExercisePerformanceScreen> with AutoRefreshOnReturn<ExercisePerformanceScreen> {
  @override
  Future<void> refreshAfterReturn() => _refresh();

  late Future<List<Map<String, Object?>>> _history;

  @override
  void initState() {
    super.initState();
    _history = AppDatabase.instance.getExercisePerformanceHistory(widget.exerciseName);
  }

  Future<void> _refresh() async {
    setState(() {
      _history = AppDatabase.instance.getExercisePerformanceHistory(widget.exerciseName);
    });
    await _history;
  }

  String _date(DateTime? value) {
    if (value == null) return 'Date unavailable';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _volume(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(2)}k kg'
      : '${value.round()} kg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        title: Text('EXERCISE HISTORY', style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: .8)),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load exercise history.', style: GoogleFonts.inter(color: AppColors.grey)));
          }
          final rows = snapshot.data ?? [];
          final sessions = <int, _ExerciseSession>{};
          for (final row in rows) {
            final id = row['workout_id'] as int;
            final session = sessions.putIfAbsent(id, () => _ExerciseSession(
              name: row['session_name'] as String? ?? 'Workout',
              date: DateTime.tryParse(row['started_at'] as String? ?? ''),
            ));
            final reps = (row['actual_reps'] as num?)?.toInt() ?? 0;
            final rawWeight = (row['actual_weight'] as num?)?.toDouble();
            final unit = (row['weight_unit'] as String? ?? 'kg').toLowerCase();
            final weight = rawWeight == null ? null : WorkoutAnalysisCalculator.toKilograms(rawWeight, unit);
            session.sets++;
            session.reps += reps;
            if (weight != null) {
              session.volumeKg += weight * reps;
              session.hasLoad = true;
              if (weight > session.topLoadKg) session.topLoadKg = weight;
              final e1rm = WorkoutAnalysisCalculator.estimateOneRepMax(weight, reps);
              if (e1rm > session.estimatedOneRepMaxKg) session.estimatedOneRepMaxKg = e1rm;
              if (weight > session.bestSetWeightKg ||
                  (weight == session.bestSetWeightKg && reps > session.bestSetReps)) {
                session.bestSetWeightKg = weight;
                session.bestSetReps = reps;
              }
            }
          }
          final history = sessions.values.toList()
            ..sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
          final weighted = history.where((s) => s.hasLoad).toList();
          final bestLoad = weighted.fold<double>(0, (v, s) => s.topLoadKg > v ? s.topLoadKg : v);
          final bestE1rm = weighted.fold<double>(0, (v, s) => s.estimatedOneRepMaxKg > v ? s.estimatedOneRepMaxKg : v);
          final totalVolume = history.fold<double>(0, (v, s) => v + s.volumeKg);
          final totalSets = history.fold<int>(0, (v, s) => v + s.sets);
          final totalReps = history.fold<int>(0, (v, s) => v + s.reps);
          return RefreshIndicator(
            color: AppColors.green,
            backgroundColor: AppColors.card,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                Text(widget.exerciseName, style: GoogleFonts.inter(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('${history.length} recorded sessions • all available history', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                const SizedBox(height: 16),
                if (history.isEmpty)
                  _panel('NO HISTORY YET', 'Completed sets for this exercise will appear here.')
                else ...[
                  Row(children: [
                    Expanded(child: _metric('PERSONAL BEST LOAD', bestLoad == 0 ? '—' : '${bestLoad.toStringAsFixed(1)} kg')),
                    const SizedBox(width: 9),
                    Expanded(child: _metric('BEST EST. 1RM', bestE1rm == 0 ? '—' : '${bestE1rm.toStringAsFixed(1)} kg')),
                  ]),
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: _metric('TOTAL VOLUME', _volume(totalVolume))),
                    const SizedBox(width: 9),
                    Expanded(child: _metric('SETS / REPS', '$totalSets / $totalReps')),
                  ]),
                  const SizedBox(height: 22),
                  _heading('SESSION HISTORY'),
                  const SizedBox(height: 10),
                  ...history.map((session) => _sessionTile(session)),
                  const SizedBox(height: 12),
                  Text(
                    'Volume is calculated from completed sets with a recorded load. Loads are converted to kg. Estimated 1RM uses the Epley formula and is an estimate, not a tested maximum. Bodyweight-only sets are included in set and rep totals but not weighted volume.',
                    style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10, height: 1.5),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heading(String value) => Text(value, style: GoogleFonts.inter(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1));

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _panel(String title, String subtitle) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Text(title, style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
    ]),
  );

  Widget _sessionTile(_ExerciseSession session) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(_date(session.date), style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        Text(session.hasLoad ? '${session.topLoadKg.toStringAsFixed(1)} kg top' : 'No load', style: GoogleFonts.inter(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      Text(session.name, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
      const SizedBox(height: 9),
      Row(children: [
        _detail('SETS', '${session.sets}'),
        _detail('REPS', '${session.reps}'),
        _detail('VOLUME', _volume(session.volumeKg)),
        _detail('EST. 1RM', session.hasLoad ? '${session.estimatedOneRepMaxKg.toStringAsFixed(1)} kg' : '—'),
      ]),
      if (session.bestSetWeightKg > 0) ...[
        const SizedBox(height: 8),
        Text('Best set: ${session.bestSetWeightKg.toStringAsFixed(1)} kg × ${session.bestSetReps} reps',
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
      ],
    ]),
  );

  Widget _detail(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    const SizedBox(height: 3),
    Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 8, fontWeight: FontWeight.w700)),
  ]));
}

class _ExerciseSession {
  final String name;
  final DateTime? date;
  int sets = 0;
  int reps = 0;
  double volumeKg = 0;
  double topLoadKg = 0;
  double bestSetWeightKg = 0;
  int bestSetReps = 0;
  double estimatedOneRepMaxKg = 0;
  bool hasLoad = false;

  _ExerciseSession({required this.name, required this.date});
}
