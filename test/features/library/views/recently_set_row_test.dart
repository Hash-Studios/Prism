import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/library/views/widgets/recently_set_row.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

AppliedWallpaper _item(String id, {String? fullUrl, DateTime? at}) => AppliedWallpaper(
  id: id,
  source: 'prism',
  thumbnailUrl: '/missing/$id.jpg',
  fullUrl: fullUrl ?? 'https://example.com/$id.jpg',
  target: 'home',
  appliedAt: at ?? DateTime.utc(2026),
);

void main() {
  Future<void> pumpRow(WidgetTester tester, List<AppliedWallpaper> items) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: Scaffold(body: RecentlySetRow(items: items)),
    ),
  );

  testWidgets('shows nothing when no wallpaper was set yet', (tester) async {
    await pumpRow(tester, const <AppliedWallpaper>[]);

    expect(find.text('Recently set'), findsNothing);
  });

  testWidgets('deduplicates history in supplied order and shows at most eight wallpapers', (tester) async {
    await pumpRow(tester, <AppliedWallpaper>[
      _item('w0', at: DateTime.utc(2026, 1, 1)),
      _item('dup', fullUrl: 'https://example.com/w0.jpg', at: DateTime.utc(2026, 1, 3)),
      for (int i = 1; i < 9; i++) _item('w$i', at: DateTime.utc(2026, 1, i + 1)),
    ]);

    expect(find.text('Recently set'), findsOneWidget);
    expect(find.bySemanticsLabel('Set this wallpaper again'), findsNWidgets(8));
    expect(find.byType(InkWell), findsNWidgets(8));
    final List<String> renderedPaths = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as FileImage).file.path)
        .toList();
    expect(renderedPaths, <String>[for (int i = 0; i < 8; i++) '/missing/w$i.jpg']);
  });

  testWidgets('tapping a recently set wall opens the Set screen even with a saved default', (tester) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final List<SetScreenRequest> opened = <SetScreenRequest>[];
    final original = SetWallpaperFlow.screenOpener;
    SetWallpaperFlow.screenOpener = (context, request) async {
      opened.add(request);
      return null;
    };
    addTearDown(() => SetWallpaperFlow.screenOpener = original);

    await pumpRow(tester, <AppliedWallpaper>[_item('w0')]);
    await tester.tap(find.bySemanticsLabel('Set this wallpaper again'));
    await tester.pump();
    for (int i = 0; i < 80 && opened.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }

    expect(opened, hasLength(1));
    expect(opened.single.url, 'https://example.com/w0.jpg');
    expect(opened.single.thumbnailUrl, '/missing/w0.jpg');
    expect(opened.single.onAdjust, isNotNull);
  });
}
