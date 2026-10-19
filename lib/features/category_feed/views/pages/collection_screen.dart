import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The collections tab: Prism collections first, then the wallpaper categories.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with AutomaticKeepAliveClientMixin {
  late Future<void> _collectionsFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    analytics.track(const CollectionsCheckedEvent());
    _collectionsFuture = getCollections();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Widget header = PrismHeader(title: context.l10n.wallpaperLibraryCollections, showBack: false);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<void>(
          future: _collectionsFuture,
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Column(
                children: <Widget>[
                  header,
                  const Expanded(child: CollectionsSkeleton()),
                ],
              );
            }
            if (snapshot.hasError) {
              Future<void> retry() async {
                setState(() {
                  _collectionsFuture = getCollections();
                });
                await _collectionsFuture;
              }

              return RefreshIndicator(
                onRefresh: () {
                  PrismHaptics.impact();
                  return retry();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(child: header),
                    SliverFillRemaining(
                      child: GlintState(
                        kind: GlintStateKind.offline,
                        title: context.l10n.wallpaperServerUnavailable,
                        body: context.l10n.wallpaperCheckConnection,
                        actionLabel: context.l10n.wallpaperTryAgain,
                        onAction: () {
                          PrismHaptics.tap();
                          unawaited(retry());
                        },
                      ),
                    ),
                  ],
                ),
              );
            }
            return CollectionsGrid(header: header);
          },
        ),
      ),
    );
  }
}
