import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/short_link_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ShortLinkResolver _resolverFor(Future<http.Response> Function(http.Request request) handler) =>
    ShortLinkResolver(client: MockClient(handler));

void main() {
  test('a 2xx response with a known canonical url resolves to its action', () async {
    final resolver = _resolverFor((request) async {
      expect(request.url.toString(), 'https://prismwalls.com/api/links/abc');
      return http.Response(jsonEncode(<String, String>{'canonical_url': 'https://prismwalls.com/user/akshay'}), 200);
    });

    final result = await resolver.resolve('abc');

    expect(result, isA<ShortLinkResolved>());
    expect((result as ShortLinkResolved).action, isA<UserLinkIntent>());
  });

  test('a 2xx response without a canonical url fails with missing data', () async {
    final resolver = _resolverFor((_) async => http.Response('{}', 200));

    final result = await resolver.resolve('abc');

    expect((result as ShortLinkFailed).reason, AnalyticsReasonValue.missingData);
  });

  test('a canonical url the parser does not know fails with missing data', () async {
    final resolver = _resolverFor(
      (_) async => http.Response(jsonEncode(<String, String>{'canonical_url': 'https://prismwalls.com/nothing'}), 200),
    );

    final result = await resolver.resolve('abc');

    expect((result as ShortLinkFailed).reason, AnalyticsReasonValue.missingData);
  });

  test('a non-2xx response fails with error', () async {
    final resolver = _resolverFor((_) async => http.Response('nope', 404));

    final result = await resolver.resolve('abc');

    expect((result as ShortLinkFailed).reason, AnalyticsReasonValue.error);
    expect(result.isNetwork, isFalse);
  });

  test('a timeout fails with error and counts as a network failure', () async {
    final resolver = _resolverFor((_) => Future<http.Response>.error(TimeoutException('slow')));

    final result = await resolver.resolve('abc');

    expect((result as ShortLinkFailed).reason, AnalyticsReasonValue.error);
    expect(result.isNetwork, isTrue);
  });

  test('a socket error counts as a network failure', () async {
    final resolver = _resolverFor((_) => Future<http.Response>.error(const SocketException('offline')));

    expect(((await resolver.resolve('abc')) as ShortLinkFailed).isNetwork, isTrue);
  });

  test('a server that is down counts as a network failure, a missing code does not', () async {
    expect(
      ((await _resolverFor((_) async => http.Response('', 503)).resolve('a')) as ShortLinkFailed).isNetwork,
      isTrue,
    );
    expect(
      ((await _resolverFor((_) async => http.Response('', 404)).resolve('a')) as ShortLinkFailed).isNetwork,
      isFalse,
    );
    expect(
      ((await _resolverFor((_) async => http.Response('', 400)).resolve('a')) as ShortLinkFailed).isNetwork,
      isFalse,
    );
  });

  test('a bad body is not a network failure', () async {
    final resolver = _resolverFor((_) async => http.Response('not json', 200));

    expect(((await resolver.resolve('abc')) as ShortLinkFailed).isNetwork, isFalse);
  });
}
