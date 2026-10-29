import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

final String _previewPath = File('assets/images/prism.webp').absolute.path;

const aw.WallpaperCapabilities _allCapabilities = aw.WallpaperCapabilities(
  supportsStaticWallpaper: true,
  supportsHomeWallpaper: true,
  supportsLockWallpaper: true,
  supportsBothWallpapers: true,
);

const ValueKey<String> _setKey = ValueKey<String>('set-screen-set');

class _Client implements WallpaperClient {
  _Client({this.capabilities = const aw.WallpaperCapabilities()});

  final aw.WallpaperCapabilities capabilities;

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => capabilities;

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async =>
      aw.WallpaperOperationResult(status: aw.WallpaperOperationStatus.applied, requestedTarget: request.target);

  @override
  Future<aw.WallpaperOperationResult> prepareVideoWallpaper(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> openLiveWallpaperPreview(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> applyOpenGlWallpaper(aw.OpenGlLiveWallpaperRequest request) =>
      throw UnimplementedError();
}

/// Fails every save, the way a full disk would.
class _FailingSettings extends SettingsLocalDataSource {
  _FailingSettings() : super(InMemoryLocalStore());

  @override
  Future<void> set(String key, Object? value) => Future<void>.error(StateError('disk full'));
}

/// Opens the Set screen from a button, the way a caller does.
Future<void> _openSetScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSetScreen(context, SetScreenRequest(url: _previewPath)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();
  late SettingsLocalDataSource settings;

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    aw.AsyncWallpaper.debugSetClient(_Client(capabilities: _allCapabilities));
  });

  tearDown(() async {
    aw.AsyncWallpaper.debugResetClient();
    await getIt.reset();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('lastTarget is null until saveLastTarget stores a target', (tester) async {
    expect(SetWallpaperFlow.lastTarget(), isNull);

    SetWallpaperFlow.saveLastTarget(WallpaperTarget.lock);
    await tester.pump();

    expect(SetWallpaperFlow.lastTarget(), WallpaperTarget.lock);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('with no default saved, the Set screen starts on the last target', (tester) async {
    await settings.set(PersistenceKeys.lastApplyTarget, 'lock');
    await _openSetScreen(tester);

    expect(find.text('Set on lock screen'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a saved default target wins over the last target', (tester) async {
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    await settings.set(PersistenceKeys.lastApplyTarget, 'lock');
    await _openSetScreen(tester);

    expect(find.text('Set on home screen'), findsOneWidget);
    expect(find.text('Set on lock screen'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Set on the Set screen remembers the chosen target as the last target', (tester) async {
    await _openSetScreen(tester);

    await tester.tap(find.text(l10n.setScreenTargetBoth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_setKey));
    await tester.pumpAndSettle();

    expect(settings.get<String>(PersistenceKeys.lastApplyTarget, defaultValue: ''), 'both');
    expect(SetWallpaperFlow.lastTarget(), WallpaperTarget.both);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  // Guards lib: `saveLastTarget` catches the Future error from `SettingsLocalDataSource.set`.
  testWidgets('a failed async save of the last target does not throw', (tester) async {
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(_FailingSettings());

    SetWallpaperFlow.saveLastTarget(WallpaperTarget.lock);
    await tester.pump();

    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
