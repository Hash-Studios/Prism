import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_tile_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import 'support/fav_fixtures.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late FavouriteWallsBloc bloc;

  /// Built inside the test body so the bloc runs on the fake-async clock the tester pumps.
  FavouriteWallsBloc createBloc() {
    bloc = FavouriteWallsBloc(fetchUseCase, _MockToggleFavouriteWallUseCase(), _MockClearFavouriteWallsUseCase());
    addTearDown(bloc.close);
    return bloc;
  }

  setUpAll(() {
    CachedNetworkImageProvider.defaultCacheManager = _MockCacheManager();
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
  });

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpGrid(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(body: FavouriteGrid()),
        ),
      ),
    );
  }

  testWidgets('shows loading cards until the favourites arrive, then the empty state', (tester) async {
    final Completer<Result<List<FavouriteWallEntity>>> pending = Completer<Result<List<FavouriteWallEntity>>>();
    when(() => fetchUseCase(any())).thenAnswer((_) => pending.future);
    createBloc();

    await pumpGrid(tester);
    await tester.pump();

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.byType(GlintState), findsNothing);

    pending.complete(Result.success(const <FavouriteWallEntity>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('No favourites yet'), findsOneWidget);
    verify(() => fetchUseCase(any())).called(1);
  });

  testWidgets('shows the grid straight away when the favourites are already loaded', (tester) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    createBloc();
    bloc.add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await tester.pump();
    await tester.pump();
    expect(bloc.state.status, LoadStatus.success);

    await pumpGrid(tester);

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  group('with favourites', () {
    late _MockClearFavouriteWallsUseCase clearUseCase;
    late _MockToggleFavouriteWallUseCase toggleUseCase;

    FavouriteWallsBloc createBlocWith(List<FavouriteWallEntity> items) {
      clearUseCase = _MockClearFavouriteWallsUseCase();
      toggleUseCase = _MockToggleFavouriteWallUseCase();
      registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
      registerFallbackValue(ToggleFavouriteWallParams(userId: 'user_1', wall: items.first, currentlyFavourited: false));
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(items)));
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
      bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);
      return bloc;
    }

    Future<void> pumpLoaded(WidgetTester tester) async {
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('filter chips and search narrow the grid and clear filters restores it', (tester) async {
      createBlocWith(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace', createdAt: DateTime.utc(2025, 1, 2)),
      ]);
      await pumpLoaded(tester);
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Prism'));
      await tester.pump();
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No matching favourites'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsOneWidget);
    });

    testWidgets('long press selects, Remove sends one batched delete and Undo restores', (tester) async {
      createBlocWith(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace', createdAt: DateTime.utc(2025, 1, 2)),
        wallhavenFav('c', createdAt: DateTime.utc(2025)),
      ]);
      await pumpLoaded(tester);

      await tester.longPress(find.bySemanticsLabel('Wallpaper by Ada'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Wallpaper by Grace'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Remove from favourites'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a', 'b']);
      expect(bloc.state.items.map((wall) => wall.id), <String>['c']);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Removed 2 favourites'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.items.map((wall) => wall.id), <String>['a', 'b', 'c']);
    });

    testWidgets('legacy favourites explain themselves on tap and can be removed after a long press', (tester) async {
      createBlocWith(<FavouriteWallEntity>[legacyFav('old', author: 'Old Timer')]);
      await pumpLoaded(tester);

      await tester.tap(find.bySemanticsLabel('Wallpaper by Old Timer'));
      await tester.pump();
      expect(find.textContaining('older version'), findsOneWidget);

      await tester.longPress(find.bySemanticsLabel('Wallpaper by Old Timer'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove from favourites'), findsOneWidget);
    });

    testWidgets('a failed load with nothing cached shows an error with Retry', (tester) async {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      createBloc();
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't load favourites"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(LoadingCards), findsNothing);
    });
  });

  group('toolbar tools', () {
    late _MockClearFavouriteWallsUseCase clearUseCase;
    late _MockToggleFavouriteWallUseCase toggleUseCase;
    late List<String> toasts;
    late List<MethodCall> shareCalls;
    late Directory tempDir;
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    const MethodChannel shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() {
      final cache = _MockCacheManager();
      CachedNetworkImageProvider.defaultCacheManager = cache;
      PrismImageCache.testOverride = cache;
      addTearDown(() => PrismImageCache.testOverride = null);
      when(
        () => cache.getFileStream(any(), withProgress: true),
      ).thenAnswer((_) => StreamController<FileResponse>().stream);
      toasts = <String>[];
      shareCalls = <MethodCall>[];
      tempDir = Directory.systemTemp.createTempSync('fav_export_test');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(toastChannel, (call) async {
        if (call.method == 'showToast') toasts.add((call.arguments as Map)['msg'] as String);
        return true;
      });
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        shareCalls.add(call);
        return 'shared';
      });
      messenger.setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    });

    tearDown(() {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(toastChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
      tempDir.deleteSync(recursive: true);
    });

    FavouriteWallsBloc createToolsBloc(List<FavouriteWallEntity> items) {
      clearUseCase = _MockClearFavouriteWallsUseCase();
      toggleUseCase = _MockToggleFavouriteWallUseCase();
      registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
      registerFallbackValue(ToggleFavouriteWallParams(userId: 'user_1', wall: items.first, currentlyFavourited: false));
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(items)));
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
      bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);
      return bloc;
    }

    Future<void> pumpLoaded(WidgetTester tester) async {
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> openMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('More favourites actions'));
      await settle(tester);
      await tester.tap(find.text(item));
      await settle(tester);
    }

    testWidgets('the toolbar shows how many favourites there are', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a'), pexelsFav('b')]);
      await pumpLoaded(tester);

      expect(find.text('2 favourites'), findsOneWidget);
    });

    testWidgets('Clear all asks with the count, clears, and Undo restores the list', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[
        prismFav('a', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', createdAt: DateTime.utc(2025, 1, 2)),
      ]);
      await pumpLoaded(tester);

      await openMenu(tester, 'Clear all favourites');
      expect(find.text('Clear 2 favourites?'), findsOneWidget);
      expect(find.text('This removes them from your account.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      verifyNever(() => clearUseCase(any()));

      await openMenu(tester, 'Clear all favourites');
      await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
      await settle(tester);
      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a', 'b']);
      expect(bloc.state.items, isEmpty);
      expect(find.text('Cleared 2 favourites'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.items.map((wall) => wall.id), <String>['a', 'b']);
    });

    testWidgets('a clear that fails shows an error and keeps the list', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a')]);
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('nope')));
      await pumpLoaded(tester);

      await openMenu(tester, 'Clear all favourites');
      await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
      await settle(tester);

      expect(toasts, contains("Couldn't clear favourites. Try again."));
      expect(find.text('Cleared 1 favourite'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a failed refresh with items on screen tells the user and keeps the list', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a')]);
      await pumpLoaded(tester);
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

      bloc.add(const FavouriteWallsEvent.refreshRequested());
      await tester.pump();
      await tester.pump();

      expect(bloc.state.status, LoadStatus.failure);
      expect(toasts, <String>["Couldn't refresh favourites. Showing your saved list."]);
      expect(find.bySemanticsLabel('Wallpaper by'), findsNothing);
      expect(find.text('1 favourite'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Export writes the JSON file and shares it', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace'),
      ]);
      await pumpLoaded(tester);

      await openMenu(tester, 'Export favourites');
      for (int i = 0; i < 120 && shareCalls.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }

      final List<File> written = tempDir.listSync().whereType<File>().toList();
      expect(written, hasLength(1));
      expect(written.single.path, endsWith('.json'));
      final Map<String, Object?> decoded = jsonDecode(written.single.readAsStringSync()) as Map<String, Object?>;
      expect(decoded['count'], 2);
      expect((decoded['favourites']! as List<Object?>).length, 2);
      expect(toasts, isEmpty);
      expect(shareCalls, isNotEmpty);
    });

    testWidgets('Export with no favourites says so and shares nothing', (tester) async {
      createToolsBloc(<FavouriteWallEntity>[prismFav('a')]);
      await pumpLoaded(tester);
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      bloc.add(const FavouriteWallsEvent.synced(userId: 'user_1', items: <FavouriteWallEntity>[]));
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('More favourites actions'), findsNothing);
      expect(shareCalls, isEmpty);
    });
  });

  group('guest', () {
    setUp(() {
      app_state.prismUser = app_constants.createGuestPrismUser();
    });

    testWidgets('the first frame asks a guest to sign in', (tester) async {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
      createBloc();
      await pumpGrid(tester);

      expect(find.byType(SignInPrompt), findsOneWidget);
      expect(find.text('Sign in to use favourites'), findsOneWidget);
      await tester.pump();
      await tester.pump();
    });

    testWidgets('a guest with saved favourites sees the list and a banner that can be dismissed', (tester) async {
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[prismFav('a', author: 'Ada')]));
      createBloc();
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.text('Sign in to keep them on every device'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.text('Sign in to keep them on every device'), findsNothing);
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
    });
  });

  group('unavailable tile', () {
    testWidgets('an image that fails for good shows Unavailable and a one-tap remove', (tester) async {
      final cache = _MockCacheManager();
      CachedNetworkImageProvider.defaultCacheManager = cache;
      PrismImageCache.testOverride = cache;
      addTearDown(() => PrismImageCache.testOverride = null);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      when(
        () => cache.getFileStream(any(), withProgress: true),
      ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('Offline')));
      final clearUseCase = _MockClearFavouriteWallsUseCase();
      final toggleUseCase = _MockToggleFavouriteWallUseCase();
      registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[prismFav('a', author: 'Ada')]));
      bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);

      await pumpGrid(tester);
      for (int i = 0; i < 60 && find.text('Unavailable').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Unavailable'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a']);
      expect(find.byType(FavouriteTileImage), findsNothing);
    });
  });
}
