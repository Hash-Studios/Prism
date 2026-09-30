import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_summary_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/profile_user_fixture.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

void main() {
  late _MockPublicProfileBloc bloc;

  setUpAll(() => registerFallbackValue(const PublicProfileEvent.refreshRequested()));

  setUp(() {
    bloc = _MockPublicProfileBloc();
    when(() => bloc.state).thenReturn(PublicProfileState.initial());
    app_state.prismUser = profileUser(id: 'me');
  });

  Future<void> pumpTile(WidgetTester tester, UserSummaryEntity user, {VoidCallback? onTap}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: UserSummaryTile(user: user, onTap: onTap ?? () {}),
          ),
        ),
      ),
    );
  }

  UserSummaryEntity user({bool following = false, String email = 'ana@example.com'}) => UserSummaryEntity(
    id: 'u1',
    name: 'Ana Rivera',
    email: email,
    username: 'ana_rivera',
    profilePhoto: '',
    isFollowedByCurrentUser: following,
  );

  testWidgets('shows name, username and a Follow button that asks the bloc to follow', (tester) async {
    await pumpTile(tester, user());

    expect(find.text('Ana Rivera'), findsOneWidget);
    expect(find.text('@ana_rivera'), findsOneWidget);
    await tester.tap(find.text('Follow'));

    final event = verify(() => bloc.add(captureAny())).captured.single as PublicProfileEvent;
    expect(event.toString(), contains('follow: true'));
    expect(event.toString(), contains('targetUserId: u1'));
  });

  testWidgets('a followed user shows Following and asks the bloc to unfollow', (tester) async {
    await pumpTile(tester, user(following: true));

    expect(find.text('Follow'), findsNothing);
    await tester.tap(find.text('Following'));

    final event = verify(() => bloc.add(captureAny())).captured.single as PublicProfileEvent;
    expect(event.toString(), contains('follow: false'));
  });

  testWidgets('the row opens the profile without touching follow', (tester) async {
    bool opened = false;
    await pumpTile(tester, user(), onTap: () => opened = true);

    await tester.tap(find.text('Ana Rivera'));

    expect(opened, isTrue);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets("hides the follow button on the viewer's own account", (tester) async {
    await pumpTile(tester, user(email: 'user@example.com'));

    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('a long name on a narrow screen with large text ellipsizes without overflow', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 600), textScaler: TextScaler.linear(1.5)),
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider<PublicProfileBloc>.value(
              value: bloc,
              child: UserSummaryTile(
                user: const UserSummaryEntity(
                  id: 'u1',
                  name: 'Alexandria Montgomery-Featherstonehaugh the Third',
                  email: 'a@example.com',
                  username: 'alexandria_montgomery_featherstonehaugh',
                  profilePhoto: '',
                  isFollowedByCurrentUser: true,
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Following'), findsOneWidget);
  });
}
