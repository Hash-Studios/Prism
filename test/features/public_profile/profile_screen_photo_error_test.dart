import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/profile_user_fixture.dart';

class _Cache extends Mock implements BaseCacheManager {}

class _Bloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

class _Repository extends Mock implements PublicProfileRepository {}

void main() {
  late BaseCacheManager previous;
  late Directory directory;
  late _Cache cache;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('profile-photo-error-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    previous = CachedNetworkImageProvider.defaultCacheManager;
  });
  tearDownAll(() async {
    await previous.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await directory.delete(recursive: true);
  });
  setUp(() {
    cache = _Cache();
    CachedNetworkImageProvider.defaultCacheManager = cache;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    final bloc = _Bloc();
    whenListen(
      bloc,
      const Stream<PublicProfileState>.empty(),
      initialState: PublicProfileState.initial().copyWith(email: 'user@example.com', status: LoadStatus.success),
    );
    final repo = _Repository();
    when(() => repo.watchProfile(any())).thenAnswer((_) => const Stream<PublicProfileEntity?>.empty());
    getIt.registerFactory<PublicProfileBloc>(() => bloc);
    getIt.registerSingleton<PublicProfileRepository>(repo);
    getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial({}));
  });
  tearDown(() async {
    CachedNetworkImageProvider.defaultCacheManager = previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    AnalyticsRuntime.reset();
    app_state.prismUser = constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpProfile(WidgetTester tester, String photo) async {
    app_state.prismUser = profileUser(id: 'me', profilePhoto: photo);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a profile photo that fails to load shows the default avatar', (tester) async {
    when(
      () => cache.getFileStream(any(), withProgress: any(named: 'withProgress')),
    ).thenAnswer((_) => Stream<FileResponse>.error(const HttpExceptionWithStatus(404, 'fixture avatar missing')));

    await pumpProfile(tester, 'https://example.test/avatar.jpg');

    expect(find.descendant(of: find.byType(CachedNetworkImage), matching: find.byIcon(JamIcons.user)), findsOneWidget);
    expect(find.byType(Placeholder), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty profile photo shows the default avatar', (tester) async {
    await pumpProfile(tester, '');

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(JamIcons.user), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
