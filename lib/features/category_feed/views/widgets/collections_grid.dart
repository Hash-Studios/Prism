import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as c_data;
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CollectionsGrid extends StatefulWidget {
  const CollectionsGrid({super.key, this.header});

  /// Scrolls with the cards. The collections tab puts its title here.
  final Widget? header;

  @override
  State<CollectionsGrid> createState() => _CollectionsGridState();
}

enum _PremiumPreviewAction { none, unlockNow, watchAndUnlock, upgrade }

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
        await showCoinGateSheet<_PremiumPreviewAction>(
          context,
          title: 'Premium collection',
          cost: CoinPolicy.premiumPreview24h,
          message: (missing) => missing > 0
              ? 'A 24 hour preview costs ${CoinPolicy.premiumPreview24h} coins. You need $missing more.'
              : 'Preview this premium collection for 24 hours for ${CoinPolicy.premiumPreview24h} coins.',
          options: const [
            CoinGateOption(
              label: 'Unlock for 24 hours (-${CoinPolicy.premiumPreview24h})',
              value: _PremiumPreviewAction.unlockNow,
            ),
            CoinGateOption(
              label: 'Watch an ad (+${CoinPolicy.rewardedAd}) and unlock',
              value: _PremiumPreviewAction.watchAndUnlock,
            ),
            CoinGateOption(label: 'Upgrade to Pro', value: _PremiumPreviewAction.upgrade, outlined: true),
          ],
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
      toasts.error("Couldn't unlock the preview. Try again.");
      return;
    }

    if (!result.success) {
      if (result.insufficientBalance) {
        final int missing = (CoinPolicy.premiumPreview24h - CoinsService.instance.balanceNotifier.value).clamp(
          1,
          CoinPolicy.premiumPreview24h,
        );
        toasts.error('You need $missing more coins.');
        await _showPremiumPreviewSheet(
          collectionName: collectionName,
          sourceTag: 'coins.preview.low_balance_nudge.collections_grid',
        );
        return;
      }
      toasts.error("Couldn't unlock the preview. Try again.");
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
      toasts.success('Preview unlocked for 24 hours (-${CoinPolicy.premiumPreview24h} coins).');
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
    final bool watched = await watchRewardedAd(context.read<AdsBloc>());
    if (!watched) {
      toasts.error("The ad didn't finish.");
      return;
    }
    try {
      final credit = await CoinsService.instance.award(
        CoinEarnAction.rewardedAd,
        sourceTag: 'coins.preview.watch_and_unlock.rewarded_ad',
      );
      if (!credit.changed) {
        toasts.error("Couldn't add the coins. Try again.");
        return;
      }
      if (mounted) {
        await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(source: 'premium_preview_watch_ad');
      }
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(
        sourceTag: 'coins.preview.watch_and_unlock.rewarded_ad',
        error: error,
        stackTrace: stackTrace,
      );
      toasts.error("Couldn't add the coins. Try again.");
      return;
    }
    await _attemptPreviewUnlockAndOpen(
      collectionName: collectionName,
      sourceTag: 'coins.preview.watch_and_unlock.unlock',
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

  void _onTapCard(CollectionCardData data) {
    if (data.kind == CollectionCardKind.collection) {
      unawaited(_handleCollectionTap(isPremium: data.isPremium, collectionName: data.name));
      return;
    }
    context.router.push(CollectionViewRoute(collectionName: 'category:${Uri.encodeComponent(data.name)}'));
  }

  SliverPadding _cards(List<CollectionCardData> cards) {
    return SliverPadding(
      padding: collectionsGridPadding,
      sliver: SliverGrid.builder(
        gridDelegate: collectionsGridDelegate(context),
        itemCount: cards.length,
        itemBuilder: (context, index) => CollectionCard(data: cards[index], onTap: () => _onTapCard(cards[index])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<CollectionCardData> collections = c_data.collections
        .map(
          (collection) => CollectionCardData(
            kind: CollectionCardKind.collection,
            name: collection['name']?.toString() ?? '',
            thumbUrl: (collection['thumb1']?.toString() ?? '').trim().isNotEmpty
                ? collection['thumb1'].toString()
                : collection['thumb2']?.toString() ?? '',
            isPremium: collection['premium'] == true,
          ),
        )
        .toList(growable: false);
    final List<CollectionCardData> categories = context
        .select<CategoryFeedBloc, List<CategoryEntity>>((bloc) => bloc.state.categories)
        .map(
          (category) => CollectionCardData(
            kind: CollectionCardKind.category,
            name: category.name.trim(),
            thumbUrl: category.image.trim().isNotEmpty ? category.image.trim() : category.image2.trim(),
            isPremium: false,
          ),
        )
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: refreshList,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(parent: ScrollConfiguration.of(context).getScrollPhysics(context)),
        slivers: <Widget>[
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          if (collections.isEmpty && categories.isEmpty)
            SliverFillRemaining(
              child: GlintState(
                kind: GlintStateKind.empty,
                title: 'No collections yet',
                body: 'Pull down to refresh, or check back soon.',
                actionLabel: 'Refresh',
                onAction: () => unawaited(refreshList()),
              ),
            ),
          if (collections.isNotEmpty) _cards(collections),
          if (categories.isNotEmpty) ...<Widget>[
            const SliverToBoxAdapter(
              child: PrismSectionHeader(
                title: 'Categories',
                padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
              ),
            ),
            _cards(categories),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
        ],
      ),
    );
  }
}
