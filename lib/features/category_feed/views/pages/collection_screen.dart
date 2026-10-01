import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:flutter/material.dart';

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
    return FutureBuilder<void>(
      future: _collectionsFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingCards();
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                const SizedBox(height: 120),
                GlintState(
                  kind: GlintStateKind.offline,
                  title: "Can't connect to the Servers!",
                  actionLabel: 'Try again',
                  onAction: () {
                    PrismHaptics.tap();
                    unawaited(retry());
                  },
                ),
              ],
            ),
          );
        }
        return CollectionsGrid();
      },
    );
  }
}
