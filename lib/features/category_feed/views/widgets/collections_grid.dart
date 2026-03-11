import 'dart:async';
import 'dart:math';

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
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
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

class _CollectionsGridState extends State<CollectionsGrid> with TickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<Color?> animation;
  GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey<RefreshIndicatorState>();
  Random r = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation =
        context.prismModeStyleForWindow(listen: false) == "Dark"
              ? TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
                  ),
                ]).animate(_controller!)
              : TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .1),
                      end: Colors.black.withValues(alpha: .14),
                    ),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .14),
                      end: Colors.black.withValues(alpha: .1),
                    ),
                  ),
                ]).animate(_controller!)
          ..addListener(() {
            setState(() {});
          });
    _controller!.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
    refreshKey.currentState?.show();
    await CData.getCollections();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = InheritedDataProvider.of(context)?.scrollController;
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

    Widget buildCollectionCard(_DiscoverTileData? tile) {
      final bool loading = tile == null;
      final bool isPremium = tile?.isPremium ?? false;
      final String name = loading ? "LOADING" : tile.name.toUpperCase();
      final String thumb1 = loading ? '' : tile.thumb1;
      final String thumb2 = loading ? '' : tile.thumb2;
      return GestureDetector(
        onTap: loading
            ? null
            : () {
                if (tile.kind == _DiscoverTileKind.collection) {
                  unawaited(_handleCollectionTap(isPremium: isPremium, collectionName: tile.name));
                  return;
                }
                final encodedName = Uri.encodeComponent(tile.name);
                context.router.push(CollectionViewRoute(collectionName: 'category:$encodedName'));
              },
        child: PremiumBanner(
          comparator: !isPremium,
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 40,
                left: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        offset: const Offset(5, 5),
                        color: context.prismModeStyleForContext() == "Light" ? Colors.black12 : Colors.black54,
                      ),
                    ],
                  ),
                  height: (MediaQuery.of(context).size.width / 2) / 0.6225 - 63.5,
                  width: MediaQuery.of(context).size.width / 2 - 59,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 25, left: 25),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.displayMedium!.copyWith(
                      fontSize: 16,
                      color: loading
                          ? (context.prismModeStyleForContext() == "Light" ? Colors.black : Colors.white)
                          : Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        offset: const Offset(5, 5),
                        color: context.prismModeStyleForContext() == "Light" ? Colors.black26 : Colors.black54,
                      ),
                    ],
                  ),
                  height: (MediaQuery.of(context).size.width / 2) / 0.6225 - 108.5,
                  width: MediaQuery.of(context).size.width / 2 - 59,
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  decoration: loading
                      ? BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20))
                      : BoxDecoration(
                          color: animation.value,
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(image: CachedNetworkImageProvider(thumb2), fit: BoxFit.cover),
                        ),
                  height: (MediaQuery.of(context).size.width / 2) / 0.6225 - 108.5,
                  width: MediaQuery.of(context).size.width / 2 - 59,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        offset: const Offset(5, 5),
                        color: context.prismModeStyleForContext() == "Light" ? Colors.black26 : Colors.black54,
                      ),
                    ],
                  ),
                  height: (MediaQuery.of(context).size.width / 2) / 0.6225 - 108.5,
                  width: MediaQuery.of(context).size.width / 2 - 59,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  decoration: loading
                      ? BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20))
                      : BoxDecoration(
                          color: animation.value,
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(image: CachedNetworkImageProvider(thumb1), fit: BoxFit.cover),
                        ),
                  height: (MediaQuery.of(context).size.width / 2) / 0.6225 - 108.5,
                  width: MediaQuery.of(context).size.width / 2 - 59,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshKey,
      onRefresh: refreshList,
      child: GridView.builder(
        controller: controller,
        physics: const ScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        itemCount: itemCount,
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6225,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          if (isLoading) {
            return buildCollectionCard(null);
          }
          return buildCollectionCard(discoverTiles[index]);
        },
      ),
    );
  }
}
