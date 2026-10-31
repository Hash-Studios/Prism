import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WallMetadataHistoryState {
  const WallMetadataHistoryState({
    this.edits = const [],
    this.cursor,
    this.loading = true,
    this.busy = false,
    this.failure,
    this.revertedCount = 0,
  });

  final List<WallMetadataAudit> edits;
  final String? cursor;
  final bool loading;
  final bool busy;
  final WallMetadataFailure? failure;
  final int revertedCount;
}

class WallMetadataHistoryCubit extends Cubit<WallMetadataHistoryState> {
  WallMetadataHistoryCubit(this._actions, {required this.wallDocId}) : super(const WallMetadataHistoryState());

  final WallMetadataActions _actions;
  final String wallDocId;
  String? _revision;
  String? _operationAudit;
  String? _operationId;

  Future<void> load({bool more = false}) async {
    if (state.busy || (more && state.cursor == null)) return;
    final WallMetadataHistoryState before = state;
    emit(
      WallMetadataHistoryState(
        edits: more ? before.edits : const [],
        loading: !more,
        busy: true,
        revertedCount: before.revertedCount,
      ),
    );
    try {
      if (!more) {
        _revision = (await _actions.load(wallDocId, approved: true)).revision;
        _operationAudit = null;
        _operationId = null;
      }
      final WallMetadataAuditPage page = await _actions.listEdits(wallDocId, cursor: more ? before.cursor : null);
      if (isClosed) return;
      emit(
        WallMetadataHistoryState(
          edits: <WallMetadataAudit>[if (more) ...before.edits, ...page.edits],
          cursor: page.cursor,
          loading: false,
          revertedCount: before.revertedCount,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        WallMetadataHistoryState(
          edits: before.edits,
          cursor: before.cursor,
          loading: false,
          failure: _failure(error),
          revertedCount: before.revertedCount,
        ),
      );
    }
  }

  Future<void> revert(WallMetadataAudit audit) async {
    if (state.busy || !audit.canRevert || _revision == null || state.failure != null) return;
    if (_operationAudit != audit.id) {
      _operationAudit = audit.id;
      _operationId = newWallMetadataOperationId();
    }
    final WallMetadataHistoryState before = state;
    emit(
      WallMetadataHistoryState(
        edits: before.edits,
        cursor: before.cursor,
        loading: false,
        busy: true,
        revertedCount: before.revertedCount,
      ),
    );
    try {
      final WallMetadataSnapshot saved = await _actions.revert(
        wallDocId,
        audit.id,
        revision: _revision!,
        operationId: _operationId!,
      );
      if (isClosed) return;
      _revision = saved.revision;
      emit(WallMetadataHistoryState(loading: false, revertedCount: before.revertedCount + 1));
      await load();
    } catch (error) {
      if (isClosed) return;
      emit(
        WallMetadataHistoryState(
          edits: before.edits,
          cursor: before.cursor,
          loading: false,
          failure: _failure(error),
          revertedCount: before.revertedCount,
        ),
      );
    }
  }

  static WallMetadataFailure _failure(Object error) =>
      error is WallMetadataException ? error.failure : WallMetadataFailure.unavailable;
}
