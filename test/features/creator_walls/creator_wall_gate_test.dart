import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/creator_walls/creator_walls.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PrismWallpaper _wall() => const PrismWallpaper(
  core: WallpaperCore(
    id: 'neon',
    source: WallpaperSource.prism,
    fullUrl: '',
    thumbnailUrl: 'https://example.com/neon.jpg',
    authorUid: 'maker',
    authorName: 'Ava',
  ),
  firestoreDocumentId: 'neon',
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
        return CreatorWallUnlockButton(wall: wall, checking: access == CreatorWallAccess.checking);
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

  testWidgets('a stranger whose marker reads as unlocked sees the normal Set child', (WidgetTester tester) async {
    final CreatorWallUnlocks unlocks = CreatorWallUnlocks(
      owner: () => 'fan',
      read: (_, _) async => <String, dynamic>{'wallDocId': 'neon'},
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
}
