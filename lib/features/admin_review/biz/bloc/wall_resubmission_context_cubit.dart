import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WallResubmissionContextState {
  const WallResubmissionContextState({this.contexts = const {}, this.loading = false, this.failed = false});

  final Map<String, WallResubmissionContext> contexts;
  final bool loading;
  final bool failed;
}

class WallResubmissionContextCubit extends Cubit<WallResubmissionContextState> {
  WallResubmissionContextCubit(this._actions) : super(const WallResubmissionContextState());

  final WallMetadataActions _actions;
  int _generation = 0;

  Future<void> load(List<String> ids) async {
    final int generation = ++_generation;
    emit(const WallResubmissionContextState(loading: true));
    try {
      final Map<String, WallResubmissionContext> contexts = await _actions.contexts(ids);
      if (isClosed || generation != _generation) return;
      emit(WallResubmissionContextState(contexts: contexts));
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(const WallResubmissionContextState(failed: true));
    }
  }
}
