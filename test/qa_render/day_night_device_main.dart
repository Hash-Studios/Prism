// Device QA entry point for Day and night: a fake signed-in Pro user and a real pair. iOS publishes it for the Shortcuts
// action at launch. Android starts with the pair off and auto-rotate on, so the switch shows the mode confirm, then
// starts the real async_wallpaper daily schedule.
// Run: fvm flutter run -t test/qa_render/day_night_device_main.dart -d <device>
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/data/repositories/day_night_repository_impl.dart';
import 'package:Prism/features/day_night/day_night_support.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/pages/day_night_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';
import '../support/in_memory_local_store.dart';

const DayNightWall _day = DayNightWall(
  id: 'qa-day',
  source: WallpaperSource.prism,
  fullUrl: 'https://img.prismwalls.com/previews/4f2935aee606c4a151ce2a5cd20570e729bfbf38b0b40fbeea65bb1b193c1730.img',
  thumbnailUrl:
      'https://img.prismwalls.com/previews/4f2935aee606c4a151ce2a5cd20570e729bfbf38b0b40fbeea65bb1b193c1730.img',
);
const DayNightWall _night = DayNightWall(
  id: 'qa-night',
  source: WallpaperSource.prism,
  fullUrl: 'https://img.prismwalls.com/previews/17178b61fa1febf9269a5ebab8fbffd627e0ba2211edc7262516d990e60f089a.img',
  thumbnailUrl:
      'https://img.prismwalls.com/previews/17178b61fa1febf9269a5ebab8fbffd627e0ba2211edc7262516d990e60f089a.img',
);

class _QaRouter extends Mock implements StackRouter {}

class _QaAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _QaAnalytics extends FakeAppAnalytics {}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AnalyticsRuntime.instance = _QaAnalytics();
  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'qa-user'
    ..name = 'Mira'
    ..premium = true
    ..loggedIn = true;
  dayNightSupportedOverride = true;
  final _QaRouter router = _QaRouter();
  registerFallbackValue(AutoRotateRoute());
  when(() => router.push(any())).thenAnswer((_) async => null);
  final bool android = defaultTargetPlatform == TargetPlatform.android;
  final _QaAutoRotateBloc autoRotate = _QaAutoRotateBloc();
  when(() => autoRotate.state).thenReturn(
    AutoRotateState.initial().copyWith(loaded: true, isPro: true, config: AutoRotateConfig(enabled: android)),
  );
  final DayNightBloc bloc = DayNightBloc(DayNightRepositoryImpl(SettingsLocalDataSource(InMemoryLocalStore())))
    ..add(const DayNightEvent.entitlementChanged(isPro: true, userId: 'qa-user'))
    ..add(const DayNightEvent.wallPicked(DayNightSlot.day, _day))
    ..add(const DayNightEvent.wallPicked(DayNightSlot.night, _night));
  if (!android) bloc.add(const DayNightEvent.toggled(true));
  runApp(
    StackRouterScope(
      controller: router,
      stateHash: 0,
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AutoRotateBloc>.value(value: autoRotate),
          BlocProvider<DayNightBloc>.value(value: bloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: kLightTheme,
          darkTheme: kDarkTheme,
          home: const DayNightScreen(),
        ),
      ),
    ),
  );
}
