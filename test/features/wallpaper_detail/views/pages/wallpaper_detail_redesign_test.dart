import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_panel.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/in_memory_local_store.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

final FeedItemEntity _entity = FeedItemEntity.prism(
  id: 'z3zf',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'z3zf',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/full.jpg',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      resolution: '1403x3040',
      sizeBytes: 2500000,
      authorName: 'Hk3ToN',
      category: 'gradients',
      createdAt: DateTime(2020, 12, 9),
    ),
    firestoreDocumentId: 'doc-1',
  ),
);

final WallpaperDetailLoaded _loaded = WallpaperDetailLoaded(
  entity: _entity,
  views: '1707',
  paletteLoading: false,
  colors: const <Color>[Color(0xFFE91E63), Color(0xFF009688)],
  accent: const Color(0xFFE91E63),
);

void main() {
  late _MockDetailBloc bloc;

  setUpAll(() {
    registerFallbackValue(const OnPanelOpened());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });

  setUp(() {
    bloc = _MockDetailBloc();
    app_state.prismUser = app_constants.createGuestPrismUser();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() => getIt.reset());

  Future<void> pumpDetail(WidgetTester tester, WallpaperDetailState state, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(wallId: 'z3zf', source: WallpaperSource.prism),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('collapsed panel is one row: name, author, main action and favourite', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpDetail(tester, _loaded);

    expect(find.text('Z3ZF'), findsOneWidget);
    expect(find.text('by Hk3ToN'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Set wallpaper'), findsOneWidget);
    expect(find.bySemanticsLabel('Favourite'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Clock preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('tapping the name opens the panel with the palette, facts and actions', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpDetail(tester, _loaded);

    await tester.tap(find.text('Z3ZF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    for (final String fact in <String>['Resolution', '1403x3040', 'Category', 'gradients', 'Views', '1707', 'Source']) {
      expect(find.text(fact), findsOneWidget, reason: fact);
    }
    expect(find.text('Author'), findsOneWidget);
    for (final String label in <String>['Download', 'Share', 'Edit', 'Report']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.bySemanticsLabel('Original wallpaper colors'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on iOS the main action is Download and there is no Set', (tester) async {
    await pumpDetail(tester, _loaded);

    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
    expect(find.text('Set wallpaper'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the docked panel reads on a dark theme too', (tester) async {
    await pumpDetail(tester, _loaded, theme: kDarkTheme8);

    final DecoratedBox box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(DetailPanel), matching: find.byType(DecoratedBox)).first,
    );
    final ShapeDecoration decoration = box.decoration as ShapeDecoration;
    expect(decoration.color, kDarkTheme8.colorScheme.surfaceContainerLow.withValues(alpha: 0.94));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading keeps the thumbnail and shows a skeleton panel with a back button', (tester) async {
    await pumpDetail(tester, const WallpaperDetailLoading(thumbnailUrl: 'https://example.com/thumb.jpg'));

    expect(find.byType(DetailPanelSkeleton), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error offers Try again and a back button', (tester) async {
    await pumpDetail(tester, const WallpaperDetailError(message: ''));

    expect(find.text("Couldn't load this wallpaper"), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    verify(() => bloc.add(any(that: isA<LoadFromId>()))).called(2);
  });
}
