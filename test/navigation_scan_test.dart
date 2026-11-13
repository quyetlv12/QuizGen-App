import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/ui.dart';

void main() {
  testWidgets('scan sweep moves, settles and respects reduced motion', (
    tester,
  ) async {
    var reduced = false;
    var scans = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Scaffold(
                bottomNavigationBar: StudyNavigation(
                  selected: 0,
                  onChanged: (_) {},
                  onScan: () => scans++,
                ),
              ),
            );
          },
        ),
      ),
    );
    double lineY() => tester
        .widget<Transform>(find.byKey(const ValueKey('navigation-scan-line')))
        .transform
        .storage[13];
    expect(find.byIcon(Icons.crop_free_rounded), findsOneWidget);
    expect(lineY(), closeTo(0, .001));
    await tester.pump(const Duration(milliseconds: 550));
    expect(lineY(), closeTo(10, .001));
    update(() => reduced = true);
    await tester.pump();
    await tester.pump();
    expect(lineY(), closeTo(0, .001));
    await tester.pump(const Duration(milliseconds: 550));
    expect(lineY(), closeTo(0, .001));
    await tester.tap(find.byTooltip('Quét tài liệu'));
    expect(scans, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
