import 'dart:math' show max;

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class RemixesState {
  const RemixesState();
}

final class RemixesLoading extends RemixesState {
  const RemixesLoading();
}

/// [remixes] holds at most 24 walls the viewer may open. [total] is the larger of the original's remix count and the
/// number of visible remixes found.
final class RemixesLoaded extends RemixesState {
  const RemixesLoaded(this.remixes, this.total);

  final List<PrismWallpaper> remixes;
  final int total;
}

/// No visible remixes, or the lookup failed.
final class RemixesEmpty extends RemixesState {
  const RemixesEmpty();
}

/// The remixes of one original that the viewer may open. Pages past hidden remixes until 24 are visible.
@injectable
class RemixesCubit extends Cubit<RemixesState> {
  RemixesCubit(this._repository) : super(const RemixesLoading());

  static const int _showLimit = 24;
  static const int _maxPages = 4;

  final WallRemixRepository _repository;
  int _loadVersion = 0;

  /// Loads the remixes of [original]. Uses [viewer] when given, otherwise the signed-in user and the blocked creators.
  Future<void> load(PrismWallpaper original, {WallViewer? viewer}) async {
    if (isClosed) return;
    final int loadVersion = ++_loadVersion;
    emit(const RemixesLoading());
    try {
      final WallViewer resolvedViewer = viewer ?? await _currentViewer();
      if (isClosed || loadVersion != _loadVersion) return;
      final String docId = original.firestoreDocumentId?.trim() ?? '';
      final PrismWallpaper? verified = await _repository.fetchApprovedWall(docId);
      if (isClosed || loadVersion != _loadVersion) return;
      if (verified == null || !resolvedViewer.canFullyView(verified)) {
        emit(const RemixesEmpty());
        return;
      }

      final List<PrismWallpaper> visible = <PrismWallpaper>[];
      String? cursor;
      for (int page = 0; page < _maxPages; page++) {
        final List<PrismWallpaper> rows = await _repository.fetchRemixes(docId, startAfterDocId: cursor);
        if (isClosed || loadVersion != _loadVersion) return;
        visible.addAll(visibleRemixes(rows, original: verified, viewer: resolvedViewer));
        if (visible.length >= _showLimit || rows.length < WallRemixRepository.remixLimit) break;
        cursor = rows.last.firestoreDocumentId;
        if (cursor == null || cursor.isEmpty) break;
      }

      if (isClosed || loadVersion != _loadVersion) return;
      if (visible.isEmpty) {
        emit(const RemixesEmpty());
        return;
      }
      emit(RemixesLoaded(visible.take(_showLimit).toList(growable: false), max(verified.remixCount, visible.length)));
    } catch (error, stackTrace) {
      if (isClosed || loadVersion != _loadVersion) return;
      logger.w('[RemixesCubit] load failed for ${original.id}', error: error, stackTrace: stackTrace);
      emit(const RemixesEmpty());
    }
  }

  Future<WallViewer> _currentViewer() async {
    final Set<String> blockedCreatorUids = await _repository.blockedCreatorUids();
    return WallViewer(
      isPremium: app_state.prismUser.premium,
      premiumCollections: app_state.premiumCollections,
      blockedCreatorUids: blockedCreatorUids,
    );
  }
}
