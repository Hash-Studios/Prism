import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'streak_shop_event.dart';
part 'streak_shop_state.dart';

@injectable
class StreakShopBloc extends Bloc<StreakShopEvent, StreakShopState> {
  StreakShopBloc(this._repository) : super(const StreakShopState()) {
    on<StreakShopLoaded>(_onLoaded);
  }

  final PrismWallpaperRepository _repository;

  Future<void> _onLoaded(StreakShopLoaded event, Emitter<StreakShopState> emit) async {
    emit(state.copyWith(status: StreakShopStatus.loading));

    final result = await _repository.fetchStreakShopWallpapers();

    result.fold(
      onSuccess: (items) => emit(state.copyWith(status: StreakShopStatus.success, items: items)),
      onFailure: (_) => emit(state.copyWith(status: StreakShopStatus.failure)),
    );
  }
}
