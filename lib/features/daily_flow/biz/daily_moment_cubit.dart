import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/daily_flow/domain/daily_moment_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_moment_cubit.freezed.dart';

@freezed
abstract class DailyMomentState with _$DailyMomentState {
  const factory DailyMomentState({
    DailyMomentStep? step,
    @Default(false) bool busy,
    @Default(false) bool done,
    @Default(false) bool unavailable,
    @Default(false) bool error,
    StreakClaimResult? receipt,
    int? coins,
    String? itemId,
    @Default(0) int chestCost,
    @Default(0) int balance,
  }) = _DailyMomentState;
  const DailyMomentState._();
  bool get hasReceipt => receipt != null || coins != null || itemId != null;
}

class DailyMomentCubit extends Cubit<DailyMomentState> {
  DailyMomentCubit(this.repository, {this.requestedStep, this.receipt, this.onStepDone})
    : _owner = repository.accountId,
      super(const DailyMomentState(busy: true)) {
    _accountSubscription = repository.watchAccount().listen((account) {
      if (account == _owner || isClosed || _closedByUser) return;
      _closedByUser = true;
      emit(const DailyMomentState(unavailable: true));
    });
  }
  final DailyMomentRepository repository;
  final DailyMomentStep? requestedStep;
  final StreakClaimResult? receipt;
  final void Function(DailyMomentStep step)? onStepDone;
  final String _owner;
  bool _closedByUser = false;
  late final StreamSubscription<String> _accountSubscription;

  bool get _active => !isClosed && !_closedByUser && repository.accountId == _owner && _owner.isNotEmpty;

  Future<void> start() async {
    if (!_active) return;
    final StreakClaimResult? pending = receipt ?? repository.pendingReceipt;
    if (requestedStep == null && pending != null) {
      repository.consumeReceipt();
      if (!_active) return;
      emit(DailyMomentState(step: DailyMomentStep.streak, receipt: pending, balance: repository.balance));
      onStepDone?.call(DailyMomentStep.streak);
      return;
    }
    await _load(requestedStep ?? DailyMomentStep.streak);
  }

  String? _loadedUtcDay;
  String get _utcDay => repository.now().toUtc().toIso8601String().substring(0, 10);

  Future<void> _load(DailyMomentStep step) async {
    if (!_active) return;
    emit(DailyMomentState(step: step, busy: true, balance: repository.balance));
    try {
      if (step == DailyMomentStep.streak) {
        final result = await repository.claimStreak();
        if (!_active) return;
        if (result != null) {
          repository.consumeReceipt();
          emit(DailyMomentState(step: step, receipt: result, balance: repository.balance));
          onStepDone?.call(step);
        } else if (requestedStep == null) {
          await _load(DailyMomentStep.chest);
        } else {
          emit(DailyMomentState(step: step, unavailable: true, balance: repository.balance));
        }
        return;
      }
      await repository.refresh();
      if (!_active) return;
      _loadedUtcDay = _utcDay;
      final DailyChestStatus? chest = repository.chest;
      final bool unavailable = switch (step) {
        DailyMomentStep.streak => true,
        DailyMomentStep.chest => chest == null || chest.opened,
        DailyMomentStep.spin => !repository.freeSpinAvailable,
      };
      if (unavailable && requestedStep != step) {
        if (step == DailyMomentStep.chest) {
          await _load(DailyMomentStep.spin);
        } else {
          emit(DailyMomentState(done: true, balance: repository.balance));
        }
        return;
      }
      emit(
        DailyMomentState(
          step: step,
          unavailable: unavailable,
          chestCost: chest?.nextCost ?? 0,
          balance: repository.balance,
        ),
      );
    } catch (_) {
      if (_active) emit(DailyMomentState(step: step, error: true, balance: repository.balance));
    }
  }

  Future<void> primary() async {
    if (!_active || state.busy || state.done || state.unavailable) return;
    final DailyMomentStep? step = state.step;
    if (step == null) return;
    if (state.hasReceipt) {
      if (step == DailyMomentStep.spin) {
        emit(DailyMomentState(done: true, balance: repository.balance));
      } else {
        await _load(step == DailyMomentStep.streak ? DailyMomentStep.chest : DailyMomentStep.spin);
      }
      return;
    }
    if (state.error) {
      await _load(step);
      return;
    }
    if (_loadedUtcDay != _utcDay) {
      await _load(step);
      return;
    }
    final int maxCost = state.chestCost;
    emit(DailyMomentState(step: step, busy: true, chestCost: maxCost, balance: repository.balance));
    try {
      int? coins;
      String? itemId;
      if (step == DailyMomentStep.chest) {
        final DailyChestResult result = await repository.openChest(maxCost: maxCost);
        if (!_active) return;
        if (result is ChestWon) {
          coins = result.win.coins;
          itemId = result.win.itemId;
        } else if (result is ChestRefused) {
          emit(
            DailyMomentState(
              step: step,
              unavailable: result.refusal == ChestRefusal.alreadyOpened,
              error: result.refusal != ChestRefusal.alreadyOpened,
              chestCost: result.price ?? maxCost,
              balance: repository.balance,
            ),
          );
          return;
        }
      } else if (step == DailyMomentStep.spin) {
        final SpinWheelResult result = await repository.takeFreeSpin();
        if (!_active) return;
        if (result is SpinWon) {
          coins = result.win.coins;
          itemId = result.win.itemId;
        } else if (result is SpinRefused) {
          emit(DailyMomentState(step: step, unavailable: true, balance: repository.balance));
          return;
        }
      }
      if (!_active) return;
      emit(
        DailyMomentState(
          step: step,
          error: coins == null && itemId == null,
          coins: coins,
          itemId: itemId,
          chestCost: maxCost,
          balance: repository.balance,
        ),
      );
      if (coins != null || itemId != null) onStepDone?.call(step);
    } catch (_) {
      if (_active) emit(DailyMomentState(step: step, error: true, chestCost: maxCost, balance: repository.balance));
    }
  }

  void stop() => _closedByUser = true;

  @override
  Future<void> close() async {
    await _accountSubscription.cancel();
    await super.close();
  }
}
