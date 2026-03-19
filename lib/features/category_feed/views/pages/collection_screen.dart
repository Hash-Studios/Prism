import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:flutter/material.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  _CollectionScreenState createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with AutomaticKeepAliveClientMixin {
  late Future<List?> _collectionsFuture;

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
    return FutureBuilder<List?>(
      future: _collectionsFuture,
      builder: (BuildContext context, AsyncSnapshot<List?> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return Center(child: Loader());
          case ConnectionState.none:
            return Center(child: Loader());
          default:
            if (snapshot.hasError) {
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _collectionsFuture = getCollections();
                  });
                  await _collectionsFuture;
                },
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Spacer(),
                    Center(child: Text("Can't connect to the Servers!")),
                    Spacer(),
                  ],
                ),
              );
            } else {
              return CollectionsGrid();
            }
        }
      },
    );
  }
}
