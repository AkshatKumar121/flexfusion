import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _weightUnit = 'kg';
  String _heightUnit = 'cm';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = AppDatabase.instance;
    final values = await Future.wait([
      db.getAppSetting('weight_unit', defaultValue: 'kg'),
      db.getAppSetting('height_unit', defaultValue: 'cm'),
    ]);
    if (!mounted) return;
    setState(() {
      _weightUnit = values[0];
      _heightUnit = values[1];
      _isLoading = false;
    });
  }

  Future<void> _changeUnit(String key, String value) async {
    final previousValue = key == 'weight_unit' ? _weightUnit : _heightUnit;
    setState(() {
      if (key == 'weight_unit') _weightUnit = value;
      if (key == 'height_unit') _heightUnit = value;
    });
    try {
      await AppDatabase.instance.saveAppSetting(key, value);
    } catch (error) {
      debugPrint('Could not save $key: $error');
      if (!mounted) return;
      setState(() {
        if (key == 'weight_unit') _weightUnit = previousValue;
        if (key == 'height_unit') _heightUnit = previousValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this setting. Please try again.')),
      );
    }
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
              _buildTabs(),
              const SizedBox(height: 22),
              _buildUnitsCard(),
              const SizedBox(height: 16),
              _buildPreferencesCard(),
              const SizedBox(height: 16),
              _buildDataCard(),
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

  Widget _buildTabs() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: Text(
                  'PROFILE',
                  style: GoogleFonts.inter(
                    color: AppColors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'SETTINGS',
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
        ],
      ),
    );
  }

  Widget _buildUnitsCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsHeading(
            icon: Icons.straighten,
            title: 'UNITS & MEASUREMENTS',
          ),
          const SizedBox(height: 12),
          _UnitRow(
            label: 'Weight Unit',
            options: const ['kg', 'lb'],
            value: _weightUnit,
            onChanged: (value) => _changeUnit('weight_unit', value),
          ),
          _UnitRow(
            label: 'Height Unit',
            options: const ['cm', 'ft/in'],
            value: _heightUnit,
            onChanged: (value) => _changeUnit('height_unit', value),
          ),
          _UnitRow(
            label: 'Energy Unit',
            options: const ['kcal'],
            value: 'kcal',
            onChanged: (_) {},
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsHeading(
            icon: Icons.settings_outlined,
            title: 'APP PREFERENCES',
          ),
          const SizedBox(height: 8),
          _SettingsInfoRow(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            trailing: Text(
              'Dark',
              style: GoogleFonts.inter(
                color: AppColors.grey,
                fontSize: 12,
              ),
            ),
          ),
          _SettingsInfoRow(
            icon: Icons.notifications_none,
            title: 'Reminders',
            trailing: _comingSoonLabel(),
          ),
          _SettingsInfoRow(
            icon: Icons.event_available_outlined,
            title: 'End of Day Check-in',
            trailing: _comingSoonLabel(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _comingSoonLabel() {
    return Text(
      'COMING SOON',
      style: GoogleFonts.inter(
        color: AppColors.grey,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _buildDataCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsHeading(
            icon: Icons.storage_outlined,
            title: 'DATA MANAGEMENT',
          ),
          const SizedBox(height: 8),
          _SettingsActionRow(
            icon: Icons.file_upload_outlined,
            title: 'Export Data',
            subtitle: 'Download your data (CSV)',
            onTap: () => _showNotReady('Data export'),
          ),
          _SettingsActionRow(
            icon: Icons.cloud_download_outlined,
            title: 'Restore Data',
            subtitle: 'Restore from a previously exported file',
            onTap: () => _showNotReady('Data restore'),
          ),
          // Reset is intentionally hidden until a complete, tested reset
          // flow can remove database records and local progress-photo files safely.
        ],
      ),
    );
  }

  void _showNotReady(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature will be implemented in a later step')),
    );
  }

}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

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

class _SettingsHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SettingsHeading({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.white, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _UnitRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool showDivider;

  const _UnitRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: options.map((option) {
                final selected = option == value;
                return GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 58),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.red : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsRowBase(
      icon: icon,
      title: title,
      trailing: trailing,
    );
  }
}

class _SettingsRowBase extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsRowBase({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.grey, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 23),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
