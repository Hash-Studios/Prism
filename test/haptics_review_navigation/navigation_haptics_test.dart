import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/moods/biz/moods_cubit.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/empty_mood_repository.dart';

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _MockPersonalizedFeedBloc extends MockBloc<PersonalizedFeedEvent, PersonalizedFeedState>
    implements PersonalizedFeedBloc {}

class _MockTrendingBloc extends MockBloc<TrendingEvent, TrendingState> implements TrendingBloc {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
  final List<String> haptics = <String>[];

  setUp(() {
    PrismHaptics.enabled = true;
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, (
      MethodCall call,
    ) async {
      haptics.add(call.arguments! as String);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, null);
  });

  Future<void> pumpFeed(WidgetTester tester, {VoidCallback? onTuneTap}) async {
    final _MockPersonalizedFeedBloc bloc = _MockPersonalizedFeedBloc();
    final PersonalizedFeedState loadedEmpty = PersonalizedFeedState.initial().copyWith(
      status: LoadStatus.success,
      hasMore: false,
    );
    whenListen(bloc, const Stream<PersonalizedFeedState>.empty(), initialState: loadedEmpty);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<PersonalizedFeedBloc>(bloc);
    final _MockTrendingBloc trendingBloc = _MockTrendingBloc();
    when(() => trendingBloc.state).thenReturn(TrendingState.initial());
    when(trendingBloc.close).thenAnswer((_) async {});
    getIt.registerSingleton<TrendingBloc>(trendingBloc);
    getIt.registerSingleton<MoodsCubit>(MoodsCubit(const EmptyMoodRepository()));
    final _MockWotdBloc wotdBloc = _MockWotdBloc();
    when(() => wotdBloc.state).thenReturn(WotdState.initial());
    final _MockNotificationsBloc notificationsBloc = _MockNotificationsBloc();
    when(() => notificationsBloc.state).thenReturn(InAppNotificationsState.initial());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<WotdBloc>.value(value: wotdBloc),
          BlocProvider<InAppNotificationsBloc>.value(value: notificationsBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(body: PersonalizedFeedScreen(onTuneTap: onTuneTap)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('feed tab pointer and semantics taps share the tune callback and haptic', (tester) async {
    int tuned = 0;
    await pumpFeed(tester, onTuneTap: () => tuned++);

    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.tap(find.widgetWithText(Tab, 'For you'));
    await tester.pump();

    expect(tuned, 1);
    expect(haptics, <String>['tap']);
    tester.semantics.tap(find.semantics.byLabel(RegExp('For you')));
    await tester.pump();
    expect(tuned, 2);
    expect(haptics, <String>['tap', 'tap']);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('choosing another feed tab plays the selection haptic', (tester) async {
    await pumpFeed(tester, onTuneTap: () {});

    await tester.tap(find.widgetWithText(Tab, 'Latest'));
    await tester.pump();

    expect(haptics, <String>['selection']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the For you tab does nothing and plays no haptic when no callback is supplied', (tester) async {
    await pumpFeed(tester);

    await tester.tap(find.widgetWithText(Tab, 'For you'));
    await tester.pump();

    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    expect(haptics, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
