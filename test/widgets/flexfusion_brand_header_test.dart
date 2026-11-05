import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flexfusion/shared/widgets/flexfusion_brand_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('brand header renders trainer label and supplied action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlexFusionBrandHeader(
            trailingAction: IconButton(
              tooltip: 'Profile',
              onPressed: () {},
              icon: const Icon(Icons.person_outline),
            ),
          ),
        ),
      ),
    );

    expect(find.text('TRAINER'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
