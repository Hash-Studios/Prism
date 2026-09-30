import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/features/favourite_setups/biz/bloc/favourite_setups_bloc.j.dart';
import 'package:Prism/features/favourite_setups/domain/usecases/favourite_setups_usecases.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/views/widgets/setup_detail_view.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _MockViewStats extends Mock implements ViewStatsRepository {}

class _MockFetchUseCase extends Mock implements FetchFavouriteSetupsUseCase {}

class _MockToggleUseCase extends Mock implements ToggleFavouriteSetupUseCase {}

const SetupEntity _setup = SetupEntity(
  id: 'setup1',
  image: 'https://example.com/setup1.jpg',
  name: 'Bloodland',
  desc: 'A dark setup',
  by: 'Creator',
  icon: 'Lawnicons',
  widget: 'KWGT pack',
);

void main() {
  late _MockViewStats viewStats;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    viewStats = _MockViewStats();
    when(() => viewStats.recordSetupView(any())).thenAnswer((_) async => Result.success('12'));
    getIt.registerSingleton<ViewStatsRepository>(viewStats);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    app_state.notchSize = 0;
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpView(WidgetTester tester, {bool sharedLink = false}) async {
    // Flutter's test font is wider than the app font, so the dense info row overflows only here.
    final void Function(FlutterErrorDetails)? onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final bloc = FavouriteSetupsBloc(_MockFetchUseCase(), _MockToggleUseCase());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteSetupsBloc>.value(
          value: bloc,
          child: SetupDetailView(setup: _setup, sharedLink: sharedLink),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byIcon(JamIcons.chevron_up));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('records the setup view once and shows the details when the panel opens', (tester) async {
    await pumpView(tester);
    await openPanel(tester);

    verify(() => viewStats.recordSetupView('SETUP1')).called(1);
    expect(find.text('BLOODLAND'), findsOneWidget);
    expect(find.text('A dark setup'), findsOneWidget);
    expect(find.text('12 views'), findsOneWidget);
    expect(find.text('Wall Link'), findsOneWidget);
    expect(find.text('Lawnicons'), findsOneWidget);
    expect(find.text('KWGT pack'), findsOneWidget);
  });

  testWidgets('offers favourite and share actions', (tester) async {
    await pumpView(tester);

    expect(find.byType(FavoriteIcon), findsOneWidget);
    expect(find.byIcon(JamIcons.share_alt), findsOneWidget);
    expect(find.text('Premium Required'), findsNothing);
  });

  testWidgets('a shared link asks a free user for premium and hides the actions', (tester) async {
    await pumpView(tester, sharedLink: true);
    await openPanel(tester);

    expect(find.text('Premium Required'), findsOneWidget);
    expect(find.byType(FavoriteIcon), findsNothing);
    expect(find.text('Lawnicons'), findsNothing);
  });

  testWidgets('a shared link keeps the favourite action for premium users and drops re-sharing', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..premium = true;
    await pumpView(tester, sharedLink: true);

    expect(find.byType(FavoriteIcon), findsOneWidget);
    expect(find.byIcon(JamIcons.share_alt), findsNothing);
    expect(find.text('Premium Required'), findsNothing);
  });
}
