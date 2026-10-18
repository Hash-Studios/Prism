import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/quests/domain/repositories/quests_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'quests_event.j.dart';
part 'quests_state.j.dart';
part 'quests_bloc.j.freezed.dart';

@injectable
class QuestsBloc extends Bloc<QuestsEvent, QuestsState> {
  QuestsBloc(this._repository) : super(const QuestsState()) {
    on<_Started>(_onStarted);
    on<_Refreshed>(_onRefreshed);
    on<_AwardsShown>((_, _) => _repository.consumeAwards());
  }

  final QuestsRepository _repository;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// [quests] when it is for the current UTC day. Yesterday's quests are hidden until the server sends today's.
  QuestState? _today(QuestState? quests) => quests != null && quests.dayKey == economyDayKey(clock()) ? quests : null;

  Future<void> _onStarted(_Started event, Emitter<QuestsState> emit) async {
    unawaited(_repository.refresh());
    await Future.wait(<Future<void>>[
      emit.forEach<QuestState?>(_repository.watchQuests(), onData: (quests) => state.copyWith(quests: _today(quests))),
      emit.forEach<List<QuestAward>>(_repository.watchAwards(), onData: (awards) => state.copyWith(awards: awards)),
    ]);
  }

  Future<void> _onRefreshed(_Refreshed event, Emitter<QuestsState> emit) async {
    final QuestState? today = _today(state.quests);
    if (today != state.quests) emit(state.copyWith(quests: today));
    await _repository.refresh();
  }
}
