import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _MockPublicProfileRepository extends Mock implements PublicProfileRepository {}

class _MockUserBlockRepository extends Mock implements UserBlockRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> haptics = <String>[];

  setUp(() {
    PrismHaptics.enabled = true;
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      hapticsChannel,
      (MethodCall call) async => haptics.add(call.arguments! as String),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpProfile(WidgetTester tester, {required bool following}) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final viewer = app_constants.createGuestPrismUser()
      ..loggedIn = true
      ..email = 'viewer@example.com';
    app_state.prismUser = viewer;
    final _MockPublicProfileBloc bloc = _MockPublicProfileBloc();
    whenListen(bloc, const Stream<PublicProfileState>.empty(), initialState: PublicProfileState.initial());
    when(() => bloc.close()).thenAnswer((_) async {});
    final _MockPublicProfileRepository profileRepository = _MockPublicProfileRepository();
    when(() => profileRepository.watchProfile('creator@example.com')).thenAnswer(
      (_) => Stream<PublicProfileEntity?>.value(
        PublicProfileEntity(
          id: 'creator',
          name: 'Creator',
          email: 'creator@example.com',
          username: 'creator',
          profilePhoto: '',
          bio: '',
          followers: following ? <String>['viewer@example.com'] : <String>[],
          following: const <String>[],
          links: const <String, String>{},
          coverPhoto: '',
        ),
      ),
    );
    final _MockUserBlockRepository blockRepository = _MockUserBlockRepository();
    when(() => blockRepository.watchBlockedCreatorEmails()).thenAnswer((_) => Stream<Set<String>>.value(<String>{}));
    getIt.registerSingleton<PublicProfileBloc>(bloc);
    getIt.registerSingleton<PublicProfileRepository>(profileRepository);
    getIt.registerSingleton<UserBlockRepository>(blockRepository);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen(profileIdentifier: 'creator@example.com')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('unfollow request emits one tap haptic, not a success outcome', (tester) async {
    await pumpProfile(tester, following: true);
    await tester.tap(find.byIcon(JamIcons.user_remove));
    await tester.pump();

    expect(haptics, <String>['tap']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('follow request emits one tap haptic, not a success outcome', (tester) async {
    await pumpProfile(tester, following: false);
    await tester.tap(find.byIcon(JamIcons.user_plus));
    await tester.pump();

    expect(haptics, <String>['tap']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
