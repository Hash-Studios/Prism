import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_relation_list_body.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

void main() {
  late _MockPublicProfileBloc bloc;

  setUpAll(() => registerFallbackValue(const PublicProfileEvent.refreshRequested()));

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

  Future<void> pumpBody(
    WidgetTester tester, {
    required RelationList followers,
    List<String> emails = const <String>['ana@example.com'],
    UserRelationKind kind = UserRelationKind.followers,
  }) async {
    final PublicProfileState state = kind == UserRelationKind.followers
        ? PublicProfileState.initial().copyWith(followers: followers)
        : PublicProfileState.initial().copyWith(following: followers);
    whenListen(bloc, const Stream<PublicProfileState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: UserRelationListBody(kind: kind, emails: emails),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  const UserSummaryEntity ana = UserSummaryEntity(
    id: 'u2',
    email: 'ana@example.com',
    name: 'Ana Rivera',
    username: 'ana_rivera',
    profilePhoto: '',
    isFollowedByCurrentUser: false,
  );

  testWidgets('shows the title, a search field and skeleton rows while the first page loads', (tester) async {
    await pumpBody(tester, followers: const RelationList(isFetching: true));

    expect(find.text('Followers'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search by username'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsWidgets);
  });

  testWidgets('lists people with a Follow button each', (tester) async {
    await pumpBody(tester, followers: const RelationList(summaries: <UserSummaryEntity>[ana]));

    expect(find.text('Ana Rivera'), findsOneWidget);
    expect(find.text('@ana_rivera'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('no followers yet is an empty state, not an error', (tester) async {
    await pumpBody(tester, followers: const RelationList(), emails: const <String>[]);

    expect(find.text('No followers yet'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('the following list has its own title and empty copy', (tester) async {
    await pumpBody(tester, followers: const RelationList(), emails: const <String>[], kind: UserRelationKind.following);

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Not following anyone yet'), findsOneWidget);
  });

  testWidgets('a failed first page shows an error whose retry asks for page 0 again', (tester) async {
    await pumpBody(tester, followers: const RelationList());

    expect(find.text('Could not load followers'), findsOneWidget);
    clearInteractions(bloc);
    await tester.tap(find.text('Try again'));

    final event = verify(() => bloc.add(captureAny())).captured.single as PublicProfileEvent;
    expect(event.toString(), contains('page: 0'));
  });

  testWidgets('the clear button appears once there is text and empties the field', (tester) async {
    await pumpBody(tester, followers: const RelationList(summaries: <UserSummaryEntity>[ana]));

    expect(find.byTooltip('Clear search'), findsNothing);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsNothing);
  });
}
