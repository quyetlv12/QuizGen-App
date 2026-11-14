import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/quiz_tags.dart';
import 'package:quizmind/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppController c;
  late Json state;
  late List<String> actions;
  bool failMutation = false;
  final boundaryKey = GlobalKey();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    actions = [];
    failMutation = false;
    state = {
      'documents': [],
      'jobs': [],
      'attempts': [],
      'tags': <Json>[
        {'id': 'a', 'name': 'Ôn thi'},
        {'id': 'b', 'name': 'Quan trọng', 'color': 'amber'},
      ],
      'quizzes': [
        {
          'id': 'q',
          'title': 'Hệ hô hấp ở người',
          'questions': [],
          'createdAt': 1700000000,
          'tagIds': ['a'],
        },
        {
          'id': 'q2',
          'title': 'Phân thức đại số',
          'questions': [],
          'createdAt': 1700000000,
          'tagIds': ['b'],
        },
      ],
    };
    c = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'http://localhost:8787',
        client: MockClient((request) async {
          final path = request.url.path;
          Json result = state;
          if (path != '/api/state') {
            actions.add(path);
            if (failMutation) {
              return http.Response.bytes(
                utf8.encode(jsonEncode({'error': 'Không thể lưu tag'})),
                400,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            final body = jsonDecode(request.body) as Json;
            final tags = state['tags'] as List;
            if (path.endsWith('create')) {
              result = {
                'id': 'new',
                'name': body['name'],
                'color': body['color'],
              };
              tags.add(result);
            } else if (path.endsWith('rename')) {
              result = tags.firstWhere((t) => t['id'] == body['tagId']) as Json;
              result['name'] = body['name'];
              result['color'] = body['color'];
            } else if (path.endsWith('delete')) {
              tags.removeWhere((t) => t['id'] == body['tagId']);
            } else if (path.endsWith('assign')) {
              (state['quizzes'] as List).first['tagIds'] = body['tagIds'];
            }
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode(result)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    c.state = jsonDecode(jsonEncode(state)) as Json;
    c.connected = true;
  });
  tearDown(() => c.dispose());

  Future<void> build(WidgetTester tester) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme().copyWith(
            textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
            filledButtonTheme: FilledButtonThemeData(
              style: appTheme().filledButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          home: HomeScreen(c: c, initialTab: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finishRequest(WidgetTester tester) async {
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  test('legacy and unknown colors fall back to green', () {
    expect(tagColors({'name': 'Legacy'}), tagPalette['green']);
    expect(tagColors({'color': 'unknown'}), tagPalette['green']);
    expect(tagColors({'color': 'blue'}), tagPalette['blue']);
  });

  testWidgets('filter quizzes and assign multiple tags', (tester) async {
    await build(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ôn thi'));
    await tester.pumpAndSettle();
    expect(find.text('Phân thức đại số'), findsNothing);
    await tester.tap(find.text('Gắn tag').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Quan trọng'));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ đã chọn · 2'), findsOneWidget);
    await tester.ensureVisible(find.text('Hoàn tất'));
    await tester.tap(find.text('Hoàn tất'));
    await finishRequest(tester);
    expect(actions, contains('/api/tags/assign'));
    expect((state['quizzes'] as List).first['tagIds'], ['a', 'b']);
    expect(find.byType(QuizTagSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create rename and confirm delete tag', (tester) async {
    await build(tester);
    await tester.tap(find.byTooltip('Quản lý thẻ Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Màu Xanh dương'));
    await tester.enterText(find.byType(TextField), 'Cần ôn lại');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('+ Thêm'));
    await tester.tap(find.text('+ Thêm'));
    await finishRequest(tester);
    expect(find.widgetWithText(ListTile, 'Cần ôn lại'), findsOneWidget);
    expect((state['tags'] as List).last['color'], 'blue');
    await tester.ensureVisible(find.byTooltip('Sửa hoặc xoá Cần ôn lại'));
    await tester.tap(find.byTooltip('Sửa hoặc xoá Cần ôn lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi tên'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Màu Đỏ'));
    await tester.tap(find.byTooltip('Màu Đỏ'));
    await tester.enterText(find.byType(TextField), 'Đề khó');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu tag'));
    await tester.tap(find.text('Lưu tag'));
    await finishRequest(tester);
    expect((state['tags'] as List).last['color'], 'red');
    await tester.ensureVisible(find.byTooltip('Sửa hoặc xoá Đề khó'));
    await tester.tap(find.byTooltip('Sửa hoặc xoá Đề khó'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá tag').last);
    await finishRequest(tester);
    expect(
      actions,
      containsAll(['/api/tags/create', '/api/tags/rename', '/api/tags/delete']),
    );
    expect(find.widgetWithText(ListTile, 'Đề khó'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save keeps selection and allows retry', (tester) async {
    await build(tester);
    await tester.tap(find.text('Gắn tag').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Quan trọng'));
    await tester.pumpAndSettle();
    failMutation = true;
    await tester.ensureVisible(find.text('Hoàn tất'));
    await tester.tap(find.text('Hoàn tất'));
    await finishRequest(tester);
    expect(find.byType(QuizTagSheet), findsOneWidget);
    expect(find.textContaining('Không thể lưu tag'), findsOneWidget);
    expect(find.text('Thẻ đã chọn · 2'), findsOneWidget);
    expect((state['quizzes'] as List).first['tagIds'], ['a']);
    failMutation = false;
    await tester.ensureVisible(find.text('Hoàn tất'));
    await tester.tap(find.text('Hoàn tất'));
    await finishRequest(tester);
    expect(find.byType(QuizTagSheet), findsNothing);
    expect((state['quizzes'] as List).first['tagIds'], ['a', 'b']);
  });

  for (final width in [320.0, 393.0, 1280.0]) {
    testWidgets('layout at $width and keyboard', (tester) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['CAPTURE_TAGS'] == '1') {
        await tester.runAsync(() async {
          await (FontLoader('Arial')..addFont(
                File('/System/Library/Fonts/Supplemental/Arial.ttf')
                    .readAsBytes()
                    .then((b) => ByteData.view(b.buffer)),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      Future<void> capture(String name) async {
        if (Platform.environment['CAPTURE_TAGS'] != '1') return;
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final img = await boundary.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/verification/quiz-tags/$name-${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      await build(tester);
      await capture('list');
      await tester.tap(find.text('Gắn tag').first);
      await tester.pumpAndSettle();
      await capture('sheet');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }
}
