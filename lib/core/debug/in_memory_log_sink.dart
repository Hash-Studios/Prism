import 'dart:async';

import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/logger/log_sink.dart';

/// An in-memory circular buffer that captures all log records.
/// Exposes a broadcast [stream] for reactive UI consumption.
class InMemoryLogSink implements LogSink {
  InMemoryLogSink._({int capacity = 2000}) : _capacity = capacity;

  static final InMemoryLogSink instance = InMemoryLogSink._();

  final int _capacity;
  final List<AppLogRecord> _buffer = [];
  final StreamController<AppLogRecord> _controller = StreamController<AppLogRecord>.broadcast();

  /// Stream of new log records as they arrive.
  Stream<AppLogRecord> get stream => _controller.stream;

  /// Snapshot of all buffered records (oldest first).
  List<AppLogRecord> get records => List<AppLogRecord>.unmodifiable(_buffer);

  @override
  void write(AppLogRecord record) {
    if (_buffer.length >= _capacity) {
      _buffer.removeAt(0);
    }
    _buffer.add(record);
    if (!_controller.isClosed) {
      _controller.add(record);
    }
  }

  void clear() {
    _buffer.clear();
  }

  void dispose() {
    _controller.close();
  }
}
