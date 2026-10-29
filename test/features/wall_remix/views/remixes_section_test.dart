import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_remix/biz/remixes_cubit.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/features/wall_remix/views/widgets/remixes_section.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../wall_remix_fixture.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

class _MockUserBlockRepository extends Mock implements UserBlockRepository {}

/// Serves a fixed list of remixes, newest first.
class _FakeRemixRepository extends WallRemixRepository {
  _FakeRemixRepository(this.remixes, this.original) : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final List<PrismWallpaper> remixes;
  final PrismWallpaper original;

  @override
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId, {String? startAfterDocId}) async => remixes;

  @override
  Future<Set<String>> blockedCreatorUids({bool waitForInitialLoad = true}) async => const <String>{};

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async => original;
}

class _MappedRemixRepository extends WallRemixRepository {
  _MappedRemixRepository(this.remixesByOriginal, this.originalsByDocId)
    : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final Map<String, List<PrismWallpaper>> remixesByOriginal;
  final Map<String, PrismWallpaper?> originalsByDocId;
  int queryCount = 0;

  @override
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId, {String? startAfterDocId}) async {
    queryCount++;
    return remixesByOriginal[originalDocId] ?? const <PrismWallpaper>[];
  }

  @override
  Future<Set<String>> blockedCreatorUids({bool waitForInitialLoad = true}) async => const <String>{};

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async {
    queryCount++;
    return originalsByDocId[docId];
  }
}

class _DeferredRemixRepository extends WallRemixRepository {
  _DeferredRemixRepository(this.originalsByDocId, this.remixesByOriginal, this.pending)
    : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final Map<String, PrismWallpaper?> originalsByDocId;
  final Map<String, List<PrismWallpaper>> remixesByOriginal;
  final Map<String, Completer<List<PrismWallpaper>>> pending;

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async => originalsByDocId[docId];

  @override
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId, {String? startAfterDocId}) =>
      pending[originalDocId]?.future ??
      Future<List<PrismWallpaper>>.value(remixesByOriginal[originalDocId] ?? const []);

  @override
  Future<Set<String>> blockedCreatorUids({bool waitForInitialLoad = true}) async => const <String>{};
}

WallViewer _viewer({bool isPremium = true}) =>
    WallViewer(isPremium: isPremium, premiumCollections: const <String>['space'], blockedCreatorUids: const <String>{});

