import 'dart:async';

/// A single captured HTTP transaction.
class NetworkLogEntry {
  NetworkLogEntry({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.elapsedMs,
    this.error,
  });

  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  int? statusCode;
  Map<String, String>? responseHeaders;
  String? responseBody;
  int? elapsedMs;
  String? error;

  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;
  bool get isError => error != null || (statusCode != null && statusCode! >= 400);
  bool get isPending => statusCode == null && error == null;
}

/// Circular buffer storing captured HTTP transactions.
class NetworkLogStore {
  NetworkLogStore._({int capacity = 500}) : _capacity = capacity;

  static final NetworkLogStore instance = NetworkLogStore._();

  final int _capacity;
  final List<NetworkLogEntry> _buffer = [];
  final StreamController<NetworkLogEntry> _controller = StreamController<NetworkLogEntry>.broadcast();

  Stream<NetworkLogEntry> get stream => _controller.stream;

  List<NetworkLogEntry> get entries => List<NetworkLogEntry>.unmodifiable(_buffer);

  void add(NetworkLogEntry entry) {
    if (_buffer.length >= _capacity) {
      _buffer.removeAt(0);
    }
    _buffer.add(entry);
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  void update(NetworkLogEntry entry) {
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  void clear() {
    _buffer.clear();
  }
}
