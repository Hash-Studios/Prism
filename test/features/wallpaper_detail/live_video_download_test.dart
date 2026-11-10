import 'dart:async';
import 'dart:io';

import 'package:Prism/features/wallpaper_detail/views/widgets/live_wall_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prism_live_download_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => directory.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await directory.delete(recursive: true);
  });

  test('distinct URLs with the same Dart hash do not reuse another video', () async {
    const String firstUrl = 'https://cdn.example.com/videos/41224.mp4';
    const String secondUrl = 'https://cdn.example.com/videos/45700.mp4';
    expect(firstUrl.hashCode, secondUrl.hashCode);
    final MockClient client = MockClient((request) async => http.Response(request.url.toString(), 200));

    await http.runWithClient(() async {
      final File first = await downloadLiveVideo(firstUrl);
      final File second = await downloadLiveVideo(secondUrl);
      expect(second.path, isNot(first.path));
      expect(await second.readAsString(), secondUrl);
    }, () => client);
  });

  test('empty responses are refused and a later tap retries the request', () async {
    int requests = 0;
    final MockClient client = MockClient((_) async {
      requests++;
      return http.Response(requests == 1 ? '' : 'complete-video', 200);
    });

    await http.runWithClient(() async {
      await expectLater(downloadLiveVideo('https://cdn.example.com/empty.mp4'), throwsA(isA<HttpException>()));
      expect(await directory.list().toList(), isEmpty);
      final File retry = await downloadLiveVideo('https://cdn.example.com/empty.mp4');
      expect(await retry.readAsString(), 'complete-video');
      expect(requests, 2);
    }, () => client);
  });

  test('a response shorter than Content-Length never becomes a reusable cache entry', () async {
    final MockClient client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(Stream<List<int>>.value(<int>[1, 2, 3]), 200, contentLength: 6),
    );

    await http.runWithClient(() async {
      await expectLater(downloadLiveVideo('https://cdn.example.com/partial.mp4'), throwsA(isA<HttpException>()));
      expect(await directory.list().toList(), isEmpty);
    }, () => client);
  });

  test('a failed stream leaves no reusable bytes and can be retried', () async {
    int requests = 0;
    Stream<List<int>> broken() async* {
      yield <int>[1, 2];
      throw const SocketException('connection reset');
    }

    final MockClient client = MockClient.streaming((_, _) async {
      requests++;
      return http.StreamedResponse(requests == 1 ? broken() : Stream<List<int>>.value(<int>[3, 4]), 200);
    });

    await http.runWithClient(() async {
      await expectLater(downloadLiveVideo('https://cdn.example.com/retry.mp4'), throwsA(isA<SocketException>()));
      expect(await directory.list().toList(), isEmpty);
      final File retry = await downloadLiveVideo('https://cdn.example.com/retry.mp4');
      expect(await retry.readAsBytes(), <int>[3, 4]);
      expect(requests, 2);
    }, () => client);
  });

  test('an oversized stream is cancelled before the remaining body is read', () async {
    bool readRemainder = false;
    Stream<List<int>> oversized() async* {
      yield Uint8List(20 * 1024 * 1024);
      yield <int>[1];
      readRemainder = true;
      yield <int>[2];
    }

    final MockClient client = MockClient.streaming((_, _) async => http.StreamedResponse(oversized(), 200));
    await http.runWithClient(() async {
      await expectLater(downloadLiveVideo('https://cdn.example.com/huge.mp4'), throwsA(isA<HttpException>()));
      expect(readRemainder, isFalse);
      expect(await directory.list().toList(), isEmpty);
    }, () => client);
  });

  test('concurrent taps share one download and only reuse its complete bytes', () async {
    final Completer<void> release = Completer<void>();
    int requests = 0;
    Stream<List<int>> body() async* {
      yield <int>[1, 2];
      await release.future;
      yield <int>[3, 4];
    }

    final MockClient client = MockClient.streaming((_, _) async {
      requests++;
      return http.StreamedResponse(body(), 200);
    });

    await http.runWithClient(() async {
      final Future<File> first = downloadLiveVideo('https://cdn.example.com/shared.mp4');
      final Future<File> second = downloadLiveVideo('https://cdn.example.com/shared.mp4');
      await pumpEventQueue();
      final int requestsBeforeCompletion = requests;
      expect((await directory.list().toList()).whereType<File>().where((file) => file.path.endsWith('.mp4')), isEmpty);
      release.complete();
      final List<File> files = await Future.wait(<Future<File>>[first, second]);
      expect(requestsBeforeCompletion, 1);
      expect(files.first.path, files.last.path);
      expect(await files.first.readAsBytes(), <int>[1, 2, 3, 4]);
      await downloadLiveVideo('https://cdn.example.com/shared.mp4');
      expect(requests, 1);
    }, () => client);
  });
}
