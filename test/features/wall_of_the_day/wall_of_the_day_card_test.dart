import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wall_of_the_day_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _RecordingAnalytics extends FakeAppAnalytics {
  final List<String> events = <String>[];

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event.eventName);
}

void main() {
  testWidgets('wotd_viewed fires once per wall even when the carousel rebuilds the card', (tester) async {
    final analytics = _RecordingAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);

    final bloc = _MockWotdBloc();
    when(() => bloc.state).thenReturn(
      WotdState.initial().copyWith(
        status: LoadStatus.success,
        entity: const WallOfTheDayEntity(
          wallId: 'wotd-1',
          url: '',
          thumbnailUrl: '',
          title: 'Dunes',
          photographer: 'Ana',
        ),
      ),
    );

    // The carousel disposes page 0 when it scrolls away and builds a fresh card when it loops back.
    for (var loop = 0; loop < 3; loop++) {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<WotdBloc>.value(
            value: bloc,
            child: WallOfTheDayCard(key: ValueKey<int>(loop)),
          ),
        ),
      );
    }

    expect(analytics.events.where((e) => e == 'wotd_viewed'), hasLength(1));
  });
}
