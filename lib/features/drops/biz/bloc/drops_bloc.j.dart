import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'drops_event.j.dart';
part 'drops_state.j.dart';
part 'drops_bloc.j.freezed.dart';

@injectable
class DropsBloc extends Bloc<DropsEvent, DropsState> {
  DropsBloc(this._repository) : super(DropsState.initial()) {
    on<_Started>(_onStarted);
    on<_Refreshed>(_onRefreshed);
    on<_UnlockRequested>(_onUnlockRequested);
    on<_Ticked>((_, emit) => emit(state.copyWith(now: DateTime.now())));
    on<_UnlockedChanged>(_onUnlockedChanged);
    CoinsService.instance.dropsUnlockedNotifier.addListener(_onUnlockedNotifier);
  }

  static const String packKey = '__pack__';

  /// Past Drops the vault shows at most, newest first.
  static const int vaultCap = 52;

  final DropsRepository _repository;
  Timer? _timer;
  String? _weekKey;

  void _onUnlockedNotifier() => add(DropsEvent.unlockedChanged(CoinsService.instance.dropsUnlockedNotifier.value));

  Future<void> _onStarted(_Started event, Emitter<DropsState> emit) async {
    _weekKey = event.weekKey;
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => add(const DropsEvent.ticked()));
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        now: DateTime.now(),
        unlocked: CoinsService.instance.dropsUnlockedNotifier.value,
      ),
    );
    await _load(emit);
    final DropEntity? drop = state.drop;
    if (drop != null) unawaited(analytics.track(DropViewedEvent(weekKey: drop.weekKey)));
  }

  Future<void> _onRefreshed(_Refreshed event, Emitter<DropsState> emit) => _load(emit);

  Future<void> _load(Emitter<DropsState> emit) async {
    final DateTime now = DateTime.now();
    final String? weekKey = _weekKey;
    if (weekKey != null) {
      final Result<DropEntity?> result = await _repository.fetchByWeekKey(weekKey);
      result.fold(
        onSuccess: (drop) => emit(state.copyWith(status: LoadStatus.success, now: now, drop: drop)),
        onFailure: (_) => emit(state.copyWith(status: LoadStatus.failure)),
      );
      return;
    }
    final Result<DropEntity?> live = await _repository.fetchLive(now);
    live.fold(
      onSuccess: (drop) => emit(state.copyWith(status: LoadStatus.success, now: now, drop: drop)),
      onFailure: (_) => emit(state.copyWith(status: LoadStatus.failure)),
    );
    if (live.isSuccess) await _fillVault(emit);
  }

  Future<void> _onUnlockedChanged(_UnlockedChanged event, Emitter<DropsState> emit) async {
    emit(state.copyWith(unlocked: event.unlocked));
    if (_weekKey == null && state.status == LoadStatus.success) await _fillVault(emit);
  }

  /// Loads the Drop of every past week the user owns a wall from. Loaded Drops stay in [DropsState.past].
  Future<void> _fillVault(Emitter<DropsState> emit) async {
    final String? liveWeek = state.drop?.weekKey;
    final List<String> weeks =
        state.unlocked.values
            .map((DropUnlock u) => u.weekKey)
            .where((String week) => week.isNotEmpty && week != liveWeek)
            .toSet()
            .toList()
          ..sort((String a, String b) => b.compareTo(a));
    final Set<String> cached = <String>{for (final DropEntity d in state.past) d.weekKey};
    final List<String> missing = weeks.take(vaultCap).where((String week) => !cached.contains(week)).toList();
    if (missing.isEmpty) return;
    final List<Result<DropEntity?>> results = await Future.wait(missing.map(_repository.fetchByWeekKey));
    final List<DropEntity> fetched = results.map((Result<DropEntity?> r) => r.data).nonNulls.toList();
    if (fetched.isEmpty) return;
    emit(
      state.copyWith(
        past: <DropEntity>[...state.past, ...fetched]
          ..sort((DropEntity a, DropEntity b) => b.weekKey.compareTo(a.weekKey)),
      ),
    );
  }

  Future<void> _onUnlockRequested(_UnlockRequested event, Emitter<DropsState> emit) async {
    final DropEntity? drop = state.drop;
    if (drop == null || state.busyKey != null) return;
    final bool isPro = app_state.prismUser.premium;
    final bool pack = event.wallId == null;
    final int price = pack
        ? drop.packPrice(remaining: state.lockedWalls.length, isPro: isPro)
        : drop.wallPrice(isPro: isPro);
    emit(state.copyWith(busyKey: event.wallId ?? packKey));
    final DropUnlockResult result = await CoinsService.instance.unlockDrop(weekKey: drop.weekKey, wallId: event.wallId);
    if (result.outcome == DropUnlockOutcome.unlocked && result.unlocked.isNotEmpty) {
      unawaited(
        analytics.track(
          DropUnlockedEvent(weekKey: drop.weekKey, pack: pack, count: result.unlocked.length, price: price),
        ),
      );
    }
    emit(state.copyWith(busyKey: null, lastResult: result));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    CoinsService.instance.dropsUnlockedNotifier.removeListener(_onUnlockedNotifier);
    return super.close();
  }
}
