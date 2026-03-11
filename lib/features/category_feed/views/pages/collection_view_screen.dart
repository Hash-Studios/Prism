import 'dart:async';

import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/views/category_feed_bloc_adapter.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/pexels_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallhaven_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class CollectionViewScreen extends StatefulWidget {
  const CollectionViewScreen({super.key, required this.collectionName});

  final String collectionName;

  @override
  State<CollectionViewScreen> createState() => _CollectionViewScreenState();
}

class _CollectionViewScreenState extends State<CollectionViewScreen> {
  bool get _isCategoryView => widget.collectionName.startsWith('category:');

  String get _decodedCategoryName {
    final encoded = widget.collectionName.substring('category:'.length);
    return Uri.decodeComponent(encoded).trim();
  }

  @override
  void initState() {
    super.initState();
    if (_isCategoryView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final choices = context.categoryChoiceList(listen: false);
        final selected = choices.firstWhere(
          (choice) => (choice.name ?? '').trim().toLowerCase() == _decodedCategoryName.toLowerCase(),
          orElse: () => choices.first,
        );
        unawaited(context.categoryChangeWallpaperFuture(selected, 'r'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCategoryView ? _decodedCategoryName.capitalize() : widget.collectionName.capitalize();
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: PreferredSize(
        preferredSize: const Size(double.infinity, 55),
        child: HeadingChipBar(current: title),
      ),
      body: _isCategoryView ? const _CategoryFeedContent() : _buildCollectionContent(),
    );
  }

  Widget _buildCollectionContent() {
    return FutureBuilder(
      future: getCollectionWithName(widget.collectionName),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          return const CollectionViewGrid();
        }
        return const LoadingCards();
      },
    );
  }
}

class _CategoryFeedContent extends StatelessWidget {
  const _CategoryFeedContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryFeedBloc, CategoryFeedState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
          return const LoadingCards();
        }
        if (state.status == LoadStatus.failure) {
          return RefreshIndicator(
            onRefresh: () async {
              final choice = context.categorySelectedChoice(listen: false);
              await context.categoryChangeWallpaperFuture(choice, 'r');
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
        }
        final source = state.selectedCategory?.source ?? WallpaperSource.prism;
        switch (source) {
          case WallpaperSource.wallhaven:
            return const WallHavenGrid();
          case WallpaperSource.pexels:
            return const PexelsGrid();
          case WallpaperSource.prism:
            return const WallpaperGrid();
          case WallpaperSource.wallOfTheDay:
          case WallpaperSource.downloaded:
          case WallpaperSource.unknown:
            return const WallpaperGrid();
        }
      },
    );
  }
}

extension _StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
