import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  late Future<List<Map<String, Object?>>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _plansFuture = AppDatabase.instance.getWorkoutPlans();

  Future<void> _refresh() async {
    setState(_reload);
    await _plansFuture;
  }

  Future<String?> _textDialog(String title, {String initial = '', String hint = 'Name'}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(color: AppColors.white),
          decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('SAVE')),
        ],
      ),
    );
    controller.dispose();
    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<void> _createPlan() async {
    final name = await _textDialog('Create workout plan', hint: 'e.g. Strength Split');
    if (name == null || !mounted) return;
    await AppDatabase.instance.createWorkoutPlan(name);
    await _refresh();
  }

  Future<void> _openPlan(Map<String, Object?> plan) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WorkoutPlanDetailScreen(plan: plan),
    ));
    if (mounted) await _refresh();
  }

  Future<void> _rename(Map<String, Object?> plan) async {
    final name = await _textDialog('Rename workout plan', initial: plan['name'] as String);
    if (name == null || !mounted) return;
    await AppDatabase.instance.updateWorkoutPlan(plan['id'] as int, name: name);
    await _refresh();
  }

  Future<void> _duplicate(Map<String, Object?> plan) async {
    final name = await _textDialog('Duplicate plan', initial: '${plan['name']} Copy');
    if (name == null || !mounted) return;
    await AppDatabase.instance.duplicateWorkoutPlan(plan['id'] as int, name);
    await _refresh();
  }

  Future<void> _delete(Map<String, Object?> plan) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete plan?', style: GoogleFonts.inter(color: AppColors.white)),
        content: Text('This removes "${plan['name']}" and its planned days. Completed workout history is kept.', style: GoogleFonts.inter(color: AppColors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (yes == true) {
      await AppDatabase.instance.deleteWorkoutPlan(plan['id'] as int);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        title: Text('MY WORKOUT PLANS', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlan,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('NEW PLAN'),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final plans = snapshot.data ?? [];
          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_month_outlined, color: AppColors.green, size: 42),
                  const SizedBox(height: 14),
                  Text('No workout plans yet', style: GoogleFonts.inter(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  Text('Create a plan, add your training days and choose your exercises.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12)),
                ]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final active = (plan['is_active'] as int? ?? 0) == 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: active ? AppColors.green : AppColors.border)),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(15, 9, 8, 9),
                  title: Row(children: [
                    Expanded(child: Text(plan['name'] as String, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w700))),
                    if (active) const Chip(label: Text('ACTIVE'), backgroundColor: AppColors.green, labelStyle: TextStyle(color: Colors.black, fontSize: 9)),
                  ]),
                  subtitle: Text((plan['description'] as String?)?.isNotEmpty == true ? plan['description'] as String : 'Tap to manage days and exercises', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                  onTap: () => _openPlan(plan),
                  trailing: PopupMenuButton<String>(
                    iconColor: AppColors.grey,
                    onSelected: (value) async {
                      if (value == 'activate') {
                        await AppDatabase.instance.setActiveWorkoutPlan(plan['id'] as int);
                        await _refresh();
                      } else if (value == 'rename') {
                        await _rename(plan);
                      } else if (value == 'duplicate') {
                        await _duplicate(plan);
                      } else if (value == 'delete') {
                        await _delete(plan);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!active) const PopupMenuItem(value: 'activate', child: Text('Set as active')),
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class WorkoutPlanDetailScreen extends StatefulWidget {
  final Map<String, Object?> plan;
  const WorkoutPlanDetailScreen({super.key, required this.plan});

  @override
  State<WorkoutPlanDetailScreen> createState() => _WorkoutPlanDetailScreenState();
}

class _WorkoutPlanDetailScreenState extends State<WorkoutPlanDetailScreen> {
  late Future<List<Map<String, Object?>>> _daysFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _daysFuture = AppDatabase.instance.getWorkoutPlanDays(widget.plan['id'] as int);

  Future<void> _refresh() async {
    setState(_reload);
    await _daysFuture;
  }

  Future<void> _editDay(Map<String, Object?> day) async {
    final controller = TextEditingController(text: day['label'] as String);
    var type = day['schedule_type'] as String? ?? 'sequence';
    var weekday = day['weekday'] as int? ?? 1;
    var rest = (day['is_rest_day'] as int? ?? 0) == 1;
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Edit plan day'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: controller, decoration: const InputDecoration(labelText: 'Day name')),
        DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Schedule'), items: const [DropdownMenuItem(value: 'sequence', child: Text('Sequence based')), DropdownMenuItem(value: 'weekday', child: Text('Fixed weekday'))], onChanged: (v) => setDialog(() => type = v ?? 'sequence')),
        if (type == 'weekday') DropdownButtonFormField<int>(value: weekday, decoration: const InputDecoration(labelText: 'Weekday'), items: const [DropdownMenuItem(value: 1, child: Text('Monday')), DropdownMenuItem(value: 2, child: Text('Tuesday')), DropdownMenuItem(value: 3, child: Text('Wednesday')), DropdownMenuItem(value: 4, child: Text('Thursday')), DropdownMenuItem(value: 5, child: Text('Friday')), DropdownMenuItem(value: 6, child: Text('Saturday')), DropdownMenuItem(value: 7, child: Text('Sunday'))], onChanged: (v) => setDialog(() => weekday = v ?? 1)),
        CheckboxListTile(value: rest, onChanged: (v) => setDialog(() => rest = v ?? false), title: const Text('Rest day'), contentPadding: EdgeInsets.zero),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE'))],
    )));
    if (ok == true && controller.text.trim().isNotEmpty && mounted) {
      await AppDatabase.instance.updateWorkoutPlanDay(id: day['id'] as int, label: controller.text, dayOrder: day['day_order'] as int, scheduleType: type, weekday: type == 'weekday' ? weekday : null, isRestDay: rest);
      await _refresh();
    }
    controller.dispose();
  }

  Future<void> _addDay() async {
    final labelController = TextEditingController();
    var scheduleType = 'sequence';
    var weekday = DateTime.now().weekday;
    var isRest = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Add plan day', style: GoogleFonts.inter(color: AppColors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelController, style: GoogleFonts.inter(color: AppColors.white), decoration: const InputDecoration(labelText: 'Day name (e.g. Push A)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: scheduleType,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'Schedule'),
            items: const [DropdownMenuItem(value: 'sequence', child: Text('Sequence based')), DropdownMenuItem(value: 'weekday', child: Text('Fixed weekday'))],
            onChanged: (v) => setDialogState(() => scheduleType = v ?? 'sequence'),
          ),
          if (scheduleType == 'weekday') DropdownButtonFormField<int>(
            value: weekday,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'Weekday'),
            items: const [DropdownMenuItem(value: 1, child: Text('Monday')), DropdownMenuItem(value: 2, child: Text('Tuesday')), DropdownMenuItem(value: 3, child: Text('Wednesday')), DropdownMenuItem(value: 4, child: Text('Thursday')), DropdownMenuItem(value: 5, child: Text('Friday')), DropdownMenuItem(value: 6, child: Text('Saturday')), DropdownMenuItem(value: 7, child: Text('Sunday'))],
            onChanged: (v) => setDialogState(() => weekday = v ?? 1),
          ),
          CheckboxListTile(value: isRest, onChanged: (v) => setDialogState(() => isRest = v ?? false), title: const Text('Rest day'), contentPadding: EdgeInsets.zero),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ADD')),
        ],
      )),
    );
    final label = labelController.text.trim();
    labelController.dispose();
    if (result != true || label.isEmpty || !mounted) return;
    final days = await AppDatabase.instance.getWorkoutPlanDays(widget.plan['id'] as int);
    await AppDatabase.instance.addWorkoutPlanDay(
      planId: widget.plan['id'] as int,
      label: label,
      dayOrder: days.length + 1,
      scheduleType: scheduleType,
      weekday: scheduleType == 'weekday' ? weekday : null,
      isRestDay: isRest,
    );
    await _refresh();
  }

  Future<void> _addExercise(int dayId) async {
    final exercises = await AppDatabase.instance.getExercises();
    final existingExercises = await AppDatabase.instance.getPlanDayExercises(dayId);
    if (!mounted) return;
    final selected = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      builder: (context) => SafeArea(child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Choose exercise', style: GoogleFonts.inter(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w700))),
          Expanded(child: exercises.isEmpty
            ? Center(child: Text('Add exercises in Exercise Library first.', style: GoogleFonts.inter(color: AppColors.grey)))
            : ListView.builder(itemCount: exercises.length, itemBuilder: (_, i) {
                final exercise = exercises[i];
                return ListTile(
                  title: Text(exercise['name'] as String, style: GoogleFonts.inter(color: AppColors.white)),
                  subtitle: Text('${exercise['muscle_group'] ?? 'Other'} • ${exercise['equipment'] ?? 'Equipment not set'}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                  onTap: () => Navigator.pop(context, exercise),
                );
              })),
        ]),
      )),
    );
    if (selected == null || !mounted) return;
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');
    final weightController = TextEditingController();
    final restController = TextEditingController(text: '90');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Set targets', style: GoogleFonts.inter(color: AppColors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${selected['name']}', style: GoogleFonts.inter(color: AppColors.green)),
          TextField(controller: setsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of sets')),
          TextField(controller: repsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target reps per set')),
          TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target weight in kg (optional)')),
          TextField(controller: restController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rest seconds')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ADD')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final setCount = int.tryParse(setsController.text) ?? 3;
      final reps = int.tryParse(repsController.text) ?? 10;
      final rest = int.tryParse(restController.text) ?? 90;
      final weight = double.tryParse(weightController.text);
      if (setCount > 0 && setCount <= 20 && reps > 0 && reps <= 100 && rest >= 0 && rest <= 3600 && (weight == null || weight >= 0)) {
        await AppDatabase.instance.addExerciseToPlanDay(
          dayId: dayId,
          exerciseId: selected['id'] as int,
          exerciseName: selected['name'] as String,
          exerciseOrder: existingExercises.length + 1,
          setCount: setCount,
          targetReps: reps,
          targetWeight: weight,
          restSeconds: rest,
        );
        await _refresh();
      }
    }
    setsController.dispose(); repsController.dispose(); weightController.dispose(); restController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.white, title: Text(widget.plan['name'] as String, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addDay, backgroundColor: AppColors.green, foregroundColor: Colors.black, icon: const Icon(Icons.add), label: const Text('ADD DAY')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _daysFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final days = snapshot.data!;
          if (days.isEmpty) return Center(child: Text('Add your first training or rest day.', style: GoogleFonts.inter(color: AppColors.grey)));
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final reordered = [...days];
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              for (var i = 0; i < reordered.length; i++) {
                final row = reordered[i];
                await AppDatabase.instance.updateWorkoutPlanDay(id: row['id'] as int, label: row['label'] as String, dayOrder: i + 1, scheduleType: row['schedule_type'] as String, weekday: row['weekday'] as int?, isRestDay: (row['is_rest_day'] as int? ?? 0) == 1);
              }
              await _refresh();
            },
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return _PlanDayCard(
                key: ValueKey(day['id']),
                day: day,
                onAddExercise: () => _addExercise(day['id'] as int),
                onEdit: () => _editDay(day),
                onDelete: () async { await AppDatabase.instance.deleteWorkoutPlanDay(day['id'] as int); await _refresh(); },
              );
            },
          );
        },
      ),
    );
  }
}

