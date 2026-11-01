import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_remix/biz/remix_credit_cubit.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/features/wall_remix/views/widgets/remix_credit_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../wall_remix_fixture.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

class _MockUserBlockRepository extends Mock implements UserBlockRepository {}

/// Serves one approved original, or none.
class _FakeRemixRepository extends WallRemixRepository {
  _FakeRemixRepository(this.original) : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final PrismWallpaper? original;

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async => original;

  @override
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(const <String>{});
}

class _MappedRemixRepository extends WallRemixRepository {
  _MappedRemixRepository(this.originalsByDocId) : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final Map<String, PrismWallpaper?> originalsByDocId;

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async => originalsByDocId[docId];

  @override
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(const <String>{});
}

class _DeferredRemixRepository extends WallRemixRepository {
  _DeferredRemixRepository(this.originalsByDocId, this.pending)
    : super(_MockFirestoreClient(), _MockUserBlockRepository());

  final Map<String, PrismWallpaper?> originalsByDocId;
  final Map<String, Completer<PrismWallpaper?>> pending;

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) =>
      pending[docId]?.future ?? Future<PrismWallpaper?>.value(originalsByDocId[docId]);

  @override
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(const <String>{});
}

WallViewer _viewer({bool isPremium = true, Set<String> blocked = const <String>{}}) => WallViewer(
  isPremium: isPremium,
  premiumCollections: const <String>['space'],
  blockedCreators: KnownBlockedCreators(blocked),
);

Future<void> _pump(WidgetTester tester, {required PrismWallpaper? original, required WallViewer viewer}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RemixCreditRow(
          remixOfDocId: 'doc-orig',
          cubit: RemixCreditCubit(_FakeRemixRepository(original)),
          viewer: viewer,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows the credit line for an approved original', (tester) async {
    await _pump(
      tester,
      original: remixWall(id: 'orig', docId: 'doc-orig'),
      viewer: _viewer(),
    );

    expect(find.text('Remix of Koi by Asha'), findsOneWidget);
  });

  testWidgets('shows nothing when the original is missing', (tester) async {
    await _pump(tester, original: null, viewer: _viewer());

    expect(find.textContaining('Remix of'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('shows nothing when the approved target is not an AI wall', (tester) async {
    await _pump(
      tester,
      original: remixWall(id: 'orig', docId: 'doc-orig', isAi: false),
      viewer: _viewer(),
    );

    expect(find.textContaining('Remix of'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('shows nothing when the original is premium-gated for a free viewer', (tester) async {
    await _pump(
      tester,
      original: remixWall(id: 'orig', docId: 'doc-orig', collections: const <String>['space']),
      viewer: _viewer(isPremium: false),
    );

    expect(find.textContaining('Remix of'), findsNothing);
  });

  testWidgets('shows nothing when the original creator is blocked', (tester) async {
    await _pump(
      tester,
      original: remixWall(id: 'orig', docId: 'doc-orig'),
      viewer: _viewer(blocked: const <String>{'uid-asha'}),
    );

    expect(find.textContaining('Remix of'), findsNothing);
  });

  testWidgets('reloads for a new source and rechecks viewer access', (tester) async {
    final _MappedRemixRepository repository = _MappedRemixRepository(<String, PrismWallpaper?>{
      'doc-a': remixWall(id: 'orig-a', docId: 'doc-a', title: 'First'),
      'doc-b': remixWall(id: 'orig-b', docId: 'doc-b', title: 'Second', collections: const <String>['space']),
    });
    String remixOfDocId = 'doc-a';
    WallViewer viewer = _viewer();

    Widget build() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RemixCreditRow(remixOfDocId: remixOfDocId, cubit: RemixCreditCubit(repository), viewer: viewer),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Remix of First by Asha'), findsOneWidget);

    remixOfDocId = 'doc-b';
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Remix of First by Asha'), findsNothing);
    expect(find.text('Remix of Second by Asha'), findsOneWidget);

    viewer = _viewer(isPremium: false);
    await tester.pumpWidget(build());
    await tester.pump();
    expect(find.textContaining('Remix of'), findsNothing);
  });

  testWidgets('ignores a late original lookup after the remix source changes', (tester) async {
    final Completer<PrismWallpaper?> oldResponse = Completer<PrismWallpaper?>();
    final _DeferredRemixRepository repository = _DeferredRemixRepository(
      <String, PrismWallpaper?>{'doc-b': remixWall(id: 'orig-b', docId: 'doc-b', title: 'Current')},
      <String, Completer<PrismWallpaper?>>{'doc-a': oldResponse},
    );
    String remixOfDocId = 'doc-a';

    Widget build() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RemixCreditRow(remixOfDocId: remixOfDocId, cubit: RemixCreditCubit(repository), viewer: _viewer()),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    remixOfDocId = 'doc-b';
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Remix of Current by Asha'), findsOneWidget);

    oldResponse.complete(remixWall(id: 'orig-a', docId: 'doc-a', title: 'Stale'));
    await tester.pump();
    expect(find.text('Remix of Current by Asha'), findsOneWidget);
    expect(find.textContaining('Stale'), findsNothing);
  });
}
