import 'dart:async';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:flutter/material.dart';

/// Shown when the signed-in viewer has blocked this profile’s account.
class BlockedUserProfileShell extends StatefulWidget {
  const BlockedUserProfileShell({
    super.key,
    required this.targetUserId,
    required this.targetEmail,
    required this.displayName,
  });

  final String targetUserId;
  final String targetEmail;
  final String displayName;

  @override
  State<BlockedUserProfileShell> createState() => _BlockedUserProfileShellState();
}

class _BlockedUserProfileShellState extends State<BlockedUserProfileShell> {
  bool _unblocking = false;

  Future<void> _unblock() async {
    setState(() => _unblocking = true);
    await unblockUserWithFeedback(context, widget.targetUserId);
    // On success the profile stream swaps this shell out, so only reset when it is still here.
    if (mounted) setState(() => _unblocking = false);
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Profile',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PrismSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Glint(),
                const SizedBox(height: PrismSpace.md),
                Text(
                  'You blocked ${widget.displayName}',
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.cardTitle(context),
                ),
                const SizedBox(height: 6),
                Text(
                  'Their wallpapers are hidden from your feeds and notifications. You can unblock them any time.',
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.body(context),
                ),
                const SizedBox(height: PrismSpace.md),
                PrismButton(
                  label: 'Unblock',
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
                  loading: _unblocking,
                  onPressed: () => unawaited(_unblock()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
