import 'dart:async';

import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/string_extensions.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/category_cover.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as c_data;
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/pexels_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallhaven_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_grid.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/followed_topics/views/widgets/topic_follow_button.dart';
import 'package:Prism/l10n/l10n.dart';
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
  late Future<void> _collectionFuture = c_data.getCollectionWithName(widget.collectionName);

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
    setState(() {
      _collectionFuture = c_data.getCollectionWithName(widget.collectionName);
    });
    return _collectionFuture.catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCategoryView
        ? categoryDisplayName(_decodedCategoryName, context.l10n)
        : widget.collectionName.inCaps;
    final FollowedTopic? topic = _isCategoryView ? FollowedTopic.category(_decodedCategoryName) : null;
    return PrismPage(
      maxContentWidth: double.infinity,
      title: title,
      actions: <Widget>[if (topic != null) TopicFollowButton(topic: topic)],
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
          return _Settle(child: _coverLoading(_collectionCoverUrl(widget.collectionName)));
        }
        if (snapshot.hasError) {
          return _Settle(
            child: RefreshableGlintState(
              kind: GlintStateKind.error,
              title: context.l10n.wallpaperCollectionLoadError,
              body: context.l10n.wallpaperCheckConnection,
              actionLabel: context.l10n.wallpaperTryAgain,
              onAction: () => unawaited(_retryCollection()),
              onRefresh: _retryCollection,
            ),
          );
        }
        return const _Settle(child: CollectionViewGrid());
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
      builder: (context, state) => _Settle(child: _content(context, state)),
    );
  }

  Widget _content(BuildContext context, CategoryFeedState state) {
    // The bloc is shared, so until it selects this category it still holds the previous one. A name that is
    // not in the list falls back to the first category, as `_selectCategory` does.
    final List<String> names = state.categories.map((category) => category.name.trim().toLowerCase()).toList();
    final String wanted = categoryName.toLowerCase();
    final String? expected = names.isEmpty ? null : (names.contains(wanted) ? wanted : names.first);
    final bool showsThisCategory = expected != null && state.selectedCategory?.name.trim().toLowerCase() == expected;
    if (!showsThisCategory && !(state.items.isEmpty && state.status == LoadStatus.failure)) {
      return _coverLoading(_categoryCoverUrl(state.categories, categoryName));
    }
    if (state.items.isEmpty && (state.status == LoadStatus.initial || state.status == LoadStatus.loading)) {
      return _coverLoading(_categoryCoverUrl(state.categories, categoryName));
    }
    if (state.items.isEmpty && state.status == LoadStatus.failure) {
      return RefreshableGlintState(
        kind: GlintStateKind.error,
        title: context.l10n.wallpaperFeedWallsLoadError,
        body: context.l10n.wallpaperCheckConnection,
        actionLabel: context.l10n.wallpaperTryAgain,
        onAction: () => unawaited(onRetry()),
        onRefresh: onRetry,
      );
    }
    final source = state.selectedCategory?.source ?? WallpaperSource.prism;
    switch (source) {
      case WallpaperSource.wallhaven:
        return const WallHavenGrid();
      case WallpaperSource.pexels:
        return const PexelsGrid();
      case WallpaperSource.prism:
        return WallpaperGrid(desktopDownload: state.selectedCategory?.searchType == CategorySearchType.desktop);
      case WallpaperSource.downloaded:
      case WallpaperSource.unknown:
        return const WallpaperGrid();
    }
  }
}

String _collectionCoverUrl(String name) {
  // The Collections tab opens a collection by its lowercased name, while the index keeps the name as written.
  final String wanted = name.trim().toLowerCase();
  for (final Map<String, dynamic> collection in c_data.collections) {
    if (collection['name']?.toString().trim().toLowerCase() == wanted) {
      final String thumb1 = collection['thumb1']?.toString().trim() ?? '';
      return thumb1.isNotEmpty ? thumb1 : collection['thumb2']?.toString().trim() ?? '';
    }
  }
  return '';
}

String _categoryCoverUrl(List<CategoryEntity> categories, String name) {
  for (final CategoryEntity category in categories) {
    if (category.name.trim().toLowerCase() == name.toLowerCase()) {
      return category.image.trim().isNotEmpty ? category.image.trim() : category.image2.trim();
    }
  }
  return '';
}

/// The loading placeholder for a cover. Keyed by the cover, so a cover that arrives late starts its own tint.
Widget _coverLoading(String url) => _CoverLoading(key: ValueKey<String>(url), url: url);

/// How long the blocks take to ease from the neutral into the cover's colour.
const Duration _tintEase = Duration(milliseconds: 200);

/// Cover colours already worked out, so a second visit opens on its tint at once.
final Map<String, Color> _dominantByUrl = <String, Color>{};

/// Crossfades the loading placeholder into the walls, so the page changes in one calm step.
class _Settle extends StatelessWidget {
  const _Settle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.fast),
      switchInCurve: PrismCurves.enter,
      switchOutCurve: PrismCurves.exitReverse,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: <Widget>[...previous, if (current != null) current]),
      child: child,
    );
  }
}

/// First paint while a collection loads: its cover as a full-width header (the Collections tab already warmed it) and
/// still blocks in the cover's dominant colour where the walls will land. Until that colour is known the header and the
/// blocks share one neutral that eases into the tint. Without a cover it is the plain skeleton.
class _CoverLoading extends StatefulWidget {
  const _CoverLoading({super.key, required this.url});

  final String url;

  @override
  State<_CoverLoading> createState() => _CoverLoadingState();
}

class _CoverLoadingState extends State<_CoverLoading> {
  late Color? _dominant = _dominantByUrl[widget.url];

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty && _dominant == null) unawaited(_resolveDominant());
  }

  Future<void> _resolveDominant() async {
    try {
      final ColorScheme scheme = await ColorScheme.fromImageProvider(
        provider: ResizeImage(coverImageProvider(widget.url), width: 32),
        brightness: Brightness.dark,
      );
      _dominantByUrl[widget.url] = scheme.primary;
      if (mounted) setState(() => _dominant = scheme.primary);
    } on Object {
      // The blocks stay on the calm neutral.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) return const LoadingCards();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color rest = Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.07), scheme.surface);
    final Color tint = _dominant == null ? rest : Color.lerp(_dominant, scheme.surface, 0.55)!;
    return Semantics(
      label: context.l10n.coreLoading,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: tint),
          duration: context.motion(_tintEase),
          curve: PrismCurves.enter,
          builder: (context, color, _) => Column(
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: color!,
                  child: Image(
                    image: ResizeImage(coverImageProvider(widget.url), width: 1080),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    frameBuilder: (context, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: context.motion(PrismDurations.fast),
                            curve: PrismCurves.enter,
                            child: child,
                          ),
                  ),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: GridView.builder(
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: PrismWallGrid.padding,
                    itemCount: 12,
                    gridDelegate: PrismWallGrid.delegate(context),
                    itemBuilder: (context, index) => DecoratedBox(
                      decoration: BoxDecoration(color: color, borderRadius: PrismWallGrid.tileRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
