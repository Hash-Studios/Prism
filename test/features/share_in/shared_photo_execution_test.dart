import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/photo_wallpaper_page.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
final PhotoSource _photo = PhotoSource(bytes: _png, size: const PhotoSize(4000, 3000));

class _ActivityApi extends PrismLiveActivityHostApi {
  final Completer<String?> started = Completer<String?>();
  int starts = 0;
  int cancellations = 0;

  @override
  Future<String?> startAiGeneration(AiActivityRequest request) {
    starts++;
    return started.future;
  }

  @override
  Future<void> cancelAiGeneration(String id) async => cancellations++;
}

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'share-owner'
      ..loggedIn = true;
    CoinsService.instance.balanceNotifier.value = 500;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpPage(WidgetTester tester, PhotoWallpaperRepository repository) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PhotoWallpaperPage(
          repository: repository,
          initialSource: _photo,
          screenSize: const PhotoSize(1080, 2340),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a shared initial photo opens its plan without compressing or sending the image', (tester) async {
    int uploadsPrepared = 0;
    int calls = 0;
    final PhotoWallpaperRepository repository = PhotoWallpaperRepository(
      null,
      null,
      (Uint8List bytes, int _) async {
        uploadsPrepared++;
        return bytes;
      },
      (_) async {
        calls++;
        return null;
      },
    );

    await pumpPage(tester, repository);

    expect(find.text('Extend to fit your screen'), findsOneWidget);
    expect(uploadsPrepared, 0);
    expect(calls, 0);
  });

  testWidgets('signing out after Fit prevents Run from preparing or sending the image', (tester) async {
    int uploadsPrepared = 0;
    int calls = 0;
    final PhotoWallpaperRepository repository = PhotoWallpaperRepository(
      null,
      null,
      (Uint8List bytes, int _) async {
        uploadsPrepared++;
        return bytes;
      },
      (_) async {
        calls++;
        return null;
      },
    );
    await pumpPage(tester, repository);
    app_state.prismUser = app_constants.createGuestPrismUser();

    await tester.tap(find.byKey(const ValueKey<String>('photo-run')));
    await tester.pump(const Duration(seconds: 1));

    expect(uploadsPrepared, 0);
    expect(calls, 0);
  });

  testWidgets('switching accounts during Live Activity setup prevents the image send', (tester) async {
    final _ActivityApi api = _ActivityApi();
    final PrismLiveActivityHostApi originalApi = LiveActivityChannel.api;
    final bool Function() originalSupported = LiveActivityChannel.isSupportedPlatform;
    LiveActivityChannel.api = api;
    LiveActivityChannel.isSupportedPlatform = () => true;
    addTearDown(() {
      LiveActivityChannel.api = originalApi;
      LiveActivityChannel.isSupportedPlatform = originalSupported;
    });
    int uploadsPrepared = 0;
    final PhotoWallpaperRepository repository = PhotoWallpaperRepository(null, null, (Uint8List bytes, int _) async {
      uploadsPrepared++;
      return bytes;
    }, (_) async => null);
    await pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey<String>('photo-run')));
    await tester.pump();

    app_state.prismUser.id = 'another-account';
    api.started.complete('activity');
    await tester.pump(const Duration(seconds: 1));

    expect(uploadsPrepared, 0);
    expect(api.cancellations, api.starts, reason: 'every Live Activity that started is cancelled');
  });

  test('revoking upload permission during compression prevents the callable', () async {
    bool mayUpload = true;
    int calls = 0;
    final PhotoWallpaperRepository repository = PhotoWallpaperRepository(
      null,
      null,
      (Uint8List bytes, int _) async {
        mayUpload = false;
        return bytes;
      },
      (_) async {
        calls++;
        return null;
      },
    );
    final PhotoJobState result = await repository.run(
      PhotoJob(source: _photo, mode: PhotoJobMode.extend, target: PhotoJobTarget.phone, cost: 75),
      requestId: 'shared-photo',
      targetSize: const PhotoSize(1080, 2340),
      mayUpload: () => mayUpload,
    );

    expect(calls, 0);
    expect(
      result,
      isA<PhotoJobFailed>().having((PhotoJobFailed failure) => failure.reason, 'reason', PhotoJobFailure.signIn),
    );
  });

  test('signing out after a failed request prevents a retry with the photo', () async {
    bool mayUpload = true;
    int calls = 0;
    final PhotoWallpaperRepository repository = PhotoWallpaperRepository(null, null, (bytes, _) async => bytes, (_) {
      calls++;
      mayUpload = false;
      return Future<Object?>.error(StateError('connection lost'));
    });
    final PhotoJobState result = await repository.run(
      PhotoJob(source: _photo, mode: PhotoJobMode.extend, target: PhotoJobTarget.phone, cost: 75),
      requestId: 'shared-photo',
      targetSize: const PhotoSize(1080, 2340),
      mayUpload: () => mayUpload,
    );
    expect(calls, 1);
    expect(result, isA<PhotoJobFailed>().having((failure) => failure.reason, 'reason', PhotoJobFailure.signIn));
  });
}
