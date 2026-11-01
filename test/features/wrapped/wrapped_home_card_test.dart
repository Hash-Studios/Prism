import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wrapped/biz/bloc/wrapped_bloc.j.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/widgets/wrapped_home_card.dart';
import 'package:Prism/features/wrapped/wrapped_config.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/profile_user_fixture.dart';
import 'wrapped_fixture.dart';

class _Repository implements WrappedRepository {
  @override
  Future<WrappedYear?> fetch(String uid, int year) async => fixtureWrappedYear();
}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

void main() {
  tearDown(() {
    WrappedConfig.override = null;
  });

  test('shows the Home card only inside the window for the loaded owner', () {
    WrappedConfig.override = (enabled: true, start: DateTime(2026, 12), end: DateTime(2027, 1, 15));
    final WrappedState ready = WrappedState.ready('u1', fixtureWrappedYear());

    expect(wrappedForHome(ready, 'u1', DateTime(2026, 11, 30, 23)), isNull);
    expect(wrappedForHome(ready, 'u1', DateTime(2026, 12, 1, 0, 5)), isNotNull);
    expect(wrappedForHome(ready, 'u1', DateTime(2027, 1, 15, 22)), isNotNull);
    expect(wrappedForHome(ready, 'u1', DateTime(2027, 1, 16)), isNull);
  });

  test('hides the Home card when the flag is off, for another uid, or when not loaded', () {
    final WrappedState ready = WrappedState.ready('u1', fixtureWrappedYear());
    final DateTime inWindow = DateTime(2026, 12, 10);

    WrappedConfig.override = (enabled: false, start: DateTime(2026, 12), end: DateTime(2027, 1, 15));
    expect(wrappedForHome(ready, 'u1', inWindow), isNull);

    WrappedConfig.override = (enabled: true, start: DateTime(2026, 12), end: DateTime(2027, 1, 15));
    expect(wrappedForHome(ready, 'u2', inWindow), isNull);
    expect(wrappedForHome(ready, '', inWindow), isNull);
    expect(wrappedForHome(const WrappedState.notEligible('u1'), 'u1', inWindow), isNull);
    expect(wrappedForHome(const WrappedState.loading('u1'), 'u1', inWindow), isNull);
  });

  testWidgets('renders the title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: WrappedHomeCard(year: fixtureWrappedYear(), memCacheHeight: 200)),
      ),
    );

    expect(find.text('Your 2026 in Prism'), findsOneWidget);
    expect(find.text('Your year in walls is ready.'), findsOneWidget);
  });

  testWidgets('a mounted Home carousel loads Wrapped after the app resumes inside its window', (tester) async {
    final DateTime today = DateTime.now();
    final PrismUsersV2 previousUser = app_state.prismUser;
    app_state.prismUser = profileUser(id: 'heavy');
    final WrappedBloc bloc = WrappedBloc(_Repository());
    getIt.registerSingleton<WrappedBloc>(bloc);
    final _MockWotdBloc wotd = _MockWotdBloc();
    when(() => wotd.state).thenReturn(WotdState.initial());
    addTearDown(wotd.close);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      app_state.prismUser = previousUser;
      if (getIt.isRegistered<WrappedBloc>()) await getIt.unregister<WrappedBloc>();
    });
    WrappedConfig.override = (
      enabled: true,
      start: DateTime(today.year, today.month, today.day + 1),
      end: DateTime(today.year, today.month, today.day + 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: BlocProvider<WotdBloc>.value(
          value: wotd,
          child: const Scaffold(body: FeedCarousel(previewWalls: <PrismFeedItem>[])),
        ),
      ),
    );
    expect(find.text('Your 2026 in Prism'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    WrappedConfig.override = (
      enabled: true,
      start: DateTime(today.year, today.month, today.day - 1),
      end: DateTime(today.year, today.month, today.day + 1),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(bloc.state, isA<WrappedReady>());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(CarouselSlider), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Your 2026 in Prism'), findsOneWidget);
  });
}
