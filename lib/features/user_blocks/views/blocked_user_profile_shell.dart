import 'dart:async';

import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

/// Shown when the signed-in viewer has blocked this profile’s account.
class BlockedUserProfileShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).primaryColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Icon(JamIcons.chevron_left, color: Theme.of(context).colorScheme.secondary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You blocked $displayName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: PrismFonts.proximaNova,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Their wallpapers are hidden from your feeds and notifications. '
                'You can unblock them any time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: PrismFonts.proximaNova,
                  fontSize: 14,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => unawaited(unblockUserWithFeedback(context, targetUserId)),
                child: const Text('Unblock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
