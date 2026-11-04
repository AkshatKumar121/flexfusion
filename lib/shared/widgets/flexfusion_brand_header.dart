import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';

/// Shared FlexFusion brand header used by the Home and Train tabs.
class FlexFusionBrandHeader extends StatelessWidget {
  final Widget trailingAction;

  const FlexFusionBrandHeader({
    super.key,
    required this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 38,
                    width: 2,
                    color: const Color(0xFF555555),
                  ),
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
            const Spacer(),
            trailingAction,
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 1,
          color: const Color(0xFF292929),
        ),
      ],
    );
  }
}
