import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// One refresh in flight per API instance. Bodies are buffered for one retry,
/// including multipart requests; mutation retries occur only after a 401.
class SessionHttpClient extends http.BaseClient {
  SessionHttpClient(this.inner, this.baseUrl);
  final http.Client inner;
  final String baseUrl;
  String? accessToken;
  String? refreshToken;
  Future<bool>? _refreshing;
  Timer? _timer;
  int _epoch = 0;
  int _identityEpoch = 0;
  bool _closed = false;
  Future<void> Function(String, String)? onTokens;
  void Function()? onInvalidated;
  void Function()? onRefreshed;

  void setTokens(String? access, String? refresh, {bool renewal = false}) {
    if (!renewal) _identityEpoch++;
    _epoch++;
    accessToken = access;
    refreshToken = refresh;
    _schedule();
  }

  DateTime? get _expiry {
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(accessToken!.split('.')[1])),
        ),
      );
      return DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_closed || refreshToken == null || _expiry == null) return;
    final delay =
        _expiry!.difference(DateTime.now().toUtc()) -
        const Duration(minutes: 1);
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      try {
        await refresh();
      } catch (_) {
        // A network outage is retryable and does not destroy a local draft.
        if (!_closed && refreshToken != null) {
          _timer = Timer(const Duration(seconds: 30), _retryRefresh);
        }
      }
    });
  }

  void _retryRefresh() async {
    try {
      await refresh();
    } catch (_) {
      if (!_closed && refreshToken != null) {
        _timer = Timer(const Duration(seconds: 30), _retryRefresh);
      }
    }
  }

  Future<bool> refresh() {
    final existing = _refreshing;
    if (existing != null) return existing;
    final future = _doRefresh();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<bool> _doRefresh() async {
    final credential = refreshToken;
    if (credential == null || _closed) return false;
    final epoch = _epoch;
    final response = await inner.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': credential}),
    );
    if (_epoch != epoch || _closed) {
      return false; // Logout/new login wins over late refresh.
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      setTokens(null, null);
      onInvalidated?.call();
      return false;
    }
    if (response.statusCode != 200) {
      throw http.ClientException('Session renewal temporarily unavailable');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final access = json['access_token'] as String?;
    final refresh = json['refresh_token'] as String?;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      throw http.ClientException('Invalid session renewal response');
    }
    setTokens(access, refresh, renewal: true);
    await onTokens?.call(access, refresh);
    onRefreshed?.call();
    return true;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authenticated =
        request.headers.containsKey('Authorization') &&
        !request.url.path.startsWith('/auth/');
    if (!authenticated) return inner.send(request);
    final identity = _identityEpoch;
    final expiry = _expiry;
    if (refreshToken != null &&
        expiry != null &&
        expiry.isBefore(
          DateTime.now().toUtc().add(const Duration(minutes: 1)),
        )) {
      await refresh();
    }
    if (identity != _identityEpoch || accessToken == null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"detail":"Session expired"}')),
        401,
      );
    }
    final bytes = await request.finalize().toBytes();
    Future<http.StreamedResponse> transmit() {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..bodyBytes = bytes
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects;
      return inner.send(copy);
    }

    final sentToken = accessToken;
    var response = await transmit();
    if (identity != _identityEpoch) {
      await response.stream.drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"detail":"Previous session ended"}')),
        401,
      );
    }
    if (response.statusCode == 401 && refreshToken != null) {
      await response.stream.drain<void>();
      // Another request may already have replaced the token we sent.
      if (accessToken != sentToken || await refresh()) {
        if (accessToken != null) {
          response = await transmit();
        } else {
          response = http.StreamedResponse(
            Stream.value(utf8.encode('{"detail":"Session expired"}')),
            401,
          );
        }
      } else {
        response = http.StreamedResponse(
          Stream.value(utf8.encode('{"detail":"Session expired"}')),
          401,
        );
      }
    }
    // Do not clear a new session because a previous session request finished late.
    if (response.statusCode == 401 && identity == _identityEpoch) {
      setTokens(null, null);
      onInvalidated?.call();
    }
    return response;
  }

  Future<void> revoke() async {
    final credential = refreshToken;
    setTokens(null, null);
    if (credential == null) return;
    try {
      await inner
          .post(
            Uri.parse('$baseUrl/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': credential}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Local logout succeeds even if the network is unavailable. */
    }
  }

  @override
  void close() {
    _closed = true;
    _epoch++;
    _timer?.cancel();
    inner.close();
  }
}
