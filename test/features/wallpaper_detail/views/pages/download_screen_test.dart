import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';

const String _channelPrefix = 'dev.flutter.pigeon.Prism.PrismMediaHostApi';

class _MockStackRouter extends Mock implements StackRouter {}

/// A real [width] x [height] PNG, so the tile decodes it like a download.
Future<Uint8List> _png(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.teal);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  picture.dispose();
  final ByteData bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return bytes.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late List<String> deleteCalls;
  late Future<DownloadItemsResult> Function() onList;
  late int listCalls;
  late DownloadedWallIndex index;

  ByteData? reply(Object value) => PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[value]);

  File makeFile(String name) => File('${dir.path}/$name')..writeAsBytesSync(<int>[1, 2, 3]);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('download_screen_test');
    deleteCalls = <String>[];
    listCalls = 0;
    onList = () async => DownloadItemsResult(success: true, items: const <String>[]);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    index = DownloadedWallIndex(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<DownloadedWallIndex>(index);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('$_channelPrefix.listDownloads', (message) async {
      listCalls++;
      return reply(await onList());
    });
    messenger.setMockMessageHandler('$_channelPrefix.deleteDownload', (message) async {
      final args = PrismMediaHostApi.pigeonChannelCodec.decodeMessage(message)! as List<Object?>;
      deleteCalls.add(args.first! as String);
      return reply(OperationResult(success: true));
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('$_channelPrefix.listDownloads', null);
    messenger.setMockMessageHandler('$_channelPrefix.deleteDownload', null);
    AnalyticsRuntime.reset();
    getIt.reset();
    dir.deleteSync(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DownloadScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the PNG fixture releases its recorded picture', (tester) async {
    final List<ui.Picture> pictures = <ui.Picture>[];
    final previousOnCreate = ui.Picture.onCreate;
    ui.Picture.onCreate = (picture) {
      previousOnCreate?.call(picture);
      pictures.add(picture);
    };
    try {
      await tester.runAsync(() => _png(40, 80));
      expect(pictures, hasLength(1));
      expect(pictures.single.debugDisposed, isTrue);
    } finally {
      ui.Picture.onCreate = previousOnCreate;
      for (final ui.Picture picture in pictures) {
        if (!picture.debugDisposed) picture.dispose();
      }
    }
  });

  testWidgets('shows loading first, then the empty state with a browse action', (tester) async {
    final pending = Completer<DownloadItemsResult>();
    onList = () => pending.future;
    await pumpScreen(tester);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.text('No downloads yet'), findsNothing);

    pending.complete(DownloadItemsResult(success: true, items: const <String>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(find.text('Wallpapers you download are kept here.'), findsOneWidget);
    expect(find.text('Browse wallpapers'), findsOneWidget);
    expect(find.byType(Glint), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('a failed list shows an error that Retry recovers from', (tester) async {
    onList = () async => DownloadItemsResult(success: false, items: const <String>[], message: 'no access');
    await pumpScreen(tester);
    expect(find.text("Couldn't load your downloads"), findsOneWidget);
    expect(listCalls, 1);

    final File file = makeFile('a.png');
    onList = () async => DownloadItemsResult(success: true, items: <String>[file.path]);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(listCalls, 2);
    expect(find.text("Couldn't load your downloads"), findsNothing);
    expect(find.text('1 download · 3 B'), findsOneWidget);
  });

  testWidgets('downloaded files fill the shared wallpaper grid', (tester) async {
    final List<String> paths = <String>[makeFile('wall_0.png').path, makeFile('wall_1.png').path];
    onList = () async => DownloadItemsResult(success: true, items: paths);
    await pumpScreen(tester);

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('No downloads yet'), findsNothing);
  });

  testWidgets('a failed refresh keeps the files that are already shown', (tester) async {
    final File file = makeFile('a.png');
    onList = () async => DownloadItemsResult(success: true, items: <String>[file.path]);
    await pumpScreen(tester);
    expect(find.text('1 download · 3 B'), findsOneWidget);

    onList = () async => DownloadItemsResult(success: false, items: const <String>[], message: 'busy');
    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(listCalls, 2);
    expect(find.text('1 download · 3 B'), findsOneWidget);
    expect(find.byType(GlintState), findsNothing);
  });

  testWidgets('long press selects, Delete confirms and removes through the host API', (tester) async {
    final File a = makeFile('a.png');
    final File b = makeFile('b.png');
    final List<String> remaining = <String>[a.path, b.path];
    onList = () async => DownloadItemsResult(success: true, items: List<String>.of(remaining));
    await pumpScreen(tester);
    expect(find.text('2 downloads · 6 B'), findsOneWidget);

    await tester.longPress(find.byKey(ValueKey<String>(a.path)));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    remaining.remove(a.path);
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(deleteCalls, <String>[a.path]);
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('1 download · 3 B'), findsOneWidget);
  });

  List<String> shownOrder(WidgetTester tester, List<File> candidates) {
    final List<File> shown = candidates
        .where((file) => find.byKey(ValueKey<String>(file.path)).evaluate().isNotEmpty)
        .toList();
    shown.sort((a, b) {
      final Offset left = tester.getTopLeft(find.byKey(ValueKey<String>(a.path)));
      final Offset right = tester.getTopLeft(find.byKey(ValueKey<String>(b.path)));
      return left.dy != right.dy ? left.dy.compareTo(right.dy) : left.dx.compareTo(right.dx);
    });
    return shown.map((file) => file.path.split('/').last).toList();
  }

  group('sort and size', () {
    late File oldest;
    late File middle;
    late File newest;

    setUp(() {
      oldest = makeFile('b_oldest.png')..setLastModifiedSync(DateTime(2024));
      middle = makeFile('c_middle.png')..setLastModifiedSync(DateTime(2025));
      newest = makeFile('a_newest.png')..setLastModifiedSync(DateTime(2026));
      onList = () async => DownloadItemsResult(success: true, items: <String>[oldest.path, middle.path, newest.path]);
    });

    testWidgets('the toolbar shows the count and the total size', (tester) async {
      File('${dir.path}/big.png').writeAsBytesSync(List<int>.filled(1536 * 1024, 7));
      onList = () async => DownloadItemsResult(success: true, items: <String>[oldest.path, '${dir.path}/big.png']);
      await pumpScreen(tester);

      expect(find.text('2 downloads · 1.5 MB'), findsOneWidget);
    });

    testWidgets('newest first by default, then oldest, then name', (tester) async {
      await pumpScreen(tester);
      expect(shownOrder(tester, <File>[oldest, middle, newest]), <String>[
        'a_newest.png',
        'c_middle.png',
        'b_oldest.png',
      ]);

      Future<void> choose(String label) async {
        await tester.tap(find.byTooltip('Sort downloads'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await choose('Oldest');
      expect(shownOrder(tester, <File>[oldest, middle, newest]), <String>[
        'b_oldest.png',
        'c_middle.png',
        'a_newest.png',
      ]);

      await choose('Name');
      expect(shownOrder(tester, <File>[oldest, middle, newest]), <String>[
        'a_newest.png',
        'b_oldest.png',
        'c_middle.png',
      ]);
    });
  });

  group('Set as wallpaper', () {
    late File a;
    late File b;

    setUp(() {
      a = makeFile('a.png');
      b = makeFile('b.png');
      onList = () async => DownloadItemsResult(success: true, items: <String>[a.path, b.path]);
    });

    testWidgets('shows for exactly one selected file on Android', (tester) async {
      await pumpScreen(tester);
      await tester.longPress(find.byKey(ValueKey<String>(a.path)));
      await tester.pump();

      final SetWallpaperButton button = tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton));
      expect(button.url, a.path);

      await tester.tap(find.byKey(ValueKey<String>(b.path)));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byType(SetWallpaperButton), findsNothing);
    });

    testWidgets('selecting one download and tapping Set opens the Set screen', (tester) async {
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      final original = SetWallpaperFlow.screenOpener;
      SetWallpaperFlow.screenOpener = (context, request) async {
        opened.add(request);
        return null;
      };
      addTearDown(() => SetWallpaperFlow.screenOpener = original);

      await pumpScreen(tester);
      await tester.longPress(find.byKey(ValueKey<String>(a.path)));
      await tester.pump();
      await tester.tap(find.byType(SetWallpaperButton));
      await tester.pump();
      for (int i = 0; i < 80 && opened.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }

      expect(opened, hasLength(1));
      expect(opened.single.url, a.path);
      expect(opened.single.onAdjust, isNotNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('never shows on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpScreen(tester);
        await tester.longPress(find.byKey(ValueKey<String>(a.path)));
        await tester.pump();

        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byType(SetWallpaperButton), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('deleting a download forgets it in the downloaded index', (tester) async {
    final File a = makeFile('keep_me.png');
    final File b = makeFile('delete_me.png');
    await index.remember(link: 'https://example.com/keep_me.png', id: 'keep', source: WallpaperSource.prism);
    await index.remember(link: 'https://example.com/delete_me.png', id: 'gone', source: WallpaperSource.prism);
    final List<String> remaining = <String>[a.path, b.path];
    onList = () async => DownloadItemsResult(success: true, items: List<String>.of(remaining));
    await pumpScreen(tester);

    await tester.longPress(find.byKey(ValueKey<String>(b.path)));
    await tester.pump();
    remaining.remove(b.path);
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(deleteCalls, <String>[b.path]);
    expect(index.has('https://example.com/delete_me.png'), isFalse);
    expect(index.has('https://example.com/keep_me.png'), isTrue);
  });

  testWidgets('deleting one download words the dialog in the singular', (tester) async {
    final File a = makeFile('a.png');
    final File b = makeFile('b.png');
    onList = () async => DownloadItemsResult(success: true, items: <String>[a.path, b.path]);
    await pumpScreen(tester);

    await tester.longPress(find.byKey(ValueKey<String>(a.path)));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('It is removed from this device. You can download it again later.'), findsOneWidget);
  });

  testWidgets('deleting many downloads words the dialog in the plural', (tester) async {
    final File a = makeFile('a.png');
    final File b = makeFile('b.png');
    onList = () async => DownloadItemsResult(success: true, items: <String>[a.path, b.path]);
    await pumpScreen(tester);

    await tester.longPress(find.byKey(ValueKey<String>(a.path)));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey<String>(b.path)));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete 2 downloads?'), findsOneWidget);
    expect(find.text('They are removed from this device. You can download them again later.'), findsOneWidget);
  });

  testWidgets('the download count uses the secondary text colour, not the hint colour', (tester) async {
    onList = () async => DownloadItemsResult(success: true, items: <String>[makeFile('a.png').path]);
    final ThemeData theme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(onSurfaceVariant: Colors.orange),
      hintColor: Colors.purple,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: DownloadScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final Color? color = tester.widget<Text>(find.text('1 download · 3 B')).style?.color;
    expect(color, Colors.orange);
    expect(color, isNot(theme.hintColor));
  });

  group('opening a download', () {
    testWidgets('reads the shape of a decoded picture and nothing before it decodes', (tester) async {
      final Uint8List bytes = (await tester.runAsync(() => _png(40, 80)))!;
      final MemoryImage picture = MemoryImage(bytes);
      expect(decodedAspectRatio(picture), isNull);

      await tester.runAsync(() => precacheImage(picture, tester.binding.rootElement!));
      expect(decodedAspectRatio(picture), 0.5);
    });

    testWidgets('passes the tile shape to the detail, so its card opens at the final size', (tester) async {
      final Uint8List bytes = (await tester.runAsync(() => _png(160, 90)))!;
      final File file = File('${dir.path}/wide.png')..writeAsBytesSync(bytes);
      await index.remember(link: 'https://example.com/wide.png', id: 'wide', source: WallpaperSource.wallhaven);
      onList = () async => DownloadItemsResult(success: true, items: <String>[file.path]);
      final _MockStackRouter router = _MockStackRouter();
      registerFallbackValue(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: file));
      when(() => router.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StackRouterScope(controller: router, stateHash: 0, child: DownloadScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      final ImageProvider tile = tester.widget<Image>(find.byType(Image)).image;
      for (var i = 0; i < 50 && decodedAspectRatio(tile) == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }

      await tester.tap(find.byKey(ValueKey<String>(file.path)));
      await tester.pump();

      final WallpaperDetailRoute route =
          verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
      expect(route.args!.aspectRatio, closeTo(16 / 9, 0.01));
      expect(route.args!.localFile?.path, file.path);
    });
  });
}
