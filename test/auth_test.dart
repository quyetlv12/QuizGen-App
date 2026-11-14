import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quizmind/api.dart';
import 'package:quizmind/auth_screen.dart';
import 'package:quizmind/main.dart';
import 'package:quizmind/theme.dart';
import 'package:quizmind/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const session = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const relay = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const user = {
  'id': 'one',
  'name': 'An Nguyễn',
  'email': 'an@example.com',
  'role': 'teacher',
};
const empty = {'documents': [], 'quizzes': [], 'jobs': [], 'attempts': []};
http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  Future<AppController> controller(
    FutureOr<http.Response> Function(http.Request) handler,
  ) async => AppController(
    await SharedPreferences.getInstance(),
    requireAccount: true,
    api: LocalApi(
      'http://127.0.0.1:8787',
      token: relay,
      client: MockClient((request) async => handler(request)),
    ),
  );

  test('restores verified account with both credentials; logout clears state and vault', () async {
    FlutterSecureStorage.setMockInitialValues({
      'quizmind-session-http://127.0.0.1:8787': session,
    });
    final calls = <http.Request>[];
    final c = await controller((r) {
      calls.add(r);
      expect(r.headers['Authorization'], 'Bearer $relay');
      expect(r.headers['X-QuizMind-Session'], session);
      return response(r.url.path.endsWith('/me') ? {'user': user} : empty);
    });
    addTearDown(c.dispose);
    await c.restoreAccount();
    expect(c.user, user);
    await c.refresh();
    await c.logout();
    expect(c.user, isNull);
    expect(c.api.session, isNull);
    expect(c.items('documents'), isEmpty);
    expect(calls.last.url.path, '/api/auth/logout');
    expect(
      await const FlutterSecureStorage().read(
        key: 'quizmind-session-http://127.0.0.1:8787',
      ),
      isNull,
    );
  });

  test(
    'register sends chosen role, persists session, and namespaces local drafts',
    () async {
      Json? payload;
      final c = await controller((r) {
        if (r.url.path == '/api/auth/register') {
          payload = jsonDecode(r.body) as Json;
          return response({'user': user, 'session': session});
        }
        expect(r.headers['X-QuizMind-Session'], session);
        return response(empty);
      });
      addTearDown(c.dispose);
      await c.authenticate(
        email: ' an@example.com ',
        password: 'password1',
        name: ' An ',
        role: 'teacher',
      );
      expect(payload, {
        'email': 'an@example.com',
        'password': 'password1',
        'name': 'An',
        'role': 'teacher',
      });
      final firstKey = c.localKey('draft-quiz');
      await c.prefs.setString(firstKey, 'private answers');
      c.user = {...user, 'id': 'two'};
      expect(c.localKey('draft-quiz'), isNot(firstKey));
      expect(c.prefs.getString(c.localKey('draft-quiz')), isNull);
      expect(
        await const FlutterSecureStorage().read(
          key: 'quizmind-session-http://127.0.0.1:8787',
        ),
        session,
      );
    },
  );

  test(
    'expired session clears data and rejects an old in-flight snapshot',
    () async {
      final oldSnapshot = Completer<http.Response>();
      final c = await controller((r) {
        if (r.url.path == '/api/state') return oldSnapshot.future;
        return response({'error': 'expired'}, 403);
      });
      addTearDown(c.dispose);
      c.user = user;
      c.api.session = session;
      c.state = {
        ...empty,
        'documents': [
          {'id': 'private'},
        ],
      };
      final refresh = c.refresh();
      final generation = c.connectionGeneration;
      await expectLater(
        c.api.request('/api/research', {}),
        throwsA(isA<ApiException>()),
      );
      expect(c.user, isNull);
      expect(c.connectionGeneration, greaterThan(generation));
      oldSnapshot.complete(
        response({
          ...empty,
          'documents': [
            {'id': 'old'},
          ],
        }),
      );
      await refresh;
      expect(c.items('documents'), isEmpty);
      expect(c.accountError, contains('hết hạn'));
    },
  );

  test(
    'bad login stays on form; offline restoration does not expose saved data',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'quizmind-session-http://127.0.0.1:8787': session,
      });
      final c = await controller(
        (r) => response({
          'error': 'Unavailable',
        }, r.url.path.endsWith('/me') ? 503 : 401),
      );
      addTearDown(c.dispose);
      await c.restoreAccount();
      expect(c.user, isNull);
      expect(c.api.session, isNull);
      expect(c.accountError, 'Unavailable');
      await expectLater(
        c.authenticate(email: 'an@example.com', password: 'wrong'),
        throwsA(isA<ApiException>()),
      );
      expect(c.authenticationRequired, isFalse);
    },
  );

  testWidgets(
    'auth gate, registration validation, and default user registration',
    (tester) async {
      Json? payload;
      final c = await controller((r) {
        if (r.url.path == '/api/auth/register') {
          payload = jsonDecode(r.body) as Json;
          return response({'error': 'Email này đã được đăng ký.'}, 409);
        }
        return response(empty);
      });
      addTearDown(c.dispose);
      await tester.pumpWidget(QuizMindApp(controller: c));
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.ensureVisible(find.text('Đăng ký'));
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tạo tài khoản').last);
      await tester.tap(find.text('Tạo tài khoản').last);
      await tester.pumpAndSettle();
      expect(payload, isNull);
      expect(find.text('Vui lòng nhập email hợp lệ.'), findsOneWidget);
      final fields = find.byType(TextFormField);
      for (final entry in [
        'An',
        'an@example.com',
        'password1',
        'password1',
      ].asMap().entries) {
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      expect(find.text('Bạn là ai?'), findsNothing);
      expect(find.text('Giáo viên'), findsNothing);
      await tester.ensureVisible(find.text('Tạo tài khoản').last);
      await tester.tap(find.text('Tạo tài khoản').last);
      await tester.pumpAndSettle();
      expect(payload?['role'], 'user');
      expect(find.text('Email này đã được đăng ký.'), findsOneWidget);
    },
  );

  for (final register in [false, true]) {
    testWidgets(
      '${register ? 'registration' : 'login'} opens home after authentication',
      (tester) async {
        Json? payload;
        final endpoint = register ? '/api/auth/register' : '/api/auth/login';
        final c = await controller((r) {
          if (r.url.path == endpoint) {
            payload = jsonDecode(r.body) as Json;
            return response({
              'user': {...user, 'role': 'user'},
              'session': session,
            });
          }
          return response(empty);
        });
        addTearDown(c.dispose);
        await tester.pumpWidget(QuizMindApp(controller: c));
        if (register) {
          await tester.ensureVisible(find.text('Đăng ký'));
          await tester.tap(find.text('Đăng ký'));
          await tester.pumpAndSettle();
        }
        final values = register
            ? ['An', 'an@example.com', 'password1', 'password1']
            : ['an@example.com', 'password1'];
        for (final entry in values.asMap().entries) {
          await tester.enterText(
            find.byType(TextFormField).at(entry.key),
            entry.value,
          );
        }
        final action = find.text(register ? 'Tạo tài khoản' : 'Đăng nhập').last;
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(payload?['email'], 'an@example.com');
        if (register) expect(payload?['role'], 'user');
        expect(find.byType(AuthScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(
          tester.widget<StudyNavigation>(find.byType(StudyNavigation)).selected,
          0,
        );
        await c.logout();
        await tester.pumpAndSettle();
        expect(find.byType(AuthScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 393.0, 1280.0]) {
    testWidgets('auth layouts at $width and keyboard remain scrollable', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width == 1280 ? 1000 : 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await controller((_) => response(empty));
      addTearDown(c.dispose);
      final boundary = GlobalKey();
      if (Platform.environment['CAPTURE_AUTH'] == '1') {
        await tester.runAsync(() async {
          await (FontLoader('Arial')..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('/System/Library/Fonts/Supplemental/Arial.ttf')
                        .readAsBytes(),
                  ),
                ),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme().copyWith(
            filledButtonTheme: Platform.environment['CAPTURE_AUTH'] == '1'
                ? FilledButtonThemeData(
                    style: appTheme().filledButtonTheme.style?.copyWith(
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : appTheme().filledButtonTheme,
            textTheme: appTheme().textTheme.apply(
              fontFamily: Platform.environment['CAPTURE_AUTH'] == '1'
                  ? 'Arial'
                  : null,
            ),
          ),
          home: RepaintBoundary(
            key: boundary,
            child: AuthScreen(controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        if (Platform.environment['CAPTURE_AUTH'] != '1') return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final img = await render.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/verification/auth/$name-${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      await capture('login');
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();
      await capture('register');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.tap(find.byType(TextFormField).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tạo tài khoản').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }
}
