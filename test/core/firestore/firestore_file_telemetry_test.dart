import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent telemetry writes preserve complete ordered records and append after reopening', () async {
    final root = await Directory.systemTemp.createTemp('prism-telemetry-');
    addTearDown(() => root.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => root.path,
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final sink = FirestoreFileTelemetrySink();
    FirestoreTelemetryEvent event(int index) => FirestoreTelemetryEvent(
      timestamp: DateTime.utc(2026, 1, 2),
      sourceTag: 'feed.$index',
      operation: FirestoreOperation.queryGet,
      collection: 'walls',
      filtersHash: 'filter',
      durationMs: index,
      success: index != 3,
      resultCount: index == 3 ? null : 4,
      errorCode: index == 3 ? 'permission-denied' : null,
    );

    await Future.wait(List<Future<void>>.generate(10, (index) => sink.emit(event(index))));
    await FirestoreFileTelemetrySink().emit(event(10));
    final file = File('${root.path}/$firestoreTelemetryFileName');
    final records = (await file.readAsLines()).map((line) => jsonDecode(line) as Map<String, dynamic>).toList();

    expect(records.map((record) => record['sourceTag']), List<String>.generate(11, (index) => 'feed.$index'));
    expect(records[3], <String, Object?>{
      'timestamp': '2026-01-02T00:00:00.000Z',
      'sourceTag': 'feed.3',
      'operation': 'queryGet',
      'collection': 'walls',
      'filtersHash': 'filter',
      'durationMs': 3,
      'success': false,
      'orderBy': null,
      'limit': null,
      'resultCount': null,
      'docId': null,
      'errorCode': 'permission-denied',
    });
    final original = await file.readAsString();
    trimTelemetryFile(file, maxBytes: original.length + 1);
    expect(await file.readAsString(), original);
    trimTelemetryFile(file, maxBytes: 1);
    final kept = (await file.readAsLines()).map((line) => jsonDecode(line) as Map<String, dynamic>);
    expect(kept.map((record) => record['sourceTag']), <String>[
      'feed.5',
      'feed.6',
      'feed.7',
      'feed.8',
      'feed.9',
      'feed.10',
    ]);
  });
}
