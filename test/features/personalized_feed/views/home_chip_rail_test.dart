import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/views/widgets/home_chip_rail.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final PrismThemeOption rose = prismLightThemes.firstWhere((PrismThemeOption option) => option.label == 'Rose');
  final ThemeData theme = withPrismAccent(rose.theme, rose.defaultAccentValue);

  Future<void> pumpRail(
    WidgetTester tester, {
    HomeFeedChip selected = HomeFeedChip.forYou,
    ValueChanged<HomeFeedChip>? onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: HomeChipRailDelegate(selected: selected, onSelected: onSelected ?? (_) {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('the band paints the page colour, so it matches the page behind the feed', (tester) async {
    await pumpRail(tester);

    final Material band = tester.widget<Material>(
      find.descendant(of: find.byType(SliverPersistentHeader), matching: find.byType(Material)).first,
    );

    expect(band.color, theme.colorScheme.surface);
  });

  testWidgets('the rail is 56 px high, lines up with the 16 px page edge and keeps 44 px tap targets', (tester) async {
    await pumpRail(tester);

    final Finder band = find.descendant(of: find.byType(SliverPersistentHeader), matching: find.byType(Material)).first;
    expect(tester.getSize(band).height, 56);
    expect(tester.getTopLeft(find.widgetWithText(PrismChip, 'For you')).dx, 16);
    for (final HomeFeedChip chip in HomeFeedChip.values) {
      expect(tester.getSize(find.widgetWithText(PrismChip, chip.label)).height, 44, reason: chip.label);
    }
  });

  testWidgets('the selected chip is the inverted pill and the others are tonal', (tester) async {
    await pumpRail(tester, selected: HomeFeedChip.latest);

    Color fillOf(String label) {
      final AnimatedContainer container = tester.widget<AnimatedContainer>(
        find.descendant(of: find.widgetWithText(PrismChip, label), matching: find.byType(AnimatedContainer)),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    expect(fillOf('Latest'), theme.colorScheme.onSurface);
    expect(fillOf('For you'), isNot(theme.colorScheme.onSurface));
    expect(fillOf('Popular'), isNot(theme.colorScheme.onSurface));
  });

  testWidgets('at 2x text the labels grow to 1.5x only, so the chips stay inside the 56 px rail', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpRail(tester);

    final RichText label = tester.widget<RichText>(
      find.descendant(of: find.widgetWithText(PrismChip, 'For you'), matching: find.byType(RichText)),
    );
    final Finder band = find.descendant(of: find.byType(SliverPersistentHeader), matching: find.byType(Material)).first;

    expect(label.textScaler.scale(14), 21);
    expect(tester.getSize(band).height, 56);
    expect(tester.getSize(find.widgetWithText(PrismChip, 'For you')).height, lessThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last chip ends 16 px from the screen edge once the rail is scrolled to the end', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpRail(tester);

    await tester.drag(find.byType(ListView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopRight(find.widgetWithText(PrismChip, 'Popular')).dx, 360 - 16);
  });

  testWidgets('tapping a chip reports it', (tester) async {
    HomeFeedChip? picked;
    await pumpRail(tester, onSelected: (chip) => picked = chip);

    await tester.tap(find.widgetWithText(PrismChip, 'Popular'));

    expect(picked, HomeFeedChip.popular);
  });
}
