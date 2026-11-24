import 'dart:async';
import 'dart:convert';

import 'package:rhttp/rhttp.dart';

import 'package:namida/controller/network_proxy_controller.dart';

class LxHttpProxy {
  LxHttpProxy() {
    _proxyController.addOnChanged((_) {
      // In-flight requests retain their client. The next request uses the new proxy.
      _client = null;
    });
  }

  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36';

  final _proxyController = NetworkProxyController.inst;
  final _activeTokens = <String, CancelToken>{};
  Future<RhttpClient>? _client;

  Future<RhttpClient> _getClient() async {
    final pending = _client ??= RhttpClient.create(
      settings: ClientSettings(proxySettings: _proxyController.rhttpProxySettings, throwOnStatusCode: false),
    );
    try {
      return await pending;
    } catch (_) {
      if (identical(_client, pending)) _client = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> execute({
    required String requestKey,
    required String url,
    required Map<String, dynamic> options,
  }) async {
    final method = (options['method'] as String? ?? 'GET').toUpperCase();
    final headers = _stringFields(options['headers'] as Map<String, dynamic>? ?? const {});
    final headerNames = {for (final key in headers.keys) key.toLowerCase(): key};
    if (!headerNames.containsKey('user-agent')) headers['User-Agent'] = _userAgent;
    if (!headerNames.containsKey('accept')) headers['Accept'] = 'application/json';
    final contentType = headers[headerNames['content-type']]?.split(';').first.trim().toLowerCase();
    final body = _requestBody(options, contentType);
    final timeout = Duration(milliseconds: (options['timeout'] as num? ?? 15000).clamp(0, 60000).toInt());
    final binary = options['binary'] as bool? ?? false;

    final cancelToken = CancelToken();
    _activeTokens[requestKey] = cancelToken;
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      unawaited(cancelToken.cancel());
    });
    try {
      final client = await _getClient();
      final response = await client.request(
        method: HttpMethod(method),
        url: url,
        headers: HttpHeaders.rawMap(headers),
        body: body,
        expectBody: binary ? HttpExpectBody.bytes : HttpExpectBody.text,
        cancelToken: cancelToken,
      );
      return {
        'statusCode': response.statusCode,
        'statusMessage': '',
        'headers': response.headerMap,
        'binary': binary,
        'body': binary ? base64Encode((response as HttpBytesResponse).body) : _decodeText((response as HttpTextResponse).body),
      };
    } on RhttpCancelException {
      if (timedOut) throw TimeoutException('HTTP 请求超时（${timeout.inMilliseconds} ms）', timeout);
      throw StateError('HTTP 请求已取消');
    } finally {
      timer.cancel();
      _activeTokens.remove(requestKey);
    }
  }

  void cancel(String requestKey) => unawaited(_activeTokens[requestKey]?.cancel());

  static Map<String, String> _stringFields(Map<String, dynamic> fields) => {
    for (final entry in fields.entries)
      if (entry.value != null) entry.key: entry.value.toString(),
  };

  static HttpBody? _requestBody(Map<String, dynamic> options, String? contentType) {
    final form = options['form'] as Map<String, dynamic>?;
    if (form != null) return HttpBody.form(_stringFields(form));

    final data = options['formData'] ?? options['body'];
    return switch (data) {
      null => null,
      String value => HttpBody.text(value),
      Map<String, dynamic> value when options['formData'] != null || contentType == 'application/x-www-form-urlencoded' =>
        HttpBody.form(_stringFields(value)),
      Map() || List() when contentType?.startsWith('text/') == true => HttpBody.text(jsonEncode(data)),
      Map() || List() => HttpBody.json(data),
      _ => throw const FormatException('不支持的 HTTP 请求体格式'),
    };
  }

  static Object? _decodeText(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }
}
