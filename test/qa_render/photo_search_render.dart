@Tags(<String>['qa_render'])
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/prism_feed/data/wall_search_terms.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/photo_match_ranking.dart';
import 'package:Prism/features/user_search/data/photo_search_service.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
// ignore: depend_on_referenced_packages
import 'package:file/file.dart' as fs;
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/creator_directory/creator_directory_test_support.dart';
import '../support/fake_app_analytics.dart';
import '../support/favourite_test_scope.dart';
import 'qa_harness.dart';

// Renders the real Search screen with the real photo pipeline: decode, 512 px clean copy, palette in an isolate, and
// rankPhotoMatches. The Vision callable answers with fixed stub labels, and the wall sources are fixtures.

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

class _MockCountsCubit extends MockCubit<Map<String, PrismWallpaperStats>> implements FavouriteCountsCubit {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

final AppLocalizationsEn _en = AppLocalizationsEn();

/// [id, colour ids, top gradient colour, bottom gradient colour, stored terms].
const List<(String, List<String>, int, int, String)> _walls = <(String, List<String>, int, int, String)>[
  ('qa-sunset-dunes', <String>['orange', 'pink', 'purple'], 0xFFFF7A1A, 0xFFC2185B, 'Dusk dunes sky sunset afterglow'),
  ('qa-sunset-sea', <String>['red', 'orange'], 0xFFD81B1B, 0xFFFF8A00, 'Red sea evening sunset'),
  ('qa-orange-fold', <String>['orange'], 0xFFFF6A00, 0xFFFFB000, 'Orange fold abstract pattern'),
  ('qa-fern-room', <String>['green', 'brown'], 0xFF3F6F2A, 0xFF7A4A1F, 'Fern room interior design houseplant'),
  ('qa-moss-forest', <String>['green'], 0xFF1F4D1A, 0xFF6A9A2A, 'Moss forest tree green'),
  ('qa-neon-alley', <String>['black', 'pink', 'purple'], 0xFF0A0A12, 0xFFE0287A, 'Neon alley night street'),
  ('qa-cyan-night', <String>['black', 'teal'], 0xFF05060A, 0xFF3FD0D0, 'Cyan night city light'),
  ('qa-blue-calm', <String>['blue'], 0xFF0A3D91, 0xFF4A8FE0, 'Blue calm water'),
  ('qa-grey-stone', <String>['grey', 'white'], 0xFF7A7A7A, 0xFFE6E6E6, 'Grey stone rock texture'),
];

/// What the Vision stub answers for each photo, by the photo's scene name.
const Map<String, List<String>> _stubLabels = <String, List<String>>{
  'sunset': <String>['Sky', 'Sunset', 'Afterglow', 'Cloud', 'Evening'],
  'green_room': <String>['Room', 'Interior design', 'Houseplant', 'Green', 'Wall'],
  'neon_street': <String>['Neon', 'Night', 'Street', 'Light', 'City'],
};

Future<Uint8List> _png(int width, int height, void Function(ui.Canvas canvas, Size size) paint) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// The three test photos, drawn at 1200 x 1600 like a phone photo.
Future<Uint8List> _photo(String scene) => _png(1200, 1600, (canvas, size) {
  final Rect all = Offset.zero & size;
  switch (scene) {
    case 'sunset':
      canvas.drawRect(
        all,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height),
            const <Color>[Color(0xFFFFB347), Color(0xFFFF5E3A), Color(0xFF7B2D8B)],
            const <double>[0, 0.55, 1],
          ),
      );
      canvas.drawCircle(const Offset(600, 1050), 130, Paint()..color = const Color(0xFFFFE08A));
      canvas.drawPath(
        Path()
          ..moveTo(0, 1300)
          ..lineTo(300, 1180)
          ..lineTo(650, 1280)
          ..lineTo(900, 1150)
          ..lineTo(1200, 1240)
          ..lineTo(1200, 1600)
          ..lineTo(0, 1600)
          ..close(),
        Paint()..color = const Color(0xFF2A1430),
      );
    case 'green_room':
      canvas.drawRect(all, Paint()..color = const Color(0xFF4F7A3A));
      canvas.drawRect(const Rect.fromLTWH(0, 1150, 1200, 450), Paint()..color = const Color(0xFF7A4E26));
      canvas.drawRect(const Rect.fromLTWH(380, 250, 440, 550), Paint()..color = const Color(0xFFD8E6C8));
      canvas.drawCircle(const Offset(220, 960), 180, Paint()..color = const Color(0xFF2F5A24));
      canvas.drawRect(const Rect.fromLTWH(180, 1000, 80, 150), Paint()..color = const Color(0xFF5A3418));
    case 'neon_street':
      canvas.drawRect(all, Paint()..color = const Color(0xFF07070D));
      final Paint glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRect(const Rect.fromLTWH(120, 300, 400, 120), glow..color = const Color(0xFFFF2FA0));
      canvas.drawRect(const Rect.fromLTWH(650, 520, 430, 100), glow..color = const Color(0xFF29E6FF));
      canvas.drawRect(const Rect.fromLTWH(200, 820, 700, 80), glow..color = const Color(0xFFB04CFF));
      canvas.drawRect(const Rect.fromLTWH(760, 1050, 240, 350), glow..color = const Color(0xFFFF2FA0));
      canvas.drawPath(
        Path()
          ..moveTo(0, 1600)
          ..lineTo(450, 1150)
          ..lineTo(750, 1150)
          ..lineTo(1200, 1600)
          ..close(),
        Paint()..color = const Color(0xFF14141F),
      );
  }
});

