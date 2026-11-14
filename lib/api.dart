import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'task_progress.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${UniqueKey()}';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class LocalApi {
  String base;
  String? token;
  String? session;
  void Function()? onSessionExpired;
  final http.Client client;
  LocalApi(this.base, {this.token, http.Client? client})
    : client = client ?? http.Client();

  static String origin(String value) => Uri.parse(value).origin;

  static bool validAddress(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final loopback = uri.host == 'localhost' || uri.host == '127.0.0.1';
    return uri.host.isNotEmpty &&
        RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(uri.host) &&
        ((loopback && uri.scheme == 'http') ||
            (!loopback && uri.scheme == 'https')) &&
        (!loopback || uri.hasPort) &&
        uri.port > 0 &&
        uri.port <= 65535 &&
        (uri.path.isEmpty || uri.path == '/');
  }

  Future<Json> request(String path, [Json? body]) async {
    if (!validAddress(base)) {
      throw ApiException(
        'Dùng HTTP loopback có cổng hoặc HTTPS cho dịch vụ từ xa.',
      );
    }
    try {
      final requestBase = base;
      final requestToken = token;
      final requestSession = session;
      final uri = Uri.parse(
        '${requestBase.replaceAll(RegExp(r'/$'), '')}$path',
      );
      final req = http.Request(body == null ? 'GET' : 'POST', uri)
        ..followRedirects = false;
      req.headers['Content-Type'] = 'application/json';
      if (requestToken != null && requestToken.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $requestToken';
      }
      if (requestSession != null) {
        req.headers['X-QuizMind-Session'] = requestSession;
      }
      if (body != null) req.body = jsonEncode(body);
      final response = await (() async {
        return http.Response.fromStream(await client.send(req));
      })().timeout(Duration(seconds: path == '/api/research' ? 140 : 25));
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) rethrow;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 403 &&
            requestSession != null &&
            requestSession == session) {
          onSessionExpired?.call();
        }
        throw ApiException(
          data is Map && data['error'] is String
              ? data['error']
              : 'Dịch vụ trả HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
      if (data is! Json) throw const FormatException();
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        path == '/api/research'
            ? 'Tra cứu quá thời gian chờ. Hãy đợi một lúc rồi thử lại.'
            : 'Dịch vụ phản hồi chậm. Kiểm tra tác vụ trên Trang chủ trước khi thử lại.',
      );
    } on SocketException {
      throw ApiException(
        'Chưa kết nối dịch vụ trên Mac. Mở dịch vụ rồi thử lại.',
      );
    } on http.ClientException {
      throw ApiException('Mất kết nối dịch vụ trên Mac. Hãy thử kết nối lại.');
    } on FormatException {
      throw ApiException('Phản hồi dịch vụ không hợp lệ.');
    }
  }
}

const _builtInRelay = String.fromEnvironment('QUIZMIND_RELAY_URL');
const _builtInRelayToken = String.fromEnvironment('QUIZMIND_RELAY_TOKEN');

class JobNotice {
  final String name;
  final bool success;
  final String? error;
  const JobNotice({required this.name, required this.success, this.error});
}

class AppController extends ChangeNotifier {
  final SharedPreferences prefs;
  final bool requireAccount;
  final FlutterSecureStorage secureStorage;
  Json? user;
  bool restoringAccount = false;
  String? accountError;
  Future<void> _storageWork = Future.value();
  String get _sessionKey => 'quizmind-session-${LocalApi.origin(api.base)}';
  String localKey(String key) => requireAccount
      ? '${LocalApi.origin(api.base)}:${user?['id'] ?? 'signed-out'}:$key'
      : key;

  Future<void> _saveSession(String key, String? value) {
    final operation = _storageWork.then(
      (_) => value == null
          ? secureStorage.delete(key: key)
          : secureStorage.write(key: key, value: value),
    );
    _storageWork = operation.catchError((Object _) {});
    return operation;
  }

  void _clearAccount() {
    timer?.cancel();
    user = null;
    api.session = null;
    connectionGeneration++;
    state = {'documents': [], 'quizzes': [], 'jobs': [], 'attempts': []};
    connected = false;
    refreshing = false;
    authenticationRequired = false;
    _refreshGeneration = null;
    _hasLoadedState = false;
    _jobNotice = null;
    _pendingActions.clear();
    _syncProgress(reset: true);
  }

  void _expireAccount() {
    if (!requireAccount || closed) return;
    final key = _sessionKey;
    _clearAccount();
    accountError = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    unawaited(_saveSession(key, null).catchError((Object _) {}));
    notifyListeners();
  }

