import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/widgets/user_relation_list_body.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

const String _profileUid = 'profile-uid';

const PublicProfileEvent _loadFollowersPage = PublicProfileEvent.relationPageRequested(
  kind: UserRelationKind.followers,
  profileUid: _profileUid,
);

const PublicProfileEvent _refreshFollowers = PublicProfileEvent.relationRefreshRequested(
  kind: UserRelationKind.followers,
  profileUid: _profileUid,
);

const RelationCursor _nextCursor = RelationCursor(createdAt: 1, edgeId: 'u29');

UserSummaryEntity _user(int i) => UserSummaryEntity(
  id: 'u$i',
  email: 'user$i@example.com',
  name: 'User $i',
  username: 'user_$i',
  profilePhoto: '',
  isFollowedByCurrentUser: false,
);

final List<UserSummaryEntity> _thirtyUsers = <UserSummaryEntity>[for (int i = 0; i < 30; i++) _user(i)];

void main() {
  late _MockPublicProfileBloc bloc;

  setUp(() {
    bloc = _MockPublicProfileBloc();
    getIt.registerFactory<PublicProfileBloc>(() => bloc);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = profileUser(id: 'me');
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  void stubState(PublicProfileState state, {Stream<PublicProfileState> stream = const Stream.empty()}) {
    whenListen(bloc, stream, initialState: state);
  }

  PublicProfileState followersState(RelationList followers) =>
      PublicProfileState.initial().copyWith(followers: followers);

  Future<void> pumpBody(
    WidgetTester tester, {
    required RelationList followers,
    UserRelationKind kind = UserRelationKind.followers,
    Widget Function(Widget child)? wrap,
  }) async {
    final PublicProfileState state = kind == UserRelationKind.followers
        ? followersState(followers)
        : PublicProfileState.initial().copyWith(following: followers);
    stubState(state);
    final Widget body = UserRelationListBody(kind: kind, profileUid: _profileUid);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: wrap == null ? null : (context, child) => wrap(child!),
        home: body,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('asks for the first page on open', (tester) async {
    await pumpBody(tester, followers: const RelationList());

    verify(() => bloc.add(_loadFollowersPage)).called(1);
  });

  testWidgets('loads more near the end of the list', (tester) async {
    await pumpBody(
      tester,
      followers: RelationList(summaries: _thirtyUsers, next: _nextCursor, pages: 1),
    );

    await scrollToEnd(tester);

    expect(find.bySemanticsLabel(l10n.accountRelationLoadingMore), findsOneWidget);
    expect(verify(() => bloc.add(_loadFollowersPage)).callCount, greaterThan(1));
  });

  testWidgets('a failed next page shows the retry row and Try again asks again', (tester) async {
    await pumpBody(
      tester,
      followers: RelationList(summaries: _thirtyUsers, next: _nextCursor, pages: 1, failed: true),
    );

    await scrollToEnd(tester);
    expect(find.text(l10n.accountRelationLoadMoreFailed), findsOneWidget);
    expect(find.text(l10n.accountTryAgain), findsOneWidget);

    clearInteractions(bloc);
    await tester.ensureVisible(find.text(l10n.accountTryAgain));
    await tester.pump();
    await tester.tap(find.text(l10n.accountTryAgain));
    await tester.pump();

    verify(() => bloc.add(_loadFollowersPage)).called(1);
  });

  testWidgets('first page failure shows the error state', (tester) async {
    await pumpBody(tester, followers: const RelationList(failed: true));

    expect(find.text(l10n.accountCouldNotLoadFollowers), findsOneWidget);
    expect(find.text(l10n.accountTryAgain), findsOneWidget);
  });

  testWidgets('empty list shows the empty state', (tester) async {
    await pumpBody(tester, followers: const RelationList(pages: 1));

    expect(find.text(l10n.accountNoFollowersYet), findsOneWidget);
  });

  testWidgets('empty following list shows the following empty state', (tester) async {
    await pumpBody(tester, followers: const RelationList(pages: 1), kind: UserRelationKind.following);

    expect(find.text(l10n.accountNotFollowingAnyoneYet), findsOneWidget);
  });

  testWidgets('large text: retry row wraps without overflow', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpBody(
      tester,
      followers: RelationList(summaries: _thirtyUsers, next: _nextCursor, pages: 1, failed: true),
      wrap: (child) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child,
        ),
      ),
    );

    await scrollToEnd(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.accountRelationLoadMoreFailed), findsOneWidget);
    expect(find.text(l10n.accountTryAgain), findsOneWidget);
  });

  testWidgets('RTL: rows and footer render', (tester) async {
    await pumpBody(
      tester,
      followers: RelationList(summaries: _thirtyUsers.take(3).toList(), next: _nextCursor, pages: 1, failed: true),
      wrap: (child) => Directionality(textDirection: TextDirection.rtl, child: child),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.accountRelationLoadMoreFailed), findsOneWidget);
  });

  testWidgets('RTL: loading footer renders its semantics label', (tester) async {
    await pumpBody(
      tester,
      followers: RelationList(summaries: _thirtyUsers.take(3).toList(), next: _nextCursor, pages: 1),
      wrap: (child) => Directionality(textDirection: TextDirection.rtl, child: child),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(l10n.accountRelationLoadingMore), findsOneWidget);
  });

  testWidgets('pull to refresh asks for a refresh', (tester) async {
    final StreamController<PublicProfileState> states = StreamController<PublicProfileState>.broadcast();
    addTearDown(states.close);
    final RelationList followers = RelationList(summaries: _thirtyUsers.take(3).toList(), next: _nextCursor, pages: 1);
    stubState(followersState(followers), stream: states.stream);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UserRelationListBody(kind: UserRelationKind.followers, profileUid: _profileUid),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    clearInteractions(bloc);

    await tester.fling(find.byType(ListView), const Offset(0, 600), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    verify(() => bloc.add(_refreshFollowers)).called(1);

    // The refresh future waits for a state with isFetching false. Emit one so it completes.
    states.add(followersState(followers));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
