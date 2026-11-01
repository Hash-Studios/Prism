import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/wrapped/biz/bloc/wrapped_bloc.j.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/pages/wrapped_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';
import 'wrapped_fixture.dart';

class _Repository implements WrappedRepository {
  _Repository(this.years);

  final Map<String, WrappedYear?> years;
  final List<String> reads = <String>[];

  @override
  Future<WrappedYear?> fetch(String uid, int year) async {
    reads.add('$uid/$year');
    return years[uid];
  }
}

class _Analytics extends FakeAppAnalytics {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);
}

void main() {
  late _Analytics analytics;
  late PrismUsersV2 previousUser;
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  setUp(() {
    analytics = _Analytics();
    AnalyticsRuntime.instance = analytics;
    previousUser = app_state.prismUser;
    toasts.overlayResolver = () => navigator.currentState?.overlay;
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = previousUser;
    toasts.overlayResolver = null;
    if (getIt.isRegistered<WrappedBloc>()) await getIt.unregister<WrappedBloc>();
  });

  Future<_Repository> open(WidgetTester tester, Map<String, WrappedYear?> years) async {
    final _Repository repository = _Repository(years);
    getIt.registerSingleton<WrappedBloc>(WrappedBloc(repository));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PrismWrappedPage(source: WrappedSourceValue.push))),
            child: const Text('Open Wrapped'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Wrapped'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return repository;
  }

  testWidgets('a user with no Wrapped sees a message, goes back and is counted as not eligible', (tester) async {
    app_state.prismUser = profileUser(id: 'quiet');
    final _Repository repository = await open(tester, <String, WrappedYear?>{'quiet': null});
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(repository.reads, <String>['quiet/2026']);
    expect(find.byType(PrismWrappedPage), findsNothing);
    expect(find.text('Open Wrapped'), findsOneWidget);
    expect(find.text('There is no Wrapped for this account this year.'), findsOneWidget);
    expect(analytics.events.whereType<WrappedNotEligibleEvent>().single.source, WrappedSourceValue.push);
    expect(analytics.events.whereType<WrappedOpenedEvent>(), isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a user already known to have no Wrapped also leaves', (tester) async {
    app_state.prismUser = profileUser(id: 'quiet');
    final _Repository repository = _Repository(<String, WrappedYear?>{'quiet': null});
    final WrappedBloc bloc = WrappedBloc(repository)..add(const WrappedEvent.load('quiet'));
    await tester.runAsync(() => bloc.stream.firstWhere((state) => state is WrappedNotEligible));
    getIt.registerSingleton<WrappedBloc>(bloc);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PrismWrappedPage(source: WrappedSourceValue.home))),
            child: const Text('Open Wrapped'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Wrapped'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(repository.reads, <String>['quiet/2026']);
    expect(find.byType(PrismWrappedPage), findsNothing);
    expect(analytics.events.whereType<WrappedNotEligibleEvent>().single.source, WrappedSourceValue.home);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the story shows only the signed-in user\'s own Wrapped', (tester) async {
    app_state.prismUser = profileUser(id: 'heavy');
    final _Repository repository = await open(tester, <String, WrappedYear?>{'heavy': fixtureWrappedYear()});

    expect(repository.reads, <String>['heavy/2026']);
    expect(find.text('Your year in walls'), findsOneWidget);
    expect(analytics.events.whereType<WrappedOpenedEvent>().single.source, WrappedSourceValue.push);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a signed-out visitor never reads a Wrapped', (tester) async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final _Repository repository = await open(tester, <String, WrappedYear?>{});
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(repository.reads, isEmpty);
    expect(find.byType(PrismWrappedPage), findsNothing);
    expect(analytics.events.whereType<WrappedNotEligibleEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 5));
  });
}
