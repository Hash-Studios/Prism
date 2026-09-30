import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/views/pages/swipe_review_screen.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_wallpaper_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockReviewBatchBloc extends MockBloc<ReviewBatchEvent, ReviewBatchState> implements ReviewBatchBloc {}

class _FakeEvent extends Fake implements ReviewBatchEvent {}

FirestoreDocument _wall(String id, String title) => FirestoreDocument(id, <String, dynamic>{
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
    verify(() => bloc.add(any(that: isA<ReviewBatchSwipeRejected>()))).called(1);
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
}
