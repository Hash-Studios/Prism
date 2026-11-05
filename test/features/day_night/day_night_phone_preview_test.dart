import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_phone_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

void main() {
  setUpAll(() => registerFallbackValue(WallpaperDetailRoute()));

  testWidgets('empty slot stays visible without download guidance or wall action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DayNightPhonePreview(slot: DayNightSlot.day, wall: null, time: '7:00 AM', needsDownload: true),
        ),
      ),
    );

    expect(find.text('Hold any wallpaper, then tap Use as day wall.'), findsOneWidget);
    expect(find.text('Download this wall in Prism first.'), findsNothing);
    expect(find.text('Open wall'), findsNothing);
  });

  testWidgets('Open wall navigates to that selected wall detail', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    when(() => router.maybePop()).thenAnswer((_) async => false);
    const DayNightWall wall = DayNightWall(
      id: 'protected-wall-123',
      source: WallpaperSource.prism,
      fullUrl: '',
      thumbnailUrl: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const Scaffold(
            body: DayNightPhonePreview(slot: DayNightSlot.day, wall: wall, time: '7:00 AM', needsDownload: true),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open wall'));
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    final WallpaperDetailRouteArgs args = route.args!;
    expect(args.wallId, wall.id);
    expect(args.source, wall.source);
    expect(args.thumbnailUrl, wall.thumbnailUrl);
    verifyNever(() => router.maybePop());
  });
}
