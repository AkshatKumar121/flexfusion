import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flexfusion/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core app navigation and dashboard destinations work', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // The app opens on Home and exposes exactly the three primary tabs.
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('TRAIN'), findsOneWidget);
    expect(find.text('EAT'), findsOneWidget);

    // Eat tab loads its diary and the user can return to Home.
    await tester.tap(find.text('EAT'));
    await tester.pumpAndSettle();
    expect(find.text('ADD FOOD'), findsOneWidget);
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();

    // Train tab loads independently and navigation remains responsive.
    await tester.tap(find.text('TRAIN'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR TRAINING SPACE'), findsOneWidget);
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();

    // Workout analysis opens from the Home dashboard and supports Back.
    await tester.scrollUntilVisible(
      find.text('WORKOUT ANALYSIS'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('WORKOUT ANALYSIS').last);
    await tester.pumpAndSettle();
    expect(find.text('WORKOUT ANALYSIS'), findsWidgets);
    expect(find.text('TODAY'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Activity opens from the dashboard and returns to the same app shell.
    await tester.scrollUntilVisible(
      find.text('LOG ACTIVITY'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('LOG ACTIVITY'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIVITY'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
