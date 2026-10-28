import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/views/pages/wallpaper_history_screen.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  late WallpaperHistoryStore store;

  setUp(() {
    store = WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<WallpaperHistoryStore>(store);
    getIt.registerFactory<WallpaperHistoryBloc>(() => WallpaperHistoryBloc(store));
  });

  tearDown(() => getIt.reset());

  Future<void> record(String id, String target, DateTime at) => store.record(
    AppliedWallpaper(
      id: id,
      source: 'prism',
      thumbnailUrl: '/nonexistent/$id.png',
      fullUrl: '/nonexistent/$id.png',
      target: target,
      appliedAt: at,
    ),
  );

  testWidgets('empty history shows the empty state without a clear action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperHistoryScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.text('Clear history'), findsNothing);
  });

  testWidgets('lists applied wallpapers newest first with target labels', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await record('b', 'lock', DateTime(2026, 1, 2, 9));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperHistoryScreen(),
      ),
    );
    await tester.pump();

    final List<AppliedWallpaperTile> tiles = tester
        .widgetList<AppliedWallpaperTile>(find.byType(AppliedWallpaperTile))
        .toList();
    expect(tiles.map((t) => t.item.id), ['b', 'a']);
    expect(find.text('Lock screen'), findsOneWidget);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('Clear history asks first and empties the list on confirm', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperHistoryScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.items(), hasLength(1));

    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.items(), isEmpty);
    expect(find.text('No wallpapers yet'), findsOneWidget);
  });

  testWidgets('the newest home row and the newest lock row show a Current badge', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await record('b', 'lock', DateTime(2026, 1, 2, 9));
    await record('c', 'home', DateTime(2026, 1, 3, 9));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperHistoryScreen(),
      ),
    );
    await tester.pump();

    final Iterable<String> current = tester
        .widgetList<AppliedWallpaperTile>(find.byType(AppliedWallpaperTile))
        .where((tile) => tile.isCurrent)
        .map((tile) => tile.item.id);
    expect(current.toSet(), {'c', 'b'});
    expect(find.text('Current'), findsNWidgets(2));
  });

  testWidgets('the Current badge is an accent pill with a label that reads on the accent', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    final ThemeData theme = ThemeData(colorScheme: const ColorScheme.light(primary: Color(0xFFE57697)));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: const WallpaperHistoryScreen(),
      ),
    );
    await tester.pump();

    final DecoratedBox badge = tester.widget<DecoratedBox>(
      find.ancestor(of: find.text('Current'), matching: find.byType(DecoratedBox)).first,
    );
    final ShapeDecoration decoration = badge.decoration as ShapeDecoration;

    expect(decoration.shape, isA<StadiumBorder>());
    expect(decoration.color, const Color(0xFFE57697));
    expect(tester.widget<Text>(find.text('Current')).style!.color, Colors.black);
  });

  testWidgets('a both row is current for both screens with one badge', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await record('b', 'both', DateTime(2026, 1, 2, 9));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperHistoryScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Current'), findsOneWidget);
  });

  testWidgets('a long press removes the row and Undo brings it back', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await record('b', 'lock', DateTime(2026, 1, 2, 9));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WallpaperHistoryScreen()),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('b')).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.items().map((item) => item.id), ['a']);
    expect(find.text('Removed from history'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.items().map((item) => item.id), ['b', 'a']);
  });

  testWidgets('a swipe removes the row', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WallpaperHistoryScreen()),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(AppliedWallpaperTile), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(store.items(), isEmpty);
    expect(find.text('No wallpapers yet'), findsOneWidget);
  });

  testWidgets('Set again opens the Set screen as wallpaper_history even with a saved default', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    final List<SetScreenRequest> opened = <SetScreenRequest>[];
    final original = SetWallpaperFlow.screenOpener;
    SetWallpaperFlow.screenOpener = (context, request) async {
      opened.add(request);
      return null;
    };
    addTearDown(() => SetWallpaperFlow.screenOpener = original);
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallpaperHistoryScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AppliedWallpaperTile));
    await tester.pump();
    for (int i = 0; i < 80 && opened.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }

    expect(opened, hasLength(1));
    expect(opened.single.url, '/nonexistent/a.png');
    expect(opened.single.thumbnailUrl, '/nonexistent/a.png');
    expect(opened.single.onAdjust, isNotNull);
  });
}
