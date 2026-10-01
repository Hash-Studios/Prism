import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(getIt.reset);

  test('wall_of_the_day push opens its wall directly', () async {
    final FakeFirestoreClient firestore = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.wallOfTheDay: <String, Map<String, dynamic>>{
          'current': <String, dynamic>{'wallId': 'old-wall-doc'},
        },
        FirebaseCollections.walls: <String, Map<String, dynamic>>{
          'new-wall-doc': <String, dynamic>{
            'id': 'new-wall',
            'source': 'prism',
            'wallpaper_url': 'https://example.com/new.jpg',
            'wallpaper_thumb': 'https://example.com/new-thumb.jpg',
          },
        },
      },
    );
    getIt.registerSingleton<FirestoreClient>(firestore);

    final PageRouteInfo? route = await const NotificationRouteMapper().fromPayload(<String, dynamic>{
      'route': 'wall_of_the_day',
      'wall_id': 'new-wall-doc',
    }, sourceTag: 'test');

    expect(route, isA<WallpaperDetailRoute>());
    final WallpaperDetailRouteArgs args = (route! as WallpaperDetailRoute).args!;
    expect(args.wallId, 'new-wall');
    expect(args.source, WallpaperSource.prism);
    expect(args.thumbnailUrl, 'https://example.com/new-thumb.jpg');
  });
}
