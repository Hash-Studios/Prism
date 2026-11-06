import 'dart:async';

import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the creator has a desktop version of this wall waiting for review.
/// A null repository or a failed watch reads as false.
class DesktopPendingCubit extends Cubit<bool> {
  DesktopPendingCubit(DesktopSubmissionRepository? repository, {required String wallDocId, required String uid})
    : super(false) {
    _subscription = repository
        ?.watchPendingForWall(wallDocId: wallDocId, uid: uid)
        .listen(_emitPending, onError: (Object _) => _emitPending(false));
  }

  StreamSubscription<bool>? _subscription;

  void _emitPending(bool pending) {
    if (!isClosed) emit(pending);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
