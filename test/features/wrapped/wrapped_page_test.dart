import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
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
  final Set<String> failOnce = <String>{};

  @override
  Future<WrappedYear?> fetch(String uid, int year) async {
    reads.add('$uid/$year');
    if (failOnce.remove(uid)) throw Exception('temporary failure');
    return years[uid];
  }
}

class _Sessions implements SessionRepository {
  _Sessions(this.currentUser);

  final StreamController<PrismUsersV2> _users = StreamController<PrismUsersV2>.broadcast();
  @override
  PrismUsersV2 currentUser;

  @override
  Stream<PrismUsersV2> watchCurrentUser() async* {
    yield currentUser;
    yield* _users.stream;
  }

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user) async {
    currentUser = user;
    _users.add(user);
    return Result.success<SessionEntity>(
      SessionEntity(
        userId: user.id,
        loggedIn: user.loggedIn,
        premium: user.premium,
        subscriptionTier: user.subscriptionTier,
      ),
    );
  }

  @override
  Future<Result<SessionEntity>> getSession() => throw UnimplementedError();

  @override
  Future<Result<SessionEntity>> updateFollowing(List<String> following) => throw UnimplementedError();

  Future<void> close() => _users.close();
}

void _registerBloc(WrappedBloc bloc) {
  getIt.registerSingleton<WrappedBloc>(bloc);
  addTearDown(() async {
    if (getIt.isRegistered<WrappedBloc>()) await getIt.unregister<WrappedBloc>();
  });
}

void _registerSessions(_Sessions sessions) {
  getIt.registerSingleton<SessionRepository>(sessions);
  addTearDown(() async {
    if (getIt.isRegistered<SessionRepository>()) await getIt.unregister<SessionRepository>();
    await sessions.close();
  });
}

void main() {
  late FakeAppAnalytics analytics;
  late PrismUsersV2 previousUser;
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    previousUser = app_state.prismUser;
    toasts.overlayResolver = () => navigator.currentState?.overlay;
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = previousUser;
    toasts.overlayResolver = null;
    if (getIt.isRegistered<WrappedBloc>()) await getIt.unregister<WrappedBloc>();
    if (getIt.isRegistered<SessionRepository>()) await getIt.unregister<SessionRepository>();
  });

  Future<_Repository> open(WidgetTester tester, Map<String, WrappedYear?> years) async {
    final _Repository repository = _Repository(years);
    _registerBloc(WrappedBloc(repository));
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
    await tester.pumpAndSettle();

    expect(repository.reads, <String>['quiet/2026']);
    expect(find.byType(PrismWrappedPage), findsNothing);
    expect(find.text('Open Wrapped'), findsOneWidget);
    expect(find.text('There is no Wrapped for this account this year.'), findsOneWidget);
    expect(analytics.events.whereType<WrappedNotEligibleEvent>().single.source, WrappedSourceValue.push);
    expect(analytics.events.whereType<WrappedOpenedEvent>(), isEmpty);

    await tester.tap(find.text('Open Wrapped'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(PrismWrappedPage), findsNothing);
    expect(repository.reads, <String>['quiet/2026']);
    expect(analytics.events.whereType<WrappedNotEligibleEvent>(), hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the story shows only the signed-in user’s own Wrapped', (tester) async {
    app_state.prismUser = profileUser(id: 'heavy');
    final _Repository repository = await open(tester, <String, WrappedYear?>{'heavy': fixtureWrappedYear()});

    expect(repository.reads, <String>['heavy/2026']);
    expect(find.text('Your year in walls'), findsOneWidget);
    expect(analytics.events.whereType<WrappedOpenedEvent>().single.source, WrappedSourceValue.push);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed Wrapped read can be retried', (tester) async {
    app_state.prismUser = profileUser(id: 'heavy');
    final _Repository repository = _Repository(<String, WrappedYear?>{'heavy': fixtureWrappedYear()})
      ..failOnce.add('heavy');
    _registerBloc(WrappedBloc(repository));
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

    expect(find.text('Unable to load your Wrapped. Check your connection and try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.reads, <String>['heavy/2026', 'heavy/2026']);
    expect(find.text('Your year in walls'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the open story closes when the signed-in account changes', (tester) async {
    final PrismUsersV2 user = profileUser(id: 'heavy');
    app_state.prismUser = user;
    final _Sessions sessions = _Sessions(user);
    _registerSessions(sessions);
    final _Repository repository = await open(tester, <String, WrappedYear?>{'heavy': fixtureWrappedYear()});

    expect(repository.reads, <String>['heavy/2026']);
    expect(find.byType(PrismWrappedPage), findsOneWidget);
    await sessions.replaceCurrentUser(profileUser(id: 'other'));
    await tester.pumpAndSettle();

    expect(find.byType(PrismWrappedPage), findsNothing);
    expect(find.text('Open Wrapped'), findsOneWidget);
  });

  testWidgets('an account switch blanks a story under another route', (tester) async {
    final PrismUsersV2 user = profileUser(id: 'heavy');
    app_state.prismUser = user;
    final _Sessions sessions = _Sessions(user);
    _registerSessions(sessions);
    await open(tester, <String, WrappedYear?>{'heavy': fixtureWrappedYear()});
    expect(find.text('Your year in walls'), findsOneWidget);

    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Overlay'))),
      ),
    );
    await tester.pumpAndSettle();
    await sessions.replaceCurrentUser(profileUser(id: 'other'));
    await tester.pump();
    expect(find.text('Overlay'), findsOneWidget);
    expect(find.text('Your year in walls'), findsNothing);

    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(PrismWrappedPage), findsOneWidget);
    expect(find.text('Your year in walls'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a signed-out visitor never reads a Wrapped', (tester) async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final _Repository repository = await open(tester, <String, WrappedYear?>{});
    await tester.pumpAndSettle();

    expect(repository.reads, isEmpty);
    expect(find.byType(PrismWrappedPage), findsNothing);
    expect(analytics.events.whereType<WrappedNotEligibleEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 5));
  });
}
