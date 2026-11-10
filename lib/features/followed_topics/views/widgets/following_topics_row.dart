import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/followed_topics/views/topic_copy.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The "Following" row on Home: one chip per followed topic, with a dot when new walls landed since the user last
/// opened it. Nothing for a guest, with no followed topics, or when the layout setting turns it off.
class FollowingTopicsRow extends StatelessWidget {
  const FollowingTopicsRow({super.key});

  @override
  Widget build(BuildContext context) =>
      getIt.isRegistered<FollowedTopicsStore>() && getIt.isRegistered<LayoutPrefsStore>()
      ? const _FollowingRow()
      : const SizedBox.shrink();
}

class _FollowingRow extends StatefulWidget {
  const _FollowingRow();

  @override
  State<_FollowingRow> createState() => _FollowingRowState();
}

class _FollowingRowState extends State<_FollowingRow> with WidgetsBindingObserver {
  final FollowedTopicsStore _store = getIt<FollowedTopicsStore>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_store.ensureLoaded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Home stays alive for the whole session: pick up new walls, other devices' follows and a time zone change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_store.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LayoutPrefs>(
      valueListenable: getIt<LayoutPrefsStore>(),
      builder: (context, prefs, _) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final List<FollowedTopic> topics = _store.topics;
          if (!prefs.followingRow || topics.isEmpty) return const SizedBox.shrink();
          return _Row(topics: topics, store: _store);
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.topics, required this.store});

  final List<FollowedTopic> topics;
  final FollowedTopicsStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.followingRowLabel,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.only(top: PrismSpace.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismFeedLayout.gridSpacing + PrismSpace.xs),
              child: PrismSectionHeader(title: l10n.followingRowTitle, small: true, padding: EdgeInsets.zero),
            ),
            // The row is 44 tall, like the mood chips. Up to 2x text the compact label still fits its pill.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 2,
              child: SizedBox(
                height: prismTapTarget(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: PrismFeedLayout.gridSpacing + PrismSpace.xxs),
                  itemCount: topics.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => _TopicChip(topic: topics[index], isNew: store.hasNew(topics[index])),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic, required this.isNew});

  final FollowedTopic topic;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String name = topic.title(l10n);
    return Semantics(
      container: true,
      label: isNew ? l10n.topicNewWallpapers(name) : name,
      button: true,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: PrismChip(
        label: name,
        compact: true,
        leading: isNew ? const _NewDot() : null,
        onTap: () => _open(context),
      ),
    );
  }

  void _open(BuildContext context) {
    unawaited(context.router.push(topic.route(source: 'following')));
  }
}

class _NewDot extends StatelessWidget {
  const _NewDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
  );
}
