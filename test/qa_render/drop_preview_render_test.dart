@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/drops/drops.dart';
import 'package:Prism/features/drops/views/pages/drop_preview_page.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/drops/drop_fixtures.dart';
import 'qa_harness.dart';

class _MockDropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

final DateTime _now = DateTime(2026, 10, 21, 9, 41);

DropEntity _drop({Duration endsIn = const Duration(days: 4, hours: 3)}) {
  final DropEntity base = dropEntity(wallIds: <String>['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']);
  return DropEntity(
    weekKey: base.weekKey,
    title: base.title,
    startsAt: _now.subtract(const Duration(days: 2)),
    endsAt: _now.add(endsIn),
    priceWall: 30,
    pricePack: 100,
    count: base.count,
    walls: base.walls,
  );
}

Future<void> _show(
  QaShot shot, {
  required String wallId,
  Duration endsIn = const Duration(days: 4, hours: 3),
  Map<String, DropUnlock> unlocked = const <String, DropUnlock>{},
  bool home = false,
  bool amoled = false,
}) async {
  final _MockDropsBloc bloc = _MockDropsBloc();
  when(() => bloc.close()).thenAnswer((_) async {});
  final DropsState state = DropsState(
    status: LoadStatus.success,
    now: _now,
    drop: _drop(endsIn: endsIn),
    unlocked: unlocked,
  );
  whenListen(bloc, const Stream<DropsState>.empty(), initialState: state);
  Widget page = BlocProvider<DropsBloc>.value(
    value: bloc,
    child: DropPreviewPage(wallId: wallId),
  );
  if (amoled) page = Theme(data: kDarkTheme2, child: page);
  await shot.pump(page);
  if (home) {
    await shot.tester.tap(find.text('Home screen'));
    await shot.settle(frames: 2);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(WallpaperDetailRoute());
  });
  setUpAll(loadFonts);

  qaScreen('drop_preview_lock', (QaShot shot) async {
    await _show(shot, wallId: 'C', amoled: shot.brightness == Brightness.dark);
    await shot.save('drop_preview_lock');
  });

  qaScreen('drop_preview_home', pro: true, (QaShot shot) async {
    await _show(shot, wallId: 'D', home: true, amoled: shot.brightness == Brightness.dark);
    await shot.save('drop_preview_home');
  });

  qaScreen('drop_preview_last_call', (QaShot shot) async {
    await _show(shot, wallId: 'B', endsIn: const Duration(hours: 5, minutes: 20));
    await shot.save('drop_preview_last_call');
  });

  qaScreen('drop_preview_owned', (QaShot shot) async {
    CoinsService.instance.balanceNotifier.value = 340;
    await _show(
      shot,
      wallId: 'C',
      unlocked: <String, DropUnlock>{
        'C': const DropUnlock(wallId: 'C', weekKey: '2026-W42', url: 'https://full.test/C.jpg'),
      },
    );
    await shot.save('drop_preview_owned');
  });
}
