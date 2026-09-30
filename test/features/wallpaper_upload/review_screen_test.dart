import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/review_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/rejection_feedback.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _ReviewFirestoreClient extends FakeFirestoreClient {
  _ReviewFirestoreClient({this.failRejectedStream = false, this.failPendingStream = false, this.neverEmit = false});

  final bool failRejectedStream;
  final bool failPendingStream;
  final bool neverEmit;
  final List<FirestoreDocument> rejectedRows = <FirestoreDocument>[];
  final List<FirestoreDocument> pendingRows = <FirestoreDocument>[];

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    if (neverEmit) return StreamController<List<T>>().stream;
    if (spec.collection == FirebaseCollections.rejectedWalls && failRejectedStream) {
      return Stream<List<T>>.error(StateError('offline'));
    }
    if (spec.collection == FirebaseCollections.walls && failPendingStream) {
      return Stream<List<T>>.error(StateError('offline'));
    }
    final List<FirestoreDocument> documents = spec.collection == FirebaseCollections.rejectedWalls
        ? rejectedRows
        : pendingRows;
    return Stream<List<T>>.value(documents.map((document) => map(document.data(), document.id)).toList());
  }
}

/// The thumbnail skeleton pulses forever while an image loads, so screen tests run with motion off.
Widget _screen() => MaterialApp(
  builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  home: const ReviewScreen(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ReviewFirestoreClient firestore;

  setUp(() {
    firestore = _ReviewFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
  });
  tearDown(() => getIt.unregister<FirestoreClient>());

  setUpAll(() async {
    await (FontLoader('Proxima Nova')..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))).load();
  });

  for (final double width in <double>[360, 390, 440]) {
    for (final bool rejected in <bool>[false, true]) {
      for (final double textScale in <double>[1, 1.5]) {
        testWidgets(
          '${rejected ? 'rejected' : 'pending'} wall tile content stays within a ${width.toInt()}px card at ${textScale}x text',
          (WidgetTester tester) async {
            tester.view.physicalSize = Size(width, 956);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: kLightTheme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: MediaQuery(
                      data: MediaQueryData(size: Size(width, 956), textScaler: TextScaler.linear(textScale)),
                      child: WallTile(
                        FirestoreDocument('pWTbDtblpDvZpVsYZbjt', <String, dynamic>{
                          'createdAt': DateTime.utc(2026, 9, 30),
                          'size': '12.34MB',
                          'resolution': '1440x3200',
                          if (rejected)
                            'rejectionReason':
                                'Please replace the screenshot with a clear full-screen image and include the wallpaper, icon pack, and widget details.',
                        }),
                        rejected: rejected,
                      ),
                    ),
                  ),
                ),
              ),
            );

            final Rect cardRect = tester.getRect(find.byType(PrismCard));
            final Finder cardText = find.descendant(of: find.byType(PrismCard), matching: find.byType(Text));
            for (final Element text in cardText.evaluate()) {
              final Rect textRect = tester.getRect(find.byWidget(text.widget));
              expect(textRect.left, greaterThanOrEqualTo(cardRect.left));
              expect(textRect.right, lessThanOrEqualTo(cardRect.right));
              expect(textRect.bottom, lessThanOrEqualTo(cardRect.bottom));
            }
            expect(tester.getRect(find.byType(PrismTag)).bottom, lessThanOrEqualTo(cardRect.bottom));
            final Finder iconButtons = find.byType(IconButton);
            expect(iconButtons, findsNWidgets(2));
            for (int index = 0; index < 2; index++) {
              final Rect button = tester.getRect(iconButtons.at(index));
              expect(button.left, greaterThanOrEqualTo(cardRect.left));
              expect(button.right, lessThanOrEqualTo(cardRect.right));
              expect(button.bottom, lessThanOrEqualTo(cardRect.bottom));
              expect(button.width, greaterThanOrEqualTo(44));
            }
            expect(tester.takeException(), isNull);
            expect(find.text('pWTbDtblpDvZpVsYZbjt'), findsNothing);
            expect(find.text('1440 x 3200 · 12.34 MB'), findsOneWidget);
            if (rejected) {
              expect(find.byType(RejectionFeedback), findsOneWidget);
            }
          },
        );
      }
    }
  }

  testWidgets('a legacy rejected wallpaper without a reason shows the fallback in its tile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WallTile(FirestoreDocument('wall-1', <String, dynamic>{'rejectionReason': '  '}), rejected: true),
          ),
        ),
      ),
    );

    expect(find.text(RejectionFeedback.fallbackReason), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error when rejected submissions cannot load', (tester) async {
    getIt.unregister<FirestoreClient>();
    firestore = _ReviewFirestoreClient(failRejectedStream: true);
    getIt.registerSingleton<FirestoreClient>(firestore);

    await tester.pumpWidget(_screen());
    await tester.pump();

    expect(find.text("Couldn't load your rejected submissions."), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final bool rejected in <bool>[false, true]) {
    testWidgets('deletes a ${rejected ? 'rejected' : 'pending'} wall from its source collection', (tester) async {
      final String collection = rejected ? FirebaseCollections.rejectedWalls : FirebaseCollections.walls;
      (rejected ? firestore.rejectedRows : firestore.pendingRows).add(
        const FirestoreDocument('wall-1', <String, dynamic>{
          'wallpaper_thumb': 'https://example.com/thumb.png',
          'wallpaper_url': 'https://example.com/wall.png',
          'size': '2 MB',
          'resolution': '1440x3200',
        }),
      );
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete wallpaper'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this wallpaper?'), findsOneWidget);
      await tester.tap(find.text('Delete wallpaper'));
      await tester.pumpAndSettle();

      expect(firestore.writes, hasLength(1));
      expect(firestore.writes.single, (op: 'delete', collection: collection, id: 'wall-1', data: null));
    });
  }

  testWidgets('canceling wall deletion leaves the source document unchanged', (tester) async {
    firestore.rejectedRows.add(
      const FirestoreDocument('wall-1', <String, dynamic>{
        'wallpaper_thumb': 'https://example.com/thumb.png',
        'wallpaper_url': 'https://example.com/wall.png',
        'size': '2 MB',
        'resolution': '1440x3200',
      }),
    );
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete wallpaper'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this wallpaper?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(firestore.writes, isEmpty);
  });

  testWidgets('lists uploads in review first, then rejected, each under its own header', (tester) async {
    firestore.pendingRows.add(
      const FirestoreDocument('wall-1', <String, dynamic>{'size': '2 MB', 'resolution': '1440x3200'}),
    );
    firestore.rejectedRows.add(
      const FirestoreDocument('wall-2', <String, dynamic>{
        'size': '3 MB',
        'resolution': '1080x2400',
        'rejectionReason': 'Too blurry.',
      }),
    );
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(find.text('Your uploads'), findsOneWidget);
    expect(find.text('In review'), findsNWidgets(2));
    expect(find.text('Rejected'), findsNWidgets(2));
    expect(find.text('Too blurry.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('In review').first).dy,
      lessThan(tester.getTopLeft(find.text('Rejected').first).dy),
    );
  });

  testWidgets('shows an empty state with an upload action when there are no uploads', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pump();
    await tester.pump();

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Wallpapers you upload show their review status here.'), findsOneWidget);
    expect(find.text('Upload a wallpaper'), findsOneWidget);
  });

  testWidgets('shows a skeleton while the uploads load', (tester) async {
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(_ReviewFirestoreClient(neverEmit: true));

    await tester.pumpWidget(_screen());
    await tester.pump();

    expect(find.byType(PrismSkeleton), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);
  });

  testWidgets('shows one error with a retry when both lists fail to load', (tester) async {
    getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(_ReviewFirestoreClient(failRejectedStream: true, failPendingStream: true));

    await tester.pumpWidget(_screen());
    await tester.pump();

    expect(find.text("Couldn't load your uploads"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
