import 'package:flutter/material.dart';
import '../../app/auto_refresh_on_return.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});
  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}
class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> with AutoRefreshOnReturn<WorkoutHistoryScreen> {
  @override
  Future<void> refreshAfterReturn() async {
    if (!mounted) return;
    final future = AppDatabase.instance.getWorkoutHistory();
    setState(() => _history = future);
    await future;
  }

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
