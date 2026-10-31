import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:Prism/features/creator_directory/views/similar_creators_offer.dart';
import 'package:Prism/features/creator_directory/views/widgets/followed_by_line.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/follow_outcome_toast.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/profile_user_fixture.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _FakeDirectory extends Fake implements CreatorDirectoryRepository {
  FollowedBy followed = FollowedBy.none;
  bool failFollowed = false;
  int followedCalls = 0;
  List<DirectoryCreator> similar = const <DirectoryCreator>[];
  int similarCalls = 0;

  @override
  Future<FollowedBy> followedBy(String creatorUid) async {
    followedCalls++;
    if (failFollowed) throw StateError('offline');
    return followed;
  }

  @override
  Future<List<DirectoryCreator>> similarTo(String uid, {int limit = 6}) async {
    similarCalls++;
    return similar;
  }
}

DirectoryCreator _creator(String uid, String name) => DirectoryCreator(
  entry: CreatorDirectoryEntry(
    uid: uid,
    name: name,
    username: name.toLowerCase(),
    photoUrl: '',
    followerCount: 0,
    wallIds: const <String>[],
    categories: const <String>[],
    similar: const <String>[],
    rank: 1,
  ),
  walls: const [],
);

FollowedByPerson _person(String name) => (name: name, photoUrl: '');

FollowOutcome _outcome({required bool follow, bool success = true, String name = 'Kai'}) =>
    FollowOutcome(id: 1, follow: follow, success: success, targetName: name, targetUserId: 'k');

