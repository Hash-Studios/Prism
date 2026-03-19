part of 'streak_shop_bloc.dart';

abstract class StreakShopEvent {
  const StreakShopEvent();
}

class StreakShopLoaded extends StreakShopEvent {
  const StreakShopLoaded();
}
