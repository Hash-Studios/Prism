import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// The "Followed by" line of one profile. Null while it loads. Errors, guests and the viewer's own profile give
/// [FollowedBy.none], so the line stays hidden.
@injectable
class FollowedByCubit extends Cubit<FollowedBy?> {
  FollowedByCubit(this._repository) : super(null);

  final CreatorDirectoryRepository _repository;
  int _load = 0;

  Future<void> load(String creatorUid) async {
    final int load = ++_load;
    emit(null);
    final String viewer = app_state.prismUser.id;
    if (!app_state.prismUser.loggedIn || creatorUid.isEmpty || creatorUid == viewer) {
      emit(FollowedBy.none);
      return;
    }
    FollowedBy result = FollowedBy.none;
    try {
      result = await _repository.followedBy(creatorUid);
    } catch (_) {}
    if (isClosed || load != _load) return;
    emit(app_state.prismUser.loggedIn && app_state.prismUser.id == viewer ? result : FollowedBy.none);
  }
}
