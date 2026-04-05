import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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
                  icon: Icon(JamIcons.chevron_left, color: Theme.of(context).colorScheme.secondary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You blocked $displayName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Proxima Nova',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Their wallpapers and setups are hidden from your feeds and notifications. '
                'You can unblock them any time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Proxima Nova',
                  fontSize: 14,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () async {
                  final UserBlockRepository repo = getIt<UserBlockRepository>();
                  final result = await repo.unblockUser(targetUserId: targetUserId);
                  if (!context.mounted) {
                    return;
                  }
                  if (result.isFailure) {
                    toasts.error(result.failure?.toString() ?? 'Could not unblock');
                    unawaited(analytics.track(const UserBlockActionEvent(action: 'unblock', result: 'failure')));
                    return;
                  }
                  unawaited(analytics.track(const UserBlockActionEvent(action: 'unblock', result: 'success')));
                  toasts.codeSend('User unblocked');
                },
                child: const Text('Unblock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