Future<void> _pump(
  WidgetTester tester, {
  required PrismWallpaper original,
  required List<PrismWallpaper> remixes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RemixesSection(
            original: original,
            cubit: RemixesCubit(_FakeRemixRepository(remixes, original)),
            viewer: _viewer(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
  });

  testWidgets('shows the title, the count and one tile per visible remix', (tester) async {
    await _pump(
      tester,
      original: remixWall(id: 'orig', docId: 'doc-orig', remixCount: 2, authorEmail: 'owner@example.com'),
      remixes: [
        remixWall(id: 'r1', docId: 'd1', authorName: 'Ben', authorEmail: 'ben@example.com', authorUid: 'uid-b'),
        remixWall(id: 'r2', docId: 'd2', authorName: 'Chloe', authorEmail: 'chloe@example.com', authorUid: 'uid-c'),
      ],
    );

    expect(find.text('Remixes'), findsOneWidget);
    expect(find.text('2 remixes'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Chloe'), findsOneWidget);
    expect(analytics.events.whereType<RemixesGridOpenedEvent>().single.count, 2);
  });

  testWidgets('does not show a remix by the original owner', (tester) async {
    await _pump(
      tester,
      original: remixWall(id: 'orig', docId: 'doc-orig', remixCount: 2, authorEmail: 'owner@example.com'),
      remixes: [
        remixWall(id: 'r1', docId: 'd1', authorName: 'Ben', authorEmail: 'ben@example.com', authorUid: 'uid-b'),
        remixWall(id: 'r2', docId: 'd2', authorName: 'Owner', authorEmail: 'OWNER@example.com', authorUid: 'uid-o'),
      ],
    );

    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Owner'), findsNothing);
    expect(find.text('2 remixes'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no remixes', (tester) async {
    await _pump(
      tester,
      original: remixWall(id: 'orig', docId: 'doc-orig'),
      remixes: const [],
    );

    expect(find.text('Remixes'), findsNothing);
    expect(analytics.events.whereType<RemixesGridOpenedEvent>(), isEmpty);
  });

  testWidgets('reloads when the original changes and filters again when the viewer changes', (tester) async {
    final _MappedRemixRepository repository = _MappedRemixRepository(
      <String, List<PrismWallpaper>>{
        'doc-a': <PrismWallpaper>[
          remixWall(
            id: 'r-a',
            docId: 'r-a-doc',
            authorName: 'A remix',
            authorEmail: 'a@example.com',
            authorUid: 'uid-a',
          ),
        ],
        'doc-b': <PrismWallpaper>[
          remixWall(
            id: 'r-b',
            docId: 'r-b-doc',
            authorName: 'Premium remix',
            authorEmail: 'b@example.com',
            authorUid: 'uid-b',
            collections: const <String>['space'],
          ),
        ],
      },
      <String, PrismWallpaper?>{
        'doc-a': remixWall(id: 'orig-a', docId: 'doc-a', remixCount: 1),
        'doc-b': remixWall(id: 'orig-b', docId: 'doc-b', remixCount: 1),
      },
    );
    PrismWallpaper original = remixWall(id: 'orig-a', docId: 'doc-a', remixCount: 1);
    WallViewer viewer = _viewer();

    Widget build() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RemixesSection(original: original, cubit: RemixesCubit(repository), viewer: viewer),
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('A remix'), findsOneWidget);

    original = remixWall(id: 'orig-b', docId: 'doc-b', remixCount: 1);
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('A remix'), findsNothing);
    expect(find.text('Premium remix'), findsOneWidget);

    final int queriesBeforeEquivalentViewer = repository.queryCount;
    viewer = _viewer();
    await tester.pumpWidget(build());
    await tester.pump();
    expect(repository.queryCount, queriesBeforeEquivalentViewer);

    viewer = _viewer(isPremium: false);
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Premium remix'), findsNothing);

    viewer = _viewer();
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Premium remix'), findsOneWidget);

    original = remixWall(id: 'orig-b', docId: 'doc-b', remixCount: 1, review: false);
    repository.originalsByDocId['doc-b'] = original;
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Premium remix'), findsNothing);
  });

  testWidgets('hides remixes when the original is no longer available to the viewer', (tester) async {
    final original = remixWall(id: 'orig', docId: 'doc-orig', remixCount: 1);
    final _MappedRemixRepository repository = _MappedRemixRepository(
      <String, List<PrismWallpaper>>{
        'doc-orig': <PrismWallpaper>[
          remixWall(
            id: 'r1',
            docId: 'd1',
            authorName: 'Remix',
            authorEmail: 'remixer@example.com',
            authorUid: 'uid-r1',
          ),
        ],
      },
      <String, PrismWallpaper?>{'doc-orig': remixWall(id: 'orig', docId: 'doc-orig', review: false, remixCount: 1)},
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RemixesSection(original: original, cubit: RemixesCubit(repository), viewer: _viewer()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Remix'), findsNothing);
    expect(find.text('Remixes'), findsNothing);
  });

  testWidgets('ignores a late response after the original changes', (tester) async {
    final Completer<List<PrismWallpaper>> oldResponse = Completer<List<PrismWallpaper>>();
    final _DeferredRemixRepository repository = _DeferredRemixRepository(
      <String, PrismWallpaper?>{
        'doc-a': remixWall(id: 'orig-a', docId: 'doc-a', remixCount: 1),
        'doc-b': remixWall(id: 'orig-b', docId: 'doc-b', remixCount: 1),
      },
      <String, List<PrismWallpaper>>{
        'doc-b': <PrismWallpaper>[
          remixWall(id: 'r-b', docId: 'r-b-doc', authorName: 'Current', authorUid: 'uid-current'),
        ],
      },
      <String, Completer<List<PrismWallpaper>>>{'doc-a': oldResponse},
    );
    PrismWallpaper original = remixWall(id: 'orig-a', docId: 'doc-a', remixCount: 1);

    Widget build() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RemixesSection(original: original, cubit: RemixesCubit(repository), viewer: _viewer()),
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    original = remixWall(id: 'orig-b', docId: 'doc-b', remixCount: 1);
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Current'), findsOneWidget);

    oldResponse.complete(<PrismWallpaper>[
      remixWall(id: 'r-a', docId: 'r-a-doc', authorName: 'Stale', authorUid: 'uid-stale'),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Stale'), findsNothing);
  });
}
