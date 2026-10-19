part of 'shop_bloc.j.dart';

enum ShopNoticeKind {
  rankRewardSynced,
  purchased,
  alreadyOwned,
  proOnly,
  rankLocked,
  soldOut,
  insufficient,
  purchaseFailed,
  equipped,
  unequipped,
  equipFailed,
}

/// A one-shot message for the UI to toast. A new instance each time, so the same text can show twice.
class ShopNotice {
  const ShopNotice(this.kind, {required this.success, required this.itemId, this.rankId});

  final ShopNoticeKind kind;
  final bool success;
  final String itemId;
  final String? rankId;
}

@freezed
abstract class ShopState with _$ShopState {
  const factory ShopState({
    @Default(ShopItemKind.theme) ShopItemKind kind,
    @Default(<String>{}) Set<String> owned,
    @Default(<String>{}) Set<String> legacyThemes,
    String? equippedFrame,
    String? equippedNameGlow,
    @Default(0) int balance,
    @Default('bronze') String rankId,
    @Default(false) bool premium,
    String? loadingItemId,
    ShopNotice? notice,
  }) = _ShopState;

  const ShopState._();

  factory ShopState.initial() => const ShopState();

  List<ShopItem> get items => shopItemsOf(kind);

  bool isOwned(ShopItem item) => shopItemOwned(item, owned: owned, legacyThemes: legacyThemes);

  bool isEquipped(ShopItem item) => switch (item.kind) {
    ShopItemKind.frame => equippedFrame == item.id,
    ShopItemKind.nameGlow => equippedNameGlow == item.id,
    _ => false,
  };

  ShopAvailability availability(ShopItem item, {DateTime? now}) =>
      shopAvailability(item, premium: premium, rankId: rankId, now: now ?? DateTime.now());
}
