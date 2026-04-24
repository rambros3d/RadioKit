import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('RKLed renders on state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.neon,
          child: const RKLed(on: true),
        ),
      ),
    );
    expect(find.byType(RKLed), findsOneWidget);
  });

  testWidgets('RKDisplay renders text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.neon,
          child: const RKDisplay(text: 'Hello'),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });
}
