part of 'shop_bloc.j.dart';

@freezed
abstract class ShopEvent with _$ShopEvent {
  const factory ShopEvent.started() = _Started;
  const factory ShopEvent.kindChanged(ShopItemKind kind) = _KindChanged;
  const factory ShopEvent.synced() = _Synced;
  const factory ShopEvent.purchaseRequested(String itemId) = _PurchaseRequested;
  const factory ShopEvent.equipRequested({required String itemId, required bool equip}) = _EquipRequested;
}
