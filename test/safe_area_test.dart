import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/ui.dart';

void main() {
  for (final size in [const Size(402, 874), const Size(1024, 1366)]) {
    for (final withAppBar in [false, true]) {
      testWidgets(
        'PageBody respects system insets at $size, app bar $withAppBar',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 62, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 62, bottom: 34),
                ),
                child: child!,
              ),
              home: Scaffold(
                appBar: withAppBar
                    ? AppBar(title: const Text('App bar'))
                    : null,
                body: const PageBody(children: [PageTitle('Thêm tài liệu')]),
              ),
            ),
          );
          final top = tester.getTopLeft(find.byType(PageTitle)).dy;
          expect(top, withAppBar ? 62 + kToolbarHeight + 16 : 62 + 16);
          expect(
            tester.getTopLeft(find.byTooltip('Quay lại')).dy,
            greaterThanOrEqualTo(top),
          );
          final viewport = tester.getRect(find.byType(ListView));
          expect(viewport.bottom, size.height - 34);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
