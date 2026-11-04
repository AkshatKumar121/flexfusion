import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';

class MacroItem extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;
  const MacroItem({required this.label, required this.value, required this.target, required this.color});
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
