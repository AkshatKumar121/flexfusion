import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';

class EatScreen extends StatelessWidget {
  const EatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              Text(
                'YOUR NUTRITION',
                style: GoogleFonts.inter(
                  color: AppColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Eat well. Get stronger.',
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Track your food and hit your daily goals.',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
              ),
              const SizedBox(height: 22),
              _buildCaloriesCard(),
              const SizedBox(height: 16),
              _buildMacrosCard(),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TODAY’S MEALS',
                    style: GoogleFonts.inter(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '0 FOODS LOGGED',
                    style: GoogleFonts.inter(
                      color: AppColors.grey,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _MealCard(
                title: 'BREAKFAST',
                subtitle: 'Start your day right',
                icon: Icons.wb_twilight_outlined,
                calories: '0 kcal',
              ),
              const SizedBox(height: 12),
              _MealCard(
                title: 'LUNCH',
                subtitle: 'Fuel your afternoon',
                icon: Icons.wb_sunny_outlined,
                calories: '0 kcal',
              ),
              const SizedBox(height: 12),
              _MealCard(
                title: 'SNACKS',
                subtitle: 'Keep your energy up',
                icon: Icons.cookie_outlined,
                calories: '0 kcal',
              ),
              const SizedBox(height: 12),
              _MealCard(
                title: 'DINNER',
                subtitle: 'Finish the day strong',
                icon: Icons.nights_stay_outlined,
                calories: '0 kcal',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 130,
              height: 48,
              child: Image.asset(
                'assets/images/fxf_logo.jpg',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
            Transform.translate(
              offset: const Offset(-25, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 38, width: 2, color: const Color(0xFF555555)),
                  const SizedBox(width: 13),
                  Transform.translate(
                    offset: const Offset(0, 1),
                    child: Text(
                      'TRAINER',
                      style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(height: 1, color: const Color(0xFF292929)),
      ],
    );
  }

  Widget _buildCaloriesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CALORIES',
                style: GoogleFonts.inter(
                  color: AppColors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Icon(Icons.local_fire_department_outlined,
                  color: AppColors.green, size: 21),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '0',
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ 2,200 kcal',
                  style: GoogleFonts.inter(color: AppColors.grey, fontSize: 12),
                ),
              ),
              const Spacer(),
              Text(
                '2,200 LEFT',
                style: GoogleFonts.inter(
                  color: AppColors.green,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 7,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Daily calorie goal',
            style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAILY MACROS',
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 17),
          const Row(
            children: [
              Expanded(
                child: _MacroItem(
                  label: 'PROTEIN',
                  consumed: '0 g',
                  target: '180 g',
                  color: AppColors.red,
                ),
              ),
              Expanded(
                child: _MacroItem(
                  label: 'CARBS',
                  consumed: '0 g',
                  target: '190 g',
                  color: AppColors.green,
                ),
              ),
              Expanded(
                child: _MacroItem(
                  label: 'FATS',
                  consumed: '0 g',
                  target: '65 g',
                  color: Color(0xFFE8B45B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroItem extends StatelessWidget {
  final String label;
  final String consumed;
  final String target;
  final Color color;

  const _MacroItem({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.grey,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          consumed,
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'of $target',
          style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String calories;

  const _MealCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.calories,
  });

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Food logging will be added in the next step.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.green, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                calories,
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                'No foods added yet',
                style: GoogleFonts.inter(color: AppColors.grey, fontSize: 10),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showComingSoon(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'ADD FOOD',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
