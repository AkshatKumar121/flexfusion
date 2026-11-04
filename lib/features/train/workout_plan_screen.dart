import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'workout_session_screen.dart';
import 'widgets/plan_day_card.dart';

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

  void _reload() { _plansFuture = AppDatabase.instance.getWorkoutPlans(); }

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

  void _reload() { _daysFuture = AppDatabase.instance.getWorkoutPlanDays(widget.plan['id'] as int); }

  Future<void> _refresh() async {
    setState(_reload);
    await _daysFuture;
  }

  Future<void> _startDay(Map<String, Object?> day) async {
    final active = await AppDatabase.instance.getInProgressWorkout();
    if (!mounted) return;
    if (active != null) {
      await Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => WorkoutSessionScreen(
          workoutId: active['id'] as int,
          title: active['session_name'] as String,
        ),
      ));
      if (mounted) await _refresh();
      return;
    }

    final id = await AppDatabase.instance.startWorkoutSession(
      planId: widget.plan['id'] as int,
      planDayId: day['id'] as int,
      sessionName: day['label'] as String,
    );
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => WorkoutSessionScreen(workoutId: id, title: day['label'] as String),
    ));
    if (mounted) await _refresh();
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
        DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Schedule'), items: const [DropdownMenuItem(value: 'sequence', child: Text('Sequence based')), DropdownMenuItem(value: 'weekday', child: Text('Fixed weekday'))], onChanged: (v) => setDialog(() => type = v ?? 'sequence')),
        if (type == 'weekday') DropdownButtonFormField<int>(initialValue: weekday, decoration: const InputDecoration(labelText: 'Weekday'), items: const [DropdownMenuItem(value: 1, child: Text('Monday')), DropdownMenuItem(value: 2, child: Text('Tuesday')), DropdownMenuItem(value: 3, child: Text('Wednesday')), DropdownMenuItem(value: 4, child: Text('Thursday')), DropdownMenuItem(value: 5, child: Text('Friday')), DropdownMenuItem(value: 6, child: Text('Saturday')), DropdownMenuItem(value: 7, child: Text('Sunday'))], onChanged: (v) => setDialog(() => weekday = v ?? 1)),
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
            initialValue: scheduleType,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'Schedule'),
            items: const [DropdownMenuItem(value: 'sequence', child: Text('Sequence based')), DropdownMenuItem(value: 'weekday', child: Text('Fixed weekday'))],
            onChanged: (v) => setDialogState(() => scheduleType = v ?? 'sequence'),
          ),
          if (scheduleType == 'weekday') DropdownButtonFormField<int>(
            initialValue: weekday,
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
      builder: (context) {
        var searchQuery = '';
        return StatefulBuilder(builder: (context, setSheetState) {
          final query = searchQuery.trim().toLowerCase();
          final filteredExercises = exercises.where((exercise) {
            if (query.isEmpty) return true;
            return [
              exercise['name'],
              exercise['muscle_group'],
              exercise['equipment'],
              exercise['instructions'],
            ].any((value) => (value?.toString() ?? '').toLowerCase().contains(query));
          }).toList();

          return SafeArea(child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Text('Choose exercise', style: GoogleFonts.inter(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: false,
                  onChanged: (value) => setSheetState(() => searchQuery = value),
                  style: GoogleFonts.inter(color: AppColors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search exercises, muscle groups, equipment...',
                    hintStyle: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                    suffixIcon: searchQuery.isEmpty ? null : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, color: AppColors.grey),
                      onPressed: () => setSheetState(() => searchQuery = ''),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.green)),
                  ),
                ),
              ),
              Expanded(
                child: exercises.isEmpty
                    ? Center(child: Text('Add exercises in Exercise Library first.', style: GoogleFonts.inter(color: AppColors.grey)))
                    : filteredExercises.isEmpty
                        ? Center(child: Text('No exercises match "$searchQuery".', style: GoogleFonts.inter(color: AppColors.grey)))
                        : ListView.builder(
                            itemCount: filteredExercises.length,
                            itemBuilder: (_, i) {
                              final exercise = filteredExercises[i];
                              return ListTile(
                                title: Text(exercise['name'] as String, style: GoogleFonts.inter(color: AppColors.white)),
                                subtitle: Text('${exercise['muscle_group'] ?? 'Other'} • ${exercise['equipment'] ?? 'Equipment not set'}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                                onTap: () => Navigator.pop(context, exercise),
                              );
                            },
                          ),
              ),
            ]),
          ));
        });
      },
    );
    if (selected == null || !mounted) return;
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');
    final weightController = TextEditingController();
    final restController = TextEditingController(text: '90');
    var useCustomRestTime = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Set targets', style: GoogleFonts.inter(color: AppColors.white)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${selected['name']}', style: GoogleFonts.inter(color: AppColors.green)),
            TextField(controller: setsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of sets')),
            TextField(controller: repsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target reps per set')),
            TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target weight in kg (optional)')),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: useCustomRestTime,
              onChanged: (value) => setDialogState(() => useCustomRestTime = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Set a custom rest time'),
              subtitle: const Text('Otherwise, the default 90 seconds will be used.'),
            ),
            if (useCustomRestTime)
              TextField(
                controller: restController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rest duration',
                  suffixText: 'seconds',
                  helperText: 'Enter a value from 1 to 3600 seconds',
                ),
              ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ADD')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      final setCount = int.tryParse(setsController.text) ?? 3;
      final reps = int.tryParse(repsController.text) ?? 10;
      final rest = useCustomRestTime ? int.tryParse(restController.text) : 90;
      final weight = double.tryParse(weightController.text);
      if (setCount > 0 && setCount <= 20 && reps > 0 && reps <= 100 &&
          rest != null && rest >= 1 && rest <= 3600 &&
          (weight == null || weight >= 0)) {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your set, rep, weight and rest-time values. Rest time must be 1–3600 seconds.')),
        );
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
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            onReorderItem: (oldIndex, newIndex) async {
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
              return PlanDayCard(
                key: ValueKey(day['id']),
                day: day,
                index: index,
                onAddExercise: () => _addExercise(day['id'] as int),
                onEdit: () => _editDay(day),
                onStart: () => _startDay(day),
                onDelete: () async { await AppDatabase.instance.deleteWorkoutPlanDay(day['id'] as int); await _refresh(); },
              );
            },
          );
        },
      ),
    );
  }
}
