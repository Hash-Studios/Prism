import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_archive_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:Prism/features/wall_of_the_day/views/pages/wotd_archive_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockArchiveBloc extends MockBloc<WotdArchiveEvent, WotdArchiveState> implements WotdArchiveBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

WotdPastPick _pick(String id, DateTime date) => WotdPastPick(
  date: date,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.test/$id.jpg',
      thumbnailUrl: '',
      authorName: 'Ana',
    ),
    review: true,
  ),
);

void main() {
  late _MockArchiveBloc bloc;
  late _MockStackRouter router;
  late FakeAppAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(const WotdArchiveEvent.started());
    registerFallbackValue(WallpaperDetailRoute());
  });

  setUp(() {
    bloc = _MockArchiveBloc();
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpPage(WidgetTester tester, WotdArchiveState state, {Stream<WotdArchiveState>? stream}) {
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, stream ?? const Stream<WotdArchiveState>.empty(), initialState: state);
    return tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<WotdArchiveBloc>.value(value: bloc, child: const WotdArchivePage()),
        ),
      ),
    );
  }

  testWidgets('shows a skeleton while the first load runs', (tester) async {
    await pumpPage(tester, WotdArchiveState.initial().copyWith(status: LoadStatus.loading));

    expect(find.text('Past picks'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);
  });

  testWidgets('shows one tile per pick with its date, newest first', (tester) async {
    await pumpPage(
      tester,
      WotdArchiveState.initial().copyWith(
        status: LoadStatus.success,
        picks: <WotdPastPick>[_pick('a', DateTime(2026, 1, 4)), _pick('b', DateTime(2026, 1, 3))],
      ),
    );

    expect(find.text('Sun 4 Jan'), findsOneWidget);
    expect(find.text('Sat 3 Jan'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Sun 4 Jan')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Sat 3 Jan')).dy),
    );
  });

  testWidgets('a tap records the archive open and opens the wall with no refetch and a hero tag', (tester) async {
    await pumpPage(
      tester,
      WotdArchiveState.initial().copyWith(
        status: LoadStatus.success,
        picks: <WotdPastPick>[_pick('a', DateTime(2026, 1, 4))],
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();

    final opened = analytics.events.where((event) => event.eventName == 'wotd_opened').single;
    expect(opened.toWireParameters(), containsPair('source', 'archive'));
    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    expect(route.args!.entity, isA<PrismFeedItem>());
    expect(route.args!.entity!.id, 'a');
    expect(route.args!.heroTag, contains('a'));
  });

  testWidgets('pulling down asks the bloc for a refresh', (tester) async {
    final StreamController<WotdArchiveState> states = StreamController<WotdArchiveState>.broadcast(sync: true);
    addTearDown(states.close);
    final WotdArchiveState loaded = WotdArchiveState.initial().copyWith(
      status: LoadStatus.success,
      picks: <WotdPastPick>[_pick('a', DateTime(2026, 1, 4))],
    );
    when(() => bloc.add(any())).thenAnswer((_) => states.add(loaded));
    await pumpPage(tester, loaded, stream: states.stream);

    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const WotdArchiveEvent.refreshRequested())).called(1);
  });

  testWidgets('a failed first load shows Try again, and an empty archive says so', (tester) async {
    await pumpPage(
      tester,
      WotdArchiveState.initial().copyWith(status: LoadStatus.failure, failure: const ServerFailure('offline')),
    );
    expect(find.text("Couldn't load past picks"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, WotdArchiveState.initial().copyWith(status: LoadStatus.success));
    expect(find.text('No past picks yet'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
