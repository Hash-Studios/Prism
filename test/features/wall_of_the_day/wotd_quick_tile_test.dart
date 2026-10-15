import 'dart:async';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wotd_quick_tile_listener.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

const WallOfTheDayEntity _wall = WallOfTheDayEntity(
  wallId: 'wall-1',
  url: 'https://example.com/wall-1.jpg',
  thumbnailUrl: 'https://example.com/wall-1-thumb.jpg',
  photographer: 'Ana',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.quickTileWotdTarget: 'both',
      PersistenceKeys.quickTileWotdUrl: 'https://example.com/old.jpg',
    });
  });

  testWidgets('successful empty WOTD clears the cached quick-tile wall', (tester) async {
    final _MockWotdBloc bloc = _MockWotdBloc();
    final StreamController<WotdState> states = StreamController<WotdState>();
    whenListen(bloc, states.stream, initialState: WotdState.initial().copyWith(status: LoadStatus.loading));

    await tester.pumpWidget(
      BlocProvider<WotdBloc>.value(
        value: bloc,
        child: const WotdQuickTileListener(child: SizedBox.shrink()),
      ),
    );
    states.add(WotdState.initial().copyWith(status: LoadStatus.success));
    await tester.pump();
    await tester.pump();

    final String? cachedUrl = (await QuickTileConfigService.loadWotdTileConfig())?.cachedUrl;
    await tester.pumpWidget(const SizedBox.shrink());
    await states.close();
    expect(cachedUrl, '');
  });

  testWidgets('loading and failure keep the last usable quick-tile wall', (tester) async {
    final _MockWotdBloc bloc = _MockWotdBloc();
    final StreamController<WotdState> states = StreamController<WotdState>();
    whenListen(
      bloc,
      states.stream,
      initialState: WotdState.initial().copyWith(status: LoadStatus.success, entity: _wall),
    );

    await tester.pumpWidget(
      BlocProvider<WotdBloc>.value(
        value: bloc,
        child: const WotdQuickTileListener(child: SizedBox.shrink()),
      ),
    );
    states
      ..add(WotdState.initial().copyWith(status: LoadStatus.loading, entity: _wall))
      ..add(WotdState.initial().copyWith(status: LoadStatus.failure, entity: _wall));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final String? cachedUrl = (await QuickTileConfigService.loadWotdTileConfig())?.cachedUrl;
    await tester.pumpWidget(const SizedBox.shrink());
    await states.close();
    expect(cachedUrl, 'https://example.com/old.jpg');
  });

  testWidgets('successful WOTD updates the quick-tile wall URL', (tester) async {
    final _MockWotdBloc bloc = _MockWotdBloc();
    final StreamController<WotdState> states = StreamController<WotdState>();
    whenListen(bloc, states.stream, initialState: WotdState.initial().copyWith(status: LoadStatus.loading));

    await tester.pumpWidget(
      BlocProvider<WotdBloc>.value(
        value: bloc,
        child: const WotdQuickTileListener(child: SizedBox.shrink()),
      ),
    );
    states.add(WotdState.initial().copyWith(status: LoadStatus.success, entity: _wall));
    await tester.pump();
    await tester.pump();

    final String? cachedUrl = (await QuickTileConfigService.loadWotdTileConfig())?.cachedUrl;
    await tester.pumpWidget(const SizedBox.shrink());
    await states.close();
    expect(cachedUrl, 'https://example.com/wall-1.jpg');
  });
}
