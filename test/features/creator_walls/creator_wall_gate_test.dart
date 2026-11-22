import 'dart:async';

import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/creator_walls/creator_walls.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PrismWallpaper _wall({String id = 'neon', String? docId}) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: '',
    thumbnailUrl: 'https://example.com/neon.jpg',
    authorUid: 'maker',
    authorName: 'Ava',
  ),
  firestoreDocumentId: docId ?? id,
  creatorPrice: 40,
);

Widget _app(CreatorWallUnlocks unlocks, PrismWallpaper wall) => MaterialApp(
  theme: kLightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: CreatorWallGate(
      wall: wall,
      unlocks: unlocks,
      builder: (BuildContext context, CreatorWallAccess access) {
        if (access == CreatorWallAccess.owner || access == CreatorWallAccess.unlocked) return const Text('Set');
        return CreatorWallUnlockButton(wall: wall, checking: access == CreatorWallAccess.checking, unlocks: unlocks);
      },
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Two frames: the first starts the marker read, the second lets the completed read rebuild the gate.
  Future<void> settleRead(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a stranger with no unlock marker sees the unlock button', (WidgetTester tester) async {
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(owner: () => 'fan', read: (_, _) async => null);
    await tester.pumpWidget(_app(unlocks, _wall()));
    await settleRead(tester);

    expect(find.text('Unlock for 40 coins'), findsOneWidget);
    expect(find.text('Set'), findsNothing);
  });

  testWidgets('a guest who cancels sign-in does not open the unlock sheet', (tester) async {
    final Future<bool> Function(BuildContext) previous = signedInActionSignIn;
    signedInActionSignIn = (_) async => false;
    addTearDown(() => signedInActionSignIn = previous);
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(owner: () => 'fan', read: (_, _) async => null);
    await tester.pumpWidget(_app(unlocks, _wall()));
    await settleRead(tester);
    await tester.tap(find.text('Unlock for 40 coins'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock this wall'), findsNothing);
    expect(find.text('Unlock for 40 coins'), findsOneWidget);
  });

  testWidgets('a stranger whose marker reads as unlocked sees the normal Set child', (WidgetTester tester) async {
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(
      owner: () => 'fan',
      read: (_, _) async => <String, dynamic>{'wallDocId': 'neon', 'wallId': 'neon'},
    );
    await tester.pumpWidget(_app(unlocks, _wall()));
    await settleRead(tester);

    expect(find.text('Set'), findsOneWidget);
    expect(find.text('Unlock for 40 coins'), findsNothing);
  });

  testWidgets('the creator sees the normal Set child without a marker read', (WidgetTester tester) async {
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(owner: () => 'maker', read: (_, _) async => null);
    await tester.pumpWidget(_app(unlocks, _wall()));
    await settleRead(tester);

    expect(find.text('Set'), findsOneWidget);
    expect(find.text('Unlock for 40 coins'), findsNothing);
  });

  testWidgets('a marker read error can be retried and a late old-owner result stays scoped', (tester) async {
    String uid = 'fan';
    var attempts = 0;
    final Completer<Map<String, dynamic>?> pending = Completer<Map<String, dynamic>?>();
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(
      owner: () => uid,
      read: (owner, _) async {
        attempts++;
        if (owner == 'other') return null;
        if (attempts == 1) throw StateError('offline');
        return pending.future;
      },
    );
    await tester.pumpWidget(_app(unlocks, _wall()));
    await tester.pump();
    await tester.pump();
    expect(unlocks.accessFor(_wall()), CreatorWallAccess.locked);

    unlocks.invalidate('neon');
    expect(unlocks.accessFor(_wall()), CreatorWallAccess.checking);
    uid = 'other';
    pending.complete(<String, dynamic>{'wallDocId': 'neon', 'wallId': 'neon'});
    await tester.pump();
    await tester.pump();
    expect(unlocks.accessFor(_wall()), CreatorWallAccess.locked);
    expect(attempts, greaterThanOrEqualTo(2));
  });

  testWidgets('session reset discards late marker reads and mismatched marker wall ids', (tester) async {
    final Completer<Map<String, dynamic>?> pending = Completer<Map<String, dynamic>?>();
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(owner: () => 'fan', read: (_, _) => pending.future);
    await tester.pumpWidget(_app(unlocks, _wall()));
    expect(unlocks.accessFor(_wall()), CreatorWallAccess.checking);
    unlocks.resetSession();
    pending.complete(<String, dynamic>{'wallDocId': 'neon', 'wallId': 'some-other-wall'});
    await tester.pump();
    await tester.pump();
    expect(unlocks.accessFor(_wall()), CreatorWallAccess.locked);
  });

  testWidgets('a positive cache entry cannot unlock a different logical wall using the same doc id', (tester) async {
    var reads = 0;
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(
      owner: () => 'fan',
      read: (_, _) async {
        reads++;
        return null;
      },
    );
    unlocks.markUnlocked('neon', wallId: 'first-wall');
    final PrismWallpaper replacement = _wall(id: 'replacement-wall', docId: 'neon');
    await tester.pumpWidget(_app(unlocks, replacement));
    expect(unlocks.accessFor(replacement), isNot(CreatorWallAccess.unlocked));
    await tester.pump();
    await tester.pump();
    expect(unlocks.accessFor(replacement), CreatorWallAccess.locked);
    expect(reads, 1);
  });
}
