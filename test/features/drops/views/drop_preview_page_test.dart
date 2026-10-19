import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/drops/drops.dart';
import 'package:Prism/features/drops/views/pages/drop_preview_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../drop_fixtures.dart';

class _MockDropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

void main() {
  late _MockDropsBloc bloc;
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(const DropsEvent.started());
    registerFallbackValue(WallpaperDetailRoute());
  });

  setUp(() {
    bloc = _MockDropsBloc();
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerFactory<DropsBloc>(() => bloc);
    CoinsService.instance.balanceNotifier.value = 100;
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  const DropUnlock ownedA = DropUnlock(wallId: 'A', weekKey: '2026-W42', url: 'https://full.test/A.jpg');
  const DropUnlock ownedB = DropUnlock(wallId: 'B', weekKey: '2026-W42', url: 'https://full.test/B.jpg');

  DropsState loaded(DropEntity? drop, {Map<String, DropUnlock> unlocked = const {}}) =>
      DropsState(status: LoadStatus.success, now: DateTime.now(), drop: drop, unlocked: unlocked);

  Future<void> openPreview(
    WidgetTester tester,
    DropsState state, {
    String wallId = 'A',
    StreamController<DropsState>? states,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(bloc, states?.stream ?? const Stream<DropsState>.empty(), initialState: state);
    await tester.pumpWidget(
      BlocProvider<DropsBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          builder: (context, child) => StackRouterScope(controller: router, stateHash: 0, child: child!),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openDropPreview(context, wall: dropWall(wallId)),
              child: const Text('launch'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('launch'));
    await tester.pumpAndSettle();
  }

  group('DropPreviewPage', () {
    testWidgets('opens at the tapped wall with its serial and title', (tester) async {
      await openPreview(tester, loaded(dropEntity()), wallId: 'C');

      expect(find.text('03 / 04'), findsOneWidget);
      expect(find.text('Wall C'), findsOneWidget);
      expect(find.text('by Ana'), findsOneWidget);
      expect(find.text('Lock screen'), findsOneWidget);
      expect(find.text('Home screen'), findsOneWidget);
    });

    testWidgets('does nothing when there is no Drop', (tester) async {
      await openPreview(tester, loaded(null));

      expect(find.byType(DropPreviewPage), findsNothing);
    });

    testWidgets('swiping changes the serial and the wall the buy button targets', (tester) async {
      await openPreview(tester, loaded(dropEntity()));
      expect(find.text('01 / 04'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('02 / 04'), findsOneWidget);
      expect(find.text('Wall B'), findsOneWidget);

      await tester.tap(find.text('Unlock for 30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlock this wall for 30'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const DropsEvent.unlockRequested(wallId: 'B'))).called(1);
    });

    testWidgets('a live Drop shows the price and the countdown, a Pro user sees the Pro tag', (tester) async {
      app_state.prismUser.premium = true;
      await openPreview(tester, loaded(dropEntity()));

      expect(find.text('Unlock for 15'), findsOneWidget);
      expect(find.text('Pro price'), findsOneWidget);
      expect(find.textContaining('Ends in 5d'), findsOneWidget);
      expect(find.text('Last call'), findsNothing);
    });

    testWidgets('the last day says Last call', (tester) async {
      await openPreview(tester, loaded(dropEntity(endsIn: const Duration(hours: 5, minutes: 30))));

      expect(find.text('Last call'), findsOneWidget);
      expect(find.textContaining('Ends in 5h'), findsOneWidget);
    });

    testWidgets('an ended Drop has no buy button', (tester) async {
      await openPreview(tester, loaded(dropEntity(endsIn: const Duration(minutes: -5))));

      expect(find.text('This Drop has ended'), findsOneWidget);
      expect(find.textContaining('Unlock for'), findsNothing);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('an owned wall shows Owned and Open, and Open opens the wall', (tester) async {
      await openPreview(tester, loaded(dropEntity(), unlocked: {'B': ownedB}), wallId: 'B');

      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.textContaining('Unlock for'), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pump();

      final route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
      expect(route.args!.entity!.id, 'B');
    });

    testWidgets('the bar switches to Open when the wall is unlocked', (tester) async {
      final DropsState before = loaded(dropEntity());
      final StreamController<DropsState> states = StreamController<DropsState>.broadcast();
      addTearDown(states.close);
      await openPreview(tester, before, states: states);
      expect(find.text('Unlock for 30'), findsOneWidget);

      states.add(before.copyWith(unlocked: {'A': ownedA}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Open'), findsOneWidget);
      expect(find.textContaining('Unlock for'), findsNothing);
      expect(find.text('Owned'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the close button has a tooltip and closes the page', (tester) async {
      await openPreview(tester, loaded(dropEntity()));

      expect(find.byTooltip('Close preview'), findsOneWidget);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();

      expect(find.byType(DropPreviewPage), findsNothing);
    });

    testWidgets('has no save, set, share or download action', (tester) async {
      await openPreview(tester, loaded(dropEntity(), unlocked: {'B': ownedB}));
      final RegExp banned = RegExp(r'\b(download|set|save|share)\b', caseSensitive: false);

      final List<String> labels = <String>[
        for (final Text t in tester.widgetList<Text>(find.byType(Text))) t.data ?? t.textSpan?.toPlainText() ?? '',
        for (final Tooltip t in tester.widgetList<Tooltip>(find.byType(Tooltip))) t.message ?? '',
        for (final Semantics s in tester.widgetList<Semantics>(find.byType(Semantics)))
          '${s.properties.label ?? ''} ${s.properties.tooltip ?? ''}',
      ];

      expect(labels.where(banned.hasMatch), isEmpty);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
