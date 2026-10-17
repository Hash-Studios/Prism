import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/boost_wall_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/coins_test_backend.dart';

PrismWallpaper _wall({String? email = 'Owner@Example.com', bool review = true, DateTime? boostedUntil}) =>
    PrismWallpaper(
      core: WallpaperCore(
        id: 'W1',
        source: WallpaperSource.prism,
        fullUrl: 'https://example.test/w1.jpg',
        thumbnailUrl: 'https://example.test/w1-thumb.jpg',
        authorEmail: email,
      ),
      review: review,
      boostedUntil: boostedUntil,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  late List<String> calls;

  setUp(() async {
    await backend.install();
    app_state.prismUser.email = 'owner@example.com';
    calls = <String>[];
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add(name);
      return <String, Object?>{
        'success': true,
        'changed': true,
        'previousBalance': 200,
        'currentBalance': 100,
        'delta': -100,
        'reason': 'ok',
        'endsAt': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
      };
    };
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  group('canBoostWall', () {
    test('is true for the owner of an approved wall, ignoring email case', () {
      expect(canBoostWall(_wall()), isTrue);
    });

    test('is false for another user, an unapproved wall, a missing email and a guest', () {
      expect(canBoostWall(_wall(email: 'other@example.com')), isFalse);
      expect(canBoostWall(_wall(review: false)), isFalse);
      expect(canBoostWall(_wall(email: null)), isFalse);
      app_state.prismUser.loggedIn = false;
      expect(canBoostWall(_wall()), isFalse);
    });
  });

  Future<void> pumpRow(WidgetTester tester, PrismWallpaper wall) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: BoostWallRow(wall: wall)),
    ),
  );

  testWidgets('shows the price and the 24 hour promise', (tester) async {
    await pumpRow(tester, _wall());

    expect(find.text('Boost to Trending'), findsOneWidget);
    expect(find.text('24 hours at the top · 100 coins'), findsOneWidget);
  });

  testWidgets('shows the end time while a boost is active and does not call the server', (tester) async {
    await pumpRow(tester, _wall(boostedUntil: DateTime.now().add(const Duration(hours: 5))));

    expect(find.textContaining('Boosted until'), findsOneWidget);
    await tester.tap(find.text('Boost to Trending'));
    await tester.pump();

    expect(calls, isEmpty);
  });

  testWidgets('confirming calls boostWall and the row then shows the end time', (tester) async {
    await pumpRow(tester, _wall());

    await tester.tap(find.text('Boost to Trending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boost for 100 coins'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(calls, <String>['boostWall']);
    expect(find.textContaining('Boosted until'), findsOneWidget);
  });

  testWidgets('cancelling the sheet spends nothing', (tester) async {
    await pumpRow(tester, _wall());

    await tester.tap(find.text('Boost to Trending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(find.text('24 hours at the top · 100 coins'), findsOneWidget);
  });
}
