import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/in_memory_local_store.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

FeedItemEntity _prism({List<String> collections = const <String>[], int? width, int? height}) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: 'Akshay',
      width: width,
      height: height,
    ),
    collections: collections,
    tags: const <String>['space', 'stars'],
  ),
);

Future<List<double>> _hues(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData data = (await image.toByteData())!;
  return <double>[
    for (int x = 0; x < image.width; x++)
      HSVColor.fromColor(
        Color.fromARGB(255, data.getUint8(x * 4), data.getUint8(x * 4 + 1), data.getUint8(x * 4 + 2)),
      ).hue,
  ];
}

Future<Uint8List> _redAndBluePng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(const Rect.fromLTWH(1, 0, 1, 1), Paint()..color = const Color(0xFF0000FF));
  final ui.Image image = await recorder.endRecording().toImage(2, 1);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  setUpAll(() => registerFallbackValue(const SelectAccentColor(color: Colors.black)));

  late DownloadedWallIndex downloaded;

  setUp(() {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    downloaded = DownloadedWallIndex(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    getIt.registerSingleton<DownloadedWallIndex>(downloaded);
  });

  tearDown(() => getIt.reset());

  Future<_MockWallpaperDetailBloc> pumpDetail(WidgetTester tester, WallpaperDetailLoaded state) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: state.entity),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  testWidgets('Android shows a labelled Set action in the collapsed row and the other actions in the panel', (
    tester,
  ) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.text('Set wallpaper'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsOneWidget);
    expect(find.byType(DownloadButton), findsOneWidget);
    expect(find.byType(FavouriteWallpaperButton), findsOneWidget);
    expect(find.byType(ShareButton), findsOneWidget);
    expect(find.byType(EditButton), findsOneWidget);
    expect(
      tester.getRect(find.byType(SetWallpaperButton)).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('collapsed panel content is faded out and returns when the panel opens', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(), paletteLoading: false, colors: const <Color>[Colors.teal]),
    );

    expect(find.bySemanticsLabel('Original wallpaper colors'), findsNothing);
    AnimatedOpacity chipFade() => tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.widgetWithText(ActionChip, 'space'), matching: find.byType(AnimatedOpacity)).first,
    );
    expect(chipFade().opacity, 0);
    expect(tester.getSemantics(find.bySemanticsLabel('Expand wallpaper details')).rect.height, lessThan(100));

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pumpAndSettle();

    expect(chipFade().opacity, 1);
    expect(find.bySemanticsLabel('Original wallpaper colors'), findsOneWidget);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('collapsed palette ignores taps and an expanded palette selects its colour', (tester) async {
    final _MockWallpaperDetailBloc bloc = await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(), paletteLoading: false, colors: const <Color>[Colors.teal]),
    );
    final Finder tealSwatch = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Accent color #009688',
    );

    expect(tealSwatch, findsOneWidget);
    await tester.tapAt(tester.getCenter(tealSwatch));
    await tester.pump();
    verifyNever(() => bloc.add(any(that: isA<SelectAccentColor>())));

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pumpAndSettle();
    await tester.tap(tealSwatch);

    verify(() => bloc.add(const SelectAccentColor(color: Colors.teal))).called(1);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('iOS shows Save as the primary action and no Set action', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsNothing);
    expect(find.byType(DownloadButton), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a wall in a premium collection is a premium download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(collections: <String>['space']), paletteLoading: false),
    );
    final DownloadButton premium = tester.widget<DownloadButton>(find.byType(DownloadButton));

    expect(premium.isPremiumContent, isTrue);
    expect(premium.contentId, 'prism-1');
  });

  testWidgets('a wall in a free collection is a normal download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(collections: <String>['Nature']), paletteLoading: false),
    );

    expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).isPremiumContent, isFalse);
  });

  testWidgets('a colour picked on the colour bar tints the wallpaper with its hue', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Colors.teal],
        accent: Colors.teal,
        colorChanged: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final Finder tinted = find.ancestor(
      of: find.byWidgetPredicate((widget) => widget is CachedNetworkImage && widget.imageUrl.endsWith('thumb.jpg')),
      matching: find.byType(ColorFiltered),
    );
    expect(tinted, findsOneWidget);
    expect(tester.widget<ColorFiltered>(tinted).colorFilter, const ColorFilter.mode(Colors.teal, BlendMode.hue));
  });

  testWidgets('the original wallpaper has no colour filter, even with an accent on the chrome', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Colors.teal],
        accent: Colors.teal,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ColorFiltered), findsNothing);
  });

  group('colour variation as the source of Set, Download and Edit', () {
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('detail_tint');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => directory.path,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, null);
      directory.deleteSync(recursive: true);
    });

    List<Future<String> Function()?> preparers(WidgetTester tester) => <Future<String> Function()?>[
      tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).prepareSource,
      tester.widget<DownloadButton>(find.byType(DownloadButton)).variant?.prepare,
      tester.widget<EditButton>(find.byType(EditButton)).prepareSource,
    ];

    testWidgets('with a colour picked, each action renders this wallpaper in that hue', (tester) async {
      final File source = File('${directory.path}/wall.png');
      await tester.runAsync(() async => source.writeAsBytes(await _redAndBluePng()));
      final FeedItemEntity entity = FeedItemEntity.prism(
        id: 'prism-1',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'prism-1',
            source: WallpaperSource.prism,
            fullUrl: source.path,
            thumbnailUrl: 'https://img.test/thumb.jpg',
          ),
        ),
      );
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          entity: entity,
          paletteLoading: false,
          colors: const <Color>[Color(0xFF00FF00)],
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );

      for (final Future<String> Function()? prepare in preparers(tester)) {
        final List<double> hues = (await tester.runAsync(() async {
          final String path = await prepare!();
          return _hues(await File(path).readAsBytes());
        }))!;

        expect(hues, hasLength(2));
        expect(hues, everyElement(closeTo(120, 10)));
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a tinted download is its own variation, named and remembered by its colour', (tester) async {
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          entity: _prism(),
          paletteLoading: false,
          colors: const <Color>[Color(0xFF00FF00)],
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );
      const String url = 'https://img.test/full.jpg';
      final DownloadButton button = tester.widget<DownloadButton>(find.byType(DownloadButton));

      expect(button.variant!.key, 'tint-00ff00');
      expect(button.variant!.identityOf(url), 'full_tint-00ff00.png');

      button.onDownloaded!();
      await tester.pump();

      expect(downloaded.has('full_tint-00ff00.png'), isTrue);
      expect(downloaded.has(url), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('with the original showing, a download is remembered under the wallpaper link', (tester) async {
      await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
      const String url = 'https://img.test/full.jpg';
      final DownloadButton button = tester.widget<DownloadButton>(find.byType(DownloadButton));

      expect(button.variant, isNull);
      button.onDownloaded!();
      await tester.pump();

      expect(downloaded.has(url), isTrue);
      expect(downloaded.has('full_tint-00ff00.png'), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('with the original showing, each action uses the wallpaper as it is', (tester) async {
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          entity: _prism(),
          paletteLoading: false,
          colors: const <Color>[Colors.teal],
          accent: Colors.teal,
        ),
      );

      expect(preparers(tester), everyElement(isNull));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  testWidgets('a wall smaller than the screen shows the low resolution note', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(width: 100, height: 100), paletteLoading: false));

    expect(find.text('Low resolution for your screen'), findsOneWidget);
  });

  testWidgets('a large wall shows no low resolution note', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(width: 9000, height: 9000), paletteLoading: false));

    expect(find.text('Low resolution for your screen'), findsNothing);
  });

  testWidgets('the tags show as chips', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.widgetWithText(ActionChip, 'space'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'stars'), findsOneWidget);
  });

  testWidgets('the similar strip stays hidden when it cannot load', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('More like this'), findsNothing);
  });
}
