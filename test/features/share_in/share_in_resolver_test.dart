import 'dart:io';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/share_in/biz/share_in_resolver.dart';
import 'package:Prism/features/share_in/data/shared_inbox.dart';
import 'package:Prism/features/share_in/domain/shared_item.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _imageId = '123e4567-e89b-12d3-a456-426614174000';
const MethodChannel _channel = MethodChannel('test/prism_shared_inbox');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late SharedInbox inbox;
  late List<AnalyticsEvent> events;
  late String? takenPath;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('share_in_resolver_test_');
    final Directory inboxDir = Directory(p.join(root.path, 'inbox'))..createSync();
    final Directory handOffDir = Directory(p.join(root.path, 'hand_off'))..createSync();
    events = <AnalyticsEvent>[];
    takenPath = null;
    inbox = SharedInbox(
      channel: _channel,
      inboxDirectory: () async => inboxDir,
      handOffDirectory: () async => handOffDir,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      MethodCall call,
    ) async {
      if (call.method == 'directory') return inboxDir.path;
      if (call.method == 'take') {
        if (takenPath == null) throw PlatformException(code: 'missing');
        return takenPath;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<DeepLinkRouteResolution> resolve(ShareInIntent intent) {
    return resolveShareIn(intent, const DeepLinkNavigation(), inbox: inbox, track: events.add);
  }

  test('an image that the inbox returns opens the share sheet with that image', () async {
    takenPath = p.join(root.path, 'inbox', 'photo.png');

    final DeepLinkRouteResolution resolution = await resolve(
      const ShareInIntent(inboxId: _imageId, rawUri: 'prism://share-in?id=$_imageId'),
    );

    final ShareInRoute route = resolution.route! as ShareInRoute;
    expect(route.args!.kind, SharedItemKind.image);
    expect(route.args!.item, isA<SharedImage>());
    expect((route.args!.item! as SharedImage).path, takenPath);
    expect(events.whereType<ShareReceivedEvent>().single.kind, SharedItemKindValue.image);
  });

  test('an image that the inbox cannot return opens the share sheet in its failed state', () async {
    final DeepLinkRouteResolution resolution = await resolve(
      const ShareInIntent(inboxId: _imageId, rawUri: 'prism://share-in?id=$_imageId'),
    );

    final ShareInRoute route = resolution.route! as ShareInRoute;
    expect(route.args!.kind, SharedItemKind.image);
    expect(route.args!.item, isNull);
    expect(events.whereType<ShareActionEvent>().single.action, ShareActionValue.failed);
  });

  test('a web link opens the share sheet with a URL item', () async {
    final DeepLinkRouteResolution resolution = await resolve(
      const ShareInIntent(text: 'https://example.com/x', rawUri: 'prism://share-in?text=x'),
    );

    final ShareInRoute route = resolution.route! as ShareInRoute;
    expect(route.args!.kind, SharedItemKind.url);
    expect(route.args!.item, isA<SharedUrl>());
  });

  test('text with no link opens the share sheet in its failed state', () async {
    final DeepLinkRouteResolution resolution = await resolve(
      const ShareInIntent(text: 'hello', rawUri: 'prism://share-in?text=hello'),
    );

    final ShareInRoute route = resolution.route! as ShareInRoute;
    expect(route.args!.kind, SharedItemKind.url);
    expect(route.args!.item, isNull);
    expect(events.whereType<ShareActionEvent>().single.action, ShareActionValue.failed);
  });

  test('a Prism wall link opens the wall with Save to Folder open', () async {
    final DeepLinkRouteResolution resolution = await resolve(
      const ShareInIntent(text: 'https://prismwalls.com/share/w1?source=prism', rawUri: 'prism://share-in?text=x'),
    );

    final WallpaperDetailRoute route = resolution.route! as WallpaperDetailRoute;
    expect(route.args!.openFolderSheet, isTrue);
    expect(route.args!.wallId, 'w1');
    final ShareActionEvent action = events.whereType<ShareActionEvent>().single;
    expect(action.action, ShareActionValue.save);
    expect(action.kind, SharedItemKindValue.prismLink);
  });

  test('copies the source app into the share received event', () async {
    await resolve(
      const ShareInIntent(text: 'https://example.com/x', sourceApp: 'com.android.chrome', rawUri: 'prism://share-in'),
    );

    expect(events.whereType<ShareReceivedEvent>().single.sourceApp, 'com.android.chrome');
  });

  test('withFolderSheet keeps the wall and source and opens the folder sheet', () {
    final WallpaperDetailRoute input = WallpaperDetailRoute(wallId: 'a', source: WallpaperSource.prism);

    final WallpaperDetailRoute result = withFolderSheet(input);

    expect(result.args!.wallId, 'a');
    expect(result.args!.source, WallpaperSource.prism);
    expect(result.args!.openFolderSheet, isTrue);
  });
}
