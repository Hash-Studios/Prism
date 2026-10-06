import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/views/pages/wallpaper_history_screen.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart';
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
    await tester.pumpWidget(const MaterialApp(home: WallpaperHistoryScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.text('Clear history'), findsNothing);
  });

  testWidgets('lists applied wallpapers newest first with target labels', (tester) async {
    await record('a', 'home', DateTime(2026, 1, 1, 9));
    await record('b', 'lock', DateTime(2026, 1, 2, 9));
    await tester.pumpWidget(const MaterialApp(home: WallpaperHistoryScreen()));
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
    await tester.pumpWidget(const MaterialApp(home: WallpaperHistoryScreen()));
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
}
