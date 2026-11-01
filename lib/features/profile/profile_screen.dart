import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _fitnessGoal;

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings screen is coming next'),
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
                  'Akshat Kumar',
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
            onPressed: () => _showComingSoon('Edit profile'),
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
            onEdit: () => _showComingSoon('Personal details'),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: _DetailTile(
                  icon: Icons.cake_outlined,
                  label: 'AGE',
                  value: 'Not set',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _DetailTile(
                  icon: Icons.height,
                  label: 'HEIGHT',
                  value: 'Not set',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _DetailTile(
                  icon: Icons.monitor_weight_outlined,
                  label: 'WEIGHT',
                  value: 'Not set',
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
          const _SectionHeading(
            icon: Icons.track_changes,
            title: 'FITNESS GOAL',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _GoalOption(
                title: 'Fat Loss',
                icon: Icons.local_fire_department_outlined,
                selected: _fitnessGoal == 'Fat Loss',
                onTap: () => setState(() => _fitnessGoal = 'Fat Loss'),
              ),
              const SizedBox(width: 9),
              _GoalOption(
                title: 'Muscle Gain',
                icon: Icons.fitness_center,
                selected: _fitnessGoal == 'Muscle Gain',
                onTap: () => setState(() => _fitnessGoal = 'Muscle Gain'),
              ),
              const SizedBox(width: 9),
              _GoalOption(
                title: 'Recomposition',
                icon: Icons.autorenew,
                selected: _fitnessGoal == 'Recomposition',
                onTap: () => setState(() => _fitnessGoal = 'Recomposition'),
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
            onEdit: () => _showComingSoon('Daily targets'),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  'Not set',
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
          const Row(
            children: [
              Expanded(
                child: _MacroTarget(
                  color: AppColors.red,
                  amount: '—',
                  label: 'Protein',
                ),
              ),
              Expanded(
                child: _MacroTarget(
                  color: AppColors.green,
                  amount: '—',
                  label: 'Carbs',
                ),
              ),
              Expanded(
                child: _MacroTarget(
                  color: Color(0xFFE8BD3D),
                  amount: '—',
                  label: 'Fats',
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    final color = selected ? AppColors.red : AppColors.border;

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