/// Answers each `https://qa.test/` url with a gradient: a fixture wall's own colours, or a colour fixture's palette colour.
class _WallImages extends Fake implements BaseCacheManager {
  _WallImages(this._files);

  final Map<String, fs.File> _files;

  static Future<_WallImages> build() async {
    final MemoryFileSystem memory = MemoryFileSystem();
    final Map<String, fs.File> files = <String, fs.File>{};
    Future<void> add(String url, Color top, Color bottom) async {
      final fs.File file = memory.file('/${files.length}.png')
        ..writeAsBytesSync(
          await _png(270, 480, (canvas, size) {
            canvas.drawRect(
              Offset.zero & size,
              Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), <Color>[top, bottom]),
            );
          }),
        );
      files[url] = file;
    }

    for (final (String id, _, int top, int bottom, _) in _walls) {
      await add('https://qa.test/$id', Color(top), Color(bottom));
    }
    for (final PrismPaletteColor colour in prismPalette) {
      for (int i = 1; i <= 6; i++) {
        final HSLColor hsl = HSLColor.fromColor(colour.color);
        await add(
          'https://qa.test/wh-${colour.hex}-$i',
          hsl.withLightness((hsl.lightness + 0.05 * i).clamp(0, 0.9)).toColor(),
          hsl.withLightness((hsl.lightness - 0.04 * i).clamp(0.05, 1)).toColor(),
        );
      }
    }
    return _WallImages(files);
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream<FileResponse>.value(
    FileInfo(_files[url] ?? _files.values.first, FileSource.Cache, DateTime.now().add(const Duration(days: 1)), url),
  );
}

PrismWallpaper _wall(String id, List<String> colours) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://qa.test/$id',
    thumbnailUrl: 'https://qa.test/$id',
    authorName: 'QA creator',
    resolution: '1080x1920',
  ),
  colors: colours,
);

/// The fixture search: Prism walls through the real ranking, then six colour fixtures for the top colour.
({WallpaperSearchPage page, String query}) _searchByPhoto(PhotoQuery photo) {
  final List<PrismWallpaper> ranked = rankPhotoMatches(photo, <PhotoCandidate>[
    for (final (String id, List<String> colours, _, _, String text) in _walls)
      (wall: _wall(id, colours), terms: searchTermsOf(text)),
  ], limit: 6);
  final String hex = photo.topColor.hex;
  return (
    page: (
      provider: SearchProviderValue.wallhaven,
      prismResults: <FeedItemEntity>[for (final wall in ranked) PrismFeedItem(id: wall.id, wallpaper: wall)],
      results: <FeedItemEntity>[
        for (int i = 1; i <= 6; i++)
          WallhavenFeedItem(
            id: 'wh-$hex-$i',
            wallpaper: WallhavenWallpaper(
              core: WallpaperCore(
                id: 'wh-$hex-$i',
                source: WallpaperSource.wallhaven,
                fullUrl: 'https://qa.test/wh-$hex-$i',
                thumbnailUrl: 'https://qa.test/wh-$hex-$i',
                resolution: '1080x1920',
              ),
            ),
          ),
      ],
      isLocal: false,
    ),
    query: photo.topLabel,
  );
}

enum _Labels { found, capped, guest }

