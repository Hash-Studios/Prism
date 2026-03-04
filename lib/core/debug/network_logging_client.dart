import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/debug/network_log_store.dart';
import 'package:Prism/logger/logger.dart';
import 'package:http/http.dart' as http;

/// Maximum number of bytes to capture from request/response bodies.
const int _kMaxBodyBytes = 2048;

/// Headers whose values are replaced with [redacted] before logging.
const Set<String> _kSensitiveHeaders = {'authorization', 'cookie', 'x-api-key', 'x-auth-token'};

/// HTTP client wrapper that logs every request/response to [NetworkLogStore]
/// and the app [logger].
class NetworkLoggingClient extends http.BaseClient {
  NetworkLoggingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  static int _idCounter = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String id = 'net_${++_idCounter}';
    final DateTime start = DateTime.now();

    final Map<String, String> safeHeaders = _sanitizeHeaders(request.headers);

    String? requestBody;
    if (request is http.Request) {
      requestBody = _truncate(request.body);
    }

    final NetworkLogEntry entry = NetworkLogEntry(
      id: id,
      timestamp: start,
      method: request.method,
      url: request.url.toString(),
      requestHeaders: safeHeaders,
      requestBody: requestBody,
    );
    NetworkLogStore.instance.add(entry);

    logger.d(
      '→ ${request.method} ${request.url}',
      tag: 'Network',
      fields: <String, Object?>{'id': id, 'method': request.method, 'url': request.url.toString()},
    );

    try {
      final http.StreamedResponse streamed = await _inner.send(request);
      final int elapsedMs = DateTime.now().difference(start).inMilliseconds;

      final List<int> bytes = await streamed.stream.toBytes();
      final String? body = _decodeBody(bytes);

      entry.statusCode = streamed.statusCode;
      entry.responseHeaders = Map<String, String>.from(streamed.headers);
      entry.responseBody = body != null ? _truncate(body) : null;
      entry.elapsedMs = elapsedMs;
      NetworkLogStore.instance.update(entry);

      final bool isError = streamed.statusCode >= 400;
      if (isError) {
        logger.w(
          '← ${request.method} ${request.url} ${streamed.statusCode} (${elapsedMs}ms)',
          tag: 'Network',
          fields: <String, Object?>{'id': id, 'status': streamed.statusCode, 'elapsed_ms': elapsedMs},
        );
      } else {
        logger.d(
          '← ${request.method} ${request.url} ${streamed.statusCode} (${elapsedMs}ms)',
          tag: 'Network',
          fields: <String, Object?>{'id': id, 'status': streamed.statusCode, 'elapsed_ms': elapsedMs},
        );
      }

      // Reconstruct the streamed response with the already-consumed bytes.
      return http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        streamed.statusCode,
        contentLength: streamed.contentLength,
        request: streamed.request,
        headers: streamed.headers,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );
    } catch (e, st) {
      final int elapsedMs = DateTime.now().difference(start).inMilliseconds;
      entry.error = e.toString();
      entry.elapsedMs = elapsedMs;
      NetworkLogStore.instance.update(entry);
      logger.e(
        '✗ ${request.method} ${request.url} (${elapsedMs}ms)',
        tag: 'Network',
        error: e,
        stackTrace: st,
        fields: <String, Object?>{'id': id},
      );
      rethrow;
    }
  }

  @override
  void close() => _inner.close();

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      if (_kSensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, '[redacted]');
      }
      return MapEntry(key, value);
    });
  }

  String _truncate(String text) {
    if (text.length <= _kMaxBodyBytes) return text;
    return '${text.substring(0, _kMaxBodyBytes)}… [truncated ${text.length - _kMaxBodyBytes} bytes]';
  }

  String? _decodeBody(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return '[binary ${bytes.length} bytes]';
    }
  }
}
