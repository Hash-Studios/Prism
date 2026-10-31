import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter/widgets.dart';

/// Hides a directory card or row as soon as the viewer blocks its creator, without a reload.
class VisibleDirectoryCreator extends StatefulWidget {
  const VisibleDirectoryCreator({super.key, required this.uid, required this.child});

  final String uid;
  final Widget child;

  @override
  State<VisibleDirectoryCreator> createState() => _VisibleDirectoryCreatorState();
}

class _VisibleDirectoryCreatorState extends State<VisibleDirectoryCreator> {
  late BlockedCreators _blocked;
  late final StreamSubscription<BlockedCreators> _subscription;

  @override
  void initState() {
    super.initState();
    final UserBlockRepository blocks = getIt<UserBlockRepository>();
    _blocked = blocks.blockedCreators;
    _subscription = blocks.watchBlockedCreators().listen((blocked) => setState(() => _blocked = blocked));
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlockedCreatorsFilter.hidesCreatorUid(widget.uid, _blocked) ? const SizedBox.shrink() : widget.child;
}
