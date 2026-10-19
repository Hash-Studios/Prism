import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as c_data;
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
import 'package:Prism/l10n/l10n.dart';
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

class _CollectionsGridState extends State<CollectionsGrid> {
  // ponytail: one preview operation per grid; per-collection locks if simultaneous unlocks become necessary.
  bool _premiumPreviewInFlight = false;

  Future<void> _handleCollectionTap({required bool isPremium, required String collectionName}) async {
    final String normalizedCollectionName = collectionName.trim().toLowerCase();
    if (!isPremium) {
      _openCollection(normalizedCollectionName);
      return;
    }
    if (CoinsService.instance.premiumContentUnlocked) {
      _openCollection(normalizedCollectionName);
      return;
    }
    if (!app_state.prismUser.loggedIn) {
      googleSignInPopUp(context, () {
        unawaited(_handleCollectionTap(isPremium: isPremium, collectionName: normalizedCollectionName));
      });
      return;
    }

    if (_premiumPreviewInFlight) {
      return;
    }
    _premiumPreviewInFlight = true;
    try {
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
      if (!mounted) {
        return;
      }
      if (hasPreviewAccess) {
        _openCollection(normalizedCollectionName);
        return;
      }

      await _unlockPreviewAndOpen(normalizedCollectionName);
    } finally {
      _premiumPreviewInFlight = false;
    }
  }

  void _openCollection(String collectionName) {
    context.router.push(CollectionViewRoute(collectionName: collectionName.trim().toLowerCase()));
  }

  Future<CoinGateChoice> _choosePreviewAction(CoinGatePrompt prompt) async {
    final CoinGateChoice? choice = await showCoinGateSheet<CoinGateChoice>(
      context,
      title: context.l10n.wallpaperPremiumCollection,
      cost: CoinPolicy.premiumPreview24h,
      message: (missing) => missing > 0
          ? context.l10n.wallpaperPreviewUnlockCostMissing(CoinPolicy.premiumPreview24h, missing)
          : context.l10n.wallpaperPreviewUnlockCost(CoinPolicy.premiumPreview24h),
      options: [
        CoinGateOption(
          label: context.l10n.wallpaperPreviewUnlock24Hours(CoinPolicy.premiumPreview24h),
          value: CoinGateChoice.spend,
        ),
        if (prompt.missing > 0 && prompt.canWatchAd)
          CoinGateOption(
            label: context.l10n.wallpaperPreviewWatchAdUnlock(watchAdOptionLabel(context.l10n)),
            value: CoinGateChoice.watchAd,
          ),
        CoinGateOption(label: context.l10n.wallpaperSeePrismPro, value: CoinGateChoice.upgrade, outlined: true),
      ],
    );
    return choice ?? CoinGateChoice.cancel;
  }

  Future<void> _unlockPreviewAndOpen(String collectionName) {
    CoinGateSpec previewSpec({bool confirmFirst = true}) => CoinGateSpec(
      action: CoinSpendAction.premiumPreview24h,
      tags: CoinGateTags(
        spend: confirmFirst ? 'coins.preview.unlock.collections_grid' : 'coins.preview.watch_and_unlock.unlock',
        promptSpend: 'coins.preview.unlock.collections_grid',
        retrySpend: 'coins.preview.watch_and_unlock.unlock',
        ad: 'coins.preview.watch_and_unlock.rewarded_ad',
        nudge: 'coins.preview.sheet.collections_grid',
        insufficient: 'coins.preview.low_balance_nudge.collections_grid',
      ),
      upsellSource: 'premium_preview_watch_ad',
      upgradeSource: 'premium_preview_upgrade',
      nudgeBelow: confirmFirst ? CoinPolicy.premiumPreview24h : null,
      confirmFirst: confirmFirst,
      toastWhenInsufficient: true,
      logInsufficientOnlyWhenLow: true,
      spendErrorMessage: "Couldn't unlock the preview. Try again.",
      refundOnFailure: false,
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
        toasts.success(context.l10n.wallpaperCollectionPreviewUnlocked(CoinPolicy.premiumPreview24h));
      },
      perform: () async {
        if (mounted) {
          _openCollection(collectionName);
        }
        return true;
      },
      retrySpec: () => previewSpec(confirmFirst: false),
    );

    return CoinGate.forContext(context).run(previewSpec());
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
    PrismHaptics.tap();
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
        itemBuilder: (context, index) => CollectionCard(
          key: ValueKey<String>('${cards[index].kind.name}:${cards[index].name}'),
          data: cards[index],
          onTap: () => _onTapCard(cards[index]),
        ),
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
      onRefresh: () {
        PrismHaptics.impact();
        return refreshList();
      },
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
                title: context.l10n.wallpaperCollectionsEmptyTitle,
                body: context.l10n.wallpaperCollectionsEmptyBody,
                actionLabel: context.l10n.wallpaperRefresh,
                onAction: () => unawaited(refreshList()),
              ),
            ),
          if (collections.isNotEmpty) _cards(collections),
          if (categories.isNotEmpty) ...<Widget>[
            SliverToBoxAdapter(
              child: PrismSectionHeader(
                title: context.l10n.wallpaperCategories,
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
