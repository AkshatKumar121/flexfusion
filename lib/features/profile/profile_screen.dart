import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _fitnessGoal;
  Map<String, Object?>? _profile;
  Map<String, Object?>? _targets;
  double? _weight;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final db = AppDatabase.instance;
    final profile = await db.getUserProfile();
    final targets = await db.getNutritionTargets();
    final weight = await db.getLatestBodyWeight();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _targets = targets;
      _weight = (weight?['weight_value'] as num?)?.toDouble();
      _fitnessGoal = profile?['current_goal'] as String?;
      _isLoading = false;
    });
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _profile?['display_name'] as String? ?? '');
    final age = TextEditingController(text: (_profile?['age'] ?? '').toString() == 'null' ? '' : (_profile?['age'] ?? '').toString());
    final height = TextEditingController(text: (_profile?['height_value'] ?? '').toString() == 'null' ? '' : (_profile?['height_value'] ?? '').toString());
    final weight = TextEditingController(text: _weight?.toString() ?? '');
    final calories = TextEditingController(text: (_targets?['calorie_target'] ?? 2200).toString());
    final protein = TextEditingController(text: (_targets?['protein_target_g'] ?? 180).toString());
    final carbs = TextEditingController(text: (_targets?['carbs_target_g'] ?? 190).toString());
    final fat = TextEditingController(text: (_targets?['fat_target_g'] ?? 65).toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Edit profile', style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _editField(name, 'Display name'),
            _editField(age, 'Age (years)', numeric: true),
            _editField(height, 'Height (cm)', numeric: true),
            _editField(weight, 'Current weight (kg)', numeric: true),
            const SizedBox(height: 8),
            _editField(calories, 'Daily calories (kcal)', numeric: true),
            _editField(protein, 'Protein target (g)', numeric: true),
            _editField(carbs, 'Carbs target (g)', numeric: true),
            _editField(fat, 'Fat target (g)', numeric: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.black),
            onPressed: () async {
              final values = [age, height, weight, calories, protein, carbs, fat].map((c) => double.tryParse(c.text.trim())).toList();
              if (name.text.trim().isEmpty || values.any((v) => v == null || v <= 0) || values[0]! > 120 || values[1]! > 250) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid profile values.')));
                return;
              }
              await AppDatabase.instance.saveProfileAndTargets(
                displayName: name.text,
                age: values[0]!.round(),
                heightCm: values[1]!,
                weightKg: values[2]!,
                goal: _fitnessGoal ?? 'Recomposition',
                calories: values[3]!,
                protein: values[4]!,
                carbs: values[5]!,
                fat: values[6]!,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    for (final controller in [name, age, height, weight, calories, protein, carbs, fat]) {
      controller.dispose();
    }
    if (saved == true) await _loadProfile();
  }

  Widget _editField(TextEditingController controller, String label, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.inter(color: AppColors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: AppColors.grey, fontSize: 11),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildPageTabs(),
              const SizedBox(height: 22),
              _buildMemberCard(),
              const SizedBox(height: 16),
              _buildPersonalDetails(),
              const SizedBox(height: 16),
              _buildFitnessGoal(),
              const SizedBox(height: 16),
              _buildDailyTargets(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          tooltip: 'Back',
        ),
        const Spacer(),
        SizedBox(
          width: 112,
          height: 42,
          child: Image.asset(
            'assets/images/fxf_logo.jpg',
            fit: BoxFit.contain,
          ),
        ),
        Container(
          height: 30,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: AppColors.border,
        ),
        Text(
          'TRAINER',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildPageTabs() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'PROFILE',
                      style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Container(height: 2, color: AppColors.red),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              child: Center(
                child: Text(
                  'SETTINGS',
                  style: GoogleFonts.inter(
                    color: AppColors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard() {
    return _ProfileCard(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.grey,
                  size: 48,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_profile?['display_name'] as String?)?.isNotEmpty == true ? _profile!['display_name'] as String : 'Your profile',
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'FlexFusion Member',
                  style: GoogleFonts.inter(
                    color: AppColors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.inter(
                      color: AppColors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined, color: AppColors.grey),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetails() {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.person_outline,
            title: 'PERSONAL DETAILS',
            onEdit: _editProfile,
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: _DetailTile(
                  icon: Icons.cake_outlined,
                  label: 'AGE',
                  value: (_profile?['age'] ?? 'Not set').toString(),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _DetailTile(
                  icon: Icons.height,
                  label: 'HEIGHT',
                  value: _profile?['height_value'] == null ? 'Not set' : '${(_profile!['height_value'] as num).round()} cm',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _DetailTile(
                  icon: Icons.monitor_weight_outlined,
                  label: 'WEIGHT',
                  value: _weight == null ? 'Not set' : '${_weight!.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessGoal() {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.track_changes,
            title: 'FITNESS GOAL',
            onEdit: _editProfile,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _GoalOption(
                title: 'Fat Loss',
                icon: Icons.local_fire_department_outlined,
                selected: _fitnessGoal == 'Fat Loss',
                onTap: () => _saveGoal('Fat Loss'),
              ),
              const SizedBox(width: 9),
              _GoalOption(
                title: 'Muscle Gain',
                icon: Icons.fitness_center,
                selected: _fitnessGoal == 'Muscle Gain',
                onTap: () => _saveGoal('Muscle Gain'),
              ),
              const SizedBox(width: 9),
              _GoalOption(
                title: 'Recomposition',
                icon: Icons.autorenew,
                selected: _fitnessGoal == 'Recomposition',
                onTap: () => _saveGoal('Recomposition'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTargets() {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.bar_chart_rounded,
            title: 'DAILY TARGETS',
            onEdit: _editProfile,
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  (_targets?['calorie_target'] as num?) == null ? 'Not set' : '${(_targets!['calorie_target'] as num).round()} kcal',
                  style: GoogleFonts.inter(
                    color: AppColors.green,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'DAILY CALORIES',
                  style: GoogleFonts.inter(
                    color: AppColors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MacroTarget(
                  color: AppColors.red,
                  amount: (_targets?['protein_target_g'] as num?)?.round().toString() ?? '—',
                  label: 'Protein',
                ),
              ),
              Expanded(
                child: _MacroTarget(
                  color: AppColors.green,
                  amount: (_targets?['carbs_target_g'] as num?)?.round().toString() ?? '—',
                  label: 'Carbs',
                ),
              ),
              Expanded(
                child: _MacroTarget(
                  color: Color(0xFFE8BD3D),
                  amount: (_targets?['fat_target_g'] as num?)?.round().toString() ?? '—',
                  label: 'Fats',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveGoal(String goal) async {
    setState(() => _fitnessGoal = goal);
    final profile = _profile;
    if (profile == null || _weight == null || _targets == null) {
      await _editProfile();
      return;
    }
    await AppDatabase.instance.saveProfileAndTargets(
      displayName: profile['display_name'] as String? ?? '',
      age: (profile['age'] as num).round(),
      heightCm: (profile['height_value'] as num).toDouble(),
      weightKg: _weight!,
      goal: goal,
      calories: (_targets!['calorie_target'] as num).toDouble(),
      protein: (_targets!['protein_target_g'] as num).toDouble(),
      carbs: (_targets!['carbs_target_g'] as num).toDouble(),
      fat: (_targets!['fat_target_g'] as num).toDouble(),
    );
    await _loadProfile();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature editing will be added next')),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Widget child;

  const _ProfileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onEdit;

  const _SectionHeading({
    required this.icon,
    required this.title,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.white, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ),
        if (onEdit != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.grey,
              size: 19,
            ),
            tooltip: 'Edit $title',
          ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.grey, size: 21),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 9),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GoalOption({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 108,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.red.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppColors.red : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? AppColors.red : AppColors.grey),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.red : AppColors.grey,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroTarget extends StatelessWidget {
  final Color color;
  final String amount;
  final String label;

  const _MacroTarget({
    required this.color,
    required this.amount,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                amount,
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
