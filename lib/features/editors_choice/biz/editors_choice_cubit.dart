import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/editors_choice/domain/editors_choice_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class EditorsChoiceState {
  const EditorsChoiceState();
}

final class EditorsChoiceLoading extends EditorsChoiceState {
  const EditorsChoiceLoading();
}

/// [walls] is empty when there are no picks the user can see.
final class EditorsChoiceLoaded extends EditorsChoiceState {
  const EditorsChoiceLoaded(this.walls);

  final List<PrismWallpaper> walls;
}

final class EditorsChoiceFailed extends EditorsChoiceState {
  const EditorsChoiceFailed();
}

/// The Editors' Choice picks, newest pick first.
@injectable
class EditorsChoiceCubit extends Cubit<EditorsChoiceState> {
  EditorsChoiceCubit(this._repository) : super(const EditorsChoiceLoading()) {
    _pickChanges = _repository.watchPickChanges().listen((_) {
      final int? limit = _limit;
      if (limit != null) unawaited(load(limit: limit));
    });
  }

  final EditorsChoiceRepository _repository;
  late final StreamSubscription<void> _pickChanges;
  int? _limit;
  int _loadVersion = 0;

  @override
  Future<void> close() async {
    await _pickChanges.cancel();
    return super.close();
  }

  /// Admin only. Sets or clears one pick. Throws [EditorsChoiceNotEligible] when the server refuses the wall.
  Future<void> setPick({required String wallDocId, required bool picked}) =>
      _repository.setPick(wallDocId: wallDocId, picked: picked);

  /// Loads the newest [limit] picks.
  Future<void> load({required int limit}) async {
    if (isClosed) return;
    _limit = limit;
    final int loadVersion = ++_loadVersion;
    emit(const EditorsChoiceLoading());
    try {
      final List<PrismWallpaper> walls = await _repository.fetchPicks(limit: limit);
      if (!isClosed && loadVersion == _loadVersion) emit(EditorsChoiceLoaded(walls));
    } catch (error, stackTrace) {
      if (loadVersion != _loadVersion) return;
      logger.w('[EditorsChoiceCubit] load failed', error: error, stackTrace: stackTrace);
      if (!isClosed) emit(const EditorsChoiceFailed());
    }
  }
}
