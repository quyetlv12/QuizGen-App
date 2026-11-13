import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sends only generic task states to the Lock Screen; no document/chat content.
class TaskProgress {
  TaskProgress({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('quizmind/progress');

  final MethodChannel _channel;
  Future<void> _queue = Future.value();
  bool _active = false;
  bool _initialized = false;
  bool _failed = false;
  final Set<String> _trackedJobs = {};

  Future<void> sync(
    List<Map<String, dynamic>> jobs,
    Iterable<String> pending, {
    bool offline = false,
    bool failed = false,
    bool reset = false,
  }) {
    const labels = {
      'queued': 'Đang chờ xử lý',
      'extracting': 'Đang đọc tài liệu',
      'generating': 'AI đang tạo câu hỏi',
      'validating': 'Đang đối chiếu nguồn',
    };
    final active = jobs
        .where((job) => labels.containsKey(job['stage']))
        .toList();
    failed |= jobs.any(
      (job) => _trackedJobs.contains(job['id']) && job['stage'] == 'failed',
    );
    _failed = (_active && _failed) || failed;
    failed = _failed;
    _trackedJobs
      ..clear()
      ..addAll(active.map((job) => job['id'].toString()));
    final count = active.length + pending.length;
    if (!_active && count == 0 && !reset) {
      if (_initialized) return _queue;
      reset = true; // Remove an activity left behind by a previous app process.
    }
    _initialized = true;
    final status = offline
        ? 'Mất kết nối. Mở app để kiểm tra'
        : active.isNotEmpty
        ? labels[active.first['stage']]!
        : pending.isNotEmpty
        ? pending.first
        : failed
        ? 'Tác vụ chưa hoàn tất. Mở app để kiểm tra'
        : 'Đã hoàn tất';
    _active = count > 0 && !reset;
    final payload = {
      'count': reset ? 0 : count,
      'status': status,
      'failed': failed,
      'reset': reset,
    };
    _queue = _queue.then((_) async {
      if (defaultTargetPlatform != TargetPlatform.iOS) return;
      try {
        await _channel.invokeMethod<void>('sync', payload);
      } on MissingPluginException {
        // Other platforms and tests have no ActivityKit bridge.
      } on PlatformException {
        // Live Activities being unavailable must never interrupt the operation.
      }
    });
    return _queue;
  }
}
