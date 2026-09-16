import 'dart:async';

import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';

class FakeUserBlockRepository implements UserBlockRepository {
  FakeUserBlockRepository.pending();

  final StreamController<Set<String>> _controller = StreamController<Set<String>>.broadcast();
  final Completer<Set<String>> _initialLoad = Completer<Set<String>>();

  Set<String> _cached = <String>{};
  bool _hasLoaded = false;

  void completeInitial(Set<String> blocked) {
    _cached = blocked;
    _hasLoaded = true;
    if (!_initialLoad.isCompleted) {
      _initialLoad.complete(blocked);
    }
    _controller.add(blocked);
  }

  @override
  Set<String> get cachedBlockedCreatorEmails => _cached;

  @override
  Future<Result<void>> blockUser({required String targetUserId}) async => Result.success(null);

  @override
  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList() async =>
      Result.success(const <BlockedUserListRow>[]);

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) async {
    if (waitForInitialLoad && !_hasLoaded) {
      return _initialLoad.future;
    }
    return _cached;
  }

  @override
  bool get hasLoadedBlockedCreatorEmails => _hasLoaded;

  @override
  Future<Result<void>> unblockUser({required String targetUserId}) async => Result.success(null);

  @override
  Stream<Set<String>> watchBlockedCreatorEmails() => _controller.stream;
}
