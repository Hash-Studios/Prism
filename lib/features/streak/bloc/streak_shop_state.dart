part of 'streak_shop_bloc.dart';

enum StreakShopStatus { initial, loading, success, failure }

class StreakShopState {
  const StreakShopState({this.status = StreakShopStatus.initial, this.items = const []});

  final StreakShopStatus status;
  final List<PrismWallpaper> items;

  StreakShopState copyWith({StreakShopStatus? status, List<PrismWallpaper>? items}) {
    return StreakShopState(status: status ?? this.status, items: items ?? this.items);
  }
}
