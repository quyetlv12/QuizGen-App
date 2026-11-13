import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
      final uri = Uri.parse(
        '${requestBase.replaceAll(RegExp(r'/$'), '')}$path',
      );
      final req = http.Request(body == null ? 'GET' : 'POST', uri)
        ..followRedirects = false;
      req.headers['Content-Type'] = 'application/json';
      if (requestToken != null && requestToken.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $requestToken';
      }
      if (body != null) req.body = jsonEncode(body);
      final response = await (() async {
        return http.Response.fromStream(await client.send(req));
      })().timeout(const Duration(seconds: 25));
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) rethrow;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
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
        'Dịch vụ phản hồi chậm. Kiểm tra tác vụ trên Trang chủ trước khi thử lại.',
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
  late final LocalApi api;
  Json state = {'documents': [], 'quizzes': [], 'jobs': [], 'attempts': []};
  bool connected = false, refreshing = false, closed = false;
  String? error;
  Timer? timer;
  int connectionGeneration = 0;
  bool authenticationRequired = false;
  int? _refreshGeneration;
  JobNotice? _jobNotice;
  bool _hasLoadedState = false;
  AppController(this.prefs, {LocalApi? api}) {
    this.api =
        api ??
        LocalApi(
          _builtInRelay.isNotEmpty
              ? _builtInRelay
              : (prefs.getString('relay') ?? 'http://127.0.0.1:8787'),
          token: _builtInRelayToken.isNotEmpty ? _builtInRelayToken : null,
        );
  }
  List<Json> items(String key) => (state[key] as List).cast<Json>();
  JobNotice? takeJobNotice() {
    final notice = _jobNotice;
    _jobNotice = null;
    return notice;
  }

  void start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    if (_refreshGeneration == connectionGeneration ||
        closed ||
        authenticationRequired) {
      return;
    }
    refreshing = true;
    final generation = connectionGeneration;
    _refreshGeneration = generation;
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
      if (generation == connectionGeneration) {
        _refreshGeneration = null;
        refreshing = false;
        if (!closed) notifyListeners();
      }
    }
  }

  Future<Json> send(String path, Json body, {int? expectedGeneration}) async {
    final generation = connectionGeneration;
    if (closed ||
        (expectedGeneration != null && expectedGeneration != generation)) {
      throw ApiException('Kết nối đã thay đổi; thao tác cũ đã bị hủy.');
    }
    late Json result;
    try {
      result = await api.request(path, body);
    } catch (_) {
      if (generation != connectionGeneration || closed) {
        throw ApiException('Kết nối đã thay đổi; bỏ lỗi từ dịch vụ cũ.');
      }
      rethrow;
    }
    if (generation != connectionGeneration || closed) {
      throw ApiException('Kết nối đã thay đổi; thao tác cũ đã bị hủy.');
    }
    await refresh();
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
      connectionGeneration++;
      state = {'documents': [], 'quizzes': [], 'jobs': [], 'attempts': []};
      connected = false;
      error = null;
      refreshing = false;
      _refreshGeneration = null;
      _jobNotice = null;
      _hasLoadedState = false;
    }
    api.base = canonical;
    api.token = nextToken == null || nextToken.isEmpty ? null : nextToken;
    authenticationRequired = false;
    final generation = connectionGeneration;
    notifyListeners();
    await prefs.setString('relay', canonical);
    if (changed) {
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith('draft-'),
      )) {
        await prefs.remove(key);
      }
    }
    if (closed || generation != connectionGeneration) return;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    await refresh();
  }

  @override
  void dispose() {
    closed = true;
    timer?.cancel();
    api.client.close();
    super.dispose();
  }
}
