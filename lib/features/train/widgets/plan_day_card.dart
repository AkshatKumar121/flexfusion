import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/local/app_database.dart';

class PlanDayCard extends StatefulWidget {
  final Map<String, Object?> day;
  final int index;
  final Future<void> Function() onAddExercise;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onDelete;
  const PlanDayCard({super.key, required this.day, required this.index, required this.onAddExercise, required this.onEdit, required this.onStart, required this.onDelete});

  @override
  State<PlanDayCard> createState() => _PlanDayCardState();
}

class _PlanDayCardState extends State<PlanDayCard> {
  late Future<List<Map<String, Object?>>> _exercisesFuture;
  @override
  void initState() { super.initState(); _load(); }
  void _load() { _exercisesFuture = AppDatabase.instance.getPlanDayExercises(widget.day['id'] as int); }

  Future<void> _substitute(Map<String, Object?> exercise) async {
    final library = await AppDatabase.instance.getExercises();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Map<String, Object?>>(context: context, backgroundColor: AppColors.card, builder: (context) => SafeArea(child: ListView(shrinkWrap: true, children: [
      const ListTile(title: Text('Replace with')),
      for (final item in library) ListTile(title: Text(item['name'] as String), subtitle: Text('${item['muscle_group'] ?? ''} • ${item['equipment'] ?? ''}'), onTap: () => Navigator.pop(context, item)),
    ])));
    if (selected == null) return;
    await AppDatabase.instance.substitutePlanExercise(planExerciseId: exercise['id'] as int, exerciseId: selected['id'] as int, exerciseName: selected['name'] as String);
    if (mounted) setState(_load);
  }

  Future<void> _editTargets(Map<String, Object?> exercise) async {
    final sets = await AppDatabase.instance.getPlanExerciseSets(exercise['id'] as int);
    if (sets.isEmpty || !mounted) return;
    final first = sets.first;
    final count = TextEditingController(text: sets.length.toString());
    final reps = TextEditingController(text: first['target_reps'].toString());
    final weight = TextEditingController(text: first['target_weight']?.toString() ?? '');
    final rest = TextEditingController(text: first['rest_seconds'].toString());
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Edit ${exercise['exercise_name_snapshot']}', style: GoogleFonts.inter(color: AppColors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sets')),
        TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target reps')),
        TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target weight kg')),
        TextField(controller: rest, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rest seconds')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE'))],
    ));
    final setCount = int.tryParse(count.text);
    final targetReps = int.tryParse(reps.text);
    final restSeconds = int.tryParse(rest.text);
    final targetWeight = double.tryParse(weight.text);
    if (ok == true && setCount != null && setCount > 0 && setCount <= 20 && targetReps != null && targetReps > 0 && restSeconds != null && restSeconds >= 0 && (weight.text.trim().isEmpty || (targetWeight != null && targetWeight >= 0))) {
      await AppDatabase.instance.updatePlanExerciseSets(planExerciseId: exercise['id'] as int, setCount: setCount, targetReps: targetReps, targetWeight: targetWeight, weightUnit: 'kg', restSeconds: restSeconds);
      if (mounted) setState(_load);
    }
    count.dispose(); reps.dispose(); weight.dispose(); rest.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rest = (widget.day['is_rest_day'] as int? ?? 0) == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ReorderableDragStartListener(index: widget.index, child: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.drag_handle, color: AppColors.grey, size: 22))),
          Expanded(child: Text(widget.day['label'] as String, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w700))),
          Text(rest ? 'REST' : (widget.day['schedule_type'] == 'weekday' ? _weekday(widget.day['weekday'] as int? ?? 1) : 'SEQUENCE'), style: GoogleFonts.inter(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.w800)),
          if (!rest) TextButton(onPressed: widget.onStart, child: const Text('START')),
          IconButton(onPressed: widget.onEdit, icon: const Icon(Icons.edit_outlined, color: AppColors.grey, size: 18)),
          IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, color: AppColors.grey, size: 19)),
        ]),
        if (!rest) FutureBuilder<List<Map<String, Object?>>>(
          future: _exercisesFuture,
          builder: (context, snapshot) {
            final exercises = snapshot.data ?? [];
            return Column(children: [
              for (final exercise in exercises)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(exercise['exercise_name_snapshot'] as String, style: GoogleFonts.inter(color: AppColors.white, fontSize: 12)),
                  onTap: () => _editTargets(exercise),
                  subtitle: FutureBuilder<List<Map<String, Object?>>>(
                    future: AppDatabase.instance.getPlanExerciseSets(exercise['id'] as int),
                    builder: (context, sets) {
                      final rows = sets.data ?? [];
                      if (rows.isEmpty) return const SizedBox.shrink();
                      final first = rows.first;
                      final weight = first['target_weight'] == null ? '' : ' • ${first['target_weight']} kg';
                      return Text('${rows.length} sets × ${first['target_reps']} reps$weight • ${first['rest_seconds']}s rest', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10));
                    },
                  ),
                  trailing: PopupMenuButton<String>(
                    iconColor: AppColors.grey,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editTargets(exercise);
                      } else if (value == 'substitute') {
                        await _substitute(exercise);
                      } else if (value == 'remove') {
                        await AppDatabase.instance.deletePlanExercise(exercise['id'] as int);
                        if (mounted) setState(_load);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit sets and targets')),
                      PopupMenuItem(value: 'substitute', child: Text('Substitute exercise')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () async { await widget.onAddExercise(); if (mounted) setState(_load); }, icon: const Icon(Icons.add, size: 16), label: const Text('ADD EXERCISE'))),
            ]);
          },
        ) else Padding(padding: const EdgeInsets.only(top: 5), child: Text('Recovery day — no exercises scheduled.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11))),
      ]),
    );
  }

  String _weekday(int day) => const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][day - 1];
}
