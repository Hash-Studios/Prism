import 'dart:typed_data';

import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/domain/desktop_submit_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'desktop_upload_cubit.freezed.dart';

@freezed
abstract class DesktopUploadState with _$DesktopUploadState {
  const factory DesktopUploadState({
    @Default(false) bool sending,
    @Default(false) bool sent,
    DesktopSubmitFailure? failure,
  }) = _DesktopUploadState;
}

class DesktopUploadCubit extends Cubit<DesktopUploadState> {
  DesktopUploadCubit(this._repository) : super(const DesktopUploadState());

  final DesktopSubmissionRepository _repository;

  Future<void> submit({required String wallDocId, required Uint8List bytes}) async {
    if (isClosed) return;
    emit(state.copyWith(sending: true, failure: null));
    try {
      await _repository.submit(wallDocId: wallDocId, bytes: bytes);
      if (isClosed) return;
      emit(state.copyWith(sent: true));
    } on DesktopSubmitException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(sending: false, failure: error.failure));
    } on Object {
      if (isClosed) return;
      emit(state.copyWith(sending: false, failure: DesktopSubmitFailure.failed));
    }
  }

  void clearFailure() {
    if (state.failure != null) emit(state.copyWith(failure: null));
  }
}