Future<void> _install(
  WidgetTester tester, {
  required String scene,
  required _Labels labels,
  bool privacySeen = true,
}) async {
  final _MockFunctions functions = _MockFunctions();
  final _MockCallable callable = _MockCallable();
  when(() => functions.httpsCallable('photoSearchLabels', options: any(named: 'options'))).thenReturn(callable);
  if (labels == _Labels.capped) {
    when(
      () => callable.call<Object?>(any()),
    ).thenThrow(FirebaseFunctionsException(code: 'resource-exhausted', message: 'Daily photo search limit reached.'));
  } else {
    final _MockResult result = _MockResult();
    when(() => result.data).thenReturn(<String, Object?>{'labels': _stubLabels[scene], 'category': null});
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }
  final Uint8List original = (await tester.runAsync(() => _photo(scene)))!;
  final _MockWallpaperSearchService search = _MockWallpaperSearchService();
  when(
    () => search.searchByPhoto(any(), filters: any(named: 'filters')),
  ).thenAnswer((invocation) async => _searchByPhoto(invocation.positionalArguments.first as PhotoQuery));
  final _MockSearchDiscoveryBloc discovery = _MockSearchDiscoveryBloc();
  when(() => discovery.state).thenReturn(SearchDiscoveryState.initial());
  whenListen(discovery, const Stream<SearchDiscoveryState>.empty(), initialState: SearchDiscoveryState.initial());
  final _MockCountsCubit counts = _MockCountsCubit();
  whenListen(
    counts,
    const Stream<Map<String, PrismWallpaperStats>>.empty(),
    initialState: const <String, PrismWallpaperStats>{},
  );
  getIt
    ..registerSingleton<PhotoSearchService>(PhotoSearchService(() async => original, (png) async => png, functions))
    ..registerSingleton<WallpaperSearchService>(search)
    ..registerFactory<SearchDiscoveryBloc>(() => discovery)
    ..registerSingleton<FavouriteCountsCubit>(counts);
  registerCreatorDirectoryFakes();
  AnalyticsRuntime.instance = FakeAppAnalytics();
  await getIt<SettingsLocalDataSource>().set(PersistenceKeys.photoSearchPrivacySeen, privacySeen);
  if (labels == _Labels.guest) app_state.prismUser = app_constants.createGuestPrismUser();
}

Future<void> _runPhoto(QaShot shot, String name, {double textScale = 1}) async {
  PrismImageCache.testOverride = (await shot.tester.runAsync(_WallImages.build))!;
  await shot.pump(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: favouriteTestBuilder(context, const SearchScreen()),
      ),
    ),
  );
  await shot.tester.tap(find.byTooltip(_en.searchByPhoto));
  for (int i = 0; i < 4; i++) {
    await shot.tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await shot.settle(frames: 2);
  }
  await shot.settle(frames: 8);
  await shot.save(name);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const SearchFilters());
    registerFallbackValue(WallpaperDetailRoute());
    registerFallbackValue(
      PhotoQuery(
        preview: Uint8List(0),
        palette: <PaletteShare>[(color: prismPalette.first, share: 1.0)],
        labelsStatus: PhotoLabelsStatus.guest,
      ),
    );
  });
  setUpAll(loadFonts);
  tearDown(AnalyticsRuntime.reset);

  qaScreen('search bar with the photo button', (shot) async {
    await _install(shot.tester, scene: 'sunset', labels: _Labels.found);
    await shot.pump(Builder(builder: (context) => favouriteTestBuilder(context, const SearchScreen())));
    await shot.save('photo_search_bar');
  });

  qaScreen('privacy sheet before the first photo search', (shot) async {
    await _install(shot.tester, scene: 'sunset', labels: _Labels.found, privacySeen: false);
    await shot.pump(Builder(builder: (context) => favouriteTestBuilder(context, const SearchScreen())));
    await shot.tester.tap(find.byTooltip(_en.searchByPhoto));
    await shot.settle(frames: 12);
    expect(find.text(_en.searchPhotoPrivacy), findsOneWidget);
    await shot.save('photo_search_privacy_sheet');
  });

  for (final String scene in <String>['sunset', 'green_room', 'neon_street']) {
    qaScreen('signed-in photo search: $scene', (shot) async {
      await _install(shot.tester, scene: scene, labels: _Labels.found);
      await _runPhoto(shot, 'photo_search_$scene');
    });
  }

  qaScreen('guest photo search: colours only', (shot) async {
    await _install(shot.tester, scene: 'sunset', labels: _Labels.guest);
    await _runPhoto(shot, 'photo_search_guest');
  });

  qaScreen('capped photo search', (shot) async {
    await _install(shot.tester, scene: 'green_room', labels: _Labels.capped);
    await _runPhoto(shot, 'photo_search_capped');
  });

  qaScreen('large text photo search', (shot) async {
    await _install(shot.tester, scene: 'neon_street', labels: _Labels.found);
    await _runPhoto(shot, 'photo_search_large_text', textScale: 2);
  });
}
