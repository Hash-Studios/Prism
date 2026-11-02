import 'dart:async';
import 'dart:io';

import 'package:Prism/features/wallpaper_upload/data/resubmission_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ResubmissionState {
  const ResubmissionState({this.preparation, this.loading = true, this.failed = false});
  final ResubmissionPreparation? preparation;
  final bool loading;
  final bool failed;
}

class ResubmissionCubit extends Cubit<ResubmissionState> {
  ResubmissionCubit(this._repository, {required this.uid, required this.email}) : super(const ResubmissionState());
  final ResubmissionRepository _repository;
  final String uid;
  final String email;
  File? _temporaryOriginal;

  Future<void> _clearTemporaryOriginal() async {
    final file = _temporaryOriginal;
    _temporaryOriginal = null;
    if (file != null) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        return;
      }
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    await _clearTemporaryOriginal();
  }

  Future<void> load(String docId) async {
    emit(const ResubmissionState());
    try {
      final preparation = await _repository.prepare(docId, uid: uid, email: email);
      await _clearTemporaryOriginal();
      if (preparation.temporaryOriginal) _temporaryOriginal = preparation.original;
      if (isClosed) {
        await _clearTemporaryOriginal();
        return;
      }
      if (!isClosed) emit(ResubmissionState(preparation: preparation, loading: false));
    } catch (_) {
      if (!isClosed) emit(const ResubmissionState(loading: false, failed: true));
    }
  }

  void chooseImage(File file) {
    unawaited(_clearTemporaryOriginal());
    final preparation = state.preparation;
    if (preparation != null) {
      emit(
        ResubmissionState(
          loading: false,
          preparation: ResubmissionPreparation(seed: preparation.seed, original: file),
        ),
      );
    }
  }
}
