import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/short_link_resolver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

ShortLinkResolver _resolverFor(Future<http.Response> Function(http.Request request) handler) =>
    ShortLinkResolver(client: MockClient(handler));

void main() {
  test('failed short links open only inside a supported browser surface', () async {
    bool supported = true;
    bool fails = false;
    Uri? launchedUrl;
    launcher.LaunchMode? launchedMode;
    final resolver = ShortLinkResolver(
      client: MockClient((_) async => http.Response('{}', 404)),
      supportsLaunchMode: (mode) async => supported && mode == launcher.LaunchMode.inAppBrowserView,
      launchUrl: (url, {required mode}) async {
        launchedUrl = url;
        launchedMode = mode;
        if (fails) throw PlatformException(code: 'launch-failed');
        return true;
      },
    );

    expect(await resolver.openFallback('failed'), isTrue);
    expect(launchedUrl.toString(), 'https://prismwalls.com/l/failed');
    expect(launchedMode, launcher.LaunchMode.inAppBrowserView);

    supported = false;
    launchedUrl = null;
    expect(await resolver.openFallback('failed'), isFalse);
    expect(launchedUrl, isNull);

    supported = true;
    fails = true;
    expect(await resolver.openFallback('failed'), isFalse);
  });

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

  test('a canonical url that points to another short link fails instead of recursing', () async {
    final resolver = _resolverFor(
      (_) async => http.Response(jsonEncode(<String, String>{'canonical_url': 'https://prismwalls.com/l/next'}), 200),
    );

    final result = await resolver.resolve('abc');

    expect((result as ShortLinkFailed).reason, AnalyticsReasonValue.missingData);
  });

  test('a non-2xx response fails with error', () async {
    final resolver = _resolverFor((_) async => http.Response('nope', 404));

    final result = await resolver.resolve('abc');

    expect((result as ShortLinkFailed).reason, AnalyticsReasonValue.error);
  });

  test('a timeout fails with error', () async {
    final resolver = _resolverFor((_) => Future<http.Response>.error(TimeoutException('slow')));

    final result = await resolver.resolve('abc');

    expect((result as ShortLinkFailed).reason, AnalyticsReasonValue.error);
  });
}
