import 'dart:async';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/string_extensions.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
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
  late Future<void> _collectionFuture = getCollectionWithName(widget.collectionName);

  bool get _isCategoryView => widget.collectionName.startsWith('category:');

  String get _decodedCategoryName {
    final encoded = widget.collectionName.substring('category:'.length);
    return Uri.decodeComponent(encoded).trim();
  }

  @override
  void initState() {
    super.initState();
    if (_isCategoryView) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_selectCategory()));
    }
  }

  /// Selects this screen's category. When the category list is not loaded yet it is requested first.
  Future<void> _selectCategory() async {
    if (!mounted) {
      return;
    }
    final bloc = context.read<CategoryFeedBloc>();
    if (bloc.state.categories.isEmpty) {
      final loaded = bloc.stream.firstWhere(
        (state) => state.categories.isNotEmpty || state.status == LoadStatus.failure,
      );
      bloc.add(const CategoryFeedEvent.started());
      await loaded.timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
    }
    final categories = bloc.state.categories;
    if (!mounted || categories.isEmpty) {
      return;
    }
    final selected = categories.firstWhere(
      (category) => category.name.trim().toLowerCase() == _decodedCategoryName.toLowerCase(),
      orElse: () => categories.first,
    );
    final settled = bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
    bloc.add(CategoryFeedEvent.categorySelected(category: selected));
    await settled.timeout(const Duration(seconds: 30), onTimeout: () => bloc.state);
  }

  Future<void> _retryCollection() {
    setState(() => _collectionFuture = getCollectionWithName(widget.collectionName));
    return _collectionFuture.catchError((Object _) {});
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
      body: _isCategoryView
          ? _CategoryFeedContent(categoryName: _decodedCategoryName, onRetry: _selectCategory)
          : _buildCollectionContent(),
    );
  }

  Widget _buildCollectionContent() {
    return FutureBuilder<void>(
      future: _collectionFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingCards(useFeedLayout: true);
        }
        if (snapshot.hasError) {
          return RefreshableGlintState(
            kind: GlintStateKind.error,
            title: "Couldn't load this collection",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => unawaited(_retryCollection()),
            onRefresh: _retryCollection,
          );
        }
        return const CollectionViewGrid();
      },
    );
  }
}

class _CategoryFeedContent extends StatelessWidget {
  const _CategoryFeedContent({required this.categoryName, required this.onRetry});

  final String categoryName;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryFeedBloc, CategoryFeedState>(
      builder: (context, state) {
        // The bloc is shared, so until it selects this category it still holds the previous one. A name that is
        // not in the list falls back to the first category, as `_selectCategory` does.
        final List<String> names = state.categories.map((category) => category.name.trim().toLowerCase()).toList();
        final String wanted = categoryName.toLowerCase();
        final String? expected = names.isEmpty ? null : (names.contains(wanted) ? wanted : names.first);
        final bool showsThisCategory =
            expected != null && state.selectedCategory?.name.trim().toLowerCase() == expected;
        if (!showsThisCategory && !(state.items.isEmpty && state.status == LoadStatus.failure)) {
          return const LoadingCards(useFeedLayout: true);
        }
        if (state.items.isEmpty && (state.status == LoadStatus.initial || state.status == LoadStatus.loading)) {
          return const LoadingCards(useFeedLayout: true);
        }
        if (state.items.isEmpty && state.status == LoadStatus.failure) {
          return RefreshableGlintState(
            kind: GlintStateKind.error,
            title: "Couldn't load wallpapers",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => unawaited(onRetry()),
            onRefresh: () {
              PrismHaptics.impact();
              return onRetry();
            },
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
