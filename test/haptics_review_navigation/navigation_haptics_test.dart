import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

class _MockPersonalizedFeedBloc extends MockBloc<PersonalizedFeedEvent, PersonalizedFeedState>
    implements PersonalizedFeedBloc {}

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

  testWidgets('logo pointer and semantics actions share the tap callback and haptic', (tester) async {
    final _MockNotificationsBloc bloc = _MockNotificationsBloc();
    when(() => bloc.state).thenReturn(InAppNotificationsState.initial());
    int tapped = 0;
    await tester.pumpWidget(
      BlocProvider<InAppNotificationsBloc>.value(
        value: bloc,
        child: MaterialApp(
          home: Scaffold(appBar: PrismTopAppBar(onLogoTap: () => tapped++)),
        ),
      ),
    );

    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Feed settings'));
    await tester.pump();

    expect(tapped, 1);
    expect(haptics, <String>['tap']);
    tester.semantics.tap(find.semantics.byLabel('Feed settings'));
    await tester.pump();
    expect(tapped, 2);
    expect(haptics, <String>['tap', 'tap']);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('feed tune action is disabled when no callback is supplied', (tester) async {
    final _MockPersonalizedFeedBloc bloc = _MockPersonalizedFeedBloc();
    final PersonalizedFeedState loadedEmpty = PersonalizedFeedState.initial().copyWith(
      status: LoadStatus.success,
      hasMore: false,
    );
    whenListen(bloc, const Stream<PersonalizedFeedState>.empty(), initialState: loadedEmpty);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<PersonalizedFeedBloc>(bloc);
    final _MockWotdBloc wotdBloc = _MockWotdBloc();
    when(() => wotdBloc.state).thenReturn(WotdState.initial());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
    });

    await tester.pumpWidget(
      BlocProvider<WotdBloc>.value(
        value: wotdBloc,
        child: const MaterialApp(home: Scaffold(body: PersonalizedFeedScreen())),
      ),
    );
    await tester.pump();

    final IconButton tuneButton = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Tune your feed'), matching: find.byType(IconButton)),
    );
    expect(tuneButton.onPressed, isNull);
    expect(haptics, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('feed tune action invokes its callback and haptic when supplied', (tester) async {
    final _MockPersonalizedFeedBloc bloc = _MockPersonalizedFeedBloc();
    final PersonalizedFeedState loadedEmpty = PersonalizedFeedState.initial().copyWith(
      status: LoadStatus.success,
      hasMore: false,
    );
    whenListen(bloc, const Stream<PersonalizedFeedState>.empty(), initialState: loadedEmpty);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<PersonalizedFeedBloc>(bloc);
    final _MockWotdBloc wotdBloc = _MockWotdBloc();
    when(() => wotdBloc.state).thenReturn(WotdState.initial());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
    });
    int tuned = 0;

    await tester.pumpWidget(
      BlocProvider<WotdBloc>.value(
        value: wotdBloc,
        child: MaterialApp(
          home: Scaffold(body: PersonalizedFeedScreen(onTuneTap: () => tuned++)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Tune your feed'));
    await tester.pump();

    expect(tuned, 1);
    expect(haptics, <String>['tap']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
