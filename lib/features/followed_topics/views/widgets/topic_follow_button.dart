import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/followed_topics/views/topic_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Follow or Following on a category or mood page. A guest gets the sign-in prompt first.
///
/// The button sits on every topic page, so it also clears the topic's new-wall dot on Home when the page opens.
class TopicFollowButton extends StatelessWidget {
  const TopicFollowButton({super.key, required this.topic});

  final FollowedTopic topic;

  @override
  Widget build(BuildContext context) =>
      getIt.isRegistered<FollowedTopicsStore>() ? _FollowButton(topic: topic) : const SizedBox.shrink();
}

class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.topic});

  final FollowedTopic topic;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final FollowedTopicsStore _store = getIt<FollowedTopicsStore>();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_store.ensureLoaded().then((_) => _store.markSeen(widget.topic)));
  }

  Future<void> _toggle() async {
    final AppLocalizations l10n = context.l10n;
    final FollowedTopic topic = widget.topic;
    final String name = topic.title(l10n);
    // Decided before sign-in: an account that already follows the topic must not unfollow it on this tap.
    final bool follow = !_store.isFollowed(topic);
    if (!await requireSignedInAction(context) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _store.ensureLoaded();
      if (!follow) {
        if (await _store.unfollow(topic)) {
          unawaited(analytics.track(TopicUnfollowedEvent(kind: topic.kind.name, topicId: topic.id)));
        } else {
          toasts.error(l10n.topicFollowFailed);
        }
        return;
      }
      if (_store.isFollowed(topic)) return;
      switch (await _store.follow(topic)) {
        case TopicFollowResult.done:
          unawaited(analytics.track(TopicFollowedEvent(kind: topic.kind.name, topicId: topic.id)));
          toasts.success(l10n.topicFollowedToast(name));
        case TopicFollowResult.limit:
          toasts.error(l10n.topicFollowLimit(FollowedTopic.maxFollowed));
        case TopicFollowResult.failed:
          toasts.error(l10n.topicFollowFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final bool following = _store.isFollowed(widget.topic);
        final String name = widget.topic.title(l10n);
        return Semantics(
          container: true,
          button: true,
          toggled: following,
          label: following ? l10n.topicUnfollowHint(name) : l10n.topicFollowHint(name),
          onTap: _busy ? null : () => unawaited(_toggle()),
          excludeSemantics: true,
          child: AnimatedSwitcher(
            duration: context.motion(PrismDurations.fast),
            child: PrismButton(
              key: ValueKey<bool>(following),
              label: following ? l10n.topicFollowing : l10n.topicFollow,
              icon: following ? Icons.check_rounded : Icons.add_rounded,
              variant: following ? PrismButtonVariant.tonal : PrismButtonVariant.primary,
              size: PrismButtonSize.compact,
              onPressed: _busy ? null : () => unawaited(_toggle()),
            ),
          ),
        );
      },
    );
  }
}
