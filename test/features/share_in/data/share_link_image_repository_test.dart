import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/features/share_in/data/share_link_image_repository.dart';
import 'package:Prism/features/share_in/data/shared_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Uri _page = Uri.parse('https://example.com/p');
final Uint8List _pngBytes = Uint8List.fromList(<int>[137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13]);

void main() {
  late Directory root;
  late Directory inbox;
  late Directory handOff;

  setUp(() {
    root = Directory.systemTemp.createTempSync('share_link_image_repo_test');
    inbox = Directory('${root.path}/inbox')..createSync();
    handOff = Directory('${root.path}/hand_off');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  SharedInbox sharedInbox() => SharedInbox(inboxDirectory: () async => inbox, handOffDirectory: () async => handOff);

  List<FileSystemEntity> handOffFiles() => handOff.existsSync() ? handOff.listSync() : <FileSystemEntity>[];

  Future<Object?> Function(String url) lookupReturning(Object? data) =>
      (String url) async => data;

  Map<String, Object?> imageLookup(String url) => <String, Object?>{'imageUrl': url};

  test('downloads the image into the hand-off folder with its bytes', () async {
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(<String, Object?>{'imageUrl': 'https://cdn.example.com/a.png'}),
      client: MockClient((http.Request request) async {
        return http.Response.bytes(_pngBytes, 200, headers: <String, String>{'content-type': 'image/png'});
      }),
    );

    final String? path = await repository.imageFor(_page);

    expect(path, isNotNull);
    expect(path!.startsWith(handOff.path), isTrue);
    expect(path.endsWith('.png'), isTrue);
    expect(File(path).readAsBytesSync(), _pngBytes);
  });

  test('a non-https image URL returns null and never calls the client', () async {
    int calls = 0;
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('http://cdn.example.com/a.png')),
      client: MockClient((http.Request request) async {
        calls++;
        return http.Response.bytes(_pngBytes, 200, headers: <String, String>{'content-type': 'image/png'});
      }),
    );

    expect(await repository.imageFor(_page), isNull);
    expect(calls, 0);
  });

  test('redirects are followed manually and never downgrade to HTTP', () async {
    final List<Uri> requests = <Uri>[];
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('https://cdn.example.com/start')),
      client: MockClient((http.Request request) async {
        requests.add(request.url);
        expect(request.followRedirects, isFalse);
        return http.Response('', 302, headers: <String, String>{'location': 'http://cdn.example.com/image.png'});
      }),
    );

    expect(await repository.imageFor(_page), isNull);
    expect(requests, <Uri>[Uri.parse('https://cdn.example.com/start')]);
    expect(handOffFiles(), isEmpty);
  });

  test('a relative HTTPS redirect downloads the image', () async {
    int calls = 0;
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('https://cdn.example.com/start')),
      client: MockClient((http.Request request) async {
        calls++;
        if (calls == 1) return http.Response('', 302, headers: <String, String>{'location': '/image.png'});
        expect(request.url.toString(), 'https://cdn.example.com/image.png');
        return http.Response.bytes(_pngBytes, 200, headers: <String, String>{'content-type': 'image/png'});
      }),
    );

    final String? path = await repository.imageFor(_page);
    expect(path, isNotNull);
    expect(File(path!).readAsBytesSync(), _pngBytes);
    expect(calls, 2);
  });

  test('continuous chunks cannot extend the total download deadline', () async {
    bool cancelled = false;
    final StreamController<List<int>> chunks = StreamController<List<int>>();
    Timer? producer;
    chunks.onListen = () {
      int sent = 0;
      producer = Timer.periodic(const Duration(milliseconds: 10), (Timer timer) {
        chunks.add(_pngBytes);
        if (++sent == 30) {
          timer.cancel();
          unawaited(chunks.close());
        }
      });
    };
    chunks.onCancel = () {
      cancelled = true;
      producer?.cancel();
    };
    addTearDown(() => producer?.cancel());
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('https://cdn.example.com/a.png')),
      timeout: const Duration(milliseconds: 50),
      client: MockClient.streaming((http.BaseRequest request, http.ByteStream body) async {
        return http.StreamedResponse(chunks.stream, 200, headers: <String, String>{'content-type': 'image/png'});
      }),
    );

    expect(await repository.imageFor(_page), isNull);
    expect(cancelled, isTrue);
    expect(handOffFiles(), isEmpty);
  });

  test('a lookup with no imageUrl returns null', () async {
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(<String, Object?>{'imageUrl': null}),
      client: MockClient((http.Request request) async => fail('the client must not be called')),
    );

    expect(await repository.imageFor(_page), isNull);
  });

  test('a lookup that throws returns null', () async {
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: (String url) async => throw StateError('lookup failed'),
      client: MockClient((http.Request request) async => fail('the client must not be called')),
    );

    expect(await repository.imageFor(_page), isNull);
  });

  test('a text/html response returns null and leaves no file behind', () async {
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('https://cdn.example.com/a.png')),
      client: MockClient((http.Request request) async {
        return http.Response('<html></html>', 200, headers: <String, String>{'content-type': 'text/html'});
      }),
    );

    expect(await repository.imageFor(_page), isNull);
    expect(handOffFiles(), isEmpty);
  });

  test('a content-length over the limit returns null before any download', () async {
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('https://cdn.example.com/a.png')),
      client: MockClient.streaming((http.BaseRequest request, http.ByteStream body) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(_pngBytes),
          200,
          contentLength: ShareLinkImageRepository.maxImageBytes + 1,
          headers: <String, String>{'content-type': 'image/png'},
        );
      }),
    );

    expect(await repository.imageFor(_page), isNull);
    expect(handOffFiles(), isEmpty);
  });

  test('a streamed body over the limit with no content-length returns null and leaves no file', () async {
    const int chunkBytes = 1024 * 1024;
    const int chunkCount = 26;
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('https://cdn.example.com/a.png')),
      client: MockClient.streaming((http.BaseRequest request, http.ByteStream body) async {
        final Stream<List<int>> chunks = Stream<List<int>>.fromIterable(
          List<List<int>>.generate(chunkCount, (_) => Uint8List(chunkBytes)),
        );
        return http.StreamedResponse(chunks, 200, headers: <String, String>{'content-type': 'image/png'});
      }),
    );

    expect(await repository.imageFor(_page), isNull);
    expect(handOffFiles(), isEmpty);
  });

  test('a 404 response returns null', () async {
    final ShareLinkImageRepository repository = ShareLinkImageRepository(
      inbox: sharedInbox(),
      lookup: lookupReturning(imageLookup('https://cdn.example.com/a.png')),
      client: MockClient((http.Request request) async {
        return http.Response('missing', 404, headers: <String, String>{'content-type': 'image/png'});
      }),
    );

    expect(await repository.imageFor(_page), isNull);
    expect(handOffFiles(), isEmpty);
  });
}
