import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/moods/biz/gallery_walls_cubit.dart';
import 'package:Prism/features/moods/views/pages/gallery_screen.dart';
import 'package:Prism/features/wall_requests/biz/wall_requests_cubit.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/views/pages/wall_requests_page.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

class _MockWallRequestsCubit extends MockCubit<WallRequestsState> implements WallRequestsCubit {}

class _MockGalleryCubit extends MockCubit<GalleryWallsState> implements GalleryWallsCubit {}

WallRequest _request({
  String id = 'r1',
  String text = 'dark minimal mountains',
  WallRequestStatus status = WallRequestStatus.open,
  String filledWallId = '',
  WallRequestFiller? filledBy,
}) => WallRequest(
  id: id,
  text: text,
  tags: const <String>['Minimal'],
  voteCount: 4,
  status: status,
  createdAt: DateTime(2026, 10, 28),
  requesterName: 'Ana',
  requesterPhoto: '',
  mine: false,
  voted: false,
  hidden: false,
  filledWallId: filledWallId,
  filledBy: filledBy,
);

WallRequestsState _state({
  Map<WallRequestTab, WallRequestsTabState> tabs = const <WallRequestTab, WallRequestsTabState>{},
}) {
  return WallRequestsState(
    tabs: <WallRequestTab, WallRequestsTabState>{
      for (final WallRequestTab tab in WallRequestTab.values) tab: tabs[tab] ?? const WallRequestsTabLoading(),
    },
  );
}

void main() {
  late _MockWallRequestsCubit cubit;
  late StreamController<WallRequestsState> states;

  setUpAll(() {
    registerFallbackValue(WallRequestTab.top);
  });

  setUp(() {
    cubit = _MockWallRequestsCubit();
    states = StreamController<WallRequestsState>.broadcast();
    when(() => cubit.load(any())).thenAnswer((_) async {});
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  tearDown(() async {
    await states.close();
  });

  void stub(WallRequestsState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, states.stream, initialState: state);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallRequestsCubit>.value(value: cubit, child: const WallRequestsPage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the three tab labels', (tester) async {
    stub(_state());
    await pumpPage(tester);

    expect(find.text('Wall requests'), findsOneWidget);
    expect(find.text('Top'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Filled'), findsOneWidget);
  });

  testWidgets('the top tab loads once and lists its requests', (tester) async {
    stub(
      _state(
        tabs: <WallRequestTab, WallRequestsTabState>{
          WallRequestTab.top: WallRequestsTabLoaded(<WallRequest>[
            _request(id: 'a'),
            _request(id: 'b', text: 'neon city rain'),
          ]),
        },
      ),
    );
    await pumpPage(tester);

    verify(() => cubit.load(WallRequestTab.top)).called(1);
    expect(find.byType(WallRequestRow), findsNWidgets(2));
    expect(find.text('dark minimal mountains'), findsOneWidget);
    expect(find.text('neon city rain'), findsOneWidget);
  });

  testWidgets('switching to Filled loads it and shows the filled wall thumbnail', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final WallRequestsState initial = _state(
      tabs: <WallRequestTab, WallRequestsTabState>{
        WallRequestTab.top: WallRequestsTabLoaded(<WallRequest>[_request()]),
        WallRequestTab.filled: WallRequestsTabLoaded(<WallRequest>[
          _request(
            id: 'f1',
            text: 'forest cabin',
            status: WallRequestStatus.filled,
            filledWallId: 'wall-1',
            filledBy: WallRequestFiller.studio,
          ),
        ]),
      },
    );
    stub(initial);
    await pumpPage(tester);

    await tester.tap(find.text('Filled'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => cubit.load(WallRequestTab.filled)).called(1);
    expect(find.text('forest cabin'), findsOneWidget);
    expect(find.bySemanticsLabel('Open the wall'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a failed tab shows a retry that loads it again', (tester) async {
    stub(_state(tabs: <WallRequestTab, WallRequestsTabState>{WallRequestTab.top: const WallRequestsTabFailed()}));
    await pumpPage(tester);

    expect(find.widgetWithText(GlintState, "Couldn't load requests"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    verify(() => cubit.load(WallRequestTab.top)).called(2);
  });

  testWidgets('a rejected row upvote shows the localized account-age error', (tester) async {
    app_state.prismUser.loggedIn = true;
    final WallRequest request = _request();
    final WallRequestsState loaded = _state(
      tabs: <WallRequestTab, WallRequestsTabState>{
        WallRequestTab.top: WallRequestsTabLoaded(<WallRequest>[request]),
      },
    );
    final List<String> messages = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (MethodCall call) async {
        if (call.method == 'showToast') messages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
        return true;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      );
    });
    stub(loaded);
    when(() => cubit.toggleVote(request, WallRequestTab.top)).thenAnswer((_) async {
      states.add(WallRequestsState(tabs: loaded.tabs, error: WallRequestError.accountTooNew));
    });
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Upvote'));
    await tester.pump();
    verify(() => cubit.toggleVote(request, WallRequestTab.top)).called(1);
    await tester.pump();

    expect(messages, <String>["Your account can request walls and vote once it's 10 days old."]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tapping a filled wall opens the real gallery route with its single logical id', (tester) async {
    final AppRouter router = AppRouter();
    final _MockGalleryCubit gallery = _MockGalleryCubit();
    when(() => cubit.close()).thenAnswer((_) async {});
    when(() => gallery.load(any())).thenAnswer((_) async {});
    when(() => gallery.close()).thenAnswer((_) async {});
    whenListen(gallery, const Stream<GalleryWallsState>.empty(), initialState: const GalleryWallsLoaded([]));
    stub(
      _state(
        tabs: <WallRequestTab, WallRequestsTabState>{
          WallRequestTab.filled: WallRequestsTabLoaded(<WallRequest>[
            _request(status: WallRequestStatus.filled, filledWallId: 'logical-wall-1'),
          ]),
        },
      ),
    );
    getIt.registerFactory<WallRequestsCubit>(() => cubit);
    getIt.registerFactory<GalleryWallsCubit>(() => gallery);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(() async {
      router.dispose();
      AnalyticsRuntime.reset();
      await getIt.reset();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(
          deepLinkBuilder: (_) => DeepLink(<PageRouteInfo>[WallRequestsRoute(tab: 'filled')]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.bySemanticsLabel('Open the wall'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.current.name, GalleryRoute.name);
    final GalleryScreen screen = tester.widget<GalleryScreen>(find.byType(GalleryScreen));
    expect(screen.ids, 'logical-wall-1');
    expect(screen.source, 'request');
    verify(() => gallery.load(<String>['logical-wall-1'])).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
