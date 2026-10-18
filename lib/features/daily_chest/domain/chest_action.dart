import 'package:Prism/core/coins/daily_chest.dart';

/// What the main button of the chest page does for this status and balance.
enum ChestAction {
  /// Open it: free, or a price the balance covers.
  open,

  /// The balance is short of the price: open the way to earn coins.
  getCoins,

  /// Today's chest is open already.
  spent,
}

ChestAction chestAction({required DailyChestStatus status, required int balance}) {
  if (status.opened) return ChestAction.spent;
  if (balance < status.nextCost) return ChestAction.getCoins;
  return ChestAction.open;
}
