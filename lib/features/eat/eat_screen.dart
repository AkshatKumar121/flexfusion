import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'nutrition_streak_screen.dart';
import 'food_picker_sheet.dart';
import 'models/food_models.dart';
import 'widgets/macro_item.dart';

class EatScreen extends StatefulWidget {
  const EatScreen({super.key});
  @override
  State<EatScreen> createState() => EatScreenState();
}

class EatScreenState extends State<EatScreen> {
  late String _date;
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  bool _isLoading = true;
  int _loadGeneration = 0;
  double calorieTarget = 2200;
  double proteinTarget = 180;
  double carbsTarget = 190;
  double fatTarget = 65;

  final Map<String, List<LoggedFood>> meals = {
    'BREAKFAST': [], 'LUNCH': [], 'SNACKS': [], 'DINNER': [],
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadData();
  }

  DateTime get _selectedDay => DateTime.parse(_date);
  bool get _canEditSelectedDate => !_selectedDay.isBefore(_today.subtract(const Duration(days: 30)));

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2000),
      lastDate: _today,
      helpText: 'SELECT FOOD LOG DATE',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    await _loadData();
  }

  Future<void> refreshEatScreen() => _loadData(showLoading: false);

  Future<void> _loadData({bool showLoading = true}) async {
    final requestedDate = _date;
    final generation = ++_loadGeneration;
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      final rows = await db.getFoodLogsForDate(requestedDate);
      final targets = await db.getNutritionTargets();
      // A later date selection or refresh owns the screen now. Never let an
      // older asynchronous read overwrite the currently selected day's data.
      if (!mounted || generation != _loadGeneration || requestedDate != _date) return;
      if (targets != null) {
        calorieTarget = (targets['calorie_target'] as num).toDouble();
        proteinTarget = (targets['protein_target_g'] as num).toDouble();
        carbsTarget = (targets['carbs_target_g'] as num).toDouble();
        fatTarget = (targets['fat_target_g'] as num).toDouble();
      }
      for (final meal in meals.keys) {
        meals[meal] = rows
            .where((row) => row['meal_type'] == meal)
            .map((row) => LoggedFood(
                  row['food_name_snapshot'] as String,
                  (row['quantity_g'] as num).toDouble(),
                  (row['calories'] as num).toDouble(),
                  (row['protein_g'] as num).toDouble(),
                  (row['carbs_g'] as num).toDouble(),
                  (row['fat_g'] as num).toDouble(),
                  id: row['id'] as int,
                ))
            .toList();
      }
    } catch (error) {
      debugPrint('Could not load meal entries from SQLite: $error');
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<LoggedFood> get all => meals.values.expand((e) => e).toList();
  double get kcal => all.fold(0, (s, f) => s + f.kcal);
  double get protein => all.fold(0, (s, f) => s + f.protein);
  double get carbs => all.fold(0, (s, f) => s + f.carbs);
  double get fat => all.fold(0, (s, f) => s + f.fat);

  Future<void> addFood(String meal) async {
    final requestedDate = _date;
    if (!_canEditSelectedDate) return;
    final result = await showModalBottomSheet<LoggedFood>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => FoodPickerSheet(meal: meal),
    );
    if (result != null && mounted) {
      final id = await AppDatabase.instance.insertFoodLog(
        date: requestedDate,
        meal: meal,
        name: result.name,
        foodId: result.foodId,
        grams: result.grams,
        calories: result.kcal,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
      );
      if (!mounted || _date != requestedDate) return;
      setState(() => meals[meal]!.add(result.copyWith(id: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (calorieTarget - kcal).clamp(0, calorieTarget).toDouble();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : SafeArea(child: RefreshIndicator(
        color: AppColors.green,
        backgroundColor: AppColors.card,
        onRefresh: () => _loadData(showLoading: false),
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header(),
          const SizedBox(height: 28),
          Text('YOUR NUTRITION', style: GoogleFonts.inter(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 7),
          Text('Eat well. Get stronger.', style: GoogleFonts.inter(color: AppColors.white, fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Track your food and hit your daily goals.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12)),
          const SizedBox(height: 18),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_month_outlined, color: AppColors.green, size: 19),
                const SizedBox(width: 9),
                Expanded(child: Text(_selectedDay == _today ? 'TODAY • ${_formatDate(_selectedDay)}' : _formatDate(_selectedDay), style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                Text('CHANGE DATE', style: GoogleFonts.inter(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.w800)),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right, color: AppColors.grey, size: 18),
              ]),
            ),
          ),
          if (!_canEditSelectedDate) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('This date is older than 30 days. Entries are available to view but cannot be changed.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
          ),
          const SizedBox(height: 16),
          _calorieCard(remaining),
          const SizedBox(height: 16),
          _macroCard(),
          const SizedBox(height: 26),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_selectedDay == _today ? 'TODAY’S MEALS' : 'MEALS • ${_formatDate(_selectedDay)}', style: GoogleFonts.inter(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${all.length} FOODS LOGGED', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: .6)),
            const SizedBox(height: 5),
            Text(_canEditSelectedDate ? 'EDITING AVAILABLE' : 'VIEW ONLY', style: GoogleFonts.inter(color: _canEditSelectedDate ? AppColors.green : AppColors.grey, fontSize: 8, fontWeight: FontWeight.w700)),
          ]),
          ]),
          const SizedBox(height: 13),
          _mealCard('BREAKFAST', 'Start your day right', Icons.wb_twilight_outlined),
          const SizedBox(height: 12),
          _mealCard('LUNCH', 'Fuel your afternoon', Icons.wb_sunny_outlined),
          const SizedBox(height: 12),
          _mealCard('SNACKS', 'Keep your energy up', Icons.cookie_outlined),
          const SizedBox(height: 12),
          _mealCard('DINNER', 'Finish the day strong', Icons.nights_stay_outlined),
        ]),
      ))),
    );
  }

  Widget _header() => Column(children: [
    Row(children: [
      SizedBox(width: 130, height: 48, child: Image.asset('assets/images/fxf_logo.jpg', fit: BoxFit.contain, alignment: Alignment.centerLeft)),
      Transform.translate(offset: const Offset(-25, 0), child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 38, width: 2, color: const Color(0xFF555555)),
        const SizedBox(width: 13),
        Transform.translate(offset: const Offset(0, 1), child: Text('TRAINER', style: GoogleFonts.inter(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 5))),
      ])),
      const Spacer(),
      IconButton(
        tooltip: 'Workout and activity streak',
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NutritionStreakScreen(),
          ),
        ),
        icon: const Icon(
          Icons.local_fire_department_rounded,
          color: Color(0xFFFF3D70),
          size: 29,
        ),
      ),
    ]),
    const SizedBox(height: 20),
    Container(height: 1, color: const Color(0xFF292929)),
  ]);

  Widget _calorieCard(double remaining) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('CALORIES', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const Icon(Icons.local_fire_department_outlined, color: AppColors.green, size: 21),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(kcal.round().toString(), style: GoogleFonts.inter(color: AppColors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(width: 8),
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('/ ${calorieTarget.round()} kcal', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12))),
        const Spacer(),
        Text('${remaining.round()} LEFT', style: GoogleFonts.inter(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 15),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (kcal / calorieTarget).clamp(0.0, 1.0), minHeight: 7, backgroundColor: AppColors.surface, valueColor: const AlwaysStoppedAnimation(AppColors.green))),
      const SizedBox(height: 12),
      Text('Daily calorie goal', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
    ]),
  );

  Widget _macroCard() => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DAILY MACROS', style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8)),
      const SizedBox(height: 17),
      Row(children: [
        Expanded(child: MacroItem(label: 'PROTEIN', value: protein, target: proteinTarget, color: AppColors.red)),
        Expanded(child: MacroItem(label: 'CARBS', value: carbs, target: carbsTarget, color: AppColors.green)),
        Expanded(child: MacroItem(label: 'FATS', value: fat, target: fatTarget, color: const Color(0xFFE8B45B))),
      ]),
    ]),
  );

  Widget _mealCard(String title, String subtitle, IconData icon) {
    final foods = meals[title]!;
    final mealKcal = foods.fold<double>(0, (s, f) => s + f.kcal);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.green.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.green, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .7)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
          ])),
          Text('${mealKcal.round()} kcal', style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 13),
        Container(height: 1, color: AppColors.border),
        if (foods.isEmpty) ...[
          const SizedBox(height: 11),
          Row(children: [
            Text('No foods added yet', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
            const Spacer(),
            _addButton(title),
          ]),
        ] else ...[
          ...foods.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.value.name, style: GoogleFonts.inter(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${entry.value.grams.round()} g • P ${entry.value.protein.round()}g • C ${entry.value.carbs.round()}g • F ${entry.value.fat.round()}g', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9)),
              ])),
              Text('${entry.value.kcal.round()} kcal', style: GoogleFonts.inter(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              if (_canEditSelectedDate) IconButton(
                onPressed: () => _editFood(entry.value),
                icon: const Icon(Icons.edit_outlined, color: AppColors.green, size: 16),
                tooltip: 'Edit quantity',
                visualDensity: VisualDensity.compact,
              ),
              if (_canEditSelectedDate) IconButton(
                onPressed: () async {
                  final food = entry.value;
                  if (food.id != null) {
                    await AppDatabase.instance.deleteFoodLog(food.id!);
                  }
                  if (mounted) {
                    setState(() => meals[title]!.removeAt(entry.key));
                  }
                },
                icon: const Icon(Icons.close, color: AppColors.grey, size: 16),
                tooltip: 'Remove food',
                visualDensity: VisualDensity.compact,
              ),
            ]),
          )),
          Align(alignment: Alignment.centerRight, child: _addButton(title)),
        ],
      ]),
    );
  }

  Future<void> _editFood(LoggedFood food) async {
    if (!_canEditSelectedDate || food.id == null) return;
    final controller = TextEditingController(text: food.grams.toStringAsFixed(0));
    final grams = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Edit ${food.name}', style: const TextStyle(color: AppColors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(labelText: 'Quantity (g)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(dialogContext, value != null && value > 0 ? value : null);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (grams == null || !mounted) return;
    final ratio = grams / food.grams;
    await AppDatabase.instance.updateFoodLog(
      id: food.id!,
      grams: grams,
      calories: food.kcal * ratio,
      protein: food.protein * ratio,
      carbs: food.carbs * ratio,
      fat: food.fat * ratio,
    );
    if (mounted) await _loadData();
  }

  Widget _addButton(String meal) => TextButton.icon(
    onPressed: _canEditSelectedDate ? () => addFood(meal) : null,
    style: TextButton.styleFrom(foregroundColor: AppColors.green, padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
    icon: const Icon(Icons.add, size: 16),
    label: Text('ADD FOOD', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
  );
}
