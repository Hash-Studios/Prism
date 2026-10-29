import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/wallpaper_upload/biz/bloc/wall_metadata_cubit.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _Actions extends Mock implements WallMetadataActions {}

void main() {
  const initial = PendingWallMetadata(text: WallTextMetadata(title: 'Before'));
  const next = PendingWallMetadata(
    text: WallTextMetadata(title: 'After', description: 'New description', tags: ['blue']),
    category: 'Nature',
  );
  const snapshot = WallMetadataSnapshot(metadata: initial, approved: true, revision: 'rev-1');
  late _Actions actions;
  late WallMetadataCubit cubit;
  late FakeAppAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(initial);
    registerFallbackValue(snapshot);
  });

  setUp(() {
    actions = _Actions();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    when(() => actions.load('doc', approved: true)).thenAnswer((_) async => snapshot);
    cubit = WallMetadataCubit(actions, wallDocId: 'doc', approved: true);
  });

  tearDown(() async {
    await cubit.close();
    AnalyticsRuntime.reset();
  });

  test('approved changes retain category and save canonical metadata with the initial revision', () async {
    await cubit.load();
    cubit.change(next);
    expect(cubit.state.draft!.category, 'General');
    when(
      () => actions.save(
        'doc',
        any(),
        expected: any(named: 'expected'),
        operationId: any(named: 'operationId'),
      ),
    ).thenAnswer((_) async => const WallMetadataSnapshot(metadata: next, approved: true, revision: 'rev-2'));
    await cubit.save();
    expect(cubit.state.status, WallMetadataStatus.saved);
    expect(cubit.state.snapshot!.revision, 'rev-2');
    final event = analytics.events.single;
    expect(event.eventName, 'wall_approved_metadata_edited');
    expect(event.toWireParameters(), {
      'asset_id': 'doc',
      'fields': ['title', 'desc', 'tags'],
    });
  });

  test('a busy save ignores repeated taps and input changes', () async {
    await cubit.load();
    cubit.change(next);
    final pending = Completer<WallMetadataSnapshot>();
    when(
      () => actions.save(
        'doc',
        any(),
        expected: any(named: 'expected'),
        operationId: any(named: 'operationId'),
      ),
    ).thenAnswer((_) => pending.future);
    final first = cubit.save();
    await cubit.save();
    cubit.change(initial);
    expect(cubit.state.status, WallMetadataStatus.saving);
    expect(cubit.state.draft!.text.title, 'After');
    pending.complete(snapshot);
    await first;
    verify(
      () => actions.save(
        'doc',
        any(),
        expected: any(named: 'expected'),
        operationId: any(named: 'operationId'),
      ),
    ).called(1);
  });

  test('lost response retry preserves operation ID and expected revision', () async {
    await cubit.load();
    cubit.change(next);
    final ids = <String>[];
    when(
      () => actions.save(
        'doc',
        any(),
        expected: any(named: 'expected'),
        operationId: any(named: 'operationId'),
      ),
    ).thenAnswer((call) async {
      ids.add(call.namedArguments[#operationId] as String);
      if (ids.length == 1) throw const WallMetadataException(WallMetadataFailure.unavailable);
      return snapshot;
    });
    await cubit.save();
    expect(cubit.state.draft!.text, next.text);
    expect(analytics.events, isEmpty);
    await cubit.save();
    expect(ids, hasLength(2));
    expect(ids.first, ids.last);
    expect(analytics.events, hasLength(1));
  });

  test('conflict keeps unsaved values and blocks more saves until explicit reload', () async {
    await cubit.load();
    cubit.change(next);
    when(
      () => actions.save(
        'doc',
        any(),
        expected: any(named: 'expected'),
        operationId: any(named: 'operationId'),
      ),
    ).thenThrow(const WallMetadataException(WallMetadataFailure.conflict));
    await cubit.save();
    expect(cubit.state.needsReload, isTrue);
    expect(cubit.state.draft!.text, next.text);
    cubit.change(const PendingWallMetadata(text: WallTextMetadata(title: 'Still unsaved')));
    await cubit.save();
    verify(
      () => actions.save(
        'doc',
        any(),
        expected: any(named: 'expected'),
        operationId: any(named: 'operationId'),
      ),
    ).called(1);
    await cubit.load();
    expect(cubit.state.draft, initial);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.dirty, isFalse);
  });

  test('overlong metadata is rejected before any network call', () async {
    await cubit.load();
    cubit.change(PendingWallMetadata(text: WallTextMetadata(description: 'x' * 501)));
    await cubit.save();
    expect(cubit.state.failure, WallMetadataFailure.invalid);
    verifyNever(
      () => actions.save(
        any(),
        any(),
        expected: any(named: 'expected'),
        operationId: any(named: 'operationId'),
      ),
    );
  });
}
