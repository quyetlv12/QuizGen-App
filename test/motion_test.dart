import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('reduced motion interrupts tab fade and unlocks latest tab', (
    tester,
  ) async {
    var index = 0;
    var reduced = false;
    var taps = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Scaffold(
                body: SmoothTabBody(
                  index: index,
                  children: [
                    const Text('First tab'),
                    TextButton(
                      onPressed: () => taps++,
                      child: const Text('Latest tab'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    update(() => index = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // Only the accessibility preference changes; the selected index stays put.
    update(() => reduced = true);
    await tester.pump();
    await tester.tap(find.text('Latest tab'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion during route push preserves live form state', (
    tester,
  ) async {
    var reduced = false;
    late StateSetter update;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            navigatorKey: nav,
            theme: appTheme().copyWith(platform: TargetPlatform.iOS),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: const Scaffold(body: Text('Root')),
          );
        },
      ),
    );
    openScreen(nav.currentContext!, const _StatefulForm());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before = tester.state(find.byType(_StatefulForm));
    await tester.enterText(find.byType(TextField), 'Nháp chưa lưu');
    update(() => reduced = true);
    await tester.pump();
    expect(tester.state(find.byType(_StatefulForm)), same(before));
    expect(find.text('Nháp chưa lưu'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(_StatefulForm)))!;
    expect(route.animation!.status, AnimationStatus.completed);
    expect(tester.takeException(), isNull);
  });

  for (final phase in ['fade-out', 'fade-in']) {
    testWidgets(
      'rapid tabs and reduced motion during $phase settle immediately',
      (tester) async {
        final harness = GlobalKey<_TabHarnessState>();
        await tester.pumpWidget(MaterialApp(home: _TabHarness(key: harness)));
        void select(int index) => harness.currentState!.select(index);
        select(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.text('Tab 1'), findsNothing);
        expect(find.text('Tab 0'), findsOneWidget);
        select(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 31));
        await tester.pump();
        expect(find.text('Tab 2'), findsOneWidget);
        expect(find.text('Tab 0'), findsNothing);
        await tester.pump(const Duration(milliseconds: 40));
        // Retarget while fading in; go back to the same visible tab as well.
        select(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        select(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 15));
        select(0);
        await tester.pump();
        await tester.pump(Duration(milliseconds: phase == 'fade-out' ? 5 : 70));
        harness.currentState!.reduce();
        await tester.pump();
        expect(find.text('Tab 0'), findsOneWidget);
        await tester.tap(find.text('Tab 0'));
        expect(harness.currentState!.taps, 1);
        select(1);
        await tester.pump();
        await tester.tap(find.text('Tab 1'));
        expect(harness.currentState!.taps, 2);
        harness.currentState!.reduce(false);
        select(2);
        await tester.pump();
        expect(find.text('Tab 1'), findsOneWidget);
        expect(find.text('Tab 2'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('Tab 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Disposal in flight must not leave a pending async transition.
        select(0);
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'tab fade settles within one frame of 220 ms, with one page exposed',
    (tester) async {
      final harness = GlobalKey<_TabHarnessState>();
      await tester.pumpWidget(MaterialApp(home: _TabHarness(key: harness)));
      harness.currentState!.select(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 61));
      await tester.pump();
      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 0'), findsNothing);
      await tester.pump(const Duration(milliseconds: 161));
      await tester.tap(find.text('Tab 1'));
      expect(harness.currentState!.taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'iOS push, cancelled and committed back swipe keep form and scroll',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: appTheme().copyWith(platform: TargetPlatform.iOS),
          home: const _StatefulForm(),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Form gốc');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  ),
                )
                .first,
          )
          .position;
      final offset = scroll.pixels;
      expect(offset, greaterThan(0));
      final state = tester.state(find.byType(_StatefulForm));
      final route = AppPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Detail'))),
      );
      nav.currentState!.push(route);
      await tester.pump();
      expect(route.transitionDuration, const Duration(milliseconds: 260));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 220),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.value, inExclusiveRange(0, 1));
      expect(find.byType(CupertinoPageTransition), findsWidgets);
      await tester.pumpAndSettle();
      expect(route.popGestureEnabled, isTrue);
      var gesture = await tester.startGesture(const Offset(1, 250));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(nav.currentState!.userGestureInProgress, isTrue);
      // End slowly below the halfway point to cancel, rather than fling back.
      await gesture.moveBy(const Offset(-5, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      gesture = await tester.startGesture(const Offset(1, 250));
      await gesture.moveBy(Offset(tester.view.physicalSize.width * .8, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
      expect(tester.state(find.byType(_StatefulForm)), same(state));
      expect(scroll.pixels, closeTo(offset, .1));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Form gốc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion snaps pop, replacement and new routes', (
    tester,
  ) async {
    var reduced = false;
    var rootTaps = 0;
    late StateSetter update;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            navigatorKey: nav,
            theme: appTheme().copyWith(platform: TargetPlatform.iOS),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: Scaffold(
              body: TextButton(
                onPressed: () => rootTaps++,
                child: const Text('Root action'),
              ),
            ),
          );
        },
      ),
    );
    final detail = AppPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Detail')),
    );
    nav.currentState!.push(detail);
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    update(() => reduced = true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Detail'), findsNothing);
    await tester.tap(find.text('Root action'));
    expect(rootTaps, 1);
    final first = AppPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('First')),
    );
    nav.currentState!.push(first);
    await tester.pump();
    await tester.pump();
    expect(first.transitionDuration, Duration.zero);
    expect(first.animation!.status, AnimationStatus.completed);
    final replacement = AppPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Replacement')),
    );
    nav.currentState!.pushReplacement(replacement);
    await tester.pump();
    await tester.pump();
    expect(find.text('Replacement'), findsOneWidget);
    expect(find.text('First', skipOffstage: false), findsNothing);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Root action'));
    expect(rootTaps, 2);
    update(() => reduced = false);
    await tester.pump();
    final animated = AppPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Animated replacement')),
    );
    nav.currentState!.pushReplacement(animated);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(animated.animation!.value, inExclusiveRange(0, 1));
    update(() => reduced = true);
    await tester.pump();
    await tester.pump();
    expect(animated.animation!.status, AnimationStatus.completed);
    expect(find.text('Root action', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion during a back gesture leaves gesture ownership intact',
    (tester) async {
      var reduced = false;
      var taps = 0;
      late StateSetter update;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              navigatorKey: nav,
              theme: appTheme().copyWith(platform: TargetPlatform.iOS),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: child!,
              ),
              home: const Scaffold(body: Text('Root')),
            );
          },
        ),
      );
      final route = AppPageRoute<void>(
        builder: (_) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('Detail action'),
            ),
          ),
        ),
      );
      nav.currentState!.push(route);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(1, 250));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(nav.currentState!.userGestureInProgress, isTrue);
      update(() => reduced = true);
      await tester.pump();
      expect(nav.currentState!.userGestureInProgress, isTrue);
      expect(route.isCurrent, isTrue);
      await gesture.moveBy(const Offset(-5, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(nav.currentState!.userGestureInProgress, isFalse);
      expect(route.isCurrent, isTrue);
      await tester.tap(find.text('Detail action'));
      expect(taps, 1);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Root'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real tabs keep library search and scroll with personal overview',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = AppController(await SharedPreferences.getInstance())
        ..connected = true;
      c.state['documents'] = [
        for (var i = 0; i < 20; i++)
          {
            'id': '$i',
            'name': 'Sinh học $i.pdf',
            'pages': ['Nguồn'],
            'warnings': [],
            'createdAt': 1,
          },
      ];
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: appTheme(),
          home: HomeScreen(c: c, initialTab: 1),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Sinh');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  ),
                )
                .first,
          )
          .position;
      final offset = scroll.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Tài liệu của bạn'), findsOneWidget);
      expect(find.byKey(const ValueKey('relay-address')), findsNothing);
      openScreen(
        nav.currentContext!,
        const Scaffold(body: Text('Above profile')),
      );
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Tài liệu của bạn'), findsOneWidget);
      await tester.tap(find.text('Tài liệu'));
      await tester.pumpAndSettle();
      expect(scroll.pixels, closeTo(offset, .1));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Sinh'), findsOneWidget);
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Tài liệu của bạn'), findsOneWidget);
      for (var i = 0; i < 24; i++) {
        final label = ['Trang chủ', 'Tài liệu', 'Bộ đề', 'Cá nhân'][i % 4];
        await tester.tap(
          find.descendant(
            of: find.byType(StudyNavigation),
            matching: find.text(label),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
      expect(find.text('Tài liệu của bạn'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('quiz answer draft survives a covering route and return', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance());
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: appTheme(),
        home: QuizScreen(
          c: c,
          quiz: {
            'id': 'motion-quiz',
            'title': 'Motion fixture',
            'questions': [
              {
                'question': 'Chọn đáp án',
                'options': ['Đáp án 1', 'Đáp án 2', 'Đáp án 3', 'Đáp án 4'],
                'correct': 0,
                'explanation': 'Nguồn',
                'page': 1,
                'quote': 'Nguồn',
              },
            ],
          },
        ),
      ),
    );
    await tester.tap(find.text('Đáp án 1'));
    await tester.pump();
    final draft = c.prefs.getString('draft-motion-quiz');
    expect(jsonDecode(draft!)['answers'], [0]);
    final state = tester.state(find.byType(QuizScreen));
    openScreen(nav.currentContext!, const Scaffold(body: Text('Help')));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(QuizScreen)), same(state));
    expect(c.prefs.getString('draft-motion-quiz'), draft);
    expect(find.text('1 đã trả lời'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}

class _StatefulForm extends StatefulWidget {
  const _StatefulForm();

  @override
  State<_StatefulForm> createState() => _StatefulFormState();
}

class _StatefulFormState extends State<_StatefulForm> {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        TextField(controller: text),
        const SizedBox(height: 1500),
        const Text('End'),
      ],
    ),
  );
}

class _TabHarness extends StatefulWidget {
  const _TabHarness({super.key});
  @override
  State<_TabHarness> createState() => _TabHarnessState();
}

class _TabHarnessState extends State<_TabHarness> {
  int index = 0;
  int taps = 0;
  bool reduced = false;
  void select(int value) => setState(() => index = value);
  void reduce([bool value = true]) => setState(() => reduced = value);
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: Scaffold(
      body: SmoothTabBody(
        index: index,
        children: [
          for (var i = 0; i < 3; i++)
            Center(
              child: TextButton(onPressed: () => taps++, child: Text('Tab $i')),
            ),
        ],
      ),
    ),
  );
}
