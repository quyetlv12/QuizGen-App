import 'dart:convert';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixturePicker extends FilePicker {
  FilePickerResult? result;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

class NoCamera extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => [];
}

void main() {
  late AppController controller;
  late List<Json> submissions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    submissions = [];
    controller = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'http://localhost:8787',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            submissions.add(jsonDecode(request.body) as Json);
            return http.Response('{"id":"job"}', 200);
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

  Future<void> open(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => screen),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
  }

  Json document() => {
    'id': 'document-one',
    'name': 'Tên cũ',
    'pages': ['Nội dung tài liệu đã đọc.'],
    'warnings': [],
    'createdAt': 1,
  };

  testWidgets(
    'import requires a typed name, never uses the filename as fallback',
    (tester) async {
      await open(tester, ImportScreen(c: controller));
      await tester.scrollUntilVisible(
        find.text('Thư viện tài liệu mẫu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Thư viện tài liệu mẫu'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('import-document-name'));
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
      await tester.scrollUntilVisible(
        find.text('Đọc nội dung tài liệu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Đọc nội dung tài liệu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đọc nội dung tài liệu'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập tên tài liệu.'), findsOneWidget);
      expect(submissions, isEmpty);
      await tester.scrollUntilVisible(
        field,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, '   ');
      await tester.scrollUntilVisible(
        find.text('Đọc nội dung tài liệu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Đọc nội dung tài liệu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đọc nội dung tài liệu'));
      await tester.pumpAndSettle();
      expect(submissions, isEmpty);
      await tester.scrollUntilVisible(
        field,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, '  Sinh học — Chương 1  ');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.scrollUntilVisible(
        find.text('Đọc nội dung tài liệu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Đọc nội dung tài liệu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đọc nội dung tài liệu'));
      await tester.pumpAndSettle();
      expect(submissions.single['name'], 'Sinh học — Chương 1');
      expect(
        (submissions.single['files'] as List).single['name'],
        'Thư viện Mây — tài liệu mẫu.txt',
      );
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  void expectNameVisible(WidgetTester tester) {
    final field = find.byKey(const ValueKey('import-document-name'));
    expect(field.hitTestable(), findsOneWidget);
    final rect = tester.getRect(field);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      ),
    );
  }

  for (final size in [const Size(320, 740), const Size(800, 600)]) {
    testWidgets(
      'upload reveals mandatory name at $size; cancel/error retain it',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        FilePickerIO.registerWith();
        final original = FilePicker.platform;
        final picker = FixturePicker();
        FilePicker.platform = picker;
        addTearDown(() => FilePicker.platform = original);
        final bytes = (await rootBundle.load('assets/sample.txt')).buffer
            .asUint8List();
        picker.result = FilePickerResult([
          PlatformFile(name: 'source.txt', size: bytes.length, bytes: bytes),
        ]);
        await open(tester, ImportScreen(c: controller));
        await tapVisible(tester, find.byType(UploadZone));
        expectNameVisible(tester);
        final field = find.byKey(const ValueKey('import-document-name'));
        expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
        await tester.enterText(field, '   ');
        await tapVisible(tester, find.text('Đọc nội dung tài liệu'));
        expect(submissions, isEmpty);
        await tester.scrollUntilVisible(
          field,
          -180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Vui lòng nhập tên tài liệu.'), findsOneWidget);
        await tester.enterText(field, '  Tên upload  ');
        tester.testTextInput.hide();
        FocusManager.instance.primaryFocus?.unfocus();
        picker.result = null;
        await tapVisible(tester, find.byType(UploadZone));
        // Cancel must keep both the title and the existing file.
        await tester.scrollUntilVisible(
          field,
          -180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<TextFormField>(field).controller!.text,
          '  Tên upload  ',
        );
        picker.result = FilePickerResult([
          PlatformFile(name: 'empty.txt', size: 0, bytes: Uint8List(0)),
        ]);
        await tapVisible(tester, find.byType(UploadZone));
        expect(submissions, isEmpty);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Đọc nội dung tài liệu'));
        expect(submissions.single['name'], 'Tên upload');
        final sent = (submissions.single['files'] as List).single;
        expect(sent['name'], 'source.txt');
        expect(base64Decode(sent['data'] as String), bytes);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'scan callback reveals name, preserves it on added page and cancel',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = CameraPlatform.instance;
      CameraPlatform.instance = NoCamera();
      addTearDown(() => CameraPlatform.instance = original);
      final bytes = (await rootBundle.load('assets/robot.png')).buffer
          .asUint8List();
      await open(tester, ImportScreen(c: controller));
      Future<void> scanPage(String name) async {
        await tapVisible(tester, find.text('Chụp hoặc quét tài liệu'));
        final scanner = tester.widget<ScanScreen>(find.byType(ScanScreen));
        expect(
          await scanner.onCapture(XFile.fromData(bytes, path: name)),
          isTrue,
        );
        Navigator.of(tester.element(find.byType(ScanScreen))).pop();
        await tester.pumpAndSettle();
        expectNameVisible(tester);
      }

      await scanPage('page-one.png');
      final field = find.byKey(const ValueKey('import-document-name'));
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
      await tapVisible(tester, find.text('Đọc nội dung tài liệu'));
      expect(submissions, isEmpty);
      await tester.scrollUntilVisible(
        field,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, '  Tên bản quét  ');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await scanPage('page-two.png');
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '  Tên bản quét  ',
      );
      await tapVisible(tester, find.text('Chụp hoặc quét tài liệu'));
      final scanner = tester.widget<ScanScreen>(find.byType(ScanScreen));
      await expectLater(
        scanner.onCapture(XFile.fromData(Uint8List(0), path: 'empty.png')),
        throwsA(isA<ApiException>()),
      );
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        field,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '  Tên bản quét  ',
      );
      await tapVisible(tester, find.text('Đọc nội dung tài liệu'));
      expect(submissions.single['name'], 'Tên bản quét');
      final sent = submissions.single['files'] as List;
      expect(sent.map((f) => f['name']), ['page-one.png', 'page-two.png']);
      expect(
        sent.every(
          (f) => base64Decode(f['data'] as String).length == bytes.length,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bell shows actual system jobs, live updates, empty and connection error',
    (tester) async {
      controller.connected = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: HomeScreen(c: controller, initialTab: 3),
        ),
      );
      expect(find.byKey(const ValueKey('relay-address')), findsNothing);
      expect(find.byKey(const ValueKey('relay-token')), findsNothing);
      expect(find.text('Tài liệu của bạn'), findsOneWidget);
      await tester.tap(find.byTooltip('Thông báo hệ thống'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thông báo'), findsOneWidget);
      controller.state['jobs'] = [
        {'id': 'scan-job', 'name': 'Đọc bản quét', 'stage': 'extracting'},
        {
          'id': 'quiz-job',
          'name': 'Tạo bộ đề',
          'stage': 'failed',
          'error': 'Không đọc được nguồn.',
        },
      ];
      controller.notifyListeners();
      await tester.pump();
      expect(find.text('Chưa có thông báo'), findsNothing);
      expect(find.text('Đang đọc tài liệu'), findsOneWidget);
      expect(find.text('Không đọc được nguồn.'), findsOneWidget);
      controller.state['documents'] = [document()];
      controller.state['jobs'] = [
        {
          'id': 'scan-job',
          'name': 'Đọc bản quét',
          'stage': 'ready',
          'documentId': 'document-one',
        },
      ];
      controller.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('Đọc bản quét'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(DocumentScreen))).pop();
      await tester.pumpAndSettle();
      controller.connected = false;
      controller.error = 'Phiên xác thực đã hết hạn.';
      controller.notifyListeners();
      await tester.pump();
      expect(find.text('Phiên xác thực đã hết hạn.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generation validates name and custom integer count before sending',
    (tester) async {
      await open(tester, DocumentScreen(c: controller, document: document()));
      final name = find.byKey(const ValueKey('generate-document-name'));
      final count = find.byKey(const ValueKey('question-count'));
      expect(tester.widget<TextFormField>(name).controller!.text, 'Tên cũ');
      await tester.enterText(name, '   ');
      await tester.tap(find.text('Tạo câu hỏi với AI'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập tên tài liệu.'), findsOneWidget);
      expect(submissions, isEmpty);
      await tester.ensureVisible(name);
      await tester.enterText(name, '  Tên tài liệu đã đặt  ');
      for (final invalid in ['', '0', '101', '1.5', '-1', 'abc']) {
        await tester.ensureVisible(count);
        await tester.enterText(count, invalid);
        await tester.tap(find.text('Tạo câu hỏi với AI'));
        await tester.pumpAndSettle();
        expect(
          find.text('Vui lòng nhập số nguyên từ 1 đến 100.'),
          findsOneWidget,
        );
        expect(submissions, isEmpty);
      }
      await tester.ensureVisible(count);
      await tester.enterText(count, '1');
      await tester.tap(find.text('Tạo câu hỏi với AI'));
      await tester.pumpAndSettle();
      expect(submissions.single['count'], 1);
      expect(submissions.single['name'], 'Tên tài liệu đã đặt');
      expect(submissions.single['documentId'], 'document-one');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick choices update custom count; boundaries fit a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, DocumentScreen(c: controller, document: document()));
      final count = find.byKey(const ValueKey('question-count'));
      await tester.ensureVisible(find.text('15 câu'));
      await tester.tap(find.text('15 câu'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(count).controller!.text, '15');
      await tester.ensureVisible(count);
      await tester.enterText(count, '100');
      await tester.tap(find.text('Tạo câu hỏi với AI'));
      await tester.pumpAndSettle();
      expect(submissions.single['count'], 100);
      expect(tester.takeException(), isNull);
    },
  );
}
