@Tags(<String>['qa_render'])
library;

import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_field.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/features/badges/views/widgets/badge_celebrate_sheet.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/views/widgets/search_filter_sheet.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

/// The bottom corner radius of an iPhone 15 Pro screen.
const double _iphoneCornerRadius = 55;

Future<void> _open(BuildContext context, WidgetBuilder builder, {bool large = false}) =>
    showPrismSheet<void>(context, builder: builder, initialDetent: large ? PrismSheetDetent.large : null);

/// A stand-in for the wallpaper grid, so the dimmed screen behind the sheet reads as the app.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  static const List<Color> _tiles = <Color>[
    Color(0xFF3A6EA5),
    Color(0xFFE07A5F),
    Color(0xFF81B29A),
    Color(0xFFF2CC8F),
    Color(0xFF6D597A),
    Color(0xFF355070),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 0.5,
        padding: const EdgeInsets.all(PrismSpace.xxs),
        mainAxisSpacing: PrismSpace.xxs,
        crossAxisSpacing: PrismSpace.xxs,
        children: <Widget>[
          for (int i = 0; i < 6; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PrismRadius.sm),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[_tiles[i], _tiles[(i + 2) % _tiles.length]],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Future<BuildContext> _home(QaShot shot) async {
  PrismDeviceCornerRadius.setValueForTesting(_iphoneCornerRadius);
  await shot.pump(const _Backdrop());
  return shot.tester.element(find.byType(GridView));
}

Widget _picker(BuildContext _) => PrismSheetBody(
  title: 'Set wallpaper',
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      PrismRow(icon: Icons.home_rounded, title: 'Home screen', onTap: () {}),
      PrismRow(icon: Icons.lock_rounded, title: 'Lock screen', onTap: () {}),
      PrismRow(icon: Icons.smartphone_rounded, title: 'Both screens', onTap: () {}),
    ],
  ),
);

void main() {
  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    await loadFonts();
  });

  qaScreen('sheet confirm', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(
      showPrismConfirm(
        context,
        title: 'Delete this wallpaper?',
        message: 'It goes from your profile and from search. You cannot undo this.',
        confirmLabel: 'Delete wallpaper',
        destructive: true,
      ),
    );
    await shot.settle();
    await shot.save('sheet_confirm');
  });

  qaScreen('sheet picker', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(_open(context, _picker));
    await shot.settle();
    await shot.save('sheet_picker');
  });

  qaScreen('sheet moment', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(
      _open(
        context,
        (BuildContext _) => PrismSheetBody(
          mood: GlintMood.celebrate,
          centered: true,
          title: 'Streak saved',
          message: 'Your freeze kept your 12 day streak alive. Come back tomorrow to keep it going.',
          actions: <Widget>[PrismButton(label: 'Nice', expand: true, onPressed: () {})],
        ),
      ),
    );
    await shot.settle(frames: 10);
    await shot.save('sheet_moment');
  });

  qaScreen('sheet form', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(
      _open(
        context,
        (BuildContext _) => PrismSheetBody(
          title: 'Report a problem',
          trailingAction: PrismSheetAction(label: 'Clear', onTap: () {}),
          message: 'Tell us what went wrong. We read every report.',
          actions: <Widget>[PrismButton(label: 'Send report', expand: true, onPressed: () {})],
          child: const PrismTextField(label: 'What happened?', hint: 'The wallpaper did not apply', maxLines: 4),
        ),
      ),
    );
    await shot.settle();
    await shot.save('sheet_form');
  });

  qaScreen('sheet set wallpaper', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(showSetWallpaperSheet(context, canAdjust: true));
    await shot.settle();
    await shot.save('sheet_real_set_wallpaper');
  });

  qaScreen('sheet search filters', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(showSearchFilterSheet(context, const SearchFilters()));
    await shot.settle();
    await shot.save('sheet_real_search_filters');
  });

  qaScreen('sheet new badge', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(showBadgeCelebrateSheet(context, const EarnedBadge(id: 'week_warrior', coins: 25)));
    await shot.settle(frames: 10);
    await shot.save('sheet_real_badge');
  });

  qaScreen('sheet startup choice', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(
      showStartupChoiceSheet(
        context,
        message: 'Turn on notifications to hear about new walls from creators you follow?',
        confirmLabel: 'Turn on',
        dismissLabel: 'Not now',
      ),
    );
    await shot.settle();
    await shot.save('sheet_real_startup_choice');
  });

  qaScreen('sheet full height', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(_open(context, _picker, large: true));
    await shot.settle();
    await shot.save('sheet_large');
  });
}
