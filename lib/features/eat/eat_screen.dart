import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class EatScreen extends StatefulWidget {
  const EatScreen({super.key});
  @override
  State<EatScreen> createState() => EatScreenState();
}

class EatScreenState extends State<EatScreen> {
  late String _date;
  late final DateTime _today;
  bool _isLoading = true;
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
    _today = DateTime(now.year, now.month, now.day);
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
      firstDate: _today.subtract(const Duration(days: 30)),
      lastDate: _today,
      helpText: 'SELECT FOOD LOG DATE',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    await _loadData();
  }

  Future<void> refreshEatScreen() => _loadData();

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      final rows = await db.getFoodLogsForDate(_date);
      final targets = await db.getNutritionTargets();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LoggedFood> get all => meals.values.expand((e) => e).toList();
  double get kcal => all.fold(0, (s, f) => s + f.kcal);
  double get protein => all.fold(0, (s, f) => s + f.protein);
  double get carbs => all.fold(0, (s, f) => s + f.carbs);
  double get fat => all.fold(0, (s, f) => s + f.fat);

  Future<void> addFood(String meal) async {
    if (!_canEditSelectedDate) return;
    final result = await showModalBottomSheet<LoggedFood>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => FoodPickerSheet(meal: meal),
    );
    if (result != null && mounted) {
      final id = await AppDatabase.instance.insertFoodLog(
        date: _date,
        meal: meal,
        name: result.name,
        foodId: result.foodId,
        grams: result.grams,
        calories: result.kcal,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
      );
      if (!mounted) return;
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
          : SafeArea(child: SingleChildScrollView(
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
            Text('${_selectedDay == _today ? 'TODAY’S MEALS' : 'MEALS • ${_formatDate(_selectedDay)}'}', style: GoogleFonts.inter(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
      )),
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
        Expanded(child: _MacroItem(label: 'PROTEIN', value: protein, target: proteinTarget, color: AppColors.red)),
        Expanded(child: _MacroItem(label: 'CARBS', value: carbs, target: carbsTarget, color: AppColors.green)),
        Expanded(child: _MacroItem(label: 'FATS', value: fat, target: fatTarget, color: const Color(0xFFE8B45B))),
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
    onPressed: () => addFood(meal),
    style: TextButton.styleFrom(foregroundColor: AppColors.green, padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
    icon: const Icon(Icons.add, size: 16),
    label: Text('ADD FOOD', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
  );
}

class _MacroItem extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;
  const _MacroItem({required this.label, required this.value, required this.target, required this.color});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 28, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(height: 10),
    Text(label, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .5)),
    const SizedBox(height: 5),
    Text('${value.round()} g', style: GoogleFonts.inter(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
    Text('of ${target.round()} g', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
  ]);
}

class FoodData {
  final int? id;
  final String name;
  final double kcal, protein, carbs, fat;
  final bool isCustom;
  const FoodData(this.name, this.kcal, this.protein, this.carbs, this.fat,
      {this.id, this.isCustom = false});
}

class LoggedFood {
  final int? id;
  final int? foodId;
  final String name;
  final double grams, kcal, protein, carbs, fat;
  const LoggedFood(this.name, this.grams, this.kcal, this.protein, this.carbs, this.fat,
      {this.id, this.foodId});

  LoggedFood copyWith({int? id}) => LoggedFood(
    name, grams, kcal, protein, carbs, fat, id: id ?? this.id, foodId: foodId,
  );
}

const fallbackFoods = <FoodData>[
  FoodData('Chicken breast, raw', 120, 22.5, 0, 2.6),
  FoodData('Egg, whole', 143, 12.6, .7, 9.5),
  FoodData('Paneer', 265, 18.3, 1.2, 20.8),
  FoodData('Cooked white rice', 130, 2.7, 28.2, .3),
  FoodData('Roti, whole wheat', 297, 9.8, 55.9, 3.7),
  FoodData('Oats, dry', 389, 16.9, 66.3, 6.9),
  FoodData('Banana', 89, 1.1, 22.8, .3),
  FoodData('Apple', 52, .3, 13.8, .2),
  FoodData('Plain curd', 61, 3.5, 4.7, 3.3),
  FoodData('Milk, toned', 60, 3, 4.8, 3),
  FoodData('Almonds', 579, 21.2, 21.6, 49.9),
  FoodData('Boiled potato', 87, 1.9, 20.1, .1),
  FoodData('Moong dal, cooked', 105, 7, 19.2, .4),
  FoodData('Besan', 387, 22.4, 57.8, 6.7),
];

class FoodPickerSheet extends StatefulWidget {
  final String meal;
  const FoodPickerSheet({super.key, required this.meal});
  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet> {
  final search = TextEditingController();
  final grams = TextEditingController(text: '100');
  final name = TextEditingController();
  final kcal = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();
  FoodData? selected;
  bool custom = false;
  bool _loadingCustomFoods = true;
  List<FoodData> _customFoods = [];
  List<FoodData> _catalogueFoods = [];

  @override
  void initState() {
    super.initState();
    _loadCustomFoods();
  }

  Future<void> _loadCustomFoods() async {
    try {
      final builtInRows = await AppDatabase.instance.getBuiltInFoods();
      final customRows = await AppDatabase.instance.getCustomFoods();
      if (!mounted) return;
      setState(() {
        _catalogueFoods = builtInRows.map((row) => FoodData(
          row['name'] as String,
          (row['calories_per_basis'] as num).toDouble(),
          (row['protein_per_basis_g'] as num).toDouble(),
          (row['carbs_per_basis_g'] as num).toDouble(),
          (row['fat_per_basis_g'] as num).toDouble(),
          id: row['id'] as int,
        )).toList();
        _customFoods = customRows.map((row) => FoodData(
          row['name'] as String,
          (row['calories_per_basis'] as num).toDouble(),
          (row['protein_per_basis_g'] as num).toDouble(),
          (row['carbs_per_basis_g'] as num).toDouble(),
          (row['fat_per_basis_g'] as num).toDouble(),
          id: row['id'] as int,
          isCustom: true,
        )).toList();
        _loadingCustomFoods = false;
      });
    } catch (error) {
      debugPrint('Could not load saved custom foods: $error');
      if (mounted) setState(() => _loadingCustomFoods = false);
    }
  }

  @override
  void dispose() {
    search.dispose(); grams.dispose(); name.dispose(); kcal.dispose();
    protein.dispose(); carbs.dispose(); fat.dispose();
    super.dispose();
  }

  double _parseNumber(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  InputDecoration decoration(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.grey, fontSize: 11),
    filled: true, fillColor: AppColors.card, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.green)),
  );

  Future<void> save() async {
    final amount = _parseNumber(grams);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a quantity greater than zero.')));
      return;
    }
    if (custom && name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a food name.')));
      return;
    }
    if (!custom && selected == null) return;

    var food = selected;
    if (custom) {
      final foodName = name.text.trim();
      final values = [_parseNumber(kcal), _parseNumber(protein), _parseNumber(carbs), _parseNumber(fat)];
      if (values.any((value) => value < 0) || kcal.text.trim().isEmpty ||
          protein.text.trim().isEmpty || carbs.text.trim().isEmpty ||
          fat.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid non-negative nutrition values.')),
        );
        return;
      }
      try {
        final foodId = await AppDatabase.instance.insertCustomFood(
          name: foodName,
          caloriesPer100g: values[0],
          proteinPer100g: values[1],
          carbsPer100g: values[2],
          fatPer100g: values[3],
        );
        food = FoodData(foodName, values[0], values[1], values[2], values[3],
            id: foodId, isCustom: true);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save custom food: $error')),
          );
        }
        return;
      }
    }

    final f = food!;
    final scale = amount / 100;
    if (mounted) {
      Navigator.pop(context, LoggedFood(
        f.name, amount, f.kcal * scale, f.protein * scale,
        f.carbs * scale, f.fat * scale, foodId: f.id,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFoods = [
      ...(_catalogueFoods.isNotEmpty ? _catalogueFoods : fallbackFoods),
      ..._customFoods,
    ];
    final list = allFoods.where((f) => f.name.toLowerCase().contains(search.text.toLowerCase().trim())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * .86,
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.grey, borderRadius: BorderRadius.circular(4))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 12), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ADD TO ${widget.meal}', style: GoogleFonts.inter(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 5),
              Text(custom ? 'Create custom food' : 'Find a food', style: GoogleFonts.inter(color: AppColors.white, fontSize: 21, fontWeight: FontWeight.w800)),
            ])),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.grey)),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
            Expanded(child: _mode('FOOD CATALOGUE', !custom, () => setState(() { custom = false; selected = null; }))),
            const SizedBox(width: 8),
            Expanded(child: _mode('CUSTOM FOOD', custom, () => setState(() { custom = true; selected = null; }))),
          ])),
          const SizedBox(height: 12),
          Expanded(child: custom ? _customForm() : _catalogue(list)),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('QUANTITY', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .8)),
                const SizedBox(height: 5),
                SizedBox(height: 44, child: TextField(controller: grams, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.inter(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700), decoration: decoration('Grams (g)'))),
              ])),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: SizedBox(height: 44, child: ElevatedButton(
                onPressed: custom || selected != null ? save : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.black, disabledBackgroundColor: AppColors.surface, disabledForegroundColor: AppColors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text('ADD TO MEAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)),
              ))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _mode(String label, bool active, VoidCallback tap) => InkWell(
    onTap: tap, borderRadius: BorderRadius.circular(8),
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? AppColors.red.withValues(alpha: .12) : AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? AppColors.red : AppColors.border)),
      child: Text(label, style: GoogleFonts.inter(color: active ? AppColors.white : AppColors.grey, fontSize: 9, fontWeight: FontWeight.w800))),
  );

  Widget _catalogue(List<FoodData> list) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 10), child: TextField(
      controller: search, onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(color: AppColors.white, fontSize: 13),
      decoration: decoration('Search foods').copyWith(prefixIcon: const Icon(Icons.search, color: AppColors.grey)),
    )),
    if (_loadingCustomFoods)
      const LinearProgressIndicator(minHeight: 2, color: AppColors.green, backgroundColor: AppColors.surface),
    Expanded(child: list.isEmpty
      ? Center(child: Text('No matching foods. Try another search or add a custom food.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12)))
      : ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
        itemBuilder: (_, i) {
          final f = list[i]; final active = selected?.name == f.name;
          return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 2),
            title: Text(f.name, style: GoogleFonts.inter(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            subtitle: Text('${f.isCustom ? 'MY FOOD • ' : ''}${f.kcal.round()} kcal • P ${f.protein}g C ${f.carbs}g F ${f.fat}g per 100 g', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9)),
            trailing: Icon(active ? Icons.check_circle : Icons.add_circle_outline, color: active ? AppColors.green : AppColors.grey),
            onTap: () => setState(() {
              final isSameFood = selected?.id != null && f.id != null
                  ? selected!.id == f.id
                  : selected == f;
              selected = isSameFood ? null : f;
            }),
          );
        },
      )),
  ]);

  Widget _customForm() => ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), children: [
    _field(name, 'Food name', true),
    const SizedBox(height: 10),
    Text('NUTRITION PER 100 GRAMS', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8)),
    const SizedBox(height: 10),
    Row(children: [Expanded(child: _field(kcal, 'Calories (kcal)')), const SizedBox(width: 8), Expanded(child: _field(protein, 'Protein (g)'))]),
    const SizedBox(height: 10),
    Row(children: [Expanded(child: _field(carbs, 'Carbs (g)')), const SizedBox(width: 8), Expanded(child: _field(fat, 'Fat (g)'))]),
    const SizedBox(height: 8),
    Text('Enter the nutrition values shown on the food label, per 100 g.', style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10)),
  ]);

  Widget _field(TextEditingController c, String hint, [bool text = false]) => TextField(
    controller: c, keyboardType: text ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
    style: GoogleFonts.inter(color: AppColors.white, fontSize: 12), decoration: decoration(hint),
  );
}
