// Independent QA probes. Product and developer-owned tests are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';

void main() {
  for (final commit in [false, true]) {
    testWidgets('QA reduce during back gesture: commit=$commit', (t) async {
      final nav = GlobalKey<NavigatorState>();
      late StateSetter update;
      var reduced = false;
      var rootTaps = 0;
      var detailTaps = 0;
      await t.pumpWidget(StatefulBuilder(builder: (context, setState) {
        update = setState;
        return MaterialApp(
          navigatorKey: nav,
          theme: appTheme().copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Scaffold(body: Center(child: TextButton(
            onPressed: () => rootTaps++, child: const Text('QA root'),
          ))),
        );
      }));
      final rootState = nav.currentState;
      final detail = AppPageRoute<void>(builder: (_) => Scaffold(
        body: Center(child: TextButton(onPressed: () => detailTaps++,
          child: const Text('QA detail'))),
      ));
      nav.currentState!.push(detail);
      await t.pumpAndSettle();
      final gesture = await t.startGesture(const Offset(1, 250));
      await gesture.moveBy(Offset(t.view.physicalSize.width * (commit ? .75 : .15), 0));
      await t.pump(const Duration(milliseconds: 100));
      expect(nav.currentState!.userGestureInProgress, isTrue);
      update(() => reduced = true);
      await t.pump();
      expect(nav.currentState!.userGestureInProgress, isTrue);
      // End slowly so position, not a fling, decides cancellation/completion.
      await gesture.moveBy(const Offset(-1, 0));
      await t.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await t.pumpAndSettle();
      expect(nav.currentState!.userGestureInProgress, isFalse);
      expect(nav.currentState, same(rootState));
      if (commit) {
        expect(find.text('QA detail', skipOffstage: false), findsNothing);
        await t.tap(find.text('QA root'));
        expect(rootTaps, 1);
      } else {
        expect(detail.isCurrent, isTrue);
        await t.tap(find.text('QA detail'));
        expect(detailTaps, 1);
      }
      update(() => reduced = false);
      await t.pump();
      final next = AppPageRoute<void>(builder: (_) => const Scaffold(body: Text('Next')));
      nav.currentState!.push(next);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(next.animation!.value, inExclusiveRange(0, 1));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('QA tab boundary bursts preserve edits and final interaction', (t) async {
    final form = TextEditingController(text: 'QA unsaved');
    addTearDown(form.dispose);
    late StateSetter update;
    var index = 0;
    var reduced = false;
    var taps = 0;
    await t.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(body: SmoothTabBody(index: index, children: [
          Center(child: TextField(controller: form)),
          Center(child: TextButton(onPressed: () => taps++, child: const Text('QA one'))),
          Center(child: TextButton(onPressed: () => taps++, child: const Text('QA two'))),
        ])),
      );
    })));
    for (final delay in [0, 30, 59, 60, 61, 100, 219]) {
      update(() { reduced = false; index = 0; });
      await t.pumpAndSettle();
      expect(form.text, 'QA unsaved');
      update(() => index = 1);
      await t.pump();
      await t.pump(Duration(milliseconds: delay));
      update(() => index = 2);
      await t.pump();
      await t.pump(const Duration(milliseconds: 7));
      update(() => index = 1);
      await t.pump();
      update(() { index = 2; reduced = true; });
      await t.pump();
      expect(find.text('QA one'), findsNothing);
      expect(find.text('QA two'), findsOneWidget);
      await t.tap(find.text('QA two'));
      expect(taps, [0,30,59,60,61,100,219].indexOf(delay) + 1);
      expect(form.text, 'QA unsaved');
      expect(t.takeException(), isNull);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('QA remove-until during reduce leaves only destination usable', (t) async {
    final nav = GlobalKey<NavigatorState>();
    late StateSetter update;
    var reduced = false;
    var taps = 0;
    await t.pumpWidget(StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MaterialApp(navigatorKey: nav, theme: appTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced), child: child!),
        home: const Scaffold(body: Text('Old root')));
    }));
    nav.currentState!.push(AppPageRoute<void>(builder: (_) => const Scaffold(body: Text('Old detail'))));
    await t.pumpAndSettle();
    final next = AppPageRoute<void>(builder: (_) => Scaffold(body: TextButton(
      onPressed: () => taps++, child: const Text('New root'))));
    nav.currentState!.pushAndRemoveUntil(next, (_) => false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    update(() => reduced = true);
    await t.pump();
    await t.pump();
    expect(next.animation!.status, AnimationStatus.completed);
    expect(find.text('Old root', skipOffstage: false), findsNothing);
    expect(find.text('Old detail', skipOffstage: false), findsNothing);
    expect(nav.currentState!.canPop(), isFalse);
    await t.tap(find.text('New root'));
    expect(taps, 1);
    expect(t.takeException(), isNull);
  });
}
