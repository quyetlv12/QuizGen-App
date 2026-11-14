import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/learning_profile.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppController c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = AppController(
      await SharedPreferences.getInstance(),
      requireAccount: true,
    );
    c.user = {'id': 'one'};
  });
  tearDown(() => c.dispose());

  test(
    'preferences persist, isolate accounts and tolerate corrupt storage',
    () async {
      await const LearningPreferences(
        subject: 'Toán',
        grade: 'Lớp 12',
        difficulty: 'hard',
        dailyGoal: 30,
      ).save(c);
      expect(LearningPreferences.load(c).dailyGoal, 30);
      expect(LearningPreferences.load(c).instructions, contains('Lớp 12'));
      c.user = {'id': 'two'};
      expect(LearningPreferences.load(c).subject, isEmpty);
      await c.prefs.setString(c.localKey('learning-profile'), 'invalid');
      expect(LearningPreferences.load(c).difficulty, 'auto');
    },
  );

  test(
    'stats weight by questions, filter invalid attempts and use local day',
    () {
      final now = DateTime(2026, 11, 14, 12);
      final stats = LearningStats([
        {
          'quizId': 'a',
          'total': 10,
          'score': 8,
          'createdAt': now.millisecondsSinceEpoch / 1000,
        },
        {
          'quizId': 'a',
          'total': 5,
          'score': 1,
          'createdAt':
              now.subtract(const Duration(days: 1)).millisecondsSinceEpoch /
              1000,
        },
        {'quizId': 'b', 'total': 0, 'score': 0},
      ], now: now);
      expect(stats.accuracy, 60);
      expect(stats.todayAnswered, 10);
      expect(stats.byQuiz['a'], (9, 15));
      expect(stats.valid.length, 2);
    },
  );

  testWidgets('validates and saves preferences and prefills quiz generation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme().copyWith(
          textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
          filledButtonTheme: FilledButtonThemeData(
            style: appTheme().filledButtonTheme.style?.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        home: LearningPreferencesScreen(c: c),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Môn học ưu tiên'),
      'Toán',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lớp / trình độ'),
      'Lớp 12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mục tiêu câu hỏi mỗi ngày'),
      '0',
    );
    await tester.ensureVisible(find.text('Lưu tùy chọn'));
    await tester.tap(find.text('Lưu tùy chọn'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số nguyên từ 1 đến 100.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mục tiêu câu hỏi mỗi ngày'),
      '30',
    );
    await tester.ensureVisible(find.text('Lưu tùy chọn'));
    await tester.tap(find.text('Lưu tùy chọn'));
    await tester.pumpAndSettle();
    expect(LearningPreferences.load(c).dailyGoal, 30);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: appTheme().copyWith(
          textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
          filledButtonTheme: FilledButtonThemeData(
            style: appTheme().filledButtonTheme.style?.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        home: DocumentScreen(
          c: c,
          document: {
            'id': 'doc',
            'name': 'Toán',
            'pages': ['Nội dung'],
            'warnings': [],
            'createdAt': 1,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final instructions = tester.widget<TextFormField>(
      find.byKey(const ValueKey('generate-instructions')),
    );
    expect(instructions.controller!.text, contains('Môn học ưu tiên: Toán'));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets('learning screens fit $width and show real/empty stats', (
      tester,
    ) async {
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
      Future<void> capture(String name) async {
        if (Platform.environment['CAPTURE_PROFILE'] != '1') return;
        await tester.runAsync(() async {
          final render = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/verification/profile/$name-${width.toInt()}.png',
          );
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme().copyWith(
            textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
            filledButtonTheme: FilledButtonThemeData(
              style: appTheme().filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          home: LearningStatsScreen(c: c),
        ),
      );
      expect(find.text('Chưa có kết quả học tập'), findsOneWidget);
      c.state['attempts'] = [
        {'quizId': 'a', 'total': 5, 'score': 4, 'createdAt': 1},
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme().copyWith(
            textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
            filledButtonTheme: FilledButtonThemeData(
              style: appTheme().filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          home: LearningStatsScreen(key: UniqueKey(), c: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('80%'), findsOneWidget);
      await capture('learning-stats');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme().copyWith(
            textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
            filledButtonTheme: FilledButtonThemeData(
              style: appTheme().filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          home: LearningPreferencesScreen(c: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('learning-preferences');
    });
  }
}
