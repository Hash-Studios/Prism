import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/followed_topics/views/topic_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The Settings row "Topics you follow". It opens the list. A guest follows nothing, so a guest sees no row.
class FollowedTopicsSettingsRow extends StatelessWidget {
  const FollowedTopicsSettingsRow({super.key});

  @override
  Widget build(BuildContext context) =>
      getIt.isRegistered<FollowedTopicsStore>() ? const _SettingsRow() : const SizedBox.shrink();
}

class _SettingsRow extends StatefulWidget {
  const _SettingsRow();

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  final FollowedTopicsStore _store = getIt<FollowedTopicsStore>();

  @override
  void initState() {
    super.initState();
    unawaited(_store.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    if (!app_state.prismUser.loggedIn) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => PrismRow(
        icon: Icons.interests_rounded,
        title: context.l10n.followedTopicsTitle,
        subtitle: context.l10n.followedTopicsCount(_store.topics.length),
        onTap: () => showFollowedTopicsSheet(context),
      ),
    );
  }
}

Future<void> showFollowedTopicsSheet(BuildContext context) =>
    showPrismSheet<void>(context, builder: (_) => const FollowedTopicsSheet());

/// The followed topics, in follow order. A tap opens the topic page; Unfollow removes it.
class FollowedTopicsSheet extends StatelessWidget {
  const FollowedTopicsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final FollowedTopicsStore store = getIt<FollowedTopicsStore>();
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final List<FollowedTopic> topics = store.topics;
        return PrismSheetBody(
          title: l10n.followedTopicsTitle,
          child: topics.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: PrismSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.followedTopicsEmptyTitle, style: PrismTextStyles.cardTitle(context)),
                      const SizedBox(height: PrismSpace.xs),
                      Text(l10n.followedTopicsEmptyBody, style: PrismTextStyles.body(context)),
                    ],
                  ),
                )
              : PrismGroup(
                  children: <Widget>[for (final FollowedTopic topic in topics) _TopicRow(topic: topic, store: store)],
                ),
        );
      },
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.store});

  final FollowedTopic topic;
  final FollowedTopicsStore store;

  Future<void> _unfollow(BuildContext context) async {
    final String failed = context.l10n.topicFollowFailed;
    if (await store.unfollow(topic)) {
      unawaited(analytics.track(TopicUnfollowedEvent(kind: topic.kind.name, topicId: topic.id)));
    } else {
      toasts.error(failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String name = topic.title(l10n);
    return PrismRow(
      title: name,
      subtitle: topic.kindLabel(l10n),
      onTap: () {
        final StackRouter router = context.router;
        Navigator.of(context).pop();
        unawaited(router.push(topic.route(source: 'settings')));
      },
      trailing: Semantics(
        container: true,
        button: true,
        label: l10n.topicUnfollowHint(name),
        excludeSemantics: true,
        child: PrismButton(
          label: l10n.topicUnfollow,
          variant: PrismButtonVariant.ghost,
          size: PrismButtonSize.compact,
          onPressed: () => unawaited(_unfollow(context)),
        ),
      ),
    );
  }
}
