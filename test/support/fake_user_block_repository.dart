import 'dart:async';

import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:rxdart/rxdart.dart';

class FakeUserBlockRepository implements UserBlockRepository {
  FakeUserBlockRepository.pending();

  final BehaviorSubject<BlockedCreators> _controller = BehaviorSubject<BlockedCreators>.seeded(
    const UnknownBlockedCreators(),
  );
  Completer<BlockedCreators> _initialLoad = Completer<BlockedCreators>();

  Set<String> _cached = <String>{};
  List<BlockedUserListRow> blockedRows = const <BlockedUserListRow>[];
  bool _hasLoaded = false;

  void completeInitial(Set<String> blocked) {
    _cached = blocked;
    _hasLoaded = true;
    if (!_initialLoad.isCompleted) {
      _initialLoad.complete(KnownBlockedCreators(blocked));
    }
    _controller.add(KnownBlockedCreators(blocked));
  }

  /// Ends the initial wait the way the real repository's timeout does: the list stays unknown.
  void timeOutInitialLoad() {
    if (!_initialLoad.isCompleted) _initialLoad.complete(const UnknownBlockedCreators());
  }

  void emitUnknown() {
    _hasLoaded = false;
    _initialLoad = Completer<BlockedCreators>();
    _controller.add(const UnknownBlockedCreators());
  }

  @override
  BlockedCreators get blockedCreators => _hasLoaded ? KnownBlockedCreators(_cached) : const UnknownBlockedCreators();

  @override
  Future<void> clearForUser(String userId) async {}

  @override
  Future<Result<void>> blockUser({required String targetUserId}) async => Result.success(null);

  @override
  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList() async => Result.success(blockedRows);

  @override
  Future<BlockedCreators> loadBlockedCreators() async {
    if (!_hasLoaded) {
      return _initialLoad.future;
    }
    return KnownBlockedCreators(_cached);
  }

  @override
  Future<Result<void>> unblockUser({required String targetUserId}) async => Result.success(null);

  @override
  Stream<BlockedCreators> watchBlockedCreators() => _controller.stream;
}