  Future<void> restoreAccount() async {
    if (restoringAccount || closed) return;
    restoringAccount = true;
    accountError = null;
    notifyListeners();
    final generation = connectionGeneration;
    try {
      await _storageWork;
      final saved = await secureStorage.read(key: _sessionKey);
      if (closed || generation != connectionGeneration) return;
      if (saved != null) {
        api.session = saved;
        final result = await api.request('/api/auth/me');
        if (closed || generation != connectionGeneration) return;
        user = _accountUser(result['user']);
      }
    } catch (e) {
      if (!closed && generation == connectionGeneration) {
        api.session = null;
        accountError = e is ApiException
            ? e.toString()
            : 'Không đọc được phiên đã lưu. Hãy thử lại hoặc đăng nhập.';
      }
    } finally {
      restoringAccount = false;
      if (!closed) {
        notifyListeners();
        if (user != null) _startPolling();
      }
    }
  }

  Json _accountUser(dynamic value) {
    if (value is! Json ||
        value['id'] is! String ||
        value['email'] is! String ||
        value['name'] is! String ||
        !['user', 'teacher', 'student'].contains(value['role'])) {
      throw ApiException('Thông tin tài khoản không hợp lệ.');
    }
    return value;
  }

  Future<void> authenticate({
    required String email,
    required String password,
    String? name,
    String role = 'user',
  }) async {
    final generation = connectionGeneration;
    final key = _sessionKey;
    final result = await api.request(
      name == null ? '/api/auth/login' : '/api/auth/register',
      {
        'email': email.trim(),
        'password': password,
        if (name != null) 'name': name.trim(),
        if (name != null) 'role': role,
      },
    );
    final nextUser = _accountUser(result['user']);
    final session = result['session'];
    if (session is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(session)) {
      throw ApiException('Phiên đăng nhập không hợp lệ.');
    }
    if (closed || generation != connectionGeneration) return;
    try {
      await _saveSession(key, session);
    } catch (_) {
      throw ApiException(
        'Không lưu được phiên an toàn trên thiết bị. Hãy thử đăng nhập lại.',
      );
    }
    if (closed || generation != connectionGeneration) return;
    _clearAccount();
    user = nextUser;
    api.session = session;
    accountError = null;
    error = null;
    notifyListeners();
    _startPolling();
  }

  Future<void> logout() async {
    final key = _sessionKey;
    // Capture credentials before clearing state; never send logout for a later account.
    final revoke = api.request('/api/auth/logout', {}).then<void>((_) {});
    // Attach a handler immediately while secure storage is being cleared.
    final revocation = revoke.then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    _clearAccount();
    accountError = null;
    notifyListeners();

    Object? failure;
    try {
      await _saveSession(key, null);
    } catch (e) {
      failure = e;
    }
    final revokeFailure = await revocation;
    failure ??= revokeFailure;
    if (failure != null && !closed && user == null) {
      accountError = 'Đã thoát trên ứng dụng; chưa xác nhận xóa phiên đã lưu hoặc thu hồi trên dịch vụ. Hãy thử lại.';
      notifyListeners();
    }
  }

