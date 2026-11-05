import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_pick_sheet.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDayNightBloc extends MockBloc<DayNightEvent, DayNightState> implements DayNightBloc {}

PrismWallpaper _wallpaper(String id, {List<String>? colors}) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://example.test/$id.jpg',
    thumbnailUrl: '',
    authorName: 'Ana',
  ),
  colors: colors,
);

PrismFeedItem _feedItem(String id, {List<String>? colors}) => PrismFeedItem(
  id: id,
  wallpaper: _wallpaper(id, colors: colors),
);

final FeedItemEntity _item = _feedItem('wall-1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockDayNightBloc bloc;

  setUpAll(() {
    registerFallbackValue(const DayNightEvent.proLapseAcknowledged());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => null,
    );
  });

  setUp(() {
    bloc = _MockDayNightBloc();
    when(() => bloc.state).thenReturn(DayNightState.initial());
    whenListen(bloc, const Stream<DayNightState>.empty(), initialState: DayNightState.initial());
  });

  Future<void> pumpSheet(WidgetTester tester, {FeedItemEntity? item, VariantGroup? variants, double textScale = 1}) {
    return tester.pumpWidget(
      BlocProvider<DayNightBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDayNightPickSheet(context, item: item ?? _item, variants: variants),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester tester, {
    FeedItemEntity? item,
    VariantGroup? variants,
    double textScale = 1,
  }) async {
    await pumpSheet(tester, item: item, variants: variants, textScale: textScale);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the day and night rows but no variant row without variants', (tester) async {
    await openSheet(tester);

    expect(find.text('Use as day wall'), findsOneWidget);
    expect(find.text('Use as night wall'), findsOneWidget);
    expect(find.text('Use the lightest and darkest variant'), findsNothing);
  });

  testWidgets('shows the variant row and adds the lightest and darkest pair when tapped', (tester) async {
    final VariantGroup group = VariantGroup(
      id: 'group',
      walls: <PrismWallpaper>[
        _wallpaper('dark', colors: const <String>['#000000']),
        _wallpaper('light', colors: const <String>['#ffffff']),
      ],
    );

    await openSheet(tester, variants: group);
    expect(find.text('Use the lightest and darkest variant'), findsOneWidget);

    await tester.tap(find.text('Use the lightest and darkest variant'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    verify(
      () => bloc.add(
        DayNightEvent.variantsPicked(
          day: DayNightWall.fromFeedItem(_feedItem('light', colors: const <String>['#ffffff'])),
          night: DayNightWall.fromFeedItem(_feedItem('dark', colors: const <String>['#000000'])),
        ),
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Use as night wall adds the night wall for this item', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Use as night wall'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    verify(() => bloc.add(DayNightEvent.wallPicked(DayNightSlot.night, DayNightWall.fromFeedItem(_item)))).called(1);
  });

  testWidgets('tapping Use as day wall adds the day wall for this item', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Use as day wall'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    verify(() => bloc.add(DayNightEvent.wallPicked(DayNightSlot.day, DayNightWall.fromFeedItem(_item)))).called(1);
  });

  testWidgets('opens without an exception at 2.0 text scale', (tester) async {
    await openSheet(tester, textScale: 2);

    expect(find.text('Use as day wall'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
