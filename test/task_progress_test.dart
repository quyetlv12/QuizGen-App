import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/task_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/progress');
  late List<Map<dynamic, dynamic>> calls;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.arguments as Map);
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'historical jobs do not start an activity; tracks real stages and failure',
    () async {
      final progress = TaskProgress(channel: channel);
      await progress.sync([
        {'id': 'old', 'stage': 'failed'},
      ], []);
      expect(calls.single['reset'], true);
      expect(calls.single['count'], 0);
      await progress.sync([], []);
      expect(calls, hasLength(1));
      await progress.sync([
        {'id': 'new', 'stage': 'extracting', 'name': 'private'},
      ], []);
      expect(calls.last['status'], 'Đang đọc tài liệu');
      expect(calls.last.toString(), isNot(contains('private')));
      await progress.sync([
        {'id': 'new', 'stage': 'failed'},
      ], []);
      expect(calls.last['failed'], true);
      expect(calls.last['count'], 0);
    },
  );

  test(
    'concurrent tasks, offline state, completion and connection reset',
    () async {
      final progress = TaskProgress(channel: channel);
      await progress.sync(
        [
          {'id': '1', 'stage': 'generating'},
        ],
        ['AI đang trả lời'],
      );
      expect(calls.last['count'], 2);
      await progress.sync(
        [
          {'id': '1', 'stage': 'generating'},
        ],
        [],
        offline: true,
      );
      expect(calls.last['status'], contains('Mất kết nối'));
      await progress.sync([], []);
      expect(calls.last['status'], 'Đã hoàn tất');
      await progress.sync([], ['Đang lưu']);
      await progress.sync([], [], reset: true);
      expect(calls.last['reset'], true);
      expect(calls.last['count'], 0);
    },
  );

  test('platform failure never fails the backend operation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'disabled'),
        );
    await TaskProgress(channel: channel).sync([], ['Đang lưu']);
  });

  test('failure survives overlapping actions until they finish', () async {
    final progress = TaskProgress(channel: channel);
    await progress.sync([], ['Đang lưu', 'AI đang trả lời']);
    await progress.sync([], ['AI đang trả lời'], failed: true);
    await progress.sync([], []);
    expect(calls.last['failed'], true);
    await progress.sync([], ['Đang lưu']);
    await progress.sync([], []);
    expect(calls.last['failed'], false);
  });
}
