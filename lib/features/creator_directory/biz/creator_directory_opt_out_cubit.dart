import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

typedef OptOutState = ({bool loaded, bool optOut});

/// The Settings switch for leaving the creator directory. A failed write goes back and returns false.
@injectable
class CreatorDirectoryOptOutCubit extends Cubit<OptOutState> {
  CreatorDirectoryOptOutCubit(this._repository) : super((loaded: false, optOut: false));

  final CreatorDirectoryRepository _repository;

  Future<void> load() async {
    bool optOut = false;
    try {
      optOut = await _repository.isOptedOut();
    } catch (_) {}
    if (!isClosed) emit((loaded: true, optOut: optOut));
  }

  Future<bool> setOptedOut(bool optOut) async {
    final bool previous = state.optOut;
    emit((loaded: true, optOut: optOut));
    try {
      await _repository.setOptedOut(optOut);
      return true;
    } catch (_) {
      if (!isClosed) emit((loaded: true, optOut: previous));
      return false;
    }
  }
}
