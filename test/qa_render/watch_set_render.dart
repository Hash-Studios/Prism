@Tags(<String>['qa_render'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/watch_set/data/watch_type_store.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/features/watch_set/views/watch_guide.dart';
import 'package:Prism/features/watch_set/views/watch_set_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/in_memory_local_store.dart';
import 'qa_harness.dart';

/// A second save in one test process stalls, so the save scene renders one theme per run: light by default, dark with
/// `--dart-define=QA_SAVE_DARK=true`.
const bool _saveDark = bool.fromEnvironment('QA_SAVE_DARK');

/// The watch set: the watch list, the set with and without a desktop version, the crop with each mask, the real save
/// path writing its files to build/qa_render/saved/, and the guides.
void main() {
  late Directory temp;
  late File wall;

  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    await loadFonts();
    temp = Directory.systemTemp.createTempSync('qa_watch_set_');
    wall = File('${temp.path}/wall.jpg')
      ..writeAsBytesSync(File('assets/images/onboarding_bg_primary.jpg').readAsBytesSync());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => temp.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
  });

  Future<void> remember(WatchFormat? format) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    if (getIt.isRegistered<SettingsLocalDataSource>()) getIt.unregister<SettingsLocalDataSource>();
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    if (format != null) await settings.set(watchFormatSettingsKey, format.id);
  }

  WatchSetWall wallOf({WallDesktopVariant? desktop, String name = 'wall'}) {
    final File file = File('${temp.path}/$name.jpg');
    if (!file.existsSync()) wall.copySync(file.path);
    return WatchSetWall(
      id: 'qa-$name',
      source: WallpaperSource.wallhaven,
      link: file.path,
      previewUrl: file.path,
      isPremium: false,
      pixelSize: const Size(1024, 1536),
      desktop: desktop,
    );
  }

  const WallDesktopVariant desktop = WallDesktopVariant(
    version: 'aaaaaaaaaaaaaaaa',
    thumbnailUrl: 'https://img.prismwalls.com/previews/desktop-qa.jpg',
    width: 2560,
    height: 1600,
  );

  Widget opener(void Function(BuildContext context) open) => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(onPressed: () => open(context), child: const Text('open')),
      ),
    ),
  );

  Widget scaled(double textScale, Widget child) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );

  Future<void> open(QaShot shot, void Function(BuildContext context) show) async {
    await shot.pump(opener(show));
    await shot.tester.tap(find.text('open'));
    await shot.settle(frames: 10);
  }

  Future<T> onPlatform<T>(TargetPlatform platform, Future<T> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      return await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  qaScreen('watch list on Android', (QaShot shot) async {
    await remember(null);
    await open(shot, (context) => showWatchSetSheet(context, wallOf()));
    await shot.save('watch_picker_android');
  });

  qaScreen('watch list on iPhone', (QaShot shot) async {
    await remember(null);
    await onPlatform(TargetPlatform.iOS, () async {
      await open(shot, (context) => showWatchSetSheet(context, wallOf()));
      await shot.save('watch_picker_ios');
    });
  });

  qaScreen('watch set with desktop, Galaxy Watch', (QaShot shot) async {
    await remember(WatchFormat.galaxyLarge);
    await open(shot, (context) => showWatchSetSheet(context, wallOf(desktop: desktop)));
    await shot.save('watch_set_galaxy_desktop');
  });

  qaScreen('watch set, Apple Watch, iPhone', (QaShot shot) async {
    await remember(WatchFormat.apple46);
    await onPlatform(TargetPlatform.iOS, () async {
      await open(shot, (context) => showWatchSetSheet(context, wallOf()));
      await shot.save('watch_set_apple');
      await shot.tester.tap(find.text('Adjust watch crop'));
      await shot.settle(frames: 8);
      await shot.save('watch_crop_apple');
    });
  });

  qaScreen('watch crop, round', (QaShot shot) async {
    await remember(WatchFormat.pixelWatch);
    await open(shot, (context) => showWatchSetSheet(context, wallOf()));
    await shot.tester.tap(find.text('Adjust watch crop'));
    await shot.settle(frames: 8);
    final TestGesture drag = await shot.tester.startGesture(shot.tester.getCenter(find.bySemanticsLabel('Crop area')));
    await drag.moveBy(const Offset(-30, 0));
    await drag.moveBy(const Offset(-60, 0));
    await shot.tester.pump(const Duration(milliseconds: 300));
    await shot.save('watch_crop_round_drag');
    await drag.up();
    await shot.settle();
    await shot.tester.tap(find.text('Use this crop'));
    await shot.settle(frames: 8);
    await shot.save('watch_set_after_crop');
  });

  qaScreen('watch set save and guide', (QaShot shot) async {
    if ((shot.mode == 'dark') != _saveDark) return;
    await remember(WatchFormat.apple46);
    final Directory saved = Directory('build/qa_render/saved')..createSync(recursive: true);
    OfflineAssetStore.testOverride = OfflineAssetStore(
      directory: Directory('${temp.path}/retained_${shot.mode}'),
      cacheManager: PrismImageCache.instance,
    );
    addTearDown(() => OfflineAssetStore.testOverride = null);
    shot.backend.onCall = (String name, Map<String, dynamic> parameters) async => <String, Object>{
      'success': true,
      'changed': true,
      'previousBalance': 340,
      'currentBalance': 335,
      'delta': -5,
      'transactionId': 'qa_spend',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
        PrismMediaHostApi.pigeonChannelCodec,
      ),
      (Object? message) async {
        final DownloadRequest request = (message! as List<Object?>).single! as DownloadRequest;
        final String extension = request.link.endsWith('.png') ? 'png' : 'jpg';
        File(request.link).copySync('${saved.path}/${request.filenameWithoutExtension}.$extension');
        return <Object?>[OperationResult(success: true)];
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
        PrismMediaHostApi.pigeonChannelCodec,
      ),
      (_) async => <Object?>[DownloadItemsResult(success: true, items: const <String>[])],
    );
    await onPlatform(TargetPlatform.iOS, () async {
      await open(shot, (context) => showWatchSetSheet(context, wallOf(name: 'sunset_${shot.mode}')));
      await shot.tester.tap(find.textContaining('Save set'));
      for (int i = 0; i < 240 && find.text('Put it on your watch').evaluate().isEmpty; i++) {
        await shot.settle(frames: 2);
      }
      expect(find.text('Put it on your watch'), findsOneWidget);
      await shot.settle(frames: 4);
      await shot.save('watch_saved_guide_ios');
    });
    for (final File file in saved.listSync().whereType<File>().where((f) => f.path.contains('_${shot.mode}'))) {
      final ui.ImmutableBuffer buffer = (await shot.tester.runAsync(
        () => ui.ImmutableBuffer.fromUint8List(file.readAsBytesSync()),
      ))!;
      final ui.ImageDescriptor descriptor = (await shot.tester.runAsync(() => ui.ImageDescriptor.encoded(buffer)))!;
      debugPrint('QA_SAVED ${file.path.split('/').last} ${descriptor.width}x${descriptor.height}');
      descriptor.dispose();
      buffer.dispose();
    }
    await shot.tester.pumpWidget(const SizedBox());
    await getIt<SettingsLocalDataSource>().delete('pendingDownloads_v2');
    for (int i = 0; i < 3; i++) {
      await shot.tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await shot.tester.pump(const Duration(minutes: 3));
    }
  });

  qaScreen('watch guide, Wear OS', (QaShot shot) async {
    await open(
      shot,
      (context) => showPrismSheet<void>(context, builder: (_) => const WatchGuide(format: WatchFormat.pixelWatch)),
    );
    await shot.save('watch_guide_wearos');
  });

  for (final double textScale in <double>[2]) {
    qaScreen('watch set text x$textScale', (QaShot shot) async {
      await remember(WatchFormat.apple42);
      await open(
        shot,
        (context) => showPrismSheet<void>(
          context,
          builder: (_) => scaled(textScale, WatchSetSheet(wall: wallOf(desktop: desktop))),
        ),
      );
      await shot.save('watch_set_large_text');
    });

    qaScreen('watch guide text x$textScale', (QaShot shot) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await open(
          shot,
          (context) => showPrismSheet<void>(
            context,
            builder: (_) => scaled(textScale, WatchGuide(format: WatchFormat.apple46, onShare: () {})),
          ),
        );
        await shot.save('watch_guide_ios_large_text');
      });
    });
  }
}
