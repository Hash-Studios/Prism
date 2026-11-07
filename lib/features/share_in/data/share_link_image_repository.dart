import 'dart:async';
import 'dart:io';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/features/share_in/data/shared_inbox.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Finds the image of a shared web page (`shareLinkImage` callable) and downloads it to the hand-off folder.
class ShareLinkImageRepository {
  ShareLinkImageRepository({
    required SharedInbox inbox,
    Future<Object?> Function(String url)? lookup,
    http.Client? client,
    this.timeout = downloadTimeout,
  }) : _inbox = inbox,
       _lookup = lookup ?? _callLookup,
       _client = client;

  static const int maxImageBytes = 25 * 1024 * 1024;
  static const Duration downloadTimeout = Duration(seconds: 20);

  final SharedInbox _inbox;
  final Future<Object?> Function(String url) _lookup;
  final http.Client? _client;
  final Duration timeout;

  /// The local path of the page's image, or null when the page has none Prism can use.
  Future<String?> imageFor(Uri page) async {
    try {
      final Object? data = await _lookup(page.toString());
      final Object? imageUrl = data is Map ? data['imageUrl'] : null;
      final Uri? image = imageUrl is String ? Uri.tryParse(imageUrl) : null;
      if (image == null || !_isHttps(image)) return null;
      return await _download(image);
    } catch (error) {
      logger.w('[ShareIn] link image failed (${error.runtimeType})');
      return null;
    }
  }

  Future<String?> _download(Uri image) async {
    final http.Client client = _client ?? IOClient(publicOnlyHttpClient(InternetAddress.lookup));
    final Stopwatch elapsed = Stopwatch()..start();
    Duration remaining() {
      final Duration left = timeout - elapsed.elapsed;
      if (left <= Duration.zero) throw TimeoutException('The image download timed out.');
      return left;
    }

    File? file;
    try {
      http.StreamedResponse response;
      Uri current = image;
      for (int redirects = 0; ; redirects++) {
        final http.Request request = http.Request('GET', current)..followRedirects = false;
        response = await client.send(request).timeout(remaining());
        if (!const <int>{301, 302, 303, 307, 308}.contains(response.statusCode)) break;
        await response.stream.listen(null).cancel();
        final String? location = response.headers['location'];
        if (redirects == 3 || location == null) return null;
        current = current.resolve(location);
        if (!_isHttps(current)) return null;
      }
      final String type = response.headers['content-type']?.toLowerCase() ?? '';
      if (response.statusCode != 200 || !type.startsWith('image/') || (response.contentLength ?? 0) > maxImageBytes) {
        await response.stream.listen(null).cancel();
        return null;
      }
      file = await _inbox.newHandOffFile(_extensionFor(type));
      final IOSink sink = file.openWrite();
      final StreamIterator<List<int>> chunks = StreamIterator<List<int>>(response.stream);
      int total = 0;
      try {
        while (await chunks.moveNext().timeout(remaining())) {
          final List<int> chunk = chunks.current;
          total += chunk.length;
          if (total > maxImageBytes) throw const FileSystemException('The image is too large.');
          sink.add(chunk);
        }
      } finally {
        await chunks.cancel();
        await sink.close();
      }
      if (total == 0) throw const FileSystemException('The image is empty.');
      return file.path;
    } catch (_) {
      if (file != null) await _inbox.discard(file.path);
      rethrow;
    } finally {
      if (_client == null) client.close();
    }
  }

  static bool _isHttps(Uri uri) =>
      uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty && uri.port == 443;

  static String _extensionFor(String type) => switch (type.split(';').first.trim()) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    'image/heic' => 'heic',
    _ => 'jpg',
  };

  static Future<Object?> _callLookup(String url) async =>
      (await appFunctions
              .httpsCallable('shareLinkImage', options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
              .call<Object?>(<String, Object?>{'url': url}))
          .data;
}

/// An [HttpClient] that connects only to a checked public address of the URL's host, so a shared link cannot send the
/// device to a private service, also not through a redirect or a second DNS answer. TLS still checks the host name.
HttpClient publicOnlyHttpClient(Future<List<InternetAddress>> Function(String host) resolve) {
  final HttpClient client = HttpClient()..findProxy = (_) => 'DIRECT';
  client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
    if (proxyHost != null || uri.scheme != 'https') throw const SocketException('Only direct https is allowed.');
    final List<InternetAddress> addresses = await resolve(uri.host);
    if (addresses.isEmpty || !addresses.every(isPublicAddress)) {
      throw SocketException('${uri.host} does not resolve to a public address.');
    }
    final ConnectionTask<Socket> task = await Socket.startConnect(addresses.first, uri.port);
    return ConnectionTask.fromSocket(
      task.socket.then((Socket socket) => SecureSocket.secure(socket, host: uri.host)),
      task.cancel,
    );
  };
  return client;
}

/// True for an address on the public internet. Mapped and NAT64 IPv6 forms are checked as their IPv4 address.
bool isPublicAddress(InternetAddress address) {
  final List<int> b = address.rawAddress;
  if (b.length == 4) return _isPublicV4(b);
  if (b.length != 16) return false;
  final bool mapped = b.sublist(0, 10).every((int it) => it == 0) && b[10] == 0xff && b[11] == 0xff;
  final bool nat64 =
      b[0] == 0x00 && b[1] == 0x64 && b[2] == 0xff && b[3] == 0x9b && b.sublist(4, 12).every((int it) => it == 0);
  if (mapped || nat64) return _isPublicV4(b.sublist(12));
  if (b[0] & 0xe0 != 0x20) return false;
  if (b[0] == 0x20 && b[1] == 0x02) return false;
  if (b[0] == 0x20 && b[1] == 0x01 && (b[2] < 0x02 || b[2] == 0x0d && b[3] == 0xb8)) return false;
  return true;
}

bool _isPublicV4(List<int> b) {
  final int a = b[0];
  return !(a == 0 ||
      a == 10 ||
      a == 127 ||
      a >= 224 ||
      a == 100 && b[1] >= 64 && b[1] < 128 ||
      a == 169 && b[1] == 254 ||
      a == 172 && b[1] >= 16 && b[1] < 32 ||
      a == 192 && b[1] == 0 && (b[2] == 0 || b[2] == 2) ||
      a == 192 && b[1] == 88 && b[2] == 99 ||
      a == 192 && b[1] == 168 ||
      a == 198 && (b[1] == 18 || b[1] == 19) ||
      a == 198 && b[1] == 51 && b[2] == 100 ||
      a == 203 && b[1] == 0 && b[2] == 113);
}
