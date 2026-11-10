import 'dart:convert';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const PublicProfileEntity profile = PublicProfileEntity(
    id: 'user-42',
    name: 'Alice',
    email: '',
    username: 'alice',
    profilePhoto: '',
    bio: '',
    links: <String, String>{},
    coverPhoto: '',
  );

  setUp(() => app_state.prismUser.loggedIn = false);

  test('a guest relation link does not resolve its username to a profile', () async {
    int lookups = 0;
    final PageLinkIntent intent = const DeepLinkParser().parse(Uri.parse('/user/alice/followers')) as PageLinkIntent;

    final route = await routeForPageLink(
      intent,
      profileLookup: (_) async {
        lookups++;
        return profile;
      },
    );

    expect(route, isNull);
    expect(lookups, 0);
  });

  test('relation lookup starts after sign-in and resolves the real user id', () async {
    final List<String> calls = <String>[];
    final PageLinkIntent intent = const DeepLinkParser().parse(Uri.parse('/user/alice/followers')) as PageLinkIntent;

    final route = await routeForPageLink(
      intent,
      authenticate: () async {
        calls.add('authenticate');
        app_state.prismUser.loggedIn = true;
        return true;
      },
      profileLookup: (identifier) async {
        calls.add('lookup:$identifier');
        return profile;
      },
    );

    expect(calls, <String>['authenticate', 'lookup:alice']);
    expect(route, isA<FollowersRoute>());
    expect((route! as FollowersRoute).args!.userId, 'user-42');
  });

  test('a signed-in direct relation link still resolves normally', () async {
    app_state.prismUser.loggedIn = true;
    final PageLinkIntent intent = const DeepLinkParser().parse(Uri.parse('/user/alice/following')) as PageLinkIntent;

    final route = await routeForPageLink(intent, profileLookup: (_) async => profile);

    expect(route, isA<FollowingListRoute>());
    expect((route! as FollowingListRoute).args!.userId, 'user-42');
  });

  test('short-code relation resolution forwards authentication and stops on cancellation', () async {
    final List<String> calls = <String>[];
    final http.Client client = MockClient((_) async {
      return http.Response(
        jsonEncode(<String, String>{'canonical_url': 'https://prismwalls.com/user/alice/followers'}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);
    final DeepLinkNavigation navigation = DeepLinkNavigation(httpClient: client);

    final DeepLinkRouteResolution resolution = await navigation.resolveAction(
      const ShortCodeIntent(code: 'relation-code', rawUri: 'https://prismwalls.com/l/relation-code'),
      authenticate: () async {
        calls.add('authenticate');
        return false;
      },
    );

    expect(resolution.route, isNull);
    expect(calls, <String>['authenticate']);
  });

  test('share-in nested resolution inherits its per-call authentication callback', () async {
    int authentications = 0;
    final PageLinkIntent relation = const DeepLinkParser().parse(Uri.parse('/user/alice/followers')) as PageLinkIntent;
    final DeepLinkNavigation navigation = DeepLinkNavigation(
      onShareIn: (action, scopedNavigation) => scopedNavigation.resolveAction(relation),
    );

    final DeepLinkRouteResolution resolution = await navigation.resolveAction(
      const ShareInIntent(inboxId: 'image-1', rawUri: 'prism://share-in?id=image-1'),
      authenticate: () async {
        authentications++;
        return false;
      },
    );

    expect(resolution.route, isNull);
    expect(authentications, 1);
  });
}
