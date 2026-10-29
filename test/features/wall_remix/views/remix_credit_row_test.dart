import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
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
  Future<Set<String>> blockedCreatorUids() async => const <String>{};
}

WallViewer _viewer({bool isPremium = true, Set<String> blocked = const <String>{}}) =>
    WallViewer(isPremium: isPremium, premiumCollections: const <String>['space'], blockedCreatorUids: blocked);

Future<void> _pump(WidgetTester tester, {required PrismWallpaper? original, required WallViewer viewer}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RemixCreditRow(remixOfDocId: 'doc-orig', repository: _FakeRemixRepository(original), viewer: viewer),
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
}
