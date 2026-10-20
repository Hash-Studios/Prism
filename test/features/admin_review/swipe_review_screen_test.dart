import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/views/pages/swipe_review_screen.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_wallpaper_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockReviewBatchBloc extends MockBloc<ReviewBatchEvent, ReviewBatchState> implements ReviewBatchBloc {}

class _FakeEvent extends Fake implements ReviewBatchEvent {}

FirestoreDocument _wall(
  String id,
  String title, {
  String? origin,
  Map<String, dynamic>? depth,
  Map<String, dynamic>? moderation,
}) => FirestoreDocument(id, <String, dynamic>{
  'origin': ?origin,
  'depth': ?depth,
  'moderation': ?moderation,
  'title': title,
  'category': 'Nature',
  'by': 'Ann',
  'wallpaper_thumb': 'https://example.com/$id.jpg',
});

void main() {
  late _MockReviewBatchBloc bloc;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() {
    bloc = _MockReviewBatchBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    GetIt.I.registerSingleton<ReviewBatchBloc>(bloc);
  });

  tearDown(() => GetIt.I.unregister<ReviewBatchBloc>());

  Future<void> pump(WidgetTester tester, ReviewBatchState state) async {
    whenListen(bloc, const Stream<ReviewBatchState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const SwipeReviewScreen(),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads the batch on open and shows a card skeleton while loading', (tester) async {
    await pump(tester, const ReviewBatchState(status: ReviewBatchStatus.loading));

    verify(() => bloc.add(any(that: isA<ReviewBatchLoadRequested>()))).called(1);
    expect(find.text('Swipe review'), findsOneWidget);
    expect(find.byType(PrismSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an empty queue shows Glint with a refresh that reloads', (tester) async {
    await pump(tester, const ReviewBatchState(status: ReviewBatchStatus.loaded));

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('0/0'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<ReviewBatchLoadRequested>()))).called(2);
  });

  testWidgets('shows the current wallpaper, the counter and four neutral actions', (tester) async {
    await pump(
      tester,
      ReviewBatchState(
        status: ReviewBatchStatus.loaded,
        walls: <FirestoreDocument>[_wall('a', 'Sunset'), _wall('b', 'Forest')],
        totalPending: 2,
      ),
    );

    expect(find.byType(SwipeWallpaperCard), findsNWidgets(2));
    expect(find.text('Sunset'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    for (final String label in <String>['Undo', 'View', 'Skip', 'List']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Swipe right to approve, left to reject'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<ReviewBatchSwipeSkipped>()))).called(1);
  });

  testWidgets('Undo is disabled until there is something to undo', (tester) async {
    await pump(
      tester,
      ReviewBatchState(status: ReviewBatchStatus.loaded, walls: <FirestoreDocument>[_wall('a', 'Sunset')]),
    );

    await tester.tap(find.text('Undo'), warnIfMissed: false);
    await tester.pump();
    verifyNever(() => bloc.add(any(that: isA<ReviewBatchUndoRequested>())));
  });

  testWidgets('bottom bar actions expose tap semantics only while enabled', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pump(
      tester,
      ReviewBatchState(status: ReviewBatchStatus.loaded, walls: <FirestoreDocument>[_wall('a', 'Sunset')]),
    );

    final SemanticsNode skip = tester.getSemantics(find.bySemanticsLabel('Skip'));
    expect(skip.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: skip.id),
    );
    await tester.pump();
    verify(() => bloc.add(any(that: isA<ReviewBatchSwipeSkipped>()))).called(1);

    final SemanticsNode undo = tester.getSemantics(find.bySemanticsLabel('Undo'));
    expect(undo.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('a swipe to the right approves and a swipe to the left rejects', (tester) async {
    await pump(
      tester,
      ReviewBatchState(
        status: ReviewBatchStatus.loaded,
        walls: <FirestoreDocument>[_wall('a', 'Sunset'), _wall('b', 'Forest')],
      ),
    );

    await tester.drag(find.text('Sunset'), const Offset(300, 0), warnIfMissed: false);
    await tester.pumpAndSettle();
    verify(() => bloc.add(any(that: isA<ReviewBatchSwipeApproved>()))).called(1);

    await tester.drag(find.text('Sunset'), const Offset(-300, 0), warnIfMissed: false);
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(any(that: isA<ReviewBatchSwipeRejected>())));
    await tester.tap(find.text('Watermark'));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrismButton, 'Reject wallpaper'));
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(
        any(
          that: isA<ReviewBatchSwipeRejected>().having(
            (e) => e.reason,
            'reason',
            'The image has a watermark. Upload a version without it.',
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('cancelling the reason sheet snaps the card back without rejecting', (tester) async {
    await pump(
      tester,
      ReviewBatchState(status: ReviewBatchStatus.loaded, walls: <FirestoreDocument>[_wall('a', 'Sunset')]),
    );

    await tester.drag(find.text('Sunset'), const Offset(-300, 0), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrismButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any(that: isA<ReviewBatchSwipeRejected>())));
    expect(find.text('Sunset'), findsOneWidget);
  });

  testWidgets('the approve stamp appears while dragging right', (tester) async {
    await pump(
      tester,
      ReviewBatchState(status: ReviewBatchStatus.loaded, walls: <FirestoreDocument>[_wall('a', 'Sunset')]),
    );

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('Sunset')));
    for (int i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    expect(find.text('Approve'), findsOneWidget);
    for (int i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    expect(find.text('Reject'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  group('moderation signals', () {
    testWidgets('pills sit under the depth pill, most serious first, and open the sheet', (tester) async {
      await pump(
        tester,
        ReviewBatchState(
          status: ReviewBatchStatus.loaded,
          walls: <FirestoreDocument>[
            _wall(
              'a',
              'Sunset',
              moderation: <String, dynamic>{
                'v': 1,
                'flags': <String>['duplicate', 'web_match', 'text'],
                'duplicate': <String, dynamic>{'wallId': 'w9', 'similarity': 0.96, 'thumb': ''},
                'web': <Map<String, String>>[
                  <String, String>{'url': 'https://backdrops.app/x', 'host': 'backdrops.app'},
                ],
                'words': <String>['@someone', 'backdrops'],
              },
            ),
          ],
        ),
      );

      final double depthY = tester.getTopLeft(find.text('Depth: Not checked')).dy;
      final double duplicateY = tester.getTopLeft(find.text('Looks like a Prism wall · 96%')).dy;
      final double webY = tester.getTopLeft(find.text('Found on backdrops.app')).dy;
      final double textY = tester.getTopLeft(find.text('Text: @someone backdrops')).dy;
      expect(<double>[
        depthY,
        duplicateY,
        webY,
        textY,
      ], orderedEquals(<double>[depthY, duplicateY, webY, textY]..sort()));

      await tester.tap(find.text('Found on backdrops.app'));
      await tester.pumpAndSettle();
      expect(find.text('Review signals'), findsOneWidget);
    });

    testWidgets('no pills for a wall that was not checked or came back clear', (tester) async {
      await pump(
        tester,
        ReviewBatchState(
          status: ReviewBatchStatus.loaded,
          walls: <FirestoreDocument>[
            _wall('a', 'Sunset', moderation: <String, dynamic>{'v': 1, 'flags': <String>[]}),
          ],
        ),
      );

      expect(find.text('Depth: Not checked'), findsOneWidget);
      expect(find.textContaining('Text:'), findsNothing);
      expect(find.textContaining('Found on'), findsNothing);
      expect(find.textContaining('Prism wall'), findsNothing);
    });
  });

  group('depth', () {
    for (final (Map<String, dynamic>? depth, String label) in <(Map<String, dynamic>?, String)>[
      (<String, dynamic>{'tier': 'auto'}, 'Depth: Auto'),
      (<String, dynamic>{'tier': 'menu'}, 'Depth: Menu'),
      (<String, dynamic>{'tier': 'none'}, 'Depth: None'),
      (null, 'Depth: Not checked'),
    ]) {
      testWidgets('the card shows "$label" for what the detector decided', (tester) async {
        await pump(
          tester,
          ReviewBatchState(
            status: ReviewBatchStatus.loaded,
            walls: <FirestoreDocument>[_wall('a', 'Sunset', depth: depth)],
          ),
        );

        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('a tap opens Auto, Menu and None, and the pick goes to the bloc', (tester) async {
      await pump(
        tester,
        ReviewBatchState(
          status: ReviewBatchStatus.loaded,
          walls: <FirestoreDocument>[
            _wall('a', 'Sunset', depth: <String, dynamic>{'tier': 'none'}),
          ],
        ),
      );

      await tester.tap(find.byTooltip('Change Depth Effect'));
      await tester.pumpAndSettle();
      for (final String option in <String>['Auto', 'Menu', 'None']) {
        expect(find.widgetWithText(PopupMenuItem<WallDepthTier>, option), findsOneWidget, reason: option);
      }
      await tester.tap(find.widgetWithText(PopupMenuItem<WallDepthTier>, 'Menu'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          any(
            that: isA<ReviewBatchDepthChanged>()
                .having((e) => e.wallId, 'wallId', 'a')
                .having((e) => e.tier, 'tier', WallDepthTier.menu),
          ),
        ),
      ).called(1);
    });

    testWidgets('the pill hides while the card is dragged', (tester) async {
      await pump(
        tester,
        ReviewBatchState(status: ReviewBatchStatus.loaded, walls: <FirestoreDocument>[_wall('a', 'Sunset')]),
      );
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: find.text('Depth: Not checked'), matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      expect(opacity(), 1);

      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('Sunset')));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(opacity(), 0);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a finished batch offers the next one', (tester) async {
    await pump(
      tester,
      ReviewBatchState(
        status: ReviewBatchStatus.loaded,
        walls: <FirestoreDocument>[_wall('a', 'Sunset')],
        currentIndex: 1,
        totalPending: 14,
      ),
    );

    expect(find.text('Batch complete'), findsOneWidget);
    expect(find.text('14 wallpapers remaining'), findsOneWidget);
    await tester.tap(find.text('Load next batch'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<ReviewBatchNextBatchRequested>()))).called(1);
  });

  testWidgets('a Studio wall offers Reserve for Drop and the button sends the event', (tester) async {
    await pump(
      tester,
      ReviewBatchState(
        status: ReviewBatchStatus.loaded,
        walls: <FirestoreDocument>[_wall('a', 'Sunset', origin: 'studio')],
        totalPending: 1,
      ),
    );

    expect(find.text('Reserve'), findsOneWidget);
    expect(find.bySemanticsLabel('Reserve for Drop'), findsOneWidget);

    await tester.tap(find.text('Reserve'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<ReviewBatchSwipeReserved>()))).called(1);
  });

  testWidgets('a wall that is not from Studio has no Reserve action', (tester) async {
    await pump(
      tester,
      ReviewBatchState(
        status: ReviewBatchStatus.loaded,
        walls: <FirestoreDocument>[_wall('a', 'Sunset')],
        totalPending: 1,
      ),
    );

    expect(find.text('Reserve'), findsNothing);
    expect(find.text('Skip'), findsOneWidget);
  });
}
