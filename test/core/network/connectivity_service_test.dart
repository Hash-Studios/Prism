import 'dart:io';

import 'package:Prism/core/network/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('one reachable host means online', () async {
    final checker = buildInternetConnectionChecker(
      httpClient: MockClient((http.Request request) async {
        if (request.url.host == 'prismwalls.com') return http.Response('', 200);
        throw const SocketException('unreachable');
      }),
    );

    expect(await checker.hasConnection, isTrue);
  });

  test('every host failing means offline', () async {
    final checker = buildInternetConnectionChecker(
      httpClient: MockClient((http.Request request) async => throw const SocketException('unreachable')),
    );

    expect(await checker.hasConnection, isFalse);
  });

  test('checks Prism hosts every 20 s and no third-party mock API', () {
    final checker = buildInternetConnectionChecker();

    final List<String> hosts = checker.addresses.map((address) => address.uri.host).toList();
    expect(hosts, <String>['prismwalls.com', 'firestore.googleapis.com']);
    expect(checker.checkInterval, const Duration(seconds: 20));
  });
}
