import 'dart:async';

import 'package:Prism/auth/badge_model.dart' as model;
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/features/badges/views/widgets/profile_badge_row.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

class _MockProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _MockProfileRepository extends Mock implements PublicProfileRepository {}

PublicProfileEntity _profile(List<String> badges, {String id = 'u1'}) => PublicProfileEntity(
  id: id,
  name: 'Creator',
  email: 'user@example.com',
  username: 'creator',
  profilePhoto: '',
  bio: 'My wallpaper collection',
  followers: const <String>[],
  following: const <String>[],
  links: const <String, String>{},
  coverPhoto: '',
  badges: badges,
);

void main() {
  late StreamController<PublicProfileEntity?> profiles;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = FontLoader('Proxima Nova')..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'));
    await fonts.load();
  });

  setUp(() {
    profiles = StreamController<PublicProfileEntity?>.broadcast();
    final repository = _MockProfileRepository();
    when(() => repository.watchProfile(any())).thenAnswer((_) => profiles.stream);
    getIt.registerSingleton<PublicProfileRepository>(repository);
    getIt.registerFactory<PublicProfileBloc>(() {
      final bloc = _MockProfileBloc();
      when(
        () => bloc.state,
      ).thenReturn(PublicProfileState.initial().copyWith(email: 'user@example.com', status: LoadStatus.success));
      return bloc;
    });
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = profileUser(profilePhoto: '', username: 'creator', bio: 'My wallpaper collection');
  });

  tearDown(() async {
    await profiles.close();
    app_state.prismUser = createGuestPrismUser();
    await getIt.reset();
    AnalyticsRuntime.reset();
  });

  Future<void> pumpProfile(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Proxima Nova'),
        home: const ProfileScreen(),
      ),
    );
    await tester.pump();
  }

  for (final width in <double>[390, 360]) {
    for (final hasLinks in <bool>[false, true]) {
      testWidgets('all earned badges fit the $width profile header, links: $hasLinks', (tester) async {
        app_state.prismUser.badges = <model.Badge>[
          for (final info in badgeCatalog)
            model.Badge(id: info.id, name: info.name, description: '', awardedAt: '', imageUrl: '', color: '', url: ''),
        ];
        if (hasLinks) app_state.prismUser.links = <String, String>{'github': 'https://example.com'};

        await pumpProfile(tester, width: width);

        expect(tester.takeException(), isNull);
        expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, hasLength(badgeCatalog.length));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('an open own profile updates its server-awarded badges', (tester) async {
    await pumpProfile(tester);
    expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, isEmpty);

    profiles.add(_profile(const <String>['week_warrior']));
    await tester.pump();

    expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, <String>['week_warrior']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an own profile ignores badge snapshots belonging to another matching user', (tester) async {
    app_state.prismUser.badges = <model.Badge>[
      model.Badge(id: 'collector', name: 'Collector', description: '', awardedAt: '', imageUrl: '', color: '', url: ''),
    ];
    await pumpProfile(tester);

    profiles.add(_profile(const <String>['creator'], id: 'another-user'));
    await tester.pump();
    expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, <String>['collector']);

    profiles.add(_profile(const <String>['week_warrior']));
    await tester.pump();
    expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, <String>['week_warrior']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
