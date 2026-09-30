import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_header.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

const PublicProfileEntity _profile = PublicProfileEntity(
  id: 'u1',
  name: 'Ana Rivera',
  email: 'ana@example.com',
  username: 'ana_rivera',
  profilePhoto: '',
  bio: 'Makes calm gradients.',
  followers: <String>['a@example.com', 'b@example.com'],
  following: <String>['c@example.com'],
  links: <String, String>{'github': 'https://github.com/ana', 'twitter': ''},
  coverPhoto: '',
);

void main() {
  late _MockPublicProfileBloc bloc;
  final List<String> taps = <String>[];

  setUp(() {
    bloc = _MockPublicProfileBloc();
    taps.clear();
    when(() => bloc.state).thenReturn(PublicProfileState.initial());
  });

  Future<void> pumpHeader(
    WidgetTester tester, {
    bool ownProfile = false,
    bool following = false,
    bool isPro = false,
    PublicProfileEntity profile = _profile,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: SingleChildScrollView(
              child: ProfileHeader(
                profile: profile,
                ownProfile: ownProfile,
                following: following,
                isPro: isPro,
                onEdit: () => taps.add('edit'),
                onShare: () => taps.add('share'),
                onToggleFollow: () => taps.add('follow'),
                onOpenFollowers: () => taps.add('followers'),
                onOpenFollowing: () => taps.add('following'),
                onOpenPosts: () => taps.add('posts'),
                onOpenLink: (key, value) => taps.add('link:$key:$value'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows name, username, bio and the three stats', (tester) async {
    await pumpHeader(tester);

    expect(find.text('Ana Rivera'), findsOneWidget);
    expect(find.text('@ana_rivera'), findsOneWidget);
    expect(find.text('Makes calm gradients.'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('posts count waits for the walls, then shows a plus while more pages exist', (tester) async {
    await pumpHeader(tester);
    expect(find.text('–'), findsOneWidget);

    when(() => bloc.state).thenReturn(
      PublicProfileState.initial().copyWith(
        email: _profile.email,
        status: LoadStatus.success,
        hasMoreWalls: true,
        walls: <PublicProfileWallEntity>[
          const PublicProfileWallEntity(id: 'w1', wallpaperUrl: 'https://example.com/1'),
          const PublicProfileWallEntity(id: 'w2', wallpaperUrl: 'https://example.com/2'),
        ],
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHeader(tester);

    expect(find.text('2+'), findsOneWidget);
  });

  testWidgets('each stat is a labelled button that opens its list', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpHeader(tester, ownProfile: true);

      await tester.tap(find.bySemanticsLabel('Followers'));
      await tester.tap(find.bySemanticsLabel('Following'));
      await tester.tap(find.bySemanticsLabel('Posts'));

      expect(taps, <String>['followers', 'following', 'posts']);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('another profile keeps Followers actionable but hides Following action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpHeader(tester);

      expect(find.bySemanticsLabel('Followers'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Following')), matchesSemantics(label: 'Following', value: '1'));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Followers')),
        matchesSemantics(label: 'Followers', value: '2', isButton: true, hasTapAction: true),
      );
      expect(find.text('Following'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Followers'));
      expect(taps, <String>['followers']);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('own profile has Edit profile and Share profile, and no Follow button', (tester) async {
    await pumpHeader(tester, ownProfile: true, isPro: true);

    expect(find.text('Follow'), findsNothing);
    expect(find.text('Pro'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.tap(find.byTooltip('Share profile'));
    expect(taps, <String>['edit', 'share']);
  });

  testWidgets('another profile shows Follow, then Following once followed', (tester) async {
    await pumpHeader(tester);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Pro'), findsNothing);
    await tester.tap(find.text('Follow'));
    expect(taps, <String>['follow']);

    await pumpHeader(tester, following: true);
    await tester.pump(const Duration(milliseconds: 300));
    // "Following" is both the stat label and the button label.
    expect(find.text('Following'), findsNWidgets(2));
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('shows one button per filled link, named by its type, and opens it', (tester) async {
    await pumpHeader(tester);

    expect(find.byTooltip('Github'), findsOneWidget);
    expect(find.byTooltip('Twitter'), findsNothing);
    await tester.tap(find.byTooltip('Github'));
    expect(taps, <String>['link:github:https://github.com/ana']);
  });

  testWidgets('a long name and bio on a narrow screen with large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const PublicProfileEntity long = PublicProfileEntity(
      id: 'u1',
      name: 'Alexandria Montgomery-Featherstonehaugh the Third',
      email: 'a@example.com',
      username: 'alexandria_montgomery_featherstonehaugh',
      profilePhoto: '',
      bio: 'A very long bio that keeps going and going so that it has to wrap over several lines on a small screen.',
      followers: <String>[],
      following: <String>[],
      links: <String, String>{'github': 'https://github.com/a', 'twitter': 'https://twitter.com/a'},
      coverPhoto: '',
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 1600), textScaler: TextScaler.linear(1.5)),
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider<PublicProfileBloc>.value(
              value: bloc,
              child: SingleChildScrollView(
                child: ProfileHeader(
                  profile: long,
                  ownProfile: true,
                  following: false,
                  isPro: true,
                  onEdit: () {},
                  onShare: () {},
                  onToggleFollow: () {},
                  onOpenFollowers: () {},
                  onOpenFollowing: () {},
                  onOpenPosts: () {},
                  onOpenLink: (key, value) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Edit profile'), findsOneWidget);
  });
}
