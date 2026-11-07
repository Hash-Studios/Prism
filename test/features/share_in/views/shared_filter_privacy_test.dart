import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/wait_for_real_io.dart';

void main() {
  const String mediaChannel = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  Future<void> mount(WidgetTester tester, {bool signedIn = false, bool shared = true}) async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = signedIn;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final Directory directory = Directory.systemTemp.createTempSync('shared_filter_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File image = File('${directory.path}/image.png');
    await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFFF0000));
      final ui.Picture picture = recorder.endRecording();
      final ui.Image pixels = await picture.toImage(8, 8);
      picture.dispose();
      image.writeAsBytesSync((await pixels.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      pixels.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperFilterScreen(filePath: image.path, guestShare: shared),
      ),
    );
    await waitForRealIo(tester, () {
      final Finder download = find.ancestor(of: find.byTooltip('Download'), matching: find.byType(IconButton));
      return tester.widget<IconButton>(download).onPressed != null;
    }, reason: 'shared editor image decode');
  }

  for (final bool signedIn in <bool>[false, true]) {
    testWidgets('shared Set editor never offers Share, signedIn=$signedIn', (tester) async {
      await mount(tester, signedIn: signedIn);
      expect(find.byTooltip('Share'), findsNothing);
      expect(find.byTooltip('Download'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}));
  }

  testWidgets('the ordinary signed-in editor retains Share', (tester) async {
    await mount(tester, signedIn: true, shared: false);
    expect(find.byTooltip('Share'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('shared editor requires an account for ${platform == TargetPlatform.iOS ? 'filters' : 'Android Set'}', (
      tester,
    ) async {
      int prompts = 0;
      int saves = 0;
      final Future<bool> Function(BuildContext) original = signedInActionSignIn;
      signedInActionSignIn = (_) async {
        prompts++;
        return false;
      };
      addTearDown(() => signedInActionSignIn = original);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        toastChannel,
        (_) async => true,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(mediaChannel, (_) async {
        saves++;
        return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: false)]);
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(mediaChannel, null);
      });
      await mount(tester);
      if (platform == TargetPlatform.iOS) {
        await tester.tap(find.text('AddictiveBlue'));
        await tester.pump();
      }
      await tester.tap(find.byTooltip('Download'));
      await tester.pump();
      expect(prompts, 1);
      expect(saves, 0);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant(<TargetPlatform>{platform}));
  }
}
