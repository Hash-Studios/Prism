import 'package:flutter/foundation.dart';

/// What this device knows about the creators the signed-in user blocked.
sealed class BlockedCreators {
  const BlockedCreators();

  /// Whether content by the trimmed, non-empty [creatorUid] must stay hidden.
  bool blocks(String creatorUid);
}

/// The block list has not loaded for this session, so any creator may be blocked.
final class UnknownBlockedCreators extends BlockedCreators {
  const UnknownBlockedCreators();

  @override
  bool blocks(String creatorUid) => true;
}

/// The block list loaded for this session. [uids] is the complete set.
final class KnownBlockedCreators extends BlockedCreators {
  KnownBlockedCreators(Iterable<String> uids) : uids = Set<String>.unmodifiable(uids);

  final Set<String> uids;

  @override
  bool blocks(String creatorUid) => uids.contains(creatorUid);

  @override
  bool operator ==(Object other) => other is KnownBlockedCreators && setEquals(other.uids, uids);

  @override
  int get hashCode => Object.hashAllUnordered(uids);
}
