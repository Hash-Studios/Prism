import 'package:Prism/features/creator_fund/domain/creator_fund_repository.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
part 'creator_fund_bloc.j.freezed.dart';

@freezed
abstract class CreatorFundState with _$CreatorFundState {
  const factory CreatorFundState({
    @Default(false) bool loading,
    @Default(false) bool failed,
    CreatorFundStatus? status,
  }) = _CreatorFundState;
}

@freezed
sealed class CreatorFundEvent with _$CreatorFundEvent {
  const factory CreatorFundEvent.load() = LoadCreatorFund;
}

@injectable
class CreatorFundBloc extends Bloc<CreatorFundEvent, CreatorFundState> {
  CreatorFundBloc(this._repository) : super(const CreatorFundState()) {
    on<LoadCreatorFund>((event, emit) async {
      emit(state.copyWith(loading: true, failed: false));
      try {
        final status = await _repository.load();
        emit(state.copyWith(status: status, loading: false));
      } on Exception {
        emit(state.copyWith(loading: false, failed: true));
      }
    });
  }
  final CreatorFundRepository _repository;
}
