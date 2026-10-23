import 'dart:async';

import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counts implements FavouriteCountsRepository {
  final calls = <Set<String>>[];
  final pending = <Completer<Map<String, PrismWallpaperStats>>>[];

  @override
  Future<Map<String, PrismWallpaperStats>> fetch(Set<String> ids) {
    calls.add(ids);
    final result = Completer<Map<String, PrismWallpaperStats>>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  testWidgets('a forced refresh waits behind a slow initial read and stays deduped', (tester) async {
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository);
    addTearDown(cubit.close);
    cubit.request('A');
    await tester.pump();
    cubit.refreshAfterChange('A');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 7));
    expect(repository.calls, hasLength(1));
    repository.pending.first.complete({'A': const PrismWallpaperStats(favourites: 3)});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.calls, [
      <String>{'A'},
      <String>{'A'},
    ]);
    expect(cubit.state, {'A': const PrismWallpaperStats(favourites: 3)});
    repository.pending.last.complete({'A': const PrismWallpaperStats(favourites: 4)});
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(cubit.state, {'A': const PrismWallpaperStats(favourites: 4)});
    expect(repository.calls, hasLength(2));
  });

  testWidgets('cache stays bounded when many new IDs fail after successful reads', (tester) async {
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository);
    for (var i = 0; i < 600; i++) {
      cubit.request('W$i');
    }
    await tester.pump(Duration.zero);
    for (var batch = 0; batch < 20; batch++) {
      if (batch < 18) {
        repository.pending[batch].complete({
          for (final id in repository.calls[batch]) id: const PrismWallpaperStats(favourites: 1),
        });
      } else {
        repository.pending[batch].completeError(StateError('offline'));
      }
      await tester.pump(Duration.zero);
      expect(cubit.state.length, lessThanOrEqualTo(512));
    }
    await cubit.close();
  });
  testWidgets('drains at most one batch at a time and expires cached totals after a minute', (tester) async {
    var now = DateTime(2026);
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository, now: () => now);
    for (var i = 0; i < 65; i++) {
      cubit.request('W$i');
    }
    await tester.pump(Duration.zero);
    expect(repository.calls.single, hasLength(30));
    cubit.request('EXTRA');
    await tester.pump(Duration.zero);
    expect(repository.calls, hasLength(1));
    repository.pending[0].complete({
      for (final id in repository.calls[0]) id: const PrismWallpaperStats(favourites: 1),
    });
    await tester.pump(Duration.zero);
    expect(repository.calls[1], hasLength(30));
    repository.pending[1].complete({
      for (final id in repository.calls[1]) id: const PrismWallpaperStats(favourites: 1),
    });
    await tester.pump(Duration.zero);
    expect(repository.calls[2], hasLength(6));
    repository.pending[2].complete({
      for (final id in repository.calls[2]) id: const PrismWallpaperStats(favourites: 1),
    });
    await tester.pump(Duration.zero);
    cubit.request('W0');
    await tester.pump(Duration.zero);
    expect(repository.calls, hasLength(3));
    now = now.add(const Duration(minutes: 1));
    cubit.request('W0');
    await tester.pump(Duration.zero);
    expect(repository.calls, hasLength(4));
    await cubit.close();
  });

  testWidgets('local changes cause only two coalesced delayed refreshes, never a speculative total', (tester) async {
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository);
    cubit.refreshAfterChange('A');
    cubit.refreshAfterChange('A');
    cubit.refreshAfterChange('B');
    await tester.pump(const Duration(seconds: 2));
    expect(repository.calls, [
      <String>{'A', 'B'},
    ]);
    expect(cubit.state, isEmpty);
    repository.pending[0].complete({
      'A': const PrismWallpaperStats(favourites: 7),
      'B': const PrismWallpaperStats(favourites: 0),
    });
    await tester.pump(const Duration(seconds: 6));
    expect(repository.calls, hasLength(2));
    repository.pending[1].complete({
      'A': const PrismWallpaperStats(favourites: 7),
      'B': const PrismWallpaperStats(favourites: 0),
    });
    await tester.pump(const Duration(minutes: 5));
    expect(repository.calls, hasLength(2));
    expect(cubit.state, {'A': const PrismWallpaperStats(favourites: 7), 'B': const PrismWallpaperStats(favourites: 0)});
    await cubit.close();
  });

  testWidgets('errors back off then permit retry', (tester) async {
    var now = DateTime(2026);
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository, now: () => now);
    cubit.request('A');
    await tester.pump(Duration.zero);
    repository.pending.single.completeError(StateError('offline'));
    await tester.pump(Duration.zero);
    cubit.request('A');
    await tester.pump(Duration.zero);
    expect(repository.calls, hasLength(1));
    now = now.add(const Duration(seconds: 10));
    cubit.request('A');
    await tester.pump(Duration.zero);
    expect(repository.calls, hasLength(2));
    await cubit.close();
  });
  test('coalesces normalized requests, dedupes in flight and caches known zero', () async {
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository);
    addTearDown(cubit.close);
    cubit.request(' abc ');
    cubit.request('ABC');
    cubit.request('def');
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, [
      <String>{'ABC', 'DEF'},
    ]);
    cubit.request('ABC');
    repository.pending.single.complete({
      'ABC': const PrismWallpaperStats(favourites: 8),
      'DEF': const PrismWallpaperStats(favourites: 0),
    });
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, {
      'ABC': const PrismWallpaperStats(favourites: 8),
      'DEF': const PrismWallpaperStats(favourites: 0),
    });
    cubit.request('ABC');
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, hasLength(1));
  });

  test('failure leaves unknown unknown and retains a successful stale count', () async {
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository);
    addTearDown(cubit.close);
    cubit.request('ABC');
    await Future<void>.delayed(Duration.zero);
    repository.pending.last.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state['ABC'], isNull);
    cubit.request('ABC', force: true);
    await Future<void>.delayed(Duration.zero);
    repository.pending.last.complete({'ABC': const PrismWallpaperStats(favourites: 4)});
    await Future<void>.delayed(Duration.zero);
    cubit.request('ABC', force: true);
    await Future<void>.delayed(Duration.zero);
    repository.pending.last.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state['ABC']?.favourites, 4);
  });

  test('closing ignores late requests and responses', () async {
    final repository = _Counts();
    final cubit = FavouriteCountsCubit(repository);
    cubit.request('ABC');
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    repository.pending.single.complete({'ABC': const PrismWallpaperStats(favourites: 8)});
    cubit.request('DEF');
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, hasLength(1));
  });
}
