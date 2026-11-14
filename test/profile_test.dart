import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/profile_view.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';

void main() {
  for (final size in [
    const Size(393, 852),
    const Size(320, 740),
    const Size(1280, 900),
  ]) {
    testWidgets('profile content and actions at ${size.width}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      if (Platform.environment['CAPTURE_PROFILE'] == '1') {
        await tester.runAsync(() async {
          await (FontLoader('Arial')..addFont(
                File('/System/Library/Fonts/Supplemental/Arial.ttf')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      final boundary = GlobalKey();
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme().copyWith(
            textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width == 320 ? 1.3 : 1),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              extendBody: true,
              appBar: BrandBar(onNotifications: () {}),
              body: PageBody(
                behindNavigation: true,
                children: [
                  ProfileView(
                    name: size.width == 320
                        ? 'Người dùng với tên dài để kiểm tra bố cục'
                        : 'An Nguyễn',
                    email: 'an.nguyen@example.com',
                    role: 'Người dùng',
                    documents: 12,
                    quizzes: 8,
                    attempts: 24,
                    onStatistics: () => calls.add('statistics'),
                    onPersonalization: () => calls.add('personalization'),
                    onDocuments: () => calls.add('documents'),
                    onQuizzes: () => calls.add('quizzes'),
                    onLogout: () => calls.add('logout'),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
              bottomNavigationBar: StudyNavigation(
                selected: 3,
                onChanged: (_) {},
                onScan: () {},
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/robot.png'),
          tester.element(find.byType(ProfileView)),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cài đặt'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Đăng xuất')).dy,
        greaterThan(tester.getTopLeft(find.text('Bộ đề và kết quả')).dy),
      );
      expect(find.text('12 tài liệu'), findsOneWidget);
      expect(find.text('8 bộ đề · 24 lượt làm bài'), findsOneWidget);
      if (Platform.environment['CAPTURE_PROFILE'] == '1') {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/verification/profile/profile-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      for (final label in [
        'Thống kê học tập',
        'Cá nhân hóa học tập',
        'Đăng xuất',
        'Tài liệu của bạn',
        'Bộ đề và kết quả',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
      }
      expect(calls, [
        'statistics',
        'personalization',
        'logout',
        'documents',
        'quizzes',
      ]);
      expect(tester.takeException(), isNull);
    });
  }
}
