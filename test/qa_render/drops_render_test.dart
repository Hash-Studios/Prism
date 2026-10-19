@Tags(<String>['qa_render'])
library;

import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/drops/drops.dart';
import 'package:Prism/features/drops/views/widgets/unlock_sheet.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/coins_test_backend.dart';
import 'coin_economy_render_test.dart' show registerRewardsDeps;
import 'qa_harness.dart';
import 'qa_images.dart';

class _MockDropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

final DateTime _now = DateTime(2026, 10, 20, 12);

DropEntity _drop({required Duration endsIn, int collectors = 128, bool ended = false}) {
  final DateTime start = ended ? _now.subtract(const Duration(days: 9)) : _now.subtract(const Duration(days: 1));
  return DropEntity(
    weekKey: '2026-W42',
    title: 'Neon Tides',
    startsAt: start,
    endsAt: _now.add(endsIn),
    priceWall: 30,
    pricePack: 100,
    count: 6,
    collectors: collectors,
    walls: <DropWall>[
      for (final String id in <String>['A', 'B', 'C', 'D', 'E', 'F'])
        DropWall(
          id: id,
          title: 'Wall $id',
          thumb: 'https://example.test/$id.jpg',
          resolution: '1080x2400',
          by: 'Ana',
          seriesId: 's1',
        ),
    ],
  );
}

DropUnlock _own(String id) => DropUnlock(wallId: id, weekKey: '2026-W42', url: 'https://example.test/$id-full.jpg');

DropsState _state(DropEntity drop, {Iterable<String> owned = const <String>[]}) => DropsState(
  status: LoadStatus.success,
  now: _now,
  drop: drop,
  unlocked: <String, DropUnlock>{for (final String id in owned) id: _own(id)},
);

void _scene(
  String name,
  ThemeData theme,
  DropsState state,
  Future<void> Function(QaShot shot) body, {
  double height = 1250,
  bool rewards = false,
}) {
  testWidgets('$name (${theme.brightness.name})', skip: !qaRender, (WidgetTester tester) async {
    tester.view.physicalSize = Size(1170, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final CoinsTestBackend backend = CoinsTestBackend();
    await backend.install();
    seedUser(pro: false);
    await QaImages.install(tester);
    addTearDown(() async {
      QaImages.uninstall();
      resetUser();
      await getIt.reset();
    });
    if (rewards) {
      registerRewardsDeps(drops: state);
    } else {
      getIt.registerFactory<DropsBloc>(() {
        final _MockDropsBloc bloc = _MockDropsBloc();
        whenListen(bloc, const Stream<DropsState>.empty(), initialState: state);
        return bloc;
      });
    }
    final QaShot shot = QaShot(tester, theme.brightness, theme, backend);
    when(() => shot.router.push(any())).thenAnswer((_) async => null);
    when(() => shot.router.pushPath(any())).thenAnswer((_) async => null);
    await body(shot);
    expect(tester.takeException(), isNull);
  });
}

void main() {
  setUpAll(() {
    registerFallbackValue(WallpaperDetailRoute());
    registerFallbackValue(const DropsEvent.started());
  });
  setUpAll(loadFonts);

  for (final (String tag, ThemeData theme) in <(String, ThemeData)>[('amoled', kDarkTheme2), ('light', kLightTheme)]) {
    final DropEntity live = _drop(endsIn: const Duration(days: 3, hours: 4, minutes: 30));
    final DropEntity lastCall = _drop(endsIn: const Duration(hours: 5, minutes: 10));

    _scene('drops_live_$tag', theme, _state(live, owned: <String>['A']), (QaShot shot) async {
      await shot.pump(const DropsPage());
      await shot.save('drops_live_$tag');
    });

    _scene('drops_last_call_$tag', theme, _state(lastCall, owned: <String>['A', 'C']), (QaShot shot) async {
      await shot.pump(const DropsPage());
      await shot.save('drops_last_call_$tag');
    });

    _scene('drops_all_unlocked_$tag', theme, _state(live, owned: <String>['A', 'B', 'C', 'D', 'E', 'F']), (
      QaShot shot,
    ) async {
      await shot.pump(const DropsPage());
      await shot.save('drops_all_unlocked_$tag');
    });

    _scene(
      'drop_ended_detail_$tag',
      theme,
      _state(_drop(endsIn: const Duration(days: -2), ended: true), owned: <String>['A', 'D']),
      (QaShot shot) async {
        await shot.pump(const DropDetailPage(weekKey: '2026-W42'));
        await shot.save('drop_ended_detail_$tag');
      },
    );

    _scene('drop_unlock_sheet_$tag', theme, _state(live), (QaShot shot) async {
      await shot.pump(const DropsPage());
      unawaited(
        showDropUnlockSheet(
          shot.tester.element(find.byType(Scaffold).first),
          drop: live,
          wall: live.walls[1],
          remaining: 6,
          onUnlock: (_) {},
          onWatch: () async {},
        ),
      );
      await shot.settle(frames: 8);
      await shot.save('drop_unlock_sheet_$tag');
    });

    for (final (String kind, DropEntity drop) in <(String, DropEntity)>[('live', live), ('last_call', lastCall)]) {
      _scene('rewards_drop_card_${kind}_$tag', theme, _state(drop, owned: <String>['A']), rewards: true, height: 900, (
        QaShot shot,
      ) async {
        CoinsService.instance.balanceNotifier.value = 973;
        await shot.pump(const RewardsPage(showBack: false));
        await shot.save('rewards_drop_card_${kind}_$tag');
      });
    }
  }
}