  final TaskProgress taskProgress;
  final Map<Object, String> _pendingActions = {};
  late final LocalApi api;
  Json state = {'documents': [], 'quizzes': [], 'jobs': [], 'attempts': []};
  bool connected = false, refreshing = false, closed = false;
  String? error;
  Timer? timer;
  int connectionGeneration = 0;
  bool authenticationRequired = false;
  int? _refreshGeneration;
  Completer<void>? _refreshDone;
  JobNotice? _jobNotice;
  bool _hasLoadedState = false;
  AppController(
    this.prefs, {
    LocalApi? api,
    TaskProgress? taskProgress,
    this.requireAccount = false,
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage(),
       taskProgress = taskProgress ?? TaskProgress() {
    this.api =
        api ??
        LocalApi(
          _builtInRelay.isNotEmpty
              ? _builtInRelay
              : (prefs.getString('relay') ?? 'http://127.0.0.1:8787'),
          token: _builtInRelayToken.isNotEmpty ? _builtInRelayToken : null,
        );
    this.api.onSessionExpired = _expireAccount;
  }
  List<Json> items(String key) =>
      ((state[key] as List?) ?? const []).cast<Json>();
  JobNotice? takeJobNotice() {
    final notice = _jobNotice;
    _jobNotice = null;
    return notice;
  }

  void _syncProgress({bool failed = false, bool reset = false}) {
    unawaited(
      taskProgress.sync(
        items('jobs'),
        _pendingActions.values,
        offline: !connected,
        failed: failed,
        reset: reset,
      ),
    );
  }

  void start() {
    if (requireAccount) {
      unawaited(restoreAccount());
    } else {
      _startPolling();
    }
  }

  void _startPolling() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    if (_refreshGeneration == connectionGeneration ||
        closed ||
        authenticationRequired ||
        (requireAccount && user == null)) {
      return;
    }
    refreshing = true;
    final generation = connectionGeneration;
    _refreshGeneration = generation;
    final done = Completer<void>();
    _refreshDone = done;
    try {
      final nextState = await api.request('/api/state');
      if (generation != connectionGeneration || closed) return;
      if (_hasLoadedState) {
        final previousJobs = {for (final job in items('jobs')) job['id']: job};
        for (final job in (nextState['jobs'] as List).cast<Json>()) {
          final stage = job['stage'];
          final previousStage = previousJobs[job['id']]?['stage'];
          if ((stage == 'ready' || stage == 'failed') &&
              previousStage != stage) {
            _jobNotice = JobNotice(
              name: job['name'] as String,
              success: stage == 'ready',
              error: job['error'] as String?,
            );
            break;
          }
        }
      }
      _hasLoadedState = true;
      state = nextState;
      connected = true;
      error = null;
    } catch (e) {
      if (generation != connectionGeneration || closed) return;
      connected = false;
      error = e.toString();
      if (e is ApiException && e.statusCode == 401) {
        authenticationRequired = true;
        timer?.cancel();
      }
    } finally {
      done.complete();
      if (identical(_refreshDone, done)) _refreshDone = null;
      if (generation == connectionGeneration) {
        _refreshGeneration = null;
        refreshing = false;
        if (!closed) {
          _syncProgress();
          notifyListeners();
        }
      }
    }
  }

  Future<Json> send(String path, Json body, {int? expectedGeneration}) async {
    final generation = connectionGeneration;
    if (closed ||
        (expectedGeneration != null && expectedGeneration != generation)) {
      throw ApiException('Kết nối đã thay đổi; thao tác cũ đã bị hủy.');
    }
    final action = Object();
    _pendingActions[action] = switch (path) {
      '/api/import' => 'Đang gửi tài liệu',
      '/api/update' => 'Đang gửi bản cập nhật tài liệu',
      '/api/generate' => 'Đang yêu cầu tạo câu hỏi',
      '/api/chat' => 'AI đang trả lời',
      _ => 'Đang lưu thay đổi',
    };
    _syncProgress();
    late Json result;
    try {
      result = await api.request(path, body);
    } catch (_) {
      if (generation == connectionGeneration && !closed) {
        _pendingActions.remove(action);
        _syncProgress(failed: true);
      }
      if (generation != connectionGeneration || closed) {
        throw ApiException('Kết nối đã thay đổi; bỏ lỗi từ dịch vụ cũ.');
      }
      rethrow;
    }
    if (generation != connectionGeneration || closed) {
      throw ApiException('Kết nối đã thay đổi; thao tác cũ đã bị hủy.');
    }
    // A snapshot requested before this action can omit its newly queued job.
    await _refreshDone?.future;
    if (generation != connectionGeneration || closed) {
      throw ApiException('Kết nối đã thay đổi; thao tác cũ đã bị hủy.');
    }
    await refresh();
    if (generation == connectionGeneration && !closed) {
      _pendingActions.remove(action);
      _syncProgress();
    }
    if (generation != connectionGeneration || closed) {
      throw ApiException('Kết nối đã thay đổi; bỏ kết quả thao tác cũ.');
    }
    return result;
  }

  Future<void> setAddress(String value, {String? token}) async {
    if (!LocalApi.validAddress(value)) {
      throw ApiException(
        'Dùng http://loopback:cổng hoặc https://tên-máy:cổng.',
      );
    }
    final canonical = LocalApi.origin(value);
    final originChanged = LocalApi.origin(api.base) != canonical;
    final nextToken = token ?? (originChanged ? null : api.token);
    if (nextToken != null &&
        nextToken.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(nextToken)) {
      throw ApiException('Mã truy cập relay phải là token 43 ký tự.');
    }
    final changed = originChanged || api.token != nextToken;
    if (changed) {
      _pendingActions.clear();
      _syncProgress(reset: true);
      connectionGeneration++;
      state = {'documents': [], 'quizzes': [], 'jobs': [], 'attempts': []};
      connected = false;
      error = null;
      refreshing = false;
      _refreshGeneration = null;
      _jobNotice = null;
      _hasLoadedState = false;
    }
    if (changed && requireAccount) _clearAccount();
    api.base = canonical;
    api.token = nextToken == null || nextToken.isEmpty ? null : nextToken;
    authenticationRequired = false;
    final generation = connectionGeneration;
    notifyListeners();
    await prefs.setString('relay', canonical);
    if (changed && !requireAccount) {
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith('draft-'),
      )) {
        await prefs.remove(key);
      }
    }
    if (closed || generation != connectionGeneration) return;
    if (requireAccount && user == null) {
      await restoreAccount();
      return;
    }
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    await refresh();
  }

  @override
  void dispose() {
    _pendingActions.clear();
    _syncProgress(reset: true);
    closed = true;
    timer?.cancel();
    api.client.close();
    super.dispose();
  }
}
