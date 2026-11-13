import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const stateBody = '{"documents":[],"quizzes":[],"jobs":[],"attempts":[]}';
final tokenA = List.filled(43, 'A').join();
final tokenB = List.filled(43, 'B').join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
