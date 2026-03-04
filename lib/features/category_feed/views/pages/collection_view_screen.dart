import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CollectionViewScreen extends StatelessWidget {
  const CollectionViewScreen({super.key, required this.collectionName});

  final String collectionName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: PreferredSize(
        preferredSize: const Size(double.infinity, 55),
        child: HeadingChipBar(current: collectionName.capitalize()),
      ),
      body: FutureBuilder(
        future: getCollectionWithName(collectionName),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return const CollectionViewGrid();
          }
          return const LoadingCards();
        },
      ),
    );
  }
}

extension _StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
