import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
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
          return Center(child: Loader());
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _collectionsFuture = getCollections();
              });
              await _collectionsFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[
                SizedBox(height: 200),
                Center(child: Text("Can't connect to the Servers!")),
              ],
            ),
          );
        }
        return CollectionsGrid();
      },
    );
  }
}
