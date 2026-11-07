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

  test('isPublicAddress accepts public addresses and refuses private, reserved and embedded private ones', () {
    for (final String ip in <String>[
      '8.8.8.8',
      '151.101.1.1',
      '2606:4700::1111',
      '2001:200::1',
      '3ffd::1',
      '3fff:1000::1',
    ]) {
      expect(isPublicAddress(InternetAddress(ip)), isTrue, reason: ip);
    }
    for (final String ip in <String>[
      '127.0.0.1',
      '10.1.2.3',
      '172.16.0.1',
      '192.168.1.1',
      '169.254.169.254',
      '100.64.0.1',
      '0.0.0.0',
      '224.0.0.1',
      '255.255.255.255',
      '198.18.0.1',
      '192.0.2.1',
      '203.0.113.5',
      '::1',
      '::',
      'fc00::1',
      'fe80::1',
      'ff02::1',
      '2001:db8::1',
      '2002:c0a8:101::1',
      '::ffff:127.0.0.1',
      '64:ff9b::a00:1',
      '::ffff:8.8.8.8',
      '0:0:0:0:0:ffff:808:808',
      '64:ff9b::808:808',
      '3ffe::1',
      '3fff:fff:ffff::1',
      '2606:4700::5efe:8.8.8.8',
      '2606:4700:0:0:200:5efe:808:808',
    ]) {
      expect(isPublicAddress(InternetAddress(ip)), isFalse, reason: ip);
    }
  });

  group('publicOnlyHttpClient', () {
    Future<Object?> connectError(HttpClient client, String url) async {
      try {
        await client.getUrl(Uri.parse(url));
        return null;
      } on SocketException catch (error) {
        return error;
      } finally {
        client.close(force: true);
      }
    }

    test('refuses a host that resolves to a private address', () async {
      int lookups = 0;
      final HttpClient client = publicOnlyHttpClient((_) async {
        lookups++;
        return <InternetAddress>[InternetAddress('10.0.0.1')];
      });
      expect(await connectError(client, 'https://cdn.example.com/a.png'), isA<SocketException>());
      expect(lookups, 1, reason: 'an unrelated HTTP override or DNS failure must not make this test pass');
    });

    test('refuses a host with one private address among public ones', () async {
      final HttpClient client = publicOnlyHttpClient(
        (_) async => <InternetAddress>[InternetAddress('8.8.8.8'), InternetAddress('192.168.0.2')],
      );
      expect(await connectError(client, 'https://cdn.example.com/a.png'), isA<SocketException>());
    });

    test('refuses a host that does not resolve', () async {
      final HttpClient client = publicOnlyHttpClient((_) async => <InternetAddress>[]);
      expect(await connectError(client, 'https://cdn.example.com/a.png'), isA<SocketException>());
    });

    test('refuses plain http without resolving it', () async {
      int lookups = 0;
      final HttpClient client = publicOnlyHttpClient((_) async {
        lookups++;
        return <InternetAddress>[InternetAddress('8.8.8.8')];
      });
      expect(await connectError(client, 'http://cdn.example.com/a.png'), isA<SocketException>());
      expect(lookups, 0);
    });

    test('DNS refusal happens before any socket attempt', () async {
      int lookups = 0;
      int connections = 0;
      await IOOverrides.runZoned(
        () async {
          for (final List<String> answers in <List<String>>[
            <String>[],
            <String>['10.0.0.1'],
            <String>['8.8.8.8', '192.168.0.2'],
          ]) {
            final HttpClient client = publicOnlyHttpClient((_) async {
              lookups++;
              return answers.map(InternetAddress.new).toList();
            });
            expect(await connectError(client, 'https://cdn.example.com/a.png'), isA<SocketException>());
          }
        },
        socketStartConnect: (Object? host, int port, {Object? sourceAddress, int sourcePort = 0}) {
          connections++;
          throw const SocketException('An OS refusal must not make the policy test pass.');
        },
      );
      expect(lookups, 3);
      expect(connections, 0);
    });

    test('an IPv6 literal is resolved without brackets and pins its raw address', () async {
      const String ip = '2606:4700::1111';
      final List<String> lookups = <String>[];
      int connections = 0;
      await IOOverrides.runZoned(
        () async {
          final HttpClient client = publicOnlyHttpClient((String host) async {
            lookups.add(host);
            return <InternetAddress>[InternetAddress(host)];
          });
          expect(await connectError(client, 'https://[$ip]/image'), isA<SocketException>());
        },
        socketStartConnect: (Object? host, int port, {Object? sourceAddress, int sourcePort = 0}) {
          connections++;
          expect(host, isA<InternetAddress>());
          expect((host! as InternetAddress).rawAddress, InternetAddress(ip).rawAddress);
          expect(port, 443);
          throw const SocketException('Stop after checking the pinned address.');
        },
      );
      expect(lookups, <String>[ip]);
      expect(connections, 1);
    });

    test('does not replace an installed network policy, including local QA', () {
      int clients = 0;
      expect(
        () => HttpOverrides.runZoned(
          () => publicOnlyHttpClient((_) async => <InternetAddress>[InternetAddress('8.8.8.8')]).close(force: true),
          createHttpClient: (SecurityContext? context) {
            clients++;
            return _DirectHttp().createHttpClient(context);
          },
        ),
        throwsA(isA<SocketException>()),
      );
      expect(clients, 0);
    });

    test('closing during DNS prevents a late answer from opening a socket', () async {
      final Completer<List<InternetAddress>> dns = Completer<List<InternetAddress>>();
      final Completer<void> resolving = Completer<void>();
      int connections = 0;
      await IOOverrides.runZoned(
        () async {
          final HttpClient client = publicOnlyHttpClient((_) {
            resolving.complete();
            return dns.future;
          });
          final Future<Object?> error = connectError(client, 'https://cdn.example.com/a.png');
          await resolving.future;
          await Future<void>.delayed(Duration.zero);
          client.close(force: true);
          dns.complete(<InternetAddress>[InternetAddress('8.8.8.8')]);
          expect(await error, isA<SocketException>());
          expect(connections, 0);
        },
        socketStartConnect: (Object? host, int port, {Object? sourceAddress, int sourcePort = 0}) {
          connections++;
          throw const SocketException('The test must not open a real socket.');
        },
      );
    });
    test('closing during stalled TLS closes the peer', () async {
      final ServerSocket server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final Completer<Socket> accepted = Completer<Socket>();
      final Completer<void> hello = Completer<void>();
      final Completer<void> closed = Completer<void>();
      final StreamSubscription<Socket> listener = server.listen((Socket peer) {
        accepted.complete(peer);
        peer.listen(
          (_) {
            if (!hello.isCompleted) hello.complete();
          },
          onDone: () => closed.complete(),
          onError: (Object _) {},
        );
      });
      Socket? peer;
      final _DirectIo nativeIo = _DirectIo();
      try {
        await IOOverrides.runZoned(
          () async {
            final HttpClient client = publicOnlyHttpClient((_) async => <InternetAddress>[InternetAddress('8.8.8.8')]);
            final Future<void> request = client
                .getUrl(Uri.parse('https://cdn.example.com/image'))
                .then<void>((_) {}, onError: (Object _) {});
            try {
              peer = await accepted.future.timeout(const Duration(seconds: 2));
              await hello.future.timeout(const Duration(seconds: 2));
              client.close(force: true);
              final bool didClose = await closed.future
                  .then((_) => true)
                  .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
              expect(didClose, isTrue, reason: 'the peer never replies to ClientHello; cancellation must close it');
            } finally {
              client.close(force: true);
              peer?.destroy();
              await request.timeout(const Duration(seconds: 2));
            }
          },
          socketStartConnect: (Object? host, int port, {Object? sourceAddress, int sourcePort = 0}) {
            return nativeIo.socketStartConnect(InternetAddress.loopbackIPv4, server.port);
          },
        );
      } finally {
        peer?.destroy();
        await listener.cancel();
        await server.close();
      }
    }, skip: 'Known SDK ownership gap: SecureSocket.secure detaches the raw socket before its handshake completes.');
  });
}

class _DirectHttp extends HttpOverrides {}

final class _DirectIo extends IOOverrides {}
