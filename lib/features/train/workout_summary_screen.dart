import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

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
