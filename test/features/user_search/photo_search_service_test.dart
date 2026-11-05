import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/features/user_search/data/photo_search_service.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

const String _gps = 'GPSLatitude 51.5007N GPSLongitude 0.1246W';

int _crc32(List<int> bytes) {
  int crc = 0xffffffff;
  for (final int byte in bytes) {
    crc ^= byte;
    for (int k = 0; k < 8; k++) {
      crc = crc & 1 == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}

List<int> _chunk(String type, List<int> data) {
  final List<int> typed = <int>[...ascii.encode(type), ...data];
  return <int>[
    ...(ByteData(4)..setUint32(0, data.length)).buffer.asUint8List(),
    ...typed,
    ...(ByteData(4)..setUint32(0, _crc32(typed))).buffer.asUint8List(),
  ];
}

/// A solid RGB PNG that carries an `eXIf` chunk and a `tEXt` chunk with a location in them.
Uint8List _pngWithLocation(int width, int height, List<int> rgb) {
  final ByteData header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  final List<int> rows = <int>[
    for (int y = 0; y < height; y++) ...<int>[0, for (int x = 0; x < width; x++) ...rgb],
  ];
  return Uint8List.fromList(<int>[
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
    ..._chunk('IHDR', header.buffer.asUint8List()),
    ..._chunk('eXIf', <int>[...ascii.encode('MM'), 0, 42, 0, 0, 0, 8, ...ascii.encode(_gps)]),
    ..._chunk('tEXt', <int>[...latin1.encode('Location'), 0, ...latin1.encode(_gps)]),
    ..._chunk('IDAT', zlib.encode(rows)),
    ..._chunk('IEND', const <int>[]),
  ]);
}

bool _contains(Uint8List haystack, String needle) => latin1.decode(haystack).contains(needle);

Future<ui.Image> _decode(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Uint8List original = _pngWithLocation(1200, 800, const <int>[0x00, 0x66, 0xcc]);

  test('the fixture carries location metadata', () {
    expect(_contains(original, 'eXIf'), isTrue);
    expect(_contains(original, 'GPSLatitude'), isTrue);
  });

  testWidgets('preparePhoto downscales to 512 px and drops all metadata', (tester) async {
    await tester.runAsync(() async {
      final PreparedPhoto prepared = await preparePhoto(original);
      for (final String marker in <String>['eXIf', 'Exif', 'tEXt', 'GPS', 'Location', 'MM\u0000*']) {
        expect(_contains(prepared.png, marker), isFalse, reason: marker);
      }
      final ui.Image upload = await _decode(prepared.png);
      expect((upload.width, upload.height), (512, 341));
      expect(prepared.sample.length, 48 * 32 * 4);
      expect(prepared.sample.sublist(0, 4), <int>[0x00, 0x66, 0xcc, 0xff]);
    });
  });

  testWidgets('a small photo keeps its size', (tester) async {
    await tester.runAsync(() async {
      final PreparedPhoto prepared = await preparePhoto(_pngWithLocation(40, 30, const <int>[0xff, 0xff, 0xff]));
      final ui.Image upload = await _decode(prepared.png);
      expect((upload.width, upload.height), (40, 30));
      expect(prepared.sample.length, 40 * 30 * 4);
    });
  });

  testWidgets('a guest gets colours and no network call', (tester) async {
    final _MockFunctions functions = _MockFunctions();
    final PhotoQuery query = (await tester.runAsync(
      () => PhotoSearchService(null, (png) async => png, functions).queryFor(original, signedIn: false),
    ))!;
    expect(query.labelsStatus, PhotoLabelsStatus.guest);
    expect(query.labels, isEmpty);
    expect(<String>[for (final entry in query.palette) entry.color.id], <String>['blue']);
    expect(_contains(query.preview, 'GPS'), isFalse);
    verifyZeroInteractions(functions);
  });

  group('signed in', () {
    late _MockFunctions functions;
    late _MockCallable callable;

    setUp(() {
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable('photoSearchLabels', options: any(named: 'options'))).thenReturn(callable);
    });

    testWidgets('sends the clean copy with a request id and reads the labels', (tester) async {
      final _MockResult result = _MockResult();
      when(() => result.data).thenReturn(<String, Object?>{
        'labels': <Object?>['Sky', 'Sunset', 3],
        'category': 'Nature',
        'remaining': 19,
      });
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
      final PhotoQuery query = (await tester.runAsync(
        () => PhotoSearchService(null, (png) async => png, functions).queryFor(original, signedIn: true),
      ))!;
      expect(query.labelsStatus, PhotoLabelsStatus.found);
      expect(query.labels, <String>['Sky', 'Sunset']);
      expect(query.category, 'Nature');
      final Map<String, Object> sent =
          verify(() => callable.call<Object?>(captureAny())).captured.single as Map<String, Object>;
      expect(sent.keys.toSet(), <String>{'image', 'requestId'});
      final HttpsCallableOptions options =
          verify(
                () => functions.httpsCallable('photoSearchLabels', options: captureAny(named: 'options')),
              ).captured.single
              as HttpsCallableOptions;
      expect(options.timeout, const Duration(seconds: 30));
      expect(sent['requestId'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
      final Uint8List image = base64Decode(sent['image']! as String);
      expect(image, query.preview);
      expect(_contains(image, 'GPS'), isFalse);
      expect(_contains(image, 'eXIf'), isFalse);
    });

    for (final (String code, PhotoLabelsStatus status) in <(String, PhotoLabelsStatus)>[
      ('resource-exhausted', PhotoLabelsStatus.capped),
      ('unauthenticated', PhotoLabelsStatus.guest),
      ('unavailable', PhotoLabelsStatus.unavailable),
    ]) {
      testWidgets('a $code error still gives colours', (tester) async {
        when(() => callable.call<Object?>(any())).thenThrow(FirebaseFunctionsException(code: code, message: code));
        final PhotoQuery query = (await tester.runAsync(
          () => PhotoSearchService(null, (png) async => png, functions).queryFor(original, signedIn: true),
        ))!;
        expect(query.labelsStatus, status);
        expect(query.labels, isEmpty);
        expect(<String>[for (final entry in query.palette) entry.color.id], <String>['blue']);
      });
    }

    testWidgets('does not log exception details that may contain the image payload', (tester) async {
      const String privatePayload = 'base64-photo-payload-secret';
      InMemoryLogSink.instance.clear();
      when(() => callable.call<Object?>(any())).thenThrow(StateError(privatePayload));
      final PhotoQuery query = (await tester.runAsync(
        () => PhotoSearchService(null, (png) async => png, functions).queryFor(original, signedIn: true),
      ))!;
      final photoLogs = InMemoryLogSink.instance.records.where((record) => record.message.contains('[PhotoSearch]'));

      expect(query.labelsStatus, PhotoLabelsStatus.unavailable);
      expect(query.topColor.id, 'blue');
      expect(photoLogs, hasLength(1));
      expect(photoLogs.single.message, isNot(contains(privatePayload)));
      expect(photoLogs.single.error, isNull);
      expect(photoLogs.single.stackTrace, isNull);
    });
  });

  testWidgets('a file that is not an image throws', (tester) async {
    final Object? error = await tester.runAsync<Object?>(() async {
      try {
        await preparePhoto(Uint8List.fromList(utf8.encode('not an image')));
        return null;
      } catch (error) {
        return error;
      }
    });
    expect(error, isNotNull);
  });
}
