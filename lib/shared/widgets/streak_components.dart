import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';

class StreakSectionLabel extends StatelessWidget {
  final String label;

  const StreakSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.grey,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      );
}

class StreakSummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double valueFontSize;

  const StreakSummaryTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.valueFontSize = 17,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF292929),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppColors.grey,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: AppColors.white,
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class StreakWeekStrip extends StatelessWidget {
  final List<DateTime> week;
  final String todayKey;
  final bool Function(String dayKey) isCompleted;
  final bool markIncompleteToday;

  const StreakWeekStrip({
    super.key,
    required this.week,
    required this.todayKey,
    required this.isCompleted,
    this.markIncompleteToday = false,
  });

  String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(7, (index) {
          final key = _key(week[index]);
          final done = isCompleted(key);
          final isToday = key == todayKey;
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.green
                        : (isToday && markIncompleteToday
                            ? Colors.transparent
                            : const Color(0xFF292929)),
                    border: isToday && !done
                        ? Border.all(color: AppColors.green, width: 2.5)
                        : null,
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Colors.black, size: 27)
                      : (isToday && markIncompleteToday
                          ? const Icon(Icons.circle, color: AppColors.green, size: 8)
                          : null),
                ),
                const SizedBox(height: 8),
                Text(
                  const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index],
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      );
}
