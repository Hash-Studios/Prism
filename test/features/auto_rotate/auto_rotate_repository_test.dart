import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String stopChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.stopWallpaperRotation';
  const String statusChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.getWallpaperRotationStatus';
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AutoRotateRepositoryImpl repository;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    repository = AutoRotateRepositoryImpl(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMessageHandler(stopChannel, null);
    messenger.setMockMessageHandler(statusChannel, null);
  });

  test('reports a rejected native stop instead of treating it as stopped', () async {
    messenger.setMockMessageHandler(
      stopChannel,
      (ByteData? _) async => const StandardMessageCodec().encodeMessage(<Object?>[false]),
    );

    expect(await repository.stop(), isFalse);
  });

  test('preserves native status-channel errors', () async {
    messenger.setMockMessageHandler(
      statusChannel,
      (ByteData? _) async =>
          const StandardMessageCodec().encodeMessage(<Object?>['channel-error', 'status unavailable', null]),
    );

    final status = await repository.status();

    expect(status.isRunning, isFalse);
    expect(status.lastError, isNotNull);
  });
}
