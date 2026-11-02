import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/wall_comments/views/comments_button.dart';
import 'package:Prism/features/wall_comments/views/wall_comments_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

const CommentsWall _wall = (wallId: 'w1', statsId: 'NEON', creatorUid: 'maker');

class _CountsRepository implements FavouriteCountsRepository {
  _CountsRepository(this.comments);

  final int comments;

  @override
  Future<Map<String, PrismWallpaperStats>> fetch(Set<String> ids) async => <String, PrismWallpaperStats>{
    for (final String id in ids) id: PrismWallpaperStats(favourites: 0, comments: comments),
  };
}

late AppLocalizations l10n;

Future<void> _mount(WidgetTester tester, int comments) async {
  getIt.registerSingleton<FavouriteCountsCubit>(
    FavouriteCountsCubit(_CountsRepository(comments)),
    dispose: (FavouriteCountsCubit cubit) => cubit.close(),
  );
  await tester.pumpWidget(
    const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: CommentsButton(wall: _wall)),
      ),
    ),
  );
  // The count cubit fetches on a zero-length timer, then emits.
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('shows the visible comment count with its semantics label', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _mount(tester, 3);

    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.commentsCountLabel(3)), findsOneWidget);
    handle.dispose();
  });

  testWidgets('shows no count when the wall has no comments', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _mount(tester, 0);

    expect(find.text('0'), findsNothing);
    expect(find.bySemanticsLabel(l10n.commentsCountLabel(0)), findsNothing);
    handle.dispose();
  });
}
