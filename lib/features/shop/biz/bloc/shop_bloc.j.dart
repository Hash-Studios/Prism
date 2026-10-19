import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/theme_mode/data/legacy_themes.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'shop_event.j.dart';
part 'shop_state.j.dart';
part 'shop_bloc.j.freezed.dart';

@injectable
class ShopBloc extends Bloc<ShopEvent, ShopState> {
  ShopBloc(this._settings) : super(ShopState.initial()) {
    on<_Started>(_onStarted);
    on<_KindChanged>((event, emit) => emit(state.copyWith(kind: event.kind)));
    on<_Synced>((_, emit) => emit(_snapshot()));
    on<_PurchaseRequested>(_onPurchase);
    on<_EquipRequested>(_onEquip);
  }

  final SettingsLocalDataSource _settings;
  final CoinsService _coins = CoinsService.instance;
  void _onChanged() => add(const ShopEvent.synced());

  List<Listenable> get _sources => <Listenable>[_coins.balanceNotifier, _coins.xpNotifier, _coins.inventoryNotifier];

  ShopState _snapshot() {
    final Inventory inventory = _coins.inventoryNotifier.value;
    return state.copyWith(
      owned: inventory.owned,
      legacyThemes: readLegacyThemes(_settings),
      equippedFrame: inventory.frame,
      equippedNameGlow: inventory.nameGlow,
      balance: _coins.balanceNotifier.value,
      rankId: _coins.xpNotifier.value.rank.id,
      premium: app_state.prismUser.premium,
    );
  }

  void _onStarted(_Started event, Emitter<ShopState> emit) {
    for (final Listenable source in _sources) {
      source.addListener(_onChanged);
    }
    emit(_snapshot());
  }

  Future<void> _onPurchase(_PurchaseRequested event, Emitter<ShopState> emit) async {
    final ShopItem? item = shopItem(event.itemId);
    if (item == null || state.loadingItemId != null) return;
    emit(state.copyWith(loadingItemId: item.id));
    final ShopPurchaseResult result = await _coins.purchaseShopItem(item.id);
    if (result.outcome == ShopPurchaseOutcome.purchased && item.rankReward == null) {
      analytics.track(ShopItemPurchasedEvent(itemId: item.id, price: shopPriceFor(item)));
    }
    emit(_snapshot().copyWith(loadingItemId: null, notice: _purchaseNotice(item, result.outcome)));
  }

  ShopNotice _purchaseNotice(ShopItem item, ShopPurchaseOutcome outcome) => switch (outcome) {
    ShopPurchaseOutcome.purchased || ShopPurchaseOutcome.owned when item.rankReward != null => ShopNotice(
      ShopNoticeKind.rankRewardSynced,
      success: true,
      itemId: item.id,
    ),
    ShopPurchaseOutcome.purchased => ShopNotice(ShopNoticeKind.purchased, success: true, itemId: item.id),
    ShopPurchaseOutcome.owned => ShopNotice(ShopNoticeKind.alreadyOwned, success: true, itemId: item.id),
    ShopPurchaseOutcome.proOnly => ShopNotice(ShopNoticeKind.proOnly, success: false, itemId: item.id),
    ShopPurchaseOutcome.rankLocked => ShopNotice(
      ShopNoticeKind.rankLocked,
      success: false,
      itemId: item.id,
      rankId: item.requiredRank,
    ),
    ShopPurchaseOutcome.expired => ShopNotice(ShopNoticeKind.soldOut, success: false, itemId: item.id),
    ShopPurchaseOutcome.insufficient => ShopNotice(ShopNoticeKind.insufficient, success: false, itemId: item.id),
    ShopPurchaseOutcome.failed => ShopNotice(ShopNoticeKind.purchaseFailed, success: false, itemId: item.id),
  };

  Future<void> _onEquip(_EquipRequested event, Emitter<ShopState> emit) async {
    final ShopItem? item = shopItem(event.itemId);
    final CosmeticSlot? slot = item?.slot;
    if (item == null || slot == null || state.loadingItemId != null) return;
    emit(state.copyWith(loadingItemId: item.id));
    final bool done = await _coins.equipCosmetic(slot, event.equip ? item.id : null);
    if (done) {
      analytics.track(CosmeticEquippedEvent(slot: slot.name, itemId: event.equip ? item.id : null));
    }
    emit(
      _snapshot().copyWith(
        loadingItemId: null,
        notice: done
            ? ShopNotice(
                event.equip ? ShopNoticeKind.equipped : ShopNoticeKind.unequipped,
                success: true,
                itemId: item.id,
              )
            : ShopNotice(ShopNoticeKind.equipFailed, success: false, itemId: item.id),
      ),
    );
  }

  @override
  Future<void> close() {
    for (final Listenable source in _sources) {
      source.removeListener(_onChanged);
    }
    return super.close();
  }
}
