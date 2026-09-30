import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/premium_banners/premium_banner.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as c_data;
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CollectionsGrid extends StatefulWidget {
  @override
  _CollectionsGridState createState() => _CollectionsGridState();
}

enum _DiscoverTileKind { collection, category }

final class _DiscoverTileData {
  const _DiscoverTileData({
    required this.kind,
    required this.name,
    required this.thumb1,
    required this.thumb2,
    required this.isPremium,
  });

  final _DiscoverTileKind kind;
  final String name;
  final String thumb1;
  final String thumb2;
  final bool isPremium;
}

String _discoverTileSemanticLabel(_DiscoverTileData tile) {
  final String trimmed = tile.name.trim();
  if (tile.kind == _DiscoverTileKind.category) {
    if (trimmed.isEmpty) {
      return 'Category';
    }
    return 'Category, $trimmed';
  }
  if (trimmed.isEmpty) {
    return tile.isPremium ? 'Premium collection' : 'Collection';
  }
  if (tile.isPremium) {
    return 'Premium collection, $trimmed';
  }
  return 'Collection, $trimmed';
}

/// Decodes network thumbs near on-screen size to reduce memory and GPU upload cost.
ImageProvider? _resizeCachedThumb(BuildContext context, String url, double logicalW, double logicalH) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final double dpr = MediaQuery.devicePixelRatioOf(context);
  final int w = (logicalW * dpr).round().clamp(1, 4096);
  final int h = (logicalH * dpr).round().clamp(1, 4096);
  return ResizeImage(CachedNetworkImageProvider(trimmed), width: w, height: h);
}

const double _kCollectionsTitleBlockHeight = 40;
const double _kCollectionsTitleImageGap = 6;
const double _kCollectionsGridChildAspectRatio = 0.56;

class _CollectionTileSkeleton extends StatelessWidget {
  const _CollectionTileSkeleton({required this.cellWidth});

  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    return PulsePlaceholder(
      builder: (BuildContext context, Color _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: _kCollectionsTitleBlockHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: cellWidth * 0.65, height: 13, child: const PulseFill()),
              ),
            ),
            const SizedBox(height: _kCollectionsTitleImageGap),
            const Expanded(child: PulseFill()),
          ],
        );
      },
    );
  }
}

