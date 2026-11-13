import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAudioCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async => 'assets/$fileName';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final audioCalls = <MethodCall>[];
  bool audioFails = false;
  setUp(() {
    audioCalls.clear();
    audioFails = false;
    AudioCache.instance = TestAudioCache();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        audioCalls.add(call);
        final args = call.arguments as Map;
        final events = 'xyz.luan/audioplayers/events/${args['playerId']}';
        if (call.method == 'create') {
          messenger.setMockMethodCallHandler(
            MethodChannel(events),
            (_) async => null,
          );
        }
        if (audioFails && call.method == 'stop') {
          throw PlatformException(code: 'audio-unavailable');
        }
        if (call.method == 'setSourceUrl') {
          messenger.handlePlatformMessage(
            events,
            const StandardMethodCodec().encodeSuccessEnvelope({
              'event': 'audio.onPrepared',
              'value': true,
            }),
            (_) {},
          );
        }
        return null;
      },
    );
  });
  testWidgets('tab motion keeps state and follows the latest rapid tap', (
    tester,
  ) async {
    var index = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: SmoothTabBody(
                index: index,
                children: const [
                  TextField(key: ValueKey('draft')),
                  Center(child: Text('Second tab')),
                  Center(child: Text('Third tab')),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('draft')),
      'Keep my draft',
    );
    update(() => index = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // The outgoing page is still the only visible page before the fade ends.
    expect(find.text('Second tab'), findsNothing);
    update(() => index = 2);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Third tab'), findsOneWidget);
    expect(find.text('Second tab'), findsNothing);
    update(() => index = 0);
    await tester.pumpAndSettle();
    expect(find.text('Keep my draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'relay confines calls to loopback and does not follow redirects',
    () async {
      for (final value in [
        'https://127.0.0.1:8787',
        'http://example.com:8787',
        'http://127.0.0.1:8787/evil',
        'http://key@localhost:8787',
        'http://localhost:8787?x=1',
      ]) {
        expect(LocalApi.validAddress(value), isFalse);
      }
      final api = LocalApi(
        'http://127.0.0.1:8787',
        client: MockClient((request) async {
          expect(request.followRedirects, isFalse);
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            '{"error":"Kết nối thất bại"}',
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await expectLater(
        api.request('/api/connection'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Kết nối thất bại',
          ),
        ),
      );
      api.client.close();
    },
  );

  testWidgets('empty library uses real counts and opens import', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance())
      ..connected = true;
    await tester.pumpWidget(QuizMindApp(controller: c));
    await tester.scrollUntilVisible(find.text('Thư viện đang chờ bạn'), 250);
    expect(find.text('Thư viện đang chờ bạn'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tạo bài trắc nghiệm'), -250);
    await tester.tap(find.text('Tạo bài trắc nghiệm'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn tệp từ thiết bị'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Thử bằng tài liệu mẫu'), 200);
    await tester.tap(find.text('Thử bằng tài liệu mẫu'));
    await tester.pumpAndSettle();
    expect(find.text('Xem lại 1 tệp'), findsOneWidget);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  testWidgets('quiz restores draft and submits stable attempt id', (
    tester,
  ) async {
    final quiz = <String, dynamic>{
      'id': 'quiz-one',
      'title': 'Tài liệu mẫu',
      'questions': [
        {
          'question': 'Thư viện mở lúc mấy giờ?',
          'options': ['8 giờ', '9 giờ', '10 giờ', '11 giờ'],
          'correct': 0,
          'explanation': 'Nguồn ghi thư viện mở cửa lúc 8 giờ.',
          'page': 1,
          'quote': 'Thư viện mở cửa lúc 8 giờ.',
        },
      ],
    };
    SharedPreferences.setMockInitialValues({
      'draft-quiz-one': jsonEncode({
        'id': 'stable-attempt',
        'answers': [0],
      }),
    });
    var submissions = 0;
    final c = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'http://localhost:8787',
        client: MockClient((request) async {
          if (request.url.path == '/api/attempts') {
            submissions++;
            final body = jsonDecode(request.body);
            expect(body['id'], 'stable-attempt');
            expect(body['answers'], [0]);
            return http.Response(
              jsonEncode({
                'id': body['id'],
                'score': 1,
                'total': 1,
                'answers': [0],
                'createdAt': 1,
              }),
              200,
            );
          }
          return http.Response(
            '{"documents":[],"quizzes":[],"jobs":[],"attempts":[]}',
            200,
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: QuizScreen(c: c, quiz: quiz),
      ),
    );
    expect(find.text('1 đã trả lời'), findsOneWidget);
    await tester.tap(find.text('Nộp bài'));
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(find.text('1/1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Xem đáp án & giải thích'), 200);
    await tester.tap(find.text('Xem đáp án & giải thích'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('NGUỒN · TRANG 1'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('NGUỒN · TRANG 1'), findsOneWidget);
    expect(c.prefs.getString('draft-quiz-one'), isNull);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  testWidgets('library search filters saved documents and reports no matches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance());
    c.state['documents'] = [
      for (final name in ['Sinh học.pdf', 'Lịch sử.txt'])
        {
          'id': name,
          'name': name,
          'pages': ['Nội dung'],
          'warnings': [],
          'createdAt': 1,
        },
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: HomeScreen(c: c, initialTab: 1),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Sinh');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Sinh học.pdf'),
      200,
      scrollable: pageScroll(),
    );
    expect(find.text('Sinh học.pdf'), findsOneWidget);
    expect(find.text('Lịch sử.txt'), findsNothing);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -200,
      scrollable: pageScroll(),
    );
    await tester.enterText(find.byType(TextField), 'không tồn tại');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Không tìm thấy tài liệu'),
      200,
      scrollable: pageScroll(),
    );
    expect(find.text('Không tìm thấy tài liệu'), findsOneWidget);
    expect(find.text('Sinh học.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('answers show immediate feedback and preserve it on return', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: QuizScreen(c: c, quiz: quizFixture()),
      ),
    );
    expect(find.text('Chính xác!'), findsNothing);
    expect(find.text('Chưa chính xác'), findsNothing);
    expect(audioCalls, isEmpty);
    await tester.tap(find.text('Lựa chọn 2'));
    await tester.pump();
    expect(find.text('Chưa chính xác'), findsOneWidget);
    expect(find.text('Đáp án đúng: A. Lựa chọn 1'), findsOneWidget);
    expect(find.text('Giải thích câu 1'), findsOneWidget);
    expect(
      audioCalls.where((c) => c.method == 'setSourceUrl').last.arguments['url'],
      'assets/audio/incorrect.mp3',
    );
    expect(audioCalls.any((c) => c.method == 'resume'), isTrue);
    expect(jsonDecode(c.prefs.getString('draft-review-quiz')!)['answers'], [
      1,
      -1,
    ]);
    await tester.tap(find.text('Câu tiếp theo'));
    await tester.pump();
    expect(find.text('Chưa chính xác'), findsNothing);
    expect(find.text('Đáp án đúng: A. Lựa chọn 1'), findsNothing);
    await tester.tap(find.text('Lựa chọn 1'));
    await tester.pump();
    expect(find.text('Chính xác!'), findsOneWidget);
    expect(
      audioCalls.where((c) => c.method == 'setSourceUrl').last.arguments['url'],
      'assets/audio/correct.mp3',
    );
    final playCount = audioCalls.where((c) => c.method == 'resume').length;
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Câu trước'));
    await tester.pump();
    expect(find.text('Chưa chính xác'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: QuizScreen(c: c, quiz: quizFixture()),
      ),
    );
    expect(find.text('Chưa chính xác'), findsOneWidget);
    expect(audioCalls.where((c) => c.method == 'resume').length, playCount);
    audioFails = true;
    await tester.tap(find.text('Lựa chọn 1'));
    await tester.pumpAndSettle();
    expect(find.text('Chính xác!'), findsOneWidget);
    expect(jsonDecode(c.prefs.getString('draft-review-quiz')!)['answers'], [
      0,
      0,
    ]);
    expect(tester.takeException(), isNull);
    audioFails = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    expect(audioCalls.where((c) => c.method == 'dispose').length, 2);
    c.dispose();
  });

  testWidgets('mark, skip and jump preserve answers and restore position', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance());
    final quiz = quizFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: QuizScreen(c: c, quiz: quiz),
      ),
    );
    await tester.tap(find.text('Lựa chọn 1'));
    await tester.scrollUntilVisible(find.text('Đánh dấu'), 200);
    await tester.ensureVisible(find.text('Đánh dấu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đánh dấu'));
    await tester.pump();
    await tester.tap(find.text('Bỏ qua'));
    await tester.pump();
    var draft = jsonDecode(c.prefs.getString('draft-review-quiz')!);
    expect(draft['answers'], [0, -1]);
    expect(draft['index'], 1);
    expect(draft['marked'], [0]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: QuizScreen(c: c, quiz: quiz),
      ),
    );
    expect(find.text('Câu 2 / 2'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Câu 1'), 200);
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Câu 1'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pump();
    expect(find.text('Câu 1 / 2'), findsOneWidget);
    draft = jsonDecode(c.prefs.getString('draft-review-quiz')!);
    expect(draft['answers'], [0, -1]);
    expect(draft['index'], 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('wrong review filters answers and keeps source quotations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: ResultScreen(
          c: c,
          quiz: quizFixture(),
          attempt: {
            'id': 'result',
            'score': 1,
            'total': 2,
            'answers': [0, 1],
            'createdAt': 1,
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Ôn lại câu sai'), 200);
    await tester.tap(find.text('Ôn lại câu sai'));
    await tester.pumpAndSettle();
    expect(find.text('Câu 1 · Chính xác'), findsNothing);
    expect(find.text('Câu 2 · Cần ôn lại'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('NGUỒN · TRANG 2'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.textContaining('Trích dẫn trang 2', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('main screens fit small text-scaled phones and tablets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance());
    final document = {
      'id': 'doc',
      'name': 'Tài liệu sinh học.pdf',
      'pages': ['Nguồn tài liệu'],
      'warnings': [],
      'createdAt': 1,
    };
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(320, 740), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      for (final screen in <Widget>[
        HomeScreen(c: c),
        HomeScreen(c: c, initialTab: 1),
        DocumentScreen(c: c, document: document),
        QuizScreen(c: c, quiz: quizFixture()),
        ResultScreen(
          c: c,
          quiz: quizFixture(),
          attempt: {
            'id': 'a',
            'score': 1,
            'total': 2,
            'answers': [0, 1],
            'createdAt': 1,
          },
        ),
        ScanScreen(onPhoto: (_) async => false, onCapture: (_) async => false),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: appTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width < 400 ? 1.25 : 1),
              ),
              child: child!,
            ),
            home: screen,
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} at $size',
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}

Map<String, dynamic> quizFixture() => {
  'id': 'review-quiz',
  'title': 'Ôn tập sinh học',
  'questions': [
    for (int i = 1; i <= 2; i++)
      {
        'question': 'Nội dung câu hỏi $i?',
        'options': ['Lựa chọn 1', 'Lựa chọn 2', 'Lựa chọn 3', 'Lựa chọn 4'],
        'correct': 0,
        'explanation': 'Giải thích câu $i',
        'page': i,
        'quote': 'Trích dẫn trang $i',
      },
  ],
};

Finder pageScroll() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;
