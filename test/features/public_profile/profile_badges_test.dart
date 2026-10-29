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
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/profile_user_fixture.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

class _MockProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _MockProfileRepository extends Mock implements PublicProfileRepository {}

PublicProfileEntity _profile(List<String> badges, {String id = 'u1'}) => PublicProfileEntity(
  id: id,
  name: 'Creator',
  email: '',
  username: 'creator',
  profilePhoto: '',
  bio: 'My wallpaper collection',
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
      ).thenReturn(PublicProfileState.initial().copyWith(profileId: 'user-uid', status: LoadStatus.success));
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

  Future<void> pumpProfile(WidgetTester tester, {double width = 390, String? identifier}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: ThemeData(fontFamily: 'Proxima Nova'),
        home: ProfileScreen(key: ValueKey(identifier), profileIdentifier: identifier),
      ),
    );
    await tester.pump();
  }

  testWidgets('Stats entry follows real own UID and username profile resolution', (tester) async {
    for (final identifier in <String?>[null, 'u1', 'creator']) {
      await pumpProfile(tester, identifier: identifier);
      expect(find.text('Stats'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    final blocks = FakeUserBlockRepository.pending()..completeInitial({});
    getIt.registerSingleton<UserBlockRepository>(blocks);
    await pumpProfile(tester, identifier: 'other-user');
    profiles.add(_profile([], id: 'other-user'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProfileBadgeRow), findsOneWidget);
    expect(find.text('Stats'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guests have a sign-in prompt without the private Stats entry', (tester) async {
    app_state.prismUser = createGuestPrismUser();
    await pumpProfile(tester);
    expect(find.text('Stats'), findsNothing);
    expect(find.textContaining('Sign in'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[390, 360]) {
    for (final hasLinks in <bool>[false, true]) {
      testWidgets('all earned badges fit the $width profile header, links: $hasLinks', (tester) async {
        app_state.prismUser.badges = <model.Badge>[
          for (final info in badgeCatalog)
            model.Badge(
              id: info.id,
              name: info.name(_l10n),
              description: info.description(_l10n),
              awardedAt: '',
              imageUrl: '',
              color: '',
              url: '',
            ),
        ];
        if (hasLinks) app_state.prismUser.links = <String, String>{'github': 'https://example.com'};

        await pumpProfile(tester, width: width);

        expect(tester.takeException(), isNull);
        expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, hasLength(badgeCatalog.length));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('an open own profile renders session-owned badges after a public graph update', (tester) async {
    await pumpProfile(tester);
    expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, isEmpty);

    app_state.prismUser.badges = <model.Badge>[
      model.Badge(
        id: 'week_warrior',
        name: 'Week Warrior',
        description: '',
        awardedAt: '',
        imageUrl: '',
        color: '',
        url: '',
      ),
    ];
    profiles.add(_profile(const <String>['creator'], id: 'user-uid'));
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

    profiles.add(_profile(const <String>['week_warrior'], id: 'user-uid'));
    await tester.pump();
    expect(tester.widget<ProfileBadgeRow>(find.byType(ProfileBadgeRow)).badgeIds, <String>['collector']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
