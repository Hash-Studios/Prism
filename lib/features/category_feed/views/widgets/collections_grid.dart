import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/core/widgets/premiumBanners/premiumBanner.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart' as CData;
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/views/category_feed_bloc_adapter.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CollectionsGrid extends StatefulWidget {
  @override
  _CollectionsGridState createState() => _CollectionsGridState();
}

enum _PremiumPreviewAction { none, unlockNow, watchAndUnlock, upgrade }

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

class _CollectionTileSkeleton extends StatefulWidget {
  const _CollectionTileSkeleton({required this.cellWidth, required this.base, required this.highlight});

  final double cellWidth;
  final Color base;
  final Color highlight;

  @override
  State<_CollectionTileSkeleton> createState() => _CollectionTileSkeletonState();
}

class _CollectionTileSkeletonState extends State<_CollectionTileSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Color?> _shimmer;

  void _attachColors() {
    _shimmer = ColorTween(
      begin: widget.base,
      end: widget.highlight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _attachColors();
    _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _CollectionTileSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.base != oldWidget.base || widget.highlight != oldWidget.highlight) {
      _attachColors();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color fallback = Theme.of(context).colorScheme.surfaceContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _kCollectionsTitleBlockHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (BuildContext context, Widget? child) {
                return Container(width: widget.cellWidth * 0.65, height: 13, color: _shimmer.value ?? fallback);
              },
            ),
          ),
        ),
        const SizedBox(height: _kCollectionsTitleImageGap),
        Expanded(
          child: AnimatedBuilder(
            animation: _shimmer,
            builder: (BuildContext context, Widget? child) {
              return ColoredBox(color: _shimmer.value ?? fallback);
            },
          ),
        ),
      ],
    );
  }
}

class _CollectionsGridState extends State<CollectionsGrid> {
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