Widget _app(Widget home, {GlobalKey<NavigatorState>? navigatorKey}) => MaterialApp(
  navigatorKey: navigatorKey,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PublicProfileEvent.followChangeRequested(
        follow: true,
        currentUserId: '',
        currentUserEmail: '',
        targetUserId: '',
        targetUserEmail: '',
      ),
    );
  });

  late _FakeDirectory repo;

  setUp(() {
    repo = _FakeDirectory();
    getIt.registerSingleton<CreatorDirectoryRepository>(repo);
    app_state.prismUser = profileUser(id: 'viewer');
    resetSimilarCreatorsOffer();
  });

  tearDown(() async {
    toasts.overlayResolver = null;
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  group('Followed by line', () {
    Future<void> pumpLine(WidgetTester tester, {String creatorUid = 'creator'}) async {
      await tester.pumpWidget(_app(FollowedByLine(creatorUid: creatorUid)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows nothing when no one the viewer follows follows the creator', (tester) async {
      repo.followed = FollowedBy.none;
      await pumpLine(tester);
      expect(find.textContaining('Followed by'), findsNothing);
      expect(repo.followedCalls, 1);
    });

    testWidgets('one person reads "Followed by Ann" with one avatar', (tester) async {
      repo.followed = FollowedBy(count: 1, people: [_person('Ann')]);
      await pumpLine(tester);
      expect(find.text('Followed by Ann'), findsOneWidget);
      expect(find.byType(PrismAvatar), findsOneWidget);
    });

    testWidgets('two people read "Followed by Ann and Ben" with two avatars', (tester) async {
      repo.followed = FollowedBy(count: 2, people: [_person('Ann'), _person('Ben')]);
      await pumpLine(tester);
      expect(find.text('Followed by Ann and Ben'), findsOneWidget);
      expect(find.byType(PrismAvatar), findsNWidgets(2));
    });

    testWidgets('five followers read "Followed by Ann, Ben and 3 others you follow" with three avatars', (
      tester,
    ) async {
      repo.followed = FollowedBy(count: 5, people: [_person('Ann'), _person('Ben'), _person('Cy')]);
      await pumpLine(tester);
      expect(find.text('Followed by Ann, Ben and 3 others you follow'), findsOneWidget);
      expect(find.byType(PrismAvatar), findsNWidgets(3));
    });

    testWidgets('three followers read "Followed by Ann, Ben and 1 other you follow"', (tester) async {
      repo.followed = FollowedBy(count: 3, people: [_person('Ann'), _person('Ben'), _person('Cy')]);
      await pumpLine(tester);
      expect(find.text('Followed by Ann, Ben and 1 other you follow'), findsOneWidget);
    });

    testWidgets('the viewer own profile never calls the repository and shows nothing', (tester) async {
      repo.followed = FollowedBy(count: 1, people: [_person('Ann')]);
      await pumpLine(tester, creatorUid: 'viewer');
      expect(repo.followedCalls, 0);
      expect(find.textContaining('Followed by'), findsNothing);
    });

    testWidgets('a signed-out viewer never calls the repository and shows nothing', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      repo.followed = FollowedBy(count: 1, people: [_person('Ann')]);
      await pumpLine(tester);
      expect(repo.followedCalls, 0);
      expect(find.textContaining('Followed by'), findsNothing);
    });

    testWidgets('a repository error shows nothing', (tester) async {
      repo.failFollowed = true;
      await pumpLine(tester);
      expect(repo.followedCalls, 1);
      expect(find.byType(PrismAvatar), findsNothing);
      expect(find.textContaining('Followed by'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Similar creators offer', () {
    late BuildContext context;
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
          navigatorKey: navigatorKey,
        ),
      );
      toasts.overlayResolver = () => navigatorKey.currentState?.overlay;
    }

    Future<void> settleToasts(WidgetTester tester) async {
      // A toast with an action stays for about 3.6 s, then fades out.
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a follow offers "More like Kai", and tapping it opens the sheet with Follow buttons', (tester) async {
      repo.similar = [_creator('a', 'Lia'), _creator('b', 'Max')];
      final bloc = _MockPublicProfileBloc();
      whenListen(bloc, const Stream<PublicProfileState>.empty(), initialState: PublicProfileState.initial());
      getIt.registerFactory<PublicProfileBloc>(() => bloc);
      await pumpApp(tester);

      showFollowOutcomeToast(context, _outcome(follow: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('Followed Kai!'), findsOneWidget);
      expect(find.text('More like Kai'), findsOneWidget);
      expect(repo.similarCalls, 1);

      await tester.tap(find.text('More like Kai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.descendant(of: find.byType(PrismSheetBody), matching: find.text('More like Kai')), findsOneWidget);
      expect(find.text('Lia'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Follow'), findsNWidgets(2));

      await tester.tap(find.text('Follow').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final List<Object?> sent = verify(() => bloc.add(captureAny())).captured;
      expect(
        sent.single,
        const PublicProfileEvent.followChangeRequested(
          follow: true,
          currentUserId: 'viewer',
          currentUserEmail: 'user@example.com',
          targetUserId: 'a',
          targetUserEmail: '',
          targetName: 'Lia',
        ),
      );
      expect(find.descendant(of: find.byType(PrismSheetBody), matching: find.text('More like Kai')), findsOneWidget);

      await settleToasts(tester);
    });

    testWidgets('a second follow in the same session shows no offer and does not call similarTo again', (tester) async {
      repo.similar = [_creator('a', 'Lia')];
      await pumpApp(tester);

      showFollowOutcomeToast(context, _outcome(follow: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('More like Kai'), findsOneWidget);

      await settleToasts(tester);

      showFollowOutcomeToast(context, _outcome(follow: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('Followed Kai!'), findsOneWidget);
      expect(find.text('More like Kai'), findsNothing);
      expect(repo.similarCalls, 1);

      await settleToasts(tester);
    });

    testWidgets('an unfollow shows "Unfollowed Kai!" and never calls similarTo', (tester) async {
      repo.similar = [_creator('a', 'Lia')];
      await pumpApp(tester);

      showFollowOutcomeToast(context, _outcome(follow: false));
      await tester.pump();
      await tester.pump();

      expect(find.text('Unfollowed Kai!'), findsOneWidget);
      expect(find.text('More like Kai'), findsNothing);
      expect(repo.similarCalls, 0);

      await settleToasts(tester);
    });

    testWidgets('no similar creators means no action, and the offer is still there for the next follow', (
      tester,
    ) async {
      repo.similar = const <DirectoryCreator>[];
      await pumpApp(tester);

      showFollowOutcomeToast(context, _outcome(follow: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('Followed Kai!'), findsOneWidget);
      expect(find.text('More like Kai'), findsNothing);
      expect(repo.similarCalls, 1);
      await settleToasts(tester);

      repo.similar = [_creator('a', 'Lia')];
      showFollowOutcomeToast(context, _outcome(follow: true));
      await tester.pump();
      await tester.pump();

      expect(repo.similarCalls, 2);
      expect(find.text('More like Kai'), findsOneWidget);
      await settleToasts(tester);
    });
  });
}
