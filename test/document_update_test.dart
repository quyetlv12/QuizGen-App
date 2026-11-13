import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_options_test.dart' show FixturePicker;

void main() {
  late AppController controller;
  late List<http.Request> posts;
  late FixturePicker picker;
  bool fail = false;
  final document = <String, dynamic>{
    'id': 'document-one',
    'name': 'Bài tập tiếng Anh',
    'pages': ['Nội dung tài liệu ban đầu.'],
    'warnings': [],
    'createdAt': 1,
  };
  setUpAll(() async {
    for (final entry in {
      'Roboto': Platform.environment['CAPTURE_FONT'],
      'Ahem': Platform.environment['CAPTURE_FONT'],
      'MaterialIcons': Platform.environment['CAPTURE_ICONS'],
    }.entries) {
      if (entry.value != null) {
        await (FontLoader(entry.key)..addFont(
              File(entry.value!)
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    posts = [];
    fail = false;
    picker = FixturePicker();
    FilePicker.platform = picker;
    controller = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'http://localhost:8787',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts.add(request);
            return fail
                ? http.Response(
                    '{"error":"Không gửi được bản cập nhật"}',
                    400,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  )
                : http.Response('{"id":"update-job"}', 202);
          }
          return http.Response(
            jsonEncode({
              'documents': [document],
              'quizzes': [],
              'jobs': [],
              'attempts': [],
            }),
            200,
          );
        }),
      ),
    );
  });
  tearDown(() {
    controller.dispose();
  });

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DocumentScreen(c: controller, document: document),
                ),
              ),
              child: const Text('Mở tài liệu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở tài liệu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cập nhật tài liệu'));
    await tester.tap(find.text('Cập nhật tài liệu'));
    await tester.pumpAndSettle();
  }

  Future<void> selectFile(WidgetTester tester) async {
    picker.result = FilePickerResult([
      PlatformFile(
        name: 'replacement.txt',
        size: 100,
        bytes: Uint8List.fromList(
          utf8.encode('Nội dung tài liệu thay thế. ' * 5),
        ),
      ),
    ]);
    await tester.ensureVisible(find.byType(UploadZone));
    await tester.tap(find.byType(UploadZone));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(393, 852), const Size(1280, 900)]) {
    testWidgets('update upload and accepted navigation at ${size.width}', (
      tester,
    ) async {
      await open(tester, size);
      expect(find.text('Cập nhật tài liệu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_UPDATE'] == '1') {
        await tester.runAsync(() async {
          final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/verification/document-update/update-${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await selectFile(tester);
      final field = find.byKey(const ValueKey('import-document-name'));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        document['name'],
      );
      await tester.scrollUntilVisible(
        find.text('Đọc và cập nhật tài liệu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Đọc và cập nhật tài liệu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đọc và cập nhật tài liệu'));
      await tester.pumpAndSettle();
      expect(posts, hasLength(1));
      expect(posts.single.url.path, '/api/update');
      final body = jsonDecode(posts.single.body) as Json;
      expect(body['documentId'], document['id']);
      expect(body['name'], document['name']);
      expect((body['files'] as List).single['name'], 'replacement.txt');
      expect(find.text('Mở tài liệu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancel picker or back leaves source screen untouched', (
    tester,
  ) async {
    await open(tester, const Size(393, 852));
    await tester.tap(find.byType(UploadZone));
    await tester.pumpAndSettle();
    expect(find.text('Đọc và cập nhật tài liệu'), findsNothing);
    expect(posts, isEmpty);
    Navigator.of(tester.element(find.byType(ImportScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DocumentScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tạo bộ đề'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tạo bộ đề'), findsOneWidget);
    expect(find.text('Bài tập tiếng Anh'), findsWidgets);
  });

  testWidgets('failed submission retains selected replacement for retry', (
    tester,
  ) async {
    fail = true;
    await open(tester, const Size(393, 852));
    await selectFile(tester);
    await tester.scrollUntilVisible(
      find.text('Đọc và cập nhật tài liệu'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Đọc và cập nhật tài liệu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đọc và cập nhật tài liệu'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);
    expect(find.text('1. replacement.txt'), findsOneWidget);
    expect(find.text('Không gửi được bản cập nhật'), findsOneWidget);
    expect(posts, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
