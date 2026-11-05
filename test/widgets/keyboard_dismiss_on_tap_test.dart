import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flexfusion/shared/widgets/keyboard_dismiss_on_tap.dart';

void main() {
  testWidgets('tapping outside the focused field dismisses keyboard focus',
      (tester) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardDismissOnTap(
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Column(
            children: [
              TextField(key: const ValueKey('first-field'), focusNode: firstFocus),
              TextField(key: const ValueKey('second-field'), focusNode: secondFocus),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Outside field'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('first-field')));
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('second-field')));
    await tester.pump();
    expect(firstFocus.hasFocus, isFalse);
    expect(secondFocus.hasFocus, isTrue);

    await tester.tap(find.text('Outside field'));
    await tester.pump();
    expect(secondFocus.hasFocus, isFalse);

    firstFocus.dispose();
    secondFocus.dispose();
  });

  testWidgets('tapping inside the active field keeps it focused', (tester) async {
    final focus = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardDismissOnTap(
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: TextField(
            key: const ValueKey('active-field'),
            focusNode: focus,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('active-field')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('active-field'))));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    focus.dispose();
  });
}
