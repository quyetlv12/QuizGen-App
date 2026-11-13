import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/ui.dart';
import 'package:quizmind/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const stateBody = '{"documents":[],"quizzes":[],"jobs":[],"attempts":[]}';
final tokenA = List.filled(43, 'A').join();
final tokenB = List.filled(43, 'B').join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat suggestions prepare the selected count without sending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    final c = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'http://127.0.0.1:8787',
        client: MockClient((request) async {
          requests++;
          return http.Response(stateBody, 200);
        }),
      ),
    );
    addTearDown(c.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in [
      const Size(393, 852),
      const Size(1280, 900),
      const Size(320, 740),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width == 320 ? 1.25 : 1),
            ),
            child: child!,
          ),
          home: ChatScreen(c: c),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('15 câu'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('15 câu'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('Sinh học lớp 9')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('Sinh học lớp 9')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Tạo 15 câu Sinh học lớp 9 về hệ hô hấp',
      );
      expect(requests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'chat composer stays above the keyboard at narrow and wide sizes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = AppController(await SharedPreferences.getInstance());
      addTearDown(c.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final size in [
        const Size(393, 852),
        const Size(1280, 900),
        const Size(852, 393),
      ]) {
        tester.view.physicalSize = size;
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpWidget(MaterialApp(home: ChatScreen(c: c)));
        await tester.tap(find.byType(TextField));
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 500 ? 180 : 320,
        );
        await tester.pumpAndSettle();
        final keyboardTop = size.height - tester.view.viewInsets.bottom;
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(keyboardTop),
        );
        expect(
          tester.getRect(find.byTooltip('Gửi yêu cầu')).bottom,
          lessThanOrEqualTo(keyboardTop),
        );
        expect(
          tester.getRect(find.byType(TextField)).top,
          greaterThanOrEqualTo(0),
        );
        await tester.enterText(
          find.byType(TextField),
          'Tạo bộ đề Toán lớp 6\nvề phân số\nvà số thập phân',
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(keyboardTop),
        );
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          greaterThan(keyboardTop),
        );
      }
    },
  );

  testWidgets('floating bot stays fixed on main tabs and opens chat', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController(await SharedPreferences.getInstance());
    addTearDown(c.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(c: c)));
    await tester.pumpAndSettle();
    final bot = find.byType(FloatingActionButton);
    final original = tester.getRect(bot);
    expect(original.right, closeTo(393 - 16, 1));
    expect(find.text('Chat với AI để tạo bộ đề'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(bot), original);
    expect(
      original.bottom,
      lessThan(tester.getRect(find.byType(StudyNavigation)).top),
    );
    for (final tab in ['Tài liệu', 'Bộ đề', 'Cá nhân']) {
      final target = find.descendant(
        of: find.byType(StudyNavigation),
        matching: find.text(tab),
      );
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.getRect(bot), original);
    }
    await tester.tap(bot);
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat validates prompt, blocks duplicate sends and opens generated quiz',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      Json? submitted;
      var posts = 0;
      var stage = 'generating';
      final quiz = <String, dynamic>{
        'id': 'chat-quiz',
        'documentId': 'chat-doc',
        'title': 'Bộ đề từ chat',
        'questions': [
          {
            'question': 'Cơ quan nào trao đổi khí?',
            'options': ['Phổi', 'Tim', 'Gan', 'Dạ dày'],
            'correct': 0,
            'explanation': 'Phổi thực hiện trao đổi khí.',
          },
        ],
      };
      final c = AppController(
        await SharedPreferences.getInstance(),
        api: LocalApi(
          'https://relay.example',
          token: tokenA,
          client: MockClient((request) async {
            if (request.method == 'POST') {
              posts++;
              submitted = jsonDecode(request.body) as Json;
              return http.Response('{"id":"chat-job","stage":"queued"}', 202);
            }
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'documents': [],
                  'attempts': [],
                  'quizzes': stage == 'ready' ? [quiz] : [],
                  'jobs': submitted == null
                      ? []
                      : [
                          {
                            'id': 'chat-job',
                            'requestId': submitted!['requestId'],
                            'name': 'Bộ đề từ chat',
                            'stage': stage,
                            'quizId': 'chat-quiz',
                          },
                        ],
                }),
              ),
              200,
            );
          }),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: ChatScreen(c: c)));
      await tester.enterText(find.byType(TextField), 'ngắn');
      await tester.tap(find.byTooltip('Gửi yêu cầu'));
      await tester.pump();
      expect(posts, 0);
      await tester.enterText(
        find.byType(TextField),
        'Tạo đề Sinh học lớp 9 về hô hấp',
      );
      await tester.tap(find.byTooltip('Gửi yêu cầu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(posts, 1);
      expect(submitted?['count'], 10);
      expect(find.text('AI đang xử lý…'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      stage = 'ready';
      await c.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Mở bộ đề'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await tester.tap(find.text('Mở bộ đề'));
      await tester.pumpAndSettle();
      expect(find.byType(QuizScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  test('HTTPS defaults to port 443, HTTP is confined to explicit loopback', () {
    for (final value in [
      'https://relay.example',
      'https://relay.example:443/',
      'http://127.0.0.1:8787',
    ]) {
      expect(LocalApi.validAddress(value), isTrue, reason: value);
    }
    for (final value in [
      'http://relay.example',
      'http://localhost',
      'https://key@relay.example',
      'https://relay.example/api',
      'https://relay.example?token=x',
      'https://relay.example#secret',
      'https://',
      'https://relay.example:0',
    ]) {
      expect(LocalApi.validAddress(value), isFalse, reason: value);
    }
  });

  test(
    'Bearer snapshot is sent only to selected origin, redirects stay disabled',
    () async {
      final response = Completer<http.Response>();
      final api = LocalApi(
        'https://a.example',
        token: tokenA,
        client: MockClient((request) {
          expect(request.url.origin, 'https://a.example');
          expect(request.headers['Authorization'], 'Bearer $tokenA');
          expect(request.followRedirects, isFalse);
          return response.future;
        }),
      );
      final pending = api.request('/api/state');
      api.base = 'https://b.example';
      api.token = tokenB;
      response.complete(http.Response('{"ok":true}', 200));
      expect(await pending, {'ok': true});
      api.client.close();
    },
  );

  test(
    'HTML/empty errors preserve 401, 403, 429 and never retry POST',
    () async {
      for (final status in [401, 403, 429, 302]) {
        var calls = 0;
        final api = LocalApi(
          'https://relay.example',
          token: tokenA,
          client: MockClient((request) async {
            calls++;
            expect(request.followRedirects, isFalse);
            return http.Response(
              status == 401 ? '' : '<html>error</html>',
              status,
            );
          }),
        );
        await expectLater(
          api.request('/api/import', {'requestId': 'fixture'}),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status),
          ),
        );
        expect(calls, 1);
        api.client.close();
      }
    },
  );

  test(
    'late response/error from A cannot overwrite B, B never receives token A',
    () async {
      for (final lateStatus in [200, 401]) {
        SharedPreferences.setMockInitialValues({
          'draft-old': 'private',
          'relay': 'https://a.example',
        });
        final pendingA = Completer<http.Response>();
        final c = AppController(
          await SharedPreferences.getInstance(),
          api: LocalApi(
            'https://a.example',
            token: tokenA,
            client: MockClient((request) async {
              if (request.url.host == 'a.example') return pendingA.future;
              expect(request.headers['Authorization'], 'Bearer $tokenB');
              return http.Response(stateBody, 200);
            }),
          ),
        );
        final oldRefresh = c.refresh();
        await c.setAddress('https://b.example', token: tokenB);
        pendingA.complete(
          http.Response('{"documents":[{"id":"OLD"}]}', lateStatus),
        );
        await oldRefresh;
        expect(c.items('documents'), isEmpty);
        expect(c.connected, isTrue);
        expect(c.authenticationRequired, isFalse);
        expect(c.prefs.getString('draft-old'), isNull);
        expect(
          c.prefs.getKeys().any((key) => key.toLowerCase().contains('token')),
          isFalse,
        );
        c.dispose();
      }
    },
  );

  test(
    'changing origin clears token and blocks payload held by a stale screen',
    () async {
      SharedPreferences.setMockInitialValues({});
      var posts = 0;
      final c = AppController(
        await SharedPreferences.getInstance(),
        api: LocalApi(
          'https://a.example',
          token: tokenA,
          client: MockClient((request) async {
            if (request.method == 'POST') posts++;
            expect(request.headers.containsKey('Authorization'), isFalse);
            return http.Response(stateBody, 200);
          }),
        ),
      );
      final oldGeneration = c.connectionGeneration;
      await c.setAddress('https://b.example');
      expect(c.api.token, isNull);
      await expectLater(
        c.send('/api/import', {
          'private': 'old-file',
        }, expectedGeneration: oldGeneration),
        throwsA(isA<ApiException>()),
      );
      expect(posts, 0);
      c.dispose();
    },
  );

  test('401 suspends polling until connection is updated', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final c = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'https://relay.example',
        client: MockClient((_) async {
          calls++;
          return http.Response('', 401);
        }),
      ),
    );
    await c.refresh();
    await c.refresh();
    expect(c.authenticationRequired, isTrue);
    expect(calls, 1);
    await c.setAddress('https://relay.example', token: tokenB);
    expect(calls, 2);
    c.dispose();
  });

  test(
    'send waits for a fresh snapshot after an overlapping refresh',
    () async {
      SharedPreferences.setMockInitialValues({});
      final oldSnapshot = Completer<http.Response>();
      final posted = Completer<void>();
      var reads = 0;
      final c = AppController(
        await SharedPreferences.getInstance(),
        api: LocalApi(
          'https://relay.example',
          client: MockClient((request) async {
            if (request.method == 'POST') {
              posted.complete();
              return http.Response('{"id":"new","stage":"queued"}', 202);
            }
            if (++reads == 1) return oldSnapshot.future;
            return http.Response(
              jsonEncode({
                'documents': [],
                'quizzes': [],
                'attempts': [],
                'jobs': [
                  {'id': 'new', 'stage': 'generating', 'name': 'Test'},
                ],
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(c.dispose);
      final refreshing = c.refresh();
      final sending = c.send('/api/generate', {});
      await posted.future;
      oldSnapshot.complete(http.Response(stateBody, 200));
      await refreshing;
      await sending;
      expect(reads, 2);
      expect(c.items('jobs').single['stage'], 'generating');
    },
  );

  test('job completion creates a one-shot notice after initial state load', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final c = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'https://relay.example',
        client: MockClient((_) async {
          calls++;
          final body = calls == 1
              ? '{"documents":[],"quizzes":[],"jobs":[{"id":"job-1","name":"Bộ đề Sinh học","stage":"generating"}],"attempts":[]}'
              : '{"documents":[],"quizzes":[],"jobs":[{"id":"job-1","name":"Bộ đề Sinh học","stage":"ready"}],"attempts":[]}';
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      ),
    );

    await c.refresh();
    expect(c.takeJobNotice(), isNull);
    await c.refresh();
    expect(calls, 2);
    final notice = c.takeJobNotice();
    expect(notice?.name, 'Bộ đề Sinh học');
    expect(notice?.success, isTrue);
    expect(c.takeJobNotice(), isNull);
    c.dispose();
  });

  testWidgets('new connection discards detail routes and old quiz draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'draft-old-quiz': jsonEncode({
        'id': 'old-attempt',
        'answers': [0],
      }),
    });
    final c = AppController(
      await SharedPreferences.getInstance(),
      api: LocalApi(
        'https://a.example',
        token: tokenA,
        client: MockClient((_) async => http.Response(stateBody, 200)),
      ),
    );
    await tester.pumpWidget(QuizMindApp(controller: c));
    openScreen(
      tester.element(find.byType(HomeScreen)),
      QuizScreen(
        c: c,
        quiz: {
          'id': 'old-quiz',
          'title': 'Old private quiz',
          'questions': [
            {
              'question': 'Old private question?',
              'explanation': 'Synthetic explanation.',
              'options': ['A', 'B', 'C', 'D'],
              'correct': 0,
            },
          ],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuizScreen), findsOneWidget);
    await c.setAddress('https://b.example', token: tokenB);
    await tester.pumpAndSettle();
    expect(find.byType(QuizScreen), findsNothing);
    expect(find.text('Tài liệu của bạn'), findsOneWidget);
    expect(find.byKey(const ValueKey('relay-token')), findsNothing);
    expect(c.prefs.getString('draft-old-quiz'), isNull);
    expect(find.text('Old private question?'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
