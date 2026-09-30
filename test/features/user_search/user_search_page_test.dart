import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/user_search.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState> implements UserSearchBloc {}

void main() {
  late _MockUserSearchBloc bloc;

  void stubState(UserSearchState state) {
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<UserSearchState>.empty(), initialState: state);
  }

  setUpAll(() {
    registerFallbackValue(const UserSearchEvent.cleared());
  });

  setUp(() {
    bloc = _MockUserSearchBloc();
    getIt.registerFactory<UserSearchBloc>(() => bloc);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
    stubState(UserSearchState.initial());
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: UserSearch()));
    await tester.pump();
  }

  testWidgets('before typing: field, back button and a Glint with a hint', (tester) async {
    await pumpPage(tester);

    expect(find.text('Find creators'), findsOneWidget);
    expect(find.text('Search creators'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byType(Glint), findsOneWidget);
    expect(find.text('Search creators by name'), findsOneWidget);
  });

  testWidgets('submitting asks the bloc to search and clearing resets it', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'ana');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    verify(() => bloc.add(const UserSearchEvent.searchRequested(query: 'ana'))).called(1);

    await tester.pump();
    await tester.tap(find.byTooltip('Clear search'));
    verify(() => bloc.add(const UserSearchEvent.cleared())).called(greaterThanOrEqualTo(1));
  });

  testWidgets('loading shows row skeletons, not wallpaper blocks', (tester) async {
    stubState(UserSearchState.initial().copyWith(status: LoadStatus.loading, query: 'ana'));
    await pumpPage(tester);

    expect(find.byType(PrismSkeleton), findsOneWidget);
    expect(find.byType(Glint), findsNothing);
  });

  testWidgets('results are rows with name, handle, follower count and a chevron', (tester) async {
    stubState(
      UserSearchState.initial().copyWith(
        status: LoadStatus.success,
        query: 'ana',
        users: const <UserSearchUser>[
          UserSearchUser(
            id: 'u1',
            name: 'Ana Silva',
            username: 'anasilva',
            email: 'ana@example.com',
            profilePhoto: '',
            followerCount: 12,
          ),
          UserSearchUser(
            id: 'u2',
            name: 'Anil',
            username: 'anil',
            email: 'anil@example.com',
            profilePhoto: '',
            followerCount: 1,
          ),
        ],
      ),
    );
    await pumpPage(tester);

    expect(find.byType(PrismRow), findsNWidgets(2));
    expect(find.text('Ana Silva'), findsOneWidget);
    expect(find.text('@anasilva · 12 followers'), findsOneWidget);
    expect(find.text('@anil · 1 follower'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
  });

  testWidgets('no match shows an empty state', (tester) async {
    stubState(UserSearchState.initial().copyWith(status: LoadStatus.success, query: 'zzz'));
    await pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, 'No creators found'), findsOneWidget);
  });

  testWidgets('a failed search shows an error and retries the same query', (tester) async {
    stubState(
      UserSearchState.initial().copyWith(
        status: LoadStatus.failure,
        query: 'ana',
        failure: const NetworkFailure('offline'),
      ),
    );
    await pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Couldn't search creators"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const UserSearchEvent.searchRequested(query: 'ana'))).called(1);
  });

  testWidgets('guests see the sign-in prompt and no search field', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SignInPrompt), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Find creators'), findsOneWidget);
  });
}
