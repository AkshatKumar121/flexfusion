import 'package:flutter/material.dart';
import '../../app/auto_refresh_on_return.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> with AutoRefreshOnReturn<ExerciseLibraryScreen> {
  @override
  Future<void> refreshAfterReturn() async {
    if (!mounted) return;
    setState(_reload);
    await _future;
  }

  late Future<List<Map<String, Object?>>> _future;
  String _searchQuery = '';
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _future = AppDatabase.instance.getExercises(); }

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
        final query = _searchQuery.trim().toLowerCase();
        final filteredExercises = exercises.where((item) {
          if (query.isEmpty) return true;
          return [
            item['name'],
            item['muscle_group'],
            item['equipment'],
            item['instructions'],
          ].any((value) => (value?.toString() ?? '').toLowerCase().contains(query));
        }).toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: GoogleFonts.inter(color: AppColors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search exercises, muscle groups, equipment...',
                hintStyle: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, color: AppColors.grey),
                        onPressed: () => setState(() => _searchQuery = ''),
                      ),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.green)),
              ),
            ),
          ),
          Expanded(
            child: filteredExercises.isEmpty
                ? Center(child: Text('No exercises match "$_searchQuery".', style: GoogleFonts.inter(color: AppColors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filteredExercises.length,
                    itemBuilder: (context, index) {
                      final item = filteredExercises[index];
                      return Card(
                        color: AppColors.card,
                        child: ListTile(
                          title: Text(item['name'] as String, style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['muscle_group'] ?? 'Other'} • ${item['equipment'] ?? 'Equipment not set'}', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11)),
                          onTap: () => _editExercise(item),
                          trailing: (item['is_custom'] as int? ?? 0) == 1
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.grey),
                                  tooltip: 'Delete custom exercise',
                                  onPressed: () async {
                                    await AppDatabase.instance.deleteExercise(item['id'] as int);
                                    if (mounted) setState(_reload);
                                  },
                                )
                              : const Tooltip(
                                  message: 'Built-in exercise',
                                  child: Icon(Icons.lock_outline, color: AppColors.grey, size: 18),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
    ),
  );
}