    await _showPremiumPreviewSheet(
      collectionName: normalizedCollectionName,
      sourceTag: 'coins.preview.sheet.collections_grid',
    );
  }

  void _openCollection(String collectionName) {
    context.router.push(CollectionViewRoute(collectionName: collectionName.trim().toLowerCase()));
  }

  Future<void> _showPremiumPreviewSheet({required String collectionName, required String sourceTag}) async {
    if (!mounted) {
      return;
    }
    final int balance = CoinsService.instance.balanceNotifier.value;
    if (balance < CoinPolicy.premiumPreview24h) {
      CoinsService.instance.logLowBalanceNudge(sourceTag: sourceTag, requiredCoins: CoinPolicy.premiumPreview24h);
    }

    final _PremiumPreviewAction action =
        await showModalBottomSheet<_PremiumPreviewAction>(
          context: context,
          backgroundColor: Theme.of(context).primaryColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (sheetContext) {
            final int currentBalance = CoinsService.instance.balanceNotifier.value;
            final int missing = (CoinPolicy.premiumPreview24h - currentBalance).clamp(0, CoinPolicy.premiumPreview24h);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).hintColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Premium Collection', style: Theme.of(sheetContext).textTheme.displaySmall),
                  const SizedBox(height: 10),
                  Text(
                    missing > 0
                        ? 'Unlock 24h preview for -10 coins. Need $missing more coins.'
                        : 'Unlock this premium collection for 24 hours for -10 coins.',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(_PremiumPreviewAction.unlockNow),
                      child: const Text('Unlock 24h (-10)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(_PremiumPreviewAction.watchAndUnlock),
                      child: const Text('Watch Ad (+10) & Unlock'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(_PremiumPreviewAction.upgrade),
                      child: const Text('Upgrade to Pro'),
                    ),
                  ),
                ],
              ),
            );
          },
        ) ??
        _PremiumPreviewAction.none;

    switch (action) {
      case _PremiumPreviewAction.unlockNow:
        await _attemptPreviewUnlockAndOpen(
          collectionName: collectionName,
          sourceTag: 'coins.preview.unlock.collections_grid',
        );
        return;
      case _PremiumPreviewAction.watchAndUnlock:
        await _watchAdAndUnlockPreview(collectionName: collectionName);
        return;
      case _PremiumPreviewAction.upgrade:
        if (mounted) {
          await PaywallOrchestrator.instance.present(
            context,
            placement: PaywallPlacement.lowBalance,
            source: 'premium_preview_upgrade',
          );
        }
        return;
      case _PremiumPreviewAction.none:
        return;
    }
  }

  Future<void> _attemptPreviewUnlockAndOpen({required String collectionName, required String sourceTag}) async {
    analytics.track(CoinPreviewUnlockAttemptEvent(collection: collectionName, sourceTag: sourceTag));
    CoinMutationResult result;
    try {
      result = await CoinsService.instance.unlockPremiumPreview24hForCollection(
        collectionKey: collectionName,
        sourceTag: sourceTag,
      );
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
      toasts.error('Unable to unlock premium preview right now.');
      return;
    }

    if (!result.success) {
      if (result.insufficientBalance) {
        final int missing = (CoinPolicy.premiumPreview24h - CoinsService.instance.balanceNotifier.value).clamp(
          1,
          CoinPolicy.premiumPreview24h,
        );
        toasts.error('Need $missing more coins.');
        await _showPremiumPreviewSheet(
          collectionName: collectionName,
          sourceTag: 'coins.preview.low_balance_nudge.collections_grid',
        );
        return;
      }
      toasts.error('Unable to unlock premium preview right now.');
      return;
    }

    if (result.changed) {
      analytics.track(
        CoinPreviewUnlockSuccessEvent(
          collection: collectionName,
          sourceTag: sourceTag,
          coinsSpent: CoinPolicy.premiumPreview24h,
        ),
      );
      toasts.codeSend('24h preview unlocked (-${CoinPolicy.premiumPreview24h} coins).');
    }
    _openCollection(collectionName);
  }

  Future<void> _watchAdAndUnlockPreview({required String collectionName}) async {
    analytics.track(
      CoinPreviewWatchAndUnlockUsedEvent(
        collection: collectionName,
        sourceTag: 'coins.preview.watch_and_unlock.collections_grid',
      ),
    );
    final bool watched = await _watchRewardedAd();
    if (!watched) {
      toasts.error('Ad was not completed.');
      return;
    }
    try {
      await CoinsService.instance.award(
        CoinEarnAction.rewardedAd,
        sourceTag: 'coins.preview.watch_and_unlock.rewarded_ad',
      );
      if (mounted) {
        await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(
          context,
          source: 'premium_preview_watch_ad',
        );
      }
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(
        sourceTag: 'coins.preview.watch_and_unlock.rewarded_ad',
        error: error,
        stackTrace: stackTrace,
      );
      toasts.error('Unable to credit coins right now.');
      return;
    }
    await _attemptPreviewUnlockAndOpen(
      collectionName: collectionName,
      sourceTag: 'coins.preview.watch_and_unlock.unlock',
    );
  }

  Future<bool> _ensureRewardedAdReady(AdsBloc bloc) async {
    if (bloc.state.ads.adLoaded) {
      return true;
    }
    if (!bloc.state.ads.loadingAd) {
      bloc.add(const AdsEvent.started());
    }
    try {
      final AdsState state = await bloc.stream
          .firstWhere((state) => state.ads.adLoaded || state.ads.adFailed)
          .timeout(const Duration(seconds: 30));
      return state.ads.adLoaded;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _watchRewardedAd() async {
    final AdsBloc bloc = context.read<AdsBloc>();
    if (!await _ensureRewardedAdReady(bloc)) {
      return false;
    }
    bool watchRequested = false;
    try {
      final Future<AdsState> completion = bloc.stream
          .firstWhere(
            (state) => state.shouldUnlockDownload || state.actionStatus == ActionStatus.failure || state.ads.adFailed,
          )
          .timeout(const Duration(seconds: 60));
      bloc.add(const AdsEvent.watchAdRequested());
      watchRequested = true;
      final AdsState result = await completion;
      return result.shouldUnlockDownload;
    } catch (_) {
      return false;
    } finally {
      if (watchRequested) {
        bloc.add(const AdsEvent.transientStateCleared());
      }
    }
  }

  Future<void> refreshList() async {
    await CData.getCollections();
  }

  @override
  Widget build(BuildContext context) {
    final List<Object?> rawCollections =
        CData.collections?.whereType<Object?>().toList(growable: false) ?? const <Object?>[];
    final bool isLoading = rawCollections.isEmpty;

    Map<String, dynamic> asMap(Object? raw) {
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return raw.cast<String, dynamic>();
      }
      return <String, dynamic>{};
    }

    final List<_DiscoverTileData> discoverTiles = isLoading
        ? const <_DiscoverTileData>[]
        : <_DiscoverTileData>[
            ...rawCollections.map((raw) {
              final collection = asMap(raw);
              return _DiscoverTileData(
                kind: _DiscoverTileKind.collection,
                name: collection['name']?.toString() ?? '',
                thumb1: collection['thumb1']?.toString() ?? '',
                thumb2: collection['thumb2']?.toString() ?? '',
                isPremium: collection['premium'] == true,
              );
            }),
            ...context
                .categoryChoiceList(listen: false)
                .map(
                  (choice) => _DiscoverTileData(
                    kind: _DiscoverTileKind.category,
                    name: choice.name?.trim() ?? '',
                    thumb1: choice.image?.trim() ?? '',
                    thumb2: choice.image2?.trim() ?? choice.image?.trim() ?? '',
                    isPremium: false,
                  ),
                ),
          ];
    final int itemCount = isLoading ? 8 : discoverTiles.length;
    const double gridSpacing = 8;
    const EdgeInsets gridPadding = EdgeInsets.fromLTRB(5, 4, 5, 4);

    final ThemeData theme = Theme.of(context);
    final double viewportW = MediaQuery.sizeOf(context).width;
    final double cellWidth = (viewportW - gridPadding.horizontal - gridSpacing) / 2;
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
          child: _CollectionTileSkeleton(
            cellWidth: cellWidth,
            base: scheme.surfaceContainer,
            highlight: scheme.surfaceContainerHigh,
          ),
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
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  image: thumbImage != null ? DecorationImage(image: thumbImage, fit: BoxFit.cover) : null,
                ),
                child: thumbImage != null ? null : const SizedBox.expand(),
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
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
