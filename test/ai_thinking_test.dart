import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/ui.dart';

void main() {
  Widget indicator({bool reducedMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: const Scaffold(body: AiThinkingIndicator()),
    ),
  );

  testWidgets('bot dots animate and dispose cleanly', (tester) async {
    await tester.pumpWidget(indicator());
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('AI đang xử lý'), findsOneWidget);
    final dots = find.descendant(
      of: find.byType(AiThinkingIndicator),
      matching: find.byType(Transform),
    );
    expect(dots, findsNWidgets(4));
    final initial = tester.widget<Transform>(dots.first).transform.clone();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Transform>(dots.first).transform, isNot(initial));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stops dots, including after settings change', (
    tester,
  ) async {
    await tester.pumpWidget(indicator());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(indicator(reducedMotion: true));
    await tester.pumpAndSettle();
    final dots = find.descendant(
      of: find.byType(AiThinkingIndicator),
      matching: find.byType(Transform),
    );
    for (final dot in tester.widgetList<Transform>(dots)) {
      expect(dot.transform.getTranslation().y, 0);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(indicator());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
