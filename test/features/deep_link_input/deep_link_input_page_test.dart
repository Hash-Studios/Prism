// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:Prism/features/deep_link_input/views/pages/deep_link_input_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class _Picker extends ImagePickerPlatform {
  Future<XFile?> Function() choose = () async => XFile('/picked/wallpaper.png');
  int calls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) {
    expect(source, ImageSource.gallery);
    calls++;
    return choose();
  }
}

class _InputRouter extends AppRouter {
  _InputRouter(this.workflow, this.opened);

  final DeepLinkInputWorkflow workflow;
  final List<RouteData> opened;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('InputHost', builder: (_) => DeepLinkInputPage(workflow: workflow)),
    ),
    for (final String name in <String>[
      UploadWallRoute.name,
      EditWallRoute.name,
      WallpaperFilterRoute.name,
      DownloadWallpaperRoute.name,
      WallpaperPositionRoute.name,
      LiveWallpaperRoute.name,
      ClockPreviewRoute.name,
      ReviewPhotoPreviewRoute.name,
    ])
      AutoRoute(
        path: '/$name',
        page: PageInfo(
          name,
          builder: (data) {
            opened.add(data);
            return const Scaffold(body: Text('Wallpaper tool'));
          },
        ),
      ),
  ];
}

void main() {
  late ImagePickerPlatform previousPicker;
  late _Picker picker;
  late List<RouteData> opened;

  setUp(() {
    previousPicker = ImagePickerPlatform.instance;
    picker = _Picker();
    ImagePickerPlatform.instance = picker;
    opened = <RouteData>[];
  });

  tearDown(() => ImagePickerPlatform.instance = previousPicker);

  Future<void> showChooser(WidgetTester tester, DeepLinkInputWorkflow workflow) async {
    final router = _InputRouter(workflow, opened);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final DeepLinkInputWorkflow workflow in DeepLinkInputWorkflow.values) {
    testWidgets('${workflow.name} waits for a choice and opens the matching tool with the picked image', (
      tester,
    ) async {
      await showChooser(tester, workflow);
      expect(picker.calls, 0);
      expect(opened, isEmpty);

      await tester.tap(find.text(AppLocalizationsEn().deepLinkInputChooseImage));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(opened, hasLength(1));
      expect(find.text('Wallpaper tool'), findsOneWidget);
      expect(find.byType(DeepLinkInputPage), findsNothing);
      switch (workflow) {
        case DeepLinkInputWorkflow.uploadWall:
          expect(opened.single.name, UploadWallRoute.name);
          expect(opened.single.argsAs<UploadWallRouteArgs>().image.path, '/picked/wallpaper.png');
        case DeepLinkInputWorkflow.editWall:
          expect(opened.single.name, EditWallRoute.name);
          expect(opened.single.argsAs<EditWallRouteArgs>().image.path, '/picked/wallpaper.png');
        case DeepLinkInputWorkflow.wallpaperFilter:
          expect(opened.single.name, WallpaperFilterRoute.name);
          expect(opened.single.argsAs<WallpaperFilterRouteArgs>().filePath, '/picked/wallpaper.png');
        case DeepLinkInputWorkflow.downloadWallpaper:
          expect(opened.single.name, DownloadWallpaperRoute.name);
          final args = opened.single.argsAs<DownloadWallpaperRouteArgs>();
          expect(args.file.path, '/picked/wallpaper.png');
          expect(args.source, WallpaperSource.downloaded);
        case DeepLinkInputWorkflow.wallpaperPosition:
          expect(opened.single.name, WallpaperPositionRoute.name);
          final args = opened.single.argsAs<WallpaperPositionRouteArgs>();
          expect(args.imageUrl, '/picked/wallpaper.png');
          expect(args.entryPoint, 'deep_link');
        case DeepLinkInputWorkflow.liveWallpaper:
          expect(opened.single.name, LiveWallpaperRoute.name);
          expect(opened.single.argsAs<LiveWallpaperRouteArgs>().imageUrl, '/picked/wallpaper.png');
        case DeepLinkInputWorkflow.clockPreview:
          expect(opened.single.name, ClockPreviewRoute.name);
          final args = opened.single.argsAs<ClockPreviewRouteArgs>();
          expect(args.link, '/picked/wallpaper.png');
          expect(args.file, isTrue);
        case DeepLinkInputWorkflow.photoPreview:
          expect(opened.single.name, ReviewPhotoPreviewRoute.name);
          final args = opened.single.argsAs<ReviewPhotoPreviewRouteArgs>();
          expect(args.url, '/picked/wallpaper.png');
          expect(args.thumbUrl, '/picked/wallpaper.png');
          expect(args.file, isTrue);
      }
    });
  }

  testWidgets('cancel stays on the chooser and allows another selection', (tester) async {
    picker.choose = () async => null;
    await showChooser(tester, DeepLinkInputWorkflow.wallpaperFilter);
    await tester.tap(find.text(AppLocalizationsEn().deepLinkInputChooseImage));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.text(AppLocalizationsEn().deepLinkInputChooseImage), findsOneWidget);
    expect(find.text(AppLocalizationsEn().deepLinkInputGalleryError), findsNothing);

    picker.choose = () async => XFile('/picked/second.png');
    await tester.tap(find.text(AppLocalizationsEn().deepLinkInputChooseImage));
    await tester.pumpAndSettle();
    expect(opened.single.argsAs<WallpaperFilterRouteArgs>().filePath, '/picked/second.png');
  });

  testWidgets('picker failure shows a recoverable error without opening a tool', (tester) async {
    picker.choose = () async => throw PlatformException(code: 'photo_access_denied');
    await showChooser(tester, DeepLinkInputWorkflow.editWall);
    await tester.tap(find.text(AppLocalizationsEn().deepLinkInputChooseImage));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.text(AppLocalizationsEn().deepLinkInputGalleryError), findsOneWidget);

    picker.choose = () async => XFile('/picked/retry.png');
    await tester.tap(find.text(AppLocalizationsEn().deepLinkInputChooseImage));
    await tester.pumpAndSettle();
    expect(opened.single.argsAs<EditWallRouteArgs>().image.path, '/picked/retry.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank picker paths never open a tool', (tester) async {
    for (final String path in <String>['', '   \t\n']) {
      picker.choose = () async => XFile(path);
      await showChooser(tester, DeepLinkInputWorkflow.uploadWall);
      await tester.tap(find.text(AppLocalizationsEn().deepLinkInputChooseImage));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.text(AppLocalizationsEn().deepLinkInputGalleryError), findsOneWidget);
    }
  });

  testWidgets('an in-flight picker cannot open twice and ignores a result after the page closes', (tester) async {
    final pending = Completer<XFile?>();
    picker.choose = () => pending.future;
    await showChooser(tester, DeepLinkInputWorkflow.liveWallpaper);
    await tester.tap(find.text('Choose image'));
    await tester.pump();
    expect(picker.calls, 1);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(picker.calls, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(XFile('/picked/late.png'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
