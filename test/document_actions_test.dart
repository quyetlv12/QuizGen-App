import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/swipe_document_row.dart';
import 'package:quizmind/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppController c;
  late List<Json> docs;
  late List<Json> requests;
  bool failing = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = [
      for (var i = 0; i < 8; i++)
        {
          'id': 'doc-$i',
          'name': 'Tài liệu $i',
          'pages': ['Nội dung'],
          'warnings': [],
          'bytes': 100,
          'createdAt': 1,
        },
    ];
    requests = [];
    failing = false;
    c = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'http://localhost:8787',
        client: MockClient((r) async {
          if (r.method == 'POST') {
            final body = jsonDecode(r.body) as Json;
            requests.add({'path': r.url.path, ...body});
            if (failing) {
              return http.Response(
                jsonEncode({'error': 'Không lưu được tài liệu.'}),
                500,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (r.url.path == '/api/rename') {
              docs.firstWhere((d) => d['id'] == body['documentId'])['name'] =
                  body['name'];
            }
            if (r.url.path == '/api/trash') {
              docs.removeWhere((d) => d['id'] == body['documentId']);
            }
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
            jsonEncode({
              'documents': docs,
              'jobs': [],
              'quizzes': [],
              'attempts': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    await c.refresh();
  });
  tearDown(() => c.dispose());
  Future<void> open(WidgetTester tester, {int tab = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: HomeScreen(c: c, initialTab: tab),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('document-doc-0')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const ValueKey('document-doc-0')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'full swipe reveals only actions; rename validates trims and survives reopening',
    (t) async {
      await open(t);
      await swipe(t);
      expect(requests, isEmpty);
      expect(find.text('Đổi tên'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);
      await t.tap(find.text('Đổi tên'));
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('rename-document-name'));
      expect(t.widget<TextFormField>(field).controller!.text, 'Tài liệu 0');
      await t.enterText(field, '   ');
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(find.text('Vui lòng nhập tên tài liệu.'), findsOneWidget);
      expect(requests, isEmpty);
      await t.enterText(field, '  Tên mới  ');
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(requests.single, {
        'path': '/api/rename',
        'documentId': 'doc-0',
        'name': 'Tên mới',
      });
      expect(find.text('Tên mới'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await open(t);
      await swipe(t);
      await t.tap(find.text('Đổi tên'));
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(field).controller!.text, 'Tên mới');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'delete names target cancel does nothing then deletes only selected item',
    (t) async {
      await open(t);
      await swipe(t);
      await t.tap(find.text('Xóa'));
      await t.pumpAndSettle();
      expect(find.textContaining('Xóa “Tài liệu 0”'), findsOneWidget);
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      expect(requests, isEmpty);
      await swipe(t);
      await t.tap(find.text('Xóa'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await t.pumpAndSettle();
      expect(requests.single['documentId'], 'doc-0');
      expect(docs.length, 7);
      expect(docs.first['id'], 'doc-1');
      expect(find.byKey(const ValueKey('document-doc-0')), findsNothing);
    },
  );
  testWidgets(
    'rename and delete server errors preserve item and rename draft',
    (t) async {
      failing = true;
      await open(t);
      await swipe(t);
      await t.tap(find.text('Đổi tên'));
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('rename-document-name'));
      await t.enterText(field, 'Tên chưa lưu');
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(find.text('Không lưu được tài liệu.'), findsOneWidget);
      expect(t.widget<TextFormField>(field).controller!.text, 'Tên chưa lưu');
      expect(docs.first['name'], 'Tài liệu 0');
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      await swipe(t);
      await t.tap(find.text('Xóa'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await t.pumpAndSettle();
      expect(find.text('Không lưu được tài liệu.'), findsOneWidget);
      expect(docs.length, 8);
    },
  );
  testWidgets(
    'vertical scrolling and tap navigation survive, home shares swipe',
    (t) async {
      await open(t);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('document-doc-6')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(requests, isEmpty);
      expect(find.text('Đổi tên'), findsNothing);
      await t.tap(find.text('Tài liệu 6'));
      await t.pumpAndSettle();
      expect(find.byType(DocumentScreen), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await open(t, tab: 0);
      await swipe(t);
      expect(find.text('Đổi tên'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('dialog cannot mutate another relay after connection changes', (
    t,
  ) async {
    await open(t);
    await swipe(t);
    await t.tap(find.text('Đổi tên'));
    await t.pumpAndSettle();
    await c.setAddress('https://another.example', token: 'B' * 43);
    c.timer?.cancel();
    await t.enterText(
      find.byKey(const ValueKey('rename-document-name')),
      'Sai relay',
    );
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(requests, isEmpty);
    expect(
      find.text('Kết nối đã thay đổi; thao tác cũ đã bị hủy.'),
      findsOneWidget,
    );
  });
  testWidgets('compact row preserves geometry and accessibility actions', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: SwipeDocumentRow(
              onRename: () async {},
              onDelete: () async {},
              child: const SizedBox(
                height: 90,
                width: double.infinity,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await t.drag(find.byType(SwipeDocumentRow), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('Đổi tên'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