class _CollectionsGridState extends State<CollectionsGrid> with TickerProviderStateMixin {
  Future<void> _handleCollectionTap({required bool isPremium, required String collectionName}) async {
    final String normalizedCollectionName = collectionName.trim().toLowerCase();
    if (!isPremium) {
      _openCollection(normalizedCollectionName);
      return;
    }
    if (app_state.prismUser.premium) {
      _openCollection(normalizedCollectionName);
      return;
    }
    if (!app_state.prismUser.loggedIn) {
      googleSignInPopUp(context, () {
        unawaited(_handleCollectionTap(isPremium: isPremium, collectionName: normalizedCollectionName));
      });
      return;
    }

    bool hasPreviewAccess = false;
    try {
      hasPreviewAccess = await CoinsService.instance.hasPremiumPreviewAccessForCollection(normalizedCollectionName);
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(
        sourceTag: 'coins.preview.check.collections_grid',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (hasPreviewAccess) {
      _openCollection(normalizedCollectionName);
      return;
    }

    await _unlockPreviewAndOpen(normalizedCollectionName);
  }

  void _openCollection(String collectionName) {
    context.router.push(CollectionViewRoute(collectionName: collectionName.trim().toLowerCase()));
  }

  Future<CoinGateChoice> _choosePreviewAction(CoinGatePrompt prompt) async {
    final CoinGateChoice? choice = await showCoinGateSheet<CoinGateChoice>(
      context,
      title: 'Premium Collection',
      cost: CoinPolicy.premiumPreview24h,
      message: (missing) => missing > 0
          ? 'Unlock 24h preview for -${CoinPolicy.premiumPreview24h} coins. Need $missing more coins.'
          : 'Unlock this premium collection for 24 hours for -${CoinPolicy.premiumPreview24h} coins.',
      options: const [
        CoinGateOption(label: 'Unlock 24h (-${CoinPolicy.premiumPreview24h})', value: CoinGateChoice.spend),
        CoinGateOption(label: 'Watch Ad (+${CoinPolicy.rewardedAd}) & Unlock', value: CoinGateChoice.watchAd),
        CoinGateOption(label: 'Upgrade to Pro', value: CoinGateChoice.upgrade, outlined: true),
      ],
    );
    return choice ?? CoinGateChoice.cancel;
  }

  Future<void> _unlockPreviewAndOpen(String collectionName) {
    return CoinGate.forContext(context).run(
      CoinGateSpec(
        action: CoinSpendAction.premiumPreview24h,
        tags: const CoinGateTags(
          spend: 'coins.preview.unlock.collections_grid',
          retrySpend: 'coins.preview.watch_and_unlock.unlock',
          ad: 'coins.preview.watch_and_unlock.rewarded_ad',
          nudge: 'coins.preview.sheet.collections_grid',
          insufficient: 'coins.preview.low_balance_nudge.collections_grid',
        ),
        upsellSource: 'premium_preview_watch_ad',
        upgradeSource: 'premium_preview_upgrade',
        nudgeBelow: CoinPolicy.premiumPreview24h,
        confirmFirst: true,
        toastWhenInsufficient: true,
        spendErrorMessage: 'Unable to unlock premium preview right now.',
        isMounted: () => mounted,
        choose: _choosePreviewAction,
        spend: (sourceTag) => CoinsService.instance.unlockPremiumPreview24hForCollection(
          collectionKey: collectionName,
          sourceTag: sourceTag,
        ),
        onAttempt: (sourceTag) =>
            analytics.track(CoinPreviewUnlockAttemptEvent(collection: collectionName, sourceTag: sourceTag)),
        onWatchChosen: () => analytics.track(
          CoinPreviewWatchAndUnlockUsedEvent(
            collection: collectionName,
            sourceTag: 'coins.preview.watch_and_unlock.collections_grid',
          ),
        ),
        onSpent: (sourceTag, _) {
          analytics.track(
            CoinPreviewUnlockSuccessEvent(
              collection: collectionName,
              sourceTag: sourceTag,
              coinsSpent: CoinPolicy.premiumPreview24h,
            ),
          );
          toasts.success('24h preview unlocked (-${CoinPolicy.premiumPreview24h} coins).');
        },
        perform: () async {
          _openCollection(collectionName);
          return true;
        },
      ),
    );
  }

  Future<void> refreshList() async {
    try {
      await c_data.getCollections();
    } catch (error, stackTrace) {
      logger.w('Failed to refresh collections.', error: error, stackTrace: stackTrace);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rawCollections = c_data.collections;
    final bool isLoading = rawCollections.isEmpty;

    final List<_DiscoverTileData> discoverTiles = isLoading
        ? const <_DiscoverTileData>[]
        : <_DiscoverTileData>[
            ...rawCollections.map(
              (collection) => _DiscoverTileData(
                kind: _DiscoverTileKind.collection,
                name: collection['name']?.toString() ?? '',
                thumb1: collection['thumb1']?.toString() ?? '',
                thumb2: collection['thumb2']?.toString() ?? '',
                isPremium: collection['premium'] == true,
              ),
            ),
            ...context.watch<CategoryFeedBloc>().state.categories.map(
              (category) => _DiscoverTileData(
                kind: _DiscoverTileKind.category,
                name: category.name.trim(),
                thumb1: category.image.trim(),
                thumb2: category.image2.trim(),
                isPremium: false,
              ),
            ),
          ];
    final int itemCount = isLoading ? 8 : discoverTiles.length;
    const double gridSpacing = 8;
    const EdgeInsets gridPadding = EdgeInsets.fromLTRB(5, 4, 5, 4);

    final ThemeData theme = Theme.of(context);
    final double viewportW = MediaQuery.sizeOf(context).width;
    // Cards up to ~260 pt wide: 2 columns on a phone, more on a tablet.
    final int columns = (viewportW / 260).ceil().clamp(2, 6);
    final double cellWidth = (viewportW - gridPadding.horizontal - gridSpacing * (columns - 1)) / columns;
    final double cellHeight = cellWidth / _kCollectionsGridChildAspectRatio;
    final double imageDecodeHeight = (cellHeight - _kCollectionsTitleBlockHeight - _kCollectionsTitleImageGap).clamp(
      48.0,
      4000.0,
    );

    Widget buildCollectionCard(_DiscoverTileData? tile) {
      final bool loading = tile == null;
      final bool isPremium = tile?.isPremium ?? false;
      final ColorScheme scheme = Theme.of(context).colorScheme;

      if (loading) {
        final Widget tileBody = Material(
          color: Colors.transparent,
          child: _CollectionTileSkeleton(cellWidth: cellWidth),
        );
        return Semantics(label: 'Loading', enabled: false, excludeSemantics: true, child: tileBody);
      }

      final _DiscoverTileData data = tile;
      final String rawThumb1 = data.thumb1.trim();
      final String rawThumb2 = data.thumb2.trim();
      final String thumbUrl = rawThumb1.isNotEmpty ? rawThumb1 : rawThumb2;
      final ImageProvider? thumbImage = _resizeCachedThumb(context, thumbUrl, cellWidth, imageDecodeHeight);
      final String trimmedName = data.name.trim();
      final String displayTitle = trimmedName.isNotEmpty
          ? trimmedName
          : (data.kind == _DiscoverTileKind.category ? 'Category' : 'Collection');

      void onTapTile() {
        if (data.kind == _DiscoverTileKind.collection) {
          unawaited(_handleCollectionTap(isPremium: isPremium, collectionName: data.name));
          return;
        }
        final encodedName = Uri.encodeComponent(data.name);
        context.router.push(CollectionViewRoute(collectionName: 'category:$encodedName'));
      }

      final Widget content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: _kCollectionsTitleBlockHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface) ??
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: _kCollectionsTitleImageGap),
          Expanded(
            child: PremiumBanner(
              comparator: !isPremium,
              child: DecoratedBox(
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
                child: thumbImage == null
                    ? const SizedBox.expand()
                    : Image(
                        image: thumbImage,
                        fit: BoxFit.cover,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => wasSynchronouslyLoaded
                            ? child
                            : AnimatedOpacity(
                                opacity: frame == null ? 0 : 1,
                                duration: context.motion(const Duration(milliseconds: 180)),
                                curve: Curves.easeOut,
                                child: child,
                              ),
                      ),
              ),
            ),
          ),
        ],
      );

      final Widget tileBody = Material(
        color: Colors.transparent,
        child: InkWell(
          splashColor: scheme.secondary.withValues(alpha: 0.3),
          highlightColor: scheme.secondary.withValues(alpha: 0.1),
          onTap: onTapTile,
          child: content,
        ),
      );

      return Semantics(button: true, label: _discoverTileSemanticLabel(data), excludeSemantics: true, child: tileBody);
    }

    return RefreshIndicator(
      onRefresh: refreshList,
      color: theme.colorScheme.primary,
      backgroundColor: theme.primaryColor,
      edgeOffset: MediaQuery.paddingOf(context).top,
      child: GridView.builder(
        padding: gridPadding,
        itemCount: itemCount,
        physics: AlwaysScrollableScrollPhysics(parent: ScrollConfiguration.of(context).getScrollPhysics(context)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: _kCollectionsGridChildAspectRatio,
          mainAxisSpacing: gridSpacing,
          crossAxisSpacing: gridSpacing,
        ),
        itemBuilder: (BuildContext context, int index) {
          if (isLoading) {
            return buildCollectionCard(null);
          }
          return buildCollectionCard(discoverTiles[index]);
        },
      ),
    );
  }
}
