import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'badges_event.dart';
part 'badges_state.dart';

@injectable
class BadgesBloc extends Bloc<BadgesEvent, BadgesState> {
  BadgesBloc(this._repository) : super(BadgesState(earnedIds: _sessionIds())) {
    on<BadgesLoaded>(_onLoaded);
  }

  final BadgeRepository _repository;

  static List<String> _sessionIds() => app_state.prismUser.badges.map((Badge b) => b.id).toList(growable: false);

  Future<void> _onLoaded(BadgesLoaded event, Emitter<BadgesState> emit) async {
    emit(state.copyWith(status: BadgesStatus.loading, earnedIds: _sessionIds()));
    final result = await _repository.check();
    result.fold(
      onSuccess: (List<Badge> badges) => emit(
        state.copyWith(status: BadgesStatus.success, earnedIds: badges.map((Badge b) => b.id).toList(growable: false)),
      ),
      // Keep the badges already in the session: a failed check must not look like "no badges".
      onFailure: (_) => emit(state.copyWith(status: BadgesStatus.failure)),
    );
  }
}
