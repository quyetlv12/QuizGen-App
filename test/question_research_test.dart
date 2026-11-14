import 'dart:async';
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
import 'package:quizmind/question_research_sheet.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const question = <String, dynamic>{
  'question': 'Ở áp suất 1 atm, nước sôi ở nhiệt độ bao nhiêu?',
  'options': ['100 °C', '50 °C', '20 °C', '0 °C'],
  'correct': 0,
};
const result = <String, dynamic>{
  'answer': 'Nước sôi ở 100 °C dưới áp suất 1 atm.\n\nNhiệt độ sôi thay đổi theo áp suất bên ngoài. Ở vùng núi cao, áp suất thấp hơn nên nước sôi ở nhiệt độ thấp hơn. Ví dụ: thời gian nấu thức ăn có thể dài hơn.',
  'sources': [
    {'title': 'Nước', 'url': 'https://vi.wikipedia.org/?curid=42'},
  ],
};

void main() {
  late AppController controller;
  late Completer<http.Response> pending;
  late List<Json> requests;
  final boundaryKey = GlobalKey();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pending = Completer<http.Response>();
    requests = [];
    controller = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'http://localhost:8787',
        client: MockClient((request) async {
          if (request.url.path == '/api/research') {
            requests.add(jsonDecode(request.body) as Json);
            return pending.future;
          }
          return http.Response(
            '{"documents":[],"quizzes":[],"jobs":[],"attempts":[]}',
            200,
          );
        }),
      ),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme().copyWith(
            textTheme: appTheme().textTheme.apply(fontFamily: 'Arial'),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showQuestionResearch(
                    context,
                    controller,
                    'quiz',
                    2,
                    question,
                  ),
                  child: const Text('Mở'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> respond(WidgetTester tester, http.Response response) async {
    await tester.runAsync(() async {
      pending.complete(response);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('loads question context, renders sources and dismisses', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(AiThinkingIndicator), findsOneWidget);
    expect(find.text(question['question'] as String), findsOneWidget);
    expect(requests.single, {'quizId': 'quiz', 'questionIndex': 2});
    await respond(
      tester,
      http.Response.bytes(
        utf8.encode(jsonEncode(result)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kiến thức mở rộng'), findsOneWidget);
    expect(find.text('Nước'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionResearchSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure can retry and no-source warning stays visible', (
    tester,
  ) async {
    await open(tester);
    await respond(
      tester,
      http.Response.bytes(
        utf8.encode('{"error":"Mất kết nối AI"}'),
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối AI'), findsOneWidget);
    pending = Completer<http.Response>();
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(find.byType(AiThinkingIndicator), findsOneWidget);
    await respond(
      tester,
      http.Response.bytes(
        utf8.encode(jsonEncode({...result, 'sources': []})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa được kiểm chứng'), findsOneWidget);
    expect(requests, hasLength(2));
  });

  testWidgets('closing during search ignores late response', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await respond(
      tester,
      http.Response.bytes(
        utf8.encode(jsonEncode(result)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection changes invalidate pending research', (tester) async {
    await open(tester);
    await tester.runAsync(() => controller.setAddress('http://localhost:9999'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kết nối đã thay đổi'), findsOneWidget);
    await respond(
      tester,
      http.Response.bytes(
        utf8.encode(jsonEncode(result)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kiến thức mở rộng'), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
  });

  for (final width in [320.0, 393.0, 1280.0]) {
    testWidgets('sheet fits and renders at $width', (tester) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['CAPTURE_RESEARCH'] == '1') {
        await tester.runAsync(() async {
          final font = FontLoader('Arial')
            ..addFont(
              File('/System/Library/Fonts/Supplemental/Arial.ttf')
                  .readAsBytes()
                  .then((bytes) => ByteData.view(bytes.buffer)),
            );
          await font.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      await open(tester);
      Future<void> capture(String state) async {
        if (Platform.environment['CAPTURE_RESEARCH'] != '1') return;
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/verification/question-research/$state-${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('loading');
      await respond(
        tester,
        http.Response.bytes(
          utf8.encode(jsonEncode(result)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pumpAndSettle();
      await capture('result');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Sao chép liên kết'));
      expect(tester.takeException(), isNull);
    });
  }
}
