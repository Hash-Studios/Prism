import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Confirms and blocks a user; updates session following, unsubscribes FCM artist topic.
Future<void> confirmAndBlockUser({
  required BuildContext context,
  required String targetUserId,
  required String targetEmail,
  String? displayName,
}) async {
  final String name = displayName == null || displayName.trim().isEmpty ? 'this user' : displayName.trim();
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Block user?'),
      content: Text(
        'You will unfollow $name, stop seeing their wallpapers and setups in feeds, '
        'and no longer get notifications about their new posts.',
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block')),
      ],
    ),
  );
  if (ok != true || !context.mounted) {
    return;
  }

  final UserBlockRepository blocks = getIt<UserBlockRepository>();
  final Result<void> result = await blocks.blockUser(targetUserId: targetUserId);
  if (!context.mounted) {
    return;
  }
  if (result.isFailure) {
    toasts.error(result.failure?.toString() ?? 'Could not block user');
    unawaited(analytics.track(const UserBlockActionEvent(action: 'block', result: 'failure')));
    return;
  }

  unawaited(analytics.track(const UserBlockActionEvent(action: 'block', result: 'success')));

  try {
    final String? topicBase = followersTopicFromEmail(targetEmail);
    if (topicBase != null && topicBase.isNotEmpty) {
      await unsubscribeFromTopicSafely(
        FirebaseMessaging.instance,
        '${topicBase}_posts',
        sourceTag: 'user_block.unsubscribe_posts',
      );
    }
  } catch (e, st) {
    logger.w('user_block: FCM unsubscribe failed', error: e, stackTrace: st);
  }

  final SessionRepository session = getIt<SessionRepository>();
  final List<String> following = session.currentUser.following;
  final String targetNorm = targetEmail.trim().toLowerCase();
  final List<String> next = following.where((String e) => e.trim().toLowerCase() != targetNorm).toList(growable: false);
  if (next.length != following.length) {
    await session.patchCurrentUser(following: next);
  }

  toasts.codeSend('User blocked');
}
