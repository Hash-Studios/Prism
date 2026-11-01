import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class RemixCreditState {
  const RemixCreditState();
}

final class RemixCreditLoading extends RemixCreditState {
  const RemixCreditLoading();
}

/// The approved AI wall that a remix started from, as the viewer may open it.
final class RemixCreditShown extends RemixCreditState {
  const RemixCreditShown(this.original);

  final PrismWallpaper original;
}

/// The original is missing, withheld from the viewer, not an AI wall, or the lookup failed.
final class RemixCreditHidden extends RemixCreditState {
  const RemixCreditHidden();
}

/// The original wall of one remix, for the credit line under the detail panel.
@injectable
class RemixCreditCubit extends Cubit<RemixCreditState> {
  RemixCreditCubit(this._repository) : super(const RemixCreditLoading());

  final WallRemixRepository _repository;
  int _loadVersion = 0;

  /// Loads the original of the remix [remixOfDocId]. Uses [viewer] when given, otherwise the signed-in user and the
  /// blocked creators.
  Future<void> load(String remixOfDocId, {WallViewer? viewer}) async {
    if (isClosed) return;
    final int loadVersion = ++_loadVersion;
    emit(const RemixCreditLoading());
    try {
      final WallViewer resolvedViewer = viewer ?? await _currentViewer();
      final PrismWallpaper? original = await _repository.fetchApprovedWall(remixOfDocId);
      if (isClosed || loadVersion != _loadVersion) return;
      if (original != null && original.aiSource != null && resolvedViewer.canFullyView(original)) {
        emit(RemixCreditShown(original));
      } else {
        emit(const RemixCreditHidden());
      }
    } catch (error, stackTrace) {
      if (isClosed || loadVersion != _loadVersion) return;
      logger.w('[RemixCreditCubit] load failed for $remixOfDocId', error: error, stackTrace: stackTrace);
      emit(const RemixCreditHidden());
    }
  }

  Future<WallViewer> _currentViewer() async {
    final BlockedCreators blockedCreators = await _repository.loadBlockedCreators();
    return WallViewer(
      isPremium: app_state.prismUser.premium,
      premiumCollections: app_state.premiumCollections,
      blockedCreators: blockedCreators,
    );
  }
}
