import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/ui.dart';

void main() {
  for (final width in [320.0, 430.0, 1280.0]) {
    testWidgets('toast stays below safe area at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 932);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold(body: Text('Nội dung'));
            },
          ),
        ),
      );
      showAppToast(page, 'Đã tạo xong bộ câu hỏi: tiếng anh', success: true);
      await tester.pump();
      final rect = tester.getRect(find.byKey(const ValueKey('app-toast')));
      expect(rect.top, 67);
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(width - 16));
      expect(rect.width, lessThanOrEqualTo(608));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Đóng thông báo'));
      await tester.pump();
      expect(find.byKey(const ValueKey('app-toast')), findsNothing);
    });
  }

  testWidgets('new toast replaces old toast and expires', (tester) async {
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            page = context;
            return const Scaffold();
          },
        ),
      ),
    );
    showAppToast(page, 'Thông báo cũ');
    await tester.pump(const Duration(seconds: 2));
    showAppToast(page, 'Thông báo mới');
    await tester.pump();
    expect(find.text('Thông báo cũ'), findsNothing);
    expect(find.text('Thông báo mới'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Thông báo mới'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Thông báo mới'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
