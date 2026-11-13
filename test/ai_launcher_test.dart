import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/ui.dart';

void main() {
  double hintOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byKey(const ValueKey('ai-hint')))
      .opacity;

  testWidgets('small bot greets, fades, then shows a different timed hint', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: AiChatLauncher(onPressed: () => opens++),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FloatingActionButton)).width, 68);
    expect(hintOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 800));
    expect(hintOpacity(tester), 1);
    expect(find.text('Hỏi AI nhé!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 160));
    final fade = find.descendant(
      of: find.byKey(const ValueKey('ai-hint')),
      matching: find.byType(FadeTransition),
    );
    final progress = tester.widget<FadeTransition>(fade).opacity.value;
    expect(progress, greaterThan(0));
    expect(progress, lessThan(1));
    await tester.pump(const Duration(seconds: 5));
    expect(hintOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 320));
    for (var second = 0; second < 46 && hintOpacity(tester) == 0; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(hintOpacity(tester), 1);
    expect(find.text('Hỏi AI nhé!'), findsNothing);
    await tester.tap(find.byType(FloatingActionButton));
    expect(opens, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background stops hints and reduced motion removes transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            floatingActionButton: AiChatLauncher(onPressed: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(hintOpacity(tester), 1);
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('ai-hint')))
          .duration,
      Duration.zero,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    // Paused apps do not render another frame until resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(hintOpacity(tester), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
