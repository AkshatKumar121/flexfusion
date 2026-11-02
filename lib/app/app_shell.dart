
import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import '../features/home/home_screen.dart';
import '../features/eat/eat_screen.dart';
import '../features/train/train_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 1;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final GlobalKey<EatScreenState> _eatScreenKey = GlobalKey<EatScreenState>();
  final GlobalKey<TrainScreenState> _trainScreenKey = GlobalKey<TrainScreenState>();

  late final List<Widget> _screens = [
    TrainScreen(key: _trainScreenKey),
    HomeScreen(key: _homeScreenKey),
    EatScreen(key: _eatScreenKey),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(
              color: AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 65,
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.fitness_center,
                  label: 'TRAIN',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.home_filled,
                  label: 'HOME',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.restaurant,
                  label: 'EAT',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            _trainScreenKey.currentState?.refreshTrainScreen();
          } else if (index == 1) {
            _homeScreenKey.currentState?.refreshDashboard();
          } else if (index == 2) {
            _eatScreenKey.currentState?.refreshEatScreen();
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.red : AppColors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.red : AppColors.grey,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
