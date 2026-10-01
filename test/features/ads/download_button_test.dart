import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _ThrowingSettings extends SettingsLocalDataSource {
  _ThrowingSettings() : super(InMemoryLocalStore());

  @override
  bool get isOpen => throw StateError('settings unavailable');
}

void main() {
  for (final source in <String, bool>{
    '/tmp/filtered wall.png': true,
    'file:///tmp/filtered%20wall.png': true,
    '/data/user/0/com.hash.prism/cache/wall.png': true,
    'https://example.com/com.hash.prism/wall.jpg': false,
  }.entries) {
    testWidgets('downloads ${source.key} with the correct native source kind', (tester) async {
      getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
      app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
      final requests = <Object?>[];
      final channels = <BasicMessageChannel<Object?>>[
        for (final method in <String>['saveMedia', 'enqueueDownload'])
          BasicMessageChannel<Object?>(
            'dev.flutter.pigeon.Prism.PrismMediaHostApi.$method',
            PrismMediaHostApi.pigeonChannelCodec,
          ),
      ];
      for (final channel in channels) {
        tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
          requests.add((message! as List<Object?>).single);
          return <Object?>[OperationResult(success: true)];
        });
      }
      addTearDown(() async {
        for (final channel in channels) {
          tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
        }
        app_state.prismUser = app_constants.createGuestPrismUser();
        await getIt.reset();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DownloadButton(link: source.key)),
        ),
      );
      await tester.tap(find.byType(CircularMenuButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requests, hasLength(1));
      if (source.value) {
        final request = requests.single! as SaveMediaRequest;
        expect(request.link, source.key);
        expect(request.isLocalFile, isTrue);
        expect(request.kind, SaveMediaKind.wallpaper);
      } else {
        final request = requests.single! as DownloadRequest;
        expect(request.link, source.key);
        expect(request.filenameWithoutExtension, 'wall');
      }
    });
  }

  testWidgets('successful download records callback when permission prompt fails', (tester) async {
    getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
    app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => <Object?>[OperationResult(success: true)],
    );
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    var callbackCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadButton(link: 'https://example.com/wall.jpg', onDownloaded: () => callbackCount++),
        ),
      ),
    );
    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(callbackCount, 1);
  });

  testWidgets('download that finishes after leaving the page still shows the saved toast', (tester) async {
    getIt.registerSingleton<SettingsLocalDataSource>(_ThrowingSettings());
    app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
    const BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final Completer<void> downloadFinished = Completer<void>();
    final List<Object?> toastMessages = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, (_) async {
      await downloadFinished.future;
      return <Object?>[OperationResult(success: true)];
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']);
      return true;
    });
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(channel, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DownloadButton(link: 'https://example.com/wall.jpg')),
      ),
    );
    await tester.tap(find.byType(CircularMenuButton));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    downloadFinished.complete();
    await tester.pump(const Duration(milliseconds: 100));

    expect(toastMessages, contains('Wall downloaded in Pictures/Prism!'));
    await tester.pump(const Duration(seconds: 1));
  });
}
