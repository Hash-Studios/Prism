import 'dart:async';

import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FavouriteCountsCubit extends Cubit<Map<String, int>> {
  FavouriteCountsCubit(this._repository, {@ignoreParam DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const {});

  final FavouriteCountsRepository _repository;
  final DateTime Function() _now;
  static const _ttl = Duration(minutes: 1);
  static const _errorBackoff = Duration(seconds: 10);
  static const _maxEntries = 512;
  final _expires = <String, DateTime>{};
  final _pending = <String>{};
  final _inFlight = <String>{};
  final _refreshIds = <String>{};
  Timer? _batchTimer;
  Timer? _refreshTimer;
  Timer? _retryTimer;
  bool _fetching = false;

  void request(String rawId, {bool force = false}) {
    if (isClosed) return;
    final id = prismStatsId(rawId);
    if (id == null) return;
    if (_inFlight.contains(id)) {
      if (force) _pending.add(id);
      return;
    }
    if (!force && (_expires[id]?.isAfter(_now()) ?? false)) return;
    _pending.add(id);
    if (!_fetching) _batchTimer ??= Timer(Duration.zero, _flush);
  }

  /// The image write ACK precedes aggregation. Refetch twice, without inventing a local global delta.
  void refreshAfterChange(String rawId) {
    final id = prismStatsId(rawId);
    if (isClosed || id == null) return;
    _refreshIds.add(id);
    _refreshTimer ??= Timer(const Duration(seconds: 2), () {
      _refreshTimer = null;
      for (final id in _refreshIds) {
        request(id, force: true);
      }
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 6), () {
        _retryTimer = null;
        final ids = Set<String>.of(_refreshIds);
        _refreshIds.clear();
        for (final id in ids) {
          request(id, force: true);
        }
      });
    });
  }

  Future<void> _flush() async {
    _batchTimer = null;
    if (isClosed || _pending.isEmpty) return;
    _fetching = true;
    final ids = _pending.take(30).toSet();
    _pending.removeAll(ids);
    _inFlight.addAll(ids);
    try {
      final counts = await _repository.fetch(ids);
      if (isClosed) return;
      final next = Map<String, int>.of(state)..addAll(counts);
      for (final id in ids) {
        _expires.remove(id);
        _expires[id] = _now().add(_ttl);
      }
      while (_expires.length > _maxEntries) {
        final oldest = _expires.keys.first;
        _expires.remove(oldest);
        next.remove(oldest);
      }
      emit(Map.unmodifiable(next));
    } on Object {
      if (!isClosed) {
        for (final id in ids) {
          _expires[id] = _now().add(_errorBackoff);
        }
      }
    } finally {
      _fetching = false;
      _inFlight.removeAll(ids);
      while (_expires.length > _maxEntries) {
        _expires.remove(_expires.keys.first);
      }
      if (!isClosed && state.keys.any((id) => !_expires.containsKey(id))) {
        emit(Map.unmodifiable(Map<String, int>.of(state)..removeWhere((id, _) => !_expires.containsKey(id))));
      }
      if (!isClosed && _pending.isNotEmpty) _batchTimer ??= Timer(Duration.zero, _flush);
    }
  }

  @override
  Future<void> close() {
    _batchTimer?.cancel();
    _refreshTimer?.cancel();
    _retryTimer?.cancel();
    return super.close();
  }
}
