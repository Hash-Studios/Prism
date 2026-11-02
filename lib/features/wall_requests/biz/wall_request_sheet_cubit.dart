import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/domain/repositories/wall_requests_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class WallRequestSheetState {
  const WallRequestSheetState();
}

final class WallRequestSheetEditing extends WallRequestSheetState {
  const WallRequestSheetEditing({this.error});

  final WallRequestError? error;
}

final class WallRequestSheetBusy extends WallRequestSheetState {
  const WallRequestSheetBusy();
}

/// A close open request exists. The sheet offers "Upvote this instead".
final class WallRequestSheetDuplicate extends WallRequestSheetState {
  const WallRequestSheetDuplicate(this.request, {required this.exact, this.error});

  final WallRequest request;
  final bool exact;
  final WallRequestError? error;
}

/// Done: the request was made, or the user upvoted the duplicate. The sheet closes.
final class WallRequestSheetDone extends WallRequestSheetState {
  const WallRequestSheetDone(this.request, {required this.upvoted});

  final WallRequest request;
  final bool upvoted;
}

@injectable
class WallRequestSheetCubit extends Cubit<WallRequestSheetState> {
  WallRequestSheetCubit(this._repository) : super(const WallRequestSheetEditing());

  final WallRequestsRepository _repository;

  Future<void> submit({
    required String text,
    required List<String> tags,
    required WallRequestSourceValue source,
    bool force = false,
  }) async {
    if (state is WallRequestSheetBusy) return;
    final WallRequestSheetState before = state;
    emit(const WallRequestSheetBusy());
    try {
      final CreateWallRequestResult result = await _repository.create(text: text, tags: tags, force: force);
      if (isClosed) return;
      switch (result) {
        case WallRequestCreated(:final WallRequest request):
          analytics.track(WallRequestCreatedEvent(source: source, tagCount: tags.length, forced: force));
          emit(WallRequestSheetDone(request, upvoted: false));
        case WallRequestDuplicate(:final WallRequest request, :final bool exact):
          emit(WallRequestSheetDuplicate(request, exact: exact));
      }
    } on WallRequestException catch (e) {
      _fail(before, e.error);
    } catch (error, stackTrace) {
      logger.w('[WallRequestSheetCubit] submit failed', error: error, stackTrace: stackTrace);
      _fail(before, WallRequestError.unknown);
    }
  }

  Future<void> upvoteInstead() async {
    final WallRequestSheetState current = state;
    if (current is! WallRequestSheetDuplicate) return;
    final WallRequest request = current.request;
    if (request.voted || !request.canVote) {
      emit(WallRequestSheetDone(request, upvoted: request.voted));
      return;
    }
    emit(const WallRequestSheetBusy());
    try {
      final int count = await _repository.setVote(request.id, vote: true);
      analytics.track(WallRequestDuplicateUpvotedEvent(exact: current.exact));
      if (!isClosed) emit(WallRequestSheetDone(request.copyWith(voted: true, voteCount: count), upvoted: true));
    } on WallRequestException catch (e) {
      _fail(current, e.error);
    } catch (error, stackTrace) {
      logger.w('[WallRequestSheetCubit] upvote failed', error: error, stackTrace: stackTrace);
      _fail(current, WallRequestError.unknown);
    }
  }

  /// Back to the text field from the duplicate card.
  void edit() => emit(const WallRequestSheetEditing());

  void _fail(WallRequestSheetState before, WallRequestError error) {
    if (isClosed) return;
    emit(
      before is WallRequestSheetDuplicate
          ? WallRequestSheetDuplicate(before.request, exact: before.exact, error: error)
          : WallRequestSheetEditing(error: error),
    );
  }
}
