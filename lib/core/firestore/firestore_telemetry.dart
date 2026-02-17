import 'dart:convert';
import 'dart:io';

import 'package:Prism/logger/logger.dart';
import 'package:path_provider/path_provider.dart';

enum FirestoreOperation {
  queryGet,
  docGet,
  streamSubscribe,
  set,
  update,
  delete,
  add,
}

class FirestoreTelemetryEvent {
  const FirestoreTelemetryEvent({
    required this.timestamp,
    required this.sourceTag,
    required this.operation,
    required this.collection,
    required this.filtersHash,
    required this.durationMs,
    required this.success,
    this.orderBy,
    this.limit,
    this.resultCount,
    this.docId,
    this.errorCode,
  });

  final DateTime timestamp;
  final String sourceTag;
  final FirestoreOperation operation;
  final String collection;
  final String filtersHash;
  final List<String>? orderBy;
  final int? limit;
  final int durationMs;
  final int? resultCount;
  final String? docId;
  final bool success;
  final String? errorCode;

  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp': timestamp.toUtc().toIso8601String(),
        'sourceTag': sourceTag,
        'operation': operation.name,
        'collection': collection,
        'filtersHash': filtersHash,
        'orderBy': orderBy,
        'limit': limit,
        'durationMs': durationMs,
        'resultCount': resultCount,
        'docId': docId,
        'success': success,
        'errorCode': errorCode,
      };
}

abstract class FirestoreTelemetrySink {
  Future<void> emit(FirestoreTelemetryEvent event);
}

class FirestoreConsoleTelemetrySink implements FirestoreTelemetrySink {
  const FirestoreConsoleTelemetrySink();

  @override
  Future<void> emit(FirestoreTelemetryEvent event) async {
    logger.i(
      '[Firestore]',
      tag: 'Firestore',
      fields: event.toJson(),
    );
  }
}

class FirestoreFileTelemetrySink implements FirestoreTelemetrySink {
  FirestoreFileTelemetrySink({this.fileName = 'firestore_telemetry.ndjson'});

  final String fileName;
  File? _file;

  Future<File> _resolveFile() async {
    if (_file != null) {
      return _file!;
    }
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/$fileName');
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    _file = file;
    return file;
  }

  @override
  Future<void> emit(FirestoreTelemetryEvent event) async {
    final File file = await _resolveFile();
    await file.writeAsString('${jsonEncode(event.toJson())}\n', mode: FileMode.append, flush: true);
  }
}

class CompositeFirestoreTelemetrySink implements FirestoreTelemetrySink {
  CompositeFirestoreTelemetrySink(this._sinks);

  final List<FirestoreTelemetrySink> _sinks;

  @override
  Future<void> emit(FirestoreTelemetryEvent event) async {
    for (final FirestoreTelemetrySink sink in _sinks) {
      await sink.emit(event);
    }
  }
}