class _PlanDayCard extends StatefulWidget {
  final Map<String, Object?> day;
  final Future<void> Function() onAddExercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PlanDayCard({super.key, required this.day, required this.onAddExercise, required this.onEdit, required this.onDelete});

  @override
  State<_PlanDayCard> createState() => _PlanDayCardState();
}

class _PlanDayCardState extends State<_PlanDayCard> {
  late Future<List<Map<String, Object?>>> _exercisesFuture;
  @override
  void initState() { super.initState(); _load(); }
  void _load() => _exercisesFuture = AppDatabase.instance.getPlanDayExercises(widget.day['id'] as int);

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
          Expanded(child: Text(widget.day['label'] as String, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w700))),
          Text(rest ? 'REST' : (widget.day['schedule_type'] == 'weekday' ? _weekday(widget.day['weekday'] as int? ?? 1) : 'SEQUENCE'), style: GoogleFonts.inter(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.w800)),
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
                  trailing: IconButton(onPressed: () async {
                    await AppDatabase.instance.deletePlanExercise(exercise['id'] as int);
                    if (mounted) setState(_load);
                  }, icon: const Icon(Icons.close, color: AppColors.grey, size: 18)),
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

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _future = AppDatabase.instance.getExercises();

  Future<void> _editExercise([Map<String, Object?>? exercise]) async {
    final name = TextEditingController(text: exercise?['name'] as String? ?? '');
    final muscle = TextEditingController(text: exercise?['muscle_group'] as String? ?? '');
    final equipment = TextEditingController(text: exercise?['equipment'] as String? ?? '');
    final instructions = TextEditingController(text: exercise?['instructions'] as String? ?? '');
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(exercise == null ? 'Add exercise' : 'Edit exercise', style: GoogleFonts.inter(color: AppColors.white)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, style: GoogleFonts.inter(color: AppColors.white), decoration: const InputDecoration(labelText: 'Exercise name')),
        TextField(controller: muscle, style: GoogleFonts.inter(color: AppColors.white), decoration: const InputDecoration(labelText: 'Muscle group')),
        TextField(controller: equipment, style: GoogleFonts.inter(color: AppColors.white), decoration: const InputDecoration(labelText: 'Equipment')),
        TextField(controller: instructions, style: GoogleFonts.inter(color: AppColors.white), decoration: const InputDecoration(labelText: 'Instructions (optional)'), maxLines: 2),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE'))],
    ));
    if (ok == true && name.text.trim().isNotEmpty && mounted) {
      await AppDatabase.instance.saveExercise(
        id: exercise?['id'] as int?,
        name: name.text,
        muscleGroup: muscle.text,
        equipment: equipment.text,
        instructions: instructions.text,
      );
      setState(_reload);
    }
    name.dispose(); muscle.dispose(); equipment.dispose(); instructions.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.white, title: Text('EXERCISE LIBRARY', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800))),
    floatingActionButton: FloatingActionButton.extended(onPressed: _editExercise, backgroundColor: AppColors.green, foregroundColor: Colors.black, icon: const Icon(Icons.add), label: const Text('ADD EXERCISE')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final exercises = snapshot.data!;
        if (exercises.isEmpty) return Center(child: Text('Your library is empty. Add your first exercise.', style: GoogleFonts.inter(color: AppColors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final item = exercises[index];
            return Card(
              color: AppColors.card,
              child: ListTile(
                title: Text(item['name'] as String, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('${item['muscle_group'] ?? 'Other'} • ${item['equipment'] ?? 'Equipment not set'}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                onTap: () => _editExercise(item),
                trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.grey), onPressed: () async {
                  await AppDatabase.instance.deleteExercise(item['id'] as int);
                  if (mounted) setState(_reload);
                }),
              ),
            );
          },
        );
      },
    ),
  );
}
