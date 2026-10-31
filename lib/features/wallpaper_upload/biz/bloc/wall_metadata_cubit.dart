import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum WallMetadataStatus { loading, ready, saving, saved, failure }

class WallMetadataState {
  const WallMetadataState({
    this.status = WallMetadataStatus.loading,
    this.snapshot,
    this.draft,
    this.failure,
    this.formVersion = 0,
  });

  final WallMetadataStatus status;
  final WallMetadataSnapshot? snapshot;
  final PendingWallMetadata? draft;
  final WallMetadataFailure? failure;
  final int formVersion;

  bool get busy => status == WallMetadataStatus.loading || status == WallMetadataStatus.saving;
  bool get dirty => snapshot != null && draft != null && snapshot!.metadata != draft;
  bool get needsReload => switch (failure) {
    WallMetadataFailure.conflict || WallMetadataFailure.statusChanged || WallMetadataFailure.missing => true,
    _ => false,
  };
}

class WallMetadataCubit extends Cubit<WallMetadataState> {
  WallMetadataCubit(this._actions, {required this.wallDocId, required this.approved})
    : super(const WallMetadataState());

  final WallMetadataActions _actions;
  final String wallDocId;
  final bool approved;
  String? _operationId;
  PendingWallMetadata? _operationDraft;

  Future<void> load() async {
    if (state.status == WallMetadataStatus.saving) return;
    emit(WallMetadataState(snapshot: state.snapshot, draft: state.draft, formVersion: state.formVersion));
    try {
      final WallMetadataSnapshot snapshot = await _actions.load(wallDocId, approved: approved);
      if (isClosed) return;
      _operationId = null;
      _operationDraft = null;
      emit(
        WallMetadataState(
          status: WallMetadataStatus.ready,
          snapshot: snapshot,
          draft: snapshot.metadata,
          formVersion: state.formVersion + 1,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        WallMetadataState(
          status: WallMetadataStatus.failure,
          snapshot: state.snapshot,
          draft: state.draft,
          failure: _failure(error),
          formVersion: state.formVersion,
        ),
      );
    }
  }

  void change(PendingWallMetadata draft) {
    if (state.busy || state.snapshot == null) return;
    final PendingWallMetadata next = approved
        ? PendingWallMetadata(text: draft.text, category: state.snapshot!.metadata.category)
        : draft;
    emit(
      WallMetadataState(
        status: WallMetadataStatus.ready,
        snapshot: state.snapshot,
        draft: next,
        failure: state.needsReload ? state.failure : null,
        formVersion: state.formVersion,
      ),
    );
  }

  Future<void> save() async {
    final WallMetadataSnapshot? expected = state.snapshot;
    final PendingWallMetadata? draft = state.draft;
    if (state.busy || state.needsReload || expected == null || draft == null || !state.dirty) return;
    if (!submissionMetadataIsValid(
      SubmissionMetadata(
        title: draft.text.title,
        description: draft.text.description,
        category: draft.category,
        tags: draft.text.tags,
      ),
    )) {
      emit(
        WallMetadataState(
          status: WallMetadataStatus.failure,
          snapshot: expected,
          draft: draft,
          failure: WallMetadataFailure.invalid,
          formVersion: state.formVersion,
        ),
      );
      return;
    }
    if (_operationDraft != draft) {
      _operationId = newWallMetadataOperationId();
      _operationDraft = draft;
    }
    emit(
      WallMetadataState(
        status: WallMetadataStatus.saving,
        snapshot: expected,
        draft: draft,
        formVersion: state.formVersion,
      ),
    );
    try {
      final WallMetadataSnapshot saved = await _actions.save(
        wallDocId,
        draft,
        expected: expected,
        operationId: _operationId!,
      );
      if (isClosed) return;
      final List<String> fields = expected.metadata.changedFields(draft, approved: approved);
      if (approved) {
        analytics.track(WallApprovedMetadataEditedEvent(assetId: wallDocId, fields: fields));
      } else {
        analytics.track(WallPendingEditedEvent(assetId: wallDocId, fields: fields));
      }
      emit(
        WallMetadataState(
          status: WallMetadataStatus.saved,
          snapshot: saved,
          draft: saved.metadata,
          formVersion: state.formVersion,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        WallMetadataState(
          status: WallMetadataStatus.failure,
          snapshot: expected,
          draft: draft,
          failure: _failure(error),
          formVersion: state.formVersion,
        ),
      );
    }
  }

  static WallMetadataFailure _failure(Object error) =>
      error is WallMetadataException ? error.failure : WallMetadataFailure.unavailable;
}
