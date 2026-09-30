import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/string_extensions.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/pexels_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallhaven_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class CollectionViewScreen extends StatefulWidget {
  const CollectionViewScreen({super.key, required this.collectionName});

  final String collectionName;

  @override
  State<CollectionViewScreen> createState() => _CollectionViewScreenState();
}

class _CollectionViewScreenState extends State<CollectionViewScreen> {
  late final Future<void> _collectionFuture = getCollectionWithName(widget.collectionName);

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
        final bloc = context.read<CategoryFeedBloc>();
        final categories = bloc.state.categories;
        if (categories.isEmpty) {
          return;
        }
        final selected = categories.firstWhere(
          (category) => category.name.trim().toLowerCase() == _decodedCategoryName.toLowerCase(),
          orElse: () => categories.first,
        );
        bloc.add(CategoryFeedEvent.categorySelected(category: selected));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_isCategoryView ? _decodedCategoryName : widget.collectionName).inCaps;
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
    return FutureBuilder<void>(
      future: _collectionFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
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
            onRefresh: () async => context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.refreshRequested()),
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
          case WallpaperSource.downloaded:
          case WallpaperSource.unknown:
            return const WallpaperGrid();
        }
      },
    );
  }
}
