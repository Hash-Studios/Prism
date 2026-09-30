import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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

  testWidgets('primary draws a compact accent button instead of a round one', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DownloadButton(link: 'https://example.com/wall.jpg', primary: true)),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
    expect(find.byType(CircularMenuButton), findsNothing);
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).size, PrismButtonSize.compact);
  });

  testWidgets('labelled puts the name under the round button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DownloadButton(link: 'https://example.com/wall.jpg', labelled: true)),
      ),
    );

    expect(find.text('Download'), findsOneWidget);
    expect(find.byType(CircularMenuButton), findsOneWidget);
  });

  testWidgets('a signed-out user sees the ad gate as a sheet with both options', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DownloadButton(link: 'https://example.com/wall.jpg')),
      ),
    );

    await tester.tap(find.byType(CircularMenuButton));
    await tester.pumpAndSettle();

    expect(find.text('Download this wallpaper'), findsOneWidget);
    expect(find.text('Watch a small video ad to download this wallpaper.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Watch ad'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Buy premium'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });
}
