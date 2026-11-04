import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'models/food_models.dart';

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
