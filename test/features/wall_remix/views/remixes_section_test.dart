import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
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
  _FakeRemixRepository(this.remixes) : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final List<PrismWallpaper> remixes;

  @override
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId) async => remixes;

  @override
  Future<Set<String>> blockedCreatorUids() async => const <String>{};
}

WallViewer _viewer() =>
    const WallViewer(isPremium: true, premiumCollections: <String>[], blockedCreatorUids: <String>{});

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
          child: RemixesSection(original: original, repository: _FakeRemixRepository(remixes), viewer: _viewer()),
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
}
