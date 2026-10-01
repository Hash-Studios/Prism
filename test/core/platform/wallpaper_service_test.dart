import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:async_wallpaper/pigeon_impl_api.dart' as wallpaper_api;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.async_wallpaper.WallpaperApi.applyWallpaper',
    wallpaper_api.WallpaperApi.pigeonChannelCodec,
  );
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));

  for (final source in <String, String>{
    'file:///tmp/filtered%20wall%23one.png': '/tmp/filtered wall#one.png',
    '/storage/emulated/0//wall.png': '/storage/emulated/0/wall.png',
  }.entries) {
    test('applies ${source.key} as its decoded local path', () async {
      wallpaper_api.StaticWallpaperRequestData? request;
      messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
        request = (message! as List<Object?>).single! as wallpaper_api.StaticWallpaperRequestData;
        return <Object?>[
          wallpaper_api.OperationResultData(
            status: wallpaper_api.OperationStatusData.applied,
            requestedTarget: wallpaper_api.WallpaperTargetData.home,
            home: wallpaper_api.TargetResultData(status: wallpaper_api.TargetStatusData.applied),
          ),
        ];
      });

      expect(await WallpaperService.setWallpaperFromSource(source.key, WallpaperTarget.home), isTrue);
      expect(request?.source?.filePath, source.value);
      expect(request?.source?.kind, wallpaper_api.WallpaperSourceKindData.filePath);
      expect(request?.target, wallpaper_api.WallpaperTargetData.home);
    });
  }
}
